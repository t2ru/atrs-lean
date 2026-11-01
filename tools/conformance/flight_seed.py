#!/usr/bin/env python3
"""上流のシード 00250_insert_flight.sql（plpgsql の関数 C_FLIGHT）から、フライトの初期状態を生成する（backlog 0be7 の第 2 段）。

シードは、投入日から 120 日後まで（両端を含む 121 日）の各日に、空席数のパターン `mod(i, 3)`（i は投入日を 0 とする日の番号）
の INSERT を実行する。各パターンは、便ごとに 10 行（搭乗クラス・運賃種別の 10 枠。順序はどの便でも同じ）を持つ。
本生成器は、関数の形（期間・日の進め方・パターンの数）を確かめたうえで、次の形で書き出す。全件（15 万行）には展開しない。

- 日付の列（投入日 2026-11-01 から 121 日。ADR 9ee4）
- 枠の列（10 個）と、便名の列（パターンで共通）
- パターンごとの空席数の表（便名ごとに 10 個）

生成物:
- lean/Spec/Seed/Flight.lean: [Spec] の `World` の初期状態 `Spec.Seed.Flight.world`
- lean/SourceModel/Db/FlightSeed.lean: [Source] の FLIGHT 表の初期状態 `seedFlightDb`（行の順は INSERT の順）

ほかの道具（tools/conformance/master_sql.py）は、`expand()` で全件を展開して PostgreSQL の投入結果と照合する。

  python3 -I tools/conformance/flight_seed.py           # 書き出す
  python3 -I tools/conformance/flight_seed.py --check   # 最新であることを確かめる
"""
import datetime
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQL = ROOT / "upstream/atrs/JavaConfig-Thymeleaf/atrs/atrs-initdb/src/sqls/integration-test-postgres/00250_insert_flight.sql"
SPEC_OUT = ROOT / "lean/Spec/Seed/Flight.lean"
SRC_OUT = ROOT / "lean/SourceModel/Db/FlightSeed.lean"
LOAD_DATE = datetime.date(2026, 11, 1)
SEED_LOCATOR = "seed:00250_insert_flight.sql#FLIGHT"

ROW = re.compile(r"INSERT INTO FLIGHT \(DEPARTURE_DATE, FLIGHT_NAME, BOARDING_CLASS_CD, FARE_TYPE_CD, VACANT_NUM\) "
                 r"VALUES \(currentDate, '(\w+)', '(\w)', '(\w+)', (\d+)\);")
BLOCK = re.compile(r"IF mod\(i, 3\) = (\d) THEN(.*?)END IF;", re.S)


def fail(msg):
    sys.exit(f"flight_seed: {msg}")


def parse():
    """(日数, 枠の列, 便名の列, パターンごとの空席数の表) を返す。関数の形が想定と違えば止める。"""
    raw = SQL.read_text(encoding="utf-8")
    # 行末の `--` 以降の注釈を除いた文の列で、関数の形を確かめる（注釈にある別の期間の指定は効かない）
    stmts = [ln.split("--", 1)[0].strip() for ln in raw.splitlines()]
    stmts = [ln for ln in stmts if ln]
    text = "\n".join(stmts)
    for needle in ["currentDate DATE := current_date;", "endDate DATE := current_date+120;", "i := 0;",
                   "WHILE currentDate <= endDate LOOP", "currentDate := currentDate + 1;", "i := i + 1;",
                   "SELECT C_FLIGHT();"]:
        if stmts.count(needle) != 1:
            fail(f"unexpected shape of C_FLIGHT ({needle!r} must appear exactly once outside comments)")
    # ループの本体は、3 つの IF ブロックと日・番号の進め方だけ
    loop = text[text.index("WHILE currentDate <= endDate LOOP"):text.index("END LOOP;")]
    rest = BLOCK.sub("", loop).split("\n")
    if [ln for ln in rest if ln] != ["WHILE currentDate <= endDate LOOP", "currentDate := currentDate + 1;", "i := i + 1;"]:
        fail("unexpected statements in the loop of C_FLIGHT")
    days = 121  # current_date から current_date + 120 まで（両端を含む）
    blocks = BLOCK.findall(text)
    if [int(k) for k, _ in blocks] != [0, 1, 2]:
        fail("expected three blocks mod(i, 3) = 0, 1, 2")
    slots, names, tables = None, None, []
    for _, body in blocks:
        lines = [ln.strip() for ln in body.strip().splitlines() if ln.strip()]
        rows = []
        for ln in lines:
            m = ROW.fullmatch(ln)
            if not m:
                fail(f"cannot parse: {ln!r}")
            rows.append((m.group(1), m.group(2), m.group(3), int(m.group(4))))
        # 便ごとに 10 行、枠の順はどの便でも同じ
        if len(rows) % 10:
            fail("rows per block is not a multiple of 10")
        groups = [rows[k:k + 10] for k in range(0, len(rows), 10)]
        s = [(r[1], r[2]) for r in groups[0]]
        n = [g[0][0] for g in groups]
        for g in groups:
            if [(r[1], r[2]) for r in g] != s or len({r[0] for r in g}) != 1:
                fail("a flight does not have the 10 slots in the common order")
        if slots is None:
            slots, names = s, n
        elif s != slots or n != names:
            fail("the blocks do not share the slots and flight names")
        tables.append([[r[3] for r in g] for g in groups])
    if len(set(names)) != len(names) or len(set(slots)) != len(slots):
        fail("duplicate flight names or slots")
    return days, slots, names, tables


