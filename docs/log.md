# Directory Update Log

## 2026-10-31

* **Creation**: [ADR 0042](decision/0042-porting-conditions-and-workflow.md) で、スキル port-lang に移植が成り立つ条件を明示し、進め方の既定を補うことを決めた。
  * スキルの [SKILL.md](../.agents/skills/port-lang/SKILL.md) に「移植が成り立つ条件」（適用の前提・成立の条件・言えること・言えないこと）を加え、版を 0.4 にした。
  * 進め方の既定として [workflow.md](../.agents/skills/port-lang/references/workflow.md) を新設した（評価・判断を記録する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録）。プロジェクトは置き換えてよい。
  * スキルの process.md・verification.md から workflow.md を参照した。
  * 独立したエージェントによる敵対的レビュー（2 観点、2 巡）を行い、指摘と対応を ADR 0042 に記した。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に「進め方の適用（ATRS）」を加えた。
* **Update**: [backlog 0024](backlog/0024-trace-tooling.md) を完了した（第 2 段）。
  * 追跡の道具 `tools/trace` に、`rehash`・`diff`・`impact` を加えた。
  * `rehash` は、検査の登録 `trace/checks.json` を使う。
  * `check` の TR-R に、`trace/renames.json` と「出典:」のロケータの参照切れを加えた。
  * `trace-dump` が定義の `module` を出力するようにした。
  * JVM・PostgreSQL との突き合わせを `tools/ci/jvm_table.sh`・`pg_table.sh` に切り出した。
* **Creation**: [ADR 0041](decision/0041-rehash-diff-impact-details.md) で、次の細部を決めた。ADR 0040 を補う。
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
* **Update**: 次の文書に、ADR 0041 による追加を反映した。
  * [rules/documentation.md](rules/documentation.md)（出典の記法）
  * [rules/atrs-porting.md](rules/atrs-porting.md)
  * [ADR 0036](decision/0036-traceability-hash-as-deterministic-check-record.md) の道具の節
  * スキル port-lang の traceability・upgrade・lean/trace-attributes
  * [AGENTS.md](../AGENTS.md)

## 2026-10-30

* **Update**: [backlog 0024](backlog/0024-trace-tooling.md) の第 1 段を終えた（`doing`）。追跡の道具 `tools/trace`（Rust）で、インベントリ・`check`・`manifest` を作った。最初の `trace/source-inventory.json`（1963 件）を生成し、[spec/traceability.md](spec/traceability.md) の生成区画を埋め、CI に加えた。機能と backlog の対応表 `trace/features.json` を置いた。
* **Creation**: [ADR 0040](decision/0040-trace-tooling-unresolved-details.md) で、追跡の道具の未確定事項を決めた。決めたのは、本文ハッシュ・正規化・ロケータの細部・版の文字列・機能と backlog の対応である。あわせて ADR 0036 の `seed:` の単位をテーブルに改めた。
* **Update**: [backlog 0016](backlog/0016-lang-semantics-sql.md) を完了した。`LangSemantics.Sql` に `ORDER BY` の許される順列の一意性の証明を加えた。PostgreSQL 16.15 で生成した突き合わせ表（373 件）を CI に加えた（この表で `VARCHAR(n)` の空白の切詰めの不一致を見つけて直した）。版を `trace/upstream.json` と [rules/atrs-porting.md](rules/atrs-porting.md) に、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Creation**: [ADR 0039](decision/0039-refinement-non-vacuity-obligations.md) で、リファインメントが空虚・自明に成り立つことを防ぐ付帯の義務と検査を定めた（作成時は 0038 だったが、main に [ADR 0038](decision/0038-lean-package-under-skill-assets-lean.md) が先に入ったため 0039 に採番し直した）。
  * 義務: 選択の像としての `Spec`（`Machine.ofChoice`・`FreeFrame`）、`Sound` と 1 点の初期状態（`InitIs`）、環境の固定（`Refines.Pinned`・`NoFaultReachable`）、標準の貼り合わせ（`Glue.ofStd`。部分写像）、入口の全域性（`TotalUnder`・`EnvWitness`）、`InitSurj`、`StateSafe`、両向きの W 課題（`Nontrivial`）、核の明示（`KernelIs`）
  * 検査: TR-G・TR-N を実装し、TR-V・TR-PE を定めた（ADR 0034・0036・0037 の決定は変えない）
  * 設計段階と実装後に、独立したエージェントによる敵対的レビューを行い、指摘と対応を ADR 0039 に記した
