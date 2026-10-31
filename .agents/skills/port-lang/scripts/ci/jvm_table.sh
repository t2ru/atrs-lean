#!/usr/bin/env bash
# assets/lean/LangSemanticsTest/JavaJvm.lean が、JVM での生成器の出力と一致することを確かめる（port-lang の道具。scripts/README.md）。
# java が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
#   <skill>/scripts/ci/jvm_table.sh
set -euo pipefail
assets="$(cd "$(dirname "$0")/../../assets/lean" && pwd)"

if ! command -v java > /dev/null; then
  if [ -n "${CI:-}" ]; then echo "java not found (required in CI)" >&2; exit 1; fi
  echo "java not found: skipped"; exit 2
fi
jvm="$(mktemp)"
trap 'rm -f "$jvm"' EXIT
(cd "$assets" && java LangSemanticsTest/jvm/JavaTable.java > "$jvm" 2> /dev/null)
diff -u "$assets/LangSemanticsTest/JavaJvm.lean" "$jvm"
echo "JavaJvm.lean: up to date ($(java -version 2>&1 | grep -m1 version))"
