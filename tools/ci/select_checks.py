"""変更の範囲から、実行する検査の段を選ぶ（docs/rules/checks.md）。

    uv run python -I tools/ci/select_checks.py list          # 選んだ段と理由を表示する
    uv run python -I tools/ci/select_checks.py run           # mise run ci:fast ::: <選んだ段>…（全数なら mise run ci）
    uv run python -I tools/ci/select_checks.py check-config  # 設定（tools/ci/check-scopes.toml）と mise.toml の整合
    uv run python -I tools/ci/select_checks.py --self-test

- 変更: `git diff HEAD`（索引と作業木）と未追跡のファイル。環境変数 CHECK_BASE=<rev> があれば、
  `merge-base(<rev>, HEAD)` から HEAD までの変更も加える（PR の CI・push の前）。
- 全数: 環境変数 CHECK_FULL=1、git の失敗、設定の [full] に当たる変更。
- 常時の段は mise.toml の `ci:fast`。変更時の段は設定の [scopes] にあり、変更されたファイルが paths の glob か
  lean_roots の import の閉包に当たったときだけ実行する。
- GITHUB_STEP_SUMMARY があれば、実行した段・飛ばした段と理由を書く（何を検査したかの記録）。
- 標準ライブラリだけを使う。
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "tools/ci/check-scopes.toml"
MISE = ROOT / "mise.toml"
FAST_TASK = "ci:fast"
FULL_TASK = "ci"

IMPORT_RE = re.compile(r"^(?:(?:public|private|meta)\s+)*import\s+(?:all\s+)?([^-]+?)\s*(?:--.*)?$")


def glob_re(glob: str) -> re.Pattern[str]:
    """`**` は任意の深さ（`**/` は 0 段を含む）、`*`・`?` は 1 段の中だけに当たる。"""
    out, i = "", 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif glob.startswith("**", i):
            out, i = out + ".*", i + 2
        elif glob[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif glob[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(glob[i]), i + 1
    return re.compile(out + r"\Z")


def matches(globs: list[str], path: str) -> bool:
    return any(glob_re(g).match(path) for g in globs)


def module_file(root: Path, lean_dirs: list[str], module: str) -> str | None:
    rel = module.replace(".", "/") + ".lean"
    for d in lean_dirs:
        if (root / d / rel).is_file():
            return f"{d}/{rel}"
    return None


def imports_of(root: Path, rel: str) -> list[str]:
    mods: list[str] = []
    for line in (root / rel).read_text(encoding="utf-8").splitlines():
        m = IMPORT_RE.match(line)
        if m:
            mods.extend(m.group(1).split())
    return mods


def lean_closure(root: Path, lean_dirs: list[str], modules: list[str]) -> set[str]:
    """モジュールから `import` をたどった閉包のファイル（lean_dirs の下にあるものだけ。Lean・Std・Batteries などは除く）。"""
    seen: set[str] = set()
    todo = list(modules)
    while todo:
        f = module_file(root, lean_dirs, todo.pop())
        if f is None or f in seen:
            continue
        seen.add(f)
        todo.extend(imports_of(root, f))
    return seen


def select(cfg: dict, changed: set[str], root: Path) -> tuple[list[str], dict[str, list[str]]]:
    """(全数の理由, {変更時の段: 当たったファイル}) を返す。全数の理由が空でなければ全数。"""
    full = sorted(p for p in changed if matches(cfg.get("full", {}).get("paths", []), p))
    hits: dict[str, list[str]] = {}
    for task, scope in cfg.get("scopes", {}).items():
        closure = lean_closure(root, cfg.get("lean_dirs", []), scope.get("lean_roots", []))
        hit = sorted(p for p in changed if p in closure or matches(scope.get("paths", []), p))
        if hit:
            hits[task] = hit
    return full, hits


def git(*args: str) -> list[str]:
    out = subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout
    return [l for l in out.splitlines() if l]


def changed_files(base: str | None) -> set[str]:
    files = set(git("diff", "--name-only", "--no-renames", "--ignore-submodules=dirty", "HEAD"))
    files |= set(git("ls-files", "--others", "--exclude-standard"))
    if base:
        mb = git("merge-base", base, "HEAD")[0]
        files |= set(git("diff", "--name-only", "--no-renames", "--ignore-submodules=dirty", mb, "HEAD"))
    return files


def load_config() -> dict:
    return tomllib.loads(CONFIG.read_text(encoding="utf-8"))


def plan() -> tuple[str | None, list[str], dict[str, list[str]], int]:
    """(全数の理由 or None, 選んだ変更時の段, 当たったファイル, 変更の数)。"""
    cfg = load_config()
    if os.environ.get("CHECK_FULL") == "1":
        return "CHECK_FULL=1", [], {}, 0
    try:
        changed = changed_files(os.environ.get("CHECK_BASE") or None)
    except (subprocess.CalledProcessError, IndexError, FileNotFoundError) as e:
        return f"git failed ({e})", [], {}, 0
    full, hits = select(cfg, changed, ROOT)
    if full:
        return "changed: " + ", ".join(full[:5]) + (" …" if len(full) > 5 else ""), [], {}, len(changed)
    return None, [t for t in cfg["scopes"] if t in hits], hits, len(changed)


def report(full: str | None, tasks: list[str], hits: dict[str, list[str]], n: int) -> str:
    cfg = load_config()
    base = os.environ.get("CHECK_BASE") or "HEAD"
    lines = [f"## 検査の選択（変更 {n} 件、base: {base}）", ""]
    if full:
        lines += [f"全数（`mise run {FULL_TASK}`）: {full}", ""]
        return "\n".join(lines)
    lines += [f"常時の段（`{FAST_TASK}`）と、次の変更時の段を実行する。", "", "| 段 | 実行 | 理由 |", "| --- | --- | --- |"]
    for t in cfg["scopes"]:
        h = hits.get(t, [])
        why = ", ".join(f"`{p}`" for p in h[:3]) + (f" ほか {len(h) - 3} 件" if len(h) > 3 else "")
        lines.append(f"| `{t}` | {'実行' if t in tasks else '飛ばす'} | {why or '関係する変更なし'} |")
    return "\n".join(lines) + "\n"


def write_summary(text: str) -> None:
    print(text)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text + "\n")


def cmd_run() -> int:
    full, tasks, hits, n = plan()
    write_summary(report(full, tasks, hits, n))
    argv = ["mise", "run", FULL_TASK] if full else ["mise", "run", FAST_TASK] + [x for t in tasks for x in (":::", t)]
    print("$ " + " ".join(argv), flush=True)
    os.chdir(ROOT)
    os.execvp(argv[0], argv)
    return 1


def config_errors(cfg: dict, mise: dict, tracked: list[str], root: Path) -> list[str]:
    errs: list[str] = []
    tasks = mise.get("tasks", {})
    ci = set(tasks.get(FULL_TASK, {}).get("depends", []))
    fast = set(tasks.get(FAST_TASK, {}).get("depends", []))
    scoped = set(cfg.get("scopes", {}))
    for t in sorted(scoped - set(tasks)):
        errs.append(f"[scopes.\"{t}\"]: no such mise task")
    # ci の depends ＝ ci:fast ＋ 変更時の段（[scopes]）。ci:fast と [scopes] は重ならない
    if FAST_TASK not in ci:
        errs.append(f"{FULL_TASK}: does not depend on {FAST_TASK}")
    for t in sorted(fast & scoped):
        errs.append(f"{t}: in both {FAST_TASK} and [scopes]")
    for t in sorted(ci - {FAST_TASK} - scoped):
        errs.append(f"{t}: in {FULL_TASK} directly; put it in {FAST_TASK} or give it a scope in [scopes]")
    for t in sorted(scoped - ci):
        errs.append(f"[scopes.\"{t}\"]: not in the depends of {FULL_TASK}")
    groups = [("[full]", cfg.get("full", {}))] + [(f"[scopes.\"{t}\"]", s) for t, s in cfg.get("scopes", {}).items()]
    for where, s in groups:
        for g in s.get("paths", []):
            if not any(glob_re(g).match(p) for p in tracked):
                errs.append(f"{where}: glob matches no tracked file: {g}")
        for m in s.get("lean_roots", []):
            if module_file(root, cfg.get("lean_dirs", []), m) is None:
                errs.append(f"{where}: Lean module not found: {m}")
        if where != "[full]" and not s.get("paths") and not s.get("lean_roots"):
            errs.append(f"{where}: empty scope")
    return errs


def cmd_check_config() -> int:
    mise = tomllib.loads(MISE.read_text(encoding="utf-8"))
    tracked = git("ls-files") + git("ls-files", "--others", "--exclude-standard")
    errs = config_errors(load_config(), mise, tracked, ROOT)
    for e in errs:
        print(f"check-scopes: {e}", file=sys.stderr)
    if errs:
        return 1
    print(f"check-scopes: OK ({len(load_config()['scopes'])} scoped tasks)")
    return 0


def self_test() -> int:
    fails: list[str] = []

    def expect(label: str, ok: bool) -> None:
        print(("  ok   " if ok else "  FAIL ") + label)
        if not ok:
            fails.append(label)

    expect("glob: ** matches any depth", bool(glob_re("a/**").match("a/b/c.lean")))
    expect("glob: **/ matches zero dirs", bool(glob_re("**/lean-toolchain").match("lean-toolchain")))
    expect("glob: **/ matches nested", bool(glob_re("**/lean-toolchain").match("lean/lean-toolchain")))
    expect("glob: * stays in one segment", not glob_re("lean/*.lean").match("lean/Spec/A.lean"))
    expect("glob: **/*.lean", bool(glob_re("lean/**/*.lean").match("lean/Spec.lean")))
    expect("glob: exact path only", not glob_re("mise.toml").match("x/mise.toml"))
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "l/Tests").mkdir(parents=True)
        (root / "a/Lib").mkdir(parents=True)
        (root / "l/Tests/Ex.lean").write_text("import Tests.Report\nmeta import Lib.Core -- c\nimport Batteries\n\n/-! doc -/\n")
        (root / "l/Tests/Report.lean").write_text("/-! no imports -/\n")
        (root / "l/Tests/Other.lean").write_text("import Tests.Ex\n")
        (root / "a/Lib/Core.lean").write_text("import Lib.Base Init\n")
        (root / "a/Lib/Base.lean").write_text("")
        dirs = ["l", "a"]
        cl = lean_closure(root, dirs, ["Tests.Ex"])
        expect("closure: follows imports across lean_dirs",
               cl == {"l/Tests/Ex.lean", "l/Tests/Report.lean", "a/Lib/Core.lean", "a/Lib/Base.lean"})
        cfg = {"lean_dirs": dirs, "full": {"paths": ["mise.toml"]},
               "scopes": {"t:ex": {"lean_roots": ["Tests.Ex"]}, "t:docs": {"paths": ["docs/**"]}}}
        full, hits = select(cfg, {"a/Lib/Base.lean"}, root)
        expect("select: change in the closure selects the task", not full and set(hits) == {"t:ex"})
        full, hits = select(cfg, {"l/Tests/Other.lean"}, root)
        expect("select: importer of the root is not in the closure", not full and not hits)
        full, hits = select(cfg, {"docs/x.md", "README.md"}, root)
        expect("select: path glob", not full and set(hits) == {"t:docs"})
        full, _ = select(cfg, {"mise.toml", "docs/x.md"}, root)
        expect("select: [full] path forces full", full == ["mise.toml"])
        full, hits = select(cfg, set(), root)
        expect("select: no change, nothing scoped", not full and not hits)
        mise = {"tasks": {"ci": {"depends": ["ci:fast", "t:ex", "t:docs"]}, "ci:fast": {"depends": ["f1"]},
                          "f1": {}, "t:ex": {}, "t:docs": {}}}
        tracked = ["mise.toml", "docs/x.md"]
        expect("config: consistent", config_errors(cfg, mise, tracked, root) == [])
        bad_mise = {"tasks": {**mise["tasks"], "ci": {"depends": ["ci:fast", "f2", "t:ex", "t:docs"]}, "f2": {}}}
        expect("config: a task in ci but unclassified is an error",
               any("f2" in e for e in config_errors(cfg, bad_mise, tracked, root)))
        dup_mise = {"tasks": {**mise["tasks"], "ci:fast": {"depends": ["f1", "t:ex"]}}}
        expect("config: a task in both tiers is an error",
               any("both" in e for e in config_errors(cfg, dup_mise, tracked, root)))
        miss_mise = {"tasks": {**mise["tasks"], "ci": {"depends": ["ci:fast", "t:ex"]}}}
        expect("config: a scoped task missing from ci is an error",
               any("t:docs" in e for e in config_errors(cfg, miss_mise, tracked, root)))
        stale = {**cfg, "scopes": {**cfg["scopes"], "t:docs": {"paths": ["doc/**"]}}}
        expect("config: a glob matching nothing is an error",
               any("doc/**" in e for e in config_errors(stale, mise, tracked, root)))
        gone = {**cfg, "scopes": {**cfg["scopes"], "t:ex": {"lean_roots": ["Tests.Gone"]}}}
        expect("config: a missing Lean module is an error",
               any("Tests.Gone" in e for e in config_errors(gone, mise, tracked, root)))
    if fails:
        print(f"select_checks self-test: {len(fails)} failure(s)", file=sys.stderr)
        return 1
    print("select_checks self-test: OK")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    if argv == ["list"]:
        full, tasks, hits, n = plan()
        print(report(full, tasks, hits, n))
        return 0
    if argv == ["run"]:
        return cmd_run()
    if argv == ["check-config"]:
        return cmd_check_config()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
