"""業務仕様の docs/spec/*.md を lean/Spec のモジュール文書（`/-! -/`）へ移す（1 回だけの移行。backlog c89a、ADR 68a6）。

配置は tools/docs/spec-to-lean.json に書く。各文書の `##` 節（と、`split` に挙げた `###` 節）を 1 つの単位とし、
移し先のファイルで、その単位の見出しを `@[spec_doc]` で指す最初の宣言の直前に差し込む（指す宣言が無ければファイルの末尾）。
文書の題と前文は、既定の移し先の最初のモジュール文書に合わせる（新しいモジュールでは、それが先頭のブロックになる）。

移した後、古い `docs/spec/<doc>.md#<anchor>` から新しい `lean/Spec/<File>.lean#<anchor>` への対応を
tools/docs/spec-anchors.json に書き、それで次を書き換える。

- Markdown の相対リンク（移した本文の中のリンクは、移し先から見た相対パスにする）
- それ以外のファイル（Lean・JSON・Java など）の `docs/spec/<doc>.md#<anchor>` の文字列（`@[spec_doc]`・登録簿の
  `sites`・ベクタの `specRef` など）

使い方（リポジトリのルートで）:

  uv run python -I tools/docs/spec_to_lean.py           # 移す（docs/spec の移した文書を消す）
  uv run python -I tools/docs/spec_to_lean.py --dry-run # 対応表だけを出す
"""

import importlib.util
import json
import os
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONFIG = REPO / "tools/docs/spec-to-lean.json"
ANCHORS_OUT = REPO / "tools/docs/spec-anchors.json"
SPEC_DIR = "docs/spec"
MARKER_RE = re.compile(r"^/-!\s*(#+)\s+(.*?)\s*-/\s*$")

spec = importlib.util.spec_from_file_location("okf_check", REPO / ".agents/skills/okf-bundle/scripts/okf_check.py")
okf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(okf)


def md_anchors(lines):
    """[(行番号 0 始まり, レベル, アンカー)]。lines は Markdown の本文（マスク前）。"""
    masked = okf.mask_code(lines)
    seen, out = {}, []
    for n, lvl, _ in okf.headings(masked):
        m = okf.HEADING_RE.match(lines[n - 1])
        s = okf.slug((m.group(2) or "").strip())
        k = seen.get(s, 0)
        out.append((n - 1, lvl, s if k == 0 else f"{s}-{k}"))
        seen[s] = k + 1
    return out


class Unit:
    def __init__(self, doc, kind, lines, tags, anchor):
        self.doc, self.kind, self.lines, self.tags, self.anchor = doc, kind, lines, tags, anchor
        self.target = None


def split_doc(doc, cfg):
    """文書を単位（前文・## 節・切り出す ### 節）に分ける。tags は行ごとの（文書, 古いアンカー）か None。"""
    text = (REPO / SPEC_DIR / f"{doc}.md").read_text(encoding="utf-8")
    fm, body, _ = okf.split_frontmatter(text)
    meta = okf.parse_yaml(fm) if fm else {}
    lines = body.split("\n")
    heads = md_anchors(lines)
    tag = [None] * len(lines)
    for n, _, a in heads:
        tag[n] = (doc, a)
    splits = set(cfg.get("split", []))
    starts = []  # (行, 種類, アンカー)
    for n, lvl, a in heads:
        if lvl == 1:
            starts.append((n, "title", a))
        elif lvl == 2:
            starts.append((n, "section", a))
        elif lvl == 3 and a in splits:
            starts.append((n, "split", a))
    if not starts or starts[0][0] != next(n for n, _, _ in heads):
        sys.exit(f"{doc}: the first heading must be the title")
    units = []
    for i, (n, kind, a) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(lines)
        ls, ts = lines[n:end], tag[n:end]
        while ls and not ls[-1].strip():
            ls, ts = ls[:-1], ts[:-1]
        units.append(Unit(doc, kind, ls, ts, a))
    # 切り出した ### 節は見出しを 1 段上げる
    for u in units:
        if u.kind == "split":
            masked = okf.mask_code(u.lines)
            u.lines = [l[1:] if masked[k].startswith("##") else l for k, l in enumerate(u.lines)]
    sources = meta.get("sources") or []
    if sources:
        title = units[0]
        refs = "、".join(f"[{s.get('title') or s['id']}]({s['resource']})" for s in sources)
        title.lines = title.lines + ["", f"資料: {refs}"]
        title.tags = title.tags + [None, None]
    return meta, units


