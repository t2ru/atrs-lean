"""`Spec` のモジュール文書から、仕様の本（HTML）を作る（spec-pivot の道具。references/docs/spec/spec-book.md）。

業務仕様の散文は、`Spec` の各モジュールのモジュール文書（列 0 から始まる `/-! … -/`）に、定義のすぐ前に書く。
この道具は、それを mdgen（Lean のファイルを Markdown にする。`assets/mdgen`）で Markdown にし、mdbook で HTML にする。
プロジェクト固有の値は `trace/project.json` の `book` から読む。

  uv run python -I <skill>/scripts/book/build.py            # 本を作る（<out>/html/index.html）
  uv run python -I <skill>/scripts/book/build.py --check    # 仕様への参照の行き先を検査する（HTML は作らない）
  uv run python -I <skill>/scripts/book/build.py --self-test

`book` の欄:

- `title`: 本の題。`language`: 本の言語（既定 `en`）
- `roots`: 本にする Lean のファイル・ディレクトリ（リポジトリ相対）。最初のものの親ディレクトリを基点とし、基点からの
  相対パスで本のページを置く（`lean/Spec/Fare.lean` → `Spec/Fare.md`）
- `entry`: 目次の順を決めるモジュール（例 `lean/Spec.lean`）。その import を先頭から深さ優先でたどった順に、
  モジュール名の階層で並べる。たどれないモジュールは末尾に名前の順で置く
- `out`: 出力のディレクトリ（生成物。`<out>/src` に Markdown、`<out>/html` に HTML）
- `repo_url`: 本の外（roots の外）のファイルへのリンクの基点（例 `https://github.com/<owner>/<repo>/blob/main`）
- `refs`: `--check` が行き先を検査する参照。`manifest`（`trace/manifest.json` の `spec_doc` の行き先）と
  `vectors`（適合テストベクタの `specRef` を探すディレクトリ）
- `okf_check`: 見出しのアンカーの規則を借りる、スキル okf-bundle の `okf_check.py` のパス

本の中のリンク: Lean のファイルの中のリンクは、そのファイルから見た相対パスで書く（エディタや GitHub でも辿れる）。
この道具は、roots の中の `.lean` を指すリンクを本のページへのリンクに、roots の外を指すリンクを `repo_url` の URL に替える。
"""

import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parents[1]
MDGEN_PKG = SKILL / "assets" / "mdgen"


def find_repo(argv):
    if "--repo" in argv:
        return Path(argv[argv.index("--repo") + 1]).resolve()
    p = Path.cwd().resolve()
    for d in [p, *p.parents]:
        if (d / "trace" / "project.json").is_file():
            return d
    sys.exit("trace/project.json not found (run in the project repository or pass --repo)")


