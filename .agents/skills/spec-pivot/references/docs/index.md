---
okf_version: "0.2"
---

# Specification

* [構成: 層・名前空間・依存・リファインメント・正規性](spec/architecture.md) - 層・Lean の名前空間・依存の向き・B メソッドのリファインメントと証明課題・空虚化を防ぐ義務・正規性の順位。
* [言語中立性の制約（Spec に課す）](spec/portability.md) - Spec をあらゆる移植先言語へ同じ振る舞いで写すために課す、言語中立性の制約。
* [両端の追跡（トレーサビリティ）](spec/traceability.md) - 移植元ソース⇔SourceModel と TargetModel⇔移植先ソースの両端の追跡: ロケータ・注釈・検査済みハッシュ・インベントリ・manifest・TR 検査・道具とプロジェクトの設定。
* [適合テストベクタの形式](spec/conformance.md) - 言語中立な適合テストベクタの置き場所・JSON の形式・比較の規則・生成と実行器。
* [検証の使い分け](spec/verification.md) - 両端の一致を確かめる決定論的な手段と、Lean の証明・検証器・テストの使い分け、保証の限界の文書の必須項目。

# Rules

* [仕様文書の書き方](rules/spec-documents.md) - Spec で表現できない仕様・草案・要約を書く Spec のモジュール文書と、メタ情報の Markdown の文書の区分・節構成・差異の表、仕様の本、道具が読む見出しと値。
* [スキルの文書の保守](rules/maintenance.md) - references/docs（OKF v0.2 のバンドル）の構成と置き場所、スキル okf-bundle・work-records による形式と記録の検査、持ち出せること、適用先との分担。

# Guide

* [移植の手順](guide/process.md) - 機能単位で進める移植の手順 1〜10 と、各手順の成果物・次へ進む条件・完了の定義。
* [作業の進め方（既定）](guide/workflow.md) - 人と AI エージェントがこの方法で移植を進めるときの既定の進め方: 評価・判断の記録・検査ゲート・敵対的レビュー。
* [版上げへの追従](guide/upgrade.md) - 移植元の版上げへの追従: 最新版だけの SourceModel、インベントリの差分、差分の原典実行、証明のグラフに沿った影響の洗い出し。
* [型の棚卸し](guide/type-inventory.md) - Lean のデータ型が、不正な状態を表現できない型（MISU。ADR bf1b）になっているかを確かめる手順と観点の一覧。
* [差異の棚卸し](guide/gap-inventory.md) - Spec とモデル（SourceModel・TargetModel）の差異の登録簿が、実装と原典の両方に合っているかを、全範囲で確かめる手順と観点の一覧。
* [言語パックの構成と追加のしかた](guide/adding-a-language.md) - 言語パックの 6 ファイルの構成と、新しい言語・SQL 方言を追加するときの手順。

# Language: Java

* [Java: LangSemantics.Java](lang/java/semantics.md) - Java の基本型を整数演算だけでエミュレートする LangSemantics.Java の名前付き演算と、処理系との突き合わせ。
* [Java: フレームワーク・ランタイムの効果](lang/java/frameworks.md) - Java のフレームワーク・ランタイムが与える効果と、モデルへの写し方・dep: ロケータ。
* [Java: ソースの構成と Lean 名前空間の対応](lang/java/layout.md) - Java のソースの構成と、Lean の名前空間の対応。
* [Java: ロケータとインベントリ](lang/java/locators.md) - Java のロケータの文法とインベントリの作り方。
* [Java: ベクタの実行（原典実行／照合）](lang/java/harness.md) - Java のコードに適合テストベクタを当てるハーネス（原典実行／照合）の作り方。
* [Java: 検証器](lang/java/verification.md) - Java のソースとモデルの一致を確かめる決定論的な手段と、その保証の限界。

# Language: SQL

