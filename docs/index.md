---
okf_version: "0.2"
---

# Rules

* [作業規約（rules）](rules/README.md) - 作業規約の索引と、規約・文書間の優先順位。
* [バックログ規約](rules/backlog.md) - バックログ項目の形式・状態・完了の定義。
* [意思決定記録（ADR）規約](rules/decision-records.md) - ADR（MADR 4.0 + OKF frontmatter）の命名・状態・テンプレート・作成基準。
* [文書規約](rules/documentation.md) - 文書の言語・規範語・出典記法・リンク・OKF v0.2 準拠の規則。
* [Lean 規約](rules/lean.md) - Lean プロジェクトの名前空間構成・全域性・型選択・命名・証明方針。
* [言語中立性（portability）規約](rules/portability.md) - 他言語へ同一ロジックを移植するための数値・文字列・日付・順序・副作用の制約。
* [移植規約](rules/porting.md) - 原典 → 草案 → Lean の SourceModel/Spec → Abstraction → テストベクタ生成 → Rust の target_model と refinement の順で移植する原則。
* [Rust 規約](rules/rust.md) - Rust プロジェクトの構成、Lean Spec を Verus に写す規則、target_model の書き方、Verus・Kani・適合テストによる検証の規約。
* [仕様執筆規約](rules/spec-writing.md) - docs/spec の書き方。規範・メタ情報・草案の区分、[Spec]/[Source] 併記、定義の節構成、記法、禁止事項。
* [テスト規約](rules/testing.md) - 適合テストベクタ・性質テスト・証明・Java オラクルによる検証規約。
* [バージョン管理規約](rules/version-control.md) - 一通りの作業が終わったら git commit する。push はしない。コミットの単位とメッセージの規則。

# Decisions

