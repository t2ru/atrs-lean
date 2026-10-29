#!/usr/bin/env python3
"""obligation-check の結果を文書と突き合わせる（TR-N と、TR-G の文書側。ADR 0038）。

`lake exe obligation-check` の JSON（Lean 側の判定と事実）と、`docs/spec/abstraction.md`・`refinement.md` の
登録簿を突き合わせる。

| 規則 | 失敗条件 | 段階導入 |
| --- | --- | --- |
| OB-L  | Lean 側の判定に誤りがある（G1〜G8） | — |
| OB-N1 | `@[nondet]` の ID が「Spec の非決定性（N-NNN）」の表に無い | — |
| OB-N2 | 表の N-NNN に対応する `@[nondet]` が無い | 警告 |
| OB-E1 | 「入口の R 課題」の表にある R 課題の抽象側の基底に `TotalUnder` の定理が無い | — |
| OB-E2 | 「入口の R 課題」の表にある R 課題が Lean に無い | 警告 |
| OB-S1 | 「出力のみ」の差異の `@[deviation]` に `StateSafe`・`StateSafeConcrete` の定理が無い | — |
| OB-S2 | 「出力のみ」の差異に `@[deviation]` がまだ無い | 警告 |
| OB-D1 | 前提型の差異が「前提型の差異の影響」の表に無い、または影響が「出力のみ」「中断」でない | — |

警告は、該当する機能の作業項目が完了するまでの段階導入である（スキル port-lang の traceability.md）。

使い方:
  python3 -I tools/ci/check_obligations.py <obligation-check の JSON>   # 本番の文書と突き合わせる
  python3 -I tools/ci/check_obligations.py --self-test                  # tools/ci/fixtures/obligations の例で確かめる
"""
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
DOCS = REPO / "docs" / "spec"
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures" / "obligations"

ID_CELL = re.compile(r"^\|\s*([A-Z]+-\d{3})\s*\|(.*)$")
IMPACTS = {"出力のみ", "中断"}


def section_rows(text: str, heading: str):
    """見出し `heading` で始まる節（次の同じ深さ以上の見出しまで）の表の行を、(ID, 残りのセル) で返す。"""
    lines = text.splitlines()
    out = []
    level = None
    for line in lines:
        m = re.match(r"^(#+)\s+(.*)$", line)
        if m:
            if level is not None and len(m.group(1)) <= level:
                break
            if m.group(2).strip().startswith(heading):
                level = len(m.group(1))
            continue
        if level is None:
            continue
        r = ID_CELL.match(line)
        if r:
            cells = [c.strip() for c in r.group(2).split("|")]
            out.append((r.group(1), cells))
    return out


def parse_docs(doc_dir: pathlib.Path):
    abstraction = (doc_dir / "abstraction.md").read_text(encoding="utf-8")
    refinement = (doc_dir / "refinement.md").read_text(encoding="utf-8")
    nondet = {i for i, _ in section_rows(abstraction, "Spec の非決定性")}
    entries = set()
    impact = {}
    pre_type = set()
    for text, reg in ((abstraction, "既知差異"), (refinement, "既知差異")):
        entries |= {i for i, _ in section_rows(text, "入口の R 課題")}
        impact.update({i: cells[0] for i, cells in section_rows(text, "前提型の差異の影響")})
        pre_type |= {i for i, cells in section_rows(text, reg) if cells and cells[0].startswith("前提型")}
    return {"nondet": nondet, "entries": entries, "impact": impact, "pre_type": pre_type}


def check(report: dict, docs: dict):
    """(重さ, 規則, 内容) の列を返す。重さは "error" か "warning"。"""
    found = []
    for e in report.get("errors", []):
        found.append(("error", "OB-L", e))
    for ob in report.get("obligations", []):
        for e in ob.get("errors", []):
            found.append(("error", "OB-L", f"{ob['name']}: {e}"))
    # TR-N
    lean_nondet = {i for d in report.get("nondet", []) for i in d["ids"]}
    for i in sorted(lean_nondet - docs["nondet"]):
        found.append(("error", "OB-N1", f"@[nondet \"{i}\"] is not in the N-NNN table"))
    for i in sorted(docs["nondet"] - lean_nondet):
        found.append(("warning", "OB-N2", f"{i} has no @[nondet] yet"))
    # 入口の全域性
    total = set(report.get("total_under", []))
    seen = set()
    for ob in report.get("obligations", []):
        for i in ob["ids"]:
            if i in docs["entries"]:
                seen.add(i)
                if ob.get("abstract_base") not in total:
                    found.append(("error", "OB-E1",
                                  f"{i} ({ob['name']}): no TotalUnder theorem for {ob.get('abstract_base')}"))
    for i in sorted(docs["entries"] - seen):
        found.append(("warning", "OB-E2", f"entry obligation {i} has no Lean theorem yet"))
    # 前提型の差異の影響
    for i in sorted(docs["pre_type"]):
        kind = docs["impact"].get(i)
        if kind not in IMPACTS:
            found.append(("error", "OB-D1", f"{i}: impact is {kind!r}; expected one of {sorted(IMPACTS)}"))
    safe = set(report.get("state_safe", []))
    for i, kind in sorted(docs["impact"].items()):
        if kind != "出力のみ":
            continue
        consts = [d["name"] for d in report.get("deviation", []) if i in d["ids"]]
        if not consts:
            found.append(("warning", "OB-S2", f"{i} (出力のみ) has no @[deviation] yet"))
        for c in consts:
            if c not in safe:
                found.append(("error", "OB-S1", f"{i} (出力のみ): {c} has no StateSafe theorem"))
    return found


def report_and_exit(found, label: str) -> int:
    errors = [f for f in found if f[0] == "error"]
    for sev, rule, msg in found:
        print(f"{label}: {sev}: {rule}: {msg}", file=sys.stderr)
    nwarn = len(found) - len(errors)
    if errors:
        print(f"{label}: FAIL ({len(errors)} error(s), {nwarn} warning(s))", file=sys.stderr)
        return 1
    print(f"{label}: OK ({nwarn} warning(s))")
    return 0


def main_check(path: str) -> int:
    report = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    return report_and_exit(check(report, parse_docs(DOCS)), "check_obligations")


def main_self_test() -> int:
    """各フィクスチャ（ディレクトリ）の `expect.txt`（失敗の規則。空なら失敗なし）と、検出した失敗の規則を比べる。"""
    bad = 0
    cases = sorted(p for p in FIXTURES.iterdir() if p.is_dir())
    for case in cases:
        report = json.loads((case / "report.json").read_text(encoding="utf-8"))
        found = check(report, parse_docs(case))
        expected = {s.strip() for s in (case / "expect.txt").read_text(encoding="utf-8").split(",") if s.strip()}
        actual = {rule for sev, rule, _ in found if sev == "error"}
        if expected != actual:
            print(f"self-test: FAIL {case.name}: expected {sorted(expected)}, got {sorted(actual)}", file=sys.stderr)
            for f in found:
                print(f"    {f}", file=sys.stderr)
            bad += 1
    if bad or not cases:
        print(f"check_obligations --self-test: FAIL ({bad} of {len(cases)})", file=sys.stderr)
        return 1
    print(f"check_obligations --self-test: OK ({len(cases)} fixtures)")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--self-test" in args:
        sys.exit(main_self_test())
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main_check(args[0]))