* [SQL: LangSemantics.Sql](lang/sql/semantics.md) - DBMS に依存しない SQL の意味論 LangSemantics.Sql と、方言の分け方。
* [SQL: 処理系・マッパの効果](lang/sql/frameworks.md) - SQL の処理系・マッパが与える効果の共通事項と、方言パックへの振り分け。
* [SQL: ソースの構成と Lean 名前空間の対応](lang/sql/layout.md) - SQL（Mapper・クエリファイル）の構成と、Lean の名前空間の対応。
* [SQL: ロケータとインベントリ](lang/sql/locators.md) - SQL のロケータの文法とインベントリの作り方。
* [SQL: ベクタの実行](lang/sql/harness.md) - データベースを含む適合テストベクタの実行条件と、処理系との差分実行の結果の形。
* [SQL: 検証](lang/sql/verification.md) - SQL を LangSemantics.Sql の式として写し、リポジトリのリファインメントで確かめる方法と、その保証の限界。
* [SQL 方言 PostgreSQL: LangSemantics.Sql.Postgresql](lang/sql/dialects/postgresql/semantics.md) - PostgreSQL 固有の意味論 LangSemantics.Sql.Postgresql と、処理系との突き合わせ。
* [SQL 方言 PostgreSQL: 処理系の効果と版](lang/sql/dialects/postgresql/engine.md) - PostgreSQL の処理系が与える効果と、版の固定。
* [SQL 方言 PostgreSQL: ベクタの実行環境](lang/sql/dialects/postgresql/harness.md) - PostgreSQL で SQL の適合テストベクタを実行する環境の設定。

# Language: Rust

* [Rust: LangSemantics.Rust](lang/rust/semantics.md) - Rust の値の意味論 LangSemantics.Rust の名前付き演算と、処理系との突き合わせ。
* [Rust: ランタイム・クレートの効果](lang/rust/frameworks.md) - Rust のランタイム・クレートが与える効果と、モデルへの写し方・dep: ロケータ。
* [Rust: ソースの構成と Lean 名前空間の対応](lang/rust/layout.md) - Rust のクレートの構成と、Lean の名前空間・Verus の写しの対応。
* [Rust: ロケータとインベントリ](lang/rust/locators.md) - Rust のロケータの文法とインベントリの作り方。
* [Rust: ベクタの実行（照合／原典実行）](lang/rust/harness.md) - Rust のコードに適合テストベクタを当てるテスト（照合／原典実行）の作り方。
* [Rust: 検証器（Verus・Kani）](lang/rust/verification.md) - Rust のソースとモデルの一致を確かめる検証器（Verus・Kani）と、その保証の限界。

# Language: Lean

* [Lean プロジェクトの規約](lang/lean/rules.md) - 形式化言語 Lean 4 のプロジェクトの規約: ツールチェーン、依存、禁止する構文、名前、静的検査。
* [Lean の追跡属性と trace-dump](lang/lean/trace-attributes.md) - Lean の追跡属性・ギャップの登録簿と、trace-dump・obligation-check の実装。

# Decisions

