#!/usr/bin/env python3
"""OKF v0.2 の Knowledge Bundle と Markdown のリンクの検査（spec-pivot の道具。scripts/README.md）。

検査するバンドルと規則は、リポジトリの `trace/project.json` の `okf` から読む（形は
references/docs/rules/maintenance.md#バンドルの検査）。リポジトリのルートは、作業ディレクトリから上にたどって探す
（`--repo` でも指定できる）。Python の標準ライブラリだけで動く。frontmatter は YAML の部分集合として読む
（下の「YAML の部分集合」）。部分集合の外の書き方は、YAML として正しくても違反とする。

検査（違反の符号。どれも失敗扱い）:
  F1  index.md・log.md 以外の .md に frontmatter が無い、または YAML の部分集合として読めない（OKF §11-1）
  F2  frontmatter に空でない文字列の `type` が無い（OKF §11-2）
  R1  index.md の形（frontmatter はバンドルのルートの `okf_version` だけ。本文は `#` 見出しと
      `* [題名](パス) - 説明` だけ）（OKF §8・§11-3、§12）
  R2  log.md の形（frontmatter 無し。`# ` の題名、`## YYYY-MM-DD` の見出しが新しい順で重複しない）（OKF §9・§11-3）
  K1  `type` が規則（`rules[].match`）の値と違う
  K2  規則の必須キーが無い
  K3  キーの値が不正（`status` のライフサイクル（OKF §5.4）、`generated`・`verified`（§5.2・§7）、`sources`（§5.1）、
      `tags` の形、規則の `enum`）
  K4  規則の `quoted` のキーがダブルクォートで囲まれていない
  H1  `#` 見出しが 1 つでない、または frontmatter の `title` と違う（規則の `title_heading`）
  S1  規則の必須の節（`##` 見出し）が無い、または順序が違う
  A1  意思決定記録（`kind: adr`）: `decision_status` と `status` の対応、`superseded_by`、選択肢が 2 つ以上、
      `Decision Outcome` に採択を示す行（規則の `outcome_markers` で始まる行。既定は `Chosen option`）
  B1  作業項目（`kind: backlog`）: `state` の値、`status` を持たない、`done` の項目に未完了の完了条件が無い
  I1  バンドルのルートの index.md が、バンドルの文書（index.md・log.md 以外の .md）を列挙していない
  I2  index.md の項目の題名・説明が、指す文書の `title`・`description` と違う
  L1  相対リンクの指す先が無い
  L2  リンクの見出しアンカーが、指す Markdown に無い（GitHub の slug の規則）
  L3  `/` で始まるリンク（`links.absolute` が false のとき）

コードブロック（``` / ~~~）とインラインのコードの中は、リンク・見出しとして扱わない。

YAML の部分集合（frontmatter）:
  - ブロックのマッピング（`key: value`。キーは英数字・`_`・`-`）と、ブロックの列（`- value`、`- key: value`）。
    入れ子は空白で字下げする（タブ不可）。列は親のキーより深く字下げする。
  - スカラ: ダブルクォート（`\\"`・`\\\\`・`\\n`・`\\t`・`\\uXXXX`）、シングルクォート、プレーン（1 行。`: ` を含まない。
    指示子で始まらない）。`null`・`~`・`true`・`false`・整数は型付きで読み、他のプレーンは文字列。
  - フローの列 `[a, "b"]`（要素はスカラだけ）。行全体のコメント `# …` と、値の後の ` # …`。
  - 使えないもの: フローのマッピング `{…}`、ブロックのスカラ `|`・`>`、複数行のプレーン、アンカー・別名・タグ、複数文書。

使い方:
  uv run python -I <skill>/scripts/docs/okf_check.py              # 検査する（違反で終了コード 1）
  uv run python -I <skill>/scripts/docs/okf_check.py --self-test  # 違反例（scripts/ci/fixtures/okf/）を検出できることを確かめる
"""
import datetime
import json
import os
import pathlib
import re
import sys
import unicodedata
import urllib.parse

HERE = pathlib.Path(__file__).resolve().parent
FIXTURES = HERE.parent / "ci" / "fixtures" / "okf"


# ---------------------------------------------------------------- YAML の部分集合

class YamlError(Exception):
    def __init__(self, line, msg):
        super().__init__(f"line {line}: {msg}")
        self.line = line


KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:[ ]+(.*))?$")
INT_RE = re.compile(r"^[-+]?(?:0|[1-9][0-9]*)$")
PLAIN_BAD_START = tuple("-?:,[]{}#&*!|>'\"%@`")


def parse_yaml(text, base_line=1):
    """部分集合の YAML を読む。トップレベルはマッピング。違反は YamlError。"""
    toks = []
    for n, raw in enumerate(text.split("\n"), base_line):
        body = raw.lstrip(" ")
        if body.startswith("\t") or "\t" in raw[:len(raw) - len(raw.lstrip())]:
            raise YamlError(n, "tab in indentation")
        s = body.rstrip()
        if not s or s.startswith("#"):
            continue
        if s in ("---", "...") and len(body) == len(raw):
            raise YamlError(n, "multiple documents are not supported")
        toks.append([n, len(raw) - len(body), s])
    if not toks:
        return {}
    if toks[0][1] != 0:
        raise YamlError(toks[0][0], "top level must start at column 0")
    val, i = _block(toks, 0, 0)
    if i != len(toks):
        raise YamlError(toks[i][0], "unexpected indentation")
    if not isinstance(val, dict):
        raise YamlError(toks[0][0], "top level must be a mapping")
    return val


def _is_item(s):
    return s == "-" or s.startswith("- ")


def _block(toks, i, ind):
    return _seq(toks, i, ind) if _is_item(toks[i][2]) else _map(toks, i, ind)


def _map(toks, i, ind):
    out = {}
    while i < len(toks) and toks[i][1] == ind and not _is_item(toks[i][2]):
        n, _, s = toks[i]
        m = KEY_RE.match(s)
        if not m:
            raise YamlError(n, f"expected `key: value`, got {s!r}")
        key, rest = m.group(1), m.group(2)
        if key in out:
            raise YamlError(n, f"duplicate key {key!r}")
        i += 1
        if rest is None or rest.startswith("#"):
            if i < len(toks) and toks[i][1] > ind:
                out[key], i = _block(toks, i, toks[i][1])
            elif i < len(toks) and toks[i][1] == ind and _is_item(toks[i][2]):
                raise YamlError(toks[i][0], "indent the sequence deeper than its key")
            else:
                out[key] = None
        else:
            out[key] = _scalar(rest, n)
    if i < len(toks) and toks[i][1] > ind:
        raise YamlError(toks[i][0], "unexpected indentation (multi-line values are not supported)")
    return out, i


def _seq(toks, i, ind):
    out = []
    while i < len(toks) and toks[i][1] == ind and _is_item(toks[i][2]):
        n, _, s = toks[i]
        rest = s[1:].lstrip(" ")
        col = ind + len(s) - len(rest)
        if not rest or rest.startswith("#"):
            i += 1
            if i < len(toks) and toks[i][1] > ind:
                v, i = _block(toks, i, toks[i][1])
            else:
                v = None
            out.append(v)
        elif KEY_RE.match(rest) or _is_item(rest):
            toks[i] = [n, col, rest]
            v, i = _block(toks, i, col)
            out.append(v)
        else:
            out.append(_scalar(rest, n))
            i += 1
    if i < len(toks) and toks[i][1] > ind:
        raise YamlError(toks[i][0], "unexpected indentation")
    return out, i


def _quoted(s, n):
    """先頭の引用符付きスカラを読み、(値, 残り) を返す。"""
    q = s[0]
    out, j = [], 1
    while j < len(s):
        c = s[j]
        if q == "'" and c == "'":
            if s[j + 1:j + 2] == "'":
                out.append("'")
                j += 2
                continue
            return "".join(out), s[j + 1:]
        if q == '"' and c == '"':
            return "".join(out), s[j + 1:]
        if q == '"' and c == "\\":
            e = s[j + 1:j + 2]
            simple = {'"': '"', "\\": "\\", "/": "/", "n": "\n", "t": "\t", "r": "\r", "0": "\0", " ": " "}
            if e in simple:
                out.append(simple[e])
                j += 2
                continue
            if e == "u" and re.fullmatch(r"[0-9A-Fa-f]{4}", s[j + 2:j + 6] or ""):
                out.append(chr(int(s[j + 2:j + 6], 16)))
                j += 6
                continue
            raise YamlError(n, f"unsupported escape \\{e}")
        out.append(c)
        j += 1
    raise YamlError(n, "unterminated quoted scalar")


