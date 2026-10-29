# AGENTS.md

このリポジトリは、TERASOLUNA のサンプルアプリケーション **ATRS（航空券予約システム）** の
Thymeleaf 版を、**Lean 4 で形式化したモデルと仕様** を介して **Rust** へ移植するプロジェクトである。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(Java/SQL)           (Lean)                       (Lean)            (Lean)                 (Rust)
```
最終目標は **他のあらゆる言語へ同一ロジックを移植できる、検証可能な仕様** を得ることにある。

- 正規仕様は Lean の `Spec`。`Spec` で表現できない仕様だけを `docs/spec` で定義する（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
- モデルと証明はすべて Lean に置く。移植先ソースは Rust。`TargetModel` ⇔ Rust は追跡注釈・適合テスト・Verus・Kani で確認する（[ADR 0022](docs/decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。
- トレースは両端の 2 本だけ。**移植元ソースと移植先ソースは直接つながない**（[ADR 0023](docs/decision/0023-cross-language-traceability.md)）。
- 移植元の版上げに追従する。`SourceModel` は最新版のみ（[ADR 0024](docs/decision/0024-following-upstream-releases.md)、[port-lang/upgrade.md](.agents/skills/port-lang/references/upgrade.md)）。
- 移植の方法はアプリに依存しないスキル **port-lang** に、ATRS 固有の情報は `docs/` に置く（[ADR 0025](docs/decision/0025-extract-porting-method-as-agent-skill.md)）。

- 上流ソース: <https://github.com/terasolunaorg/atrs> の `JavaConfig-Thymeleaf/`
  - branch `release/5.11.0.RELEASE` / commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`

## 作業前に必ず読むもの

**すべての作業（文書・コード・証明・テスト）の前に、次の 2 つを読むこと。**

1. **言語間移植の方法**: スキル [`.agents/skills/port-lang/SKILL.md`](.agents/skills/port-lang/SKILL.md)（アプリに依存しない方法。Agent Skills 形式。[ADR 0025](docs/decision/0025-extract-porting-method-as-agent-skill.md)）。言語ごとの情報は `references/<lang>/` にあり、ATRS では `java`・`sql`（移植元）、`rust`（移植先）、`lean`（形式化）を使う。
2. **ATRS の運用規約**: [`docs/rules/README.md`](docs/rules/README.md) と、そこから参照される規約。特に [atrs-porting.md](docs/rules/atrs-porting.md)（スキルを ATRS に適用するときの固有事項）。

