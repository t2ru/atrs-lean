#!/usr/bin/env bash
# <command> を実行し、終了コード 2（「処理系が無いので飛ばした」。ローカルだけ。CI では 1 になる）を 0 に読み替える（mise.toml）。
#   tools/ci/skippable.sh <command> [args...]
rc=0
"$@" || rc=$?
[ "$rc" -eq 2 ] && exit 0
exit "$rc"
