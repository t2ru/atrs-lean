# Directory Update Log

## 2026-10-31

* **Creation**: [backlog 114a](backlog/114a-gap-attributes-and-trace-in-skill.md) を作り、完了した（`done`）。
* **Creation**: [ADR 7fe4](decision/7fe4-move-trace-attributes-to-skill.md) で、`lean/Trace`（追跡属性・trace-dump・obligation-check の本体）をスキル port-lang の `assets/lean/Trace` に移した。テストは `assets/lean/TraceTest` と `lake exe trace-test` に移した。
* **Creation**: [ADR cc24](decision/cc24-gap-registry-as-lean-attributes.md) で、ギャップの登録簿を Lean の `@[gap_entry]`（型 `Trace.Gap`）に置き、箇所の印 `@[gap]` を足した。`lean/Abstraction/Gap.lean` に D-001〜D-030 を移し、未確定の差異に D-028、PRE の外の ID の無かった 2 行に D-029・D-030 を割り当てた。検査 TR-K・GK を足した。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)・[spec/refinement.md](spec/refinement.md)（差異の表を生成区画にした）
  * [spec/assurance.md](spec/assurance.md)（検査器の置き場所、ギャップの登録簿の行）
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.5、`Trace` の置き場所）
  * [backlog/README.md](backlog/README.md)
  * スキル port-lang の SKILL.md（版 0.5）・`architecture.md`・`traceability.md`（TR-K）・`lean/trace-attributes.md`（ギャップの登録簿）・`spec-documents.md`・`lean/rules.md`・`workflow.md`
  * [AGENTS.md](../AGENTS.md)
* **Add**: [ADR e9bc](decision/e9bc-fare-double-analysis.md)（運賃計算の double の誤差を定理で確定し、D-001・D-002 の前提を正確な条件で書く）。
* **Update**: [backlog bbcc](backlog/bbcc-fare-abstraction-proofs.md) の第 1 段を終えた（`doing`）。3 段に分け、Java オラクルとの一致の完了条件を [backlog f18c](backlog/f18c-java-oracle-harness.md) に移し、`depends_on` から f18c を外した。double・BigDecimal の補題（スキルの `LangSemantics.Java.DoubleLemmas`・`bdCeilHundredUp_val`）と、基本運賃・運賃の差異の条件（`Abstraction.Fare`）を証明した。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（D-001・D-002 の内容と前提、ABS-006 の取り消し、ABS-007・ABS-101）
  * [spec/fare-calculation.md](spec/fare-calculation.md)（基本運賃・運賃の差異の条件）
  * [spec/assurance.md](spec/assurance.md)（前提が十分条件であること）
  * [backlog/README.md](backlog/README.md)、[AGENTS.md](../AGENTS.md)
  * スキル port-lang の [java/semantics.md](../.agents/skills/port-lang/references/java/semantics.md)（補題と、double の式の差の示し方）

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) を完了した（`done`）。R 課題 ABS-026（`Abstraction.MasterData.queryRefines`）と、W 課題 ABS-127（`need_D027`）を証明した。fare-calculation.md の例を、意図から書く例として `Tests.SpecChecks` に置いた。
* **Update**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) に、次の 2 点の決定を加えた。
  * `LocalDate` の写し `dateOfJ` を、通算日数で写す定義に改めた
  * obligation-check の G4 で、帰納型の補助の定数を許すようにした
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（ABS-026・ABS-127 の定理名）
  * [backlog/README.md](backlog/README.md)
  * [AGENTS.md](../AGENTS.md)

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 b-2a を終えた（`doing`）。ABS-026 の標準の抽象化 α（葉 19 個と核の定理、ABS-048）と `dev_D027`（D-027）を `Abstraction.MasterData` に置いた。
* **Update**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) に、次の 4 点の決定を加えた。
  * 参照の答えの射影（表示順を除く）
  * 空白の便名（`Query.Valid` に `hasText`）
  * α の葉と合成の分け方
  * 部分写像の汎用の核 `undefOrEq`（obligation-check の G7 を広げた）
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（α の表に 3 行、D-027 の成分の名前）
  * [spec/master-data.md](spec/master-data.md)（参照関数）
  * [spec/domain-model.md](spec/domain-model.md)（便名）
  * [spec/input-validation.md](spec/input-validation.md)（文字クラス `Blank`）
  * スキル port-lang の `architecture.md`（部分写像の汎用の核）
  * [AGENTS.md](../AGENTS.md)

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 b-1 を終えた（`doing`）。R 課題 ABS-026 の補題を、`Abstraction.Prim`・`Abstraction.MasterData` と、スキル port-lang の `LangSemantics` に置いた（暦、`HashMap`、一意な検索、整列、結合、キャッシュのキー、`load()`、コードリスト）。
* **Creation**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) で、次の 4 点を決めた。作成時は旧番号 0046 だったが、main の [ADR f57e](decision/f57e-uuid-ids-for-decisions-and-backlog.md) に合わせて UUID の ID を振った。
  * 空港コード `NOP` を MD-8 で禁じる
  * D-027 の対象を具体側の入力全体に広げる（[ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) を補う）
  * `LangSemantics.Java` の `LocalDate` の通算日数を床除算で書き直す（負の年で JVM と食い違っていた）
  * 補題の置き場所と、`decide +kernel` の使い方
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（D-027 の範囲、[Spec] の前提の外の `NOP`）
  * [spec/master-data.md](spec/master-data.md)（MD-8）
  * [spec/domain-model.md](spec/domain-model.md)（値域）
  * [spec/assurance.md](spec/assurance.md)（JVM の突き合わせ表の件数と `LocalDate` の範囲）
  * [ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) の More Information（補足の追記）
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR f57e](decision/f57e-uuid-ids-for-decisions-and-backlog.md) で、ADR と backlog の ID を 4 桁の連番から UUID v4 に改め、ファイル名を `<ID の先頭 4 文字>-<slug>.md` とした。
  * 既存の ADR 45 件と backlog 33 件を採番し直し、全文書・コード・JSON の参照を新 ID に書き換えた（旧番号との対応は ADR f57e と `tools/docs/legacy-ids.json`）。過去の記録の参照も書き換えた。採番の経緯を述べた箇所の番号は「旧番号」と明記した。
  * 道具が読む箇所（`id`・`depends_on`・`superseded_by`、`trace/features.json`、登録簿の backlog の列）は ID 全体、本文の参照は先頭 4 文字とした。
  * `tools/docs/ids.py`（`new`・`check`・`migrate`）を作り、`check` を `tools/ci/lean.sh` に加えた。`tools/trace` と `tools/ci/check_obligations.py` は、backlog を frontmatter の `id` で引くようにした。
