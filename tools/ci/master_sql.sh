#!/usr/bin/env bash
# conformance/sql/master-data.json・flight-search.json・reservation.json が、PostgreSQL でのマスタの Mapper の文・コードリストの SQL・
# 空席照会の文・予約が使う文の実行結果と一致することを確かめる（backlog 25f7・0be7・aedf）。照合そのものは lake test
# （Tests.MasterSql・Tests.FlightSql・Tests.ReservationSql）が行う。
# PostgreSQL が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
#   tools/ci/master_sql.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

pgver="$(uv run --quiet python -I -c 'import json; print(json.load(open("trace/upstream.json"))["languages"]["postgresql"]["version"])')"
if ! { [ -n "${PGHOST:-}" ] || command -v pg_config > /dev/null || ls /usr/lib/postgresql/*/bin/initdb > /dev/null 2>&1; }; then
  if [ -n "${CI:-}" ]; then echo "PostgreSQL not available (required in CI)" >&2; exit 1; fi
  echo "PostgreSQL not found: skipped"; exit 2
fi
.agents/skills/spec-pivot/scripts/ci/with_postgres.sh uv run --quiet python -I tools/conformance/master_sql.py --check --expect-version "$pgver"
.agents/skills/spec-pivot/scripts/ci/with_postgres.sh uv run --quiet python -I tools/conformance/reservation_sql.py --check --expect-version "$pgver"
