"""移した業務仕様へのリンクの文字列のうち、古いファイル名（`fare-calculation.md` など）をモジュール名に替える
（tools/docs/spec_to_lean.py の後に 1 回だけ実行する。backlog c89a）。"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def module_of(src, link):
    """リンクの指す Lean のファイルのモジュール名（`Spec.Fare` など）。"""
    path = os.path.normpath(os.path.join(os.path.dirname(src), link.partition("#")[0]))
    return "`" + path[len("lean/"):-len(".lean")].replace(os.sep, ".") + "`"


def main():
    amap = json.loads((REPO / "tools/docs/spec-anchors.json").read_text(encoding="utf-8"))["anchors"]
    mods = {k.rsplit("/", 1)[1][:-3]: "`" + v[len("lean/"):-len(".lean")].replace("/", ".") + "`"
            for k, v in amap.items() if "#" not in k}
    pat = re.compile(r"\[(" + "|".join(map(re.escape, mods)) + r")\.md(#[^\]]*)?\]\(([^)\s]*\.lean(?:#[^)\s]*)?)\)")
    files = subprocess.run(["git", "ls-files", "-m", "-o", "--exclude-standard"], cwd=REPO,
                           capture_output=True, text=True, check=True).stdout.split()
    n = 0
    for f in files:
        p = REPO / f
        if not f.endswith((".md", ".lean")) or not p.is_file():
            continue
        s = p.read_text(encoding="utf-8")
        t, k = pat.subn(lambda m: f"[{module_of(f, m.group(3))}]({m.group(3)})", s)
        if k:
            n += k
            p.write_text(t, encoding="utf-8")
    print(f"replaced {n} link text(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
