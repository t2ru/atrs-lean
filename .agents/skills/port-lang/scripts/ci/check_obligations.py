#!/usr/bin/env python3
"""obligation-check の結果を文書と突き合わせる（TR-N と、TR-G の文書側。port-lang の道具。scripts/README.md）。

`lake exe obligation-check` の JSON（Lean 側の判定と事実）と、抽象化・具体化の課題一覧（`trace/project.json` の
`docs.abstraction`・`docs.refinement`）の
登録簿、`docs/backlog/` の状態を突き合わせる。既知差異とその影響の登録簿は Lean の `@[gap_entry]` にあり、
JSON の `gaps` から読む（references/docs/lang/lean/trace-attributes.md#ギャップの登録簿）。見出しの文字列は
references/docs/rules/spec-documents.md#道具が読む見出しと値 が定める。

| 規則 | 失敗条件 |
| --- | --- |
| OB-L   | Lean 側の判定に誤りがある（G0〜G9） |
| OB-DOC | 登録簿の節（Spec の非決定性・入口の R 課題・証明課題）が見つからない |
| OB-N1  | `@[nondet]` の ID が「Spec の非決定性」の表に無い。または同じ ID の `@[nondet]` が 2 つ以上ある |
| OB-N3  | 環境の選択に 自由 の行の型が、自由な選択に 環境 の行の型が使われている |
| OB-N2  | 表の N-NNN に対応する `@[nondet]` が無い（段階導入） |
| OB-R   | 文書で種類 R の課題 ID を持つ `@[obligation]` 定理が、`Refines` も義務の束 `Machine.Adequate` も結論に持たない |
| OB-A   | Lean にある R 課題（結論が `Refines`）に、同じ課題 ID の義務の束（結論が `Machine.Adequate`）が無い |
| OB-E1  | 「入口の R 課題」の R 課題に、環境の前提の `EnvWitness` を伴う `TotalUnder` が無い |
| OB-E2  | 「入口の R 課題」の R 課題が Lean に無い（段階導入） |
| OB-D1  | 前提型の差異に影響（「出力のみ」「中断」）が無い、または影響を持つ差異が前提型でない |
| OB-D2  | `@[deviation]` の ID が登録簿（`gaps`）に無い。または `restrict` に使われた差異が前提型でない |
| OB-S1  | 「出力のみ」の差異を `restrict` に使う R 課題に、その差異の `StateSafe`・`StateSafeConcrete` が無い |
| OB-S2  | 「出力のみ」の差異に `@[deviation]` がまだ無い（段階導入） |

段階導入（OB-N2・OB-E2・OB-S2）: 登録簿の各行の backlog の列にある項目が `done` でなければ警告、`done` なら失敗とする
（スキル port-lang の spec/traceability.md）。

使い方:
  python3 -I <skill>/scripts/ci/check_obligations.py <obligation-check の JSON>   # 本番の文書と突き合わせる
  python3 -I <skill>/scripts/ci/check_obligations.py --self-test                  # scripts/ci/fixtures/obligations の例で確かめる
"""
import json
import pathlib
import re
import sys

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
    for p in backlog_dir.glob("*.md"):
        text = p.read_text(encoding="utf-8")
        i = re.search(r'^id:\s*"?([0-9a-f-]+)"?\s*$', text, re.M)
        m = re.search(r"^state:\s*(\w+)", text, re.M)
        if i and m:
            states[i.group(1)] = m.group(1)
    return states


def parse_docs(abstraction_md: pathlib.Path, refinement_md: pathlib.Path, backlog_dir: pathlib.Path):
    abstraction = abstraction_md.read_text(encoding="utf-8")
    refinement = refinement_md.read_text(encoding="utf-8")
    docs = {"nondet": {}, "entries": {}, "impact": {}, "deviation_kind": {}, "r_tasks": set(),
            "backlog": backlog_states(backlog_dir)}
    for i, cells in section_rows(abstraction, "Spec の非決定性"):
        docs["nondet"][i] = {"kind": cells[0], "backlog": cells[-1]}
    for text, task_heading in ((abstraction, "証明課題"), (refinement, "REF:")):
        for i, cells in section_rows(text, "入口の R 課題"):
            docs["entries"][i] = cells[-1]
        for i, cells in section_rows(text, task_heading):
            if cells and cells[0] == "R":
                docs["r_tasks"].add(i)
    return docs


def staged(docs, backlog_id: str):
    """段階導入の重さ: backlog が done なら error、そうでなければ warning。"""
    return "error" if docs["backlog"].get(backlog_id) == "done" else "warning"


def gap_registry(report: dict, docs: dict):
    """report の `gaps`（Lean の登録簿）から、差異の種類と前提型の影響を docs に入れる。"""
    for g in report.get("gaps", []):
        docs["deviation_kind"][g["id"]] = g["kind_label"]
        if g.get("impact"):
            docs["impact"][g["id"]] = {"kind": g["impact"]["label"], "backlog": (g.get("backlog") or [""])[0]}


def check(report: dict, docs: dict):
    """(重さ, 規則, 内容) の列を返す。重さは "error" か "warning"。"""
    found = []
    gap_registry(report, docs)
    refinements = report.get("refinements", [])
    for e in report.get("errors", []):
        found.append(("error", "OB-L", e))
    # 証明の状態が未証明（pending）の差異の G9。段階導入の判定は trace check（TR-K）が行う
    for w in report.get("warnings", []):
        found.append(("warning", "OB-L", w))
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
            if i in docs["r_tasks"] and not ob["refines"] and not ob.get("adequate"):
                found.append(("error", "OB-R", f"{i} ({ob['name']}) is an R task but its conclusion is not Refines"))
    # 義務の束（R 課題ごとに、同じ ID の Machine.Adequate）
    bundled = {i for ob in report.get("obligations", []) if ob.get("adequate") for i in ob["ids"]}
    for ob in refinements:
        for i in ob["ids"]:
            if i not in bundled:
                found.append(("error", "OB-A", f"{i} ({ob['name']}) has no Machine.Adequate bundle with the same ID"))
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
                found.append(("error", "OB-D2", f"@[deviation \"{i}\"] ({name}) has no @[gap_entry] in the registry"))
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


def run(report: dict, abstraction_md: pathlib.Path, refinement_md: pathlib.Path, backlog_dir: pathlib.Path):
    try:
        docs = parse_docs(abstraction_md, refinement_md, backlog_dir)
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


def find_repo() -> pathlib.Path:
    """`--repo <dir>` か、作業ディレクトリから上にたどって `trace/project.json` があるところ。"""
    if "--repo" in sys.argv:
        i = sys.argv.index("--repo")
        root = pathlib.Path(sys.argv[i + 1]).resolve()
        del sys.argv[i:i + 2]
        return root
    d = pathlib.Path.cwd().resolve()
    for c in (d, *d.parents):
        if (c / "trace" / "project.json").is_file():
            return c
    sys.exit("check_obligations: repository root (trace/project.json) not found")


def main_check(path: str, repo: pathlib.Path) -> int:
    report = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    docs = json.loads((repo / "trace" / "project.json").read_text(encoding="utf-8"))["docs"]
    found = run(report, repo / docs["abstraction"], repo / docs["refinement"], repo / docs["backlog"])
    return report_and_exit(found, "check_obligations")


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
        found = run(report, case / "abstraction.md", case / "refinement.md", case / "backlog")
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
    if "--self-test" in sys.argv[1:]:
        sys.exit(main_self_test())
    repo = find_repo()
    args = sys.argv[1:]
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main_check(args[0], repo))
