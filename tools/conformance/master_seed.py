#!/usr/bin/env python3
"""シードのマスタ（conformance/fixtures/master-data.json）から、[Source] のマスタの表の値のリテラル
`lean/SourceModel/Db/MasterSeed.lean` を生成する。

ADR ab93 の 3d: 予約の束の環境の前提の証人を初期状態（シード）で示すため、具体側の入力のマスタの DB（`MasterDb`）を
シードの値で持つ。`Abstraction.MasterData.SeedAlpha` が、その α が [Spec] のシードのマスタ `Spec.Seed.Master.masterData`
であることを示す。行の順は JSON（シードの順）のまま。[Source] の表なので、`outsideSpec` の行も除かない。

各表の定義には、上流のシードの文のロケータ（`seed:`。ハッシュは `trace/source-inventory.json` の値）を `@[source]` で
付ける。シードから表の値への変換は本生成器の決定論的な変換で、`--check` が一致を確かめる。

使い方:
  uv run python -I tools/conformance/master_seed.py           # lean/SourceModel/Db/MasterSeed.lean を書く
  uv run python -I tools/conformance/master_seed.py --check   # 生成物が最新であることを確かめる（CI）
"""
import datetime
import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
FIX = REPO / "conformance" / "fixtures"
OUT = REPO / "lean" / "SourceModel" / "Db" / "MasterSeed.lean"
CHUNK = 100
INVENTORY = REPO / "trace" / "source-inventory.json"

# 表 → (JSON の鍵、行の型、上流のシードの文)
TABLES = {
    "airport": ("airports", "AirportRow", "seed:00200_insert_fixed_value.sql#AIRPORT"),
    "route": ("routes", "RouteRow", "seed:00210_insert_route.sql#ROUTE"),
    "flightMaster": ("flightMasters", "FlightMasterRow", "seed:00220_insert_flight_master.sql#FLIGHT_MASTER"),
    "boardingClass": ("boardingClasses", "BoardingClassRow", "seed:00200_insert_fixed_value.sql#BOARDING_CLASS"),
    "fareType": ("fareTypes", "FareTypeRow", "seed:00200_insert_fixed_value.sql#FARE_TYPE"),
    "peakTime": ("peakTimes", "PeakTimeRow", "seed:00240_insert_peak_time.sql#PEAK_TIME"),
    "plane": ("planes", "PlaneRow", "seed:00200_insert_fixed_value.sql#PLANE"),
    "creditType": ("creditTypes", "CreditTypeRow", "seed:00200_insert_fixed_value.sql#CREDIT_TYPE"),
}


def seed_hashes() -> dict:
    items = json.loads(INVENTORY.read_text(encoding="utf-8"))["items"]
    return {it["locator"]: it["hash"] for it in items if it["locator"].startswith("seed:")}


def v(x: str) -> str:
    """`VARCHAR(n)` の値（長さの証明は `decide`）。"""
    return f"⟨{json.dumps(x, ensure_ascii=False)}, by decide⟩"


def i(x: int) -> str:
    """`INT` の値（範囲の証明は `decide`）。"""
    return f"⟨{x}, by decide⟩"


def d(x: str) -> str:
    """`DATE` の値（通算日数）。"""
    e = (datetime.date.fromisoformat(x) - datetime.date(1970, 1, 1)).days
    return f"⟨{e}, by decide⟩"


