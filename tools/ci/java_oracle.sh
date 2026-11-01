#!/usr/bin/env bash
# ATRS の Java オラクル（backlog f18c）。原典を複写してビルドし（tools/oracle/build-upstream.sh）、spec-pivot の conformance-kit と
# ハーネス（tools/oracle）を作って、PostgreSQL のある環境で実行する。
#   tools/ci/java_oracle.sh [domain|http|all] [--write]
# - domain: 運賃計算・空席照会のベクタを原典で照合し、生成するベクタ（conformance/source-model/*/oracle-*.json）との差分 0 を求める
# - http:   Spring を起動した原典に要求を送り、採取結果（tools/oracle/http/*.json）との差分 0 を求める
# - --write: 生成するベクタ・採取結果を書き出す
# java・mvn・PostgreSQL が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
# 環境変数 MAVEN_SETTINGS（任意）: mvn -s に渡す設定（Maven Central に届かないローカルでミラーを使う）。
set -euo pipefail
cd "$(dirname "$0")/../.."
mode="${1:-all}"
shift || true

missing=""
command -v java > /dev/null || missing="java"
command -v mvn > /dev/null || missing="$missing mvn"
if ! { [ -n "${PGHOST:-}" ] || command -v pg_config > /dev/null || ls /usr/lib/postgresql/*/bin/initdb > /dev/null 2>&1; }; then
  missing="$missing postgresql"
fi
if [ -n "$missing" ]; then
  if [ -n "${CI:-}" ]; then echo "java_oracle: not available (required in CI):$missing" >&2; exit 1; fi
  echo "java_oracle: not found:$missing: skipped"; exit 2
fi

mvn=(mvn -B -q ${MAVEN_SETTINGS:+-s "$MAVEN_SETTINGS"})
tools/oracle/build-upstream.sh
"${mvn[@]}" -f .agents/skills/spec-pivot/assets/java/conformance-kit/pom.xml install
"${mvn[@]}" -f tools/oracle/pom.xml package
cp="tools/oracle/target/atrs-oracle.jar:$(cat tools/oracle/target/classpath.txt)"
run() {
  WITH_POSTGRES_TCP=1 .agents/skills/spec-pivot/scripts/ci/with_postgres.sh \
    java -Duser.timezone=Asia/Tokyo -Duser.language=ja -Duser.country=JP -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 \
      -Dstderr.encoding=UTF-8 -Dlogback.configurationFile=tools/oracle/src/main/resources/oracle-logback.xml \
      -cp "$cp" atrsoracle.Main "$PWD" "$@"
}
case "$mode" in
  domain|http) run "$mode" "$@" ;;
  all) run domain "$@"; run http "$@" ;;
  *) echo "usage: tools/ci/java_oracle.sh [domain|http|all] [--write]" >&2; exit 64 ;;
esac
