/-!
# 認証（`Spec.Auth`）

> **区分: 草案（draft）。** まだ Lean に形式化していない。形式化するときは、この章に定義を足し、本文を要約に書き換える。セッションの保持方式・ログイン処理の伝送（フォーム投稿、Cookie、ログイン時のセッション ID の更新）は [`Spec.Http`](Http.lean#セッション) の規範節に従う。

ログイン（画面 A1）・ログアウト（A2）と、ログイン中の会員を保持するセッション（A0）を定める。原典は Spring Security の
フォームログインを使うが、ここではその **効果** だけを定義する。
-/

/-!
## ログイン（login）

### シグネチャ

`login(membershipNumber?: String, password?: String; ports, today) : Except AtrsError Session`

### 定義（評価順）

1. **事前検査**（会員の検索より前に行う）:
   - `membershipNumber` が無い、または長さが 10 でなければ失敗（ログ `i.ar.a1.L2001`）。
   - `password` が無い、または長さが 8〜20 の範囲外なら失敗（ログ `i.ar.a1.L2002`）。
   - 長さは [Spec] では `scalarLen`、[Source] では `utf16Len`（[ADR 10a5](../../docs/decision/10a5-text-length-and-character-classes.md)、既知差異 [D-006](../../docs/spec/abstraction.md#既知差異)）。前後の空白除去は行わない。
2. 会員番号の前後の空白（U+0000–U+0020）を除去した値で会員（ログイン情報を含む）を検索する。無ければ失敗（ログ `i.ar.a1.L2001`）。事前検査は除去 **前** の値に対して行う（原典どおり。例: `" 000000001"` は長さ 10 で事前検査を通り、`"000000001"` で検索されて失敗する）。
3. `PasswordHasher.matches(password, member.login.password)` が偽なら失敗（ログ `i.ar.a1.L2003`）。
4. ログイン状態を更新する（1 トランザクション）: `loginDateTime := today`, `loginFlg := true`（ログ `i.ar.a1.L0001`）。
5. 会員情報を保持するセッション（権限 `MEMBER`）を返す。

失敗はすべて同一の `Business("e.ar.a1.2001")`（「会員番号またはパスワードが確認できませんでした。…」）として利用者に示し、どの検査で失敗したかは区別しない。

[Source] の追加の振る舞い: 手順 4 の更新件数が 1 でなければ `System("e.ar.a0.L9002")`。リポジトリの契約（[Spec] の前提）の下では到達しないため、差異ではない（[abstraction.md](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) の D-010、補題 ABS-022）。

[Source] は、画面のログインでは手順 4 を行わない（ログイン状態が変わらない）。一方、REST の HTTP Basic 認証では、成功のたびに手順 4 と同じ更新を行う（既知差異 [D-028](../../docs/spec/abstraction.md#既知差異)。観測型。[`Spec.Http`](Http.lean#rest-apiapiv1)）。

出典: atrs-web/.../app/common/security/AtrsUsernamePasswordAuthenticationFilter.java, atrs-domain/.../service/a1/AtrsUserDetailsService.java, AuthLoginServiceImpl.java, atrs-domain/.../common/security/AtrsAuthenticationSuccessListener.java
-/

/-!
## ログアウト（logout）

**[Spec=Source]** ログイン中なら `loginFlg := false` に更新し（ログ `i.ar.a2.L0001`）、セッションを破棄する（伝送は [`Spec.Http`](Http.lean#セッション)）。`loginDateTime` は変えない。未ログインならセッションの破棄のみ。

出典: atrs-domain/.../service/a2/AuthLogoutServiceImpl.java, atrs-web/.../app/common/security/AtrsLogoutSuccessHandler.java
-/

/-!
## セッション

**[Spec=Source]**

- セッションはログイン中の会員の情報（`Member`、ログイン情報を含む）を保持する。
- 会員情報変更が成功したら、セッションの会員情報を最新のもので置き換える。
- 権限 `MEMBER` が必要な機能: 会員情報変更（C2）、予約履歴レポート（D1）。未ログインでアクセスした場合はログイン画面を表示する（[`Spec.Http`](Http.lean#認証と権限)）。
- ログイン状態の確認: ログイン中かどうかを返す（REST `GET /api/auth/status`）。

画面上の挨拶表示は「ようこそ {kanjiFamilyName} {kanjiGivenName} さま」。
-/

/-!
## 根拠と対応

- 根拠: [ADR 84bf](../../docs/decision/84bf-porting-scope.md)（移植の範囲。認証は効果だけを定める）、[ADR 10a5](../../docs/decision/10a5-text-length-and-character-classes.md)（文字列の長さ）、[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)（パスワードのハッシュのポート）。
- 既知差異: D-006・D-028、[Spec] の前提の外の D-010（[一覧](../../docs/spec/abstraction.md#既知差異)）。
- D-028 の原因（[Source]）: 原典の手順 4 は `AuthenticationSuccessEvent` を受ける `AtrsAuthenticationSuccessListener` で行う。フォームログインが使う `authenticationManager` は `new ProviderManager(authProvider)` で作られ、イベント発行者が設定されていないため、イベントが出ない（`w/config/web/SpringSecurityConfig.java`）。REST の HTTP Basic 認証は、Spring Security が組み立てる認証マネージャ（イベント発行者付き）を使う。Java の原典実行（[ADR 81da](../../docs/decision/81da-java-origin-run-domain-and-http.md)、[`login.json`](../../tools/origin-run/http/login.json)）で、画面ログインの前後で `MEMBER_LOGIN` の `LOGIN_DATE_TIME`・`LOGIN_FLG` が変わらず、Basic 認証では変わることを確かめた。
-/
