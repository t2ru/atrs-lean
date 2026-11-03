/-!
# HTTP 契約（`Spec.Http`）

> **区分: 草案と規範の混在。** 各画面・API の「リクエスト → 処理 → 結果」の表は **形式化前の草案（draft）** であり、Lean `Spec.Http` に形式化する。「共通」節（状態の受け渡し、二重送信防止トークン、CSRF、エラー画面の伝送、認証の伝送方式）と REST の伝送の約束事（HTTP Basic、セッション無し、日付の JSON 表現）は **規範（normative）** としてここで定義する（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。

記述方針は [ADR 1b00](../../docs/decision/1b00-http-contract-specification.md)。HTML の構造は定義しない。画面は「画面 ID ＋ 表示データ」として定義する。
リクエストは `(メソッド, パス, 判別パラメータ)` で識別する。判別パラメータは **名前の有無だけ** を見る（値は問わない。例 `?confirm`）。
-/

/-!
## 共通

### 状態の受け渡し

- サーバ側のセッションに保持するのは「ログイン中の会員」と「二重送信防止トークン」だけである。画面間のデータは hidden 項目・リダイレクトのクエリ・一度だけ表示するフラッシュ値で受け渡す。
- リダイレクト後に表示するフラッシュ値は次の 1 リクエストでのみ有効。

### セッション

