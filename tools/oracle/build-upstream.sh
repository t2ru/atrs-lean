#!/usr/bin/env bash
# 原典（upstream/atrs/JavaConfig-Thymeleaf/atrs）を複写してビルドし、ローカルの Maven リポジトリに入れる（backlog f18c）。
# 原典の作業木には書かない（target/ も複写先にできる）。atrs-web は war なので、classes の jar を分類子 classes で入れ、
# ハーネス（tools/oracle）は atrs-web:classes に依存して推移的な依存を得る。
#   tools/oracle/build-upstream.sh
# 環境変数 MAVEN_SETTINGS（任意）: mvn -s に渡す設定（Maven Central に届かないローカルでミラーを使う）。
set -euo pipefail
cd "$(dirname "$0")/../.."
src=upstream/atrs/JavaConfig-Thymeleaf/atrs
dst=tools/oracle/target/upstream
commit="$(git -C upstream/atrs rev-parse HEAD)"
stamp="$dst/.built-$commit"
if [ -f "$stamp" ]; then exit 0; fi
mvn=(mvn -B -q ${MAVEN_SETTINGS:+-s "$MAVEN_SETTINGS"})
rm -rf "$dst"
mkdir -p "$dst"
cp -R "$src/." "$dst/"
rm -rf "$dst"/*/target
"${mvn[@]}" -f "$dst/pom.xml" -pl atrs-web -am install -DskipTests
jar --create --file "$dst/atrs-web/target/atrs-web-classes.jar" -C "$dst/atrs-web/target/classes" .
"${mvn[@]}" install:install-file -Dfile="$dst/atrs-web/target/atrs-web-classes.jar" -DpomFile="$dst/atrs-web/pom.xml" \
  -Dclassifier=classes -Dpackaging=jar
touch "$stamp"
