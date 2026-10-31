#!/usr/bin/env python3
"""obligation-check の結果を文書と突き合わせる（TR-N と、TR-G の文書側。ADR 0039）。

`lake exe obligation-check` の JSON（Lean 側の判定と事実）と、`docs/spec/abstraction.md`・`refinement.md` の
登録簿、`docs/backlog/` の状態を突き合わせる。

| 規則 | 失敗条件 |
| --- | --- |
| OB-L   | Lean 側の判定に誤りがある（G0〜G9） |
| OB-DOC | 登録簿の節（Spec の非決定性・入口の R 課題・前提型の差異の影響・既知差異・証明課題）が見つからない |
| OB-N1  | `@[nondet]` の ID が「Spec の非決定性」の表に無い。または同じ ID の `@[nondet]` が 2 つ以上ある |
| OB-N3  | 環境の選択に 自由 の行の型が、自由な選択に 環境 の行の型が使われている |
| OB-N2  | 表の N-NNN に対応する `@[nondet]` が無い（段階導入） |
| OB-R   | 文書で種類 R の課題 ID を持つ `@[obligation]` 定理が、`Refines` を結論に持たない |
| OB-E1  | 「入口の R 課題」の R 課題に、環境の前提の `EnvWitness` を伴う `TotalUnder` が無い |
| OB-E2  | 「入口の R 課題」の R 課題が Lean に無い（段階導入） |
| OB-D1  | 前提型の差異が「前提型の差異の影響」の表に無い、影響が「出力のみ」「中断」でない、または表の ID が前提型でない |
| OB-D2  | `@[deviation]` の ID が既知差異の表に無い。または `restrict` に使われた差異が前提型でない |
| OB-S1  | 「出力のみ」の差異を `restrict` に使う R 課題に、その差異の `StateSafe`・`StateSafeConcrete` が無い |
| OB-S2  | 「出力のみ」の差異に `@[deviation]` がまだ無い（段階導入） |

段階導入（OB-N2・OB-E2・OB-S2）: 登録簿の各行の backlog の列にある項目が `done` でなければ警告、`done` なら失敗とする
（スキル port-lang の traceability.md、ADR 0039）。

使い方:
  python3 -I tools/ci/check_obligations.py <obligation-check の JSON>   # 本番の文書と突き合わせる
  python3 -I tools/ci/check_obligations.py --self-test                  # tools/ci/fixtures/obligations の例で確かめる
"""
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
DOCS = REPO / "docs"
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures" / "obligations"

ID_CELL = re.compile(r"^\|\s*`?([A-Z]+-\d{3})`?\s*\|(.*)$")
IMPACTS = {"出力のみ", "中断"}
CHOICE_KINDS = {"環境", "自由"}


class DocError(Exception):
    pass


def section_rows(text: str, heading: str, required: bool = True, own_only: bool = False):
    """見出し `heading` で始まる節（次の同じ深さ以上の見出しまで。`own_only` なら次の見出しまで）の表の行を、
    (ID, 残りのセル) で返す。"""
    out = []
    level = None
    found = False
    for line in text.splitlines():
        m = re.match(r"^(#+)\s+(.*)$", line)
        if m:
            if level is not None and (own_only or len(m.group(1)) <= level):
                break
            if level is None and m.group(2).strip().startswith(heading):
                level = len(m.group(1))
                found = True
            continue
        if level is None:
            continue
        r = ID_CELL.match(line)
        if r:
            cells = [c.strip() for c in r.group(2).split("|")]
            if cells and cells[-1] == "":
                cells = cells[:-1]
            out.append((r.group(1), cells))
    if required and not found:
        raise DocError(f"section {heading!r} not found")
    return out


def backlog_states(backlog_dir: pathlib.Path):
    states = {}
    if not backlog_dir.is_dir():
        return states
    for p in backlog_dir.glob("[0-9][0-9][0-9][0-9]-*.md"):
        text = p.read_text(encoding="utf-8")
        m = re.search(r"^state:\s*(\w+)", text, re.M)
        if m:
            states[p.name[:4]] = m.group(1)
    return states


def parse_docs(spec_dir: pathlib.Path, backlog_dir: pathlib.Path):
    abstraction = (spec_dir / "abstraction.md").read_text(encoding="utf-8")
    refinement = (spec_dir / "refinement.md").read_text(encoding="utf-8")
    docs = {"nondet": {}, "entries": {}, "impact": {}, "deviation_kind": {}, "r_tasks": set(),
            "backlog": backlog_states(backlog_dir)}
    for i, cells in section_rows(abstraction, "Spec の非決定性"):
        docs["nondet"][i] = {"kind": cells[0], "backlog": cells[-1]}
    for text, task_heading in ((abstraction, "証明課題"), (refinement, "REF:")):
        for i, cells in section_rows(text, "入口の R 課題"):
            docs["entries"][i] = cells[-1]
        for i, cells in section_rows(text, "前提型の差異の影響"):
            docs["impact"][i] = {"kind": cells[0], "backlog": cells[-1]}
        for i, cells in section_rows(text, "既知差異", own_only=True):
            if re.match(r"^[DT]-\d{3}$", i):
                docs["deviation_kind"][i] = cells[0]
        for i, cells in section_rows(text, task_heading):
            if cells and cells[0] == "R":
                docs["r_tasks"].add(i)
    return docs


def staged(docs, backlog_id: str):
    """段階導入の重さ: backlog が done なら error、そうでなければ warning。"""
    return "error" if docs["backlog"].get(backlog_id) == "done" else "warning"