**規範**（[`Spec.Authentication`](Authentication.lean#セッション) が参照する伝送方式）

| 項目 | [Spec] | [Source] |
| --- | --- | --- |
| 識別 | Cookie によるセッション ID。Cookie 名は定めない（原典は `JSESSIONID`） | 同左 |
| Cookie 属性 | `HttpOnly` を付ける。`Secure`・`SameSite` は配備環境で決める | `HttpOnly` のみ（`Secure` は無効、`SameSite` は付かない。モデル外の既知差異 [D-024](../../docs/spec/abstraction.md#既知差異)） |
| タイムアウト | 最後のリクエストから 30 分で失効 | Tomcat の既定 30 分（`web.xml` に指定無し） |
| ログイン時のセッション ID | **新しい ID に変える**（セッション固定化対策） | 変えない（モデル外の既知差異 [D-016](../../docs/spec/abstraction.md#既知差異)） |
| 同時ログイン | 制限しない | 同左 |
| ログアウト | セッションを破棄し、Cookie を削除する | 同左 |
| REST（`/api/v1/**`） | セッションを作らない | 同左 |

出典: `w/config/web/SpringSecurityConfig.java`（`sessionManagement`、`AtrsUsernamePasswordAuthenticationFilter` に `SessionAuthenticationStrategy` を設定していない）, `atrs-web/src/main/webapp/WEB-INF/web.xml`

### 二重送信防止（トランザクショントークン）

名前空間ごとに一度だけ有効な不透明トークンを発行・検証する。

| 種別 | 意味 |
| --- | --- |
| `BEGIN` | 新しいトークンを発行し画面に埋め込む |
| `IN` | 送られたトークンを検証して消費し、新しいトークンを発行する。不一致・消費済みなら **409 トークンエラー画面**（`e.ar.fw.0001`） |

名前空間: `ticket/reserve`（B2）, `member/register`（C1）, `HistoryReport/create`（D1）。会員情報変更（C2）はトークンを使わない。

### CSRF

`/api/v1/**` 以外の状態を変更するリクエスト（POST）は CSRF トークンを要する。不正なら 403 相当の CSRF エラー画面（`e.ar.fw.0002`）。

### エラー画面

| 原因 | ステータス | 画面 | メッセージ |
| --- | --- | --- | --- |
| トークン不正 | 409 | `common/error/token-error` | `e.ar.fw.0001` |
| CSRF 不正 | 403 | `common/error/csrf-error` | `e.ar.fw.0002` |
| `InvalidRequest`・不正な入力（改竄） | 400 | `common/error/badRequest-error` | `e.ar.fw.0003` |
| 権限不足 | 403 | `common/error/accessForbidden-error` | `e.ar.fw.0004` |
| 該当 URL 無し | 404 | `common/error/notFound-error` | `e.ar.fw.0005` |
| 画面で捕捉されない `Business`・`System`・`PreconditionViolation`、`Conflict`（[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md)） | 500 | `common/error/system-error` | `e.ar.fw.9999` |

### 認証と権限

| 項目 | 値 |
| --- | --- |
| ログイン処理 | `POST /auth/dologin`（`membershipNumber`, `password`） |
| ログアウト | `POST /auth/dologout` → セッション破棄 → `302 /` |
| 権限 `MEMBER` が必要 | `/member/update`, `/HistoryReport/**` |
| 未ログインで上記へアクセス | ログイン画面 `A1/loginForm` を表示（リダイレクトではなく同じ URL で表示） |
| ログイン成功（通常） | 302。遷移先は (1) パラメータ `redirectTo` に値があればそれ、(2) 無ければ保存されたリクエスト、(3) どちらも無ければ `/`。**[Spec]** `redirectTo` は `/` で始まり `//` で始まらない（アプリ内の）パスだけを受け付け、それ以外は無いものとして扱う。[Source] は絶対 URL もそのまま使う（オープンリダイレクト。既知差異 [D-017](../../docs/spec/abstraction.md#既知差異)） |
| ログイン成功（Ajax: `X-Requested-With: XMLHttpRequest`） | 200（本文無し） |
| ログイン失敗（通常） | `/auth/login?error` へ forward し、ログイン画面を `e.ar.a1.2001` 付きで表示（200。URL は `/auth/dologin` のまま） |
| ログイン失敗（Ajax） | 401 |
-/

/-!
## A0/A1: トップ・ログイン

| リクエスト | 処理 | 結果 |
| --- | --- | --- |
| `GET /` | — | 302 `/ticket/search?topForm` |
| `GET\|POST /auth/login` | — | 画面 `A1/loginForm`（直前のログイン失敗メッセージがあれば表示） |
| `GET /api/auth/status` | ログイン中か | ログイン中 200（本文無し）、未ログイン 404 |
| `GET /api/member/available?membershipNumber=n` | 前後の空白（U+0000–U+0020）を除去する。結果が空またはパラメータが無ければ 400（必須パラメータ欠落）。それ以外は `isMember(n)`。[Source] は、残りが U+3000 などの Unicode の空白だけなら 200 を返す（既知差異 [D-040](../../docs/spec/abstraction.md#既知差異)） | 存在 200、無し 404 |
-/

/-!
## B1: 空席照会

パス `/ticket/search`。

| リクエスト | 入力 | 処理 | 結果 |
| --- | --- | --- | --- |
| `GET ?topForm` | — | 照会条件の初期値・照会可能期間（[`Spec.FlightSearch`](FlightSearch.lean#照会画面の初期値)） | 画面 `A0/top` |
| `GET ?form` | — | 同上 | 画面 `B1/flightSearch`（初回照会不要） |
| `GET ?flightForm` | TicketSearchInput | 入力検証 | 画面 `B1/flightSearch`。エラー時はエラー表示（初回照会不要）。成功時は画面が `GET /api/flights` で結果を取得する |
| `GET ?redo` | TicketSearchInput, ReservationFlightInput（検証しない） | — | 画面 `B1/flightSearch`（前回の条件と選択を復元）。便名が存在しなくても、選択が空でもそのまま表示する。型変換に失敗した項目があれば 400 |
| `POST`（判別無し。画面の送信先は `?select`） | ReservationFlightInput | 1. 入力検証。`selectFlights*`・`flightType` のフィールドエラーは 400。その他のエラーは `?redo` 相当の画面にエラー表示。2. `validateFlightList`。`InvalidRequest` は 400、`Business` は `?redo` 相当の画面にメッセージ表示 | 302 `/ticket/reserve?form` ＋ クエリ（`flightType`, `selectFlightFormList[i].flightName`, `.fareTypeCd`, `.depDate`(yyyy/MM/dd), `.boardingClassCd`） |

### GET /api/flights（JSON）

| 項目 | 値 |
| --- | --- |
| クエリ | `flightType`, `depAirportCd`, `arrAirportCd`, `depDate`（yyyy/MM/dd）, `boardingClassCd` |
| 検証 | FlightSearchInput（[`Spec.InputValidation`](InputValidation.lean#空席照会b1)） |
| 200 | `[FlightVacantInfo]`（[`Spec.FlightSearch`](FlightSearch.lean#出力-flightvacantinfo)）。`fareTypes` は JSON オブジェクトでキー順を保つ |
| 400 | 入力検証エラー・`Business`。本文 `{"messages": [String]}`（解決済みの文言。並びは [`Spec.InputValidation`](InputValidation.lean#検証の順序とエラーの並び) の [Spec] の順。[Source] では順序不定（既知差異 [D-022](../../docs/spec/abstraction.md#既知差異)）） |
| 404 | `NotFound`（`e.ar.b1.2003`）。本文同上 |
-/

/-!
## B2: 予約

パス `/ticket/reserve`、トークン名前空間 `ticket/reserve`。

| リクエスト | トークン | 入力 | 処理 | 結果 |
| --- | --- | --- | --- | --- |
| `GET ?form` | — | ReservationFlightInput（検証しない） | 予約入力の初期値（[`Spec.UseCase.Reserve`](UseCase/Reserve.lean#会員情報による入力補完)）、フライト表示。選択が空ならフライト表示も空。**[Spec]** 便マスタに無い便名・空の便名・搭乗日や搭乗クラスの欠落は `InvalidRequest`（400）。[Source] は `NullPointerException` または `Assert` で 500（既知差異 [D-020](../../docs/spec/abstraction.md#既知差異)） | 画面 `B2/reserveForm` |
| `POST ?redo` | — | TicketReserveInput | フライト表示（`GET ?form` と同じ。[Source] の 500 も同じ。[D-020](../../docs/spec/abstraction.md#既知差異)） | 画面 `B2/reserveForm` |
| `POST ?confirm` | BEGIN | TicketReserveInput | 1. 入力検証: `selectFlights*`・`flightType` のフィールドエラーは 400、その他は `B2/reserveForm` にエラー表示。2. `validateFlightList`: 失敗はすべて 400（`Business` も改竄扱い）。3. `reserveConfirm`: `Business` は `B2/reserveForm` にメッセージ表示 | 画面 `B2/reserveConfirm`（合計金額、フライト表示、入力値を hidden で保持） |
| `POST`（判別無し） | IN | TicketReserveInput | 1. 入力検証: エラーはすべて 400。2. `validateFlightList`: 失敗は 400。3. `reserve`（[`Spec.UseCase.Reserve`](UseCase/Reserve.lean#予約確定reserve)） | 成功: フラッシュ `{reserveNo, paymentDate, totalFare}` で 302 `?complete`。`Business`: フラッシュ（メッセージ・フライト表示）で 302 `?fail` |
| `GET ?complete` | — | — | — | 画面 `B2/reserveComplete`（予約番号、`fmtYen(totalFare)` 円、支払期限 `fmtPaymentDate(paymentDate)`。[`Spec.Prim.Format`](Prim/Format.lean#書式)） |
| `GET ?fail` | — | — | — | 画面 `B2/reserveFail`（メッセージを HTML として表示、選択した **全** フライト（往路・復路）の表示） |
| `POST ?backToSearch` | — | ReservationFlightInput | 照会条件を復元（下記） | 302 `/ticket/search?redo` ＋ 照会条件と選択フライトのクエリ |

「照会へ戻る」の照会条件: 選択が空または往路の便マスタが無ければ 400。`flightType = (選択数 = 2 ? RT : OW)`（入力の `flightType` ではなく選択数から決める。[Source] は入力の `flightType` を使い、無ければ 400。選択フライトの項目の欠落は 500。既知差異 [D-020](../../docs/spec/abstraction.md#既知差異)）、出発/到着空港は往路の区間、`outwardDate` は往路の搭乗日、`homewardDate` は復路の搭乗日（片道なら空文字）、搭乗クラスは往路のもの。
-/

/-!
## C1: 会員登録

パス `/member/register`、トークン名前空間 `member/register`。

| リクエスト | トークン | 処理 | 結果 |
| --- | --- | --- | --- |
| `GET ?form` | — | 生年月日の範囲（`1900/01/01`〜今日）を表示 | 画面 `C1/memberRegisterForm` |
| `POST ?confirm` | BEGIN | 入力検証。エラーは入力画面に表示 | 画面 `C1/memberRegisterConfirm` |
| `POST ?redo` | — | — | 画面 `C1/memberRegisterForm` |
| `POST`（判別無し） | IN | 入力検証（エラーは 400）→ `register` | フラッシュ（会員番号）で 302 `?complete` |
| `GET ?complete` | — | — | 画面 `C1/memberRegisterComplete`（会員番号） |
-/

/-!
## C2: 会員情報変更

パス `/member/update`、権限 `MEMBER`、トークン無し。

| リクエスト | 処理 | 結果 |
| --- | --- | --- |
| `GET ?form` | ログイン中の会員を `toMemberUpdateInput`（[`Spec.Member`](Member.lean)） | 画面 `C2/memberUpdateForm` |
| `POST`（判別無し） | 入力検証（エラーは入力画面）→ `update`（`e.ar.c2.2001` は入力画面にメッセージ表示） | フラッシュ `i.ar.c2.2001` で 302 `?complete` |
| `GET ?complete` | 会員を再取得して入力画面を作る | 画面 `C2/memberUpdateForm`（成功メッセージ付き） |
| `POST ?redo` | — | 画面 `C2/memberUpdateForm` |
-/

/-!
## D1: 予約履歴レポート

権限 `MEMBER`、トークン名前空間 `HistoryReport/create`。

| リクエスト | トークン | 処理 | 結果 |
| --- | --- | --- | --- |
| `GET /HistoryReport/create?form` | BEGIN | — | 画面 `D1/createReportForm`（「{会員番号} の予約履歴レポートを作成します。よろしいですか？」） |
| `POST /HistoryReport/create` | IN | `requestReport(会員番号)` | 302 `/HistoryReport/create?accepted` |
| `GET /HistoryReport/create?accepted` | — | — | 画面 `D1/createReportAccepted` |
| `GET /HistoryReport/download?reportList` | — | `listReports` | 画面 `D1/downloadReportList`（0 件なら「予約履歴レポートが存在しません。」） |
| `GET /HistoryReport/download?reportName=X` | — | `getReport` | 有り: 200 `text/csv`, `Content-Disposition: attachment;filename=X`。無し: 画面 `D1/downloadReportFailed` |
-/

/-!
## REST API（`/api/v1`）

要求の JSON の文字列に不対サロゲートのエスケープ（例 `"\ud800"`）があれば、**[Spec]** は `InvalidRequest` とする（文字列はスカラ値の列であるため）。[Source] は受け付けて処理を続ける（既知差異 [D-026](../../docs/spec/abstraction.md#既知差異)）。

- 認証: HTTP Basic（任意）。セッションを作らない。CSRF 検査無し。すべて `permitAll`。ただし `Authorization` ヘッダの資格情報が誤っていれば 401（`WWW-Authenticate: Basic realm="Realm"`。本文は定めない。`X-Requested-With: XMLHttpRequest` 付きならヘッダも本文も無い 401）。
  [Source] は、Basic 認証が成功するたびに会員のログイン状態を更新する（`loginDateTime := today`・`loginFlg := true`）。[Spec] は REST の要求でログイン状態を変えない（既知差異 [D-028](../../docs/spec/abstraction.md#既知差異)。Java の原典実行で確かめた。`tools/origin-run/http/login.json`）。
- 前処理（空白除去）無し（[`Spec.InputValidation`](InputValidation.lean#前処理)）。
- 日付の JSON 表現: **日付型**（原典の `LocalDate`）の項目は `"yyyy-MM-dd"`（要求・応答とも）。原典が文字列として整形して返す項目（`GET /api/v1/flight` の応答の `depDate` など、[`Spec.FlightSearch`](FlightSearch.lean#出力-flightvacantinfo)）と、クエリパラメータの日付（`yyyy/MM/dd`）は、この規則の対象外とする。

根拠（[Source]）: 原典の Spring Framework 7.0.3 は、クラスパスに Jackson 3（`tools.jackson.core:jackson-databind` 3.0.4）があれば Jackson 2 より優先して JSON 変換に使う。原典は Jackson 3 と Jackson 2 の両方を依存に持ち、`ObjectMapper` を独自に設定していない（`w/config/web/SpringMvcConfig.java`, `SpringMvcRestConfig.java`）。Jackson 3 は既定で日付を時刻印（配列・数値）として書かないため、`LocalDate` は `"yyyy-MM-dd"` になる。`SelectFlightResource.depDate` の `@DateTimeFormat(pattern = "yyyy/MM/dd")` は Jackson の変換には効かない。

原典での確認（[Source]）: Java の原典実行で、`POST /api/v1/ticket` の要求の `depDate` を `"yyyy-MM-dd"` で送ると予約され、応答の `paymentDate`・`selectFlightResourceList[].depDate` も `"yyyy-MM-dd"` になることを確かめた。`"yyyy/MM/dd"` の `depDate` は Jackson 3 の `LocalDate` の読み取りで失敗し、400（`ApiError` の `e.ar.fw.9999`）になる（`tools/origin-run/http/postTicket.json`。[backlog f18c](../../docs/backlog/f18c-java-oracle-harness.md)）。

### GET /api/v1/flight

クエリ・検証・応答の形は `GET /api/flights` と同じ。エラーは下記 `ApiError`。

### POST /api/v1/ticket

要求:

```json
{
  "repFamilyName": "デンデン", "repGivenName": "ハナコ", "repAge": 40, "repGender": "F",
  "repMembershipNumber": "0000000001",
  "repTel1": "03", "repTel2": "1234", "repTel3": "5678", "repMail": "a@example.com",
  "flightType": "OW",
  "selectFlightResourceList": [
    { "depDate": "2026-11-10", "flightName": "NTT001", "boardingClassCd": "N", "fareTypeCd": "OW" }
  ],
  "passengerResourceList": [
    { "familyName": "デンデン", "givenName": "ハナコ", "age": 40, "gender": "F", "membershipNumber": "0000000001" }
  ]
}
```

処理: 入力検証（[Source] は単項目のみ、[Spec] は相関検証も。[D-007](../../docs/spec/abstraction.md#既知差異)）→ `validateFlightList` → `reserve`。

- `validateFlightList` の失敗は、`InvalidRequest` も `Business`（`e.ar.b2.2001`）もすべて改竄とみなし、`InvalidRequest` として 500 を返す（原典 `w/api/ticket/TicketHelper.validateFlightList` が `BadRequestException` に包む）。
- **[Spec]** 入力検証の結果にコード `Invalid` のフィールドエラー（選択フライト数・搭乗者数の改竄）があれば、他のエラーにかかわらず `InvalidRequest` として 500 を返す。[Source] では相関検証が無く、同じ入力は後段の `Assert` で 500（`e.ar.fw.9999`）になる。

応答 201: 要求と同じオブジェクトに `reserveNo`, `paymentDate`, `totalFare` を加えたもの。`passengerResourceList` の各要素には、さらに `"empty": false` を加える（原典の `PassengerResource.isEmpty()` が JSON の欄として出る。Java の原典実行 `tools/origin-run/http/postTicket.json` で確かめた。差異にせず、[Spec] を原典に合わせる）。要求の `Integer` の欄（`repAge`・`age`）は JSON の数値とする（[Source] は数字の文字列も受け付ける。既知差異 [D-041](../../docs/spec/abstraction.md#既知差異)）。

### GET /api/v1/ticket/check?reserveNo=x

応答 200: JSON 真偽値（`existsReserveNo(x)`）。`x` は書式を検査しない（空文字・不正な値は `false`）。パラメータ `reserveNo` が無ければ 400（入力検証エラーの ApiError）。

### ApiError

```json
{ "code": "e.ar.b2.2009", "message": "…", "target": "…", "details": [ApiError] }
```

`target`・`details` は空なら省略する。

| 原因 | ステータス | 本文 |
| --- | --- | --- |
| 入力検証エラー | 400 | `code = "e.ar.fw.9999"`、`details` に各エラー（フィールドエラーは `target = 項目名`、グローバルエラーは `target = オブジェクト名`、`code` は制約名）。`details` の並びは [`Spec.InputValidation`](InputValidation.lean#検証の順序とエラーの並び) の [Spec] の順 |
| JSON 解析不能 | 400 | 原因に応じた `ApiError` |
| `NotFound` | 404 | 下記「業務メッセージの変換」 |
| `Business` | 409 | 同上（`validateFlightList` の `Business` を除く。上記） |
| `Conflict`（排他制御の失敗。[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md)） | 409 | `code = "e.ar.fw.9999"` |
| `InvalidRequest` | 500 | `code = "e.ar.a0.L9001"`、`message = "不正リクエスト(パラメータ改竄) " ++ 詳細`。詳細は [Spec] の非決定的な選択（任意の文字列）であり、適合テストでは比較しない。[Source] は原因の例外のメッセージを使う。[Spec] がどの文字列も許すので、差異ではない |
| `System(code, args)` | 500 | `code` は `System` のコード（例 `e.ar.a0.L9002`） |
| `PreconditionViolation`・その他 | 500 | `code = "e.ar.fw.9999"` |

業務メッセージの変換: メッセージが 1 件ならそのコードと文言を最上位に置く。複数なら最上位を `e.ar.fw.8001` とし、各メッセージを `details` に置く（`Business`・`NotFound` は常に 1 件のメッセージを持つので、複数の場合は原典でも到達しない）。

出典（ApiError）: `w/api/common/error/ApiGlobalExceptionHandler.java`, `ApiErrorCreator.java`

出典: atrs-web/.../app/**/\*Controller.java, atrs-web/.../api/**/\*.java, atrs-web/.../config/web/SpringSecurityConfig.java, SpringMvcConfig.java, atrs-web/src/main/webapp/WEB-INF/web.xml
-/
