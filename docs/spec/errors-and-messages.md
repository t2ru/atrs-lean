---
type: Specification
title: "エラーとメッセージ"
description: "エラーの分類、エラーコード一覧、日本語メッセージ文言、項目の表示名、引数置換規則。"
tags: [spec, errors, messages]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
sources:
  - id: messages
    resource: https://github.com/terasolunaorg/atrs/blob/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf/atrs/atrs-web/src/main/resources/i18n/atrs-messages_ja.properties
    title: atrs-messages_ja.properties
---

# エラーとメッセージ

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。メッセージ文言は Lean `Spec` のデータとして形式化する。

方針は [ADR a4fa](../decision/a4fa-errors-as-values-with-stable-codes.md)。

## 分類（AtrsError）

| 分類 | 内容 | 画面での扱い | REST（`/api/v1`）での扱い |
| --- | --- | --- | --- |
| `Business(code, args)` | 業務規則違反 | メッセージを表示して入力画面へ戻る | 409 |
| `NotFound(code)` | 照会結果 0 件 | メッセージ表示 | 404 |
| `Validation(errors)` | 入力検証エラー | 項目・画面上部に表示 | 400 |
| `InvalidRequest(reason)` | 改竄検知 | 400 エラー画面（`e.ar.fw.0003`） | 500、`code = "e.ar.a0.L9001"`（原典どおり。[http-contract.md](http-contract.md#apierror)） |
| `PreconditionViolation(reason)` | 前提違反（[Source] のみ） | 500 システムエラー画面 | 500 |
| `System(code, args)` | 整合性違反・I/O 失敗 | 500 システムエラー画面 | 500 |
| `Conflict(reason)` | 排他制御の失敗（デッドロック、ロック待ちのタイムアウト、直列化失敗、楽観ロックの衝突）で、実行環境が吸収できなかったもの。[Spec] では、状態を変更する操作の非決定的な結果である。このとき採番以外の状態は変わらない。実行可能な [Spec] の標準の選択は、この結果を選ばない（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)） | 500 システムエラー画面（`e.ar.fw.9999`） | 409（`e.ar.fw.9999`） |

`InvalidRequest` のログ用コードは `e.ar.a0.L9001`（「不正リクエスト(パラメータ改竄) {0}」）。

## 入力検証エラー

