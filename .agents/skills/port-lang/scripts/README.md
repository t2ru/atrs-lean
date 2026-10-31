# scripts: port-lang の道具

アプリに依存しない追跡・検査の道具。プロジェクト固有の値は、プロジェクトのリポジトリの `trace/project.json` から読む
（形は [references/traceability.md](../references/traceability.md#プロジェクトの設定)）。
どの道具も、作業ディレクトリから上にたどって `trace/project.json` があるところをリポジトリのルートとする
（`--repo <dir>` でも指定できる）。下の `<skill>` は、このスキルの置き場所である。

| 道具 | 内容 | 依存 |
| --- | --- | --- |
| `trace/`（Rust の crate） | 両端の追跡: インベントリ・manifest と生成区画・TR 検査・`rehash`・`diff`・`impact`（[references/traceability.md](../references/traceability.md#道具)） | Cargo（tree-sitter-java・tree-sitter-rust・serde・sha2・roxmltree・globset）、`git` |
| `ci/check_lean.py` | Lean ソースの静的検査（`sorry`・`axiom`・`native_decide`・`Float`・`partial` などと、名前空間の依存の向き。[references/lean/rules.md](../references/lean/rules.md)・[architecture.md](../references/architecture.md#依存の向き)）。`--self-test` で違反例（`ci/fixtures/lean/`）を確かめる | Python 3（標準ライブラリだけ） |
| `ci/check_obligations.py` | `lake exe obligation-check` の結果と、課題一覧（入口の R 課題・非決定性・証明課題）・作業項目の状態の突き合わせ（TR-G の文書側・TR-N）。`--self-test` で `ci/fixtures/obligations/` を確かめる | Python 3 |
| `ci/check_upstream.py` | 上流の submodule の commit と `trace/upstream.json` の一致 | Python 3、`git` |
| `ci/with_postgres.sh` | PostgreSQL に接続できる環境でコマンドを実行する（無ければ一時クラスタ。[sql/dialects/postgresql/harness.md](../references/sql/dialects/postgresql/harness.md)） | PostgreSQL |
| `ci/jvm_table.sh`・`ci/pg_table.sh` | `assets/lean/LangSemanticsTest` の JVM・PostgreSQL との突き合わせ表が、生成器の出力と一致することを確かめる。処理系が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2） | JDK / PostgreSQL |
| `docs/ids.py` | 任意。意思決定記録・作業項目の ID（UUID v4）の採番（`new`）・参照の検査（`check`）・旧番号からの書き換え（`migrate`）。設定は `trace/project.json` の `ids` | Python 3、`git` |

## 使い方（リポジトリのルートで）

```bash
cargo build --release --manifest-path <skill>/scripts/trace/Cargo.toml
(cd lean && lake exe trace-dump > /tmp/dump.json && lake exe obligation-check > /tmp/ob.json)
<skill>/scripts/trace/target/release/trace inventory source --check
<skill>/scripts/trace/target/release/trace manifest --dump /tmp/dump.json --obligations /tmp/ob.json --check
<skill>/scripts/trace/target/release/trace check --dump /tmp/dump.json --obligations /tmp/ob.json
python3 -I <skill>/scripts/ci/check_lean.py
python3 -I <skill>/scripts/ci/check_obligations.py /tmp/ob.json
```

- `lake exe trace-dump`・`obligation-check`・`axiom-check` の入口（`main`）は、モデルを import するプロジェクトの側に置く。
  本体はスキルの `assets/lean/Trace`（`Trace.Dump`・`Trace.Obligation`）にある（[references/lean/trace-attributes.md](../references/lean/trace-attributes.md)）。
- 道具の自己テスト: `cargo test --release`（`scripts/trace` で）、`check_lean.py --self-test`、`check_obligations.py --self-test`。
- CI は、これらをプロジェクトの一括検査のスクリプトから呼ぶ。