def load_okf(repo, cfg):
    path = repo / cfg.get("okf_check", ".agents/skills/okf-bundle/scripts/okf_check.py")
    spec = importlib.util.spec_from_file_location("okf_check", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------- 目次

IMPORT_RE = re.compile(r"^import\s+(.+)$")


def module_of(rel, base):
    """`lean/Spec/Fare.lean` → `Spec.Fare`（base は `lean`）。"""
    return os.path.relpath(rel, base)[:-len(".lean")].replace(os.sep, ".")


def imports(text):
    """ファイルの先頭の `import` の列（コメントと空行は飛ばし、最初のそれ以外の行で止める）。"""
    out = []
    for line in text.split("\n"):
        if not line.strip() or line.startswith("--"):
            continue
        m = IMPORT_RE.match(line)
        if not m:
            break
        out += m.group(1).split()
    return out


def order_modules(mods, entry, read):
    """mods（モジュール名の集合）を並べる。entry を先頭に、entry が直接 import するモジュールをその順に置き、
    他は entry から import を深さ優先でたどった順に、その後に置く（目次では名前の階層の親の下に入る）。"""
    dfs = _dfs(mods, entry, read)
    direct = [m for m in imports(read(entry)) if m in mods]
    rank = {m: k for k, m in enumerate([entry] + direct)}
    return sorted(dfs, key=lambda m: (rank.get(m, len(rank)), dfs.index(m)))


def _dfs(mods, entry, read):
    seen, out = set(), []

    def visit(m):
        if m in seen or m not in mods:
            return
        seen.add(m)
        out.append(m)
        for i in imports(read(m)):
            visit(i)

    visit(entry)
    return out + sorted(mods - seen)


def tree_lines(mods, titles, top=None, depth=0):
    """mods をモジュール名の階層の入れ子の箇条書きにした行の列。並びは mods の順（各階層で最初に現れた順）。
    モジュールの無い中間の名前（例 `SourceModel.Domain`）は、すぐ下の名前が 2 つ以上あれば、ページの無い見出し
    （mdbook の draft chapter `- [Domain]()`）にし、1 つなら畳む（`A.B` のように続けて示す）。題がモジュール名そのものの章は、親から見た相対の名前で示す。"""
    mset = set(mods)
    prefix = (top + ".") if top else ""
    # 名前の木: ノード = 名前の成分の列（top からの相対）
    order, kids = [], {}
    for m in mods:
        rel = m[len(prefix):].split(".") if m.startswith(prefix) else m.split(".")
        for k in range(1, len(rel) + 1):
            node, par = tuple(rel[:k]), tuple(rel[:k - 1])
            if node not in kids:
                kids[node] = []
                kids.setdefault(par, []).append(node)
    full = lambda node: prefix + ".".join(node)

    lines = []

    def emit(node, d, shown):
        name = full(node)
        if name in mset or len(kids.get(node, [])) >= 2:
            label = name[len(shown) + 1:] if shown and name.startswith(shown + ".") else name
            if name in mset:
                t = titles[name]
                lines.append(f"{'  ' * d}- [{label if t == name else t}]({name.replace('.', '/')}.md)")
            else:
                lines.append(f"{'  ' * d}- [{label}]()")
            for c in kids.get(node, []):
                emit(c, d + 1, name)
        else:
            for c in kids.get(node, []):
                emit(c, d, shown)

    for c in kids.get((), []):
        emit(c, depth, top or "")
    return lines


def summary(mods, titles, entry):
    """SUMMARY.md の本文（部の無い本）。entry を前書き、他をモジュール名の階層の入れ子で並べる。"""
    lines = ["# Summary", "", f"[{titles[entry]}]({entry.replace('.', '/')}.md)", ""]
    lines += tree_lines([m for m in mods if m != entry], titles, entry)
    return "\n".join(lines) + "\n"


def title_of(md_text, default):
    for line in md_text.split("\n"):
        m = re.match(r"^#\s+(.*?)\s*$", line)
        if m:
            return m.group(1).replace("`", "").replace("[", "").replace("]", "")
    return default


# ---------------------------------------------------------------- リンク

def rewrite_links(okf, md_text, src_rel, page_rel, pages, repo_url, repo):
    """mdgen の出力の Markdown のリンクを、本のページか repo_url の URL に替える。
    src_rel は元の Lean のファイル（リポジトリ相対）、page_rel は本のページ（src からの相対）、
    pages は本に入れた Lean のファイル（リポジトリ相対）→ ページ の対応。"""
    lines = md_text.split("\n")
    masked = okf.mask_code(lines)
    out = []
    for raw, mline in zip(lines, masked):
        spans = []
        for m in okf.LINK_RE.finditer(mline):
            target = raw[m.start(3):m.end(3)]
            if target.startswith("<") or re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) or target.startswith("#"):
                continue
            path, _, frag = target.partition("#")
            dest = os.path.normpath(os.path.join(os.path.dirname(src_rel), path))
            if dest in pages:
                new = os.path.relpath(pages[dest], os.path.dirname(page_rel) or ".").replace(os.sep, "/")
            elif dest.startswith(".."):
                continue
            else:
                kind = "tree" if (repo / dest).is_dir() else "blob"
                new = f"{repo_url.rstrip('/')}/{dest}" if kind == "blob" else f"{repo_url.rstrip('/').replace('/blob/', '/tree/')}/{dest}"
            spans.append((m.start(3), m.end(3), new + ("#" + frag if frag else "")))
        for s, e, t in reversed(spans):
            raw = raw[:s] + t + raw[e:]
        out.append(raw)
    return "\n".join(out)


# ---------------------------------------------------------------- 本を作る

def root_files(repo, roots):
    out = []
    for r in roots:
        p = repo / r
        if p.is_file():
            out.append(r)
        else:
            for f in sorted(p.rglob("*.lean")):
                out.append(f.relative_to(repo).as_posix())
    return out