- `FieldError(field, code, args)`: 項目に紐づくエラー。`field` は項目パス（例 `passengers[2].age`、`selectFlights[0].depDate`）。
- `GlobalError(code, args)`: 画面全体のエラー。
- 単項目検証のコードは制約名（`NotNull`, `NotEmpty`, `Size`, `FixedLength`, `FullWidth`, `FullWidthKatakana`, `HalfWidth`, `HalfWidthNumber`, `Email`, `Min`, `Max`, `Digits`, `ExistInCodeList`, `typeMismatch`）。
- 相関検証のコード `Invalid`（選択フライト数・搭乗者数の改竄。[input-validation.md](input-validation.md)）には文言が無い。画面でも REST でも改竄として扱われ、文言を表示する経路が無いため。
- `field` の項目パスは、本書と [input-validation.md](input-validation.md) では抽象名（`selectFlights[i]`, `passengers[i]`）で書く。HTTP の項目名との対応は [input-validation.md](input-validation.md#項目名の対応) に示す。

## メッセージの置換

`{n}` を n 番目（0 始まり）の引数で置き換える。単項目検証の `{0}` は項目の表示名（下記）。数値引数は区切り無しの十進表記。

### 単項目検証メッセージ

| コード | 文言 | 引数 |
| --- | --- | --- |
| `NotNull`, `NotEmpty` | {0}を入力してください。 | 表示名 |
| `NotNull`（選択項目: `gender`, `repGender`, `boardingClassCd`, `flightType`, `outwardFlight`, `homewardFlight`） | {0}を選択してください。 | 表示名 |
| `Size` | {0} は {2} 文字以上 {1} 文字以下でなければなりません。 | 表示名, max, min |
| `FixedLength` | {0} は {1} 文字でなければなりません。 | 表示名, n |
| `Min` | {0}は{1}以上の値を入力してください。 | 表示名, n |
| `Max` | {0}は{1}以下の値を入力してください。 | 表示名, n |
| `Digits` | {0}の桁数が{1}～{2}桁の範囲外です。入力内容をご確認ください。 | 表示名, 整数桁, 小数桁 |
| `Email` | {0} は正しいメールアドレスではありません。 | 表示名 |
| `FullWidth` | {0} は全角文字でなければなりません。 | 表示名 |
| `FullWidthKatakana` | {0} は全角カタカナでなければなりません。 | 表示名 |
| `HalfWidth` | {0} は半角文字でなければなりません。 | 表示名 |
| `HalfWidthNumber` | {0} は半角数字でなければなりません。 | 表示名 |
| `ExistInCodeList` | {0}を選択してください。 | 表示名 |
| `typeMismatch`（Integer） | {0}は半角数字ではありません。 | 表示名 |
| `typeMismatch`（Date） | {0}に正しい日付を入力してください。 | 表示名 |
| `typeMismatch`（Gender, BoardingClassCd, FlightType） | {0}を選択してください。 | 表示名 |

`NotEmpty` には項目別の文言が無く、選択項目（`depAirportCd`, `arrAirportCd`, `creditTypeCd`, `creditMonth`, `creditYear`）でも「{0}を入力してください。」になる（例「出発空港を入力してください。」）。`ExistInCodeList` は未入力を合格とするので、`NotEmpty` と重ねて報告されることは無い。

REST API の `NotNull`（`flightSearchQuery.boardingClassCd`, `flightSearchQuery.flightType`, `passengerResource.gender`, `selectFlightResource.boardingClassCd`, `ticketReserveResource.repGender`, `ticketReserveResource.flightType`）は「{0}を入力してください。」。

## 業務・画面メッセージ

| コード | 分類 | 文言 |
| --- | --- | --- |
| `e.ar.a1.2001` | Business | 会員番号またはパスワードが確認できませんでした。入力情報をご確認ください。 |
| `e.ar.b1.2001` | Business | 空席照会対象外の搭乗日が入力されています。対象期間をご確認ください。 |
| `e.ar.b1.2002` | Business | ご指定の区間は運行しておりません。運行区間をご確認ください。 |
| `e.ar.b1.2003` | NotFound | ご指定の条件に合致するフライトはございません。 |
| `e.ar.b1.5001` | Validation | 出発空港と到着空港に同じ空港は指定できません。区間をご確認ください。 |
| `e.ar.b1.5002` | Validation | 復路搭乗日は往路搭乗日以降である必要があります。 |
| `e.ar.b2.2001` | Business | 選択された復路のフライトはご利用できません。復路のフライトは往路の到着時刻より2時間以上経過している必要があります。 |
| `e.ar.b2.2002` | Business | 入力された代表者情報の会員番号が確認できませんでした。入力情報をご確認ください。 |
| `e.ar.b2.2003` | Business | 入力された代表者情報と会員番号に該当するお客様情報が一致しません。入力情報をご確認ください。 |
| `e.ar.b2.2004` | Business | 予約代表者の方は{0}歳以上である必要があります。 |
| `e.ar.b2.2005` | Business | 入力された[{0}]番目の会員番号が確認できませんでした。入力情報をご確認ください。 |
| `e.ar.b2.2006` | Business | 入力された[{0}]番目のお客様情報と会員番号に該当するお客様情報が一致しません。入力情報をご確認ください。 |
| `e.ar.b2.2007` | Business | 運賃種別に「レディース割」をご利用の場合、搭乗者は全て女性である必要があります。 |
| `e.ar.b2.2008` | Business | 以下のフライトが予約可能時期を満たしておりません。フライトを変更してください。（引数無し。「以下のフライト」は失敗画面に並ぶ選択した全フライトを指す） |
| `e.ar.b2.2009` | Business | `<h2>ご迷惑をおかけして申し訳ありません。</h2><p>以下のフライトの座席が確保できませんでした。<br>お手数ですが、再度フライトの選択を行ってください。</p>`（HTML を含む。エスケープせずに表示する。引数無し。「以下のフライト」は 2008 と同じ） |
| `e.ar.b2.2010` | Business | 選択された運賃種別の最少人数を満たしておりません。運賃種別「{0}」は{1}名からご利用になれます。 |
| `e.ar.b2.5001` | Validation | 往路または復路のフライトが選択されていません。 |
| `e.ar.b2.5002` | Validation | お客様情報を入力してください。 |
| `e.ar.b2.5003` | Validation | {0}と{1} の合計文字数は {2}～{3}文字でなければなりません。 |
| `e.ar.c0.5001` | Validation | 再入力されたEメールが一致しません。入力内容をご確認ください。 |
| `e.ar.c0.5002` | Validation | 市外局番と市内局番の合計桁数が6～7桁の範囲外です。入力内容をご確認ください。 |
| `e.ar.c0.5003` | Validation | 生年月日は{0}から{1}までの期間で入力してください。 |
| `e.ar.c1.5001` | Validation | 再入力されたパスワードが一致しません。入力内容をご確認ください。 |
| `e.ar.c2.2001` | Business | 入力された現在のパスワードが一致しません。正しいパスワードを入力してください。 |
| `e.ar.c2.5001` | Validation | 再入力されたパスワードが一致しません。入力内容をご確認ください。 |
| `e.ar.c2.5002` | Validation | パスワードを変更する場合は現在のパスワード、変更するパスワード、パスワードの再入力を全て入力してください。 |
| `i.ar.c2.2001` | 情報 | 会員情報を更新しました。 |
| `e.ar.fw.0001` | 画面 | リクエストが矛盾しています。（トークンエラー） |
| `e.ar.fw.0002` | 画面 | リクエストが許可されていません。（CSRF エラー） |
| `e.ar.fw.0003` | 画面 | 400:不正なリクエストです。 |
| `e.ar.fw.0004` | 画面 | 403:不正なアクセスです。 |
| `e.ar.fw.0005` | 画面 | 404:Webページが見つかりません。 |
| `e.ar.fw.8001` | 画面 | 業務エラーが発生しました。 |
| `e.ar.fw.9999` | 画面 | `<h2>ご迷惑をおかけして申し訳ありません。</h2><p>エラーが発生しました。<br>お手数ですが、しばらく時間をおいてから再アクセスするか、お問い合わせください。</p>` |

## ログ・システムコード

ログの文言・形式は対象外（[ADR 84bf](../decision/84bf-porting-scope.md)）。コードのみ参考として示す。

| コード | 意味 |
| --- | --- |
| `e.ar.a0.L9001` | 不正リクエスト(パラメータ改竄) {0} |
| `e.ar.a0.L9002` | データ更新件数({0})と予想件数({1})の不一致 |
| `i.ar.a1.L0001` | 会員番号[{0}] ログイン成功 |
| `i.ar.a1.L2001` | 会員番号[{0}] ログイン失敗(会員番号不正) |
| `i.ar.a1.L2002` | 会員番号[{0}] ログイン失敗(パスワード不正) |
| `i.ar.a1.L2003` | 会員番号[{0}] ログイン失敗(存在しない会員番号、またはパスワード不一致) |
| `i.ar.a2.L0001` | 会員番号[{0}] ログアウト成功 |
| `e.ar.d1.L0001` | お客様番号[{0}]のレポート情報取得失敗 |
| `e.ar.d1.L0002` | お客様番号[{0}]のレポート作成失敗 |
| `e.ar.d1.L0003` | ディレクトリ[{0}]の作成失敗 |
| `e.ar.d1.L0004` | レポート作成条件抽出失敗 |
| `w.ar.d1.L0001` | ファイル[{0}]は存在しません |
| `w.ar.d1.L0002` | 受信したJMSメッセージ型[{0}]と想定メッセージ型の不一致 |
| `w.ar.d1.L0003` | 受信したJMSメッセージのお客様番号[{0}]が不正 |

## 項目の表示名

| 項目 | 表示名 |
| --- | --- |
| `membershipNumber` / `password` | 会員番号 / パスワード |
| `flightType` / `depAirportCd` / `arrAirportCd` / `boardingClassCd` | フライト種別 / 出発空港 / 到着空港 / 搭乗クラス |
| `outwardDate` / `homewardDate` / `depDate` | 往路搭乗日 / 復路搭乗日 / 搭乗日 |
| `outwardFlight` / `homewardFlight` | 往路のフライト / 復路のフライト |
| `repFamilyName` / `repGivenName` / `repAge` / `repGender` | 予約代表者姓 / 予約代表者名 / 予約代表者年齢 / 予約代表者性別 |
| `repTel1` / `repTel2` / `repTel3` | 予約代表者電話番号[1] / [2] / [3] |
| `repMail` / `repMembershipNumber` | 予約代表者メールアドレス / 予約代表者会員番号 |
| `passengers[i].familyName` / `.givenName` / `.age` / `.gender` / `.membershipNumber` | 搭乗者姓 / 搭乗者名 / 搭乗者年齢 / 搭乗者性別 / 搭乗者の会員番号 |
| `kanjiFamilyName` / `kanjiGivenName` / `kanaFamilyName` / `kanaGivenName` | 姓 / 名 / カナ姓 / カナ名 |
| `gender` / `dateOfBirth` | 性別 / 生年月日 |
| `tel1` / `tel2` / `tel3` | 電話番号[1] / [2] / [3] |
| `zipCode1` / `zipCode2` / `address` | 郵便番号[1] / [2] / 住所 |
| `mail` / `reEnterMail` | Eメール / Eメール再入力 |
| `creditTypeCd` / `creditNo` / `creditMonth` / `creditYear` | クレジットカード会社 / クレジットカード番号 / クレジットカード有効期限[月] / [年] |
| `reEnterPassword` / `currentPassword` | 再入力パスワード / 現在のパスワード |
| `selectFlights[i].depDate` / `.flightName` / `.boardingClassCd` / `.fareTypeCd`（REST） | 搭乗日 / 便名 / 登場クラスコード / 運賃種別コード |

「登場クラスコード」は原典の誤記であり、[Source] では再現する。[Spec] では「搭乗クラスコード」とする（既知差異 [D-008](abstraction.md#既知差異)）。

出典: atrs-web/src/main/resources/i18n/atrs-messages_ja.properties, atrs-fields_ja.properties, ValidationMessages.properties, atrs-domain/.../common/logging/LogMessages.java
