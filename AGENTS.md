# AGENTS.md

このリポジトリは、TERASOLUNA のサンプルアプリケーション **ATRS（航空券予約システム）** の
Thymeleaf 版を、**Lean 4 で形式化したモデルと仕様** を介して **Rust** へ移植するプロジェクトである。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(Java/SQL)           (Lean)                       (Lean)            (Lean)                 (Rust)
```
最終目標は **他のあらゆる言語へ同一ロジックを移植できる、検証可能な仕様** を得ることにある。

**基本原則**（[ADR c336](docs/decision/c336-foundational-principles.md)。他のすべての ADR・規約・スキルに優先する）:

1. 移植元プログラムと移植元モデル、移植先プログラムと移植先モデルは、決定論的な検証または変換によって一致が確認されていなければならない。また、トレーサビリティが保たれていなければならない。
2. 抽象モデルと移植(元/先)モデルの間には、B メソッドでいうリファインメントの関係にあることが証明されていなければならない。
3. 抽象モデルと移植(元/先)モデルで一致しない点がある場合は、それを証明の中とドキュメントにおいてすべて明示されていなければならない。

手段の届かない部分（保証の限界）は [docs/spec/assurance.md](docs/spec/assurance.md) にすべて列挙する。

- 正規仕様は Lean の `Spec`。`Spec` で表現できない仕様だけを `docs/spec` で定義する（[ADR 61bc](docs/decision/61bc-lean-spec-as-normative-source.md)）。
- モデルと証明はすべて Lean に置く。移植先ソースは Rust。`TargetModel` から Verus の写しを生成し、Verus で Rust との一致を証明する。あわせて、追跡注釈・適合テスト・Kani で確認する（[ADR 0bd3](docs/decision/0bd3-generate-verus-mirror-from-target-model.md)）。
- `SourceModel`・`TargetModel` は、それぞれ `Spec` を B メソッドの意味でリファインする。差異は `D-NNN`・`T-NNN` として、定理の名前付きの仮定と文書の両方に置く（[ADR 01d4](docs/decision/01d4-b-method-refinement-and-explicit-deviations.md)）。リファインメントが空虚・自明に成り立たないよう、付帯の義務（選択の像としての `Spec`、環境の固定、標準の貼り合わせ、入口の全域性など）を課す（[ADR 70eb](docs/decision/70eb-refinement-non-vacuity-obligations.md)）。
- トレースは両端の 2 本だけ。**移植元ソースと移植先ソースは直接つながない**（[ADR e2a4](docs/decision/e2a4-traceability-hash-as-deterministic-check-record.md)）。
- 移植元の版上げに追従する。`SourceModel` は最新版のみ（[ADR 3f36](docs/decision/3f36-following-upstream-releases.md)、[spec-pivot/upgrade.md](.agents/skills/spec-pivot/references/docs/guide/upgrade.md)）。
- 移植の方法 **Spec Pivot** はアプリに依存しないスキル **spec-pivot** に、ATRS 固有の情報は `docs/` に置く（[ADR f4e1](docs/decision/f4e1-extract-porting-method-as-agent-skill.md)）。

- 上流ソース: <https://github.com/terasolunaorg/atrs> の `JavaConfig-Thymeleaf/`
  - branch `release/5.11.0.RELEASE` / commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`

## 作業前に必ず読むもの

**すべての作業（文書・コード・証明・テスト）の前に、次の 2 つを読むこと。**

1. **言語間移植の方法（Spec Pivot）**: スキル [`.agents/skills/spec-pivot/SKILL.md`](.agents/skills/spec-pivot/SKILL.md)（アプリに依存しない方法。Agent Skills 形式。[ADR f4e1](docs/decision/f4e1-extract-porting-method-as-agent-skill.md)）。言語ごとの情報は `references/docs/lang/<lang>/` にあり、ATRS では `java`・`sql`（移植元）、`rust`（移植先）、`lean`（形式化）を使う。
2. **ATRS の運用規約**: [`docs/rules/README.md`](docs/rules/README.md) と、そこから参照される規約。特に [atrs-porting.md](docs/rules/atrs-porting.md)（スキルを ATRS に適用するときの固有事項）。