def _strip_comment(s):
    m = re.search(r"\s#", s)
    return (s[:m.start()] if m else s).rstrip()


def _plain(s, n, flow=False):
    if not s:
        raise YamlError(n, "empty item")
    if s.startswith(PLAIN_BAD_START) and not (s[0] == "-" and len(s) > 1 and s[1] != " "):
        raise YamlError(n, f"plain scalar {s!r} starts with an indicator; quote it")
    if ": " in s or s.endswith(":"):
        raise YamlError(n, f"plain scalar {s!r} contains ': '; quote it")
    if flow and re.search(r"[\[\]{},]", s):
        raise YamlError(n, f"flow item {s!r} contains a flow indicator; quote it")
    if s in ("null", "~", "Null", "NULL"):
        return None
    if s in ("true", "True", "TRUE"):
        return True
    if s in ("false", "False", "FALSE"):
        return False
    if INT_RE.match(s):
        return int(s)
    return s


def _scalar(s, n):
    if s[0] in "\"'":
        v, rest = _quoted(s, n)
        if _strip_comment(rest):
            raise YamlError(n, f"unexpected text after quoted scalar: {rest.strip()!r}")
        return v
    if s[0] == "[":
        return _flow_seq(s, n)
    if s[0] == "{":
        raise YamlError(n, "flow mappings `{...}` are not supported; use a block mapping")
    if s[0] in "|>":
        raise YamlError(n, "block scalars are not supported")
    s = _strip_comment(s)
    return _plain(s, n)


def _flow_seq(s, n):
    out, j = [], 1
    s = s.rstrip()
    while True:
        while j < len(s) and s[j] == " ":
            j += 1
        if j >= len(s):
            raise YamlError(n, "unterminated flow sequence")
        if s[j] == "]":
            if out and expect_item:
                raise YamlError(n, "trailing comma in flow sequence")
            rest = s[j + 1:]
            if _strip_comment(rest):
                raise YamlError(n, f"unexpected text after flow sequence: {rest.strip()!r}")
            return out
        if s[j] in "\"'":
            v, rest = _quoted(s[j:], n)
            j = len(s) - len(rest)
        elif s[j] in "[{":
            raise YamlError(n, "nested flow collections are not supported")
        else:
            k = j
            while k < len(s) and s[k] not in ",]":
                k += 1
            v = _plain(s[j:k].strip(), n, flow=True)
            j = k
        out.append(v)
        while j < len(s) and s[j] == " ":
            j += 1
        if j < len(s) and s[j] == ",":
            j += 1
            expect_item = True
        elif j < len(s) and s[j] == "]":
            expect_item = False
        else:
            raise YamlError(n, "expected ',' or ']' in flow sequence")


# ---------------------------------------------------------------- Markdown

FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$")
LINK_RE = re.compile(r"(!?)\[((?:[^\[\]\n]|\[[^\[\]\n]*\])*)\]\(\s*(<[^>\n]*>|[^)\s]+)(?:\s+(?:\"[^\"\n]*\"|'[^'\n]*'))?\s*\)")


def split_frontmatter(text):
    """(frontmatter の文字列か None, frontmatter の後の本文, 本文の最初の行番号)。"""
    if not text.startswith("---\n"):
        return None, text, 1
    end = re.search(r"^---[ \t]*$", text[4:], re.M)
    if not end:
        return None, text, 1
    fm = text[4:4 + end.start()].rstrip("\n")
    cut = 4 + end.end() + 1
    return fm, text[cut:], text[:cut].count("\n") + 1


def mask_code(lines):
    """コードブロックの行を空にし、インラインのコードを空白に置き換えた行の列。"""
    out, fence = [], None
    for line in lines:
        m = FENCE_RE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line.strip()[len(m.group(1)):].strip():
                fence = None
            out.append("")
            continue
        if m:
            fence = m.group(1)
            out.append("")
            continue
        out.append(mask_inline(line))
    return out


def mask_inline(line):
    def rep(m):
        return " " * len(m.group(0))
    return re.sub(r"(`+)(?!`).*?(?<!`)\1(?!`)", rep, line)


def heading_text_plain(t):
    """見出しの Markdown を、GitHub が表示する文字列に近づける。"""
    t = re.sub(r"\s+#+\s*$", "", t)
    t = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = t.replace("`", "")
    t = re.sub(r"(\*\*|__|\*|~~)", "", t)
    return t.strip()


