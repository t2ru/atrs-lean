#!/usr/bin/env bash
# PostgreSQL に接続できる環境で <command> を実行する（spec-pivot の道具。scripts/README.md）。
#   <skill>/scripts/ci/with_postgres.sh <command> [args...]
#
# - 環境変数 PGHOST が設定されていれば、そのサーバを使う（CI はサービスコンテナ）。
# - 無ければ、一時クラスタを作って起動する。設定は spec-pivot の
#   references/docs/lang/sql/dialects/postgresql/harness.md に従う（initdb --locale=C --encoding=UTF8、TimeZone=UTC）。
#   root で実行した場合は postgres ユーザで起動する。
# - 環境変数 WITH_POSTGRES_TCP=1 なら、一時クラスタを 127.0.0.1 の空いているポートでも待ち受けさせ、
#   PGHOST=127.0.0.1・PGPORT をそのポートにする（Unix ソケットを使えない JDBC などのため。Java の原典実行）。
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
if [ "${WITH_POSTGRES_TCP:-}" = 1 ]; then
  port="$(python3 -I -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  "${as[@]}" "$bindir/pg_ctl" -D "$dir/data" -l "$dir/server.log" -w \
    -o "-k $dir -c listen_addresses=127.0.0.1 -p $port -c TimeZone=UTC" start > /dev/null
  PGHOST=127.0.0.1 PGPORT="$port" PGUSER=postgres PGDATABASE=postgres "$@"
  exit
fi
"${as[@]}" "$bindir/pg_ctl" -D "$dir/data" -l "$dir/server.log" -w \
  -o "-k $dir -c listen_addresses='' -c TimeZone=UTC" start > /dev/null

PGHOST="$dir" PGUSER=postgres PGDATABASE=postgres "$@"
