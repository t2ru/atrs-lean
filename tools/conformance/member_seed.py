#!/usr/bin/env python3
"""上流の会員のシード（00230_insert_member.sql）から、[Spec] と [Source] の初期状態の会員を生成する（backlog aedf）。

- lean/Spec/Seed/Member.lean: [Spec] の会員の列 `Spec.Seed.Member.members` と、採番の初期値
  （会員の次の値は、シードが `nextval('sq_member_1')` を呼んだ回数 + 1。予約・予約フライト・搭乗者は 1）
- lean/SourceModel/Db/MemberSeed.lean: [Source] の MEMBER・MEMBER_LOGIN の行と、`sq_member_1` の状態

会員番号は、シードの順に `to_char(nextval('sq_member_1'), 'FM0999999999')`（1 から）である。`LOGIN_DATE_TIME` は
`localtimestamp`（投入の時刻）なので、投入日（`conformance/fixtures/master-data.json` の `loadDate`）の 0:00 と
みなす（[Spec] のログイン日時は暦日）。各定義の `@[source]` は上流のシードの文（`seed:`。ハッシュは
`trace/source-inventory.json` の値）を指す。

使い方:
  uv run python -I tools/conformance/member_seed.py           # 生成物を書く
  uv run python -I tools/conformance/member_seed.py --check   # 生成物が最新であることを確かめる（CI）
"""
import datetime
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
SQL = REPO / "upstream/atrs/JavaConfig-Thymeleaf/atrs/atrs-initdb/src/sqls/integration-test-postgres/00230_insert_member.sql"
FIX = REPO / "conformance" / "fixtures" / "master-data.json"
INVENTORY = REPO / "trace" / "source-inventory.json"
OUT_SPEC = REPO / "lean" / "Spec" / "Seed" / "Member.lean"
OUT_SRC = REPO / "lean" / "SourceModel" / "Db" / "MemberSeed.lean"
LOC_MEMBER = "seed:00230_insert_member.sql#MEMBER"
LOC_LOGIN = "seed:00230_insert_member.sql#MEMBER_LOGIN"

MEMBER_COLS = ["CUSTOMER_NO", "KANJI_FAMILY_NAME", "KANJI_GIVEN_NAME", "KANA_FAMILY_NAME", "KANA_GIVEN_NAME", "BIRTHDAY",
               "GENDER", "TEL", "ZIP_CODE", "ADDRESS", "MAIL", "CREDIT_NO", "CREDIT_TYPE_CD", "CREDIT_TERM"]
LOGIN_COLS = ["CUSTOMER_NO", "PASSWORD", "LAST_PASSWORD", "LOGIN_DATE_TIME", "LOGIN_FLG"]


def split_values(v: str) -> list[str]:
    """`VALUES (…)` の中身を、括弧と引用符を考えて最上位のカンマで分ける。"""
    out, cur, depth, q = [], "", 0, False
    for c in v:
        if q:
            cur += c
            if c == "'":
                q = False
            continue
        if c == "'":
            q = True
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        cur += c
    out.append(cur.strip())
    return out


def parse() -> tuple[list[dict], list[dict]]:
    members, logins = [], []
    seq = 0
    for line in SQL.read_text(encoding="utf-8").splitlines():
        m = re.match(r"INSERT INTO (MEMBER|MEMBER_LOGIN) \(([^)]*)\) VALUES \((.*)\);\s*$", line)
        if not m:
            continue
        cols = [c.strip() for c in m.group(2).split(",")]
        vals = split_values(m.group(3))
        row = dict(zip(cols, vals))
        if m.group(1) == "MEMBER":
            assert cols == MEMBER_COLS, cols
            assert row["CUSTOMER_NO"].lower() == "to_char(nextval('sq_member_1'), 'fm0999999999')", row["CUSTOMER_NO"]
            seq += 1
            row["CUSTOMER_NO"] = f"{seq:010d}"
            b = re.fullmatch(r"TO_DATE\('(\d{4})/(\d{2})/(\d{2})', 'YYYY/MM/DD'\)", row["BIRTHDAY"])
            assert b, row["BIRTHDAY"]
            row["BIRTHDAY"] = tuple(int(x) for x in b.groups())
            for k in MEMBER_COLS:
                if k not in ("CUSTOMER_NO", "BIRTHDAY"):
                    assert row[k].startswith("'") and row[k].endswith("'"), (k, row[k])
                    row[k] = row[k][1:-1]
            members.append(row)
        else:
            assert cols == LOGIN_COLS, cols
            assert row["CUSTOMER_NO"].upper() == "TO_CHAR(CURRVAL('SQ_MEMBER_1'), 'FM0999999999')", row["CUSTOMER_NO"]
            row["CUSTOMER_NO"] = f"{seq:010d}"
            for k in ("PASSWORD", "LAST_PASSWORD"):
                assert row[k].startswith("'") and row[k].endswith("'"), (k, row[k])
                row[k] = row[k][1:-1]
            assert row["LOGIN_DATE_TIME"] == "localtimestamp", row["LOGIN_DATE_TIME"]
            assert row["LOGIN_FLG"] in ("FALSE", "TRUE"), row["LOGIN_FLG"]
            row["LOGIN_FLG"] = row["LOGIN_FLG"] == "TRUE"
            logins.append(row)
    assert len(members) == len(logins) == seq
    return members, logins