def slug(text):
    """GitHub（github-slugger）の見出しアンカー: 小文字にし、文字・数字・結合文字・連結句読点・`-`・空白以外を除き、
    空白を `-` にする。"""
    t = heading_text_plain(text).lower()
    kept = "".join(c for c in t if c in "- " or unicodedata.category(c)[0] in "LMN" or unicodedata.category(c) == "Pc")
    return kept.replace(" ", "-")


def headings(lines):
    """[(行番号, レベル, 文字列)]。lines はマスク済み。"""
    out = []
    for n, line in enumerate(lines, 1):
        m = HEADING_RE.match(line)
        if m:
            out.append((n, len(m.group(1)), (m.group(2) or "").strip()))
    return out


def anchors(raw_lines):
    lines = mask_code(raw_lines)
    seen, out = {}, set()
    for n, _, t in headings(lines):
        # インラインのコードはマスクされているので、元の行から見出しの文字列を取り直す
        m = HEADING_RE.match(raw_lines[n - 1])
        s = slug((m.group(2) or "").strip())
        k = seen.get(s, 0)
        out.add(s if k == 0 else f"{s}-{k}")
        seen[s] = k + 1
    for raw in raw_lines:
        for m in re.finditer(r"<a\s+(?:id|name)=\"([^\"]+)\"", raw):
            out.add(m.group(1))
    return out


# ---------------------------------------------------------------- 設定

def find_repo(argv):
    if "--repo" in argv:
        i = argv.index("--repo")
        root = pathlib.Path(argv[i + 1]).resolve()
        del argv[i:i + 2]
        return root
    d = pathlib.Path.cwd().resolve()
    for c in (d, *d.parents):
        if (c / "trace" / "project.json").is_file():
            return c
    sys.exit("okf_check: repository root (trace/project.json) not found")


def glob_re(pat):
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pat.startswith("**", i):
            out += ".*"
            i += 2
        elif pat[i] == "*":
            out += "[^/]*"
            i += 1
        elif pat[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pat[i])
            i += 1
    return re.compile(out + r"\Z")


def load_config(repo):
    cfg = json.loads((repo / "trace" / "project.json").read_text(encoding="utf-8")).get("okf")
    if cfg is None:
        sys.exit("okf_check: trace/project.json has no `okf`")
    bundles = []
    for b in cfg.get("bundles", []):
        prof = b.get("profile", {})
        if isinstance(prof, str):
            prof = json.loads((repo / prof).read_text(encoding="utf-8"))
        rules = [dict(r, _re=glob_re(r["match"])) for r in prof.get("rules", [])]
        bundles.append({"root": b["root"].rstrip("/"), "profile": prof, "rules": rules})
    return cfg, bundles


# ---------------------------------------------------------------- 検査

STATUS = ("draft", "stable", "deprecated")
ADR_STATUS = {"proposed": "draft", "accepted": "stable", "rejected": "deprecated",
              "deprecated": "deprecated", "superseded": "deprecated"}
BACKLOG_STATE = ("todo", "doing", "blocked", "done", "dropped")
ACTOR_RE = re.compile(r"^(?:human:[^\s/]+|process:[^\s/]+|[^\s/:]+/[^\s/]+)$")
ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
INDEX_ENTRY_RE = re.compile(r"^\* \[((?:[^\[\]]|\[[^\[\]]*\])+)\]\(([^)\s]+)\) - (\S.*)$")