* **Update**: [rules/decision-records.md](rules/decision-records.md)・[rules/backlog.md](rules/backlog.md)・[rules/documentation.md](rules/documentation.md)・[AGENTS.md](../AGENTS.md) の命名と参照の規則を改めた。[ADR d845](decision/d845-record-architecture-decisions-with-madr.md) に補足を加えた。
* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 a を終えた（`doing`）。
  * マスタ・設定・コードリストの読み込みの `SourceModel` を作った（Mapper の文、MyBatis の対応、Provider、コードリスト、設定、具体機械 `queryConcrete`）。
  * Mapper の SQL を PostgreSQL で差分実行して照合した（`conformance/sql/master-data.json`）。
  * マスタのベクタを両モデルで実行した。
  * `@[source]` 45 件を rehash で記録した。
* **Creation**: [ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) で、次の 5 点を決めた。
  * 読み込みの `SourceModel` の写し方。列の型は、処理系の範囲で写す。
  * `Spec.Route.flightTime` の削除
  * MD-8 の空港コード
  * 問い合わせの機械の拡張
  * 差分実行
* **Update**: [spec/abstraction.md](spec/abstraction.md) に、既知差異 D-027（前提型・具体側の入力）、影響（中断）、W 課題 ABS-127 を登録した。ABS-026 の行も改めた。
* **Update**: 次の文書を改めた。
  * [spec/master-data.md](spec/master-data.md)
  * [spec/domain-model.md](spec/domain-model.md)（値域）
  * [spec/assurance.md](spec/assurance.md)（SQL の差分実行の付録）
  * [spec/conformance.md](spec/conformance.md)（`master.*`）
  * スキル port-lang の `sql/semantics.md`・`java/semantics.md`
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) で、空虚化を防ぐ義務（ADR 70eb）を既存の研究と対応づけた。作成時は旧番号 0042 だったが、main に [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md) が先に入ったため旧番号 0043 に採番し直した。対応づけた研究は、Event-B の証明義務・vacuity detection・IronSpec・mCoq・Dafny の proof dependencies・CompCert である。
  * 採用 A: 成分の必要性（成分を外すと R 課題の命題が偽になること。検査 G9）
  * 採用 B: 仕様の変異テスト（[backlog 0d1a](backlog/0d1a-mutation-testing-of-named-components.md)）
  * 採用 C: 意図から書く例（Spec-Testing Proofs）
