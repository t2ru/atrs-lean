#!/usr/bin/env bash
# Lean 側の検査を一括で実行する（CI とローカルで共通。backlog 0001・0025）。
#   tools/ci/lean.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

step() { printf '\n== %s\n' "$*"; }

step "upstream: submodule の commit と trace/upstream.json の一致"
python3 -I tools/ci/check_upstream.py

step "static: 静的検査の自己テスト（違反例を検出できること）"
python3 -I tools/ci/check_lean.py --self-test

step "static: sorry・axiom・native_decide・Float・partial 等と、名前空間の依存の向き"
python3 -I tools/ci/check_lean.py

step "lean: lake build"
(cd lean && lake build)

step "lean: lake test"
(cd lean && lake test)

step "lean: 公理の検査"
(cd lean && lake exe axiom-check)

step "lean: trace-dump"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
(cd lean && lake exe trace-dump > "$out")
python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1]))
print("trace-dump: %d definitions (Lean %s)" % (len(d["definitions"]), d["lean_version"]))' "$out"

step "workspace: ルートで lake setup-file（Lean LSP 用）"
lake setup-file lean/Spec.lean > /dev/null
lake setup-file lean/Tests/Main.lean > /dev/null
lake setup-file .agents/skills/port-lang/assets/LangSemantics.lean > /dev/null

step "OK"