def s(v: str) -> str:
    return json.dumps(v, ensure_ascii=False)


def hashes() -> dict:
    items = json.loads(INVENTORY.read_text(encoding="utf-8"))["items"]
    return {it["locator"]: it["hash"] for it in items}


def render_spec(members: list[dict], logins: list[dict], load: tuple[int, int, int], h: dict) -> str:
    lines = [
        "import Spec.Model",
        "import Spec.World",
        "import Trace",
        "",
        "/-!",
        "# Spec.Seed.Member",
        "",
        "シードの会員（上流の `00230_insert_member.sql`）の [Spec] の値と、採番の初期値。",
        "`tools/conformance/member_seed.py` が生成する。手で編集しない。",
        "ログイン日時（`localtimestamp`）は投入日とみなす。",
        "-/",
        "",
        "namespace Spec.Seed.Member",
        "",
        "open Spec.Model Spec.Prim",
        "",
        f"/-- シードの会員（{len(members)} 名。シードの順）。 -/",
        f"@[source {s(LOC_MEMBER + '@' + h[LOC_MEMBER])}, {s(LOC_LOGIN + '@' + h[LOC_LOGIN])}]",
        "def members : List Member := [",
    ]
    for i, (m, l) in enumerate(zip(members, logins)):
        y, mo, d = m["BIRTHDAY"]
        last = "none" if l["LAST_PASSWORD"] == "" else f"some ⟨{s(l['LAST_PASSWORD'])}⟩"
        lines.append(
            f"  {{ membershipNumber := {{ val := {s(m['CUSTOMER_NO'])} }}, kanjiFamilyName := {s(m['KANJI_FAMILY_NAME'])}, "
            f"kanjiGivenName := {s(m['KANJI_GIVEN_NAME'])}, kanaFamilyName := {s(m['KANA_FAMILY_NAME'])}, "
            f"kanaGivenName := {s(m['KANA_GIVEN_NAME'])}, birthday := Date.ymd! {y} {mo} {d}, gender := .{m['GENDER']}, "
            f"tel := {s(m['TEL'])}, zipCode := {s(m['ZIP_CODE'])}, address := {s(m['ADDRESS'])}, mail := {s(m['MAIL'])}, "
            f"creditNo := {s(m['CREDIT_NO'])}, creditTypeCd := {{ val := {s(m['CREDIT_TYPE_CD'])} }}, creditTerm := {s(m['CREDIT_TERM'])}, "
            f"login := {{ password := ⟨{s(l['PASSWORD'])}⟩, lastPassword := {last}, "
            f"loginDateTime := some (Date.ymd! {load[0]} {load[1]} {load[2]}), loginFlg := {'true' if l['LOGIN_FLG'] else 'false'} }} }}"
            f"{',' if i + 1 < len(members) else ''}")
    lines += [
        "]",
        "",
        f"/-- 採番の初期値: 会員はシードが {len(members)} 回採番した次、ほかは 1。 -/",
        f"@[source {s(LOC_MEMBER + '@' + h[LOC_MEMBER])}]",
        f"def sequences : Spec.World.Sequences := {{ member := {len(members) + 1} }}",
        "",
        "end Spec.Seed.Member",
        "",
    ]
    return "\n".join(lines)


