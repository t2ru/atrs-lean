---
okf_version: "0.2"
---

# Rules

* [作業規約（rules）](rules/README.md) - 作業規約の索引と、規約・文書間の優先順位。
* [ATRS での port-lang スキルの適用](rules/atrs-porting.md) - 言語間移植の方法（スキル port-lang）を ATRS に適用するときの固有事項。言語ペア、リポジトリ配置、機能名、型、依存フレームワーク、追従中の上流、ATRS で採った値。
* [バックログ規約](rules/backlog.md) - バックログ項目の形式・状態・完了の定義。
* [意思決定記録（ADR）規約](rules/decision-records.md) - ADR（MADR 4.0 + OKF frontmatter）の命名・状態・テンプレート・作成基準。
* [文書規約](rules/documentation.md) - 文書の言語・規範語・出典記法・リンク・OKF v0.2 準拠の規則。
* [バージョン管理規約](rules/version-control.md) - 一通りの作業が終わったら git commit する。push は自分で作ったブランチに限り、PR を作成してよい。コミットの単位とメッセージの規則。

# Decisions

* [意思決定を MADR 形式の ADR として記録する](decision/d845-record-architecture-decisions-with-madr.md) - 設計判断を MADR 4.0 形式の ADR として docs/decision/NNNN-<slug>.md に記録する。
* [移植スコープをドメイン・ユースケース・HTTP 契約とする](decision/84bf-porting-scope.md) - 移植対象をドメイン・ユースケース・HTTP 契約とし、Thymeleaf の HTML 等を対象外とする。
* [docs/spec を唯一の正規仕様とし、Lean を参照実装とする](decision/3b0a-spec-as-normative-source.md) - docs/spec を唯一の正規仕様、Lean を参照実装、Java 原典をオラクルとする。
* [移植元モデルと抽象モデルの二層で仕様を定義し、関係を証明する](decision/a43d-two-layer-model-java-faithful-and-abstract.md) - 移植元モデル [Source] と抽象モデル [Spec] を別々に定義し、両者の関係を証明課題とする。
* [移植元モデルの基本演算を、検証可能な整数エミュレーションとして定義する](decision/935b-java-primitive-semantics.md) - [Source] の int32・double・BigDecimal・UTF-16 を整数のみでエミュレート可能な名前付き演算として定義する。
* [抽象モデルの数値は任意精度整数と明示的な丸めで定義する](decision/e41d-exact-integer-arithmetic-in-abstract-model.md) - [Spec] の数値は任意精度整数とし、floorDiv/ceilDiv/ceilTo で丸めを明示する。
* [業務ロジックを純粋関数のコアとし、副作用をポート経由にする](decision/f0e4-functional-core-with-ports.md) - 業務ロジックは純粋関数、時刻・永続化・採番・ハッシュ・ファイル・キューはポートとして抽象化する。
* [エラーを値として返し、原典のメッセージキーを安定したエラーコードとする](decision/a4fa-errors-as-values-with-stable-codes.md) - 業務・入力・前提違反・システムの各エラーを直和型の値で返し、e.ar.b2.2001 等の原典キーをコードとして使う。
* [日付はタイムゾーン無しの暦日とし、今日の日付を入力として注入する](decision/6eb2-date-and-time-model.md) - 暦日・時刻・日時の表現、書式、日数差の定義、Clock ポートによる現在日時の注入を定める。
* [文字列長はスカラ値単位とし、文字クラスはコードポイント範囲で定義する](decision/10a5-text-length-and-character-classes.md) - [Spec] の文字列長は Unicode スカラ値数、[Source] は UTF-16 単位とし、全角・半角・カナ等をコードポイント範囲で定義する。
* [永続化をリポジトリ契約として仕様化し、ユースケース単位の原子性を要求する](decision/97f9-persistence-and-transaction-semantics.md) - SQL に埋め込まれた業務ロジック・採番・行ロック・トランザクション境界を、技術非依存のリポジトリ契約として定義する。
* [HTTP 契約を画面遷移の状態機械と REST JSON 形状として記述する](decision/1b00-http-contract-specification.md) - 画面遷移は URL・メソッド・パラメータ・遷移先の表、REST API は JSON 形状とステータスの表で、フレームワーク非依存に記述する。
* [言語中立な適合テストベクタを JSON で管理し、全実装の完了条件とする](decision/dc3a-conformance-test-vectors.md) - conformance/ 配下にモデル別の JSON テストベクタを置き、Lean・他言語実装がすべて通すことを移植完了の条件とする。
* [Lean 4 を lean-toolchain で固定し、依存は Batteries のみとする（Mathlib 不使用）](decision/659f-lean-toolchain-and-dependencies.md) - Lean 4 + Lake を使い、依存ライブラリを Batteries に限定して Mathlib を使わない。
* [パスワードのハッシュ化と照合を PasswordHasher ポートに抽象化する](decision/2d1f-password-hashing-port.md) - ドメインはハッシュ文字列を不透明値として扱い、{pbkdf2}/{bcrypt} 形式との互換はアダプタの責務とする。
* [予約履歴レポートの非同期生成をキューとストアのポートで表し、CSV をバイト単位で規定する](decision/ff4d-asynchronous-report-generation.md) - JMS とファイルシステムを ReportQueue/ReportStore ポートに抽象化し、CSV の書式・ファイル名・一覧順を厳密に定義する。
* [docs/ を OKF v0.2 の Knowledge Bundle とする](decision/a0f1-documentation-format-okf-v0-2.md) - docs/ 配下の全文書を Open Knowledge Format v0.2 に準拠させ、docs/index.md を文書インデックスとする。
* [トップレベル名前空間を LangSemantics.<lang> / SourceModel / Spec / Abstraction / TargetModel / Refinement に統一する](decision/3e1d-language-neutral-top-level-namespaces.md) - 言語意味論・移植元・抽象・移植先の各モデルと 2 種類の証明課題に、実装言語を固定しない共通のトップレベル名前空間を与える。
* [LangSemantics.Sql で原典 SQL（PostgreSQL）の意味論を定義し、SourceModel のリポジトリを記述する](decision/5fcb-sql-semantics-for-source-repositories.md) - 原典の MyBatis SQL に含まれる業務ロジックを、アプリ非依存の SQL 意味論モデル LangSemantics.Sql の上で忠実に写す。
* [移植先言語を Rust とし、具体化証明課題を Verus と Kani で充足する](decision/dd0f-rust-as-target-language.md) - TargetModel と Refinement を Rust で実装し、Verus で Spec の写しとの一致を証明、Kani で有界検査、適合テストベクタで Lean Spec との対応を裏付ける。
* [Lean の Spec を正規仕様とし、Spec で表現できない仕様だけを docs/spec で定義する](decision/61bc-lean-spec-as-normative-source.md) - 正規仕様の所在を Lean の Spec 名前空間に移し、docs/spec は Spec の外にある要件と文書メタ情報に限定する。ADR 3b0a を置き換える。
* [モデルと証明をすべて Lean に置き、移植元ソースと移植先ソースは両端で追跡する](decision/796c-models-in-lean-and-sources-traced-at-both-ends.md) - LangSemantics・SourceModel・Spec・Abstraction・TargetModel・Refinement を Lean に置き、Java 原典と Rust ソースはそれぞれのモデルとだけ追跡でつなぐ。ADR 3e1d・dd0f を置き換える。
* [移植元ソース⇔SourceModel と TargetModel⇔移植先ソースを、ロケータ・モデル側注釈・本文ハッシュで追跡する](decision/81ab-cross-language-traceability.md) - 両端のトレースをロケータとモデル側の注釈で表し、確認済みハッシュで陳腐化を検出し、manifest 生成と TR 検査で網羅性と直接接続の禁止を機械的に保つ。
* [移植元の版上げに追従する。SourceModel は最新版のみ保持し、差分オラクルで振る舞いの変化を検出する](decision/3f36-following-upstream-releases.md) - 上流を submodule で固定し、版上げ時はインベントリ差分と新旧 2 版の差分オラクルで影響を洗い出し、証明グラフに沿って各層を更新する。旧版は git タグで参照する。
* [言語間移植の方法をアプリ非依存のスキル port-lang に切り出し、docs/ には ATRS 固有の情報を残す](decision/f4e1-extract-porting-method-as-agent-skill.md) - Lean を介した言語間移植の方法を Agent Skills 形式のスキル .agents/skills/port-lang に移し、言語ごとの情報を役割に依存しない言語パックとして references/docs/<lang>/ に置く。
* [メールアドレスの検証規則は Hibernate Validator の規則を IDN 変換抜きで書き下す](decision/ac33-email-validation-rule.md) - 制約 Email を Hibernate Validator 9.1 の AbstractEmailValidator・DomainNameUtil の規則として言語中立に定義し、IDN.toASCII だけを除外して既知差異 D-011 とする。
* [入力検証エラーの並びは Spec でだけ定め、Source では順序不定の多重集合とする](decision/e24e-validation-error-ordering.md) - Bean Validation が順序を保証しないことを SourceModel に写し、Spec では単項目・相関・グローバルの順に並べる。抽象化では順序を無視して比較する。
* [本番の Clock は Asia/Tokyo で今日を決め、fixture の投入日は 2026-11-01 に固定する](decision/9ee4-clock-timezone-and-fixture-base-date.md) - Clock ポートの本番アダプタが使うタイムゾーンと、投入日に依存するシードデータ（ピーク時期・フライト）を fixture にするときの基準日を定める。
* [排他制御の失敗をエラー分類 Conflict として表す](decision/41f7-concurrency-failure-as-conflict-error.md) - デッドロック・ロック待ちのタイムアウト・直列化失敗のように実行環境が吸収できない同時実行の失敗を AtrsError.Conflict とし、状態を変えず、画面は 500、REST は 409 とする。
* [会員情報変更は現在パスワードの照合と更新を 1 つのトランザクションで行う](decision/578b-member-update-in-single-transaction.md) - 原典では別トランザクションである照合と更新を、Spec では 1 つの直列化可能なトランザクションにまとめ、差を既知差異 D-013 とする。
* [予約履歴レポートの要求キューは少なくとも 1 回配信し、再配信に上限を設ける](decision/90f5-report-queue-at-least-once-delivery.md) - レポート生成に失敗した要求を再配信し、上限を超えたら破棄してログに残す。重複配信で別の秒のレポートが 2 本できることを許す。
* [原典の安全でない振る舞いと前提違反は Spec では正し、既知差異として記録する](decision/e10f-spec-corrects-unsafe-source-behavior.md) - セッション固定化、オープンリダイレクト、ロケール依存の曜日、前提違反による 500、緩すぎる数値・日付の解析について、Spec は安全で決定的な振る舞いを定め、原典との差を D-016〜D-021 とする。
* [基本原則: 両端の決定論的な一致、B メソッドのリファインメント、差異の全明示](decision/c336-foundational-principles.md) - ソース⇔モデルの一致を決定論的な検証または変換で確認し、抽象モデルと移植元/先モデルの間に B メソッドのリファインメントを証明し、不一致を証明と文書の両方ですべて明示することを、全 ADR・規約・スキルの上位の原則とする。
* [抽象モデルと移植元/先モデルの関係を B メソッドのリファインメントとし、差異を名前付きの前提・観測成分として明示する](decision/01d4-b-method-refinement-and-explicit-deviations.md) - SourceModel と TargetModel がそれぞれ Spec を B メソッドの意味でリファインすることを、貼り合わせ不変条件と証明義務（初期化・適用可能性・正しさ）で証明する。差異は前提型・観測型・モデル外に分類し、D-NNN / T-NNN として文書と Lean の @[deviation] の両方に置く。ADR a43d を置き換える。
* [モデルと証明を Lean に置き、移植先の Verus の写しは TargetModel から決定論的に生成する](decision/0bd3-generate-verus-mirror-from-target-model.md) - ADR 796c の層構成・依存の向き・Rust の構成を引き継ぎ、Rust の model/ を Lean TargetModel から道具で生成して手書きを禁じ、Verus で Rust の実行コードとの一致を証明する。リファインメントの枠組み Machine を名前空間の例外に加える。ADR 796c を置き換える。
* [両端の追跡をロケータとモデル側注釈で表し、確認済みハッシュを決定論的な検査の合格記録とする](decision/e2a4-traceability-hash-as-deterministic-check-record.md) - ADR 81ab の追跡方式を引き継ぎ、確認済みハッシュの意味を人の確認から決定論的な検査の合格記録に改め、TR 検査の例外と恒久的な警告をなくし、差異の対応を検査する TR-D とテンプレートのロケータ tmpl: を加える。ADR 81ab を置き換える。
* [排他制御の失敗 Conflict を、Spec の状態変更操作の非決定的な結果とする](decision/e56e-conflict-as-spec-nondeterminism.md) - AtrsError.Conflict とポートの I/O の失敗を、Spec の状態変更操作が採番以外の状態を変えずに選びうる非決定的な結果として定め、活性の限界を明示する。実行可能な Spec の標準の選択はこれらを選ばない。画面は 500、REST は 409。ADR 41f7 を置き換える。
* [リファインメントが空虚・自明に成り立つことを防ぐ義務と検査を課す](decision/70eb-refinement-non-vacuity-obligations.md) - Machine.Refines は具体⊆抽象しか保証せず、緩い Spec・空の INV・強すぎる PRE・粗い貼り合わせ・名前付きの成分の乱用・非決定性による不具合の吸収でも成り立つ。これを、選択の像としての Spec（ofChoice・FreeFrame）、Sound と 1 点の初期状態、環境の固定（Pinned・NoFaultReachable）、標準の貼り合わせ（Glue.ofStd）、入口の全域性（TotalUnder・EnvWitness）、初期化の全射性、状態の安全性、成分の両向きの例、核の明示と、検査 TR-G・TR-N・TR-V・TR-PE で塞ぐ。ADR 01d4・e2a4・e56e に義務と検査を加える。
* [運賃計算の SourceModel の表し方（マスタのキャッシュ・列挙型・HashMap）と、共有ベクタの modelDef・共有入力を決める](decision/8f18-fare-source-model-and-shared-vectors.md) - 運賃計算の SourceModel で、マスタを Provider のキャッシュとして入力に受けること、Java の列挙型に Spec の型を使うこと、HashMap の最小のモデルを決める。共有ベクタの modelDef をモデルごとの配列にできること、共有入力 fixtures を上流のシードから生成すること、source-model の期待値を仕様の例の表から取ること、翌日着の便の暫定の扱いを決める。
* [空虚化を防ぐ義務を既存の研究に照らして補う（成分の必要性・変異テスト・意図から書く例）](decision/9ac6-vacuity-literature-necessity-and-mutation.md) - ADR 70eb の義務を、Event-B の証明義務・vacuity detection・IronSpec・mCoq・Dafny の proof dependencies などの研究と対応づける。その上で、名前付きの成分を外すと R 課題の命題が偽になること（成分の必要性。G9）を義務に加える。成分の広さには仕様の変異テストを、仕様の妥当性には意図から書く例を採る。
* [マスタ・設定・コードリストの読み込みの SourceModel と、[Spec] の修正（所要時間・空港コードの値域・問い合わせ）を決める](decision/c108-master-data-source-model-and-spec-fixes.md) - マスタの読み込みの SourceModel の写し方（列の型は処理系の範囲で写す、Mapper の結果の順列を選ぶ具体機械、MyBatis の対応、コードリスト、設定）と、Spec.Route の所要時間の削除、MD-8 の空港コードの値域、問い合わせの機械の拡張、表せない値の差異 D-027、PostgreSQL での差分実行の形を決める。
* [ADR と backlog の ID を UUID にし、ファイル名を ID の先頭 4 文字と slug にする](decision/f57e-uuid-ids-for-decisions-and-backlog.md) - ADR・backlog の ID を 4 桁の連番から UUID v4（小文字 16 進）に改め、ファイル名を <ID の先頭 4 文字>-<slug>.md とする。道具が読む箇所は ID 全体を、本文は先頭 4 文字を書く。既存の 78 件を採番し直し、旧番号との対応表を残す。ADR d845 のファイル名の部分を置き換える。
* [ABS-026 の証明の構成と、空港コード NOP の禁止・D-027 の範囲・LocalDate の通算日数の修正を決める](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) - R 課題 ABS-026 の証明に向けて、空港コード NOP を MD-8 で禁じること、D-027 の対象を具体側の入力全体に広げること、LangSemantics.Java の LocalDate の通算日数の変換を床除算で書き直すこと（負の年で JVM と食い違っていた）、補題の置き場所と、有限の範囲の検査にカーネルの評価（decide +kernel）を使うことを決める。
* [運賃計算の double の誤差を定理で確定し、D-001・D-002 の前提を正確な条件で書く](decision/e9bc-fare-double-analysis.md) - backlog bbcc の第 1 段として、[Source] の運賃計算の double の式と [Spec] の整数の式の差を、因子の表（カーネルの評価）と閉じた形の補題で確定する。D-001 は値域内に差異があり（ABS-007 は否定的に解決）、D-001・D-002 の前提を「100 で割り切れない、または因子が安全」の形に改める。あわせて ABS-006 を ABS-026 に含めて取り消し、Java オラクルとの一致の完了条件を backlog f18c に移し、bbcc を 3 段に分ける。
* [Spec とモデルのギャップの登録簿を Lean の属性に置き、文書の表を生成する](decision/cc24-gap-registry-as-lean-attributes.md) - 既知差異（前提型・観測型・モデル外）、Spec の PRE の外での振る舞い、未確定の差異を、ID ごとの Lean の宣言（@[gap_entry]、型 Trace.Gap）として登録し、これを正とする。差異の生じる Spec・SourceModel・TargetModel の定義に箇所の印 @[gap] を付ける。文書の表は trace-dump から生成し、検査は Markdown の解析をやめて JSON から行う。
* [[Spec] の非決定性の選択の型と、入口の環境の前提・シードの検査を決める](decision/cd33-spec-nondet-types-and-env-pre.md) - backlog 0fdf として、非決定性 N-001〜N-005 の選択の型（@[nondet]）の形、各機能の機械での組み合わせ方、入口の環境の前提（@[env_pre]）をマスタ・設定の妥当性に限ること、シードのマスタ・設定が前提を満たすことを生成したリテラルと真偽値の検査関数の定理で示すことを決める。
* [スキル port-lang の決定と作業項目をスキルのバンドルへ移し、ATRS からはリンクで参照する](decision/50f9-move-skill-records-to-skill-bundle.md) - スキル port-lang の文書が references/docs/ の OKF バンドルになり、スキル自身の意思決定記録・作業項目を持つようになったのに合わせ、ATRS の docs/ にあった純粋にスキルの記録（ADR 6 件・backlog 2 件）を移す。ID の道具は ATRS とスキルを 1 つの ID 空間で検査する。