FMT = {
    "airport": lambda r: f"⟨{v(r['code'])}, {v(r['name'])}, {i(r['displayOrder'])}⟩",
    "route": lambda r: f"⟨{i(r['routeNo'])}, {v(r['depAirportCd'])}, {v(r['arrAirportCd'])}, {v(r['flightTime'])}, "
                       f"{i(r['basicFare'])}⟩",
    "flightMaster": lambda r: f"⟨{v(r['flightName'])}, {i(r['routeNo'])}, {v(r['departureTime'])}, "
                              f"{v(r['arrivalTime'])}, {v(r['craftType'])}⟩",
    "boardingClass": lambda r: f"⟨{v(r['boardingClassCd'])}, "
                               f"{'some ' + v(r['boardingClassName']) if r['boardingClassName'] is not None else 'none'}, "
                               f"{i(r['extraCharge'])}, {i(r['displayOrder'])}⟩",
    "fareType": lambda r: f"⟨{v(r['fareTypeCd'])}, {v(r['fareTypeName'])}, {i(r['discountRate'])}, "
                          f"{i(r['rsrvAvailableStartDayNum'])}, {i(r['rsrvAvailableEndDayNum'])}, "
                          f"{i(r['passengerMinNum'])}, {i(r['displayOrder'])}⟩",
    "peakTime": lambda r: f"⟨{v(r['peakTimeCd'])}, {d(r['peakStartDate'])}, {d(r['peakEndDate'])}, "
                          f"{i(r['multiplicationRatio'])}⟩",
    "plane": lambda r: f"⟨{v(r['craftType'])}, {i(r['nSeatNum'])}, {i(r['sSeatNum'])}⟩",
    "creditType": lambda r: f"⟨{v(r['creditTypeCd'])}, {v(r['creditFirm'])}, {i(r['displayOrder'])}⟩",
}


def table(name: str, ty: str, rows: list, fmt, source: str) -> list[str]:
    """100 行ずつの部分の列を `++` でつなぐ（長いリストのリテラルの展開の深さを抑える）。"""
    out = []
    parts = [rows[k:k + CHUNK] for k in range(0, len(rows), CHUNK)] or [[]]
    for k, part in enumerate(parts):
        out.append(f"def {name}{k} : List {ty} := [")
        out.extend(f"  {fmt(r)}{',' if j + 1 < len(part) else ''}" for j, r in enumerate(part))
        out.append("]")
        out.append("")
    out.append(f"/-- `{name}`（{len(rows)} 行）。 -/")
    out.append(f"@[source {json.dumps(source, ensure_ascii=False)}]")
    out.append(f"def {name} : List {ty} := " + " ++ ".join(f"{name}{k}" for k in range(len(parts))))
    out.append("")
    return out


def render() -> str:
    md = json.loads((FIX / "master-data.json").read_text(encoding="utf-8"))
    lines = [
        "import Trace",
        "import LangSemantics.Sql.Postgresql",
        "import SourceModel.Db.Schema",
        "",
        "/-!",
        "# SourceModel.Db.MasterSeed",
        "",
        "シードのマスタの表（[Source] の具体側の入力のマスタの DB。`conformance/fixtures/master-data.json`）。",
        "`tools/conformance/master_seed.py` が生成する。手で編集しない。",
        f"上流: {md['upstream']['release']} / {md['upstream']['commit']}。行の順はシードの順。",
        "各表の `@[source]` は上流のシードの文（この変換の入力の出所）を指す。",
        "-/",
        "",
        "set_option maxRecDepth 8192",
        "",
        "namespace SourceModel.Db.MasterSeed",
        "open LangSemantics.Sql.Postgresql SourceModel.Db.Schema",
        "",
    ]
    hashes = seed_hashes()
    for name, (key, ty, loc) in TABLES.items():
        lines += table(name, ty, md[key], FMT[name], f"{loc}@{hashes[loc]}")
    lines += [
        "/-- シードのマスタの DB。 -/",
        "def masterDb : MasterDb :=",
        "  ⟨airport, route, flightMaster, boardingClass, fareType, peakTime, plane, creditType⟩",
        "",
        "end SourceModel.Db.MasterSeed",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    text = render()
    if "--check" in sys.argv[1:]:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"master_seed: {OUT.relative_to(REPO)} is out of date (run tools/conformance/master_seed.py)",
                  file=sys.stderr)
            return 1
        print(f"master_seed: {OUT.relative_to(REPO)} is up to date")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"master_seed: wrote {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