* [意思決定を MADR 形式の ADR として記録する](decision/0001-record-architecture-decisions-with-madr.md) - 設計判断を MADR 4.0 形式の ADR として docs/decision/NNNN-<slug>.md に記録する。
* [移植スコープをドメイン・ユースケース・HTTP 契約とする](decision/0002-porting-scope.md) - 移植対象をドメイン・ユースケース・HTTP 契約とし、Thymeleaf の HTML 等を対象外とする。
* [docs/spec を唯一の正規仕様とし、Lean を参照実装とする](decision/0003-spec-as-normative-source.md) - docs/spec を唯一の正規仕様、Lean を参照実装、Java 原典をオラクルとする。
* [移植元モデルと抽象モデルの二層で仕様を定義し、関係を証明する](decision/0004-two-layer-model-java-faithful-and-abstract.md) - 移植元モデル [Source] と抽象モデル [Spec] を別々に定義し、両者の関係を証明課題とする。
* [移植元モデルの基本演算を、検証可能な整数エミュレーションとして定義する](decision/0005-java-primitive-semantics.md) - [Source] の int32・double・BigDecimal・UTF-16 を整数のみでエミュレート可能な名前付き演算として定義する。
* [抽象モデルの数値は任意精度整数と明示的な丸めで定義する](decision/0006-exact-integer-arithmetic-in-abstract-model.md) - [Spec] の数値は任意精度整数とし、floorDiv/ceilDiv/ceilTo で丸めを明示する。
* [業務ロジックを純粋関数のコアとし、副作用をポート経由にする](decision/0007-functional-core-with-ports.md) - 業務ロジックは純粋関数、時刻・永続化・採番・ハッシュ・ファイル・キューはポートとして抽象化する。
* [エラーを値として返し、原典のメッセージキーを安定したエラーコードとする](decision/0008-errors-as-values-with-stable-codes.md) - 業務・入力・前提違反・システムの各エラーを直和型の値で返し、e.ar.b2.2001 等の原典キーをコードとして使う。
* [日付はタイムゾーン無しの暦日とし、今日の日付を入力として注入する](decision/0009-date-and-time-model.md) - 暦日・時刻・日時の表現、書式、日数差の定義、Clock ポートによる現在日時の注入を定める。
* [文字列長はスカラ値単位とし、文字クラスはコードポイント範囲で定義する](decision/0010-text-length-and-character-classes.md) - [Spec] の文字列長は Unicode スカラ値数、[Source] は UTF-16 単位とし、全角・半角・カナ等をコードポイント範囲で定義する。
* [永続化をリポジトリ契約として仕様化し、ユースケース単位の原子性を要求する](decision/0011-persistence-and-transaction-semantics.md) - SQL に埋め込まれた業務ロジック・採番・行ロック・トランザクション境界を、技術非依存のリポジトリ契約として定義する。
* [HTTP 契約を画面遷移の状態機械と REST JSON 形状として記述する](decision/0012-http-contract-specification.md) - 画面遷移は URL・メソッド・パラメータ・遷移先の表、REST API は JSON 形状とステータスの表で、フレームワーク非依存に記述する。
* [言語中立な適合テストベクタを JSON で管理し、全実装の完了条件とする](decision/0013-conformance-test-vectors.md) - conformance/ 配下にモデル別の JSON テストベクタを置き、Lean・他言語実装がすべて通すことを移植完了の条件とする。
* [Lean 4 を lean-toolchain で固定し、依存は Batteries のみとする（Mathlib 不使用）](decision/0014-lean-toolchain-and-dependencies.md) - Lean 4 + Lake を使い、依存ライブラリを Batteries に限定して Mathlib を使わない。
* [パスワードのハッシュ化と照合を PasswordHasher ポートに抽象化する](decision/0015-password-hashing-port.md) - ドメインはハッシュ文字列を不透明値として扱い、{pbkdf2}/{bcrypt} 形式との互換はアダプタの責務とする。
* [予約履歴レポートの非同期生成をキューとストアのポートで表し、CSV をバイト単位で規定する](decision/0016-asynchronous-report-generation.md) - JMS とファイルシステムを ReportQueue/ReportStore ポートに抽象化し、CSV の書式・ファイル名・一覧順を厳密に定義する。
* [docs/ を OKF v0.2 の Knowledge Bundle とする](decision/0017-documentation-format-okf-v0-2.md) - docs/ 配下の全文書を Open Knowledge Format v0.2 に準拠させ、docs/index.md を文書インデックスとする。
* [トップレベル名前空間を LangSemantics.<lang> / SourceModel / Spec / Abstraction / TargetModel / Refinement に統一する](decision/0018-language-neutral-top-level-namespaces.md) - 言語意味論・移植元・抽象・移植先の各モデルと 2 種類の証明課題に、実装言語を固定しない共通のトップレベル名前空間を与える。
* [LangSemantics.Sql で原典 SQL（PostgreSQL）の意味論を定義し、SourceModel のリポジトリを記述する](decision/0019-sql-semantics-for-source-repositories.md) - 原典の MyBatis SQL に含まれる業務ロジックを、アプリ非依存の SQL 意味論モデル LangSemantics.Sql の上で忠実に写す。
* [移植先言語を Rust とし、具体化証明課題を Verus と Kani で充足する](decision/0020-rust-as-target-language.md) - TargetModel と Refinement を Rust で実装し、Verus で Spec の写しとの一致を証明、Kani で有界検査、適合テストベクタで Lean Spec との対応を裏付ける。
* [Lean の Spec を正規仕様とし、Spec で表現できない仕様だけを docs/spec で定義する](decision/0021-lean-spec-as-normative-source.md) - 正規仕様の所在を Lean の Spec 名前空間に移し、docs/spec は Spec の外にある要件と文書メタ情報に限定する。ADR 0003 を置き換える。

# Specification