# Specification

* [ATRS 仕様文書](spec/README.md) - docs/spec の役割（Spec 外の規範・メタ情報・草案）、正規性、対象版、文書の区分一覧。
* [抽象化証明課題（Abstraction）](spec/abstraction.md) - 移植元モデル SourceModel が抽象モデル Spec を B メソッドの意味でリファインすることの証明課題 ABS-NNN、貼り合わせ関係と抽象化関数、既知差異 D-NNN の一覧。
* [保証の限界](spec/assurance.md) - ソース⇔モデルの一致を確かめる決定論的な手段と、手段の届かない部分（保証の限界）・信頼の基盤を境界ごとにすべて列挙する。
* [認証（A0/A1/A2）](spec/authentication.md) - ログインの事前検査・資格情報の照合・ログイン状態の更新・ログアウト・セッションと権限。
* [設定パラメータ](spec/configuration.md) - 業務規則に影響する設定値とその既定値。純粋関数には Config として明示的に渡す。
* [適合テストベクタ（ATRS）](spec/conformance.md) - ATRS の適合テストベクタの機能区分・操作名・共有入力・ATRS 固有の前提。形式はスキル port-lang に従う。
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
* [具体化証明課題（Refinement）と移植先ソースの確認](spec/refinement.md) - TargetModel が Spec を B メソッドの意味でリファインすることの証明課題 REF-NNN、移植先の既知差異 T-NNN、TargetModel ⇔ Rust ソースを決定論的に確認する課題 SRC-NNN（写しの生成・Verus・Kani・適合テスト）。
* [予約履歴レポート（D1）](spec/reservation-history-report.md) - レポート作成要求の受付、非同期生成、CSV のバイト仕様、ファイル名、一覧と取得。
* [予約（B0/B2）](spec/reservation.md) - 選択フライトの検証、予約内容の検証、予約確認、空席の確保と予約登録、会員情報による入力補完。
* [追跡（トレーサビリティ）](spec/traceability.md) - ATRS の両端の追跡: 使うロケータ種別、運賃計算の追跡例と検査の判定、生成表、予定対応、対象外。方式はスキル port-lang に従う。

