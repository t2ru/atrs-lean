# AGENTS.md

このリポジトリは、TERASOLUNA のサンプルアプリケーション **ATRS（航空券予約システム）** の
Thymeleaf 版を、**Lean 4 で形式化した仕様** を介して **Rust** へ移植するプロジェクトである。
最終目標は **他のあらゆる言語へ同一ロジックを移植できる、検証可能な仕様** を得ることにある。

- 正規仕様は Lean の `Spec`。`Spec` で表現できない仕様だけを `docs/spec` で定義する（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
- 移植先は Rust。`Refinement` は Verus（証明）・Kani（有界検査）・適合テストベクタで充足する（[ADR 0020](docs/decision/0020-rust-as-target-language.md)）。

- 上流ソース: <https://github.com/terasolunaorg/atrs> の `JavaConfig-Thymeleaf/`
  - branch `release/5.11.0.RELEASE` / commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`

## 作業前に必ず読むもの

**すべての作業（文書・コード・証明・テスト）の前に [`docs/rules/README.md`](docs/rules/README.md) を読み、
そこから参照される規約に従うこと。** 規約と本ファイルが矛盾する場合は `docs/rules/` が優先する。

| 規約 | 内容 |
| --- | --- |
| [docs/rules/documentation.md](docs/rules/documentation.md) | 文書全般（言語・用語・リンク・出典記法） |
| [docs/rules/decision-records.md](docs/rules/decision-records.md) | 意思決定記録（MADR, `NNNN-<slug>.md`） |
| [docs/rules/spec-writing.md](docs/rules/spec-writing.md) | 仕様の書き方（[Spec]/[Source] 併記） |
| [docs/rules/porting.md](docs/rules/porting.md) | 移植の進め方（原典 → spec → 形式化 → 証明 → 移植先） |
| [docs/rules/portability.md](docs/rules/portability.md) | 言語中立性の制約 |
| [docs/rules/lean.md](docs/rules/lean.md) | Lean コーディング・証明規約 |
| [docs/rules/rust.md](docs/rules/rust.md) | Rust・Verus・Kani 規約 |
| [docs/rules/version-control.md](docs/rules/version-control.md) | git（作業の区切りで commit、push しない） |
| [docs/rules/testing.md](docs/rules/testing.md) | 適合テストベクタ・性質テスト・証明 |
| [docs/rules/backlog.md](docs/rules/backlog.md) | バックログ運用と完了の定義 |

## ディレクトリ地図

| パス | 役割 |
| --- | --- |
| [docs/index.md](docs/index.md) | **文書インデックス**。`docs/` は OKF v0.2 の Knowledge Bundle（[ADR 0017](docs/decision/0017-documentation-format-okf-v0-2.md)） |
| [docs/log.md](docs/log.md) | 文書の変更履歴 |
| [docs/decision/](docs/decision/) | 意思決定記録（ADR, MADR 形式）。設計判断の唯一の記録場所 |
| [docs/spec/](docs/spec/) | Lean `Spec` で表現できない仕様（規範）、文書メタ情報、形式化前の草案 |
| [docs/backlog/](docs/backlog/) | 作業項目。着手順と依存関係 |
| [docs/rules/](docs/rules/) | 作業規約 |
| `lean/`（予定） | Lean プロジェクト。`LangSemantics` / `SourceModel` / `Spec`（正規仕様）/ `Abstraction`（[backlog 0001](docs/backlog/0001-lean-project-scaffold.md)） |
| `rust/`（予定） | 移植先。`spec`（Verus の写し）/ `target_model` / `refinement`（[backlog 0018](docs/backlog/0018-rust-project-scaffold.md)） |
| `conformance/`（予定） | 言語中立な適合テストベクタ（[ADR 0013](docs/decision/0013-conformance-test-vectors.md)） |

## 基本原則（要約。詳細は各規約・ADR）

1. 正規仕様は Lean `Spec` と、`docs/spec` の規範節（`Spec` で表現できない仕様）である。実装は仕様に従い、仕様にない振る舞いを実装してはならない（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
2. トップレベル名前空間は言語を問わず次に統一する（[ADR 0018](docs/decision/0018-language-neutral-top-level-namespaces.md)）。
   - `LangSemantics.<lang>` 言語意味論モデル（アプリ非依存。現在は `LangSemantics.Java`, `LangSemantics.Sql`。Lean のみ）
   - `SourceModel` 移植元モデル（原典 Java/SQL の振る舞いを意味論ごと写す）
   - `Spec` 抽象モデル（言語中立・厳密整数の正規仕様）
   - `Abstraction` 移植元からの抽象化証明課題（`SourceModel` → `Spec`）
   - `TargetModel` 移植先モデル（Rust の実装）
   - `Refinement` 移植先への具体化証明課題（`Spec` → `TargetModel`。Verus・Kani・適合テスト）

   移植元と抽象を分けて関係を証明する方針は [ADR 0004](docs/decision/0004-two-layer-model-java-faithful-and-abstract.md)。
3. 抽象モデルでは浮動小数点数を使わない（[ADR 0006](docs/decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
4. Java との差異・仕様の変更は、必ず ADR か [docs/spec/abstraction.md](docs/spec/abstraction.md) に記録する。
5. 業務ロジックは純粋関数、副作用はポート経由（[ADR 0007](docs/decision/0007-functional-core-with-ports.md)）。
6. `docs/` の文書を追加・変更したら、frontmatter（OKF v0.2）・[docs/index.md](docs/index.md)・[docs/log.md](docs/log.md) を更新する（[documentation.md](docs/rules/documentation.md#okf-v02)）。
7. **一通りの作業が終わったら `git commit` する。`git push` はしない**（[version-control.md](docs/rules/version-control.md)）。

## 現在の状態

設計フェーズ。Lean・Rust のコードはまだ無い。次に着手するのは [backlog 0001](docs/backlog/0001-lean-project-scaffold.md)（Lean）と [backlog 0018](docs/backlog/0018-rust-project-scaffold.md)（Rust。Verus と Kani の併用確認を含む）。
進捗は [docs/backlog/README.md](docs/backlog/README.md) を参照。