* [ATRS 仕様文書](spec/README.md) - docs/spec の役割（Spec 外の規範・メタ情報・草案）、正規性、対象版、文書の区分一覧。
* [抽象化証明課題（Abstraction）](spec/abstraction.md) - 移植元モデル SourceModel から抽象モデル Spec への抽象化関数、既知差異 D-NNN、証明課題 ABS-NNN の一覧。
* [認証（A0/A1/A2）](spec/authentication.md) - ログインの事前検査・資格情報の照合・ログイン状態の更新・ログアウト・セッションと権限。
* [設定パラメータ](spec/configuration.md) - 業務規則に影響する設定値とその既定値。純粋関数には Config として明示的に渡す。
* [適合テストベクタ](spec/conformance.md) - conformance/ に置く言語中立の JSON テストベクタのディレクトリ構成・スキーマ・操作名・期待値の書き方。
* [ドメインモデル](spec/domain-model.md) - 型・列挙・値域・不変条件と、仕様全体で使う基本演算（除算・丸め・暦日・書式）の定義。
* [エラーとメッセージ](spec/errors-and-messages.md) - エラーの分類、エラーコード一覧、日本語メッセージ文言、項目の表示名、引数置換規則。
* [運賃計算](spec/fare-calculation.md) - 基本運賃・運賃（大人 1 名）・合計金額（大人・小児、往復）の計算と 100 円単位の切上げ。[Spec] は厳密整数、[Source] は Java の double/int32 意味論。
* [空席照会（B1）](spec/flight-search.md) - 搭乗日・区間・搭乗クラス・フライト種別から、予約可能な運賃種別ごとの空席数と運賃を出発時刻順に返す。
* [用語集](spec/glossary.md) - ATRS の業務用語と識別子の日英対応表。
* [HTTP 契約](spec/http-contract.md) - 画面遷移（URL・メソッド・判別パラメータ・遷移先・エラー画面）、認証と権限、二重送信防止、REST API の JSON 形状とステータス。
* [入力検証](spec/input-validation.md) - 前処理（空白除去）、文字クラス、単項目検証、相関検証、エラーの並び順を画面・API ごとに定義する。
* [マスタデータ](spec/master-data.md) - 空港・区間・便マスタ・搭乗クラス・運賃種別・ピーク時期・機材・カード種別の構造、不変条件、参照関数、シードデータ。
* [会員（C0/C1/C2）](spec/member.md) - 会員登録・会員情報変更・現在パスワード照合・入力値と会員エンティティの相互変換。
* [ポート](spec/ports.md) - 副作用（時刻・永続化・採番・パスワード・レポート保存・キュー）の契約。Spec はこれらの契約だけに依存し、実装は TargetModel が提供する。
* [具体化証明課題（Refinement）](spec/refinement.md) - 正規仕様 Lean Spec から Rust の移植先モデル target_model への具体化で満たすべき課題 REF-NNN と、Verus・Kani・適合テストによる充足方法。
* [予約履歴レポート（D1）](spec/reservation-history-report.md) - レポート作成要求の受付、非同期生成、CSV のバイト仕様、ファイル名、一覧と取得。
* [予約（B0/B2）](spec/reservation.md) - 選択フライトの検証、予約内容の検証、予約確認、空席の確保と予約登録、会員情報による入力補完。
* [追跡表](spec/traceability.md) - 原典の Java クラス・SQL 文と、仕様の節、Lean の名前空間（SourceModel / Spec）、Rust のモジュールの対応表。

# Backlog

