# Directory Update Log

## 2026-11-03
* **Creation**: [ADR 61e6](decision/61e6-env-relation-and-state-env-pre.md) で、束 `Machine.Preserves` の環境の固定を「具体側の環境の記述が許す選択の関係」（`Choice` の `D`・`adm`・`d₀`、成分 `noFaultStd`）に、環境の前提を状態と入力の述語（`TotalUnder`・`EnvWitness` は初期状態、`always` は 2 引数、並置は `sumEnv`・`altEnv`）に広げた。obligation-check（`adm` の形、`Pinned` の引数、`EnvWitness` の引数）、[spec/architecture.md](spec/architecture.md#空虚化を防ぐ義務) の表、テストと違反例 `v6_admPlain` を直した。スキルの版を 0.27 にした。来歴: 適用先 ATRS の予約の第 3 段 3d。
* **Update**: obligation-check の G3'（`Spec` の層の抽象機械の形）が、同じ状態の上の並置 `Machine.alt`（[ADR a303](decision/a303-shared-state-machine-alt-and-transaction.md)）も受けるようにした（版 0.27 に含める）。来歴: 適用先 ATRS の予約の第 3 段 3d（トップレベルへの統合）。

## 2026-11-02
* **Creation**: [ADR cd90](decision/cd90-estate-hoare-and-simp-tactics.md) で、命令型の計算（`EStateM`）の検証の道具を足した。スキルの版を 0.26 にした。
  * `LangSemantics.Core.EStateHoare`（Hoare 三つ組と合成の規則）
  * `LangSemantics.Core.EStateSimp`（`estate_simp`）、`LangSemantics.Java.EStateSimp`（`java_estate_simp`）
  * `LangSemantics.Java.JList.get_cons_one`
  * 例と反例は `Test/LangSemantics/EStateHoare.lean`。[lang/lean/rules.md](lang/lean/rules.md#命令型の計算の検証) に手順を書いた。
  * 来歴: 適用先 ATRS の ADR ab93（予約の第 3 段）。
* **Update**: 累積値の無い `for` 文を、処理済みの件数で添字づけた不変条件で扱う規則 `LangSemantics.Core.EStateHoare.Hoare.forIn_idx` を足した（版 0.26 に含める）。来歴: 適用先 ATRS の予約の第 3 段（搭乗者の列の挿入）。
* **Update**: 要素ごとの関係を両辺の写像で移す `LangSemantics.Core.List.Forall₂.map_of` と、弱める `Forall₂.imp` を足した（版 0.26 に含める）。来歴: 適用先 ATRS の予約の第 3 段（運賃種別の利用条件の検査の対応）。

## 2026-11-01
* **Creation**: [ADR cb1f](decision/cb1f-gap-inventory-procedure.md) で、差異の登録簿の棚卸しの手順と観点 G1〜G9 を [guide/gap-inventory.md](guide/gap-inventory.md) に置き、[guide/workflow.md](guide/workflow.md#未着手の可視化) と `SKILL.md` から参照した。登録簿の R 課題と課題表の差異の列の一致の検査を作業項目 [backlog 937d](backlog/937d-rtasks-task-table-consistency-check.md) にした。スキルの版を 0.26 にした。
  * 来歴: 適用先 ATRS の ADR f786（差異の棚卸し）。
* **Creation**: [ADR a303](decision/a303-shared-state-machine-alt-and-transaction.md) で、同じ状態を共有する機能の合成子 `Machine.alt`（`Machine.Alt`・`Machine.Machine.Alt`・`Machine.Concrete.Alt`・`Machine.Glue.Alt`・`Machine.Refines.Alt`・`Machine.Preserves.Alt`、例と反例 `Test/Machine/Alt.lean`）を足し、[spec/architecture.md](spec/architecture.md) に並置の使い分けを書き、状態を変える移植元の計算のための演算と言語パックの不足を足した。スキルの版を 0.25 にした。
  * `LangSemantics.Sql.Transaction.run`（取消。戻す成分は呼び出し側が決める）、`LangSemantics.Sql.Postgresql.PgTimestamp`（`TIMESTAMP` の列）。[lang/sql/semantics.md](lang/sql/semantics.md) を改めた。
  * `LangSemantics.Java.JLocalTime`・`JLocalDateTime`（`DateTimeFormatter.ofPattern("HHmm")` の SMART 解決、`LocalDateTime` の `atTime`・`atStartOfDay`・`plusMinutes`・`isBefore`。JVM の表に 22 の文字列と分の加算・比較の行を足した）、`LangSemantics.Java.JList.get`、`StringUtils.hasLength`・`hasText`。[lang/java/semantics.md](lang/java/semantics.md) を改めた。
  * 来歴: 適用先 ATRS の ADR 4c45（予約の第 1 段）。
* **Creation**: [ADR b187](decision/b187-proven-csimp-for-evaluating-models.md) で、モデルの評価を速くする実装を、元の定義と等しいことの定理を付けた `@[csimp]` で与えることにした（定義は書き換えない）。スキルの版を 0.24 にした。
  * `LangSemantics.Sql.Query.Bag.crossWhere`（条件を押し下げた入れ子ループの結合）と、`LangSemantics.Sql.QueryLemmas.filter_cross_split`・`select_cross_split` を足した。
  * [lang/lean/rules.md](lang/lean/rules.md#書き方) に規則を足した。
  * 来歴: 適用先 ATRS の ADR 9c1c（シードの DB を使う照合が CI で約 6 分かかっていた）。
* **Creation**: [ADR 89f2](decision/89f2-layout-check-one-process-per-group.md) で、`layout-check`（`Trace.Layout.run`）のモジュールの組を、組ごとに別のプロセス（同じ実行ファイルを `--layout-group <i>` で起動したもの）で判定するようにした。親は環境を読み込まず、結果の JSON を `mergeGroups` で合わせる。メモリの最大は組 1 つ分になる。出力と呼び出しは変えていない（違反は終了コード 1、組の判定の失敗は 2）。スキルの版を 0.23 にした。
  * `Trace.Layout.Result` に範囲のモジュールとその検査数 `modules` を、`Result.collapse`・`GroupOut`・`mergeGroups`・`runGroup`・`runAll` を足し、`Item.toJson`・`Result.merge` を除いた。`trace-test` に合わせ方と JSON の往復の検査を足した。[lang/lean/trace-attributes.md](lang/lean/trace-attributes.md)・[lang/lean/rules.md](lang/lean/rules.md#モジュールと名前空間) を改めた。
  * 来歴: 適用先 ATRS の CI（組を足すと runner がメモリで止まった）。
* **Update**: [ADR 22b4](decision/22b4-split-okf-and-records-skills.md) で、移植に関係の無い文書の道具と規則を、別のスキル okf-bundle・work-records に分けた。スキルの版を 0.22 にした。
  * `scripts/docs/okf_check.py`・`scripts/docs/docmv.py`・`scripts/ci/fixtures/okf/` をスキル okf-bundle に、`scripts/docs/ids.py` をスキル work-records に移した。`scripts/docs/` は無くなった。
  * 道具の設定を、`trace/project.json` の `okf`・`ids` から、適用先のルートの `.okf.json`・`.work-records.json` に移した。[spec/traceability.md](spec/traceability.md#プロジェクトの設定) の表から `ids`・`okf` を除いた。
  * このバンドルの規則（プロファイル）を `scripts/docs/profiles/spec-pivot.json` から `references/okf-profile.json` に移した。記録の形の検査（プロファイルの `kind`）は work-records の `ids.py check` に移った。
  * [rules/maintenance.md](rules/maintenance.md) を、このバンドルに固有の事項（構成・置き場所・持ち出せること・分担）に絞った。形式・記録の書き方は両スキルの規則に従う。`SKILL.md`・`scripts/README.md`・[guide/workflow.md](guide/workflow.md#記録と中断への備え)・`scripts/trace/src/project.rs` のコメントを合わせた。
  * 既存の記録（ADR 330e・748c・87b9、作業項目 de90・a49c・97a7）は、来歴としてこのバンドルに残した。
  * 来歴: 適用先 ATRS のオーナーの依頼（ATRS の ADR 625d・backlog 2ba8）。
* **Update**: [ADR 288a](decision/288a-rename-oracle-to-origin-run.md) で、「オラクル」を「原典実行」（`origin-run`）と呼び替えた。ベクタの `source` は `<移植元>-origin-run`。言語パック・方法の文書・既存の ADR と作業項目の本文・この変更履歴をそろえた（版 0.21 に含める）。来歴: 適用先 ATRS の ADR 18ca。
* **Creation**: [ADR 7d3a](decision/7d3a-java-conformance-kit-and-http-origin-run-method.md) で、Java の原典実行の道具 `assets/java/conformance-kit/`（Maven）を置いた。スキルの版を 0.21 にした。
  * `Json`・`Op`・`Runner`（照合・期待値の採取・`--check`）、`Reflect`（注入）、`http.HttpCapture`（要求の送信と応答の採取・正規化）、`http.WebappServer`（web.xml のままの webapp を組み込み Tomcat で起動）。
  * [lang/java/harness.md](lang/java/harness.md) に、原典のリポジトリで Provider を読む組み立て、ORM の一次キャッシュ、HTTP レベルの原典実行の方法と道具を書いた。`SKILL.md`・`scripts/README.md` を合わせた。
  * `scripts/ci/with_postgres.sh`: `WITH_POSTGRES_TCP=1` で一時クラスタを 127.0.0.1 でも待ち受けさせる（JDBC 用）。
  * 来歴: 適用先 ATRS の ADR 81da（backlog f18c）。
* **Creation**: [ADR 8cb7](decision/8cb7-run-python-tools-with-uv.md) で、Python の道具をシステムの `python3` でなく `uv run python -I` で実行するようにした。スキルの版を 0.20 にした。
  * `scripts/ci/pg_table.sh`・`scripts/trace`（`check_obligations.py` の呼び出し）が uv で Python を呼ぶ。各道具の使い方の docstring、`assets/lean/Test/LangSemantics/pg/pg_table.py` とその生成物 `PostgresqlDb.lean` の再生成の手順、[rules/maintenance.md](rules/maintenance.md)・`SKILL.md`・`scripts/README.md` を改めた。
  * 来歴: 適用先 ATRS の ADR 44a0（タスクの実行器は適用先が選ぶ）。
* **Creation**: 移植元のモデルを人が原典と見比べられるようにした（[ADR 1f75](decision/1f75-java-expression-syntax-and-spring-assert.md)・[ADR 8a3c](decision/8a3c-mirror-layout-check-and-review-view.md)）。スキルの版を 0.19 にした。
  * `LangSemantics.Java.Expr`: Java の式の構文 `java!`（JLS の優先順位・数値昇格・リテラルの型・キャスト・短絡評価・例外を投げうる式）。展開した項は原始関数の項と構文として同じ（`Test.LangSemantics.JavaExpr`）。原始関数 `j32neg`・`j64neg`・`jrem64`・`JDouble.neg`・`jdneg` を足した。
  * `LangSemantics.Java.Spring`: Spring の `Assert`（`isTrue`・`notNull`・`notEmpty`・`hasText` と、値を返す `notNullValue`・`notEmptyValue`）。`LangSemantics.Java.Exception.jAssert` は削除した（`Assert.isTrue` に置き換える）。
  * [lang/java/semantics.md](lang/java/semantics.md#式の構文-java) に構文と語彙の対応表を、[lang/java/layout.md](lang/java/layout.md#移植元として原典を読む) に原典のソースツリーの形に並べる規則を書いた。[lang/lean/rules.md](lang/lean/rules.md)・[lang/sql/layout.md](lang/sql/layout.md)・[spec/architecture.md](spec/architecture.md) を合わせた。
  * 道具: `trace check` に TR-M（配置・名前・引数・欄。設定は `source.mirror`）、`trace review`（原典とモデルの対照表）を足した。`trace-dump` は `params`・`fields`・`range` を出力する。`check_lean.py` は、式の構文のモジュール `LangSemantics.<Lang>.Expr` に限り `Lean` の import を許す。[spec/traceability.md](spec/traceability.md#検査) を改めた。
  * 来歴: 適用先 ATRS の ADR e41c。

* **Creation**: [ADR cfad](decision/cfad-name-the-method-spec-pivot.md) で、この方法を **Spec Pivot** と名付け、スキルの名前を `port-lang` から `spec-pivot` に改めた。スキルの版を 0.18 にした。
  * ディレクトリ・frontmatter の `name`・文書のバンドルの規則のファイル（`scripts/docs/profiles/spec-pivot.json`）を改め、文書・コード・コメントの名前を改めた。過去の項の文は来歴として旧名のまま残す。
  * 来歴: 適用先 ATRS の ADR fa26。

* **Update**: 適用先の R 課題（SQL の結合・整列と、`LinkedHashMap` への畳み込みを含むもの）の証明に使う汎用の補題を足した。スキルの版を 0.17 にした。
  * `LangSemantics.Sql`: `Truth.holds_or`・`inList_text_holds`・`SqlValue.eq_date_holds`・`Collation.codepoint_ne_gt`・`Collation.codepoint_eq`（`Core`）、結合の補題 `filter_cross_opt`・`filterMap_cross`・`filterMap_unique`（`QueryLemmas`）。
  * `LangSemantics.Core`: `mapM_perm`・`mapM_pairwise`（`MapM`）、`rel_of_pairwise_symm`（`List`）。
  * `LangSemantics.Java`: `JHashMap` の `get`・`put` と項目ごとの写し `pairAlpha` の可換性 `get_alpha`・`put_alpha`（`HashMap`。キーの写しが単射のとき）、`for` の模倣 `forIn_map_sim`（`ResultLemmas`）、`J64.val_ofInt_of_inRange`（`Int`）。
  * `LangSemantics.Java.DecimalFormat`: 書式の記号の組 `Symbols`（区切り文字・数字の 0・負の記号の文字列）と、それによる書式 `formatGroupedS`・`formatJ32S`、ASCII の記号で `formatGrouped` に等しいこと `formatGroupedS_ascii`。JVM との突き合わせ表に、6 つのロケール（ja-JP・de-DE・fr-FR・th-TH-u-nu-thai・ar-EG・fa-IR）の行を足した（記号は JVM から取る）。[lang/java/semantics.md](lang/java/semantics.md#演算名前は仕様文書でも共通に使う) を改めた。
  * 来歴: 適用先 ATRS の空席照会の第 3 段（R 課題 ABS-011。ATRS の ADR 0b0c）。

* **Update**: `LangSemantics.Sql.QueryLemmas` に条件の押し下げの補題 `cross_filter_left`・`select_filter_of_imp` を、`LangSemantics.Java.JLocalDate.RoundTrip` に妥当な暦日での `ofEpochDay (toEpochDay x) = x`（400 年の周期の全日をカーネルで確かめる）を、`Machine.Kernel` に `mapM_inj` を足した。スキルの版を 0.16 にした。[lang/sql/semantics.md](lang/sql/semantics.md) を改めた。来歴: 適用先 ATRS の空席照会の第 2 段（PostgreSQL での差分実行で、FLIGHT の全件の直積を避ける）。

* **Update**: `LangSemantics.Java` に `String.substring`（`jSubstring`・`jSubstringFrom`。UTF-16 の位置と補助文字の扱いの補題 `charsBeforeUtf16_bmp`）と、`DecimalFormat` の 3 桁区切りの整数の書式（`LangSemantics.Java.DecimalFormat.formatGrouped`）を足した。JVM との突き合わせ表（`Test/LangSemantics/JavaJvm.lean`。生成器 `jvm/JavaTable.java`）に行を足した。スキルの版を 0.15 にした。
  * [lang/java/semantics.md](lang/java/semantics.md#演算名前は仕様文書でも共通に使う) を改めた。
  * 来歴: 適用先 ATRS の空席照会（ATRS の ADR ce36・backlog 0be7）。

## 2026-10-31

* **Creation**: [ADR 6b4b](decision/6b4b-preserves-refines-abstracts.md) で、義務の束 `Machine.Adequate` を廃止し、`Machine.Refines`（B refines A。B メソッドのリファインメント）・`Machine.Preserves`（A preserves B。R 課題の空虚化を防ぐ意味的な義務のすべて。`Refines` を含まない）・`Machine.Abstracts`（A abstracts B = A preserves B ∧ B refines A）に分けた。[ADR ab9e](decision/ab9e-adequate-bundle-sum-and-side-staging.md) を置き換えた（並置と側ごとの段階導入は引き継ぐ）。スキルの版を 0.14 にした。
  * assets: `Machine.Preserves`（`Choice`・`OutLayer`・`OutLayerC`、条件付きの成分 `pinned`・`noFault`・`freeFrame`・`stateSafe`・`stateSafeC`）・`Machine.Abstracts` と、その並置。モジュール `Machine.Adequacy`・`Machine.{Machine,Concrete,Glue,Refines}.Adequacy` を `Machine.Preserves.Pred`・`Machine.{Machine,Glue,Refines}.Preserves`・`Machine.{Machine,Concrete}.Run` に改めた。`Refines.run`・`Refines.complete` は `Abstracts.run_of`・`Abstracts.complete_of` に改めた。
  * 検査: obligation-check の G6（束の `ch`・`outs` の照合）と GP（旧 GA）、`check_obligations.py` の OB-P（旧 OB-A。フィクスチャ `r-without-preserves`）、`scripts/trace` の `preserves`。
  * [architecture.md](spec/architecture.md#空虚化を防ぐ義務)（B との照合、`Preserves`・`Abstracts` の定義、外に残る義務、トップレベルの主定理）、[traceability.md](spec/traceability.md#検査)、[lean/rules.md](lang/lean/rules.md)・[trace-attributes.md](lang/lean/trace-attributes.md)・`SKILL.md` を改めた。
  * 来歴: 適用先 ATRS のオーナーの依頼（ATRS の ADR 91be・backlog cb23）。

* **Creation**: [ADR 1a30](decision/1a30-lean-module-namespace-layout.md) で、Lean の宣言をモジュール名の下に置く規則（NS-1。例外 E1〜E4）と、機能の証明課題を機能のモジュールに置く規則（TR-L1・TR-L2）を定めた（[backlog ce23](backlog/ce23-lean-module-namespace-layout.md)）。スキルの版を 0.13 にした。
  * [lean/rules.md](lang/lean/rules.md#モジュールと名前空間)・[architecture.md](spec/architecture.md#層)・[traceability.md](spec/traceability.md#検査)・[trace-attributes.md](lang/lean/trace-attributes.md)・`scripts/README.md` を改めた。
  * 道具: `Trace.Layout` と `lake exe layout-check`、属性 `@[ns_exception]`、`trace check` の TR-L、改名の道具 `scripts/lean/rename.py`。
  * assets の宣言を書き換えた。型名のモジュール（`LangSemantics.Java.JDouble`・`JLocalDate`・`Machine.Machine`・`Machine.Glue`・`Trace.Gap`）、`Machine.Adequacy`・`Machine.Sum` の型ごとの分割、`Machine.Adequate`、`Machine.Sum.sumPred`、`LangSemantics.Java.DoubleOps`、`Machine.Concrete.ofMachine`（旧 `Machine.toConcrete`）。
  * 来歴: 適用先 ATRS のオーナーの依頼。ATRS の側の書き換えは ATRS の backlog 9ed8 にある。

* **Creation**: [ADR ab9e](decision/ab9e-adequate-bundle-sum-and-side-staging.md) で、義務の束・機械の並置・側ごとの段階導入を決めた。スキルの版を 0.12 にした。
  * `assets/lean/Machine/Adequacy.lean`: 義務の束 `Machine.Adequate` と系 `run_init`・`exists_ok`、`Refines.complete_fun`。`assets/lean/Machine/Sum.lean`（新設）: `Machine.sum`・`Concrete.sum`・`Glue.sum`・`sumPred`、`Refines.sum`・`Adequate.sum`・`Adequate.congrPre`。
  * obligation-check（`assets/lean/Trace/Obligation.lean`）の GA と、G3' の並置。`scripts/ci/check_obligations.py` の OB-A（フィクスチャ `r-without-adequate`）。`scripts/trace` の側ごとの段階導入、TR-P の束の閉包、`check --verbose` の `--feature`・`--rule`。`scripts/docs/ids.py` の側ごとの作業項目。
  * [architecture.md](spec/architecture.md#空虚化を防ぐ義務)（義務の束・トップレベルの主定理）、[traceability.md](spec/traceability.md#検査)（TR-P・TR-G・段階導入・`features.json`）を改めた。
  * 来歴: ATRS の ADR a41d・backlog 76a6。
* **Update**: 文書を性格ごとのディレクトリに分けた（[ADR 748c](decision/748c-skill-docs-category-directories.md)、[backlog 97a7](backlog/97a7-skill-docs-category-directories.md)）。スキルの版を 0.11 にした。
  * 方法の文書を `spec/`（[architecture.md](spec/architecture.md)・[portability.md](spec/portability.md)・[traceability.md](spec/traceability.md)・[conformance.md](spec/conformance.md)・[verification.md](spec/verification.md)。`type: Specification`）、`rules/`（[spec-documents.md](rules/spec-documents.md)・[maintenance.md](rules/maintenance.md)。`Guideline`）、`guide/`（[process.md](guide/process.md)・[workflow.md](guide/workflow.md)・[upgrade.md](guide/upgrade.md)・[adding-a-language.md](guide/adding-a-language.md)。`type: Guide`）に移した。
  * 言語パック `java/`・`sql/`・`rust/`・`lean/` を `lang/` の下に移した。ファイル名と中の構成は変えていない。
  * [index.md](index.md) の節、[maintenance.md](rules/maintenance.md#バンドルの構成) の表、プロファイル `scripts/docs/profiles/spec-pivot.json` の規則を改めた。
  * 移動とリンクの張り直しの道具 `scripts/docs/docmv.py` を足した（`scripts/README.md`）。スキル・適用先の文書のリンクと、コード・設定の中のパスの言及を、これで張り直した。
* **Creation**: [ADR c08b](decision/c08b-test-namespace-for-skill-asset-tests.md) で、`assets/lean` の検査 `LangSemanticsTest`・`MachineTest`・`ConformanceKitTest`・`TraceTest` を `Test.LangSemantics`・`Test.Machine`・`Test.ConformanceKit`・`Test.Trace`（ディレクトリ `assets/lean/Test/`）に改めた。Lake のライブラリを `Test` の 1 つにし、`scripts/ci/check_lean.py` が `Test` を `Tests` の層として扱うようにした。スキルの版を 0.10 にした。
  * [lean/rules.md](lang/lean/rules.md)・[architecture.md](spec/architecture.md#層)・`SKILL.md`・`scripts/README.md`・言語パックの文書の名前とパスを改めた。
  * 来歴: 適用先 ATRS のオーナーの依頼。
* **Creation**: [ADR 330e](decision/330e-okf-bundle-check-tool.md) で、OKF のバンドルとリンクの検査の道具 `scripts/docs/okf_check.py` を置いた（[backlog a49c](backlog/a49c-okf-bundle-check-tool.md)）。スキルの版を 0.9 にした。
  * このバンドルの規則を `scripts/docs/profiles/spec-pivot.json` にした。違反例を `scripts/ci/fixtures/okf/` に置いた。
  * [maintenance.md](rules/maintenance.md#バンドルの検査)（検査と YAML の部分集合）・[traceability.md](spec/traceability.md#プロジェクトの設定)（設定の `okf`）・`scripts/README.md` を改めた。
  * 来歴: ATRS の backlog ddbd。ATRS の側の決定は ATRS の ADR 920d にある。
* **Creation**: このバンドル（`references/docs/`）を作った（[ADR 87b9](decision/87b9-skill-docs-as-okf-bundle.md)、[backlog de90](backlog/de90-skill-docs-okf-bundle-and-records.md)）。スキルの版を 0.8 にした（0.7 はギャップの証明の状態 `Trace.Evidence` の追加。ATRS の ADR 6ab4 で入った）。
  * `references/*.md` と言語パック（`java/`・`sql/`・`rust/`・`lean/`）をここへ移し、OKF v0.2 の frontmatter を付けた。方法の文書は `Guideline`、言語パックは `Reference` とした。
  * [index.md](index.md)・log.md・[maintenance.md](rules/maintenance.md)（保守の規則）・[decision/README.md](decision/README.md)・[backlog/README.md](backlog/README.md) を作った。
* **Creation**: ATRS の `docs/` から、スキルの記録を移した。ID とファイル名は変えていない。ATRS へのリンクは来歴の文に直した。
  * 意思決定記録: [ADR 6edf](decision/6edf-lean-package-under-skill-assets-lean.md)、[ADR 0eea](decision/0eea-trace-tooling-unresolved-details.md)、[ADR 9cd9](decision/9cd9-rehash-diff-impact-details.md)、[ADR 0b83](decision/0b83-porting-conditions-and-workflow.md)、[ADR 7fe4](decision/7fe4-move-trace-attributes-to-skill.md)、[ADR edc8](decision/edc8-skill-scripts-and-generic-lean-libraries.md)
  * 作業項目: [backlog 1ae4](backlog/1ae4-machine-refinement-framework.md)、[backlog a936](backlog/a936-lang-semantics-rust.md)。ATRS の backlog be49 への `depends_on` を外した。a936 の完了条件を、適用先に依存しない形にした。
* **Update**: `scripts/docs/ids.py` を改めた。
  * 種類ごとに複数の置き場所を持てるようにした（`ids.kinds` の配列）。
  * 持ち出すバンドルを検査するようにした（`ids.isolated`）。
  * `new --dir` と `move` を足した。
  * あわせて [traceability.md](spec/traceability.md#プロジェクトの設定) と `scripts/README.md` を改めた。
