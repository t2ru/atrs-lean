#!/usr/bin/env python3
"""ADR・backlog の ID（UUID v4）の採番・検査・移動（スキル work-records の道具。SKILL.md）。

リポジトリ固有の値（ADR・backlog の置き場所、持ち出すバンドル、検査の範囲、ID を書く JSON の欄）は、リポジトリの
ルートの設定ファイル `.work-records.json` から読む（形は references/docs/rules/records.md#設定）。リポジトリのルートは、
作業ディレクトリから上にたどって `.work-records.json` があるところとする（`--repo` でも指定できる）。

ID は小文字 16 進・ハイフン付きの UUID v4。ファイル名は `<ID の先頭 4 文字>-<slug>.md`（先頭 4 文字の重複は許し、
slug で区別する）。道具が読む箇所（frontmatter の `id`・`depends_on`・`superseded_by`、設定の `id_fields` が挙げる
JSON の欄）は ID 全体を、本文・コメントは先頭 4 文字（`ADR xxxx`・`backlog xxxx`）を書く。
先頭 4 文字が同じ種類の他の項目と重なる項目は、リンク無しの本文では `ADR xxxx-<slug>` と書く。

ADR・backlog の置き場所（`kinds`）は種類ごとに複数でもよい（例: プロジェクトの `docs/` と、スキルの
`references/docs/`）。ID の空間は 1 つで、参照はどの置き場所の項目にも解決する。`isolated` に挙げたバンドル
（他のリポジトリへ持ち出す文書。例: スキル）は、外の項目を frontmatter で指さず、Markdown のリンクで `root` の外へ
出ない。本文の `ADR xxxx`・`backlog xxxx` で外の項目を指してよいのは、バンドルの `decision/`・`backlog/` の中と、
それを要約する `index.md`・`log.md`（来歴）だけである。

`check` は、ID と参照に加えて、記録の形を検査する。
  A1  ADR: `decision_status` の値と OKF の `status` の対応、`superseded_by` は `superseded` のときだけ、
      `Considered Options` に選択肢が 2 つ以上、`Decision Outcome` に採択を示す行（設定の `outcome_markers` で
      始まる行。既定は `Chosen option`）
  B1  backlog: `state` の値、`status` を持たない、`depends_on` はフローの列、`done` の項目に未完了の完了条件が無い
節の有無と順序、必須のキーは、OKF のプロファイル（スキル okf-bundle の okf_check.py）で検査する。

使い方:
  uv run python -I <work-records>/scripts/ids.py new adr <slug> [--dir <dir>]   # 新しい ID とファイル名を表示する
  uv run python -I <work-records>/scripts/ids.py new backlog <slug> [--dir <dir>]
  uv run python -I <work-records>/scripts/ids.py check                # ID・ファイル名・参照・記録の形を検査する（違反で終了コード 1）
  uv run python -I <work-records>/scripts/ids.py move <stem> <dir>    # 項目を同じ種類の別の置き場所へ移し、リンクを張り直す
  uv run python -I <work-records>/scripts/ids.py --self-test          # 違反例（scripts/fixtures/）を検出できることを確かめる

`--dir` を省くと、その種類の最初の置き場所に作る。`move` は `git mv` の後、リポジトリの Markdown のリンクのうち
その項目を指すものと、移した項目の中の相対リンクを張り直す。リンク以外でパスを書いた箇所は表示するので、手で直す。
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

CONFIG = ".work-records.json"
HERE = pathlib.Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"

# ---------------------------------------------------------------- 自己テスト

def self_test():
    """`fixtures/<case>/` を一時の git リポジトリに写して `check` を実行し、`expect.txt` と突き合わせる。

    `expect.txt` の各行は `<ファイル> <メッセージの一部>`（`#` で始まる行は注釈）。期待の各行がちょうど 1 つの誤りに当たり、
    当たらない誤りが無ければ合格とする。
    """
    fails, cases = 0, sorted(p for p in FIXTURES.iterdir() if p.is_dir())
    for case in cases:
        want = [l.split(None, 1) for l in (case / "expect.txt").read_text(encoding="utf-8").splitlines()
                if l.strip() and not l.startswith("#")]
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp) / case.name
            shutil.copytree(case, repo)
            (repo / "expect.txt").unlink()
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            out = subprocess.run([sys.executable, "-I", __file__, "--repo", str(repo), "check"],
                                 capture_output=True, text=True).stdout
        errs = [l[len("error: "):] for l in out.splitlines() if l.startswith("error: ")]
        left = list(errs)
        for w in want:
            hit = [e for e in left if e.startswith(w[0]) and (len(w) == 1 or w[1] in e)]
            if len(hit) != 1:
                print(f"self-test: {case.name}: {' '.join(w)!r} matched {len(hit)} error(s)")
                fails += 1
            else:
                left.remove(hit[0])
        for e in left:
            print(f"self-test: {case.name}: unexpected error: {e}")
            fails += 1
        if (out.rstrip().splitlines() or [""])[-1].startswith("ids check: NG") != bool(want):
            print(f"self-test: {case.name}: wrong verdict: {out.rstrip().splitlines()[-1:]}")
            fails += 1
    print(f"ids self-test: {'NG' if fails else 'OK'} ({len(cases)} fixture case(s), {fails} failure(s))")
    return 1 if fails else 0


if __name__ == "__main__" and sys.argv[1:] == ["--self-test"]:
    sys.exit(self_test())


# ---------------------------------------------------------------- 設定

def find_repo():
    """`--repo <dir>` か、作業ディレクトリから上にたどって `.work-records.json` があるところ。"""
    if "--repo" in sys.argv:
        i = sys.argv.index("--repo")
        root = pathlib.Path(sys.argv[i + 1]).resolve()
        del sys.argv[i:i + 2]
        return root
    d = pathlib.Path.cwd().resolve()
    for c in (d, *d.parents):
        if (c / CONFIG).is_file():
            return c
    sys.exit(f"ids: repository root ({CONFIG}) not found")


REPO = find_repo()
# リポジトリの設定（references/docs/rules/records.md#設定）
CFG = json.loads((REPO / CONFIG).read_text(encoding="utf-8"))
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
# 本文の参照: `ADR xxxx`、`ADR xxxx-<slug>`、列挙 `ADR xxxx・yyyy`
REF_ITEM = rf"[0-9a-f]{{4}}(?:-{SLUG})?(?![0-9a-z])"
REF_RE = re.compile(rf"(?<![0-9A-Za-z])({'|'.join(WORD_KIND)}) ({REF_ITEM}(?:(?:・|、|, ?){REF_ITEM})*)")
LINK_RE = re.compile(r"\[([^\]\n]*)\]\(([^)\s]+)\)")
# ID を書く JSON の欄（[{"file": <path>, "keys": [<key>...], "kind": "adr" | "backlog"}]）
ID_FIELDS = CFG.get("id_fields", [])
# ADR の `Decision Outcome` で採択を示す行の書き出し
OUTCOME_MARKERS = tuple(CFG.get("outcome_markers", ["Chosen option"]))
ADR_STATUS = {"proposed": "draft", "accepted": "stable", "rejected": "deprecated",
              "deprecated": "deprecated", "superseded": "deprecated"}
BACKLOG_STATE = ("todo", "doing", "blocked", "done", "dropped")
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
            errs += [f"{rel}: {e}" for e in check_form(kind, fm, it["text"])]
    for spec in ID_FIELDS:
        data = json.loads((REPO / spec["file"]).read_text(encoding="utf-8"))
        for key, v in json_fields(data, set(spec["keys"])):
            if v not in all_ids[spec["kind"]]:
                errs.append(f"{spec['file']}: {key} {v!r} is not {'an ADR' if spec['kind'] == 'adr' else 'a backlog'} id")
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


def json_fields(data, keys, key=None):
    """JSON の値の中で、`keys` のどれかのキーの下にある文字列を（キー, 値）の列で返す（入れ子の列・写像もたどる）。"""
    if isinstance(data, dict):
        for k, v in data.items():
            yield from json_fields(v, keys, k if k in keys else key)
    elif isinstance(data, list):
        for v in data:
            yield from json_fields(v, keys, key)
    elif isinstance(data, str) and key is not None:
        yield key, data


def sections(text):
    """frontmatter の後の本文の `##` 節（コードブロックの外）。{見出し: 行の列}。"""
    m = re.match(r"^---\n.*?\n---\n", text, re.S)
    out, cur, fence = {}, None, None
    for line in text[m.end() if m else 0:].splitlines():
        f = re.match(r"^\s*(```|~~~)", line)
        if f:
            fence = None if fence == f.group(1) else (fence or f.group(1))
        elif fence is None and line.startswith("## "):
            cur = line[3:].strip()
            out.setdefault(cur, [])
            continue
        if cur is not None:
            out[cur].append(line)
    return out


def check_form(kind, fm, text):
    """記録の形（A1・B1）。"""
    errs = []
    secs = sections(text)
    if kind == "adr":
        ds, st = unquote(fm_value(fm, "decision_status")), unquote(fm_value(fm, "status")) or "stable"
        if ds not in ADR_STATUS:
            errs.append(f"A1: decision_status {ds!r} is not one of {tuple(ADR_STATUS)}")
        elif st != ADR_STATUS[ds]:
            errs.append(f"A1: decision_status {ds} requires status {ADR_STATUS[ds]}, not {st}")
        if (ds == "superseded") != bool(unquote(fm_value(fm, "superseded_by"))):
            errs.append("A1: superseded_by is required exactly when decision_status is superseded")
        if "Considered Options" in secs and sum(1 for l in secs["Considered Options"] if re.match(r"^[*-] ", l)) < 2:
            errs.append("A1: Considered Options lists fewer than 2 options")
        if "Decision Outcome" in secs and not any(l.startswith(OUTCOME_MARKERS) for l in secs["Decision Outcome"]):
            errs.append(f"A1: Decision Outcome has no line starting with {OUTCOME_MARKERS}")
    elif kind == "backlog":
        st = unquote(fm_value(fm, "state"))
        if st not in BACKLOG_STATE:
            errs.append(f"B1: state {st!r} is not one of {BACKLOG_STATE}")
        if fm_value(fm, "status") is not None:
            errs.append("B1: backlog items omit status (the work state is state)")
        dep = fm_value(fm, "depends_on")
        if dep is not None and not re.fullmatch(r"\[.*\]", dep):
            errs.append("B1: depends_on should be a flow list [...]")
        if st == "done" and any(re.match(r"^\s*[*-] \[ \]", l) for l in secs.get("完了条件", [])):
            errs.append("B1: state is done but a completion condition is unchecked")
    return errs


def check_line(rel, line, items, every):
    errs = []
    b = bundle_of(rel)
    # 来歴として外の項目を本文で挙げてよいのは、バンドルの decision/・backlog/ と、それを要約する index.md・log.md だけ
    history = b and (any(rel.startswith(d + "/") for ds in KINDS.values() for d in ds if d.startswith(b["bundle"] + "/"))
                     or rel in (f"{b['bundle']}/index.md", f"{b['bundle']}/log.md"))
    for u in UUID_ANY.findall(line) if rel.startswith(UUID_ROOTS) else []:
        if u not in every:
            errs.append(f"UUID {u} is not an ADR or backlog id")
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
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
