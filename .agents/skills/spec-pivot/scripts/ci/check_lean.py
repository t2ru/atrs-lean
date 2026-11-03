#!/usr/bin/env python3
"""Lean ソースの静的検査（spec-pivot の道具。scripts/README.md）。

spec-pivot の lang/lean/rules.md（全域性と安全性）と spec/architecture.md（依存の向き）を、
コメントと文字列リテラルを除いたトークンで検査する。検査する Lean のルートと言語の組は、
リポジトリの `trace/project.json`（`lean.roots`・`languages`）から読む。

| 規則 | 失敗条件 |
| --- | --- |
| LEAN-SORRY  | `sorry`・`admit` がある（全層） |
| LEAN-AXIOM  | `axiom` 宣言がある（全層。公理の確認は `lake exe axiom-check` でも行う） |
| LEAN-DECIDE | `native_decide`・`bv_decide` が Tests の外にある |
| LEAN-FLOAT  | `Float`・`Float32` が Tests の外にある |
| LEAN-UNSAFE | `partial`・`unsafe`・`implemented_by`・`extern`・`panic!`・`get!`・`xs[i]!` が Trace/ConformanceKit/Tests/Tools の外にある |
| LEAN-IMPORT | 名前空間の依存の向きに反する import がある（移植元側と移植先側の相互依存を含む）。モデルの層は `Lean` を import してはならない（例外は、言語パックの式の構文のモジュール `LangSemantics.<Lang>.Expr`） |

使い方:
  uv run python -I <skill>/scripts/ci/check_lean.py              # trace/project.json の lean.roots を検査
  uv run python -I <skill>/scripts/ci/check_lean.py --self-test  # 違反例（scripts/ci/fixtures/lean）で検出できることを確かめる
"""
import json
import pathlib
import re
import sys

FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures" / "lean"

# スキルの assets にある言語パックの LangSemantics の層（言語の組に関わらず、すべて検査の対象）
KNOWN_LANGS = {"LangSemantics.Java", "LangSemantics.Sql", "LangSemantics.Rust"}
# 言語に依存しない補題（どの言語パックからも、移植元側・移植先側のどの層からも使ってよい）
CORE = "LangSemantics.Core"
ALL_LANGS = KNOWN_LANGS | {CORE}

EXTERNAL_FOR_MODELS = {"Init", "Std", "Batteries"}
EXTERNAL_FOR_META = EXTERNAL_FOR_MODELS | {"Lean", "Lake"}
META_LAYERS = {"Trace", "ConformanceKit", "Tests", "Tools"}
# 言語パックの式の構文だけを与えるモジュール（`LangSemantics.<Lang>.Expr`。lang/<lang>/semantics.md）。
# 構文を展開するために Lean のメタ層（`Lean`）を import してよい。展開した項は、その言語パックの原始関数だけからなる
SYNTAX_MODULE_RE = re.compile(r"^LangSemantics\.[A-Z]\w*\.Expr$")
MODEL_LAYERS = {"Machine", "Spec", "SourceModel", "Abstraction", "TargetModel", "Refinement", "LangSemantics"} | ALL_LANGS
ALL_LAYERS = MODEL_LAYERS | META_LAYERS

# 言語の組で決まる表（configure で設定する）
SOURCE_LANGS: set = set()
TARGET_LANGS: set = set()
ALLOWED: dict = {}
SOURCE_SIDE: set = set()
TARGET_SIDE: set = set()


def lang_layer(lang: str) -> str:
    """言語パックの名前（`java`）から LangSemantics の層（`LangSemantics.Java`）。"""
    return "LangSemantics." + lang[:1].upper() + lang[1:]


