#!/usr/bin/env bash
# Lean 側の検査を一括で実行する（CI とローカルで共通。backlog 0001・0025・0027・0002・0030・0016）。
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

step "static: 証明義務と文書の突き合わせの自己テスト（違反例を検出できること）"
python3 -I tools/ci/check_obligations.py --self-test

step "assets/lean: JVM との突き合わせ表（LangSemanticsTest/JavaJvm.lean）が生成器の出力と一致する"
if command -v java > /dev/null; then
  jvm="$(mktemp)"
  (cd .agents/skills/port-lang/assets/lean && java LangSemanticsTest/jvm/JavaTable.java > "$jvm" 2> /dev/null)
  diff -u .agents/skills/port-lang/assets/lean/LangSemanticsTest/JavaJvm.lean "$jvm"
  rm -f "$jvm"
  echo "JavaJvm.lean: up to date ($(java -version 2>&1 | grep -m1 version))"
elif [ -n "${CI:-}" ]; then
  echo "java not found (required in CI)" >&2; exit 1
else
  echo "java not found: skipped"
fi

step "assets/lean: PostgreSQL との突き合わせ表（LangSemanticsTest/PostgresqlDb.lean）が生成器の出力と一致する"
pgver="$(python3 -I -c 'import json; print(json.load(open("trace/upstream.json"))["languages"]["postgresql"]["version"])')"
if [ -n "${PGHOST:-}" ] || command -v pg_config > /dev/null || ls /usr/lib/postgresql/*/bin/initdb > /dev/null 2>&1; then
  pgt="$(mktemp)"
  tools/ci/with_postgres.sh python3 -I .agents/skills/port-lang/assets/lean/LangSemanticsTest/pg/pg_table.py \
    --expect-version "$pgver" > "$pgt"
  diff -u .agents/skills/port-lang/assets/lean/LangSemanticsTest/PostgresqlDb.lean "$pgt"
  rm -f "$pgt"
  echo "PostgresqlDb.lean: up to date (PostgreSQL $pgver)"
elif [ -n "${CI:-}" ]; then
  echo "PostgreSQL not available (required in CI)" >&2; exit 1
else
  echo "PostgreSQL not found: skipped"
fi

step "assets/lean: lake build（LangSemantics・Machine と、その検査 LangSemanticsTest・MachineTest）"
(cd .agents/skills/port-lang/assets/lean && lake build)

step "lean: lake build"
(cd lean && lake build)

step "lean: lake test"
(cd lean && lake test)

step "lean: 公理の検査"
(cd lean && lake exe axiom-check)

out="$(mktemp)"
ob="$(mktemp)"
trap 'rm -f "$out" "$ob"' EXIT

step "lean: obligation-check（R 課題の形と付帯の義務。TR-G）と文書の突き合わせ（TR-N）"
(cd lean && lake exe obligation-check > "$ob")
python3 -I tools/ci/check_obligations.py "$ob"

step "lean: trace-dump"
(cd lean && lake exe trace-dump > "$out")
python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1]))
print("trace-dump: %d definitions (Lean %s)" % (len(d["definitions"]), d["lean_version"]))' "$out"

step "workspace: ルートで lake setup-file（Lean LSP 用）"
lake setup-file lean/Spec.lean > /dev/null
lake setup-file lean/Tests/Main.lean > /dev/null
lake setup-file .agents/skills/port-lang/assets/lean/LangSemantics.lean > /dev/null
lake setup-file .agents/skills/port-lang/assets/lean/Machine.lean > /dev/null

step "OK"
