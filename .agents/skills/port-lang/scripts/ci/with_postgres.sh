#!/usr/bin/env bash
# PostgreSQL に接続できる環境で <command> を実行する（port-lang の道具。scripts/README.md）。
#   <skill>/scripts/ci/with_postgres.sh <command> [args...]
#
# - 環境変数 PGHOST が設定されていれば、そのサーバを使う（CI はサービスコンテナ）。
# - 無ければ、一時クラスタを作って起動する。設定は port-lang の
#   references/sql/dialects/postgresql/harness.md に従う（initdb --locale=C --encoding=UTF8、TimeZone=UTC）。
#   root で実行した場合は postgres ユーザで起動する。
set -euo pipefail

if [ -n "${PGHOST:-}" ]; then
  exec "$@"
fi

bindir="$(pg_config --bindir 2> /dev/null || true)"
for d in "$bindir" /usr/lib/postgresql/*/bin; do
  if [ -n "$d" ] && [ -x "$d/initdb" ]; then bindir="$d"; break; fi
done
if [ ! -x "$bindir/initdb" ]; then
  echo "with_postgres.sh: initdb not found" >&2
  exit 2
fi

dir="$(mktemp -d)"
as=()
if [ "$(id -u)" = 0 ]; then
  chown postgres "$dir"
  as=(runuser -u postgres --)
fi
stop() {
  "${as[@]}" "$bindir/pg_ctl" -D "$dir/data" -m fast -w stop > /dev/null 2>&1 || true
  rm -rf "$dir"
}
trap stop EXIT

"${as[@]}" "$bindir/initdb" -D "$dir/data" --locale=C --encoding=UTF8 -U postgres -A trust > /dev/null
"${as[@]}" "$bindir/pg_ctl" -D "$dir/data" -l "$dir/server.log" -w \
  -o "-k $dir -c listen_addresses='' -c TimeZone=UTC" start > /dev/null

PGHOST="$dir" PGUSER=postgres PGDATABASE=postgres "$@"
