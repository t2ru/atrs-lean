#!/usr/bin/env bash
# assets/lean/LangSemanticsTest/PostgresqlDb.lean が、PostgreSQL での生成器の出力と一致することを確かめる
# （port-lang の道具。scripts/README.md）。PostgreSQL の版は、作業ディレクトリ（リポジトリのルート）の
# trace/upstream.json の languages.postgresql.version と照合する。
# PostgreSQL が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
#   <skill>/scripts/ci/pg_table.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
assets="$(cd "$here/../../assets/lean" && pwd)"

pgver="$(python3 -I -c 'import json; print(json.load(open("trace/upstream.json"))["languages"]["postgresql"]["version"])')"
if ! { [ -n "${PGHOST:-}" ] || command -v pg_config > /dev/null || ls /usr/lib/postgresql/*/bin/initdb > /dev/null 2>&1; }; then
  if [ -n "${CI:-}" ]; then echo "PostgreSQL not available (required in CI)" >&2; exit 1; fi
  echo "PostgreSQL not found: skipped"; exit 2
fi
pgt="$(mktemp)"
trap 'rm -f "$pgt"' EXIT
"$here/with_postgres.sh" python3 -I "$assets/LangSemanticsTest/pg/pg_table.py" --expect-version "$pgver" > "$pgt"
diff -u "$assets/LangSemanticsTest/PostgresqlDb.lean" "$pgt"
echo "PostgresqlDb.lean: up to date (PostgreSQL $pgver)"