* **Creation**: [backlog 0030](backlog/0030-refinement-non-vacuity.md) を作り、完了した。スキル port-lang の `assets/lean/Machine/Adequacy.lean` と反例 `assets/lean/MachineTest/Adequacy.lean`（11 件）、`lean/Trace/Obligation.lean`（`lake exe obligation-check`）、`tools/ci/check_obligations.py` を作り、`tools/ci/lean.sh` に組み込んだ。追跡属性 `@[nondet]`・`@[std_abs]`・`@[kernel]`・`@[env_pre]` を加えた。
* **Update**: [spec/abstraction.md](spec/abstraction.md) を改めた。
  * 空虚化を防ぐ義務の節を加えた。
  * α の表に、核の列と、環境・HTTP の応答の行を加えた。
  * 前提型の差異の影響（出力のみ／中断）、入口の R 課題、SPEC-005〜008、ABS-048、Spec の非決定性 N-001〜N-005 を加えた（各登録簿に backlog の列）。
* **Update**: [spec/refinement.md](spec/refinement.md) に、同じ項目と REF-011・REF-012 を加えた。
* **Update**: [spec/assurance.md](spec/assurance.md) に、モデル間の保証の限界と、環境・マスタを入力とする写しの限界を加えた。[spec/domain-model.md](spec/domain-model.md) には、入口の値域を環境の前提とすることを加えた。
* **Update**: ADR [0034](decision/0034-b-method-refinement-and-explicit-deviations.md)・[0036](decision/0036-traceability-hash-as-deterministic-check-record.md)・[0037](decision/0037-conflict-as-spec-nondeterminism.md) の More Information に、ADR 0039 による追加を記した。
* **Update**: backlog [0012](backlog/0012-conformance-vector-format-and-generator.md)・[0024](backlog/0024-trace-tooling.md) と [rules/backlog.md](rules/backlog.md) の完了の定義を改めた。main で完了した [backlog 0003](backlog/0003-abstract-domain-types-and-master-data.md) に足すはずだった作業（非決定性の選択の型・入口の環境の前提）は、[backlog 0031](backlog/0031-spec-nondet-and-entry-env.md) として新設した。
* **Update**: スキル port-lang を 0.3 に改めた（architecture・traceability・conformance・verification・spec-documents・lean/trace-attributes・SKILL.md）。