* **Creation**: [backlog ae04](backlog/ae04-component-necessity-witness.md) を作った。スキル port-lang の `Machine.Adequacy` に必要性の補題を、`MachineTest/Adequacy.lean` に反例 12・13 と正例を加えた。`obligation-check` に G9 を加えた。
* **Creation**: [backlog 0d1a](backlog/0d1a-mutation-testing-of-named-components.md) を作った（`todo`）。
* **Update**: 「強すぎる前提になっていないか」を主眼に敵対的レビューを行い、G9 を改めた（差異 ID ごとの集計、被覆 `Covers`、観測型の和 `anyOf`、ID は定数に 1 つ、`¬ Refines`・`→ False` の受理、PRE が全域な基底の `TotalUnder A always`、R 課題の基底に限った環境の前提）。指摘と対応は [ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) に記した。backlog ae04 を完了した。
* **Update**: ADR 9ac6 を次の文書に反映した。
  * [spec/abstraction.md](spec/abstraction.md)・[spec/refinement.md](spec/refinement.md)（W 課題・SPEC-006・空虚化を防ぐ義務）
  * [spec/assurance.md](spec/assurance.md)（W 課題を人が読む限界を削り、必要性の範囲の限界を加えた）
  * [ADR 70eb](decision/70eb-refinement-non-vacuity-obligations.md) の More Information（補足の追記）
  * [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の完了条件
  * スキル port-lang の SKILL・architecture・traceability・verification・conformance・spec-documents・lean/rules
  * [AGENTS.md](../AGENTS.md)
* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 1 段を終えた（`doing`）。
  * Lean `Spec.Fare` と `SourceModel.Fare`（`SourceModel.Model`・`SourceModel.MasterData`）を作った。
  * 運賃計算の全例をベクタにし、両モデルで実行するようにした（`conformance/{spec,source-model,shared}/fare/`）。
  * 共有入力 `conformance/fixtures/master-data.json`・`config.json` を、上流のシードから生成するようにした。生成器は `tools/conformance/master_fixture.py`。
  * `@[source]` 9 件を `tools/trace rehash` で記録した。
* **Creation**: [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md) で、次のことを決めた。
  * マスタの表し方（Provider のキャッシュ）
  * 列挙型
  * `HashMap`
  * 共有ベクタの `modelDef` の配列
  * 共有入力の生成
  * `source-model/` の暫定の期待値
  * 翌日着の便の暫定の扱い
* **Update**: 次の文書に、ADR 8f18 による変更を反映した。
  * [spec/fare-calculation.md](spec/fare-calculation.md): 要約（informative）に改め、Lean へのリンクを付けた
  * [spec/conformance.md](spec/conformance.md)
  * [spec/assurance.md](spec/assurance.md)
  * [spec/master-data.md](spec/master-data.md): 到着時刻 `2415` の TODO
  * [backlog 0be7](backlog/0be7-flight-search-usecase.md): 翌日着の便
  * [ADR dc3a](decision/dc3a-conformance-test-vectors.md)
  * スキル port-lang の conformance・lean/trace-attributes
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR 0b83](decision/0b83-porting-conditions-and-workflow.md) で、スキル port-lang に移植が成り立つ条件を明示し、進め方の既定を補うことを決めた。
  * スキルの [SKILL.md](../.agents/skills/port-lang/SKILL.md) に「移植が成り立つ条件」（適用の前提・成立の条件・言えること・言えないこと）を加え、版を 0.4 にした。
  * 進め方の既定として [workflow.md](../.agents/skills/port-lang/references/workflow.md) を新設した（評価・判断を記録する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録）。プロジェクトは置き換えてよい。
  * スキルの process.md・verification.md から workflow.md を参照した。
  * 独立したエージェントによる敵対的レビュー（2 観点、2 巡）を行い、指摘と対応を ADR 0b83 に記した。作成時は旧番号 0042 だったが、main に [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md)・[ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) が先に入ったため、旧番号 0044 に採番し直した。
  * main の ADR 9ac6（成分の必要性・仕様の変異テスト・意図から書く例）に合わせて、成立の条件 S2 と workflow.md の判断を記録する事項・検査ゲートを整えた。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に「進め方の適用（ATRS）」を加えた。
* **Update**: [backlog ffdc](backlog/ffdc-trace-tooling.md) を完了した（第 2 段）。
  * 追跡の道具 `tools/trace` に、`rehash`・`diff`・`impact` を加えた。
  * `rehash` は、検査の登録 `trace/checks.json` を使う。
  * `check` の TR-R に、`trace/renames.json` と「出典:」のロケータの参照切れを加えた。
  * `trace-dump` が定義の `module` を出力するようにした。
  * JVM・PostgreSQL との突き合わせを `tools/ci/jvm_table.sh`・`pg_table.sh` に切り出した。
* **Creation**: [ADR 9cd9](decision/9cd9-rehash-diff-impact-details.md) で、次の細部を決めた。ADR 0eea を補う。
  * 検査の登録
  * `rehash` の対象と手順
  * 注釈の書き換え方
  * 改名の扱い
  * `diff` の分類と `impact` の伝播
  * 「出典:」の検査
* **Update**: [spec/fare-calculation.md](spec/fare-calculation.md)・[spec/flight-search.md](spec/flight-search.md)・[spec/reservation.md](spec/reservation.md) の「出典:」をロケータ表記に書き換えた。
* **Update**: [spec/traceability.md](spec/traceability.md) を改めた。
  * 初期の予定対応の表を削除し、`trace/features.json` を参照するようにした。
  * 運賃の例から、private の `getMultiplicationRatio` を外した。
  * `checks.json`・`renames.json` と、`rehash`・`diff`・`impact` の使い方を加えた。
