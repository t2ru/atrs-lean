#!/usr/bin/env python3
"""Lean の宣言・モジュールの完全名を、リポジトリのテキストの中で一度に書き換える（spec-pivot の道具。scripts/README.md）。

使い方:
  python3 -I <skill>/scripts/lean/rename.py apply <map.json> [--dry-run] [<path> ...]
  python3 -I <skill>/scripts/lean/rename.py check <map.json> [<path> ...]
  python3 -I <skill>/scripts/lean/rename.py --self-test

`<map.json>` は `{"<旧い完全名>": "<新しい完全名>", ...}`（または `{"renames": {...}}`）。名前空間の接頭辞を
書けば、その下の名前もまとめて写る（`Test.Trace.ObFix` → `Test.Trace.ObligationFixture`）。モジュール名も同じ表に書ける
（`import` の行・文書の言及を書き換える。ファイルの移動は `git mv` で別に行う）。

- 一致は Lean の識別子の境界で判定する。直前が識別子の文字か `.` なら一致しない（`SourceModel.Spec.X` の `Spec.X` は
  書き換えない）。直後が識別子の文字（`?`・`!`・`'`・下付き文字を含む）なら一致しない（`getStr` は `getStr?` に当たらない）。
  直後が `.` なら一致する（`Spec.FlightType` は `Spec.FlightType.OW` も写す）。名前リテラルの `` ` ``・`` `` `` の後も一致する。
- 表の名前は長いものから順に試し、1 回の走査で写す（写した結果を再び写さない）。
- 対象は、`<path>`（省略時はリポジトリのルート）の下の `.lean`・`.md`・`.json`・`.py`・`.rs`・`.sh`・`.toml`・`.yml`。
  `.git`・`.lake`・`target`・`upstream` は除く。リポジトリのルートは `git rev-parse --show-toplevel` で決める。
- `check` は旧い名前の残りを列挙し、あれば終了コード 1 を返す（新しい名前が旧い名前で始まる組は、新しい名前の出現を除いて数える）。
"""
import json
import pathlib
import re
import subprocess
import sys
import tempfile

EXTS = {".lean", ".md", ".json", ".py", ".rs", ".sh", ".toml", ".yml"}
SKIP_DIRS = {".git", ".lake", "target", "upstream", "node_modules", "__pycache__"}
# 識別子の文字（Lean の識別子に現れうる文字の近似。英数字・_・'・!・?・下付き・ギリシャ文字など）
ID_CH = r"[\w'!?₀-₉ₐ-ₜ«»]"


def load_map(path):
    m = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    if isinstance(m, dict) and "renames" in m and isinstance(m["renames"], dict):
        m = m["renames"]
    if not isinstance(m, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in m.items()):
        sys.exit("rename: the map must be a JSON object of strings")
    return {k: v for k, v in m.items() if k != v}


def pattern(names):
    alts = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    # 直前: 識別子の文字（英数字・_）か `.` なら一致しない（`'`・`!`・`?` の後は名前の始まりでありうる）
    return re.compile(rf"(?<![\w.])({alts})(?!{ID_CH})")


def rewrite(text, m, rx):
    return rx.sub(lambda mo: m[mo.group(1)], text)


def files(paths):
    for p in paths:
        p = pathlib.Path(p)
        if p.is_file():
            yield p
            continue
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.suffix in EXTS and not (set(f.relative_to(p).parts[:-1]) & SKIP_DIRS):
                yield f


def repo_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return pathlib.Path(out.stdout.strip()) if out.returncode == 0 else pathlib.Path.cwd()


def apply(m, paths, dry):
    rx = pattern(m)
    changed = 0
    for f in files(paths):
        try:
            s = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        t = rewrite(s, m, rx)
        if t != s:
            changed += 1
            n = len(rx.findall(s))
            print(f"rename: {f} ({n})")
            if not dry:
                f.write_text(t, encoding="utf-8")
    print(f"rename: {changed} file(s){' (dry run)' if dry else ''}")
    return 0


def check(m, paths):
    rx = pattern(m)
    # 新しい名前が旧い名前の下にある組（`A.x` → `A.x.y`）は、新しい名前の出現を数えない
    news = sorted(set(m.values()), key=len, reverse=True)
    rx_new = pattern(news) if news else None
    left = 0
    for f in files(paths):
        try:
            s = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        masked = rx_new.sub(lambda mo: " " * len(mo.group(0)), s) if rx_new else s
        for mo in rx.finditer(masked):
            line = s.count("\n", 0, mo.start()) + 1
            print(f"rename: {f}:{line}: {mo.group(1)} → {m[mo.group(1)]}")
            left += 1
    print(f"rename: {left} remaining occurrence(s) of old names")
    return 1 if left else 0


def self_test():
    m = {"Spec.FlightType": "Spec.Model.FlightType", "A.getStr": "A.R.getStr", "A.x": "A.x.y",
         "Old.Mod": "New.Mod", "Machine.Basic": "Machine.Machine"}
    rx = pattern(m)
    cases = [
        ("open Spec.FlightType in", "open Spec.Model.FlightType in"),
        ("Spec.FlightType.OW", "Spec.Model.FlightType.OW"),
        ("SourceModel.Spec.FlightType", "SourceModel.Spec.FlightType"),
        ("A.getStr? x", "A.getStr? x"),
        ("A.getStr x", "A.R.getStr x"),
        ("``Spec.FlightType", "``Spec.Model.FlightType"),
        ("`Old.Mod.f", "`New.Mod.f"),
        ("import Machine.Basic\n", "import Machine.Machine\n"),
        ("`Spec.FlightType`。", "`Spec.Model.FlightType`。"),
        ("A.x'", "A.x'"),
        ("A.x₂", "A.x₂"),
        ("(A.x)", "(A.x.y)"),
    ]
    bad = 0
    for src, want in cases:
        got = rewrite(src, m, rx)
        if got != want:
            print(f"  FAIL {src!r}: {got!r} != {want!r}")
            bad += 1
    # check: 写した後に旧い名前が残らない（A.x → A.x.y の新しい名前は数えない）
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "a.lean"
        p.write_text("Spec.FlightType A.x\n", encoding="utf-8")
        if check(m, [d]) != 1:
            print("  FAIL check must report old names")
            bad += 1
        apply(m, [d], False)
        if check(m, [d]) != 0 or p.read_text(encoding="utf-8") != "Spec.Model.FlightType A.x.y\n":
            print("  FAIL check after apply")
            bad += 1
    print("rename self-test: " + ("OK" if bad == 0 else f"{bad} failure(s)"))
    return 1 if bad else 0


def main(argv):
    if argv[:1] == ["--self-test"]:
        return self_test()
    if len(argv) < 2 or argv[0] not in ("apply", "check"):
        print(__doc__)
        return 2
    m = load_map(argv[1])
    rest = [a for a in argv[2:] if a != "--dry-run"]
    paths = rest or [repo_root()]
    if argv[0] == "apply":
        return apply(m, paths, "--dry-run" in argv)
    return check(m, paths)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