優先順位は、ATRS の ADR → `docs/rules/` → スキル → 本ファイルの順とする（[docs/rules/README.md](docs/rules/README.md#優先順位)）。

| 規約 | 内容 |
| --- | --- |
| [docs/rules/atrs-porting.md](docs/rules/atrs-porting.md) | ATRS への適用: 言語ペア、配置、機能名、型、必須の依存、追従中の上流 |
| [docs/rules/documentation.md](docs/rules/documentation.md) | 文書全般（言語・用語・リンク・出典記法・OKF） |
| [docs/rules/decision-records.md](docs/rules/decision-records.md) | 意思決定記録（MADR, `NNNN-<slug>.md`） |
| [docs/rules/backlog.md](docs/rules/backlog.md) | バックログ運用と完了の定義 |
| [docs/rules/version-control.md](docs/rules/version-control.md) | git（作業の区切りで commit、push しない） |

## ディレクトリ地図

| パス | 役割 |
| --- | --- |
| [docs/index.md](docs/index.md) | **文書インデックス**。`docs/` は OKF v0.2 の Knowledge Bundle（[ADR 0017](docs/decision/0017-documentation-format-okf-v0-2.md)） |
| [docs/log.md](docs/log.md) | 文書の変更履歴 |
| [docs/decision/](docs/decision/) | 意思決定記録（ADR, MADR 形式）。設計判断の唯一の記録場所 |
| [docs/spec/](docs/spec/) | Lean `Spec` で表現できない仕様（規範）、文書メタ情報、形式化前の草案 |
| [docs/backlog/](docs/backlog/) | 作業項目。着手順と依存関係 |
| [docs/rules/](docs/rules/) | ATRS の運用規約 |
| [.agents/skills/port-lang/](.agents/skills/port-lang/SKILL.md) | 言語間移植の方法（アプリ非依存のスキル） |
| `lakefile.lean`（ルート） | Lake ワークスペース。Lean の LSP がリポジトリのルートから `import` を解決するために、`lean/` とスキルの `assets` を `require` する |
| `lean/`（予定） | Lean プロジェクト。`LangSemantics` / `SourceModel` / `Spec`（正規仕様）/ `Abstraction` / `TargetModel` / `Refinement`（[backlog 0001](docs/backlog/0001-lean-project-scaffold.md)） |
| `rust/`（予定） | 移植先ソース。業務機能、`model/`（`TargetModel` の Verus 写し）、`proof/`、`kani/`、`tests/`（[backlog 0018](docs/backlog/0018-rust-project-scaffold.md)） |
| `upstream/atrs`（予定） | 移植元ソース（git submodule、commit 固定。[backlog 0025](docs/backlog/0025-upstream-submodule-and-inventory.md)） |
| `trace/`（予定） | 版の宣言・インベントリ・manifest（[ADR 0023](docs/decision/0023-cross-language-traceability.md)） |
| `tools/trace/`（予定） | 追跡の道具（[backlog 0024](docs/backlog/0024-trace-tooling.md)） |
| `conformance/`（予定） | 言語中立な適合テストベクタ（[ADR 0013](docs/decision/0013-conformance-test-vectors.md)） |

## 基本原則（要約。詳細は各規約・ADR）

1. 正規仕様は Lean `Spec` と、`docs/spec` の規範節（`Spec` で表現できない仕様）である。実装は仕様に従い、仕様にない振る舞いを実装してはならない（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
2. Lean のトップレベル名前空間は次に統一する（[ADR 0022](docs/decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。
   - `LangSemantics.<lang>` 言語意味論モデル（アプリ非依存。`Java`, `Sql`, `Rust`）
   - `SourceModel` 移植元モデル（移植元ソース Java/SQL の振る舞いを意味論ごと写す）
   - `Spec` 抽象モデル（言語中立・厳密整数の正規仕様）
   - `Abstraction` 移植元からの抽象化証明課題（`SourceModel` → `Spec`）
   - `TargetModel` 移植先モデル（移植先ソース Rust の振る舞いを `LangSemantics.Rust` で写す）
   - `Refinement` 移植先への具体化証明課題（`Spec` → `TargetModel`。Lean で証明）

   移植元と抽象を分けて関係を証明する方針は [ADR 0004](docs/decision/0004-two-layer-model-java-faithful-and-abstract.md)。
3. 抽象モデルでは浮動小数点数を使わない（[ADR 0006](docs/decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
4. Java との差異・仕様の変更は、必ず ADR か [docs/spec/abstraction.md](docs/spec/abstraction.md) に記録する。
5. 業務ロジックは純粋関数、副作用はポート経由（[ADR 0007](docs/decision/0007-functional-core-with-ports.md)）。
6. `docs/` の文書を追加・変更したら、frontmatter（OKF v0.2）・[docs/index.md](docs/index.md)・[docs/log.md](docs/log.md) を更新する（[documentation.md](docs/rules/documentation.md#okf-v02)）。
7. **一通りの作業が終わったら `git commit` する。`git push` はしない**（[version-control.md](docs/rules/version-control.md)）。

## 現在の状態

設計フェーズ。Lean・Rust のコードはまだ無い。次に着手するのは [backlog 0001](docs/backlog/0001-lean-project-scaffold.md)（Lean）、[backlog 0018](docs/backlog/0018-rust-project-scaffold.md)（Rust。Verus と Kani の併用確認を含む）、[backlog 0025](docs/backlog/0025-upstream-submodule-and-inventory.md)（上流の submodule 化）。
進捗は [docs/backlog/README.md](docs/backlog/README.md) を参照。