* [スキルの意思決定記録](decision/README.md) - スキル spec-pivot の意思決定記録（MADR 4.0）の索引。
* [layout-check のモジュールの組を、組ごとに別のプロセスで判定する](decision/89f2-layout-check-one-process-per-group.md) - layout-check（Trace.Layout.run）は、モジュールの組ごとに環境を読み込んで解放しないため、メモリが組の数に比例して増えていた。組ごとに同じ実行ファイルを子プロセスとして起動して判定し、親は結果の JSON を合わせるだけにする。Environment.freeRegions による解放は採らない。
* [不正な状態を表現できない型（MISU）を Lean のすべてのデータ型に課す](decision/bf1b-make-illegal-states-unrepresentable.md) - 値の妥当性の条件を docstring・別の述語・付けた時点の検査に置かず、型（和型・証明フィールド付きの structure・名前付きの structure）で表す。外部から来る値は生の型のまま置き、検証の関数で検証済みの型に移す。機械の PRE・INV、独立な入力の間の関係、環境の全体にわたる性質は述語・検査のまま残す。
* [差異の登録簿の棚卸しの手順を方法の文書に置く](decision/cb1f-gap-inventory-procedure.md) - 差異の登録簿が実装と原典に合っているかを全範囲で確かめる棚卸しの手順と観点（G1〜G9）を、guide/gap-inventory.md に置く。登録簿の R 課題と課題表の一致の検査は作業項目にする。
* [OKF のバンドルの管理と記録の管理を、別のスキル okf-bundle・work-records に分ける](decision/22b4-split-okf-and-records-skills.md) - 移植に関係の無い文書の道具（okf_check.py・docmv.py・ids.py）と規則を、スキル spec-pivot から汎用のスキル okf-bundle（OKF のバンドル）と work-records（ADR・作業項目）に分け、設定を trace/project.json から専用のファイル .okf.json・.work-records.json に移し、移植に固有の検査を一般化する。
* [モデルの評価を速くする実装は、元の定義と等しいことの定理を付けた @[csimp] で与える](decision/b187-proven-csimp-for-evaluating-models.md) - SourceModel・Spec などの定義を、評価（適合テストベクタの実行）のために書き換えない。速い実装は別の定義とし、元の定義と等しいこと（行の並びも含めて）を定理にして @[csimp] で登録し、コンパイル後のコードだけを差し替える。証明の無い implemented_by は使わない。SQL の写しの結合のために、条件を押し下げた入れ子ループの結合 Bag.crossWhere と補題 filter_cross_split・select_cross_split を LangSemantics.Sql に置く。
* [Java の適合テストの道具 conformance-kit を assets に置き、HTTP レベルの原典実行の方法を言語パックに書く](decision/7d3a-java-conformance-kit-and-http-origin-run-method.md) - Java の原典実行に共通の部分（ベクタの読み書き・実行器・期待値の採取・反射による組み立て・HTTP の採取・組み込み Tomcat での webapp の起動）を、スキルの assets/java/conformance-kit に Maven モジュールとして置く。言語パックの harness.md に、原典のリポジトリで Provider を読む組み立て、ORM の一次キャッシュ、HTTP レベルの原典実行（web.xml を変えずに context-param で構成を差し替える）の方法を書く。with_postgres.sh に TCP で待ち受ける形を足す。
* [同じ状態を共有する機能の合成子 Machine.alt、トランザクションの取消、LocalTime・List.get・StringUtils・TIMESTAMP の写し](decision/a303-shared-state-machine-alt-and-transaction.md) - 状態の成分を共有する 2 つの機能の機械を、同じ状態の上で入力と出力を和にして並置する合成子 Machine.alt（と Concrete・Glue・Refines・Preserves.core の alt）を足す（実装は適用先の段に合わせる）。状態を変える移植元の計算のために、トランザクションの取消 LangSemantics.Sql.Transaction.run を置く。言語パックに java.time.LocalTime（HHmm の SMART 解決）・LocalDateTime、List.get、Spring の StringUtils、PostgreSQL の TIMESTAMP を足す。
* [仕様の散文を Spec のモジュール文書に書き、mdgen と mdbook で本にする道具を置く](decision/c634-spec-prose-in-lean-module-docs-and-book.md) - Spec で表せない仕様・形式化前の草案・形式化した規則の要約を、Markdown の仕様文書ではなく Spec のモジュール文書（/-! -/）の節として、定義のすぐ前に書く。Markdown の仕様文書にはメタ情報だけを残す。mdgen（assets/mdgen）と mdbook で HTML の本を作る道具 scripts/book/build.py と、仕様への参照の行き先の検査、TR-R のモジュール文書への拡張を置く。
* [本を部に分け、目次をモジュール名の階層で入れ子にする](decision/d2b6-book-parts-and-namespace-toc.md) - scripts/book/build.py の設定に book.parts（部の題・Lean のルート base・トップレベルのモジュールの列）を足し、複数の Lean のルートを 1 冊にする。目次は、部ごとに入口のモジュールの import の順、モジュール名の階層の入れ子とし、モジュールの無い中間の名前はページの無い見出しにする。本に入れた Lean のファイルへのリンクは、部をまたいでも本のページへ向ける。
* [Spec のモジュール文書には仕様だけを書き、根拠は章の末尾の「根拠と対応」節にまとめる](decision/f3c5-spec-module-docs-without-history.md) - Spec のモジュール文書（仕様の本の地の文）の前文と本文に、作業の経緯（作業項目の ID・段・経緯の物語）を書かない。根拠の意思決定記録・関係する既知差異・対応する移植元モデル・抽象化の証明・適合テストベクタは、各章の末尾の「根拠と対応」節にまとめる。序のモジュールに区分と記号の凡例を置く。題の形と区分の表示を実態にそろえる。
* [束 Preserves の環境の固定を「許す選択の関係」に、環境の前提を状態つきの述語に広げる](decision/61e6-env-relation-and-state-env-pre.md) - 障害の位置を具体側の入力が持ち、障害が実際に起きるかと、起きるまでに進んだもの（採番など）が実行で決まるユースケースでは、環境の選択を入力だけの関数 ce で決められない。束の pinned を、具体側の環境の記述 ce ic が許す選択の関係 adm に広げ、障害の指定の無い記述は標準の選択だけを許す（noFaultStd）。また、状態とマスタの対応（外部キー）を PRE に持つユースケースのため、環境の前提を状態と入力の述語にし、その証人は初期状態で示す。
* [命令型の計算の検証の道具: EStateM の Hoare 三つ組と、計算の形を求める簡約のタクティク](decision/cd90-estate-hoare-and-simp-tactics.md) - 移植元・移植先の命令型の計算（EStateM。状態の表に対する計算やトランザクション）の性質をメソッドごとに積み上げるために、LangSemantics.Core.EStateHoare（Hoare 三つ組と合成の規則）と、状態を与えた形に簡約するタクティク estate_simp（LangSemantics.Core.EStateSimp）・java_estate_simp（LangSemantics.Java.EStateSimp）を assets に置く。Std.Do の mvcgen は使えるが、写しのメソッドを展開すると Assert などの細部が検証条件に混ざるので、経路ごとの計算の形を先に求める。
* [「オラクル」を「原典実行」（origin-run）と呼び替える](decision/288a-rename-oracle-to-origin-run.md) - 移植元のプログラムを実行して期待値を採取・照合する手段を、DBMS の Oracle と紛れない「原典実行」（識別子 origin-run）と呼ぶ。新旧 2 版を比べるものは「差分の原典実行」とする。ベクタの source の値は <移植元>-origin-run、道具のディレクトリ・クラス名もこれにそろえる。
* [Java の式の構文 java! と Spring の Assert を言語パックに置き、移植元のモデルを原典と同じ字面で書く](decision/1f75-java-expression-syntax-and-spring-assert.md) - 移植元のモデルの式を、原典の Java の式と同じ字面で書けるよう、LangSemantics.Java に式の構文 java!（JLS の優先順位・数値昇格・リテラルの型・キャスト・短絡評価・例外を投げうる式）を置く。展開した項は原始関数を手で書いた項と構文として同じで、証明は変えない。あわせて Spring の Assert を同じ名前で置き、原典の語彙とモデルの語彙の対応表を言語パックに書く。
* [移植元のモデルを原典のソースツリーの形に並べ、対応を TR-M で検査し、対照表を trace review で生成する](decision/8a3c-mirror-layout-check-and-review-view.md) - 移植元のモデルのモジュールを原典のクラスと 1 対 1 にする規則を言語パックに置き、プロジェクトの設定 source.mirror で有効にする。配置・名前・引数・欄の対応を trace check の TR-M で検査し、原典とモデルを並べた静的な HTML を trace review で生成する。trace-dump は宣言の引数・欄・行の範囲を出力する。
* [スキル spec-pivot の Lean パッケージを assets/lean/ に置く](decision/6edf-lean-package-under-skill-assets-lean.md) - スキル spec-pivot の assets 直下にあった Lake パッケージ langSemantics（LangSemantics・Machine とその検査）を assets/lean/ に移し、assets の下を資産の種類ごとに分ける。Lean 以外の資産（assets/verus/ など）は assets/lean/ の外に置く。
* [追跡の道具の未確定事項（本文ハッシュ・正規化・ロケータの細部・機能と backlog の対応）を決める](decision/0eea-trace-tooling-unresolved-details.md) - ATRS の ADR e2a4 と言語パックで未確定だった、本文ハッシュの方式、正規化での空白の扱い、private の呼び先の連結、ロケータとハッシュの区切り、seed:・tmpl:・xml:・http:・prop:/msg: の形、dep:/lang: の版の文字列、警告と誤りを決める機能と backlog の対応表（trace/features.json）、合格の記録が無い場合、TR-P の数え方を決める。
* [rehash・diff・impact の細部（検査の登録・注釈の書き換え・改名・出典の検査）を決める](decision/9cd9-rehash-diff-impact-details.md) - ATRS の ADR e2a4 の rehash・diff・impact について、検査の登録（trace/checks.json）とそれが覆う定義、rehash の対象と手順、Lean の注釈の書き換え方、renames.json の検査、diff の分類と impact の伝播、文書の「出典:」のロケータの検査を決める。ADR 0eea を補う。
* [移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う](decision/0b83-porting-conditions-and-workflow.md) - スキル spec-pivot に、移植が成り立つ条件（適用の前提 P1〜P6、成立の条件 S1〜S6、言えること・言えないこと）を明示する。AWS の AI-Driven Modernization（AI Modernization Flow）のプロセス面を参考に、評価・判断を記録する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録を、置き換えてよい既定の進め方として references/workflow.md に置く。
* [追跡属性の仕組み（Trace）をスキル spec-pivot の assets に移す](decision/7fe4-move-trace-attributes-to-skill.md) - lean/Trace（追跡属性・trace-dump・obligation-check の本体）はアプリに依存しないので、スキル spec-pivot の assets/lean/Trace に移し、Lake の依存として取り込む。道具の入口（main）は ATRS の lean/Tools に残す。
* [アプリに依存しない道具と Lean のライブラリをスキル spec-pivot へ移し、ATRS 固有の値を trace/project.json に集める](decision/edc8-skill-scripts-and-generic-lean-libraries.md) - tools/ の汎用の道具（追跡の CLI・Lean の静的検査・課題一覧との突き合わせ・上流の版の検査・突き合わせ表の検査・ID の道具）をスキルの scripts/ へ移し、ATRS 固有の値を trace/project.json から読ませる。Abstraction・Tests に混ざっていた汎用の Lean コードを、スキルの assets（Machine.Kernel・LangSemantics.Core（新設）・LangSemantics.Java/Sql・ConformanceKit（新設））へ移す。汎用の方法を文書でもスキルへ移し、スキルに紛れた ATRS 固有の記述を外す。
* [スキルの文書を references/docs/ の OKF バンドルにし、スキルの決定と作業項目をスキルで持つ](decision/87b9-skill-docs-as-okf-bundle.md) - スキル spec-pivot の references を references/docs/ に移して OKF v0.2 の Knowledge Bundle とし、スキル自身の意思決定記録と作業項目を references/docs/{decision,backlog} で管理する。適用先のプロジェクトとは ID の空間を共有し、外の項目は来歴としてだけ挙げる。
* [OKF バンドルとリンクの検査の道具 okf_check.py を置き、規則を設定のプロファイルで与える](decision/330e-okf-bundle-check-tool.md) - OKF v0.2 の適合条件（frontmatter・type・index.md・log.md）、バンドルの規則（種類ごとの type・必須キー・必須の節・意思決定記録と作業項目の形）、索引の網羅、Markdown の相対リンクと見出しアンカーを検査する道具を scripts/docs/okf_check.py に置く。標準ライブラリだけで動かすため、frontmatter は YAML の部分集合として読む。規則は trace/project.json の okf にバンドルごとのプロファイルとして書く。
* [スキルの assets の Lean の検査を名前空間 Test.<ライブラリ> にまとめる](decision/c08b-test-namespace-for-skill-asset-tests.md) - assets/lean の検査（LangSemanticsTest・MachineTest・ConformanceKitTest・TraceTest）を、トップレベルの Test の下の Test.LangSemantics・Test.Machine・Test.ConformanceKit・Test.Trace に移し、ディレクトリも Test/ にまとめる。Lake のライブラリは Test の 1 つにし、静的検査は Test を Tests の層として扱う。
* [Lean の宣言をモジュール名の下に置き、機能の証明課題を機能のモジュールに置く](decision/1a30-lean-module-namespace-layout.md) - Lean の宣言の完全名をモジュール名そのものかその下に限り（NS-1）、技術的な必要がある 4 つの例外（型の名前空間・main・明示した例外・型名のモジュールのインスタンス）だけを認める。R・W・C 課題と付帯の義務は機能の名前空間のモジュールに、補題は下位のモジュールに置く（TR-L）。検査の道具 layout-check と改名の道具 rename.py を置く。
* [スキルの文書を spec/・rules/・guide/・lang/ に分け、移動の道具 docmv.py を置く](decision/748c-skill-docs-category-directories.md) - references/docs の方法の文書（平置きの 11 本）を、規範の spec/、書き方の規約の rules/、手順と進め方の guide/ に分け、言語パックを lang/<lang>/ に移す。type は spec を Specification、rules を Guideline、guide を Guide、lang を Reference とする。移動とリンクの張り直しには、新しい道具 scripts/docs/docmv.py を使う。
* [義務の束 Machine.Adequate、機械の並置によるトップレベルの主定理、側ごとの段階導入](decision/ab9e-adequate-bundle-sum-and-side-staging.md) - R 課題ごとに、Refines と空虚化を防ぐ義務を Machine.Adequate に束ね、同じ課題 ID の @[obligation] で示す（GA・OB-A）。機能の機械を Machine.sum で並置し、トップレベルの Refines・Adequate を Abstraction.lean・Refinement.lean に置く。追跡の検査の段階導入を、指摘の側（移植元・移植先）の作業項目で判定する。
* [adequate の廃止: A abstracts B = A preserves B ∧ B refines A](decision/6b4b-preserves-refines-abstracts.md) - 義務の束 Machine.Adequate を廃止し、B メソッドのリファインメント Machine.Refines（B refines A）と、R 課題の空虚化を防ぐ意味的な義務のすべてを束ねた Machine.Preserves（A preserves B。Refines を含まない）に分ける。両者の組を Machine.Abstracts（A abstracts B）とする。G6 は束の ch・outs を照合し、GA を GP、OB-A を OB-P に改める。並置と側ごとの段階導入は ADR ab9e から引き継ぐ。
* [この方法を Spec Pivot と名付け、スキルの名前を spec-pivot に改める](decision/cfad-name-the-method-spec-pivot.md) - Lean の正規仕様 Spec を軸に、移植元と移植先を両側からリファインメントで結ぶこの方法を Spec Pivot と名付ける。スキルの識別子（ディレクトリ名と frontmatter の name）を port-lang から spec-pivot に改める。
* [スキルの Python の道具を uv で実行する](decision/8cb7-run-python-tools-with-uv.md) - scripts/ と assets/lean の Python の道具（標準ライブラリだけ）を、システムの python3 でなく uv run python -I で実行する。スキルのシェルの道具（pg_table.sh）もそう呼び、文書の使い方もそう書く。タスクの実行器（mise など）は適用先が選び、スキルは求めない。

