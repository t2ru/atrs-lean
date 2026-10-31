#!/usr/bin/env python3
"""文書のバンドルの中でファイル・ディレクトリを移し、リポジトリのリンクとパスの言及を張り直す（port-lang の道具。scripts/README.md）。

使い方:
  python3 -I <skill>/scripts/docs/docmv.py [--dry-run] --root <bundle> <old> <new> [<old> <new> ...]
  python3 -I <skill>/scripts/docs/docmv.py --self-test

`<old>`・`<new>` は `--root`（リポジトリのルートからの相対）からの相対パスである。ディレクトリはその下のファイルに
展開する。いくつもの移動を 1 回で行い、移動元と移動先の両方が動くリンクも正しく張り直す。

1. git が管理する（または無視されていない）`.md` のファイルの Markdown の相対リンクを、そのファイルの移動前の位置から
   解決し、移動の表で写し、移動後の位置から相対パスに直す。URL・`/` で始まるリンク・アンカーだけのリンクは触らない。
   見出しアンカー（`#…`）は保つ（ファイル名を変えなければアンカーも変わらない）。コードブロックとインラインの
   コードの中にあるリンクの形は、例として書いたものとみなして張り直さない。
2. すべてのテキストのファイル（コードのコメント・設定を含む）で、リンクの外にある `<root の末尾 2 成分>/<old>`
   （例: `references/docs/architecture.md`）の形の言及を、新しいパスに直す。
3. `git mv` で移す（移動先の親ディレクトリを作る）。

最後に、リンクの外に残った、移したファイルのバンドルからの相対パス（`/` を含むもの。例: `sql/harness.md`）の
言及を表示する。文脈で意味が決まるので、手で確かめる。リポジトリのルートは `git rev-parse --show-toplevel` で決める。
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

# okf_check.py の LINK_RE と同じ形（ラベルの入れ子の角括弧・<…>・title を許す）。グループ 3 が行き先
LINK_RE = re.compile(r"(!?)\[((?:[^\[\]\n]|\[[^\[\]\n]*\])*)\]\(\s*(<[^>\n]*>|[^)\s]+)(?:\s+(?:\"[^\"\n]*\"|'[^'\n]*'))?\s*\)")
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
SCHEME_RE = re.compile(r"^[a-z][a-z0-9+.-]*:", re.I)
PATH_CH = r"A-Za-z0-9_\-"


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=True).stdout


def git_files(repo):
    out = git(repo, "ls-files", "--cached", "--others", "--exclude-standard")
    return sorted(p for p in out.splitlines() if (repo / p).is_file() and not (repo / p).is_symlink())


def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None


class Moves:
    """移動の表。ファイル（リポジトリからの相対）→ ファイル と、ディレクトリ → ディレクトリ。"""

    def __init__(self, repo, root, pairs, files):
        self.files, self.dirs = {}, {}
        tracked = set(files)
        for old, new in pairs:
            o, n = norm(f"{root}/{old}"), norm(f"{root}/{new}")
            if (repo / o).is_dir():
                self.dirs[o] = n
                under = [f for f in tracked if f.startswith(o + "/")]
                if not under:
                    sys.exit(f"docmv: {o}: no files under the directory")
                for f in under:
                    self.add(f, n + f[len(o):])
            elif o in tracked:
                self.add(o, n)
            else:
                sys.exit(f"docmv: {o}: no such file or directory (tracked by git)")
        for o, n in self.files.items():
            if (repo / n).exists() and n not in self.files:
                sys.exit(f"docmv: {n}: destination exists")

    def add(self, o, n):
        if o in self.files and self.files[o] != n:
            sys.exit(f"docmv: {o}: moved twice")
        self.files[o] = n

    def map(self, p):
        """移動前のパス（ファイルかディレクトリ）を移動後のパスに写す。動かないものはそのまま。"""
        if p in self.files:
            return self.files[p]
        for o in sorted(self.dirs, key=len, reverse=True):
            if p == o or p.startswith(o + "/"):
                return self.dirs[o] + p[len(o):]
        return p


def norm(p):
    return os.path.normpath(p).replace(os.sep, "/")


def relink_target(target, src_old, src_new, moves):
    """`src_old` にあったファイルの中のリンク先 `target` を、`src_new` から見た行き先に直す。"""
    bracket = target.startswith("<") and target.endswith(">")
    t = target[1:-1] if bracket else target
    path, sep, frag = t.partition("#")
    if not path or SCHEME_RE.match(path) or path.startswith("/"):
        return target
    dst_old = norm(os.path.join(os.path.dirname(src_old), path))
    dst_new = moves.map(dst_old)
    if dst_new == dst_old and src_new == src_old:
        return target
    out = os.path.relpath(dst_new, os.path.dirname(src_new) or ".").replace(os.sep, "/")
    if path.endswith("/") and not out.endswith("/"):
        out += "/"
    if out == os.path.relpath(dst_old, os.path.dirname(src_old) or ".").replace(os.sep, "/") + ("/" if path.endswith("/") else ""):
        out = path  # 書き方（./ の有無など）を保つ
    res = out + sep + frag
    return f"<{res}>" if bracket else res


def mention_re(root, moves):
    """リンクの外の `<root の末尾 2 成分>/<old>` の言及。長い順に並べ、1 回の置換で直す。"""
    parts = root.split("/")
    if len(parts) < 2:
        return None, {}
    anchor = "/".join(parts[-2:])
    table = {}
    prefix = root + "/"
    for o, n in list(moves.files.items()) + list(moves.dirs.items()):
        if o.startswith(prefix) and n.startswith(prefix):
            table[f"{anchor}/{o[len(prefix):]}"] = f"{anchor}/{n[len(prefix):]}"
    if not table:
        return None, {}
    alts = "|".join(re.escape(k) for k in sorted(table, key=len, reverse=True))
    return re.compile(rf"(?<![{PATH_CH}.])({alts})(?![{PATH_CH}]|\.[A-Za-z0-9])"), table


def mask_code(text):
    """コードブロックとインラインのコードを空白に置き換えた、同じ長さの文字列（okf_check.py の mask_code と同じ規則）。"""
    out, fence = [], None
    for line in text.split("\n"):
        m = FENCE_RE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line.strip()[len(m.group(1)):].strip():
                fence = None
            out.append(" " * len(line))
            continue
        if m:
            fence = m.group(1)
            out.append(" " * len(line))
            continue
        out.append(re.sub(r"(`+)(?!`).*?(?<!`)\1(?!`)", lambda c: " " * len(c.group(0)), line))
    return "\n".join(out)


def rewrite(text, src_old, src_new, moves, mre, table):
    is_md = src_old.endswith(".md")

    def mention(seg):
        return mre.sub(lambda m: table[m.group(1)], seg) if mre else seg

    if not is_md:
        return mention(text)
    out, pos = [], 0
    for m in LINK_RE.finditer(mask_code(text)):  # コードの中のリンクの形は張り直さない（言及としては直す）
        s, e = m.span(3)
        out.append(mention(text[pos:s]))
        out.append(relink_target(text[s:e], src_old, src_new, moves))
        pos = e
    out.append(mention(text[pos:]))
    return "".join(out)


def leftovers(repo, files, root, moves):
    """リンクの外に残る、移したファイルのバンドルからの相対パス（`/` を含む）の言及。"""
    prefix = root + "/"
    rels = sorted({o[len(prefix):] for o in moves.files if o.startswith(prefix) and "/" in o[len(prefix):]}, key=len, reverse=True)
    if not rels:
        return []
    pat = re.compile(rf"(?<![{PATH_CH}./])({'|'.join(re.escape(r) for r in rels)})(?![{PATH_CH}])")
    hits = []
    for rel in files:
        text = read_text(repo / rel)
        if text is None:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if pat.search(LINK_RE.sub("", line)):
                hits.append(f"{rel}:{n}: {line.strip()[:160]}")
    return hits


def run(repo, root, pairs, dry):
    root = norm(root)
    files = git_files(repo)
    moves = Moves(repo, root, pairs, files)
    mre, table = mention_re(root, moves)
    changed = {}
    for rel in files:
        text = read_text(repo / rel)
        if text is None:
            continue
        new_rel = moves.map(rel)
        out = rewrite(text, rel, new_rel, moves, mre, table)
        if out != text:
            changed[new_rel] = out
    for o, n in sorted(moves.files.items()):
        print(f"docmv: {'would move' if dry else 'move'} {o} -> {n}")
    print(f"docmv: {'would rewrite' if dry else 'rewrote'} links/mentions in {len(changed)} file(s)")
    if dry:
        for p in sorted(changed):
            print(f"  {p}")
        return 0
    for o, n in sorted(moves.files.items()):
        (repo / n).parent.mkdir(parents=True, exist_ok=True)
        git(repo, "mv", o, n)
    for p, out in changed.items():
        (repo / p).write_text(out, encoding="utf-8")
    hits = leftovers(repo, git_files(repo), root, moves)
    if hits:
        print(f"docmv: {len(hits)} line(s) name a moved path outside links; review them:")
        for h in hits:
            print(f"  {h}")
    return 0


def self_test():
    case = {
        "b/docs/index.md": "* [A](a.md) - a\n* [Y](x/y.md#h) - y\n* [X](x/) - dir\n* [U](https://e.org/a.md)\n",
        "b/docs/a.md": "[Y](x/y.md) [I](index.md) [L](#l) [Z](./x/z.md)\n",
        "b/docs/x/y.md": "[A](../a.md#t) [Z](z.md) see b/docs/x/z.md\n",
        "b/docs/x/z.md": "z\n`[c](a.md)` b/docs/a.md\n```\n[f](a.md)\n```\n",
        "code.lean": "-- b/docs/a.md#h and b/docs/x/ and b/docs/a.mdx and sub/b/docs/x/y.md\n",
        "README.md": "[A](b/docs/a.md) mention x/y.md\n",
    }
    want = {
        "b/docs/index.md": "* [A](g/a.md) - a\n* [Y](n/x/y.md#h) - y\n* [X](n/x/) - dir\n* [U](https://e.org/a.md)\n",
        "b/docs/g/a.md": "[Y](../n/x/y.md) [I](../index.md) [L](#l) [Z](../n/x/z.md)\n",
        "b/docs/n/x/y.md": "[A](../../g/a.md#t) [Z](z.md) see b/docs/n/x/z.md\n",
        "b/docs/n/x/z.md": "z\n`[c](a.md)` b/docs/g/a.md\n```\n[f](a.md)\n```\n",
        "code.lean": "-- b/docs/g/a.md#h and b/docs/n/x/ and b/docs/a.mdx and sub/b/docs/n/x/y.md\n",
        "README.md": "[A](b/docs/g/a.md) mention x/y.md\n",
    }
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="docmv-"))
    try:
        for p, t in case.items():
            (tmp / p).parent.mkdir(parents=True, exist_ok=True)
            (tmp / p).write_text(t, encoding="utf-8")
        git(tmp, "init", "-q")
        git(tmp, "add", ".")
        run(tmp, "b/docs", [("a.md", "g/a.md"), ("x", "n/x")], False)
        bad = []
        for p, t in want.items():
            got = read_text(tmp / p)
            if got != t:
                bad.append(f"{p}:\n  want {t!r}\n  got  {got!r}")
        for p in ("b/docs/a.md", "b/docs/x/y.md"):
            if (tmp / p).exists():
                bad.append(f"{p}: still exists")
        if bad:
            print("docmv self-test: FAILED\n" + "\n".join(bad))
            return 1
        print("docmv self-test: OK")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    args = argv[1:]
    dry = "--dry-run" in args
    args = [a for a in args if a != "--dry-run"]
    if len(args) < 4 or args[0] != "--root" or len(args[2:]) % 2:
        print(__doc__)
        return 2
    root, rest = args[1], args[2:]
    repo = pathlib.Path(git(pathlib.Path.cwd(), "rev-parse", "--show-toplevel").strip())
    return run(repo, root, list(zip(rest[0::2], rest[1::2])), dry)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