class Checker:
    def __init__(self, repo):
        self.repo = repo
        self.cfg, self.bundles = load_config(repo)
        self.errs = []
        self._cache = {}

    def err(self, code, rel, line, msg):
        loc = f"{rel}:{line}" if line else str(rel)
        self.errs.append((code, str(rel), f"[{code}] {loc}: {msg}"))

    def read(self, rel):
        if rel not in self._cache:
            try:
                self._cache[rel] = (self.repo / rel).read_text(encoding="utf-8").replace("\r\n", "\n")
            except (OSError, UnicodeDecodeError):
                self._cache[rel] = None
        return self._cache[rel]

    def walk(self, root, skip=()):
        base = self.repo / root
        if base.is_file():
            return [root] if root.endswith(".md") else []
        out = []
        for dp, dns, fns in os.walk(base):
            dns[:] = sorted(d for d in dns if not d.startswith(".") or d == ".agents")
            for f in sorted(fns):
                if f.endswith(".md"):
                    rel = os.path.relpath(os.path.join(dp, f), self.repo).replace(os.sep, "/")
                    if not rel.startswith(tuple(skip)):
                        out.append(rel)
        return out

    def meta(self, rel):
        """(frontmatter の dict か None, 本文の行, 本文の最初の行番号)。"""
        text = self.read(rel)
        fm, body, start = split_frontmatter(text)
        data = None
        if fm is not None:
            try:
                data = parse_yaml(fm, 2)
            except YamlError:
                data = None
        return data, body.split("\n"), start

    # -------------------------------------------------------- バンドル

    def check_bundle(self, b):
        root, prof = b["root"], b["profile"]
        files = self.walk(root, self.cfg.get("skip", []))
        docs = []
        for rel in files:
            name = rel.rsplit("/", 1)[-1]
            sub = rel[len(root) + 1:]
            if name == "index.md":
                self.check_index(rel, sub == "index.md", prof)
            elif name == "log.md":
                self.check_log(rel)
            else:
                docs.append(rel)
                self.check_concept(rel, sub, b)
        idx = f"{root}/index.md"
        if prof.get("index_complete") and self.read(idx) is not None:
            listed = set()
            for n, line in enumerate(self.read(idx).split("\n"), 1):
                m = INDEX_ENTRY_RE.match(line)
                if m:
                    listed.add(os.path.normpath(os.path.join(root, urllib.parse.unquote(m.group(2).split("#")[0]))))
            for rel in docs:
                if os.path.normpath(rel) not in listed:
                    self.err("I1", idx, 0, f"does not list {rel[len(root) + 1:]}")

    def check_concept(self, rel, sub, b):
        text = self.read(rel)
        fm_text, body, start = split_frontmatter(text)
        body = body.split("\n")
        if fm_text is None:
            self.err("F1", rel, 1, "no YAML frontmatter (--- … ---) at the start")
            return
        try:
            fm = parse_yaml(fm_text, 2)
        except YamlError as e:
            self.err("F1", rel, e.line, f"frontmatter is not in the YAML subset: {e}")
            return
        t = fm.get("type")
        if not isinstance(t, str) or not t.strip():
            self.err("F2", rel, 0, "frontmatter has no non-empty string `type`")
        self.check_okf_keys(rel, fm)
        rule = next((r for r in b["rules"] if r["_re"].match(sub)), None)
        if rule is None:
            if b["rules"]:
                self.err("K1", rel, 0, "no rule of the bundle profile matches this document")
            return
        if "type" in rule and t != rule["type"]:
            self.err("K1", rel, 0, f"type {t!r} should be {rule['type']!r} (rule {rule['match']})")
        common = b["profile"].get("common", {})
        required = list(common.get("required", [])) + list(rule.get("required", []))
        for k in required:
            if k not in fm or fm[k] in (None, ""):
                self.err("K2", rel, 0, f"missing key `{k}`")
        for k, allowed in {**common.get("enum", {}), **rule.get("enum", {})}.items():
            if k in fm and fm[k] is not None:
                vals = fm[k] if isinstance(fm[k], list) else [fm[k]]
                for v in vals:
                    if v not in allowed:
                        self.err("K3", rel, 0, f"`{k}` value {v!r} is not one of {allowed}")
        for k in list(common.get("quoted", [])) + list(rule.get("quoted", [])):
            m = re.search(rf"^{re.escape(k)}:[ ]*(.*)$", fm_text, re.M)
            if m and not m.group(1).startswith('"'):
                self.err("K4", rel, 0, f"`{k}` should be double-quoted")
        masked = mask_code(body)
        hs = headings(masked)
        if common.get("title_heading", rule.get("title_heading")):
            h1 = [h for h in hs if h[1] == 1]
            if len(h1) != 1:
                self.err("H1", rel, 0, f"{len(h1)} level-1 headings; write exactly one")
            elif isinstance(fm.get("title"), str):
                raw = body[h1[0][0] - 1]
                shown = heading_text_plain(HEADING_RE.match(raw).group(2) or "")
                if shown != heading_text_plain(fm["title"]):
                    self.err("H1", rel, start + h1[0][0] - 1, f"heading {shown!r} differs from title {fm['title']!r}")
        h2 = [(n, t) for n, lv, t in hs if lv == 2]
        names = [t for _, t in h2]
        pos = -1
        for s in rule.get("sections", []):
            if s not in names:
                self.err("S1", rel, 0, f"missing section `## {s}`")
                continue
            p = names.index(s)
            if p < pos:
                self.err("S1", rel, start + h2[p][0] - 1, f"section `## {s}` is out of order")
            pos = max(pos, p)
        kind = rule.get("kind")
        if kind == "adr":
            self.check_adr(rel, fm, body, h2, start, rule)
        elif kind == "backlog":
            self.check_backlog(rel, fm, body, h2, start)

    def check_okf_keys(self, rel, fm):
        if "status" in fm and fm["status"] not in STATUS:
            self.err("K3", rel, 0, f"`status` {fm['status']!r} is not an OKF lifecycle value {STATUS}")
        if "tags" in fm and not (isinstance(fm["tags"], list) and all(isinstance(x, str) and x for x in fm["tags"])):
            self.err("K3", rel, 0, "`tags` should be a list of strings")
        g = fm.get("generated")
        if g is not None:
            if not isinstance(g, dict) or not isinstance(g.get("by"), str) or not ACTOR_RE.match(g["by"]):
                self.err("K3", rel, 0, "`generated.by` should be `<producer>/<version>`, `human:<id>` or `process:<id>`")
            if not isinstance(g, dict) or not isinstance(g.get("at"), str) or not ISO_RE.match(g["at"]):
                self.err("K3", rel, 0, "`generated.at` should be an ISO 8601 timestamp with an offset")
        v = fm.get("verified")
        if v is not None:
            for e in v if isinstance(v, list) else [v]:
                if not isinstance(e, dict) or not isinstance(e.get("by"), str) or not ACTOR_RE.match(e["by"]):
                    self.err("K3", rel, 0, "`verified[].by` should be an actor (`human:<id>` …)")
        s = fm.get("sources")
        if s is not None:
            if not isinstance(s, list) or not all(isinstance(e, dict) and e.get("resource") for e in s):
                self.err("K3", rel, 0, "`sources` should be a list of mappings with `resource`")

    def section(self, body, h2, name):
        names = [t for _, t in h2]
        if name not in names:
            return None
        i = names.index(name)
        lo = h2[i][0]
        hi = h2[i + 1][0] - 1 if i + 1 < len(h2) else len(body)
        return lo, mask_code(body)[lo:hi]

    def check_adr(self, rel, fm, body, h2, start, rule):
        markers = tuple(rule.get("outcome_markers", ["Chosen option"]))
        ds = fm.get("decision_status")
        if ds not in ADR_STATUS:
            self.err("A1", rel, 0, f"`decision_status` {ds!r} is not one of {tuple(ADR_STATUS)}")
        elif fm.get("status", "stable") != ADR_STATUS[ds]:
            self.err("A1", rel, 0, f"decision_status {ds} requires status {ADR_STATUS[ds]}, not {fm.get('status', 'stable')}")
        if (ds == "superseded") != bool(fm.get("superseded_by")):
            self.err("A1", rel, 0, "`superseded_by` is required exactly when decision_status is superseded")
        sec = self.section(body, h2, "Considered Options")
        if sec:
            opts = [l for l in sec[1] if re.match(r"^[*-] ", l)]
            if len(opts) < 2:
                self.err("A1", rel, start + sec[0] - 1, "`Considered Options` lists fewer than 2 options")
        sec = self.section(body, h2, "Decision Outcome")
        if sec and not any(l.startswith(mk) for l in sec[1] for mk in markers):
            self.err("A1", rel, start + sec[0] - 1, f"`Decision Outcome` has no line starting with {markers}")

    def check_backlog(self, rel, fm, body, h2, start):
        st = fm.get("state")
        if st not in BACKLOG_STATE:
            self.err("B1", rel, 0, f"`state` {st!r} is not one of {BACKLOG_STATE}")
        if "status" in fm:
            self.err("B1", rel, 0, "backlog items omit `status` (the work state is `state`)")
        if not isinstance(fm.get("depends_on", []), list):
            self.err("B1", rel, 0, "`depends_on` should be a list")
        sec = self.section(body, h2, "完了条件")
        if st == "done" and sec:
            for k, l in enumerate(sec[1]):
                if re.match(r"^\s*[*-] \[ \]", l):
                    self.err("B1", rel, start + sec[0] + k, "state is done but a completion condition is unchecked")

    def check_index(self, rel, is_root, prof):
        text = self.read(rel)
        fm_text, body, start = split_frontmatter(text)
        body = body.split("\n")
        if fm_text is not None:
            try:
                fm = parse_yaml(fm_text, 2)
            except YamlError as e:
                self.err("R1", rel, e.line, f"frontmatter is not in the YAML subset: {e}")
                fm = {}
            if not is_root:
                self.err("R1", rel, 1, "index.md below the bundle root has no frontmatter (OKF §8)")
            elif set(fm) - {"okf_version"}:
                self.err("R1", rel, 1, f"bundle-root index.md frontmatter carries only `okf_version`, not {sorted(set(fm) - {'okf_version'})}")
            elif fm.get("okf_version") != "0.2":
                self.err("R1", rel, 1, f"okf_version {fm.get('okf_version')!r} should be \"0.2\"")
        elif is_root and prof.get("okf_version"):
            self.err("R1", rel, 1, "bundle-root index.md should declare okf_version: \"0.2\"")
        seen_heading = False
        for k, line in enumerate(body):
            n = start + k
            if not line.strip():
                continue
            if re.match(r"^# \S", line):
                seen_heading = True
                continue
            m = INDEX_ENTRY_RE.match(line)
            if not m:
                self.err("R1", rel, n, "index body has only `# heading` and `* [title](path) - description` lines")
                continue
            if not seen_heading:
                self.err("R1", rel, n, "entry before the first `# heading`")
            target = urllib.parse.unquote(m.group(2).split("#")[0])
            dest = os.path.normpath(os.path.join(os.path.dirname(rel), target))
            if dest.endswith(".md") and (self.repo / dest).is_file() and dest.rsplit("/", 1)[-1] not in ("index.md", "log.md"):
                fm, _, _ = self.meta(dest)
                if fm:
                    if isinstance(fm.get("title"), str) and m.group(1) != fm["title"]:
                        self.err("I2", rel, n, f"entry title {m.group(1)!r} differs from {dest}'s title {fm['title']!r}")
                    if isinstance(fm.get("description"), str) and m.group(3) != fm["description"]:
                        self.err("I2", rel, n, f"entry description differs from {dest}'s description")

    def check_log(self, rel):
        text = self.read(rel)
        fm_text, body, start = split_frontmatter(text)
        body = body.split("\n")
        if fm_text is not None:
            self.err("R2", rel, 1, "log.md has no frontmatter (OKF §9)")
        lines = mask_code(body)
        first = next(((k, l) for k, l in enumerate(lines) if l.strip()), None)
        if not first or not re.match(r"^# \S", first[1]):
            self.err("R2", rel, start + (first[0] if first else 0), "log.md starts with a `# title`")
        prev = None
        for k, line in enumerate(lines):
            n = start + k
            m = HEADING_RE.match(line)
            if not m or (first and k == first[0]):
                continue
            if len(m.group(1)) != 2 or not DATE_RE.match(m.group(2) or ""):
                self.err("R2", rel, n, f"heading {line.strip()!r} should be `## YYYY-MM-DD`")
                continue
            try:
                d = datetime.date.fromisoformat(m.group(2))
            except ValueError:
                self.err("R2", rel, n, f"{m.group(2)} is not a valid date")
                continue
            if prev and d >= prev:
                self.err("R2", rel, n, f"{d} is not older than the previous heading {prev} (newest first, one heading per date)")
            prev = d

    # -------------------------------------------------------- リンク

    def check_links(self):
        lc = self.cfg.get("links", {})
        skip = list(self.cfg.get("skip", [])) + list(lc.get("skip", []))
        absolute = lc.get("absolute", True)
        files = []
        for r in lc.get("roots", []):
            files += self.walk(r.rstrip("/"), skip)
        for rel in sorted(set(files)):
            raw = self.read(rel).split("\n")
            for n, line in enumerate(mask_code(raw), 1):
                for m in LINK_RE.finditer(line):
                    target = m.group(3)
                    if target.startswith("<"):
                        target = target[1:-1]
                    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target):
                        continue
                    path, _, frag = target.partition("#")
                    path = urllib.parse.unquote(path)
                    if path.startswith("/"):
                        if not absolute:
                            self.err("L3", rel, n, f"link {target} starts with '/'; write a relative path")
                        continue
                    dest = os.path.normpath(os.path.join(os.path.dirname(rel), path)) if path else rel
                    if dest.startswith("..") or not (self.repo / dest).exists():
                        self.err("L1", rel, n, f"link target {target} does not exist")
                        continue
                    if frag and dest.endswith(".md") and (self.repo / dest).is_file():
                        frag = urllib.parse.unquote(frag)
                        text = self.read(dest)
                        if text is not None:
                            _, body, _ = split_frontmatter(text)
                            if frag not in anchors(body.split("\n")):
                                self.err("L2", rel, n, f"anchor #{frag} is not a heading of {dest}")

    def run(self):
        for b in self.bundles:
            self.check_bundle(b)
        self.check_links()
        return self.errs


