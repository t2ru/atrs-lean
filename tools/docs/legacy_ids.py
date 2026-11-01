#!/usr/bin/env python3
"""ATRS の ADR・backlog の旧番号（`NNNN-<slug>.md`、`ADR NNNN`）の書き換えと検査（ATRS 固有の道具）。

ADR f57e で、ADR・backlog の番号を UUID v4 に改めた。その移行のための道具を、スキル work-records の ids.py から
ATRS に移したもの。対応表は `tools/docs/legacy-ids.json`（旧 stem → ID）。ID の置き場所などの設定は
`.work-records.json` を、共通の処理（項目の読み込み・採番・参照の形）はスキル work-records の `scripts/ids.py` を使う。

使い方（リポジトリのルートで）:
  uv run python -I tools/docs/legacy_ids.py check               # 登録簿の backlog の列に旧番号が無いこと（違反で終了コード 1）
  uv run python -I tools/docs/legacy_ids.py migrate [--write-map]  # 旧番号を新 ID に書き換える

`migrate` は、旧番号を含むブランチを取り込んだ後に実行する。表に無い旧番号のファイルには新しい ID を振り、
`--write-map` を付けたときだけ表に加える。
"""
import importlib.util
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    "work_records_ids", ROOT / ".agents" / "skills" / "work-records" / "scripts" / "ids.py")
sys.argv[1:1] = ["--repo", str(ROOT)]  # ids.py が読んで取り除く
ids = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ids)
REPO, KINDS, SLUG, WORD_KIND = ids.REPO, ids.KINDS, ids.SLUG, ids.WORD_KIND
Items, fresh_id, short_ref, git_files, read_text = ids.Items, ids.fresh_id, ids.short_ref, ids.git_files, ids.read_text
frontmatter, fm_value = ids.frontmatter, ids.fm_value

MAP = REPO / "tools" / "docs" / "legacy-ids.json"
LEGACY_RE = re.compile(rf"^(\d{{4}})-({SLUG})\.md$")
# 道具が読む ID の表（docs/spec の登録簿の backlog の列）と、ID を書く JSON・索引
REGISTERS = ("docs/spec/abstraction.md", "docs/spec/refinement.md")
FEATURES = "trace/features.json"
BACKLOG_INDEX = "docs/backlog/README.md"


def cmd_check():
    errs = []
    for rel in REGISTERS:
        for n, line in enumerate((REPO / rel).read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("|"):
                last = [c.strip() for c in line.strip().strip("|").split("|")][-1]
                if re.fullmatch(r"\d{4}", last):
                    errs.append(f"{rel}:{n}: register backlog column {last!r} is a legacy number")
    for e in errs:
        print(f"error: {e}")
    print(f"legacy ids check: {'NG' if errs else 'OK'} ({len(errs)} error(s))")
    return 1 if errs else 0


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
        data = {"note": note or "旧番号の stem → ID（ADR f57e）。tools/docs/legacy_ids.py migrate が使う。", **legacy}
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
    if rel == FEATURES:
        text = re.sub(r'("(?:backlog|source|target)": \[)([^\]]*)(\])',
                      lambda m: m.group(1) + re.sub(r'"(\d{4})"', lambda n: f'"{num["backlog"].get(n.group(1), n.group(1))}"',
                                                    m.group(2)) + m.group(3), text)
    if rel in REGISTERS:
        def reg(m):
            return m.group(1) + num["backlog"].get(m.group(2), m.group(2)) + m.group(3)
        text = re.sub(r"^(\|.*\| )(\d{4})( \|)$", reg, text, flags=re.M)
    if rel == BACKLOG_INDEX:
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


def main(argv):
    if argv[1:] == ["check"]:
        return cmd_check()
    if len(argv) >= 2 and argv[1] == "migrate":
        return cmd_migrate("--write-map" in argv[2:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