# Backlog

* [バックログ](backlog/README.md) - 作業項目の索引。状態と依存関係。
* [Lean プロジェクトの雛形と CI](backlog/be49-lean-project-scaffold.md) - lean/ に Lake プロジェクトを作り、全名前空間の骨格・追跡属性の基盤・依存方向検査を含む CI を整える。
* [LangSemantics.Java: Java 基本型の意味論](backlog/a8be-lang-semantics-java.md) - int32・IEEE 754 binary64（必要部分）・BigDecimal 丸め・UTF-16 文字列・LocalDate を、アプリ非依存の検証可能なモデルとして実装する。
* [Spec: ドメイン型・基本演算・マスタデータ](backlog/591d-abstract-domain-types-and-master-data.md) - Spec.Prim（floorDiv・暦日・書式・文字クラス）、エンティティ型、MasterData と不変条件、参照関数を実装する。
* [運賃計算（Spec と SourceModel）](backlog/25f7-fare-calculation-both-models.md) - 基本運賃・運賃・合計金額を Spec（厳密整数）と SourceModel（LangSemantics.Java）の両方で実装する。
* [運賃計算の抽象化証明](backlog/bbcc-fare-abstraction-proofs.md) - 運賃計算の抽象化証明課題（ABS-001〜005・007、W 課題 ABS-101・102・112）を Abstraction.Fare で証明する。3 段に分け、double の誤差を定理で確定し、基本運賃・運賃・合計金額の R 課題を証明した。
* [空席照会（B1）](backlog/0be7-flight-search-usecase.md) - 照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。
* [予約（B0/B2）](backlog/aedf-reservation-usecase.md) - validateFlightList・validateReservation・reserveConfirm・reserve を SourceModel と Spec で実装し、空席の不変条件を証明する。
* [会員（C1/C2）と入力検証](backlog/4e0e-member-usecases-and-input-validation.md) - 会員登録・変更と、全画面の入力検証（前処理・文字クラス・単項目・相関）を両モデルで実装する。
* [認証（A1/A2）](backlog/44f8-authentication-usecases.md) - ログインの事前検査・照合・状態更新、ログアウトを両モデルで実装する。
* [予約履歴レポート（D1）](backlog/ac71-reservation-history-report.md) - 要求・受信・生成・一覧・取得と CSV のバイト仕様を両モデルで実装する。
* [Rust: インメモリアダプタとシードデータ](backlog/4b0e-in-memory-adapters-and-seed-data.md) - Rust にポートのインメモリ実装を作り、シードデータの fixture を用意し、Kani と結合テストで契約を確認する。
* [適合テストベクタの生成と検査（Lean 側）](backlog/a8ef-conformance-vector-format-and-generator.md) - Lean Spec を実行して conformance/ の期待値を生成するツールと、スキーマ検査、Spec・SourceModel に対する実行器を作る。
* [Java オラクルハーネス](backlog/f18c-java-oracle-harness.md) - 原典の Java クラスを直接呼び出し、[Source] ベクタの期待値を採取するハーネスを作る。
* [Rust: HTTP 契約アダプタ](backlog/a89e-http-contract-adapter.md) - http-contract.md の画面遷移と REST API を Rust で実装し、SRC-006 を結合テストで確認する。
* [第二言語での移植試行](backlog/31da-second-language-portability-pilot.md) - （取りやめ）Rust を移植先に定めたため、Rust 移植そのものが試行を兼ねる。
* [LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論](backlog/c7e8-lang-semantics-sql.md) - 値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR、UPDATE の評価規則を実装する。
* [OKF バンドルとリンクの検査](backlog/ddbd-okf-bundle-lint.md) - docs/ が OKF v0.2 に適合し、相対リンクとアンカーが切れていないことを CI で検査する。
* [Rust プロジェクトの雛形、Verus と Kani の併用確認、CI](backlog/fb50-rust-project-scaffold.md) - rust/ に単一クレートの雛形を作り、Verus と Kani を同じコードに適用できるかを最初に確認し、追跡タグを含む CI を整える。
* [Rust: 運賃計算の移植先ソースと TargetModel の写し](backlog/ddb4-rust-spec-mirror-and-fare-core.md) - Lean TargetModel.Fare を Verus の model に写し、Rust の運賃計算を ensures 付きで実装・証明し、target-model ベクタを通す。
* [Rust: 空席照会・予約・会員・認証・レポートの移植先ソース](backlog/9c1b-rust-usecases-core.md) - 各機能の Rust 実装と TargetModel の Verus 写しを作り、Verus で一致を証明し、target-model ベクタを通す。
* [TargetModel と Refinement: 運賃計算](backlog/eff6-target-model-fare-and-refinement.md) - Lean に TargetModel.Fare（Rust の意味論で書く運賃計算）を書き、Refinement で Spec.Fare との一致を証明し、target-model ベクタを生成する。
* [TargetModel と Refinement: 空席照会・予約・会員・認証・レポート](backlog/26c5-target-model-usecases-and-refinement.md) - 残りの機能の TargetModel を書き、Refinement で Spec との一致と空席の不変条件を証明し、target-model ベクタを生成する。
* [追跡の道具（tools/trace）](backlog/ffdc-trace-tooling.md) - インベントリ生成・Lean ダンプの取り込み・manifest と表の生成・TR 検査・差分・影響分析を行う Rust 製の道具を作る。
* [上流の submodule 化と版の宣言](backlog/455f-upstream-submodule-and-inventory.md) - 上流 ATRS を git submodule として commit 固定で取り込み、trace/upstream.json と移植元インベントリを作る。
* [差分オラクル（新旧 2 版の振る舞い比較）](backlog/773f-differential-oracle.md) - Java オラクルハーネスを拡張し、source-model ベクタの全入力を新旧 2 版の上流で実行して出力の差分を取る。
* [Lean TargetModel から Verus の写しを生成する道具](backlog/d77c-verus-mirror-generator.md) - lake exe gen-verus で、Lean TargetModel の公開定義から rust/src/model/ の Verus spec 関数と追跡タグを決定論的に生成し、CI で再生成の差分が無いことを確認する。
* [Rust: DB・ファイル・時計のアダプタと TargetModel.Adapter](backlog/9c04-rust-external-adapters.md) - DB・ファイル・時計のアダプタを Rust で実装し、その振る舞いを TargetModel.Adapter（DB は LangSemantics.Sql の式）に写して REF-009 を証明し、SQL の差分実行（SRC-010）と結合テスト（SRC-005）で一致を確かめる。
* [リファインメントの空虚化を防ぐ義務と検査](backlog/f7b7-refinement-non-vacuity.md) - Machine.Adequacy（ofChoice・FreeFrame・InitIs・Pinned・NoFaultReachable・Glue.ofStd・TotalUnder・EnvWitness・InitSurj・StateSafe・Nontrivial・KernelIs・complete・run）、その反例、追跡属性 @[nondet]・@[std_abs]・@[kernel]・@[env_pre]、検査 obligation-check と check_obligations.py、文書の登録簿を整える。
* [Spec の非決定性の選択の型と入口の環境の前提](backlog/0fdf-spec-nondet-and-entry-env.md) - Spec の非決定性 N-001〜N-005 の選択の型（@[nondet]）と、入口の環境の前提（マスタ・設定の妥当性。@[env_pre]）を Lean に定義し、両向きの例とシードの妥当性を示す。入力の値域の前提は各機能の backlog で置く。
* [名前付きの成分の必要性の義務と検査（G9）](backlog/ae04-component-necessity-witness.md) - ADR 9ac6 の成分の必要性（成分を外した R 課題の命題が偽であること）を、Machine.Adequacy の補題（always・not_of_error・not_of_mismatch・Pinned.not_of_mismatch・TotalUnder.not_always）、反例、obligation-check の G9、文書の W 課題・SPEC-006・保証の限界に反映する。
* [名前付きの成分の変異テスト](backlog/0d1a-mutation-testing-of-named-components.md) - ADR 9ac6 の B。@[deviation]・@[env_pre]・FreeFrame の射影を仕様を強める向きに変異させて R 課題を作り直し、生き残った変異体（成分が必要以上に広い兆候）を処置の記録と突き合わせる道具を作る。
* [追跡属性をスキルへ移し、ギャップを Lean の属性で表す](backlog/114a-gap-attributes-and-trace-in-skill.md) - lean/Trace をスキル port-lang の assets/lean/Trace に移す。Spec と SourceModel のギャップ（既知差異・PRE の外・未確定）を @[gap_entry]（型 Trace.Gap）で登録し、箇所の印 @[gap] を付け、文書の表を生成し、検査を JSON から行う。
* [アプリに依存しない道具・Lean のライブラリ・方法をスキルへ移す](backlog/38fb-move-generic-elements-to-skill.md) - tools/ の汎用の道具をスキルの scripts/ へ、Abstraction・Tests の汎用の Lean コードをスキルの assets へ移し、ATRS 固有の値を trace/project.json に集める。汎用の方法を文書でもスキルへ移し、スキルに紛れた ATRS 固有の記述を外す。

# Skill

* [スキル port-lang の文書の索引](../.agents/skills/port-lang/references/docs/index.md) - スキル port-lang の OKF バンドル（方法の文書・言語パック・スキル自身の意思決定記録と作業項目）。ATRS の外のバンドルで、ATRS の文書からはリンクで参照する。

# Log

* [更新履歴](log.md) - docs/ の変更履歴（新しい順）。