def mdgen(src_dir, out_dir):
    exe = os.environ.get("MDGEN")
    if exe:
        cmd = [exe, str(src_dir), str(out_dir)]
    else:
        cmd = ["lake", "-d", str(MDGEN_PKG), "exe", "mdgen", str(src_dir), str(out_dir)]
    subprocess.run(cmd, check=True)


def parts_of(repo, cfg):
    """[(部の題か None, base, [(モジュール, 入口のファイルか None, [ファイル])])]。
    `parts` が無ければ、`roots`・`entry` を題の無い 1 部とする（入口のモジュールを 1 つの単位にする）。"""
    out = []
    if "parts" in cfg:
        for part in cfg["parts"]:
            base = part["base"].rstrip("/")
            units = []
            for m in part["modules"]:
                path = m.replace(".", "/")
                entry = f"{base}/{path}.lean"
                files = ([entry] if (repo / entry).is_file() else []) + \
                    (root_files(repo, [f"{base}/{path}"]) if (repo / base / path).is_dir() else [])
                if not files:
                    sys.exit(f"book: module {m} not found under {base}")
                units.append((m, entry if (repo / entry).is_file() else None, files))
            out.append((part.get("title"), base, units))
    else:
        roots = cfg["roots"]
        base = os.path.dirname(roots[0].rstrip("/"))
        files = root_files(repo, roots)
        entry = cfg.get("entry")
        out.append((None, base, [(module_of(entry, base) if entry else "", entry, files)]))
    return out


def page_of(f, base):
    return os.path.relpath(f, base)[:-len(".lean")] + ".md"


def unit_modules(mod, entry, files, base, texts):
    """1 つの単位（入口のモジュールとその下）のモジュールの並び。入口が無ければ名前の順。"""
    mods = {module_of(f, base) for f in files}
    if entry is None:
        return sorted(mods)
    return order_modules(mods, module_of(entry, base), lambda m: texts.get(m, ""))


def summary_parts(book_title, parts, titles):
    """SUMMARY.md の本文。前書き index.md と、部（`# <部の題>`）ごとの章。
    parts は [(部の題か None, [(入口のモジュールか None, [入口の他のモジュール])])]。入口を章にし、他をその下に入れ子で置く。"""
    lines = ["# Summary", "", f"[{book_title}](index.md)", ""]
    for title, units in parts:
        if title:
            lines += [f"# {title}", ""]
        for entry, mods in units:
            if entry:
                lines.append(f"- [{titles[entry]}]({entry.replace('.', '/')}.md)")
                lines += tree_lines(mods, titles, entry, 1)
            else:
                lines += tree_lines(mods, titles)
        lines.append("")
    return "\n".join(lines)


def index_page(book_title, parts, titles):
    lines = [f"# {book_title}", ""]
    for title, units in parts:
        heads = "、".join(f"[{titles[e]}]({e.replace('.', '/')}.md)" for e, _ in units if e)
        lines.append(f"- {title or ''}" + (f": {heads}" if heads else ""))
    return "\n".join(lines) + "\n"


def build(repo, cfg, okf):
    parts = parts_of(repo, cfg)
    out = repo / cfg.get("out", "build/book")
    src = out / "src"
    if src.exists():
        shutil.rmtree(src)
    pages = {}
    for _, base, units in parts:
        for _, _, files in units:
            for f in files:
                pg = page_of(f, base)
                if pg in pages.values():
                    sys.exit(f"book: two files map to the page {pg}")
                pages[f] = pg
    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp) / "stage"
        for f, pg in pages.items():
            dst = stage / (pg[:-len(".md")] + ".lean")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(repo / f, dst)
        mdgen(stage.resolve(), src.resolve())
    texts, titles = {}, {}
    for f, pg in pages.items():
        p = src / pg
        text = rewrite_links(okf, p.read_text(encoding="utf-8"), f, pg, pages, cfg["repo_url"], repo)
        p.write_text(text, encoding="utf-8")
        mod = pg[:-len(".md")].replace("/", ".")
        texts[mod] = (repo / f).read_text(encoding="utf-8")
        titles[mod] = title_of(text, mod)
    book_title = cfg.get("title", "Spec")
    plan = []
    for title, base, units in parts:
        us = []
        for m, entry, files in units:
            mods = unit_modules(m, entry, files, base, texts)
            e = module_of(entry, base) if entry else None
            us.append((e, [x for x in mods if x != e]))
        plan.append((title, us))
    (src / "index.md").write_text(index_page(book_title, plan, titles), encoding="utf-8")
    (src / "SUMMARY.md").write_text(summary_parts(book_title, plan, titles), encoding="utf-8")
    repo_root_url = re.sub(r"/blob/.*$", "", cfg["repo_url"])
    (out / "book.toml").write_text(
        "[book]\n"
        f"title = {json.dumps(book_title, ensure_ascii=False)}\n"
        f"language = {json.dumps(cfg.get('language', 'en'))}\n"
        'src = "src"\n\n'
        "[build]\n"
        'build-dir = "html"\n'
        "create-missing = false\n\n"
        "[output.html]\n"
        f"git-repository-url = {json.dumps(repo_root_url)}\n",
        encoding="utf-8")
    subprocess.run(["mdbook", "build", str(out)], check=True)
    print(f"book: {out / 'html' / 'index.html'} ({len(pages)} page(s), {len(parts)} part(s))")
    return 0


