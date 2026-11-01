---
type: Specification
title: "認証（A0/A1/A2）"
description: "ログインの事前検査・資格情報の照合・ログイン状態の更新・ログアウト・セッションと権限。"
tags: [spec, authentication, a1, a2]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 認証（A0/A1/A2）

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。ただしセッションの保持方式・ログイン処理の伝送（フォーム投稿、Cookie、ログイン時のセッション ID の更新）は [http-contract.md](http-contract.md#セッション) の規範節に従う。

原典は Spring Security のフォームログインを使う。ここではその **効果** を定義する（[ADR 84bf](../decision/84bf-porting-scope.md)）。

## ログイン（login）

### シグネチャ

`login(membershipNumber?: String, password?: String; ports, today) : Except AtrsError Session`

### 定義（評価順）

1. **事前検査**（会員の検索より前に行う）:
   - `membershipNumber` が無い、または長さが 10 でなければ失敗（ログ `i.ar.a1.L2001`）。
   - `password` が無い、または長さが 8〜20 の範囲外なら失敗（ログ `i.ar.a1.L2002`）。
   - 長さは [Spec] では `scalarLen`、[Source] では `utf16Len`（[ADR 10a5](../decision/10a5-text-length-and-character-classes.md)、既知差異 [D-006](abstraction.md#既知差異)）。前後の空白除去は行わない。
2. 会員番号の前後の空白（U+0000–U+0020）を除去した値で会員（ログイン情報を含む）を検索する。無ければ失敗（ログ `i.ar.a1.L2001`）。事前検査は除去 **前** の値に対して行う（原典どおり。例: `" 000000001"` は長さ 10 で事前検査を通り、`"000000001"` で検索されて失敗する）。
3. `PasswordHasher.matches(password, member.login.password)` が偽なら失敗（ログ `i.ar.a1.L2003`）。
4. ログイン状態を更新する（1 トランザクション）: `loginDateTime := today`, `loginFlg := true`（ログ `i.ar.a1.L0001`）。
5. 会員情報を保持するセッション（権限 `MEMBER`）を返す。

失敗はすべて同一の `Business("e.ar.a1.2001")`（「会員番号またはパスワードが確認できませんでした。…」）として利用者に示し、どの検査で失敗したかは区別しない。

[Source] の追加の振る舞い: 手順 4 の更新件数が 1 でなければ `System("e.ar.a0.L9002")`。リポジトリの契約（[Spec] の前提）の下では到達しないため、差異ではない（[abstraction.md](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) の D-010、補題 ABS-022）。

[Source] は手順 4 を行わない（既知差異 [D-028](abstraction.md#既知差異)。観測型）。原典の手順 4 は `AuthenticationSuccessEvent` を受ける `AtrsAuthenticationSuccessListener` で行うが、フォームログインが使う `authenticationManager` は `new ProviderManager(authProvider)` で作られ、イベント発行者が設定されていないため、イベントが出ない（`w/config/web/SpringSecurityConfig.java`）。Java オラクルで、画面ログインの成功の前後で `MEMBER_LOGIN` の `LOGIN_DATE_TIME`・`LOGIN_FLG` が変わらないことを確かめた。一方、REST の HTTP Basic 認証では、Spring Security が組み立てる認証マネージャ（イベント発行者付き）を使うので、成功のたびに更新される（`tools/oracle/http/login.json`。[backlog f18c](../backlog/f18c-java-oracle-harness.md)）。R 課題 ABS-043・ABS-045 の成分 `obs_D028` と W 課題 ABS-128 は [backlog 44f8](../backlog/44f8-authentication-usecases.md) で置く。

出典: atrs-web/.../app/common/security/AtrsUsernamePasswordAuthenticationFilter.java, atrs-domain/.../service/a1/AtrsUserDetailsService.java, AuthLoginServiceImpl.java, atrs-domain/.../common/security/AtrsAuthenticationSuccessListener.java

## ログアウト（logout）

**[Spec=Source]** ログイン中なら `loginFlg := false` に更新し（ログ `i.ar.a2.L0001`）、セッションを破棄する（伝送は [http-contract.md](http-contract.md#セッション)）。`loginDateTime` は変えない。未ログインならセッションの破棄のみ。

出典: atrs-domain/.../service/a2/AuthLogoutServiceImpl.java, atrs-web/.../app/common/security/AtrsLogoutSuccessHandler.java

## セッション

**[Spec=Source]**

- セッションはログイン中の会員の情報（`Member`、ログイン情報を含む）を保持する。
- 会員情報変更が成功したら、セッションの会員情報を最新のもので置き換える。
- 権限 `MEMBER` が必要な機能: 会員情報変更（C2）、予約履歴レポート（D1）。未ログインでアクセスした場合はログイン画面を表示する（[http-contract.md](http-contract.md#認証と権限)）。
- ログイン状態の確認: ログイン中かどうかを返す（REST `GET /api/auth/status`）。

画面上の挨拶表示は「ようこそ {kanjiFamilyName} {kanjiGivenName} さま」。