def render_src(members: list[dict], logins: list[dict], load: tuple[int, int, int], h: dict) -> str:
    epoch = (datetime.date(*load) - datetime.date(1970, 1, 1)).days

    def v(n: int, x: str) -> str:
        return f"⟨{s(x)}, by decide⟩"

    lines = [
        "import SourceModel.Db.Schema",
        "import Trace",
        "",
        "/-!",
        "# SourceModel.Db.MemberSeed",
        "",
        "シードの会員（上流の `00230_insert_member.sql`）の MEMBER・MEMBER_LOGIN の行と、`sq_member_1` の状態。",
        "`tools/conformance/member_seed.py` が生成する。手で編集しない。",
        "`LOGIN_DATE_TIME`（`localtimestamp`）は投入日の 0:00 とみなす。",
        "-/",
        "",
        "namespace SourceModel.Db.MemberSeed",
        "",
        "open LangSemantics.Sql.Postgresql SourceModel.Db.Schema",
        "",
        f"/-- MEMBER（{len(members)} 行）。 -/",
        f"@[source {s(LOC_MEMBER + '@' + h[LOC_MEMBER])}]",
        "def memberRows : List MemberRow := [",
    ]
    for i, m in enumerate(members):
        b = (datetime.date(*m["BIRTHDAY"]) - datetime.date(1970, 1, 1)).days
        lines.append(
            "  { " + ", ".join([
                f"customerNo := {v(10, m['CUSTOMER_NO'])}", f"kanjiFamilyName := {v(10, m['KANJI_FAMILY_NAME'])}",
                f"kanjiGivenName := {v(10, m['KANJI_GIVEN_NAME'])}", f"kanaFamilyName := {v(10, m['KANA_FAMILY_NAME'])}",
                f"kanaGivenName := {v(10, m['KANA_GIVEN_NAME'])}", f"birthday := ⟨{b}, by decide⟩",
                f"gender := {v(1, m['GENDER'])}", f"tel := {v(13, m['TEL'])}", f"zipCode := {v(7, m['ZIP_CODE'])}",
                f"address := {v(60, m['ADDRESS'])}", f"mail := {v(256, m['MAIL'])}", f"creditNo := {v(16, m['CREDIT_NO'])}",
                f"creditTypeCd := {v(3, m['CREDIT_TYPE_CD'])}", f"creditTerm := {v(5, m['CREDIT_TERM'])}"])
            + f" }}{',' if i + 1 < len(members) else ''}")
    lines += [
        "]",
        "",
        f"/-- MEMBER_LOGIN（{len(logins)} 行）。 -/",
        f"@[source {s(LOC_LOGIN + '@' + h[LOC_LOGIN])}]",
        "def memberLoginRows : List MemberLoginRow := [",
    ]
    for i, l in enumerate(logins):
        last = "none" if l["LAST_PASSWORD"] == "" else f"some {v(124, l['LAST_PASSWORD'])}"
        lines.append(
            f"  {{ customerNo := {v(10, l['CUSTOMER_NO'])}, password := {v(124, l['PASSWORD'])}, lastPassword := {last}, "
            f"loginDateTime := some ⟨{epoch * 86400000000}, by decide⟩, loginFlg := {'true' if l['LOGIN_FLG'] else 'false'} }}"
            f"{',' if i + 1 < len(logins) else ''}")
    lines += [
        "]",
        "",
        f"/-- `sq_member_1` の状態（シードが {len(members)} 回 `nextval` を呼んだ後）。 -/",
        f"@[source {s(LOC_MEMBER + '@' + h[LOC_MEMBER])}]",
        f"def sqMember : LangSemantics.Sql.Sequence.SequenceState := some {len(members)}",
        "",
        "end SourceModel.Db.MemberSeed",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    members, logins = parse()
    load = tuple(int(x) for x in json.loads(FIX.read_text(encoding="utf-8"))["loadDate"].split("-"))
    h = hashes()
    outs = {OUT_SPEC: render_spec(members, logins, load, h), OUT_SRC: render_src(members, logins, load, h)}
    if "--check" in sys.argv[1:]:
        bad = [p for p, t in outs.items() if not p.exists() or p.read_text(encoding="utf-8") != t]
        for p in bad:
            print(f"member_seed: {p.relative_to(REPO)} is out of date (run tools/conformance/member_seed.py)", file=sys.stderr)
        if bad:
            return 1
        print("member_seed: generated files are up to date")
        return 0
    for p, t in outs.items():
        p.write_text(t, encoding="utf-8")
        print(f"member_seed: wrote {p.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
