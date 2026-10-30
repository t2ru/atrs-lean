#!/usr/bin/env bash
# LangSemanticsTest/JavaJvm.lean が、JVM での生成器の出力と一致することを確かめる（backlog 0002）。
# java が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2）。
#   tools/ci/jvm_table.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

if ! command -v java > /dev/null; then
  if [ -n "${CI:-}" ]; then echo "java not found (required in CI)" >&2; exit 1; fi
  echo "java not found: skipped"; exit 2
fi
jvm="$(mktemp)"
trap 'rm -f "$jvm"' EXIT
(cd .agents/skills/port-lang/assets/lean && java LangSemanticsTest/jvm/JavaTable.java > "$jvm" 2> /dev/null)
diff -u .agents/skills/port-lang/assets/lean/LangSemanticsTest/JavaJvm.lean "$jvm"
echo "JavaJvm.lean: up to date ($(java -version 2>&1 | grep -m1 version))"