# ---------------------------------------------------------------- 参照の検査

def refs_of(repo, cfg):
    """[(出所, 行き先)]。trace/manifest.json の spec_doc と、ベクタの specRef。"""
    out = []
    r = cfg.get("refs", {})
    man = repo / r.get("manifest", "trace/manifest.json")
    if man.is_file():
        data = json.loads(man.read_text(encoding="utf-8"))

        def walk(x, where):
            if isinstance(x, dict):
                if x.get("type") == "spec_doc" and isinstance(x.get("to"), str):
                    out.append((where, x["to"]))
                for k, v in x.items():
                    walk(v, x.get("name", where) if isinstance(x.get("name"), str) else where)
            elif isinstance(x, list):
                for v in x:
                    walk(v, where)

        walk(data, man.relative_to(repo).as_posix())
    vec = r.get("vectors")
    if vec:
        for p in sorted((repo / vec).rglob("*.json")):
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if isinstance(data, dict) and isinstance(data.get("specRef"), str):
                out.append((p.relative_to(repo).as_posix(), data["specRef"]))
    return out


def check(repo, cfg, okf):
    errs = 0
    cache = {}
    refs = refs_of(repo, cfg)
    for where, to in refs:
        path, _, frag = to.partition("#")
        p = repo / path
        if not p.is_file():
            print(f"error: {where}: {to}: {path} does not exist")
            errs += 1
            continue
        if not frag:
            continue
        if path not in cache:
            text = p.read_text(encoding="utf-8")
            if path.endswith(".md"):
                _, body, _ = okf.split_frontmatter(text)
                cache[path] = okf.anchors(body.split("\n"))
            else:
                cache[path] = okf.anchors(okf.lean_doc_lines(text.split("\n")))
        if frag not in cache[path]:
            print(f"error: {where}: {to}: #{frag} is not a heading of {path}")
            errs += 1
    print(f"book check: {'NG' if errs else 'OK'} ({len(refs)} reference(s), {errs} error(s))")
    return 1 if errs else 0


# ---------------------------------------------------------------- 自己テスト