def dates(days):
    return [LOAD_DATE + datetime.timedelta(days=i) for i in range(days)]


def expand():
    """全件（INSERT の順）: (日付, 便名, 搭乗クラス, 運賃種別, 空席数)。"""
    days, slots, names, tables = parse()
    out = []
    for i, d in enumerate(dates(days)):
        for n, vs in zip(names, tables[i % 3]):
            for (b, f), v in zip(slots, vs):
                out.append((d, n, b, f, v))
    return out


def seed_hash():
    hashes = json.loads((ROOT / "trace/source-inventory.json").read_text(encoding="utf-8"))["items"]
    for it in hashes:
        if it["locator"] == SEED_LOCATOR:
            return it["hash"]
    fail(f"{SEED_LOCATOR} not in trace/source-inventory.json")


def header(module, desc):
    return ["/-!", f"# {module}", "", *desc, "", "`tools/conformance/flight_seed.py` が上流のシード 00250 から生成する。手で編集しない。", "-/", ""]


def spec_lean(days, slots, names, tables, h):
    L = ["import Spec.Model", "import Spec.Port", ""]
    L += header("Spec.Seed.Flight", [
        "シードのフライト（`World` の初期状態。backlog 0be7 の第 2 段）。投入日 2026-11-01 から 121 日の各日に、",
        "空席数のパターン `i % 3`（`i` は投入日を 0 とする日の番号）を、便名 × 10 枠（搭乗クラス・運賃種別）で並べる。",
        "全件には展開せず、日付の列・枠の列・便名の列・パターンの表から `world` を作る。"])
    L += ["set_option maxRecDepth 8192", "", "namespace Spec.Seed.Flight", "open Spec.Model Spec.Prim", ""]
    L += ["/-- 日付の列（投入日から 121 日）。 -/", f'@[source "{SEED_LOCATOR}@{h}"]', "def days : List Date := ["]
    L += [f"  ⟨{d.year}, {d.month}, {d.day}, by decide⟩," for d in dates(days)]
    L[-1] = L[-1].rstrip(",")
    L += ["]", ""]
    L += ["/-- 枠（搭乗クラス・運賃種別）の列。どの便でも同じ順。 -/", f'@[source "{SEED_LOCATOR}@{h}"]',
          "def slots : List (BoardingClassCd × FareTypeCd) := [" + ", ".join(f"(.{b}, .{f})" for b, f in slots) + "]", ""]
    L += ["/-- 便名の列。 -/", f'@[source "{SEED_LOCATOR}@{h}"]', "def names : List FlightName := ["]
    for k in range(0, len(names), 10):
        L.append("  " + ", ".join(f'⟨"{n}"⟩' for n in names[k:k + 10]) + ("," if k + 10 < len(names) else ""))
    L += ["]", ""]
    for p, tbl in enumerate(tables):
        L += [f"/-- パターン {p}（`i % 3 = {p}`）の空席数（便名の列の順に、枠の順の 10 個）。 -/", f'@[source "{SEED_LOCATOR}@{h}"]',
              f"def vacant{p} : List (List Nat) := ["]
        L += ["  [" + ", ".join(str(v) for v in vs) + "]," for vs in tbl]
        L[-1] = L[-1].rstrip(",")
        L += ["]", ""]
    L += ["/-- 日の番号 `i` のパターン。 -/", "def pattern (i : Nat) : List (List Nat) :=",
          "  if i % 3 = 0 then vacant0 else if i % 3 = 1 then vacant1 else vacant2", "",
          "/-- 1 日分のフライト（便名ごとに、枠と空席数を組にする）。 -/",
          "def dayFlights (d : Date) (vs : List (List Nat)) : List Flight :=",
          "  (names.zip vs).flatMap fun (n, row) => (slots.zip row).map fun ((b, f), v) => ⟨⟨d, n, b, f⟩, v⟩", "",
          "/-- シードのフライト（`World` の初期状態）。 -/",
          "def world : Spec.Port.World := ⟨(days.zipIdx).flatMap fun (d, i) => dayFlights d (pattern i)⟩", "",
          "end Spec.Seed.Flight", ""]
    return "\n".join(L)


