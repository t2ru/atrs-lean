# scripts: spec-pivot の道具

アプリに依存しない追跡・検査の道具。プロジェクト固有の値は、プロジェクトのリポジトリの `trace/project.json` から読む
（形は [references/docs/spec/traceability.md](../references/docs/spec/traceability.md#プロジェクトの設定)）。
どの道具も、作業ディレクトリから上にたどって `trace/project.json` があるところをリポジトリのルートとする
（`--repo <dir>` でも指定できる）。下の `<skill>` は、このスキルの置き場所である。

文書（OKF のバンドルとリンク、文書の移動）と記録（意思決定記録・作業項目の ID）の道具は、別のスキル okf-bundle（`scripts/okf_check.py`・`scripts/docmv.py`）と work-records（`scripts/ids.py`）にある。設定も、それぞれのスキルの設定ファイル（`.okf.json`・`.work-records.json`）に置く。

| 道具 | 内容 | 依存 |
| --- | --- | --- |
| `trace/`（Rust の crate） | 両端の追跡: インベントリ・manifest と生成区画・TR 検査（原典のソースツリーとの対応 TR-M を含む）・`rehash`・`diff`・`impact`・原典とモデルの対照表 `review`（[references/docs/spec/traceability.md](../references/docs/spec/traceability.md#道具)） | Cargo（tree-sitter-java・tree-sitter-rust・serde・sha2・roxmltree・globset）、`git` |
| `ci/check_lean.py` | Lean ソースの静的検査（`sorry`・`axiom`・`native_decide`・`Float`・`partial` などと、名前空間の依存の向き。[references/docs/lang/lean/rules.md](../references/docs/lang/lean/rules.md)・[architecture.md](../references/docs/spec/architecture.md#依存の向き)）。`--self-test` で違反例（`ci/fixtures/lean/`）を確かめる | Python 3（uv。標準ライブラリだけ） |
| `ci/check_obligations.py` | `lake exe obligation-check` の結果と、課題一覧（入口の R 課題・非決定性・証明課題）・作業項目の状態の突き合わせ（TR-G の文書側・TR-N）。`--self-test` で `ci/fixtures/obligations/` を確かめる | Python 3（uv） |
| `ci/check_upstream.py` | 上流の submodule の commit と `trace/upstream.json` の一致 | Python 3（uv）、`git` |
| `ci/with_postgres.sh` | PostgreSQL に接続できる環境でコマンドを実行する（無ければ一時クラスタ。`WITH_POSTGRES_TCP=1` なら 127.0.0.1 でも待ち受け、`PGHOST`・`PGPORT` を渡す。[sql/dialects/postgresql/harness.md](../references/docs/lang/sql/dialects/postgresql/harness.md)） | PostgreSQL |
| `ci/jvm_table.sh`・`ci/pg_table.sh` | `assets/lean/Test.LangSemantics` の JVM・PostgreSQL との突き合わせ表が、生成器の出力と一致することを確かめる。処理系が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2） | JDK / PostgreSQL |
| `lean/rename.py` | Lean の宣言・モジュールの完全名を、対応表（`{旧: 新}`）からリポジトリのテキスト（`.lean`・`.md`・`.json` など）で一度に書き換える（`apply`）。旧い名前の残りを列挙する（`check`）。名前空間の接頭辞を書けば、その下もまとめて写る。`--self-test` で確かめる（[references/docs/lang/lean/rules.md](../references/docs/lang/lean/rules.md#モジュールと名前空間)） | Python 3（uv。標準ライブラリだけ）、`git` |

## 使い方（リポジトリのルートで）

```bash
cargo build --release --manifest-path <skill>/scripts/trace/Cargo.toml
(cd lean && lake exe trace-dump > /tmp/dump.json && lake exe obligation-check > /tmp/ob.json)
<skill>/scripts/trace/target/release/trace inventory source --check
<skill>/scripts/trace/target/release/trace manifest --dump /tmp/dump.json --obligations /tmp/ob.json --check
<skill>/scripts/trace/target/release/trace check --dump /tmp/dump.json --obligations /tmp/ob.json
<skill>/scripts/trace/target/release/trace review --dump /tmp/dump.json   # build/review/index.html（生成物）
uv run python -I <skill>/scripts/ci/check_lean.py
uv run python -I <skill>/scripts/ci/check_obligations.py /tmp/ob.json
```

- `lake exe trace-dump`・`obligation-check`・`axiom-check` の入口（`main`）は、モデルを import するプロジェクトの側に置く。
  本体はスキルの `assets/lean/Trace`（`Trace.Dump`・`Trace.Obligation`）にある（[references/docs/lang/lean/trace-attributes.md](../references/docs/lang/lean/trace-attributes.md)）。
- `lake exe layout-check`（宣言がモジュール名の下にあること）の本体は `assets/lean/Trace/Layout.lean`。入口は、スキルの assets（`assets/lean/Test/Trace/LayoutCheck.lean`）とプロジェクトの側（例: `lean/Tools/LayoutCheck.lean`）に置く。
- 道具の自己テスト: `cargo test --release`（`scripts/trace` で）、`check_lean.py --self-test`、`check_obligations.py --self-test`、`lean/rename.py --self-test`、`lake exe trace-test`（`assets/lean` で）。
- Python の道具は uv で実行する（`uv run python -I`。版は適用先の `.python-version`・`pyproject.toml` に従う。[ADR 8cb7](../references/docs/decision/8cb7-run-python-tools-with-uv.md)）。
- CI は、これらをプロジェクトの一括検査（タスクの実行器やスクリプト。実行器は適用先が選ぶ）から呼ぶ。