* [バックログ](backlog/README.md) - 作業項目の索引。状態と依存関係。
* [Lean プロジェクトの雛形と CI](backlog/0001-lean-project-scaffold.md) - lean/ に Lake プロジェクトを作り、名前空間の骨格・依存方向検査を含む CI を整える。
* [LangSemantics.Java: Java 基本型の意味論](backlog/0002-lang-semantics-java.md) - int32・IEEE 754 binary64（必要部分）・BigDecimal 丸め・UTF-16 文字列・LocalDate を、アプリ非依存の検証可能なモデルとして実装する。
* [Spec: ドメイン型・基本演算・マスタデータ](backlog/0003-abstract-domain-types-and-master-data.md) - Spec.Prim（floorDiv・暦日・書式・文字クラス）、エンティティ型、MasterData と不変条件、参照関数を実装する。
* [運賃計算（Spec と SourceModel）](backlog/0004-fare-calculation-both-models.md) - 基本運賃・運賃・合計金額を Spec（厳密整数）と SourceModel（LangSemantics.Java）の両方で実装する。
* [運賃計算の抽象化証明](backlog/0005-fare-abstraction-proofs.md) - ABS-001〜ABS-006 を Abstraction.Fare で証明し、成り立たない場合は反例と前提を abstraction.md に記録する。
* [空席照会（B1）](backlog/0006-flight-search-usecase.md) - 照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。
* [予約（B0/B2）](backlog/0007-reservation-usecase.md) - validateFlightList・validateReservation・reserveConfirm・reserve を両モデルで実装し、空席の不変条件を証明する。
* [会員（C1/C2）と入力検証](backlog/0008-member-usecases-and-input-validation.md) - 会員登録・変更と、全画面の入力検証（前処理・文字クラス・単項目・相関）を両モデルで実装する。
* [認証（A1/A2）](backlog/0009-authentication-usecases.md) - ログインの事前検査・照合・状態更新、ログアウトを両モデルで実装する。
* [予約履歴レポート（D1）](backlog/0010-reservation-history-report.md) - 要求・受信・生成・一覧・取得と CSV のバイト仕様を両モデルで実装する。
* [Rust: インメモリアダプタとシードデータ](backlog/0011-in-memory-adapters-and-seed-data.md) - Rust の target_model::adapter にポートのインメモリ実装を作り、シードデータの fixture を用意して Kani で契約を検査する。
* [適合テストベクタの生成と検査（Lean 側）](backlog/0012-conformance-vector-format-and-generator.md) - Lean Spec を実行して conformance/ の期待値を生成するツールと、スキーマ検査、Spec・SourceModel に対する実行器を作る。
* [Java オラクルハーネス](backlog/0013-java-oracle-harness.md) - 原典の Java クラスを直接呼び出し、[Source] ベクタの期待値を採取するハーネスを作る。
* [Rust: HTTP 契約アダプタ](backlog/0014-http-contract-adapter.md) - http-contract.md の画面遷移と REST API を Rust の target_model::adapter で実装し、REF-006 を結合テストで検証する。
* [第二言語での移植試行](backlog/0015-second-language-portability-pilot.md) - （取りやめ）Rust を移植先に定めたため、Rust 移植そのものが試行を兼ねる。
* [LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論](backlog/0016-lang-semantics-sql.md) - 値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR、UPDATE の評価規則を実装する。
* [OKF バンドルとリンクの検査](backlog/0017-okf-bundle-lint.md) - docs/ が OKF v0.2 に適合し、相対リンクとアンカーが切れていないことを CI で検査する。
* [Rust プロジェクトの雛形、Verus と Kani の併用確認、CI](backlog/0018-rust-project-scaffold.md) - rust/ に単一クレートの雛形を作り、Verus と Kani を同じコードに適用できるかを最初に確認し、CI を整える。
* [Rust: Spec の Verus 写しと運賃計算コア](backlog/0019-rust-spec-mirror-and-fare-core.md) - Lean Spec.Prim・Spec.Fare を Verus の spec に写し、target_model::core::fare を ensures 付きで実装・証明し、適合テストを通す。
* [Rust: 空席照会・予約・会員・認証・レポートのコア](backlog/0020-rust-usecases-core.md) - 各機能の純粋なコアと状態遷移を target_model::core に実装し、Verus で Spec の写しとの一致と空席の不変条件を証明する。

# Log

* [更新履歴](log.md) - docs/ の変更履歴（新しい順）。
