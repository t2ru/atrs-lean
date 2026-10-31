#!/usr/bin/env python3
"""上流 submodule の commit と trace/upstream.json の宣言が一致するかを検査する（port-lang の道具。scripts/README.md）。

使い方: python3 -I <skill>/scripts/ci/check_upstream.py [リポジトリのルート]
"""
import json
import pathlib
import subprocess
import sys


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    decl = json.loads((root / "trace" / "upstream.json").read_text(encoding="utf-8"))
    sub = decl["submodule"]
    # gitlink（親リポジトリの index が記録している commit）と、作業ツリーの HEAD の両方を確かめる
    gitlink = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--stage", "--", sub],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    errors = []
    if len(gitlink) < 4 or gitlink[0] != "160000":
        errors.append(f"{sub} is not a submodule in the index")
    elif gitlink[1] != decl["commit"]:
        errors.append(f"gitlink {gitlink[1]} != upstream.json commit {decl['commit']}")
    head = subprocess.run(
        ["git", "-C", str(root / sub), "rev-parse", "HEAD"],
        capture_output=True, text=True,
    )
    if head.returncode != 0:
        errors.append(f"{sub} is not checked out (git submodule update --init)")
    elif head.stdout.strip() != decl["commit"]:
        errors.append(f"checked-out {head.stdout.strip()} != upstream.json commit {decl['commit']}")
    for e in errors:
        print(f"check_upstream: FAIL: {e}", file=sys.stderr)
    if not errors:
        print(f"check_upstream: OK {sub} @ {decl['commit']} ({decl['release']})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
