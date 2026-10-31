#!/usr/bin/env bash
# Lean 側の検査を一括で実行する（CI とローカルで共通。backlog be49・455f・1ae4・a8be・f7b7・c7e8・ffdc・25f7）。
#   tools/ci/lean.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

step() { printf '\n== %s\n' "$*"; }

step "upstream: submodule の commit と trace/upstream.json の一致"
python3 -I tools/ci/check_upstream.py

step "docs: ADR・backlog の ID・ファイル名・参照（ADR f57e）"
python3 -I tools/docs/ids.py check

step "conformance: 共有入力（fixtures/master-data.json・config.json）が上流のシード・設定からの生成と一致する"
python3 -I tools/conformance/master_fixture.py --check

step "static: 静的検査の自己テスト（違反例を検出できること）"
python3 -I tools/ci/check_lean.py --self-test

step "static: sorry・axiom・native_decide・Float・partial 等と、名前空間の依存の向き"
python3 -I tools/ci/check_lean.py

step "static: 証明義務と文書の突き合わせの自己テスト（違反例を検出できること）"
python3 -I tools/ci/check_obligations.py --self-test

# 終了コード 2 は「処理系が無いので飛ばした」（ローカルだけ。CI では 1 になる）。
skippable() { local rc=0; "$@" || rc=$?; [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || exit "$rc"; }

step "assets/lean: JVM との突き合わせ表（LangSemanticsTest/JavaJvm.lean）が生成器の出力と一致する"
skippable tools/ci/jvm_table.sh

step "assets/lean: PostgreSQL との突き合わせ表（LangSemanticsTest/PostgresqlDb.lean）が生成器の出力と一致する"
skippable tools/ci/pg_table.sh

step "conformance: マスタの Mapper の文・コードリストの SQL の PostgreSQL での結果（conformance/sql/master-data.json）が最新である"
skippable tools/ci/master_sql.sh

step "assets/lean: lake build（LangSemantics・Machine・Trace と、その検査 LangSemanticsTest・MachineTest・TraceTest）"
(cd .agents/skills/port-lang/assets/lean && lake build)

step "assets/lean: trace-test（trace-dump・obligation-check の処理をフィクスチャにかける）"
(cd .agents/skills/port-lang/assets/lean && lake exe trace-test)

step "lean: lake build"
(cd lean && lake build)

step "lean: lake test"
(cd lean && lake test)

step "lean: 公理の検査"
(cd lean && lake exe axiom-check)

out="$(mktemp)"
ob="$(mktemp)"
trap 'rm -f "$out" "$ob"' EXIT

step "lean: obligation-check（R 課題の形と付帯の義務。TR-G）と文書の突き合わせ（TR-N）"
(cd lean && lake exe obligation-check > "$ob")
python3 -I tools/ci/check_obligations.py "$ob"

step "lean: trace-dump"
(cd lean && lake exe trace-dump > "$out")
python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1]))
print("trace-dump: %d definitions (Lean %s)" % (len(d["definitions"]), d["lean_version"]))' "$out"

step "trace: tools/trace の自己テスト（違反例を検出できること）"
(cd tools/trace && cargo test --release --quiet)
(cd tools/trace && cargo build --release --quiet)
trace=tools/trace/target/release/trace

step "trace: インベントリ・manifest・traceability.md の生成区画が最新である"
"$trace" inventory source --check
"$trace" inventory target --check
"$trace" manifest --dump "$out" --obligations "$ob" --check

step "trace: 追跡の検査（TR-S1/S2/T1/T2/P/PE/D/X/R、TR-G・TR-N）"
"$trace" check --dump "$out" --obligations "$ob"

step "workspace: ルートで lake setup-file（Lean LSP 用）"
lake setup-file lean/Spec.lean > /dev/null
lake setup-file lean/Tests/Main.lean > /dev/null
lake setup-file .agents/skills/port-lang/assets/lean/LangSemantics.lean > /dev/null
lake setup-file .agents/skills/port-lang/assets/lean/Machine.lean > /dev/null

step "OK"
