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

* [仕様文書の書き方](rules/spec-documents.md) - Spec で表現できない仕様を書く Markdown の仕様文書の区分・節構成・差異の表と、道具が読む見出しと値。
* [スキルの文書の保守](rules/maintenance.md) - references/docs（OKF v0.2 のバンドル）の形式とその検査、意思決定記録と作業項目の書き方、ID の道具、持ち出せることの検査、適用先との分担。

# Guide

* [移植の手順](guide/process.md) - 機能単位で進める移植の手順 1〜10 と、各手順の成果物・次へ進む条件・完了の定義。
* [作業の進め方（既定）](guide/workflow.md) - 人と AI エージェントがこの方法で移植を進めるときの既定の進め方: 評価・判断の記録・検査ゲート・敵対的レビュー。
* [版上げへの追従](guide/upgrade.md) - 移植元の版上げへの追従: 最新版だけの SourceModel、インベントリの差分、差分オラクル、証明のグラフに沿った影響の洗い出し。
* [言語パックの構成と追加のしかた](guide/adding-a-language.md) - 言語パックの 6 ファイルの構成と、新しい言語・SQL 方言を追加するときの手順。

# Language: Java

* [Java: LangSemantics.Java](lang/java/semantics.md) - Java の基本型を整数演算だけでエミュレートする LangSemantics.Java の名前付き演算と、処理系との突き合わせ。
* [Java: フレームワーク・ランタイムの効果](lang/java/frameworks.md) - Java のフレームワーク・ランタイムが与える効果と、モデルへの写し方・dep: ロケータ。
* [Java: ソースの構成と Lean 名前空間の対応](lang/java/layout.md) - Java のソースの構成と、Lean の名前空間の対応。
* [Java: ロケータとインベントリ](lang/java/locators.md) - Java のロケータの文法とインベントリの作り方。
* [Java: ベクタの実行（オラクル／照合）](lang/java/harness.md) - Java のコードに適合テストベクタを当てるハーネス（オラクル／照合）の作り方。
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
* [Rust: ベクタの実行（照合／オラクル）](lang/rust/harness.md) - Rust のコードに適合テストベクタを当てるテスト（照合／オラクル）の作り方。
* [Rust: 検証器（Verus・Kani）](lang/rust/verification.md) - Rust のソースとモデルの一致を確かめる検証器（Verus・Kani）と、その保証の限界。

# Language: Lean

* [Lean プロジェクトの規約](lang/lean/rules.md) - 形式化言語 Lean 4 のプロジェクトの規約: ツールチェーン、依存、禁止する構文、名前、静的検査。
* [Lean の追跡属性と trace-dump](lang/lean/trace-attributes.md) - Lean の追跡属性・ギャップの登録簿と、trace-dump・obligation-check の実装。

# Decisions

* [スキルの意思決定記録](decision/README.md) - スキル spec-pivot の意思決定記録（MADR 4.0）の索引。
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

# Backlog

* [スキルの作業項目](backlog/README.md) - スキル spec-pivot の作業項目の索引。状態と依存関係。
* [Machine: 抽象機械と B メソッドのリファインメントの枠組み](backlog/1ae4-machine-refinement-framework.md) - アプリに依存しない Lean ライブラリ Machine（抽象機械、Refines、証明義務 INIT・適用可能性・正しさ、差異の仮定・成分）をスキルの assets/lean/Machine/ に実装する。
* [LangSemantics.Rust: Rust の意味論](backlog/a936-lang-semantics-rust.md) - 固定長整数（検査付き・折り返し）、char、UTF-8 String、Vec、Result、パニックを、アプリ非依存の検証可能なモデルとして Lean に定義する。
* [スキルの文書を OKF バンドルにし、スキルの決定と作業項目を移す](backlog/de90-skill-docs-okf-bundle-and-records.md) - references を references/docs/ の OKF v0.2 のバンドルにし、decision/・backlog/ を設けて、適用先にあったスキルの記録を移す。ID の道具を複数の置き場所と持ち出せることの検査に対応させる。
* [OKF バンドルとリンクの検査の道具](backlog/a49c-okf-bundle-check-tool.md) - OKF v0.2 の適合条件、バンドルのプロファイルの規則、索引の網羅、Markdown の相対リンクと見出しアンカーを検査する道具 scripts/docs/okf_check.py を作り、このバンドルの規則をプロファイルにする。
* [Lean の宣言をモジュール名の下に置く規則と検査](backlog/ce23-lean-module-namespace-layout.md) - 宣言の完全名をモジュール名の下に限る規則（NS-1）と証明課題の配置（TR-L）を定め、検査の道具 layout-check・TR-L・改名の道具 rename.py を作り、スキルの assets の宣言を書き換える。
* [スキルの文書を spec/・rules/・guide/・lang/ に分ける](backlog/97a7-skill-docs-category-directories.md) - references/docs の方法の文書を spec/・rules/・guide/ に、言語パックを lang/<lang>/ に移し、type・プロファイル・索引を改める。移動とリンクの張り直しの道具 scripts/docs/docmv.py を作る。