def main_check(repo):
    c = Checker(repo)
    errs = c.run()
    for _, _, msg in errs:
        print(f"error: {msg}")
    nb = len(c.bundles)
    print(f"okf check: {'NG' if errs else 'OK'} ({nb} bundle(s), {len(errs)} error(s))")
    return 1 if errs else 0


# ---------------------------------------------------------------- 自己テスト

YAML_CASES = [
    ('type: "A"\ntags: [a, b]\n', {"type": "A", "tags": ["a", "b"]}),
    ("type: Guideline\ngenerated:\n  by: x/y\n  at: 2026-10-29T21:38:09+09:00\n",
     {"type": "Guideline", "generated": {"by": "x/y", "at": "2026-10-29T21:38:09+09:00"}}),
    ("sources:\n  - id: a\n    resource: https://x/y\n  - id: b\n", {"sources": [{"id": "a", "resource": "https://x/y"}, {"id": "b"}]}),
    ('d: ["a, b", \'c\'\'d\']  # comment\nn: 3\nz: ~\nt: true\n', {"d": ["a, b", "c'd"], "n": 3, "z": None, "t": True}),
    ('e: []\nq: "x \\"y\\" \\u3042"\n', {"e": [], "q": 'x "y" あ'}),
]
YAML_BAD = [
    "title: [Spec] foo\n",          # フローの列の後に文字
    "title: a: b\n",                # プレーンに ': '
    "g: {by: x}\n",                 # フローのマッピング
    "a: 1\na: 2\n",                 # キーの重複
    "a: |\n  x\n",                  # ブロックのスカラ
    "a: foo\n  bar\n",              # 複数行のプレーン
    "s:\n- a\n",                    # キーと同じ字下げの列
    'a: "x\n',                      # 閉じない引用符
    "- a\n",                        # トップレベルが列
    "a: [x, [y]]\n",                # 入れ子のフロー
    "a:\n\t- x\n",                  # タブ
]
SLUG_CASES = [
    ("完了の定義（機能ごと）", "完了の定義機能ごと"),
    ("OKF v0.2", "okf-v02"),
    ("`decision_status` の値", "decision_status-の値"),
    ("A・B / C", "ab--c"),
    ("[リンク](x.md) と **太字**", "リンク-と-太字"),
]


