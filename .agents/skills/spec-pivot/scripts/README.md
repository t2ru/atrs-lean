# scripts: spec-pivot の道具

アプリに依存しない追跡・検査の道具。プロジェクト固有の値は、プロジェクトのリポジトリの `trace/project.json` から読む
（形は [references/docs/spec/traceability.md](../references/docs/spec/traceability.md#プロジェクトの設定)）。
どの道具も、作業ディレクトリから上にたどって `trace/project.json` があるところをリポジトリのルートとする
（`--repo <dir>` でも指定できる）。下の `<skill>` は、このスキルの置き場所である。

| 道具 | 内容 | 依存 |
| --- | --- | --- |
| `trace/`（Rust の crate） | 両端の追跡: インベントリ・manifest と生成区画・TR 検査（原典のソースツリーとの対応 TR-M を含む）・`rehash`・`diff`・`impact`・原典とモデルの対照表 `review`（[references/docs/spec/traceability.md](../references/docs/spec/traceability.md#道具)） | Cargo（tree-sitter-java・tree-sitter-rust・serde・sha2・roxmltree・globset）、`git` |
| `ci/check_lean.py` | Lean ソースの静的検査（`sorry`・`axiom`・`native_decide`・`Float`・`partial` などと、名前空間の依存の向き。[references/docs/lang/lean/rules.md](../references/docs/lang/lean/rules.md)・[architecture.md](../references/docs/spec/architecture.md#依存の向き)）。`--self-test` で違反例（`ci/fixtures/lean/`）を確かめる | Python 3（標準ライブラリだけ） |
| `ci/check_obligations.py` | `lake exe obligation-check` の結果と、課題一覧（入口の R 課題・非決定性・証明課題）・作業項目の状態の突き合わせ（TR-G の文書側・TR-N）。`--self-test` で `ci/fixtures/obligations/` を確かめる | Python 3 |
| `ci/check_upstream.py` | 上流の submodule の commit と `trace/upstream.json` の一致 | Python 3、`git` |
| `ci/with_postgres.sh` | PostgreSQL に接続できる環境でコマンドを実行する（無ければ一時クラスタ。[sql/dialects/postgresql/harness.md](../references/docs/lang/sql/dialects/postgresql/harness.md)） | PostgreSQL |
| `ci/jvm_table.sh`・`ci/pg_table.sh` | `assets/lean/Test.LangSemantics` の JVM・PostgreSQL との突き合わせ表が、生成器の出力と一致することを確かめる。処理系が無ければ、CI では失敗し、ローカルでは飛ばす（終了コード 2） | JDK / PostgreSQL |
| `lean/rename.py` | Lean の宣言・モジュールの完全名を、対応表（`{旧: 新}`）からリポジトリのテキスト（`.lean`・`.md`・`.json` など）で一度に書き換える（`apply`）。旧い名前の残りを列挙する（`check`）。名前空間の接頭辞を書けば、その下もまとめて写る。`--self-test` で確かめる（[references/docs/lang/lean/rules.md](../references/docs/lang/lean/rules.md#モジュールと名前空間)） | Python 3（標準ライブラリだけ）、`git` |
| `docs/okf_check.py` | OKF v0.2 のバンドルの検査（frontmatter・`type`・`index.md`・`log.md`、プロファイルの規則、索引の網羅）と、Markdown の相対リンク・見出しアンカーの検査。設定は `trace/project.json` の `okf`、スキルのバンドルの規則は `docs/profiles/spec-pivot.json`。`--self-test` で `ci/fixtures/okf/` を確かめる（[references/docs/rules/maintenance.md](../references/docs/rules/maintenance.md#バンドルの検査)） | Python 3（標準ライブラリだけ） |
| `docs/docmv.py` | 文書のバンドルの中でファイル・ディレクトリを移し（`git mv`）、リポジトリの Markdown の相対リンクと、コード・設定を含むテキストの中のパスの言及（`<バンドルの末尾 2 成分>/<old>`）を一度に張り直す。いくつもの移動を 1 回で行う。コードの中のリンクの形は張り直さない。`--dry-run` で確かめてから実行する。リポジトリのルートは `git` で決める。`--self-test` で一時リポジトリの例を確かめる（[references/docs/rules/maintenance.md](../references/docs/rules/maintenance.md#frontmatter)） | Python 3（標準ライブラリだけ）、`git` |
| `docs/ids.py` | 任意。意思決定記録・作業項目の ID（UUID v4）の採番（`new`）・参照の検査（`check`）・置き場所の間の移動とリンクの張り直し（`move`）・旧番号からの書き換え（`migrate`）。置き場所は種類ごとに複数でよく（プロジェクトの `docs/` とスキルの `references/docs/`）、持ち出すバンドル（スキル）が外を指していないことも検査する。設定は `trace/project.json` の `ids`。スキルの記録の書き方は [references/docs/rules/maintenance.md](../references/docs/rules/maintenance.md) | Python 3、`git` |

## 使い方（リポジトリのルートで）

```bash
cargo build --release --manifest-path <skill>/scripts/trace/Cargo.toml
(cd lean && lake exe trace-dump > /tmp/dump.json && lake exe obligation-check > /tmp/ob.json)
<skill>/scripts/trace/target/release/trace inventory source --check
<skill>/scripts/trace/target/release/trace manifest --dump /tmp/dump.json --obligations /tmp/ob.json --check
<skill>/scripts/trace/target/release/trace check --dump /tmp/dump.json --obligations /tmp/ob.json
<skill>/scripts/trace/target/release/trace review --dump /tmp/dump.json   # build/review/index.html（生成物）
python3 -I <skill>/scripts/ci/check_lean.py
python3 -I <skill>/scripts/ci/check_obligations.py /tmp/ob.json
python3 -I <skill>/scripts/docs/okf_check.py
```

- `lake exe trace-dump`・`obligation-check`・`axiom-check` の入口（`main`）は、モデルを import するプロジェクトの側に置く。
  本体はスキルの `assets/lean/Trace`（`Trace.Dump`・`Trace.Obligation`）にある（[references/docs/lang/lean/trace-attributes.md](../references/docs/lang/lean/trace-attributes.md)）。
- `lake exe layout-check`（宣言がモジュール名の下にあること）の本体は `assets/lean/Trace/Layout.lean`。入口は、スキルの assets（`assets/lean/Test/Trace/LayoutCheck.lean`）とプロジェクトの側（例: `lean/Tools/LayoutCheck.lean`）に置く。
- 道具の自己テスト: `cargo test --release`（`scripts/trace` で）、`check_lean.py --self-test`、`check_obligations.py --self-test`、`okf_check.py --self-test`、`docmv.py --self-test`、`lean/rename.py --self-test`、`lake exe trace-test`（`assets/lean` で）。
- CI は、これらをプロジェクトの一括検査のスクリプトから呼ぶ。
