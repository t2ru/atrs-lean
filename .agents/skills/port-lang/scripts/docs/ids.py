#!/usr/bin/env python3
"""ADR・backlog の ID（UUID v4）の採番・検査・旧番号からの書き換え（port-lang の道具。scripts/README.md）。

プロジェクト固有の値（ADR・backlog の置き場所、登録簿、検査の範囲、旧番号の対応表）は、リポジトリの
`trace/project.json` の `ids` から読む。リポジトリのルートは、作業ディレクトリから上にたどって探す（`--repo` でも指定できる）。

ID は小文字 16 進・ハイフン付きの UUID v4。ファイル名は `<ID の先頭 4 文字>-<slug>.md`（先頭 4 文字の重複は許し、
slug で区別する）。道具が読む箇所（frontmatter の `id`・`depends_on`・`superseded_by`、`trace/features.json` の
`backlog`、登録簿の backlog の列）は ID 全体を、本文・コメントは先頭 4 文字（`ADR xxxx`・`backlog xxxx`）を書く。
先頭 4 文字が同じ種類の他の項目と重なる項目は、リンク無しの本文では `ADR xxxx-<slug>` と書く。

ADR・backlog の置き場所（`ids.kinds`）は種類ごとに複数でもよい（例: プロジェクトの `docs/` と、スキルの
`references/docs/`）。ID の空間は 1 つで、参照はどの置き場所の項目にも解決する。`ids.isolated` に挙げたバンドル
（他のリポジトリへ持ち出す文書。例: スキル）は、外の項目を frontmatter で指さず、Markdown のリンクで `root` の外へ
出ない。本文の `ADR xxxx`・`backlog xxxx` で外の項目を指してよいのは、バンドルの `decision/`・`backlog/` の中と、
それを要約する `index.md`・`log.md`（来歴）だけである。

使い方:
  python3 -I <skill>/scripts/docs/ids.py new adr <slug> [--dir <dir>]   # 新しい ID とファイル名を表示する
  python3 -I <skill>/scripts/docs/ids.py new backlog <slug> [--dir <dir>]
  python3 -I <skill>/scripts/docs/ids.py check                # ID・ファイル名・参照を検査する（違反で終了コード 1）
  python3 -I <skill>/scripts/docs/ids.py move <stem> <dir>    # 項目を同じ種類の別の置き場所へ移し、リンクを張り直す
  python3 -I <skill>/scripts/docs/ids.py migrate              # 旧番号（NNNN-<slug>.md、`ADR NNNN`）を新 ID に書き換える

`--dir` を省くと、その種類の最初の置き場所に作る。`move` は `git mv` の後、リポジトリの Markdown のリンクのうち
その項目を指すものと、移した項目の中の相対リンクを張り直す。リンク以外でパスを書いた箇所は表示するので、手で直す。

`migrate` は旧番号の対応表（設定の `ids.legacy`。旧 stem → ID）を使う。表に無い旧番号のファイルには
新しい ID を振り、`--write-map` を付けたときだけ表に加える。旧番号を含むブランチを取り込んだ後に実行する。
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import uuid

def find_repo():
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
    sys.exit("ids: repository root (trace/project.json) not found")


REPO = find_repo()
# プロジェクトの設定（trace/project.json の ids。port-lang の references/docs/spec/traceability.md#プロジェクトの設定）
CFG = json.loads((REPO / "trace" / "project.json").read_text(encoding="utf-8"))["ids"]
MAP = REPO / CFG.get("legacy", "docs/legacy-ids.json")
# 種類 → 置き場所の列（設定は文字列か配列）
KINDS = {k: [v] if isinstance(v, str) else list(v) for k, v in CFG["kinds"].items()}
# 持ち出すバンドル（[{"bundle": <dir>, "root": <リンクが出てはならない範囲>}]）
ISOLATED = [{"bundle": b["bundle"].rstrip("/"), "root": b.get("root", b["bundle"]).rstrip("/")}
            for b in CFG.get("isolated", [])]
WORDS = {"adr": ("ADR",), "backlog": ("backlog", "Backlog", "バックログ")}
WORD_KIND = {w: k for k, ws in WORDS.items() for w in ws}
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
UUID_ANY = re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b")
SLUG = r"[a-z0-9]+(?:-[a-z0-9]+)*"
NAME_RE = re.compile(rf"^([0-9a-f]{{4}})-({SLUG})\.md$")
LEGACY_RE = re.compile(rf"^(\d{{4}})-({SLUG})\.md$")
# 本文の参照: `ADR xxxx`、`ADR xxxx-<slug>`、列挙 `ADR xxxx・yyyy`
REF_ITEM = rf"[0-9a-f]{{4}}(?:-{SLUG})?(?![0-9a-z])"
REF_RE = re.compile(rf"(?<![0-9A-Za-z])({'|'.join(WORD_KIND)}) ({REF_ITEM}(?:(?:・|、|, ?){REF_ITEM})*)")
LINK_RE = re.compile(r"\[([^\]\n]*)\]\(([^)\s]+)\)")
# 道具が読む ID の表（docs/spec の登録簿の backlog の列）
REGISTERS = tuple(CFG.get("registers", []))
# 本文の参照と UUID を検査する範囲（道具の自己テストの例は除く）
CHECK_ROOTS = tuple(CFG.get("check_roots", ["docs/"]))
# UUID がすべて ADR・backlog の ID であるべき範囲（コードの例の UUID は除く）
UUID_ROOTS = tuple(CFG.get("uuid_roots", ["docs/"]))
CHECK_SKIP = tuple(CFG.get("check_skip", []))


def git_files():
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=REPO, capture_output=True, text=True, check=True).stdout
    skip = tuple(CFG.get("exclude", ["upstream/"]))
    return [p for p in out.splitlines() if not p.startswith(skip) and (REPO / p).is_file()]


def read_text(rel):
    try:
        return (REPO / rel).read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    return m.group(1) if m else ""


def fm_value(fm, key):
    m = re.search(rf"^{key}:\s*(.*)$", fm, re.M)
    return m.group(1).strip() if m else None


def fm_list(fm, key):
    v = fm_value(fm, key)
    return re.findall(r'"([^"]*)"', v) if v else []


def unquote(v):
    return v.strip().strip('"') if v else v


class Items:
    """docs/decision・docs/backlog の項目（ID・stem）。"""

    def __init__(self):
        self.by_kind = {}
        for kind, ds in KINDS.items():
            items = []
            for d in ds:
                for p in sorted((REPO / d).glob("*.md")):
                    if p.name == "README.md":
                        continue
                    text = p.read_text(encoding="utf-8")
                    items.append({"path": p, "dir": d, "stem": p.stem, "id": unquote(fm_value(frontmatter(text), "id")),
                                  "text": text})
            self.by_kind[kind] = items

    def ids(self, kind):
        return {i["id"] for i in self.by_kind[kind] if i["id"]}

    def resolve(self, kind, ref):
        """`xxxx` または `xxxx-<slug>` に当たる項目の列。"""
        if len(ref) == 4:
            return [i for i in self.by_kind[kind] if i["stem"][:4] == ref]
        return [i for i in self.by_kind[kind] if i["stem"] == ref]

    def by_id(self):
        return {i["id"]: i for lst in self.by_kind.values() for i in lst if i["id"]}


def bundle_of(rel):
    """`rel`（リポジトリからの相対パス）を含む持ち出すバンドル。"""
    rel = str(rel)
    return next((b for b in ISOLATED if rel.startswith(b["root"] + "/")), None)


def in_bundle(rel, b):
    return str(rel).startswith(b["bundle"] + "/")


def short_ref(kind, uid, stem, all_ids):
    """本文の参照の形: 先頭 4 文字。同じ種類に重なりがあれば stem。"""
    return uid[:4] if sum(1 for x in all_ids[kind] if x[:4] == uid[:4]) == 1 else stem


# ---------------------------------------------------------------- new

def fresh_id(taken):
    """UUID v4。先頭 4 文字が十進の数字だけのものは、旧番号と見分けにくいので引き直す。"""
    while True:
        uid = str(uuid.uuid4())
        if uid not in taken and not uid[:4].isdigit():
            return uid


def cmd_new(kind, slug, d=None):
    if kind not in KINDS or not re.fullmatch(SLUG, slug):
        sys.exit(f"usage: ids.py new {{adr|backlog}} <slug> [--dir <dir>]（slug は英小文字・数字・ハイフン）")
    d = (d or KINDS[kind][0]).rstrip("/")
    if d not in KINDS[kind]:
        sys.exit(f"{d} is not a directory of {kind} ({', '.join(KINDS[kind])})")
    items = Items()
    taken = items.ids("adr") | items.ids("backlog")
    uid = fresh_id(taken)
    path = REPO / d / f"{uid[:4]}-{slug}.md"
    if path.exists():
        sys.exit(f"{path.relative_to(REPO)} exists")
    same = [i["stem"] for i in items.by_kind[kind] if i["stem"][:4] == uid[:4]]
    print(f"id: \"{uid}\"")
    print(f"path: {path.relative_to(REPO)}")
    print(f"ref: {WORDS[kind][0]} {uid[:4] if not same else path.stem}")
    if same:
        print(f"note: 先頭 4 文字が {', '.join(same)} と重なる。リンク無しの本文では stem で参照する")


# ---------------------------------------------------------------- check

def cmd_check():
    errs = []
    items = Items()
    all_ids = {k: items.ids(k) for k in KINDS}
    by_id = items.by_id()
    seen = {}
    for kind, lst in items.by_kind.items():
        for it in lst:
            rel = it["path"].relative_to(REPO)
            if not NAME_RE.match(it["path"].name):
                errs.append(f"{rel}: file name is not <4 hex>-<slug>.md")
            uid = it["id"]
            if not uid or not UUID_RE.match(uid):
                errs.append(f"{rel}: frontmatter id {uid!r} is not a lowercase UUID v4")
                continue
            if uid[:4] != it["stem"][:4]:
                errs.append(f"{rel}: file name prefix differs from id {uid}")
            if uid in seen:
                errs.append(f"{rel}: id {uid} is also used by {seen[uid]}")
            seen[uid] = rel
            fm = frontmatter(it["text"])
            b = bundle_of(rel)
            refs = []
            if kind == "backlog":
                for d in fm_list(fm, "depends_on"):
                    if d not in all_ids["backlog"]:
                        errs.append(f"{rel}: depends_on {d!r} is not a backlog id")
                    refs.append(("depends_on", d))
            sb = unquote(fm_value(fm, "superseded_by"))
            if sb and sb not in all_ids["adr"]:
                errs.append(f"{rel}: superseded_by {sb!r} is not an ADR id")
            if sb:
                refs.append(("superseded_by", sb))
            for key, u in refs:
                tgt = by_id.get(u)
                if b and tgt and not in_bundle(tgt["path"].relative_to(REPO), b):
                    errs.append(f"{rel}: {key} {tgt['stem']} is outside the bundle {b['bundle']}")
    feats = json.loads((REPO / CFG.get("features", "trace/features.json")).read_text(encoding="utf-8"))
    for f in feats["features"]:
        for b in f.get("backlog", []):
            if b not in all_ids["backlog"]:
                errs.append(f"trace/features.json: {f['name']}: backlog {b!r} is not a backlog id")
    every = all_ids["adr"] | all_ids["backlog"]
    for rel in git_files():
        if not rel.startswith(CHECK_ROOTS) or rel.startswith(CHECK_SKIP):
            continue
        text = read_text(rel)
        if text is None:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            errs += [f"{rel}:{n}: {e}" for e in check_line(rel, line, items, every)]
    for e in errs:
        print(f"error: {e}")
    print(f"ids check: {'NG' if errs else 'OK'} ({len(all_ids['adr'])} ADR, {len(all_ids['backlog'])} backlog, "
          f"{len(errs)} error(s))")
    return 1 if errs else 0


def check_line(rel, line, items, every):
    errs = []
    b = bundle_of(rel)
    # 来歴として外の項目を本文で挙げてよいのは、バンドルの decision/・backlog/ と、それを要約する index.md・log.md だけ
    history = b and (any(rel.startswith(d + "/") for ds in KINDS.values() for d in ds if d.startswith(b["bundle"] + "/"))
                     or rel in (f"{b['bundle']}/index.md", f"{b['bundle']}/log.md"))
    for u in UUID_ANY.findall(line) if rel.startswith(UUID_ROOTS) else []:
        if u not in every:
            errs.append(f"UUID {u} is not an ADR or backlog id")
    if rel in REGISTERS and line.startswith("|"):
        last = [c.strip() for c in line.strip().strip("|").split("|")][-1]
        if re.fullmatch(r"\d{4}", last):
            errs.append(f"register backlog column {last!r} is a legacy number")
    # インラインのコード（`…`）の中は例として扱い、参照の検査から外す
    raw, line = line, re.sub(r"`[^`]*`", lambda m: " " * len(m.group(0)), line)
    masked = line
    for m in LINK_RE.finditer(line):
        text, target = m.group(1), m.group(2)
        path = target.split("#")[0]
        if b and rel.endswith(".md") and path and not re.match(r"^[a-z][a-z0-9+.-]*:", path):
            dest = os.path.normpath(os.path.join(os.path.dirname(rel), path))
            if not (dest + "/").startswith(b["root"] + "/"):
                errs.append(f"link target {target} leaves {b['root']}")
        tkind = next((k for k, ds in KINDS.items() for d in ds if f"{pathlib.PurePosixPath(d).name}/" in path
                      or (rel.startswith(d + "/") and "/" not in path)), None)
        if path.endswith(".md") and tkind and rel.endswith(".md"):
            if not (REPO / rel).parent.joinpath(path).resolve().is_file():
                errs.append(f"link target {target} does not exist")
            stem = pathlib.PurePosixPath(path).stem
            r = re.fullmatch(rf"(?:(?:{'|'.join(WORD_KIND)}) )?({REF_ITEM})", text)
            if r and not stem.startswith(r.group(1)):
                errs.append(f"link text {text!r} does not match {target}")
            if r and " " in text and WORD_KIND[text.split(" ")[0]] != tkind:
                errs.append(f"link text {text!r} names another kind than {target}")
            if r:
                masked = masked.replace(m.group(0), " " * len(m.group(0)), 1)
    for m in REF_RE.finditer(masked):
        kind = WORD_KIND[m.group(1)]
        for ref in re.split(r"・|、|, ?", m.group(2)):
            found = items.resolve(kind, ref)
            if not found:
                errs.append(f"{m.group(1)} {ref}: no such {kind}")
            elif len(found) > 1:
                errs.append(f"{m.group(1)} {ref}: ambiguous ({', '.join(i['stem'] for i in found)}); write the stem")
            elif b and not history and not in_bundle(found[0]["path"].relative_to(REPO), b):
                errs.append(f"{m.group(1)} {ref}: refers to an item outside the bundle {b['bundle']}")
    for m in re.finditer(rf"(?<![\w.])(?:docs/)?(decision|backlog)/([0-9a-z]{{4}}-{SLUG})\.md", raw):
        dirs = [d for ds in KINDS.values() for d in ds if pathlib.PurePosixPath(d).name == m.group(1)]
        if not any((REPO / d / f"{m.group(2)}.md").is_file() for d in dirs):
            errs.append(f"path {m.group(0)} does not exist")
    return errs


# ---------------------------------------------------------------- migrate

def load_map():
    if MAP.is_file():
        return json.loads(MAP.read_text(encoding="utf-8"))
    return {k: {} for k in KINDS}


def cmd_migrate(write_map):
    legacy = load_map()
    note = legacy.pop("note", None)
    items = Items()
    taken = items.ids("adr") | items.ids("backlog") | {u for k in KINDS for u in legacy[k].values()}
    renames = []  # (kind, old stem, new stem, uid)
    for kind, ds in KINDS.items():
        for d in ds:
            for p in sorted((REPO / d).glob("*.md")):
                m = LEGACY_RE.match(p.name)
                if not m:
                    continue
                uid = legacy[kind].get(p.stem)
                if not uid:
                    uid = fresh_id(taken)
                    taken.add(uid)
                    legacy[kind][p.stem] = uid
                renames.append((kind, d, p.stem, f"{uid[:4]}-{m.group(2)}", uid))
    # 番号 → ID: 木にある旧番号のファイルを優先し、無ければ対応表
    num = {k: {} for k in KINDS}
    for kind in KINDS:
        for stem, uid in legacy[kind].items():
            num[kind].setdefault(stem[:4], uid)
        for k2, _, old, _, uid in renames:
            if k2 == kind:
                num[kind][old[:4]] = uid
    stems = {k: {} for k in KINDS}  # 旧 stem → 新 stem
    for kind in KINDS:
        for old, uid in legacy[kind].items():
            stems[kind][old] = f"{uid[:4]}-{old[5:]}"
    all_ids = {k: items.ids(k) | set(legacy[k].values()) for k in KINDS}
    new_stem = {u: s for k in KINDS for s, u in ((v, legacy[k][o]) for o, v in stems[k].items())}

    for kind, d, old, new, uid in renames:
        if (REPO / d / f"{new}.md").exists():
            sys.exit(f"{d}/{new}.md exists")
        subprocess.run(["git", "mv", f"{d}/{old}.md", f"{d}/{new}.md"], cwd=REPO, check=True)

    def short(kind, n):
        uid = num[kind].get(n)
        return short_ref(kind, uid, new_stem[uid], all_ids) if uid else None

    changed, leftovers = 0, []
    for rel in git_files():
        if rel == str(MAP.relative_to(REPO)):
            continue
        text = read_text(rel)
        if text is None:
            continue
        out = rewrite(rel, text, num, stems, short, new_stem, all_ids)
        if out != text:
            (REPO / rel).write_text(out, encoding="utf-8")
            changed += 1
        for n, line in enumerate(out.splitlines(), 1):
            if re.search(r"(?<![\w.+/:#-])00\d\d(?![\w/])", line) and rel.startswith(("docs/", "AGENTS", "tools/", "lean/", ".agents/", "trace/features")):
                leftovers.append(f"{rel}:{n}: {line.strip()[:160]}")
    add_adr_ids(legacy)
    if write_map:
        data = {"note": note or "旧番号の stem → ID（scripts/README.md）。port-lang の scripts/docs/ids.py migrate が使う。", **legacy}
        MAP.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"migrate: renamed {len(renames)} file(s), rewrote {changed} file(s)")
    if leftovers:
        print(f"migrate: {len(leftovers)} line(s) still contain a 4-digit number; review them:")
        for l in leftovers:
            print(f"  {l}")
    return 0


def rewrite(rel, text, num, stems, short, new_stem, all_ids):
    in_kind = next((k for k, ds in KINDS.items() for d in ds if rel.startswith(d + "/") and not rel.endswith("README.md")),
                   None)
    if in_kind:
        text = rewrite_frontmatter(in_kind, text, num)
    # 数字だけのリンク文字列 `[0031](…/0031-slug.md)`
    def link_num(m):
        stem = m.group(3)
        kind = next((k for k in KINDS if stem in stems[k]), None)
        if not kind or m.group(1) != stem[:4]:
            return m.group(0)
        return f"[{short(kind, stem[:4])}]({m.group(2)}{m.group(3)}{m.group(4)})"
    text = re.sub(rf"\[(\d{{4}})\]\(([^)\s]*?)(\d{{4}}-{SLUG})(\.md[^)\s]*)\)", link_num, text)
    # 旧 stem → 新 stem
    text = re.sub(rf"(?<![0-9A-Za-z])\d{{4}}-{SLUG}", lambda m: stem_sub_longest(m, stems), text)
    # 本文の `ADR NNNN`・列挙・範囲
    item = r"\d{4}(?![0-9])"
    sep = r"\s?(?:・|、|,|〜|–|~)\s?"
    pat = re.compile(rf"(?<![0-9A-Za-z])({'|'.join(WORD_KIND)})( ?)({item}(?:{sep}{item})*)")

    def words(m):
        kind = WORD_KIND[m.group(1)]
        parts = re.split(rf"({sep})", m.group(3))
        nums, seps = parts[0::2], parts[1::2] + [""]
        groups, i = [], 0  # (番号の列, 後ろの区切り)
        while i < len(nums):
            if seps[i].strip() in ("〜", "–", "~"):
                groups.append((sorted(n for n in num[kind] if nums[i] <= n <= nums[i + 1]), seps[i + 1]))
                i += 2
            else:
                groups.append(([nums[i]], seps[i]))
                i += 1
        res = []
        for ns, s in groups:
            conv = [short(kind, n) for n in ns]
            if not conv or any(c is None for c in conv):
                return m.group(0)
            res.append("・".join(conv) + s)
        return f"{m.group(1)}{m.group(2) or ' '}{''.join(res)}"
    text = pat.sub(words, text)
    # 道具が読む ID
    if rel == "trace/features.json":
        text = re.sub(r'("backlog": \[)([^\]]*)(\])',
                      lambda m: m.group(1) + re.sub(r'"(\d{4})"', lambda n: f'"{num["backlog"].get(n.group(1), n.group(1))}"',
                                                    m.group(2)) + m.group(3), text)
    if rel in REGISTERS:
        def reg(m):
            return m.group(1) + num["backlog"].get(m.group(2), m.group(2)) + m.group(3)
        text = re.sub(r"^(\|.*\| )(\d{4})( \|)$", reg, text, flags=re.M)
    if rel == CFG.get("backlog_index", "docs/backlog/README.md"):
        def row(m):
            cells = m.group(0).strip().strip("|").split("|")
            cells = [c.strip() for c in cells]
            cells[0] = short("backlog", cells[0]) or cells[0]
            deps = []
            for n in re.findall(r"\d{4}", cells[-1]):
                uid = num["backlog"].get(n)
                deps.append(f"[{short('backlog', n)}]({new_stem[uid]}.md)" if uid else n)
            if deps:
                cells[-1] = ", ".join(deps)
            return "| " + " | ".join(cells) + " |"
        text = re.sub(r"^\| \d{4} \|.*\|$", row, text, flags=re.M)
    return text


def stem_sub_longest(m, stems):
    s = m.group(0)
    # 正規表現は slug を貪欲に取るので、後ろの語が付いた場合は既知の stem の最長一致に戻す
    for k in KINDS:
        cands = [o for o in stems[k] if s == o or s.startswith(o + "-")]
        if cands:
            o = max(cands, key=len)
            return stems[k][o] + s[len(o):]
    return s


def rewrite_frontmatter(kind, text, num):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return text
    fm = m.group(1)

    def full(k, n):
        return num[k].get(n, n)
    fm = re.sub(r'^id:\s*"(\d{4})"', lambda x: f'id: "{full(kind, x.group(1))}"', fm, flags=re.M)
    fm = re.sub(r"^(depends_on:\s*)(\[.*\])$",
                lambda x: x.group(1) + re.sub(r'"(\d{4})"', lambda n: f'"{full("backlog", n.group(1))}"', x.group(2)),
                fm, flags=re.M)
    fm = re.sub(r'^superseded_by:\s*"?(\d{4})"?\s*$', lambda x: f'superseded_by: "{full("adr", x.group(1))}"', fm,
                flags=re.M)
    return text[:m.start(1)] + fm + text[m.end(1):]


def add_adr_ids(legacy):
    """id の無い ADR の frontmatter に、対応表から引いた id を `tags:` の後に加える。"""
    by_new = {f"{u[:4]}-{o[5:]}": u for o, u in legacy["adr"].items()}
    for p in sorted(q for d in KINDS["adr"] for q in (REPO / d).glob("*.md")):
        text = p.read_text(encoding="utf-8")
        fm = frontmatter(text)
        if fm_value(fm, "id") or p.stem not in by_new:
            continue
        text = re.sub(r"^(tags:.*\n)", lambda m: m.group(1) + f'id: "{by_new[p.stem]}"\n', text, count=1, flags=re.M)
        p.write_text(text, encoding="utf-8")


# ---------------------------------------------------------------- move

def cmd_move(stem, dest):
    dest = dest.rstrip("/")
    items = Items()
    found = [(k, i) for k, lst in items.by_kind.items() for i in lst if i["stem"] == stem]
    if len(found) != 1:
        sys.exit(f"move: {stem}: {'no such item' if not found else 'ambiguous'}")
    kind, it = found[0]
    if dest not in KINDS[kind]:
        sys.exit(f"move: {dest} is not a directory of {kind} ({', '.join(KINDS[kind])})")
    old = str(it["path"].relative_to(REPO))
    new = f"{dest}/{stem}.md"
    if old == new:
        sys.exit(f"move: {stem} is already in {dest}")
    (REPO / dest).mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "mv", old, new], cwd=REPO, check=True)

    def relink(rel, text, base_old):
        """`base_old` から見た相対リンクを、`rel` の位置から見た相対リンクに直す（old → new を含む）。"""
        def sub(m):
            label, target = m.group(1), m.group(2)
            path, frag = (target.split("#", 1) + [""])[:2]
            if not path or re.match(r"^[a-z][a-z0-9+.-]*:", path) or path.startswith("/"):
                return m.group(0)
            dst = os.path.normpath(os.path.join(os.path.dirname(base_old), path))
            if dst == old:
                dst = new
            elif base_old == rel:
                return m.group(0)
            out = os.path.relpath(dst, os.path.dirname(rel) or ".")
            return f"[{label}]({out}{'#' + frag if frag else ''})"
        return LINK_RE.sub(sub, text)

    changed, mentions = 0, []
    for rel in git_files():
        text = read_text(rel)
        if text is None:
            continue
        if rel == new:
            out = relink(rel, text, old)
        elif rel.endswith(".md"):
            out = relink(rel, text, rel)
        else:
            out = text
        if out != text:
            (REPO / rel).write_text(out, encoding="utf-8")
            changed += 1
        for n, line in enumerate(out.splitlines(), 1):
            if stem in LINK_RE.sub("", line):
                mentions.append(f"{rel}:{n}: {line.strip()[:160]}")
    print(f"move: {old} -> {new}; rewrote links in {changed} file(s)")
    if mentions:
        print(f"move: {len(mentions)} line(s) name {stem} outside links; review them:")
        for l in mentions:
            print(f"  {l}")
    return 0


def main(argv):
    d = None
    if "--dir" in argv:
        i = argv.index("--dir")
        d = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if len(argv) >= 2 and argv[1] == "new" and len(argv) == 4:
        cmd_new(argv[2], argv[3], d)
        return 0
    if argv[1:] == ["check"]:
        return cmd_check()
    if len(argv) == 4 and argv[1] == "move":
        return cmd_move(argv[2], argv[3])
    if len(argv) >= 2 and argv[1] == "migrate":
        return cmd_migrate("--write-map" in argv[2:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