* **Update**: 次の文書に、ADR 9cd9 による追加を反映した。
  * [rules/documentation.md](rules/documentation.md)（出典の記法）
  * [rules/atrs-porting.md](rules/atrs-porting.md)
  * [ADR e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md) の道具の節
  * スキル port-lang の traceability・upgrade・lean/trace-attributes
  * [AGENTS.md](../AGENTS.md)

## 2026-10-30

* **Update**: [backlog ffdc](backlog/ffdc-trace-tooling.md) の第 1 段を終えた（`doing`）。追跡の道具 `tools/trace`（Rust）で、インベントリ・`check`・`manifest` を作った。最初の `trace/source-inventory.json`（1963 件）を生成し、[spec/traceability.md](spec/traceability.md) の生成区画を埋め、CI に加えた。機能と backlog の対応表 `trace/features.json` を置いた。
* **Creation**: [ADR 0eea](decision/0eea-trace-tooling-unresolved-details.md) で、追跡の道具の未確定事項を決めた。決めたのは、本文ハッシュ・正規化・ロケータの細部・版の文字列・機能と backlog の対応である。あわせて ADR e2a4 の `seed:` の単位をテーブルに改めた。
* **Update**: [backlog c7e8](backlog/c7e8-lang-semantics-sql.md) を完了した。`LangSemantics.Sql` に `ORDER BY` の許される順列の一意性の証明を加えた。PostgreSQL 16.15 で生成した突き合わせ表（373 件）を CI に加えた（この表で `VARCHAR(n)` の空白の切詰めの不一致を見つけて直した）。版を `trace/upstream.json` と [rules/atrs-porting.md](rules/atrs-porting.md) に、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Creation**: [ADR 70eb](decision/70eb-refinement-non-vacuity-obligations.md) で、リファインメントが空虚・自明に成り立つことを防ぐ付帯の義務と検査を定めた（作成時は旧番号 0038 だったが、main に [ADR 6edf](decision/6edf-lean-package-under-skill-assets-lean.md) が先に入ったため旧番号 0039 に採番し直した）。
  * 義務: 選択の像としての `Spec`（`Machine.ofChoice`・`FreeFrame`）、`Sound` と 1 点の初期状態（`InitIs`）、環境の固定（`Refines.Pinned`・`NoFaultReachable`）、標準の貼り合わせ（`Glue.ofStd`。部分写像）、入口の全域性（`TotalUnder`・`EnvWitness`）、`InitSurj`、`StateSafe`、両向きの W 課題（`Nontrivial`）、核の明示（`KernelIs`）
  * 検査: TR-G・TR-N を実装し、TR-V・TR-PE を定めた（ADR 01d4・e2a4・e56e の決定は変えない）
  * 設計段階と実装後に、独立したエージェントによる敵対的レビューを行い、指摘と対応を ADR 70eb に記した
* **Creation**: [backlog f7b7](backlog/f7b7-refinement-non-vacuity.md) を作り、完了した。スキル port-lang の `assets/lean/Machine/Adequacy.lean` と反例 `assets/lean/MachineTest/Adequacy.lean`（11 件）、`lean/Trace/Obligation.lean`（`lake exe obligation-check`）、`tools/ci/check_obligations.py` を作り、`tools/ci/lean.sh` に組み込んだ。追跡属性 `@[nondet]`・`@[std_abs]`・`@[kernel]`・`@[env_pre]` を加えた。
* **Update**: [spec/abstraction.md](spec/abstraction.md) を改めた。
  * 空虚化を防ぐ義務の節を加えた。
  * α の表に、核の列と、環境・HTTP の応答の行を加えた。
  * 前提型の差異の影響（出力のみ／中断）、入口の R 課題、SPEC-005〜008、ABS-048、Spec の非決定性 N-001〜N-005 を加えた（各登録簿に backlog の列）。
* **Update**: [spec/refinement.md](spec/refinement.md) に、同じ項目と REF-011・REF-012 を加えた。
* **Update**: [spec/assurance.md](spec/assurance.md) に、モデル間の保証の限界と、環境・マスタを入力とする写しの限界を加えた。[spec/domain-model.md](spec/domain-model.md) には、入口の値域を環境の前提とすることを加えた。
* **Update**: ADR [01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md)・[e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md)・[e56e](decision/e56e-conflict-as-spec-nondeterminism.md) の More Information に、ADR 70eb による追加を記した。
* **Update**: backlog [a8ef](backlog/a8ef-conformance-vector-format-and-generator.md)・[ffdc](backlog/ffdc-trace-tooling.md) と [rules/backlog.md](rules/backlog.md) の完了の定義を改めた。main で完了した [backlog 591d](backlog/591d-abstract-domain-types-and-master-data.md) に足すはずだった作業（非決定性の選択の型・入口の環境の前提）は、[backlog 0fdf](backlog/0fdf-spec-nondet-and-entry-env.md) として新設した。
* **Update**: スキル port-lang を 0.3 に改めた（architecture・traceability・conformance・verification・spec-documents・lean/trace-attributes・SKILL.md）。