def configure(source: list, target: list) -> None:
    """言語の組（trace/project.json の languages）から、依存の向きの表を作る（spec/architecture.md#依存の向き）。"""
    global SOURCE_LANGS, TARGET_LANGS, ALLOWED, SOURCE_SIDE, TARGET_SIDE
    SOURCE_LANGS = {lang_layer(l) for l in source}
    TARGET_LANGS = {lang_layer(l) for l in target}
    unknown = (SOURCE_LANGS | TARGET_LANGS) - KNOWN_LANGS
    if unknown:
        sys.exit(f"check_lean: unknown language pack(s) {sorted(unknown)}")
    # 自分自身の層への依存は常に許す
    ALLOWED = {
        "Trace": set(),
        "ConformanceKit": set(ALL_LANGS),  # 適合テストベクタの実行器（メタ層）
        "Machine": set(),
        "Spec": {"Machine", "Trace"},
        "SourceModel": {"Spec", "Machine", "Trace", CORE} | SOURCE_LANGS,
        "Abstraction": {"SourceModel", "Spec", "Machine", "Trace", CORE} | SOURCE_LANGS,
        "TargetModel": {"Spec", "Machine", "Trace", CORE} | TARGET_LANGS,
        "Refinement": {"TargetModel", "Spec", "Machine", "Trace", CORE} | TARGET_LANGS,
        "LangSemantics": set(ALL_LANGS),  # 集約モジュール LangSemantics.lean
        "Tests": ALL_LAYERS,
        "Tools": ALL_LAYERS,
    }
    for l in KNOWN_LANGS:
        ALLOWED[l] = {"Trace", CORE}
    ALLOWED[CORE] = set()
    SOURCE_SIDE = {"SourceModel", "Abstraction"} | SOURCE_LANGS
    TARGET_SIDE = {"TargetModel", "Refinement"} | TARGET_LANGS


def find_repo() -> pathlib.Path:
    """`--repo <dir>` か、作業ディレクトリから上にたどって `trace/project.json` があるところ。"""
    if "--repo" in sys.argv:
        return pathlib.Path(sys.argv[sys.argv.index("--repo") + 1]).resolve()
    d = pathlib.Path.cwd().resolve()
    for c in (d, *d.parents):
        if (c / "trace" / "project.json").is_file():
            return c
    sys.exit("check_lean: repository root (trace/project.json) not found")


TOKEN_RULES = [
    ("LEAN-SORRY", re.compile(r"(?<![\w.'])(sorry|admit)(?![\w'!?])"), ALL_LAYERS),
    ("LEAN-AXIOM", re.compile(r"(?<![\w.'])axiom(?![\w'!?])"), ALL_LAYERS),
    ("LEAN-DECIDE", re.compile(r"(?<![\w.'])(native_decide|bv_decide)(?![\w'!?])"), ALL_LAYERS - {"Tests"}),
    ("LEAN-FLOAT", re.compile(r"(?<![\w'])Float(32)?(?![\w'!?])"), ALL_LAYERS - {"Tests"}),
    ("LEAN-UNSAFE",
     re.compile(r"(?<![\w.'])(partial|unsafe|implemented_by|extern)(?![\w'!?])|(?<![\w'])(panic|get)!|\]!"),
     ALL_LAYERS - META_LAYERS),
]


def layer_of(module: str):
    """モジュール名から層を決める。LangSemantics は言語まで含める。"""
    parts = module.split(".")
    root = parts[0]
    if root == "LangSemantics":
        return "LangSemantics" if len(parts) == 1 else f"LangSemantics.{parts[1]}"
    if root == "Test":  # スキルの assets の検査（Test.LangSemantics・Test.Machine・Test.ConformanceKit・Test.Trace）
        return "Tests"
    if root in ALL_LAYERS:
        return root
    return None