def check(report: dict, docs: dict):
    """(重さ, 規則, 内容) の列を返す。重さは "error" か "warning"。"""
    found = []
    refinements = report.get("refinements", [])
    for e in report.get("errors", []):
        found.append(("error", "OB-L", e))
    for ob in refinements:
        for e in ob.get("errors", []):
            found.append(("error", "OB-L", f"{ob['name']}: {e}"))
    # TR-N
    nondet_by_name = {d["name"]: d["ids"] for d in report.get("nondet", [])}
    seen_ids = {}
    for name, ids in nondet_by_name.items():
        for i in ids:
            if i in seen_ids:
                found.append(("error", "OB-N1", f"{i} is used by both {seen_ids[i]} and {name}"))
            seen_ids[i] = name
            if i not in docs["nondet"]:
                found.append(("error", "OB-N1", f"@[nondet \"{i}\"] ({name}) is not in the N-NNN table"))
    for ob in refinements:
        for field, want in (("env_choices", "環境"), ("free_choices", "自由")):
            for leaf in ob.get(field, []):
                for i in nondet_by_name.get(leaf, []):
                    kind = docs["nondet"].get(i, {}).get("kind")
                    if kind in CHOICE_KINDS and kind != want:
                        found.append(("error", "OB-N3",
                                      f"{ob['name']}: {leaf} ({i}, {kind}) is used as a {want} choice"))
    for i, row in sorted(docs["nondet"].items()):
        if row["kind"] not in CHOICE_KINDS:
            found.append(("error", "OB-DOC", f"{i}: kind {row['kind']!r} is not one of {sorted(CHOICE_KINDS)}"))
        if i not in seen_ids:
            found.append((staged(docs, row["backlog"]), "OB-N2", f"{i} has no @[nondet] yet (backlog {row['backlog']})"))
    # R 課題の形
    for ob in report.get("obligations", []):
        for i in ob["ids"]:
            if i in docs["r_tasks"] and not ob["refines"]:
                found.append(("error", "OB-R", f"{i} ({ob['name']}) is an R task but its conclusion is not Refines"))
    # 入口の全域性
    seen = set()
    for ob in refinements:
        for i in ob["ids"]:
            if i in docs["entries"]:
                seen.add(i)
                if not any(t.get("witness") for t in ob.get("total_under", [])):
                    found.append(("error", "OB-E1",
                                  f"{i} ({ob['name']}): no TotalUnder with an EnvWitness for {ob.get('abstract_base')}"))
    for i, b in sorted(docs["entries"].items()):
        if i not in seen:
            found.append((staged(docs, b), "OB-E2", f"entry obligation {i} has no Lean theorem yet (backlog {b})"))
    # 前提型の差異の影響と、差異の種類
    pre_type = {i for i, k in docs["deviation_kind"].items() if k.startswith("前提型")}
    for i in sorted(pre_type):
        row = docs["impact"].get(i)
        if row is None or row["kind"] not in IMPACTS:
            found.append(("error", "OB-D1", f"{i}: impact is {row and row['kind']!r}; expected one of {sorted(IMPACTS)}"))
    for i in sorted(set(docs["impact"]) - pre_type):
        found.append(("error", "OB-D1", f"{i}: has an impact row but is not 前提型"))
    dev_by_name = {d["name"]: d["ids"] for d in report.get("deviation", [])}
    for name, ids in dev_by_name.items():
        for i in ids:
            if i not in docs["deviation_kind"]:
                found.append(("error", "OB-D2", f"@[deviation \"{i}\"] ({name}) is not in the known-difference table"))
    for ob in refinements:
        for d in ob.get("deviations", []):
            for i in dev_by_name.get(d, []):
                if i in docs["deviation_kind"] and i not in pre_type:
                    found.append(("error", "OB-D2", f"{ob['name']}: {d} ({i}) is used in restrict but is not 前提型"))
    # 出力のみの差異の状態の安全性
    for i, row in sorted(docs["impact"].items()):
        if row["kind"] != "出力のみ":
            continue
        consts = [n for n, ids in dev_by_name.items() if i in ids]
        if not consts:
            found.append((staged(docs, row["backlog"]), "OB-S2",
                          f"{i} (出力のみ) has no @[deviation] yet (backlog {row['backlog']})"))
        for ob in refinements:
            for c in consts:
                if c in ob.get("deviations", []) and c not in ob.get("state_safe", []):
                    found.append(("error", "OB-S1", f"{i} (出力のみ): {ob['name']} has no StateSafe for {c}"))
    return found


def run(report: dict, spec_dir: pathlib.Path, backlog_dir: pathlib.Path):
    try:
        docs = parse_docs(spec_dir, backlog_dir)
    except DocError as e:
        return [("error", "OB-DOC", str(e))]
    return check(report, docs)


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
    return report_and_exit(run(report, DOCS / "spec", DOCS / "backlog"), "check_obligations")


def read_set(path: pathlib.Path):
    if not path.exists():
        return set()
    return {s.strip() for s in path.read_text(encoding="utf-8").split(",") if s.strip()}


def main_self_test() -> int:
    """各フィクスチャ（ディレクトリ）の `expect.txt`（失敗の規則）と `expect-warnings.txt`（警告の規則）を、
    検出した規則と比べる。どちらも空なら、失敗・警告が無いことを期待する。"""
    bad = 0
    cases = sorted(p for p in FIXTURES.iterdir() if p.is_dir())
    for case in cases:
        report = json.loads((case / "report.json").read_text(encoding="utf-8"))
        found = run(report, case, case / "backlog")
        for sev, fname in (("error", "expect.txt"), ("warning", "expect-warnings.txt")):
            expected = read_set(case / fname)
            actual = {rule for s, rule, _ in found if s == sev}
            if expected != actual:
                print(f"self-test: FAIL {case.name} ({sev}): expected {sorted(expected)}, got {sorted(actual)}",
                      file=sys.stderr)
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