def module_name(path):
    return path[len("lean/"):-len(".lean")].replace("/", ".")


def decl_start(lines, i):
    """i 行目（`@[spec_doc …]` の行）を含む宣言の開始行（文書コメントの先頭か、属性の先頭）。"""
    j = i
    while j > 0 and not lines[j].lstrip().startswith("@["):
        j -= 1
    if j > 0 and lines[j - 1].rstrip().endswith("-/"):
        k = j - 1
        while k >= 0 and not lines[k].lstrip().startswith("/--"):
            k -= 1
        if k >= 0:
            j = k
    return j


def first_module_doc(lines):
    """最初のモジュール文書 `/-! … -/` の（開始行, 終了行）。"""
    for i, l in enumerate(lines):
        if l.startswith("/-!"):
            for j in range(i, len(lines)):
                if lines[j].rstrip().endswith("-/"):
                    return i, j
    return None


def assemble(path, units, title_unit, docs_cfg):
    at = {a: t for c in docs_cfg.values() for a, t in c.get("at", {}).items()}
    """移し先の 1 ファイルを組み立てる。返り値は（行の列, 行ごとのタグ）。"""
    full = REPO / path
    if full.exists():
        lines = full.read_text(encoding="utf-8").split("\n")
    else:
        lines = []
    tags = [None] * len(lines)
    inserts = {}  # 行 → [単位]
    drop = set()  # 消す行
    tail = []
    for u in units:
        if u.kind == "title":
            continue
        refs = [f'"docs/spec/{u.doc}.md#{t[1]}"' for t in u.tags if t]
        head = okf.slug(re.sub(r"^#+\s*", "", u.lines[0]).strip())
        pos = None
        # 1. 同じ題（末尾の括弧書きを除く）の 1 行の節の印 `/-! ## … -/` があれば、それを本文の見出しで置き換える
        for k, l in enumerate(lines):
            m = MARKER_RE.match(l)
            if m and k not in drop and okf.slug(re.sub(r"（[^（）]*）$", "", m.group(2))) == head:
                pos = k
                drop.add(k)
                break
        # 2. 配置表の at（その文字列を含む最初の行の前）
        if pos is None and u.anchor in at:
            pos = next((k for k, l in enumerate(lines) if at[u.anchor] in l), None)
            if pos is None:
                sys.exit(f"{path}: no line contains {at[u.anchor]!r}")
        # 3. その節を `@[spec_doc]` で指す最初の宣言の前。直前の節の印が違う題なら、1 段下げて節の中に入れる
        if pos is None:
            for i, l in enumerate(lines):
                if any(r in l for r in refs) and _in_attr(lines, i):
                    pos = decl_start(lines, i)
                    k = pos - 1
                    while k >= 0 and not lines[k].strip():
                        k -= 1
                    m = MARKER_RE.match(lines[k]) if k >= 0 else None
                    if m and k not in drop:
                        pos = k
                        lines[k] = f"/-! #{m.group(1)} {m.group(2)} -/"
                    break
        if pos is None:
            tail.append(u)
        else:
            inserts.setdefault(pos, []).append(u)
    out, otag = [], []

    def block(u):
        out.append("/-!")
        otag.append(None)
        out.extend(u.lines)
        otag.extend(u.tags)
        out.extend(["-/", ""])
        otag.extend([None, None])

    if title_unit is not None:
        mod = module_name(path)
        head = title_unit.lines[0]
        title = re.sub(r"^#\s+", "", head).strip()
        new_head = f"# {title}（`{mod}`）"
        rest, rest_tags = title_unit.lines[1:], title_unit.tags[1:]
        while rest and not rest[0].strip():
            rest, rest_tags = rest[1:], rest_tags[1:]
        md = first_module_doc(lines)
        if md is None:
            out.append("/-!")
            otag.append(None)
            out.extend([new_head, ""])
            otag.extend([title_unit.tags[0], None])
            out.extend(rest)
            otag.extend(rest_tags)
            out.extend(["-/", ""])
            otag.extend([None, None])
        else:
            s, e = md
            body = lines[s:e + 1]
            btag = [None] * len(body)
            # 既存のモジュール文書の題 `# Spec.X` を文書の題に替える
            for k, l in enumerate(body):
                if re.match(r"^(/-!\s*)?# ", l):
                    prefix = "/-!\n" if l.startswith("/-!") else ""
                    body[k] = new_head if not prefix else "/-!"
                    btag[k] = title_unit.tags[0] if not prefix else None
                    if prefix:
                        body.insert(k + 1, new_head)
                        btag.insert(k + 1, title_unit.tags[0])
                    break
            else:
                sys.exit(f"{path}: the first module doc has no title")
            last = body[-1]
            assert last.rstrip().endswith("-/"), path
            if last.strip() != "-/":
                body[-1] = last.rstrip()[:-2].rstrip()
                body.append("-/")
                btag.append(None)
            body = body[:-1] + [""] + rest + ["-/"]
            btag = btag[:-1] + [None] + rest_tags + [None]
            lines = lines[:s] + body + lines[e + 1:]
            tags = tags[:s] + btag + tags[e + 1:]
            shift = len(body) - (e + 1 - s)
            inserts = {(p + shift if p > e else p): us for p, us in inserts.items()}
            drop = {(p + shift if p > e else p) for p in drop}
    for i, l in enumerate(lines):
        for u in inserts.get(i, []):
            block(u)
        if i in drop:
            continue
        out.append(l)
        otag.append(tags[i])
    if tail:
        while out and not out[-1].strip():
            out.pop()
            otag.pop()
        out.append("")
        otag.append(None)
        for u in tail:
            block(u)
    while out and not out[-1].strip():
        out.pop()
        otag.pop()
    out.append("")
    otag.append(None)
    return out, otag