* **Update**: [ADR 0038](decision/0038-lean-package-under-skill-assets-lean.md) で、スキル port-lang の Lake パッケージ `langSemantics` を `assets/` 直下から `assets/lean/` に移した。ルートと `lean/` の `require`・manifest、CI（`tools/ci/lean.sh`・`check_lean.py`・`.github/workflows/lean.yml`）、スキルの文書、[rules/atrs-porting.md](rules/atrs-porting.md)、[AGENTS.md](../AGENTS.md)、関係する backlog と ADR のパスを改めた。
* **Update**: [backlog 0002](backlog/0002-lang-semantics-java.md) を完了した。`LangSemantics.Java` に、`jdLit "0.01"` のビット表現と 1430 円・30% の例の定理、`minusDays` を足した。JVM で生成した突き合わせ表（581 件）と、運賃計算の double 式のネイティブ `Float` との突き合わせ（4,006,212 件）を CI に加え、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Update**: [rules/version-control.md](rules/version-control.md) の push の禁止を改め、自分で作ったブランチへの push と、そこからの PR の作成を認めた（既定ブランチと他人のブランチへの push は引き続き禁止、マージはオーナーが行う）。あわせて [AGENTS.md](../AGENTS.md)・[rules/README.md](rules/README.md)・[rules/backlog.md](rules/backlog.md) の要約を改めた。
* **Update**: [backlog 0003](backlog/0003-abstract-domain-types-and-master-data.md) を完了した。`lean/Spec/` に、基本演算・暦日・時刻・書式・文字クラス（`Spec.Prim`）、列挙・コード値・エンティティ・値域（`Spec.Model`）、設定（`Spec.Config`）、マスタデータと MD-1〜MD-8・参照関数（`Spec.MasterData`）、コードリスト（`Spec.CodeList`）を実装し、SPEC-001〜003 を証明した。`conformance/shared/format/` にベクタを作り、`lake test` で `Spec` に対して実行するようにした。あわせて [spec/domain-model.md](spec/domain-model.md)・[spec/master-data.md](spec/master-data.md)・[spec/configuration.md](spec/configuration.md) の形式化した節を要約（informative）に改め、[spec/conformance.md](spec/conformance.md) の操作名を足した。
* **Update**: [backlog 0027](backlog/0027-machine-refinement-framework.md) を完了した。スキル port-lang の `assets/Machine/` に、抽象機械・具体機械・貼り合わせ・`Machine.Refines`（INIT・入力の全域性・適用可能性・正しさ）・差異による制限・推移性を実装し、`assets/MachineTest/` で例と反例を証明した。CI（`tools/ci/lean.sh`）で `assets/` をビルドし、`axiom-check`・`trace-dump` の対象に `Machine` を加えた。あわせて [ADR 0034](decision/0034-b-method-refinement-and-explicit-deviations.md)（制限の関数の名前）と [spec/refinement.md](spec/refinement.md)（証明義務を 4 つに揃えた）を直した。
* **Update**: [backlog 0001](backlog/0001-lean-project-scaffold.md) を完了した。`lean/`（Lake パッケージ `atrs`、Lean v4.35.0、Batteries v4.35.0）に全名前空間の骨格・追跡属性（`Trace.Attr`）・`trace-dump`・`axiom-check`・テストを置き、CI（`tools/ci/lean.sh`、`.github/workflows/lean.yml`）を整えた。あわせて [ADR 0014](decision/0014-lean-toolchain-and-dependencies.md)（採った版）、[rules/atrs-porting.md](rules/atrs-porting.md)（配置）、[rules/version-control.md](rules/version-control.md)（コミット前の確認）を改めた。
* **Update**: [backlog 0025](backlog/0025-upstream-submodule-and-inventory.md) を完了した。上流 ATRS を `upstream/atrs` に submodule として commit 固定で取り込み、`trace/upstream.json`（版の宣言）と `trace/out-of-scope.json`（追跡の対象外）を作った。あわせて [rules/atrs-porting.md](rules/atrs-porting.md)（版の正、Windows の `core.longpaths`、TODO(spec) の解消）と [spec/traceability.md](spec/traceability.md#対象外) を改めた。
* **Creation**: [ADR 0033](decision/0033-foundational-principles.md) で、基本原則 3 項を、全 ADR・規約・スキルに優先する原則として定めた。3 項は次のとおり。
  * 両端の一致を決定論的な検証または変換で確認する。
  * 抽象モデルと移植元/先モデルの間に B メソッドのリファインメントを証明する。
  * 差異を証明と文書の両方ですべて明示する。
* **Creation**: 原則と矛盾する既存の決定を置き換える ADR を作った。
  * [0034](decision/0034-b-method-refinement-and-explicit-deviations.md): B メソッドのリファインメントと、名前付きの差異（前提型・観測型・モデル外、D/T 登録簿、R/W/C/L 課題）
  * [0035](decision/0035-generate-verus-mirror-from-target-model.md): Verus の写しを TargetModel から生成し、`Machine` を名前空間の例外に加える
  * [0036](decision/0036-traceability-hash-as-deterministic-check-record.md): 検査済みハッシュ、TR-D、`tmpl:`、TR 検査の例外の廃止
  * [0037](decision/0037-conflict-as-spec-nondeterminism.md): `Conflict` を Spec の非決定的な結果とする
* **Deprecation**: ADR [0004](decision/0004-two-layer-model-java-faithful-and-abstract.md)・[0022](decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)・[0023](decision/0023-cross-language-traceability.md)・[0029](decision/0029-concurrency-failure-as-conflict-error.md) を superseded にした。
* **Update**: ADR 0005・0011（FOR UPDATE の記述の訂正）・0019（`Postgresql` の表記、SQL の差分実行）・0024・0027・0032 に補足を加えた。置換済み ADR へのリンクを、後継の ADR へ張り替えた。
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
* **Creation**: backlog [0027](backlog/0027-machine-refinement-framework.md)（`Machine`）と [0028](backlog/0028-verus-mirror-generator.md)（写しの生成器）を作った。0002・0005〜0011・0013・0014・0016・0019〜0024 の範囲・完了条件を、R/W 課題と決定論的な手段に合わせて改めた。
* **Update**: 敵対的レビューの 2 回目の指摘を解消した。
  * [spec/abstraction.md](spec/abstraction.md): 複合的な R 課題に、差異の仮定を引き継いだ。D-009・D-014 を前提の外に、D-013 をモデル外に改めた。D-001・D-020 の前提を定めた。ABS-007・ABS-023〜025・ABS-047 と SPEC-001〜004 を加え、ABS-109/113/114 を廃止した。
  * [spec/refinement.md](spec/refinement.md): REF-009・SRC-010 を加え、Verus の禁止構文を広げた。
  * [spec/assurance.md](spec/assurance.md): `#[verifier::external]` の一覧、規範節ごとの行、活性の限界、追跡の道具、付録を加えた。
  * ADR 0033〜0037: モデル外の差異の位置づけ、前提の 2 つの形、`bv_decide` の禁止、`model_prelude.rs`、TR-T1 の生成物の扱い、`xml:`・`seed:`、改名の検査、実行環境の失敗と活性の限界を加えた。
  * ADR 0014・0030・0032 に補足（訂正）を加えた。0032 では、差分オラクルで入力を除外しないことにした。
  * スキル: 原典の事後条件を仮定にする抜け道、方言の差を無名の前提にする記述をなくした。
* **Creation**: backlog [0029](backlog/0029-rust-external-adapters.md)（DB・ファイル・時計のアダプタ）を作った。backlog の依存（0013 への依存、0010 → 0008）と担当（REF-008、SRC-005/007/008）を整え、0024 と 0025 の循環を解いた。
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
  * backlog の依存（0005・0024・0007 への依存）と担当を整えた。

## 2026-10-29

* **Creation**: 未決だった仕様を確定する ADR 7 件を作成した。[0026](decision/0026-email-validation-rule.md)（Email 規則）、[0027](decision/0027-validation-error-ordering.md)（検証エラーの並び）、[0028](decision/0028-clock-timezone-and-fixture-base-date.md)（Clock の Asia/Tokyo と fixture の投入日 2026-11-01）、[0029](decision/0029-concurrency-failure-as-conflict-error.md)（`Conflict` 分類）、[0030](decision/0030-member-update-in-single-transaction.md)（会員情報変更の 1 トランザクション化）、[0031](decision/0031-report-queue-at-least-once-delivery.md)（レポートキューの配信保証）、[0032](decision/0032-spec-corrects-unsafe-source-behavior.md)（原典の安全でない振る舞いを Spec で正す）。ADR 0008・0009・0011・0016 の More Information に後続へのリンクを足した。
* **Update**: 上流 `f4bfbf06` と依存ライブラリ（Spring Framework 7.0.3、Spring Security 7.0.x、Hibernate Validator 9.1.0.Final、ActiveMQ Artemis）のソースを読んで、仕様の未決事項と文書間の矛盾を解消した。[spec/input-validation.md](spec/input-validation.md)（Email、エラーの並び、日付の解析、項目名の対応、REST の搭乗者数）、[spec/http-contract.md](spec/http-contract.md)（セッションの規範節、ログインの遷移先、日付の JSON、ApiError のコード、Basic 認証の失敗）、[spec/errors-and-messages.md](spec/errors-and-messages.md)、[spec/ports.md](spec/ports.md)（規範節の範囲、Clock、採番、キュー、トランザクション）、[spec/abstraction.md](spec/abstraction.md)（既知差異 D-011〜D-021、課題 ABS-032〜034）など。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に上流の依存の版を記録した。backlog [0008](backlog/0008-member-usecases-and-input-validation.md)・[0013](backlog/0013-java-oracle-harness.md) の範囲を改めた。

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
