# Directory Update Log

## 2026-10-29

* **Update**: リポジトリのルートを Lake ワークスペースにした（`lakefile.lean` が `.agents/skills/port-lang/assets` を `require`）。ルートで起動した Lean LSP から `LangSemantics` の import が解決されないのを直した。手順は [atrs-porting.md](rules/atrs-porting.md) とスキルの [lean/rules.md](../.agents/skills/port-lang/references/lean/rules.md)。

* **Creation**: スキル port-lang に `assets/LangSemantics/<Lang>/`（Java・Sql・Sql.Postgresql・Rust の Lean モデル。core のみ、`#guard` 検査付き）を追加した。backlog [0002](backlog/0002-lang-semantics-java.md)・[0016](backlog/0016-lang-semantics-sql.md)・[0021](backlog/0021-lang-semantics-rust.md) はこれを起点とする。

* **Creation**: [ADR 0025](decision/0025-extract-porting-method-as-agent-skill.md)。言語間移植の方法を、アプリ非依存のスキル `.agents/skills/port-lang`（Agent Skills 形式）に切り出した。言語パック（java・sql・rust）は、移植元・移植先のどちらにもなれる 6 ファイル構成とした。
* **Deprecation**: `docs/rules/` から porting・spec-writing・portability・testing・upstream-upgrade・lean・rust をスキルへ移した（git mv）。
* **Creation**: [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの ATRS への適用）を追加した。
* **Update**: [spec/conformance.md](spec/conformance.md)・[spec/traceability.md](spec/traceability.md)・[spec/refinement.md](spec/refinement.md) を ATRS 固有の内容に絞った。ADR・backlog・spec の、移動した規約へのリンクを張り替えた。

* **Creation**: [ADR 0022](decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)（モデルと証明をすべて Lean に置き、`TargetModel` を Lean のモデル、Rust を移植先ソースとする）、[ADR 0023](decision/0023-cross-language-traceability.md)（両端の追跡: ロケータ・モデル側注釈・確認済みハッシュ・TR 検査）、[ADR 0024](decision/0024-following-upstream-releases.md)（上流の版上げ追従・差分オラクル）を作成した。
* **Deprecation**: [ADR 0018](decision/0018-language-neutral-top-level-namespaces.md) と [ADR 0020](decision/0020-rust-as-target-language.md) を ADR 0022 で置き換えた。
* **Creation**: 規約 [port-lang/upgrade.md](../.agents/skills/port-lang/references/upgrade.md)（版上げ手順、draft）を追加した。
* **Update**: [port-lang/lean/rules.md](../.agents/skills/port-lang/references/lean/rules.md)・[port-lang/rust/layout.md](../.agents/skills/port-lang/references/rust/layout.md)・porting・testing・version-control・spec-writing・documentation を新構成と追跡注釈に合わせて改訂した。
* **Update**: [spec/traceability.md](spec/traceability.md) をロケータ文法・注釈・検査・運賃の追跡例を含む形に書き直した。[spec/refinement.md](spec/refinement.md) を REF（Lean で証明）と SRC（TargetModel ⇔ Rust の確認）に分けた。[spec/conformance.md](spec/conformance.md) に `target-model/`・`modelDef`・`upstream` を追加した。
* **Update**: バックログ 0001・0007・0011・0014・0018〜0020 を改訂し、0021〜0026 を追加した。

* **Creation**: [ADR 0020](decision/0020-rust-as-target-language.md)（移植先を Rust とし、Refinement を Verus・Kani・適合テストで充足）と [ADR 0021](decision/0021-lean-spec-as-normative-source.md)（Lean `Spec` を正規とし、`Spec` で表現できない仕様だけを docs/spec で定義）を作成した。
* **Deprecation**: [ADR 0003](decision/0003-spec-as-normative-source.md) を ADR 0021 で置き換えた。
* **Update**: [ADR 0018](decision/0018-language-neutral-top-level-namespaces.md) の配置の記述を ADR 0020 に合わせた（Lean は `TargetModel`・`Refinement` を持たない）。ADR 0002・0011・0013・0014 の関連箇所を更新した。
* **Creation**: 規約 [port-lang/rust/layout.md](../.agents/skills/port-lang/references/rust/layout.md)（draft）と [rules/version-control.md](rules/version-control.md)（作業の区切りで commit、push しない）を追加した。
* **Update**: docs/spec の全文書に区分 `spec_role`（normative / meta / draft）を付け、[spec/refinement.md](spec/refinement.md) を Rust 向けに書き直した。
* **Update**: バックログ 0001・0011・0012・0014 を Rust 方針に合わせて改訂し、0015 を取りやめ、0018〜0020 を追加した。

* **Creation**: OKF v0.2 バンドルとして [docs/index.md](index.md) と本ログを作成した（[ADR 0017](decision/0017-documentation-format-okf-v0-2.md)）。
* **Creation**: 作業規約 [rules/](rules/README.md) 9 件を作成した。
* **Creation**: ADR 0001〜0019 を作成した。層の名前とトップレベル名前空間（`LangSemantics.<lang>` / `SourceModel` / `Spec` / `Abstraction` / `TargetModel` / `Refinement`）は [ADR 0018](decision/0018-language-neutral-top-level-namespaces.md)、SQL 意味論は [ADR 0019](decision/0019-sql-semantics-for-source-repositories.md)。
* **Creation**: 正規仕様 [spec/](spec/README.md) 初版（draft、未レビュー）を作成した。上流 commit `f4bfbf0615eb91805546c9c780d4761be92ce17e` を調査対象とした。
* **Creation**: バックログ [backlog/](backlog/README.md) 0001〜0017 を作成した。
