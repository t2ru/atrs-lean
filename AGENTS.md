# AGENTS.md

このリポジトリは、TERASOLUNA のサンプルアプリケーション **ATRS（航空券予約システム）** の
Thymeleaf 版を、**Lean 4 で形式化したモデルと仕様** を介して **Rust** へ移植するプロジェクトである。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(Java/SQL)           (Lean)                       (Lean)            (Lean)                 (Rust)
```
最終目標は **他のあらゆる言語へ同一ロジックを移植できる、検証可能な仕様** を得ることにある。

**基本原則**（[ADR 0033](docs/decision/0033-foundational-principles.md)。他のすべての ADR・規約・スキルに優先する）:

1. 移植元プログラムと移植元モデル、移植先プログラムと移植先モデルは、決定論的な検証または変換によって一致が確認されていなければならない。また、トレーサビリティが保たれていなければならない。
2. 抽象モデルと移植(元/先)モデルの間には、B メソッドでいうリファインメントの関係にあることが証明されていなければならない。
3. 抽象モデルと移植(元/先)モデルで一致しない点がある場合は、それを証明の中とドキュメントにおいてすべて明示されていなければならない。

手段の届かない部分（保証の限界）は [docs/spec/assurance.md](docs/spec/assurance.md) にすべて列挙する。

- 正規仕様は Lean の `Spec`。`Spec` で表現できない仕様だけを `docs/spec` で定義する（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
- モデルと証明はすべて Lean に置く。移植先ソースは Rust。`TargetModel` から Verus の写しを生成し、Verus で Rust との一致を証明する。あわせて、追跡注釈・適合テスト・Kani で確認する（[ADR 0035](docs/decision/0035-generate-verus-mirror-from-target-model.md)）。
- `SourceModel`・`TargetModel` は、それぞれ `Spec` を B メソッドの意味でリファインする。差異は `D-NNN`・`T-NNN` として、定理の名前付きの仮定と文書の両方に置く（[ADR 0034](docs/decision/0034-b-method-refinement-and-explicit-deviations.md)）。リファインメントが空虚・自明に成り立たないよう、付帯の義務（選択の像としての `Spec`、環境の固定、標準の貼り合わせ、入口の全域性など）を課す（[ADR 0039](docs/decision/0039-refinement-non-vacuity-obligations.md)）。
- トレースは両端の 2 本だけ。**移植元ソースと移植先ソースは直接つながない**（[ADR 0036](docs/decision/0036-traceability-hash-as-deterministic-check-record.md)）。
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
| [docs/rules/version-control.md](docs/rules/version-control.md) | git（作業の区切りで commit。push は自分で作ったブランチに限り、PR を作成してよい） |

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
| `lakefile.lean`（ルート） | Lake ワークスペース。Lean の LSP がリポジトリのルートから `import` を解決するために、`lean/` とスキルの `assets/lean` を `require` する |
| `lean/` | Lean プロジェクト（パッケージ `atrs`）。`Trace`（追跡属性・trace-dump）/ `Spec`（正規仕様）/ `SourceModel` / `Abstraction` / `TargetModel` / `Refinement` / `Tests` / `Tools`。`LangSemantics` はスキルの `assets/lean` を Lake 依存として取り込む（[backlog 0001](docs/backlog/0001-lean-project-scaffold.md)） |
| `rust/`（予定） | 移植先ソース。業務機能、`model/`（`TargetModel` の Verus 写し）、`proof/`、`kani/`、`tests/`（[backlog 0018](docs/backlog/0018-rust-project-scaffold.md)） |
| `upstream/atrs` | 移植元ソース（git submodule、commit 固定。[backlog 0025](docs/backlog/0025-upstream-submodule-and-inventory.md)） |
| `trace/` | 版の宣言（`upstream.json`）・対象外一覧（`out-of-scope.json`）・機能と backlog の対応表（`features.json`）・インベントリ（`source-inventory.json`・`target-inventory.json`）・manifest（[ADR 0036](docs/decision/0036-traceability-hash-as-deterministic-check-record.md)、[ADR 0040](docs/decision/0040-trace-tooling-unresolved-details.md)） |
| `tools/ci/` | CI の検査。`lean.sh`（Lean 側の一括検査。ローカルでも実行する）、`check_lean.py`（`sorry`・`axiom`・`Float`・依存の向きなど）、`check_upstream.py`（上流の commit と宣言の一致）、`check_obligations.py`（`obligation-check` の結果と登録簿の突き合わせ。TR-G・TR-N） |
| `tools/trace/` | 追跡の道具（Rust の CLI。`inventory`・`manifest`・`check`・`rehash`・`diff`・`impact`。[backlog 0024](docs/backlog/0024-trace-tooling.md)）。`rehash` が実行する検査は `trace/checks.json` に登録する |
| `conformance/` | 言語中立な適合テストベクタ（[ADR 0013](docs/decision/0013-conformance-test-vectors.md)）。`lake test` が `Spec`・`SourceModel` に対して実行する。共有入力 `fixtures/` は `tools/conformance/master_fixture.py` が上流のシードから生成する |

## 主要な規則（要約。詳細は各規約・ADR）

1. 正規仕様は Lean `Spec` と、`docs/spec` の規範節（`Spec` で表現できない仕様）である。実装は仕様に従い、仕様にない振る舞いを実装してはならない（[ADR 0021](docs/decision/0021-lean-spec-as-normative-source.md)）。
2. Lean のトップレベル名前空間は次に統一する（[ADR 0035](docs/decision/0035-generate-verus-mirror-from-target-model.md)）。
   - `LangSemantics.<lang>` 言語意味論モデル（アプリ非依存。`Java`, `Sql`, `Rust`）
   - `SourceModel` 移植元モデル（移植元ソース Java/SQL の振る舞いを意味論ごと写す）
   - `Spec` 抽象モデル（言語中立・厳密整数の正規仕様）
   - `Abstraction` 抽象化証明課題（`SourceModel` が `Spec` をリファインする）
   - `TargetModel` 移植先モデル（移植先ソース Rust の振る舞いを `LangSemantics.Rust` で写す）
   - `Refinement` 具体化証明課題（`TargetModel` が `Spec` をリファインする。Lean で証明）
   - 例外: `Machine`（リファインメントの枠組み）、`Trace`、`Tests`、`Tools`

   移植元と抽象を分け、関係を B メソッドのリファインメントとして証明する方針は [ADR 0034](docs/decision/0034-b-method-refinement-and-explicit-deviations.md)。
3. 抽象モデルでは浮動小数点数を使わない（[ADR 0006](docs/decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
4. 移植元・移植先との差異は、必ず既知差異（[docs/spec/abstraction.md](docs/spec/abstraction.md) の `D-NNN`、[docs/spec/refinement.md](docs/spec/refinement.md) の `T-NNN`）として登録する。前提型・観測型の差異は、Lean のリファインメント定理の名前付きの仮定・成分（`@[deviation]`）と、差異の証拠の定理（W 課題）にも置く。意図の判断を伴う場合は、あわせて ADR を書く。ADR だけに記録してはならない。
5. 業務ロジックは純粋関数、副作用はポート経由（[ADR 0007](docs/decision/0007-functional-core-with-ports.md)）。
6. `docs/` の文書を追加・変更したら、frontmatter（OKF v0.2）・[docs/index.md](docs/index.md)・[docs/log.md](docs/log.md) を更新する（[documentation.md](docs/rules/documentation.md#okf-v02)）。
7. **一通りの作業が終わったら `git commit` する。`git push` は自分で作ったブランチに限り、そこから PR を作成してよい。既定ブランチと他人のブランチには push しない**（[version-control.md](docs/rules/version-control.md)）。

## 現在の状態

Lean の雛形（[backlog 0001](docs/backlog/0001-lean-project-scaffold.md)。名前空間の骨格、追跡属性、`trace-dump`、`axiom-check`、CI）、上流の submodule 化（[backlog 0025](docs/backlog/0025-upstream-submodule-and-inventory.md)）、リファインメントの枠組み `Machine`（[backlog 0027](docs/backlog/0027-machine-refinement-framework.md)。スキルの `assets/lean/Machine/`）、`Spec` の土台（[backlog 0003](docs/backlog/0003-abstract-domain-types-and-master-data.md)。基本演算・暦日・書式・文字クラス・ドメイン型・設定・マスタデータ。`conformance/shared/format/` のベクタ）、`LangSemantics.Java` の検査（[backlog 0002](docs/backlog/0002-lang-semantics-java.md)。double のネイティブとの突き合わせ、JVM の表）、`LangSemantics.Sql` の検査（[backlog 0016](docs/backlog/0016-lang-semantics-sql.md)。`ORDER BY` の一意性の証明、PostgreSQL 16.15 との突き合わせ）、リファインメントの空虚化を防ぐ義務と検査（[backlog 0030](docs/backlog/0030-refinement-non-vacuity.md)。`Machine.Adequacy`、`obligation-check`、[ADR 0039](docs/decision/0039-refinement-non-vacuity-obligations.md)）は完了。追跡の道具（[backlog 0024](docs/backlog/0024-trace-tooling.md)。インベントリ・`check`・`manifest`・`rehash`・`diff`・`impact`・CI、[ADR 0040](docs/decision/0040-trace-tooling-unresolved-details.md)・[ADR 0041](docs/decision/0041-rehash-diff-impact-details.md)）も完了。運賃計算（[backlog 0004](docs/backlog/0004-fare-calculation-both-models.md)）は第 1 段（`Spec.Fare`・`SourceModel.Fare`・両モデルのベクタ・最初の `@[source]`、[ADR 0042](docs/decision/0042-fare-source-model-and-shared-vectors.md)）まで済み、第 2 段（マスタの Mapper の SQL と PostgreSQL での差分実行、Provider の `load`・`CodeList`・`Config`、ABS-026）が残る。Rust のコードはまだ無い。
次に着手できるのは、Lean 側の [backlog 0004](docs/backlog/0004-fare-calculation-both-models.md) の第 2 段・[0031](docs/backlog/0031-spec-nondet-and-entry-env.md)（`Spec` の非決定性の型と入口の環境の前提）・[0021](docs/backlog/0021-lang-semantics-rust.md)（言語意味論）・[0017](docs/backlog/0017-okf-bundle-lint.md)（OKF の検査）、原典との照合の [0013](docs/backlog/0013-java-oracle-harness.md)、Rust の [0018](docs/backlog/0018-rust-project-scaffold.md)（Verus と Kani の併用確認を含む）。
Lean 側の検査は `tools/ci/lean.sh` で一括して実行する。
進捗は [docs/backlog/README.md](docs/backlog/README.md) を参照。