def strip(src: str) -> str:
    """コメント（入れ子の /- -/ を含む）と文字列・文字リテラルの中身を空白にする。改行は保つ。"""
    out = []
    i, n = 0, len(src)
    depth = 0

    def blank(s):
        return "".join(c if c == "\n" else " " for c in s)

    while i < n:
        c = src[i]
        if depth > 0:
            if src.startswith("/-", i):
                depth += 1
                out.append("  ")
                i += 2
            elif src.startswith("-/", i):
                depth -= 1
                out.append("  ")
                i += 2
            else:
                out.append(blank(c))
                i += 1
        elif src.startswith("/-", i):
            depth = 1
            out.append("  ")
            i += 2
        elif src.startswith("--", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(blank(src[i:j]))
            i = j
        elif c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append('"' + blank(src[i + 1:j]) + '"')
            i = j + 1
        elif c == "'" and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] in "_'.!?")):
            # 文字リテラル 'a' / '\n' / '\u{..}'（識別子の x' とは区別する）
            m = re.match(r"'(\\u\{[0-9a-fA-F]+\}|\\x[0-9a-fA-F]{2}|\\.|[^\\'])'", src[i:])
            if m:
                out.append("'" + blank(m.group(0)[1:-1]) + "'")
                i += len(m.group(0))
            else:
                out.append(c)
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


IMPORT_RE = re.compile(r"^\s*(?:public\s+|private\s+)?(?:meta\s+)?import\s+(?:all\s+)?([\w.«»]+)", re.M)


MISU_PENDING: set = set()


def check_file(path: pathlib.Path, module: str):
    """1 ファイルを検査し、(規則, 行, 説明) の一覧を返す。"""
    layer = layer_of(module)
    raw = path.read_text(encoding="utf-8")
    code = strip(raw)
    found = []
    if layer == "Spec":
        found += misu_violations(raw, code, module, MISU_PENDING)
    if layer is None:
        found.append(("LEAN-IMPORT", 1, f"module {module} is not in a known top-level namespace"))
        return found
    for rule, rx, layers in TOKEN_RULES:
        if layer not in layers:
            continue
        for m in rx.finditer(code):
            line = code.count("\n", 0, m.start()) + 1
            found.append((rule, line, f"`{m.group(0)}` is not allowed in {layer}"))
    for m in IMPORT_RE.finditer(code):
        target = m.group(1)
        line = code.count("\n", 0, m.start()) + 1
        root = target.split(".")[0]
        tl = layer_of(target)
        if tl is None:
            meta = layer in META_LAYERS or SYNTAX_MODULE_RE.match(module) is not None
            ext = EXTERNAL_FOR_META if meta else EXTERNAL_FOR_MODELS
            if root not in ext:
                found.append(("LEAN-IMPORT", line, f"{layer} must not import {target} (external package {root})"))
            continue
        if tl == layer or tl in ALLOWED.get(layer, set()):
            continue
        why = ""
        if (layer in SOURCE_SIDE and tl in TARGET_SIDE) or (layer in TARGET_SIDE and tl in SOURCE_SIDE):
            why = " (source side and target side must not depend on each other)"
        found.append(("LEAN-IMPORT", line, f"{layer} must not import {target} ({tl}){why}"))
    return found


STRUCT_RE = re.compile(r"^structure\s+([\w.]+)[^\n]*?\bwhere[ \t]*\n((?:[ \t]+[^\n]*\n|[ \t]*\n)*)", re.M)
FIELD_RE = re.compile(r"^[ \t]+(?!deriving\b)([\w']+)\s*:(?!=)\s*((?:(?!:=)[^\n])+?)\s*(?::=.*)?$", re.M)
PRED_RE = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:def|abbrev|structure)\s+([\w.]+)\.(WellFormed|Valid)\b", re.M)
RAWDECL_RE = re.compile(r"@\[[^\]]*\braw_input\b[^\]]*\]\s*(?:structure|inductive)\s+([\w.]+)")
RAW_RE = re.compile(r"@\[[^\]]*\braw_input\b[^\]]*\]\s*(?:/-[\s\S]*?-/\s*)?$")