def _in_attr(lines, i):
    j = i
    while j > 0 and not lines[j].lstrip().startswith("@["):
        j -= 1
    return "spec_doc" in "\n".join(lines[j:i + 1])


def new_anchors(lines, tags):
    """組み立てたファイルの（古い（文書, アンカー）→ 新しいアンカー）。"""
    doc = okf.lean_doc_lines(lines)
    masked = okf.mask_code(doc)
    seen, out = {}, {}
    for n, _, _ in okf.headings(masked):
        m = okf.HEADING_RE.match(doc[n - 1])
        s = okf.slug((m.group(2) or "").strip())
        k = seen.get(s, 0)
        a = s if k == 0 else f"{s}-{k}"
        seen[s] = k + 1
        if tags[n - 1]:
            out[tags[n - 1]] = a
    return out


def relpath(target, start_dir):
    return os.path.relpath(target, start_dir).replace(os.sep, "/")


def rewrite_md_links(lines, src_dir, dst_dir, amap, rebase=True, self_doc=None, dst_file=None):
    """Markdown の行のリンクを書き換える。src_dir はリンクの基点だった場所、dst_dir は新しい基点（どちらもリポジトリ相対）。
    rebase が偽なら、移した文書を指すリンクだけを書き換える。"""
    masked = okf.mask_code(lines)
    out = []
    for raw, mline in zip(lines, masked):
        spans = []
        for m in okf.LINK_RE.finditer(mline):
            target = raw[m.start(3):m.end(3)]
            if target.startswith("<") or re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target):
                continue
            path, _, frag = target.partition("#")
            dest = os.path.normpath(os.path.join(src_dir, urllib.parse.unquote(path))) if path else self_doc
            if dest is None:
                continue
            key = dest + ("#" + urllib.parse.unquote(frag) if frag else "")
            if key in amap:
                new = amap[key]
            elif dest in amap and not frag:
                new = amap[dest]
            elif dest in amap:
                sys.exit(f"unknown anchor: {key}")
            elif not rebase:
                continue
            else:
                new = dest + ("#" + frag if frag else "")
            npath, _, nfrag = new.partition("#")
            rel = "" if npath == dst_file else relpath(npath, dst_dir) if npath != "." else ""
            if path.endswith("/") and not rel.endswith("/"):
                rel += "/"
            spans.append((m.start(3), m.end(3), rel + ("#" + nfrag if nfrag else "")))
        for s, e, t in reversed(spans):
            raw = raw[:s] + t + raw[e:]
        out.append(raw)
    return out


