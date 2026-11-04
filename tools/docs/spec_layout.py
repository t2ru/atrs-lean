#!/usr/bin/env python3
"""Spec のモジュール構成の再編（層と機能名）の機械的な段を、一度に行う（ATRS の道具。1 回きりの移行の記録を兼ねる）。

使い方（リポジトリのルートで）:
  uv run python -I tools/docs/spec_layout.py [--dry-run]

1. スキル okf-bundle の docmv.py で `lean/Spec` のファイルを移す（`git mv`）。`lean/Spec/X.lean` の言及（`@[spec_doc]`・
   ベクタの `specRef`・登録簿の `sites`・文書のリンク）と、Markdown・Lean のモジュール文書の相対リンクも張り直す。
2. スキル spec-pivot の rename.py で、Lean の完全名を `tools/docs/lean-renames-spec.json` のとおりに改名する。
3. 生成物のモジュール `Spec.Seed` の import を `Spec.Seed.Master` に直す（`Spec.Seed` は手書きの入口になる）。
   `open` の行から、宣言の無くなる名前空間 `Spec.Port` を除く（`World` は `Spec.World` になる）。
4. 履歴（改名・移し先の対応表、変更履歴の log.md）を、書き換える前に戻す。

`Spec.Port` の分割（`Spec.World` と文書だけの `Spec.Port`）、`Spec.Env`（旧 `Spec.EnvPre`）からシードの定理を
`Spec.Seed` へ移すこと、モジュール文書の書き直しは手で行う。
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OKF = ROOT / ".agents/skills/okf-bundle/scripts/docmv.py"
RENAME = ROOT / ".agents/skills/spec-pivot/scripts/lean/rename.py"
MAP = ROOT / "tools/docs/lean-renames-spec.json"

# lean/Spec からの相対パス: 旧 → 新
MOVES = [
    ("Config.lean", "Env/Config.lean"),
    ("MasterData.lean", "Env/MasterData.lean"),
    ("CodeList.lean", "Env/CodeList.lean"),
    ("EnvPre.lean", "Env.lean"),
    ("Seed.lean", "Seed/Master.lean"),
    ("Port.lean", "World.lean"),
    ("UseCase/Reserve.lean", "Reserve.lean"),
    ("Ticket.lean", "Reserve/FlightSelection.lean"),
    ("Authentication.lean", "Auth.lean"),
    ("ReservationHistoryReport.lean", "Report.lean"),
    ("InputValidation.lean", "Validation.lean"),
]

# 書き換えない履歴
HISTORY = [
    "tools/docs/lean-renames.json",
    "tools/docs/lean-renames-mirror.json",
    "tools/docs/lean-renames-preserves.json",
    "tools/docs/spec-anchors.json",
    "tools/docs/spec-to-lean.json",
    "docs/log.md",
    ".agents/skills/spec-pivot/references/docs/log.md",
    ".agents/skills/okf-bundle/references/docs/log.md",
    ".agents/skills/work-records/references/docs/log.md",
]

PY = ["uv", "run", "--quiet", "python", "-I"]


def run(cmd):
    print("+", " ".join(str(c) for c in cmd))
    subprocess.run(cmd, cwd=ROOT, check=True)


def lean_files():
    out = subprocess.run(["git", "ls-files", "*.lean"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [ROOT / p for p in out.splitlines() if not p.startswith("upstream/")]


def fix_lean():
    imp = re.compile(r"^import Spec\.Seed$", re.M)
    opn = re.compile(r"^(\s*open\b[^\n]*?)\s+Spec\.Port(?=\s|$)", re.M)
    lone = re.compile(r"^\s*open Spec\.Port\s*\n", re.M)
    n = 0
    for p in lean_files():
        s = p.read_text(encoding="utf-8")
        t = imp.sub("import Spec.Seed.Master", s)
        t = lone.sub("", t)
        t = opn.sub(r"\1", t)
        t = re.sub(r"^(\s*)open Spec\.Port\s+", r"\1open ", t, flags=re.M)
        if t != s:
            p.write_text(t, encoding="utf-8")
            n += 1
    print(f"spec_layout: fixed imports/open in {n} Lean file(s)")


def main(argv):
    dry = "--dry-run" in argv[1:]
    args = [str(x) for pair in MOVES for x in pair]
    if dry:
        run(PY + [OKF, "--dry-run", "--root", "lean/Spec", *args])
        run(PY + [RENAME, "apply", MAP, "--dry-run"])
        return 0
    own = {p: p.read_text(encoding="utf-8") for p in (MAP, pathlib.Path(__file__).resolve())}  # 改名の対象から外す
    run(PY + [OKF, "--root", "lean/Spec", *args])
    run(PY + [RENAME, "apply", MAP])
    for p, t in own.items():
        p.write_text(t, encoding="utf-8")
    fix_lean()
    run(["git", "checkout", "--", *HISTORY])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