def misu_violations(raw: str, code: str, module: str, pending: set):
    """MISU-1（spec-pivot の ADR bf1b）: `Spec` で、証明フィールドの無い単一の `String` を包む `structure` と、
    型の外の `T.WellFormed`・`T.Valid`。`@[raw_input "<理由>"]` を付けた型と、適用先の段階導入の一覧 `pending`
    （`trace/project.json` の `lean.misu_pending`。完全名）は除く。"""
    found = []
    ns = re.findall(r"^namespace\s+([\w.]+)", code, re.M)
    prefix = ns[0] + "." if ns else ""
    raw_types = set(RAWDECL_RE.findall(code))
    for m in STRUCT_RE.finditer(code):
        name = m.group(1)
        fields = [f for f in FIELD_RE.findall(m.group(2)) if not f[0].startswith("--")]
        if len(fields) != 1 or fields[0][1].strip() != "String":
            continue
        if name in raw_types or (prefix + name) in pending or name in pending:
            continue
        line = code.count("\n", 0, m.start()) + 1
        found.append(("MISU-1", line, f"structure {name} only wraps {fields[0][1].strip()} without a proof field "
                      "(add the invariant as a field, or mark a raw input with @[raw_input \"<reason>\"])"))
    for m in PRED_RE.finditer(code):
        name = m.group(1)
        # 生の型の妥当性の述語は、機械の PRE（ADR bf1b の規則 2・3）
        if name in raw_types or (prefix + name) in pending or name in pending:
            continue
        line = code.count("\n", 0, m.start()) + 1
        found.append(("MISU-1", line, f"{name}.{m.group(2)} is a predicate outside the type {name} "
                      "(make it a proof field, or list it in lean.misu_pending while it is staged)"))
    return found


def lean_files(root: pathlib.Path):
    for p in sorted(root.rglob("*.lean")):
        rel = p.relative_to(root)
        if rel.parts[0] == ".lake" or rel.name == "lakefile.lean":
            continue
        yield p, ".".join(rel.with_suffix("").parts)


def run(roots):
    results = {}
    for root in roots:
        for p, module in lean_files(root):
            results[p] = check_file(p, module)
    return results


def main_check() -> int:
    repo = find_repo()
    cfg = json.loads((repo / "trace" / "project.json").read_text(encoding="utf-8"))
    configure(cfg["languages"]["source"], cfg["languages"]["target"])
    roots = [repo / r for r in cfg["lean"]["roots"]]
    MISU_PENDING.update(cfg["lean"].get("misu_pending", {}).get("names", []))
    bad = 0
    nfiles = 0
    for p, found in run(roots).items():
        nfiles += 1
        for rule, line, msg in found:
            print(f"{p.relative_to(repo)}:{line}: {rule}: {msg}", file=sys.stderr)
            bad += 1
    if bad:
        print(f"check_lean: FAIL ({bad} violation(s))", file=sys.stderr)
        return 1
    print(f"check_lean: OK ({nfiles} files)")
    return 0


EXPECT_RE = re.compile(r"^-- expect:(.*)$", re.M)


def main_self_test() -> int:
    """各フィクスチャの先頭の `-- expect: RULE, …`（空なら違反なし）と、検出した規則の集合を比べる。
    フィクスチャは言語の組 Java・SQL → Rust で書いてある。"""
    configure(["java", "sql"], ["rust"])
    bad = 0
    n = 0
    for p, found in run([FIXTURES]).items():
        n += 1
        m = EXPECT_RE.search(p.read_text(encoding="utf-8"))
        if not m:
            print(f"self-test: {p.name}: missing `-- expect:` line", file=sys.stderr)
            bad += 1
            continue
        expected = {s.strip() for s in m.group(1).split(",") if s.strip()}
        actual = {r for r, _, _ in found}
        if expected != actual:
            print(f"self-test: FAIL {p.relative_to(FIXTURES)}: expected {sorted(expected)}, got {sorted(actual)}",
                  file=sys.stderr)
            for f in found:
                print(f"    {f}", file=sys.stderr)
            bad += 1
    if bad or n == 0:
        print(f"check_lean --self-test: FAIL ({bad} of {n})", file=sys.stderr)
        return 1
    print(f"check_lean --self-test: OK ({n} fixtures)")
    return 0


if __name__ == "__main__":
    sys.exit(main_self_test() if "--self-test" in sys.argv[1:] else main_check())