# Backlog

* [スキルの作業項目](backlog/README.md) - スキル spec-pivot の作業項目の索引。状態と依存関係。
* [Machine: 抽象機械と B メソッドのリファインメントの枠組み](backlog/1ae4-machine-refinement-framework.md) - アプリに依存しない Lean ライブラリ Machine（抽象機械、Refines、証明義務 INIT・適用可能性・正しさ、差異の仮定・成分）をスキルの assets/lean/Machine/ に実装する。
* [LangSemantics.Rust: Rust の意味論](backlog/a936-lang-semantics-rust.md) - 固定長整数（検査付き・折り返し）、char、UTF-8 String、Vec、Result、パニックを、アプリ非依存の検証可能なモデルとして Lean に定義する。
* [スキルの文書を OKF バンドルにし、スキルの決定と作業項目を移す](backlog/de90-skill-docs-okf-bundle-and-records.md) - references を references/docs/ の OKF v0.2 のバンドルにし、decision/・backlog/ を設けて、適用先にあったスキルの記録を移す。ID の道具を複数の置き場所と持ち出せることの検査に対応させる。
* [OKF バンドルとリンクの検査の道具](backlog/a49c-okf-bundle-check-tool.md) - OKF v0.2 の適合条件、バンドルのプロファイルの規則、索引の網羅、Markdown の相対リンクと見出しアンカーを検査する道具 scripts/docs/okf_check.py を作り、このバンドルの規則をプロファイルにする。
* [Lean の宣言をモジュール名の下に置く規則と検査](backlog/ce23-lean-module-namespace-layout.md) - 宣言の完全名をモジュール名の下に限る規則（NS-1）と証明課題の配置（TR-L）を定め、検査の道具 layout-check・TR-L・改名の道具 rename.py を作り、スキルの assets の宣言を書き換える。
* [スキルの文書を spec/・rules/・guide/・lang/ に分ける](backlog/97a7-skill-docs-category-directories.md) - references/docs の方法の文書を spec/・rules/・guide/ に、言語パックを lang/<lang>/ に移し、type・プロファイル・索引を改める。移動とリンクの張り直しの道具 scripts/docs/docmv.py を作る。
* [スキルの Lean のデータ型を、不正な状態を表現できない型にする](backlog/d3fd-misu-skill-types.md) - ADR bf1b に従い、Trace（ギャップの登録簿・追跡属性・道具の内部の記録）、Machine（Preserves の条件付きの成分）、LangSemantics・ConformanceKit（値の型）の妥当性の条件を型に移す。
* [登録簿の R 課題と課題表の差異の列の一致を検査する](backlog/937d-rtasks-task-table-consistency-check.md) - trace check に、ギャップの登録簿の rTasks と、課題表（証明課題の一覧）の各 R 課題の「差異」の列とが一致することの検査を足す。