def self_test(okf):
    fails = 0

    def eq(name, got, want):
        nonlocal fails
        if got != want:
            print(f"self-test: {name}: got {got!r}, want {want!r}")
            fails += 1

    texts = {
        "Spec": "import Trace\nimport Spec.Glossary\nimport Spec.Prim\nimport Spec.Fare\n",
        "Spec.Glossary": "/-! # 用語集 -/\n",
        "Spec.Prim": "import Spec.Prim.Int\nimport Spec.Prim.Date\n",
        "Spec.Prim.Int": "",
        "Spec.Prim.Date": "import Spec.Prim.Int\n",
        "Spec.Fare": "import Spec.Prim\nimport Spec.Seed.Flight\n",
        "Spec.Seed.Flight": "",
        "Spec.Orphan": "",
    }
    mods = order_modules(set(texts), "Spec", lambda m: texts[m])
    eq("order", mods, ["Spec", "Spec.Glossary", "Spec.Prim", "Spec.Fare", "Spec.Prim.Int", "Spec.Prim.Date",
                       "Spec.Seed.Flight", "Spec.Orphan"])
    titles = {m: m for m in mods}
    eq("summary", summary(mods, titles, "Spec").split("\n")[2:], [
        "[Spec](Spec.md)", "",
        "- [Glossary](Spec/Glossary.md)",
        "- [Prim](Spec/Prim.md)",
        "  - [Int](Spec/Prim/Int.md)",
        "  - [Date](Spec/Prim/Date.md)",
        "- [Fare](Spec/Fare.md)",
        "- [Seed.Flight](Spec/Seed/Flight.md)",
        "- [Orphan](Spec/Orphan.md)", ""])
    eq("title", title_of("```lean\nx\n```\n# 運賃計算（`Spec.Fare`）\n", "Spec.Fare"), "運賃計算（Spec.Fare）")
    A = ".agents/skills/x/assets/lean"
    roots = {"lean/Spec.lean": "Spec.md", "lean/Spec/Fare.lean": "Spec/Fare.md", "lean/Spec/Prim/Int.lean": "Spec/Prim/Int.md",
             f"{A}/Machine/Kernel.lean": "Machine/Kernel.md"}
    md = ("[a](Prim/Int.lean#floor) [b](../../docs/x.md#y) [c](#here) [d](https://e.x/) `[e](Fare.lean)`\n"
          "```lean\n[f](Fare.lean)\n```\n[g](../Spec.lean)")
    got = rewrite_links(okf, md, "lean/Spec/Fare.lean", "Spec/Fare.md", roots, "https://h/r/blob/main", Path("/nonexistent"))
    eq("links", got.split("\n"), [
        "[a](Prim/Int.md#floor) [b](https://h/r/blob/main/docs/x.md#y) [c](#here) [d](https://e.x/) `[e](Fare.lean)`",
        "```lean", "[f](Fare.lean)", "```", "[g](../Spec.md)"])
    got = rewrite_links(okf, "[a](../Fare.lean)", "lean/Spec/Prim/Int.lean", "Spec/Prim/Int.md", roots, "https://h/r/blob/main", Path("/nonexistent"))
    eq("links-nested", got, "[a](../Fare.md)")
    # 部をまたぐリンク（別の base の Lean のファイル）も本のページへ
    got = rewrite_links(okf, "[k](../../.agents/skills/x/assets/lean/Machine/Kernel.lean#k)", "lean/Spec/Fare.lean", "Spec/Fare.md",
                        roots, "https://h/r/blob/main", Path("/nonexistent"))
    eq("links-cross-part", got, "[k](../Machine/Kernel.md#k)")
    titles = {m: m for m in ["Spec", "Spec.Fare", "Spec.Prim", "Spec.Prim.Int", "Tools.A", "Tools.B"]}
    got = summary_parts("Book", [("仕様", [("Spec", ["Spec.Prim", "Spec.Fare", "Spec.Prim.Int"])]),
                                 ("道具", [(None, ["Tools.A", "Tools.B"])])], titles)
    eq("summary-parts", got.split("\n"), [
        "# Summary", "", "[Book](index.md)", "",
        "# 仕様", "",
        "- [Spec](Spec.md)",
        "  - [Prim](Spec/Prim.md)",
        "    - [Int](Spec/Prim/Int.md)",
        "  - [Fare](Spec/Fare.md)", "",
        "# 道具", "",
        "- [Tools]()",
        "  - [A](Tools/A.md)",
        "  - [B](Tools/B.md)", ""])
    # 題がモジュール名でない章は題で示し、中間の名前が 1 つの下にしか無ければ畳む
    t2 = {"S": "S", "S.A.B.C": "S.A.B.C", "S.A.B.D": "題 D", "S.X.Y": "S.X.Y"}
    eq("tree-groups", tree_lines(["S.A.B.C", "S.A.B.D", "S.X.Y"], t2, "S"), [
        "- [A.B]()", "  - [C](S/A/B/C.md)", "  - [題 D](S/A/B/D.md)", "- [X.Y](S/X/Y.md)"])
    print(f"book self-test: {'NG' if fails else 'OK'} ({fails} failure(s))")
    return 1 if fails else 0


def main(argv):
    repo = find_repo(argv) if "--self-test" not in argv else None
    if repo is None:
        here_repo = find_repo([])
        okf = load_okf(here_repo, json.loads((here_repo / "trace/project.json").read_text(encoding="utf-8")).get("book", {}))
        return self_test(okf)
    cfg = json.loads((repo / "trace/project.json").read_text(encoding="utf-8")).get("book")
    if not cfg:
        sys.exit("trace/project.json has no `book`")
    okf = load_okf(repo, cfg)
    if "--check" in argv:
        return check(repo, cfg, okf)
    return build(repo, cfg, okf)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
