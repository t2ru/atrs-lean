#!/usr/bin/env bash
# LangSemanticsTest/PostgresqlDb.lean が、PostgreSQL での生成器の出力と一致することを確かめる（backlog 0016）。
# PostgreSQL が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
#   tools/ci/pg_table.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

pgver="$(python3 -I -c 'import json; print(json.load(open("trace/upstream.json"))["languages"]["postgresql"]["version"])')"
if ! { [ -n "${PGHOST:-}" ] || command -v pg_config > /dev/null || ls /usr/lib/postgresql/*/bin/initdb > /dev/null 2>&1; }; then
  if [ -n "${CI:-}" ]; then echo "PostgreSQL not available (required in CI)" >&2; exit 1; fi
  echo "PostgreSQL not found: skipped"; exit 2
fi
pgt="$(mktemp)"
trap 'rm -f "$pgt"' EXIT
tools/ci/with_postgres.sh python3 -I .agents/skills/port-lang/assets/lean/LangSemanticsTest/pg/pg_table.py \
  --expect-version "$pgver" > "$pgt"
diff -u .agents/skills/port-lang/assets/lean/LangSemanticsTest/PostgresqlDb.lean "$pgt"
echo "PostgresqlDb.lean: up to date (PostgreSQL $pgver)"