def src_lean(days, slots, names, tables, h):
    epoch = datetime.date(1970, 1, 1)
    L = ["import Trace", "import LangSemantics.Sql.Postgresql", "import SourceModel.Db.Schema", ""]
    L += header("SourceModel.Db.FlightSeed", [
        "シードの FLIGHT 表（[Source] の状態の初期値。backlog 0be7 の第 2 段）。`C_FLIGHT()` は、投入日 2026-11-01 から",
        "121 日の各日に、空席数のパターン `mod(i, 3)` の INSERT を順に実行する。行の順は INSERT の順（日・便・枠）である。",
        "全件には展開せず、日付・枠・便名・パターンの表から `seedFlightDb` を作る。"])
    L += ["set_option maxRecDepth 8192", "", "namespace SourceModel.Db.FlightSeed",
          "open LangSemantics.Sql.Postgresql SourceModel.Db.Schema", ""]
    L += ["/-- 日付の列（`DATE` の通算日数。投入日から 121 日）。 -/", f'@[source "{SEED_LOCATOR}@{h}"]', "def days : List PgDate := ["]
    L += [f"  ⟨{(d - epoch).days}, by decide⟩," for d in dates(days)]
    L[-1] = L[-1].rstrip(",")
    L += ["]", ""]
    L += ["/-- 枠（`BOARDING_CLASS_CD`・`FARE_TYPE_CD`）の列。どの便でも同じ順。 -/", f'@[source "{SEED_LOCATOR}@{h}"]',
          "def slots : List (Varchar 1 × Varchar 4) := [" + ", ".join(f'(⟨"{b}", by decide⟩, ⟨"{f}", by decide⟩)' for b, f in slots) + "]", ""]
    L += ["/-- 便名（`FLIGHT_NAME`）の列。 -/", f'@[source "{SEED_LOCATOR}@{h}"]', "def names : List (Varchar 6) := ["]
    for k in range(0, len(names), 8):
        L.append("  " + ", ".join(f'⟨"{n}", by decide⟩' for n in names[k:k + 8]) + ("," if k + 8 < len(names) else ""))
    L += ["]", ""]
    for p, tbl in enumerate(tables):
        L += [f"/-- パターン {p}（`mod(i, 3) = {p}`）の `VACANT_NUM`（便名の列の順に、枠の順の 10 個）。 -/", f'@[source "{SEED_LOCATOR}@{h}"]',
              f"def vacant{p} : List (List Int4) := ["]
        L += ["  [" + ", ".join(f"⟨{v}, by decide⟩" for v in vs) + "]," for vs in tbl]
        L[-1] = L[-1].rstrip(",")
        L += ["]", ""]
    L += ["/-- 日の番号 `i` のパターン。 -/", "def pattern (i : Nat) : List (List Int4) :=",
          "  if i % 3 = 0 then vacant0 else if i % 3 = 1 then vacant1 else vacant2", "",
          "/-- 1 日分の INSERT の行。 -/",
          "def dayRows (d : PgDate) (vs : List (List Int4)) : List FlightRow :=",
          "  (names.zip vs).flatMap fun (n, row) => (slots.zip row).map fun ((b, f), v) => ⟨d, n, b, f, v⟩", "",
          "/-- シードの FLIGHT 表（`SELECT C_FLIGHT()` の後）。 -/",
          "def seedFlightDb : FlightDb := ⟨(days.zipIdx).flatMap fun (d, i) => dayRows d (pattern i)⟩", "",
          "end SourceModel.Db.FlightSeed", ""]
    return "\n".join(L)


def main():
    check = "--check" in sys.argv[1:]
    days, slots, names, tables = parse()
    h = seed_hash()
    outs = [(SPEC_OUT, spec_lean(days, slots, names, tables, h)), (SRC_OUT, src_lean(days, slots, names, tables, h))]
    for path, content in outs:
        rel = path.relative_to(ROOT)
        if check:
            if not path.is_file() or path.read_text(encoding="utf-8") != content:
                fail(f"{rel} is out of date (run tools/conformance/flight_seed.py)")
            print(f"flight_seed: {rel} is up to date")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            print(f"flight_seed: wrote {rel}")
    print(f"flight_seed: {days} days, {len(names)} flights, {len(slots)} slots, {days * len(names) * len(slots)} rows")


if __name__ == "__main__":
    main()