def main(argv):
    dry = "--dry-run" in argv
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))["docs"]
    units_by_file, title_of = {}, {}
    all_units = []
    for doc, c in cfg.items():
        _, units = split_doc(doc, c)
        secs = c.get("sections", {})
        for u in units:
            u.target = c["file"] if u.kind == "title" else secs.get(u.anchor, c["file"])
            if u.kind == "title":
                title_of[c["file"]] = u
            else:
                units_by_file.setdefault(u.target, []).append(u)
            all_units.append(u)
    files = sorted(set(units_by_file) | set(title_of))

    # 1 回目: 組み立てて、アンカーの対応表を作る
    amap = {}
    for doc, c in cfg.items():
        amap[f"{SPEC_DIR}/{doc}.md"] = c["file"]
    for f in files:
        lines, tags = assemble(f, units_by_file.get(f, []), title_of.get(f), cfg)
        for (doc, a), na in new_anchors(lines, tags).items():
            amap[f"{SPEC_DIR}/{doc}.md#{a}"] = f"{f}#{na}"
    missing = [(u.doc, t[1]) for u in all_units for t in u.tags if t and f"{SPEC_DIR}/{t[0]}.md#{t[1]}" not in amap]
    if missing:
        sys.exit(f"headings without a new anchor: {missing}")
    if dry:
        print(json.dumps(amap, ensure_ascii=False, indent=2))
        return 0

    # 2 回目: 移した本文のリンクを移し先から見た相対パスにして、組み立て直す
    for u in all_units:
        u.lines = rewrite_md_links(u.lines, SPEC_DIR, os.path.dirname(u.target), amap,
                                   self_doc=f"{SPEC_DIR}/{u.doc}.md", dst_file=u.target)
    for f in files:
        lines, _ = assemble(f, units_by_file.get(f, []), title_of.get(f), cfg)
        (REPO / f).parent.mkdir(parents=True, exist_ok=True)
        (REPO / f).write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")
    for doc in cfg:
        (REPO / SPEC_DIR / f"{doc}.md").unlink()

    # 参照の書き換え
    tracked = subprocess.run(["git", "ls-files"], cwd=REPO, capture_output=True, text=True, check=True).stdout.split("\n")
    skip = {"tools/docs/spec_to_lean.py", "tools/docs/spec-to-lean.json", "tools/docs/spec-anchors.json"}
    pat = re.compile(r"docs/spec/(" + "|".join(re.escape(d) for d in cfg) + r")\.md(#[^\s\"'`)\]|,>]*)?")
    unknown = []

    def sub(m):
        key = f"{SPEC_DIR}/{m.group(1)}.md" + (m.group(2) or "")
        if key in amap:
            return amap[key]
        unknown.append(key)
        return m.group(0)

    for rel in tracked:
        if not rel or rel in skip or rel.startswith("upstream/") or not (REPO / rel).is_file():
            continue
        p = REPO / rel
        try:
            text = p.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        new = text
        if rel.endswith(".md"):
            new = "\n".join(rewrite_md_links(text.split("\n"), os.path.dirname(rel), os.path.dirname(rel), amap, rebase=False))
        else:
            new = pat.sub(sub, new)
        if new != text:
            p.write_text(new, encoding="utf-8")
    ANCHORS_OUT.write_text(json.dumps({"note": "docs/spec の業務仕様を lean/Spec のモジュール文書へ移したときの、古いリンク先と新しいリンク先の対応（tools/docs/spec_to_lean.py が生成。backlog c89a）", "anchors": amap}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if unknown:
        print("unknown anchors (left as is):")
        for k in sorted(set(unknown)):
            print(f"  {k}")
        return 1
    print(f"moved {len(cfg)} document(s) into {len(files)} Lean file(s); {len(amap)} anchor(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