優先順位は、ATRS の ADR → `docs/rules/` → スキル → 本ファイルの順とする（[docs/rules/README.md](docs/rules/README.md#優先順位)）。

| 規約 | 内容 |
| --- | --- |
| [docs/rules/atrs-porting.md](docs/rules/atrs-porting.md) | ATRS への適用: 言語ペア、配置、機能名、型、必須の依存、追従中の上流 |
| [docs/rules/documentation.md](docs/rules/documentation.md) | 文書全般（言語・用語・リンク・出典記法・OKF） |
| [docs/rules/decision-records.md](docs/rules/decision-records.md) | 意思決定記録（MADR, `<ID の先頭 4 文字>-<slug>.md`、ID は UUID） |
| [docs/rules/backlog.md](docs/rules/backlog.md) | バックログ運用と完了の定義 |
| [docs/rules/version-control.md](docs/rules/version-control.md) | git（作業の区切りで commit。push は自分で作ったブランチに限り、PR を作成してよい） |

## ディレクトリ地図

| パス | 役割 |
| --- | --- |
| [docs/index.md](docs/index.md) | **文書インデックス**。`docs/` は OKF v0.2 の Knowledge Bundle（[ADR a0f1](docs/decision/a0f1-documentation-format-okf-v0-2.md)） |
| [docs/log.md](docs/log.md) | 文書の変更履歴 |
| [docs/decision/](docs/decision/) | 意思決定記録（ADR, MADR 形式）。設計判断の唯一の記録場所 |
| [docs/spec/](docs/spec/) | Lean `Spec` で表現できない仕様（規範）、文書メタ情報、形式化前の草案 |
| [docs/backlog/](docs/backlog/) | 作業項目。着手順と依存関係 |
| [docs/rules/](docs/rules/) | ATRS の運用規約 |
| [.agents/skills/spec-pivot/](.agents/skills/spec-pivot/SKILL.md) | 言語間移植の方法（アプリ非依存のスキル）。文書は OKF v0.2 のバンドル [`references/docs/`](.agents/skills/spec-pivot/references/docs/index.md)。スキル自身の意思決定記録・作業項目は `references/docs/{decision,backlog}` に置く（[ADR 50f9](docs/decision/50f9-move-skill-records-to-skill-bundle.md)）。アプリに依存しない判断・作業はそこに記録する |
| `lakefile.lean`（ルート） | Lake ワークスペース。Lean の LSP がリポジトリのルートから `import` を解決するために、`lean/` とスキルの `assets/lean` を `require` する |
| `mise.toml`・`pyproject.toml`・`.python-version`・`uv.lock`（ルート） | 検査・生成のタスク（`mise run ci` が一括検査。一覧は `mise tasks`）と、mise が管理する道具（uv だけ）。Python の道具は `uv run python -I` で実行する（[ADR 44a0](docs/decision/44a0-mise-tasks-and-uv-for-tools.md)） |
| `lean/` | Lean プロジェクト（パッケージ `atrs`）。トップレベルの主定理は `lean/Abstraction.lean` の `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts`（`Machine.Refines`・`Machine.Preserves`・`Machine.Abstracts`。A abstracts B = A preserves B ∧ B refines A。`Spec.machine` と `SourceModel.machine` は実装済みの機能の並置）に、`lean/Refinement.lean` にも同じ形で置く（[ADR 91be](docs/decision/91be-top-level-preserves-refines-abstracts.md)）。`Spec`（正規仕様）/ `SourceModel` / `Abstraction`（`Abstraction.Gap` はギャップの登録簿）/ `TargetModel` / `Refinement` / `Tests` / `Tools`（道具の入口）。`LangSemantics`（`Core`・`Java`・`Sql`・`Rust`）・`Machine`・`Trace`（追跡属性・ギャップの登録簿の型・trace-dump・obligation-check の本体）・`ConformanceKit`（適合テストの実行器）はスキルの `assets/lean` を Lake 依存として取り込む。アプリに依存しない補題・道具は ATRS に置かず、スキルに足す（[backlog be49](docs/backlog/be49-lean-project-scaffold.md)、[ADR 7fe4](.agents/skills/spec-pivot/references/docs/decision/7fe4-move-trace-attributes-to-skill.md)） |
| `rust/`（予定） | 移植先ソース。業務機能、`model/`（`TargetModel` の Verus 写し）、`proof/`、`kani/`、`tests/`（[backlog fb50](docs/backlog/fb50-rust-project-scaffold.md)） |
| `upstream/atrs` | 移植元ソース（git submodule、commit 固定。[backlog 455f](docs/backlog/455f-upstream-submodule-and-inventory.md)） |
| `trace/` | スキルの道具が読む ATRS の設定（`project.json`）・版の宣言（`upstream.json`）・対象外一覧（`out-of-scope.json`）・機能と backlog の対応表（`features.json`）・インベントリ（`source-inventory.json`・`target-inventory.json`）・manifest（[ADR e2a4](docs/decision/e2a4-traceability-hash-as-deterministic-check-record.md)、[ADR 0eea](.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md)） |
| `.agents/skills/spec-pivot/scripts/` | スキルの道具（アプリ非依存。[ADR edc8](.agents/skills/spec-pivot/references/docs/decision/edc8-skill-scripts-and-generic-lean-libraries.md)）。`trace/`（追跡の CLI。`inventory`・`manifest`・`check`・`rehash`・`diff`・`impact`）、`ci/check_lean.py`（`sorry`・`axiom`・`Float`・依存の向きなど）、`ci/check_obligations.py`（`obligation-check` の結果と登録簿の突き合わせ。TR-G・TR-N）、`ci/check_upstream.py`（上流の commit と宣言の一致）、`docs/ids.py`（ADR・backlog の ID の道具）、`docs/okf_check.py`（OKF のバンドルとリンク・見出しアンカーの検査）。ATRS 固有の値は `trace/project.json` から読む |
| `tools/` | ATRS 固有の道具。`ci/master_sql.sh`、`ci/skippable.sh`、`conformance/`（共有入力と SQL の差分実行の生成器）、`docs/legacy-ids.json`（ADR・backlog の旧番号の対応表。[ADR f57e](docs/decision/f57e-uuid-ids-for-decisions-and-backlog.md)）、`docs/lean-renames.json`（Lean の名前の改名の対応表。[backlog 9ed8](docs/backlog/9ed8-atrs-module-namespace-layout.md)）・`docs/lean-renames-preserves.json`（[backlog cb23](docs/backlog/cb23-adequate-to-preserves-abstracts.md)） |
| `conformance/` | 言語中立な適合テストベクタ（[ADR dc3a](docs/decision/dc3a-conformance-test-vectors.md)）。`lake test` が `Spec`・`SourceModel` に対して実行する。共有入力 `fixtures/` は `tools/conformance/master_fixture.py` が上流のシードから生成する |

## 主要な規則（要約。詳細は各規約・ADR）

1. 正規仕様は Lean `Spec` と、`docs/spec` の規範節（`Spec` で表現できない仕様）である。実装は仕様に従い、仕様にない振る舞いを実装してはならない（[ADR 61bc](docs/decision/61bc-lean-spec-as-normative-source.md)）。
2. Lean のトップレベル名前空間は次に統一する（[ADR 0bd3](docs/decision/0bd3-generate-verus-mirror-from-target-model.md)）。
   - `LangSemantics.<lang>` 言語意味論モデル（アプリ非依存。`Java`, `Sql`, `Rust`）
   - `SourceModel` 移植元モデル（移植元ソース Java/SQL の振る舞いを意味論ごと写す）
   - `Spec` 抽象モデル（言語中立・厳密整数の正規仕様）
   - `Abstraction` 抽象化証明課題（`SourceModel` が `Spec` をリファインする）
   - `TargetModel` 移植先モデル（移植先ソース Rust の振る舞いを `LangSemantics.Rust` で写す）
   - `Refinement` 具体化証明課題（`TargetModel` が `Spec` をリファインする。Lean で証明）
   - 例外: `Machine`（リファインメントの枠組み）、`Trace`、`ConformanceKit`、`Tests`、`Tools`

   移植元と抽象を分け、関係を B メソッドのリファインメントとして証明する方針は [ADR 01d4](docs/decision/01d4-b-method-refinement-and-explicit-deviations.md)。

   宣言は、技術的な必要（型の名前空間へのドット記法の補題・`main` など 4 つの例外）がない限り、モジュール名の下に置く（`Spec/Fare.lean` は `Spec.Fare.*`）。`Abstraction`・`Refinement` では、R・W・C 課題と付帯の義務を機能のモジュール（`lean/Abstraction/Fare.lean`）に、補題・α・差異の述語を下位のモジュールに置く。`lake exe layout-check` と `trace check` の TR-L が検査する（[スキルの ADR 1a30](.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)）。
3. 抽象モデルでは浮動小数点数を使わない（[ADR e41d](docs/decision/e41d-exact-integer-arithmetic-in-abstract-model.md)）。
4. 移植元・移植先との差異は、必ず既知差異（`D-NNN`・`T-NNN`）として、Lean の登録簿（`lean/Abstraction/Gap.lean`・`lean/Refinement/Gap.lean` の `@[gap_entry]`）に登録する。[docs/spec/abstraction.md](docs/spec/abstraction.md)・[docs/spec/refinement.md](docs/spec/refinement.md) の表は `trace manifest` がそこから生成する（手で編集しない）。差異の生じる `Spec`・`SourceModel`・`TargetModel` の定義には `@[gap "D-NNN"]` を付ける（[ADR cc24](docs/decision/cc24-gap-registry-as-lean-attributes.md)）。前提型・観測型の差異は、Lean のリファインメント定理の名前付きの仮定・成分（`@[deviation]`）と、差異の証拠の定理（W 課題）にも置く。意図の判断を伴う場合は、あわせて ADR を書く。ADR だけに記録してはならない。
5. 業務ロジックは純粋関数、副作用はポート経由（[ADR f0e4](docs/decision/f0e4-functional-core-with-ports.md)）。
6. `docs/` の文書を追加・変更したら、frontmatter（OKF v0.2）・[docs/index.md](docs/index.md)・[docs/log.md](docs/log.md) を更新する（[documentation.md](docs/rules/documentation.md#okf-v02)）。形とリンクは `okf_check.py` が検査する（[documentation.md](docs/rules/documentation.md#検査)）。
7. **一通りの作業が終わったら `git commit` する。`git push` は自分で作ったブランチに限り、そこから PR を作成してよい。既定ブランチと他人のブランチには push しない**（[version-control.md](docs/rules/version-control.md)）。

## 現在の状態

Lean の雛形（[backlog be49](docs/backlog/be49-lean-project-scaffold.md)。名前空間の骨格、追跡属性、`trace-dump`、`axiom-check`、CI）、上流の submodule 化（[backlog 455f](docs/backlog/455f-upstream-submodule-and-inventory.md)）、リファインメントの枠組み `Machine`（[backlog 1ae4](.agents/skills/spec-pivot/references/docs/backlog/1ae4-machine-refinement-framework.md)。スキルの `assets/lean/Machine/`）、`Spec` の土台（[backlog 591d](docs/backlog/591d-abstract-domain-types-and-master-data.md)。基本演算・暦日・書式・文字クラス・ドメイン型・設定・マスタデータ。`conformance/shared/format/` のベクタ）、`LangSemantics.Java` の検査（[backlog a8be](docs/backlog/a8be-lang-semantics-java.md)。double のネイティブとの突き合わせ、JVM の表）、`LangSemantics.Sql` の検査（[backlog c7e8](docs/backlog/c7e8-lang-semantics-sql.md)。`ORDER BY` の一意性の証明、PostgreSQL 16.15 との突き合わせ）、リファインメントの空虚化を防ぐ義務と検査（[backlog f7b7](docs/backlog/f7b7-refinement-non-vacuity.md)。`Machine.Preserves`、`obligation-check`、[ADR 70eb](docs/decision/70eb-refinement-non-vacuity-obligations.md)）は完了。追跡の道具（[backlog ffdc](docs/backlog/ffdc-trace-tooling.md)。インベントリ・`check`・`manifest`・`rehash`・`diff`・`impact`・CI、[ADR 0eea](.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md)・[ADR 9cd9](.agents/skills/spec-pivot/references/docs/decision/9cd9-rehash-diff-impact-details.md)）も完了。運賃計算（[backlog 25f7](docs/backlog/25f7-fare-calculation-both-models.md)）と、その抽象化証明（[backlog bbcc](docs/backlog/bbcc-fare-abstraction-proofs.md)）も完了。最初の R 課題 ABS-026（マスタ・設定・コードリストの読み込み）を証明した。
- 第 1 段: `Spec.Fare`・`SourceModel.Fare`・両モデルのベクタ・最初の `@[source]`（[ADR 8f18](docs/decision/8f18-fare-source-model-and-shared-vectors.md)）
- 第 2 段 a: マスタ・設定・コードリストの読み込みの `SourceModel`、PostgreSQL での差分実行、D-027（[ADR c108](docs/decision/c108-master-data-source-model-and-spec-fixes.md)）
- 第 2 段 b-1: ABS-026 の補題、MD-8 の `NOP`、D-027 の範囲、`LocalDate` の通算日数の修正（[ADR f353](docs/decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）
- 第 2 段 b-2a: ABS-026 の標準の抽象化 α と核、`dev_D027`、[Spec] の修正（参照の答えの射影、空白の便名）
- 第 2 段 b-2b: ABS-026 の主定理 `queryRefines`・`InitSurj`・W 課題 ABS-127（`need_D027`）、意図から書く例

運賃計算の抽象化証明（[backlog bbcc](docs/backlog/bbcc-fare-abstraction-proofs.md)）は 3 段に分け、第 1 段で double の誤差を定理で確定した（D-001 は値域内に差異がある。D-001・D-002 の前提は「100 で割り切れないか、因子が安全」。[ADR e9bc](docs/decision/e9bc-fare-double-analysis.md)）。第 2 段で、基本運賃・運賃の R 課題 ABS-001・ABS-002 と、W 課題 ABS-101・ABS-102（D-001・D-002 の必要性）を証明した。第 3 段で、合計金額の R 課題 ABS-004 と W 課題 ABS-112（D-012 の必要性）を証明し、bbcc を完了した。
空虚化を防ぐ義務を既存の研究に照らして補い、名前付きの成分の必要性（G9）を加えた（[ADR 9ac6](docs/decision/9ac6-vacuity-literature-necessity-and-mutation.md)、[backlog ae04](docs/backlog/ae04-component-necessity-witness.md)）。成分の変異テストは [backlog 0d1a](docs/backlog/0d1a-mutation-testing-of-named-components.md) で扱う。追跡属性の仕組み（`Trace`）をスキルへ移し、[Spec] と `SourceModel` のギャップ（既知差異・PRE の外・未確定）を Lean の登録簿 `@[gap_entry]` と箇所の印 `@[gap]` で表すようにした（[ADR 7fe4](.agents/skills/spec-pivot/references/docs/decision/7fe4-move-trace-attributes-to-skill.md)・[ADR cc24](docs/decision/cc24-gap-registry-as-lean-attributes.md)、[backlog 114a](docs/backlog/114a-gap-attributes-and-trace-in-skill.md)）。続いて、アプリに依存しない道具（追跡の CLI・静的検査など）をスキルの `scripts/` へ、汎用の Lean コード（`Machine.Kernel`・`LangSemantics.Core`・`ConformanceKit` など）をスキルの assets へ移し、ATRS 固有の値を `trace/project.json` に集めた（[ADR edc8](.agents/skills/spec-pivot/references/docs/decision/edc8-skill-scripts-and-generic-lean-libraries.md)、[backlog 38fb](docs/backlog/38fb-move-generic-elements-to-skill.md)）。ギャップが証明できない理由を、公理・`sorry` を使わずに、登録簿の証明の状態（偽を証明済み・被覆・未証明・形式化していない・PRE の外）と、それを裏付ける宣言（否定の定理・`opaque` の主張など）の `@[gap]` で示すようにした（[ADR 6ab4](docs/decision/6ab4-gap-evidence-states-without-axioms.md)、[backlog c27d](docs/backlog/c27d-gap-evidence-states.md)）。スキルの文書を OKF v0.2 のバンドル `references/docs/` にし、純粋にスキルの ADR（edc8・7fe4・6edf・0b83・0eea・9cd9）と backlog（1ae4・a936）をそこへ移した（[ADR 50f9](docs/decision/50f9-move-skill-records-to-skill-bundle.md)）。
実装済みの範囲（マスタの読み込みと運賃計算）の R 課題を義務の束に束ね、`Abstraction.lean` のトップレベルに示した。追跡の検査の段階導入を側ごと（移植元・移植先）にし、運賃計算・マスタの移植元側を失敗扱いにした。以後の機能の取り込みは、トップレベルの主定理と移植元側の検査が通り続けることを条件とする（[backlog 76a6](docs/backlog/76a6-source-side-adequacy-gate.md)、[ADR a41d](docs/decision/a41d-top-level-refines-adequate-and-source-side-gate.md)、[スキルの ADR ab9e](.agents/skills/spec-pivot/references/docs/decision/ab9e-adequate-bundle-sum-and-side-staging.md)）。
Rust のコードはまだ無い。
空席照会（[backlog 0be7](docs/backlog/0be7-flight-search-usecase.md)）も完了した。状態 `World`（フライト）を持つ最初の機能で、R 課題 ABS-011 と束・W 課題 ABS-114・ABS-132 を証明し、トップレベルの主定理に 5 番目の成分として加えた（[ADR ce36](docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)・[ADR cdb6](docs/decision/cdb6-flight-search-stage2-machines-seed-sql.md)・[ADR 0b0c](docs/decision/0b0c-flight-search-stage3-abs011.md)）。
[Spec] の非決定性の選択の型（`Spec.Nondet`）と入口の環境の前提（`Spec.EnvPre`。シードが満たすことの定理 `seed_env`）を置いた（[backlog 0fdf](docs/backlog/0fdf-spec-nondet-and-entry-env.md)、[ADR cd33](docs/decision/cd33-spec-nondet-types-and-env-pre.md)）。
義務の束 `Machine.Adequate` の語を廃止し、B メソッドのリファインメント `Machine.Refines`（B refines A）と、空虚化を防ぐ意味的な義務のすべてを束ねた `Machine.Preserves`（A preserves B。`Refines` を含まない）、その組 `Machine.Abstracts`（A abstracts B）に分けた。トップレベルは `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts` である（[backlog cb23](docs/backlog/cb23-adequate-to-preserves-abstracts.md)、[ADR 91be](docs/decision/91be-top-level-preserves-refines-abstracts.md)、[スキルの ADR 6b4b](.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md)。改名の対応表は `tools/docs/lean-renames-preserves.json`）。
Lean の宣言をモジュール名の下に置き、証明課題を機能のモジュールに集めた（[backlog 9ed8](docs/backlog/9ed8-atrs-module-namespace-layout.md)、[スキルの ADR 1a30](.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)。`lake exe layout-check`・TR-L）。
文書の検査として、`docs/` とスキルのバンドルの OKF の形・索引・ADR と backlog の節・相対リンクと見出しアンカーを、スキルの `okf_check.py` で CI にかけるようにした（[backlog ddbd](docs/backlog/ddbd-okf-bundle-lint.md)、[ADR 920d](docs/decision/920d-docs-bundle-check-in-ci.md)）。
次に着手できるのは、予約の [aedf](docs/backlog/aedf-reservation-usecase.md)（空席照会に依存する。[f18c](docs/backlog/f18c-java-oracle-harness.md) にも依存する）、Lean 側の [a936](.agents/skills/spec-pivot/references/docs/backlog/a936-lang-semantics-rust.md)（言語意味論）、原典との照合の [f18c](docs/backlog/f18c-java-oracle-harness.md)、Rust の [fb50](docs/backlog/fb50-rust-project-scaffold.md)（Verus と Kani の併用確認を含む）。
Lean 側の検査は `mise run ci` で一括して実行する。段ごとのタスクはルートの `mise.toml`（一覧は `mise tasks`）。mise は uv だけを管理し、Python の道具は `uv run python -I` で実行する（[ADR 44a0](docs/decision/44a0-mise-tasks-and-uv-for-tools.md)）。
進捗は [docs/backlog/README.md](docs/backlog/README.md) を参照。