* **Update**: [ADR 6edf](decision/6edf-lean-package-under-skill-assets-lean.md) で、スキル port-lang の Lake パッケージ `langSemantics` を `assets/` 直下から `assets/lean/` に移した。ルートと `lean/` の `require`・manifest、CI（`tools/ci/lean.sh`・`check_lean.py`・`.github/workflows/lean.yml`）、スキルの文書、[rules/atrs-porting.md](rules/atrs-porting.md)、[AGENTS.md](../AGENTS.md)、関係する backlog と ADR のパスを改めた。
* **Update**: [backlog a8be](backlog/a8be-lang-semantics-java.md) を完了した。`LangSemantics.Java` に、`jdLit "0.01"` のビット表現と 1430 円・30% の例の定理、`minusDays` を足した。JVM で生成した突き合わせ表（581 件）と、運賃計算の double 式のネイティブ `Float` との突き合わせ（4,006,212 件）を CI に加え、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Update**: [rules/version-control.md](rules/version-control.md) の push の禁止を改め、自分で作ったブランチへの push と、そこからの PR の作成を認めた（既定ブランチと他人のブランチへの push は引き続き禁止、マージはオーナーが行う）。あわせて [AGENTS.md](../AGENTS.md)・[rules/README.md](rules/README.md)・[rules/backlog.md](rules/backlog.md) の要約を改めた。
* **Update**: [backlog 591d](backlog/591d-abstract-domain-types-and-master-data.md) を完了した。`lean/Spec/` に、基本演算・暦日・時刻・書式・文字クラス（`Spec.Prim`）、列挙・コード値・エンティティ・値域（`Spec.Model`）、設定（`Spec.Config`）、マスタデータと MD-1〜MD-8・参照関数（`Spec.MasterData`）、コードリスト（`Spec.CodeList`）を実装し、SPEC-001〜003 を証明した。`conformance/shared/format/` にベクタを作り、`lake test` で `Spec` に対して実行するようにした。あわせて [spec/domain-model.md](spec/domain-model.md)・[spec/master-data.md](spec/master-data.md)・[spec/configuration.md](spec/configuration.md) の形式化した節を要約（informative）に改め、[spec/conformance.md](spec/conformance.md) の操作名を足した。
* **Update**: [backlog 1ae4](backlog/1ae4-machine-refinement-framework.md) を完了した。スキル port-lang の `assets/Machine/` に、抽象機械・具体機械・貼り合わせ・`Machine.Refines`（INIT・入力の全域性・適用可能性・正しさ）・差異による制限・推移性を実装し、`assets/MachineTest/` で例と反例を証明した。CI（`tools/ci/lean.sh`）で `assets/` をビルドし、`axiom-check`・`trace-dump` の対象に `Machine` を加えた。あわせて [ADR 01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md)（制限の関数の名前）と [spec/refinement.md](spec/refinement.md)（証明義務を 4 つに揃えた）を直した。
* **Update**: [backlog be49](backlog/be49-lean-project-scaffold.md) を完了した。`lean/`（Lake パッケージ `atrs`、Lean v4.35.0、Batteries v4.35.0）に全名前空間の骨格・追跡属性（`Trace.Attr`）・`trace-dump`・`axiom-check`・テストを置き、CI（`tools/ci/lean.sh`、`.github/workflows/lean.yml`）を整えた。あわせて [ADR 659f](decision/659f-lean-toolchain-and-dependencies.md)（採った版）、[rules/atrs-porting.md](rules/atrs-porting.md)（配置）、[rules/version-control.md](rules/version-control.md)（コミット前の確認）を改めた。
* **Update**: [backlog 455f](backlog/455f-upstream-submodule-and-inventory.md) を完了した。上流 ATRS を `upstream/atrs` に submodule として commit 固定で取り込み、`trace/upstream.json`（版の宣言）と `trace/out-of-scope.json`（追跡の対象外）を作った。あわせて [rules/atrs-porting.md](rules/atrs-porting.md)（版の正、Windows の `core.longpaths`、TODO(spec) の解消）と [spec/traceability.md](spec/traceability.md#対象外) を改めた。
* **Creation**: [ADR c336](decision/c336-foundational-principles.md) で、基本原則 3 項を、全 ADR・規約・スキルに優先する原則として定めた。3 項は次のとおり。
  * 両端の一致を決定論的な検証または変換で確認する。
  * 抽象モデルと移植元/先モデルの間に B メソッドのリファインメントを証明する。
  * 差異を証明と文書の両方ですべて明示する。
* **Creation**: 原則と矛盾する既存の決定を置き換える ADR を作った。
  * [01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md): B メソッドのリファインメントと、名前付きの差異（前提型・観測型・モデル外、D/T 登録簿、R/W/C/L 課題）
  * [0bd3](decision/0bd3-generate-verus-mirror-from-target-model.md): Verus の写しを TargetModel から生成し、`Machine` を名前空間の例外に加える
  * [e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md): 検査済みハッシュ、TR-D、`tmpl:`、TR 検査の例外の廃止
  * [e56e](decision/e56e-conflict-as-spec-nondeterminism.md): `Conflict` を Spec の非決定的な結果とする
* **Deprecation**: ADR [a43d](decision/a43d-two-layer-model-java-faithful-and-abstract.md)・[796c](decision/796c-models-in-lean-and-sources-traced-at-both-ends.md)・[81ab](decision/81ab-cross-language-traceability.md)・[41f7](decision/41f7-concurrency-failure-as-conflict-error.md) を superseded にした。
* **Update**: ADR 935b・97f9（FOR UPDATE の記述の訂正）・5fcb（`Postgresql` の表記、SQL の差分実行）・3f36・e24e・e10f に補足を加えた。置換済み ADR へのリンクを、後継の ADR へ張り替えた。
* **Creation**: [spec/assurance.md](spec/assurance.md)（保証の限界）を作った。
* **Update**: [spec/abstraction.md](spec/abstraction.md) を改めた。
  * リファインメントの形と、既知差異の種類・R/W 課題を加えた。
  * D-022〜D-025 を登録した。
  * D-003/004/005/010/015 を、前提の外の参考表に移した。
  * ABS-040 を ABS-041〜046 に分割し、W 課題 ABS-1NN を加えた。
* **Update**: [spec/refinement.md](spec/refinement.md) を改めた（T-NNN 登録簿、REF-007/008、SRC を決定論的な手段に改めた。設計レビューは廃した）。
* **Update**: 次の仕様文書を、原則に合わせて改めた。
  * [ports.md](spec/ports.md): `Conflict`、パスワードの契約、分離レベル、キューの上限
  * [domain-model.md](spec/domain-model.md): 値域を PRE とする
  * [master-data.md](spec/master-data.md)、[fare-calculation.md](spec/fare-calculation.md)、[http-contract.md](spec/http-contract.md)、[authentication.md](spec/authentication.md)、[member.md](spec/member.md)、[errors-and-messages.md](spec/errors-and-messages.md)、[traceability.md](spec/traceability.md)、[spec/README.md](spec/README.md)
* **Update**: スキル port-lang（0.2）を改めた。
  * SKILL.md: 3 原則を最上位に置いた。
  * architecture.md: B メソッドのリファインメント。
  * verification.md: 決定論的な手段、保証の限界、`native_decide` の禁止。
  * traceability.md: 検査済みハッシュ、TR-D。
  * process.md、spec-documents.md、upgrade.md、adding-a-language.md、言語パックの `verification.md`・`layout.md`・`locators.md`（`tmpl:`）・`semantics.md`、lean/rules.md、lean/trace-attributes.md も改めた。
* **Update**: [AGENTS.md](../AGENTS.md)、[rules/README.md](rules/README.md)（優先順位の軸を明確にした）、[rules/backlog.md](rules/backlog.md)（完了の定義）、[rules/atrs-porting.md](rules/atrs-porting.md) を改めた。
* **Creation**: backlog [1ae4](backlog/1ae4-machine-refinement-framework.md)（`Machine`）と [d77c](backlog/d77c-verus-mirror-generator.md)（写しの生成器）を作った。backlog a8be・bbcc・0be7・aedf・4e0e・44f8・ac71・4b0e・f18c・a89e・c7e8・ddb4・9c1b・a936・eff6・26c5・ffdc の範囲・完了条件を、R/W 課題と決定論的な手段に合わせて改めた。
* **Update**: 敵対的レビューの 2 回目の指摘を解消した。
  * [spec/abstraction.md](spec/abstraction.md): 複合的な R 課題に、差異の仮定を引き継いだ。D-009・D-014 を前提の外に、D-013 をモデル外に改めた。D-001・D-020 の前提を定めた。ABS-007・ABS-023〜025・ABS-047 と SPEC-001〜004 を加え、ABS-109/113/114 を廃止した。
  * [spec/refinement.md](spec/refinement.md): REF-009・SRC-010 を加え、Verus の禁止構文を広げた。
  * [spec/assurance.md](spec/assurance.md): `#[verifier::external]` の一覧、規範節ごとの行、活性の限界、追跡の道具、付録を加えた。
  * ADR c336・01d4・0bd3・e2a4・e56e: モデル外の差異の位置づけ、前提の 2 つの形、`bv_decide` の禁止、`model_prelude.rs`、TR-T1 の生成物の扱い、`xml:`・`seed:`、改名の検査、実行環境の失敗と活性の限界を加えた。
  * ADR 659f・578b・e10f に補足（訂正）を加えた。ADR e10f では、差分オラクルで入力を除外しないことにした。
  * スキル: 原典の事後条件を仮定にする抜け道、方言の差を無名の前提にする記述をなくした。
* **Creation**: backlog [9c04](backlog/9c04-rust-external-adapters.md)（DB・ファイル・時計のアダプタ）を作った。backlog の依存（f18c への依存、ac71 → 4e0e）と担当（REF-008、SRC-005/007/008）を整え、ffdc と 455f の循環を解いた。
* **Update**: 敵対的レビューの 3 回目の指摘を解消した。
  * リファインメントの義務に「入力の全域性」を加えた。
  * ポートの契約を主定理の仮定から外し、ポート実装の R 課題（ABS-021・023〜026、REF-008〜010）で証明することにした。
  * マスタ・設定を不変の入力とし、MD-1〜MD-8 を PRE に移した。
  * D-009・D-014 を前提型（具体側）に戻し、W 課題 ABS-109・ABS-114 を戻した。
  * D-026（JSON の不対サロゲート）・ABS-126 を加えた。
  * TR-S2・TR-T2 で、モデル側の変更でも再検査を求めることにした。
  * `pre_*` と `gen-verus --check-contracts` で、Verus の `requires`・`ensures` を検査することにした。
  * `model_prelude.rs` をスキルの assets に移した。`LangSemantics.Sql` は両側から使えることにした。
  * I/O 失敗の対象とコードを限定し、ports.md の規範節を絞った。
  * backlog の依存（bbcc・ffdc・aedf への依存）と担当を整えた。

## 2026-10-29

* **Creation**: 未決だった仕様を確定する ADR 7 件を作成した。[ac33](decision/ac33-email-validation-rule.md)（Email 規則）、[e24e](decision/e24e-validation-error-ordering.md)（検証エラーの並び）、[9ee4](decision/9ee4-clock-timezone-and-fixture-base-date.md)（Clock の Asia/Tokyo と fixture の投入日 2026-11-01）、[41f7](decision/41f7-concurrency-failure-as-conflict-error.md)（`Conflict` 分類）、[578b](decision/578b-member-update-in-single-transaction.md)（会員情報変更の 1 トランザクション化）、[90f5](decision/90f5-report-queue-at-least-once-delivery.md)（レポートキューの配信保証）、[e10f](decision/e10f-spec-corrects-unsafe-source-behavior.md)（原典の安全でない振る舞いを Spec で正す）。ADR a4fa・6eb2・97f9・ff4d の More Information に後続へのリンクを足した。
* **Update**: 上流 `f4bfbf06` と依存ライブラリ（Spring Framework 7.0.3、Spring Security 7.0.x、Hibernate Validator 9.1.0.Final、ActiveMQ Artemis）のソースを読んで、仕様の未決事項と文書間の矛盾を解消した。[spec/input-validation.md](spec/input-validation.md)（Email、エラーの並び、日付の解析、項目名の対応、REST の搭乗者数）、[spec/http-contract.md](spec/http-contract.md)（セッションの規範節、ログインの遷移先、日付の JSON、ApiError のコード、Basic 認証の失敗）、[spec/errors-and-messages.md](spec/errors-and-messages.md)、[spec/ports.md](spec/ports.md)（規範節の範囲、Clock、採番、キュー、トランザクション）、[spec/abstraction.md](spec/abstraction.md)（既知差異 D-011〜D-021、課題 ABS-032〜034）など。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に上流の依存の版を記録した。backlog [4e0e](backlog/4e0e-member-usecases-and-input-validation.md)・[f18c](backlog/f18c-java-oracle-harness.md) の範囲を改めた。

* **Update**: リポジトリのルートを Lake ワークスペースにした（`lakefile.lean` が `.agents/skills/port-lang/assets` を `require`）。ルートで起動した Lean LSP から `LangSemantics` の import が解決されないのを直した。手順は [atrs-porting.md](rules/atrs-porting.md) とスキルの [lean/rules.md](../.agents/skills/port-lang/references/lean/rules.md)。

* **Creation**: スキル port-lang に `assets/LangSemantics/<Lang>/`（Java・Sql・Sql.Postgresql・Rust の Lean モデル。core のみ、`#guard` 検査付き）を追加した。backlog [a8be](backlog/a8be-lang-semantics-java.md)・[c7e8](backlog/c7e8-lang-semantics-sql.md)・[a936](backlog/a936-lang-semantics-rust.md) はこれを起点とする。

* **Creation**: [ADR f4e1](decision/f4e1-extract-porting-method-as-agent-skill.md)。言語間移植の方法を、アプリ非依存のスキル `.agents/skills/port-lang`（Agent Skills 形式）に切り出した。言語パック（java・sql・rust）は、移植元・移植先のどちらにもなれる 6 ファイル構成とした。
* **Deprecation**: `docs/rules/` から porting・spec-writing・portability・testing・upstream-upgrade・lean・rust をスキルへ移した（git mv）。
* **Creation**: [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの ATRS への適用）を追加した。
* **Update**: [spec/conformance.md](spec/conformance.md)・[spec/traceability.md](spec/traceability.md)・[spec/refinement.md](spec/refinement.md) を ATRS 固有の内容に絞った。ADR・backlog・spec の、移動した規約へのリンクを張り替えた。

* **Creation**: [ADR 796c](decision/796c-models-in-lean-and-sources-traced-at-both-ends.md)（モデルと証明をすべて Lean に置き、`TargetModel` を Lean のモデル、Rust を移植先ソースとする）、[ADR 81ab](decision/81ab-cross-language-traceability.md)（両端の追跡: ロケータ・モデル側注釈・確認済みハッシュ・TR 検査）、[ADR 3f36](decision/3f36-following-upstream-releases.md)（上流の版上げ追従・差分オラクル）を作成した。
* **Deprecation**: [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md) と [ADR dd0f](decision/dd0f-rust-as-target-language.md) を ADR 796c で置き換えた。
* **Creation**: 規約 [port-lang/upgrade.md](../.agents/skills/port-lang/references/upgrade.md)（版上げ手順、draft）を追加した。
* **Update**: [port-lang/lean/rules.md](../.agents/skills/port-lang/references/lean/rules.md)・[port-lang/rust/layout.md](../.agents/skills/port-lang/references/rust/layout.md)・porting・testing・version-control・spec-writing・documentation を新構成と追跡注釈に合わせて改訂した。
* **Update**: [spec/traceability.md](spec/traceability.md) をロケータ文法・注釈・検査・運賃の追跡例を含む形に書き直した。[spec/refinement.md](spec/refinement.md) を REF（Lean で証明）と SRC（TargetModel ⇔ Rust の確認）に分けた。[spec/conformance.md](spec/conformance.md) に `target-model/`・`modelDef`・`upstream` を追加した。
* **Update**: バックログ be49・aedf・4b0e・a89e・fb50・ddb4・9c1b を改訂し、a936・eff6・26c5・ffdc・455f・773f を追加した。

* **Creation**: [ADR dd0f](decision/dd0f-rust-as-target-language.md)（移植先を Rust とし、Refinement を Verus・Kani・適合テストで充足）と [ADR 61bc](decision/61bc-lean-spec-as-normative-source.md)（Lean `Spec` を正規とし、`Spec` で表現できない仕様だけを docs/spec で定義）を作成した。
* **Deprecation**: [ADR 3b0a](decision/3b0a-spec-as-normative-source.md) を ADR 61bc で置き換えた。
* **Update**: [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md) の配置の記述を ADR dd0f に合わせた（Lean は `TargetModel`・`Refinement` を持たない）。ADR 84bf・97f9・dc3a・659f の関連箇所を更新した。
* **Creation**: 規約 [port-lang/rust/layout.md](../.agents/skills/port-lang/references/rust/layout.md)（draft）と [rules/version-control.md](rules/version-control.md)（作業の区切りで commit、push しない）を追加した。
* **Update**: docs/spec の全文書に区分 `spec_role`（normative / meta / draft）を付け、[spec/refinement.md](spec/refinement.md) を Rust 向けに書き直した。
* **Update**: バックログ be49・4b0e・a8ef・a89e を Rust 方針に合わせて改訂し、31da を取りやめ、fb50・ddb4・9c1b を追加した。

* **Creation**: OKF v0.2 バンドルとして [docs/index.md](index.md) と本ログを作成した（[ADR a0f1](decision/a0f1-documentation-format-okf-v0-2.md)）。
* **Creation**: 作業規約 [rules/](rules/README.md) 9 件を作成した。
* **Creation**: ADR d845・84bf・3b0a・a43d・935b・e41d・f0e4・a4fa・6eb2・10a5・97f9・1b00・dc3a・659f・2d1f・ff4d・a0f1・3e1d・5fcb を作成した。層の名前とトップレベル名前空間（`LangSemantics.<lang>` / `SourceModel` / `Spec` / `Abstraction` / `TargetModel` / `Refinement`）は [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md)、SQL 意味論は [ADR 5fcb](decision/5fcb-sql-semantics-for-source-repositories.md)。
* **Creation**: 正規仕様 [spec/](spec/README.md) 初版（draft、未レビュー）を作成した。上流 commit `f4bfbf0615eb91805546c9c780d4761be92ce17e` を調査対象とした。
* **Creation**: バックログ [backlog/](backlog/README.md) be49・a8be・591d・25f7・bbcc・0be7・aedf・4e0e・44f8・ac71・4b0e・a8ef・f18c・a89e・31da・c7e8・ddbd を作成した。