def self_test():
    fails = 0
    for src, want in YAML_CASES:
        try:
            got = parse_yaml(src)
        except YamlError as e:
            got = f"error: {e}"
        if got != want:
            print(f"self-test: yaml {src!r}: got {got!r}, want {want!r}")
            fails += 1
    for src in YAML_BAD:
        try:
            parse_yaml(src)
            print(f"self-test: yaml {src!r}: accepted, want an error")
            fails += 1
        except YamlError:
            pass
    for src, want in SLUG_CASES:
        if slug(src) != want:
            print(f"self-test: slug {src!r}: got {slug(src)!r}, want {want!r}")
            fails += 1
    cases = sorted(p for p in FIXTURES.iterdir() if p.is_dir())
    for case in cases:
        want = set()
        for line in (case / "expect.txt").read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                code, rel = line.split(None, 1)
                want.add((code, rel.strip()))
        got = {(code, rel) for code, rel, _ in Checker(case).run()}
        if got != want:
            print(f"self-test: {case.name}: missing {sorted(want - got)}, unexpected {sorted(got - want)}")
            for _, _, msg in Checker(case).run():
                print(f"  {msg}")
            fails += 1
    print(f"okf check self-test: {'NG' if fails else 'OK'} ({len(YAML_CASES) + len(YAML_BAD)} yaml, "
          f"{len(SLUG_CASES)} slug, {len(cases)} fixture case(s), {fails} failure(s))")
    return 1 if fails else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    return main_check(find_repo(argv))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
