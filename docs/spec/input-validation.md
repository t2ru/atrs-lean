---
type: Specification
title: "入力検証"
description: "前処理（空白除去）、文字クラス、単項目検証、相関検証、エラーの並び順を画面・API ごとに定義する。"
tags: [spec, validation]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 入力検証

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

原典の Bean Validation と相関検証（`*Validator`）の **効果** を、検証関数 `validate(input) : [FieldError | GlobalError]` として定義する。
結果が空なら合格。エラーは [errors-and-messages.md](errors-and-messages.md#入力検証エラー) の形式で表す。

## 前処理

**[Spec=Source]**

- **画面（フォーム投稿）と画面用の JSON API（`/api/flights`, `/api/member/available` などの `/api/v1` 以外）**: すべての文字列項目（クエリパラメータを含む）は、前後の U+0000–U+0020 を除去し、結果が空文字なら「未入力」とする（原典 `StringTrimmerEditor(true)` / `String.trim()`）。
- **REST API（`/api/v1/*`）**: JSON 本文には前処理を行わない。JSON の `null` または項目の欠落を「未入力」とし、空文字は空文字のまま検証する。
- 数値・日付・列挙の項目は、文字列から型への変換に失敗したら `FieldError(field, "typeMismatch")` とし、その項目の他の検証は行わない。
- 未入力の項目は、`Required` 以外の単項目検証をすべて合格とする。

出典: atrs-web/.../app/common/binding/GlobalBindingInitializer.java

### 日付の解析

**[Spec]** 画面の日付項目とクエリパラメータの日付は、書式 `yyyy/MM/dd` で次をすべて満たすときだけ受け付ける。それ以外は `typeMismatch`。

- 年は数字ちょうど 4 桁（符号無し）、月・日は数字ちょうど 2 桁（ゼロ埋め必須）。区切りは `/`。前後に余分な文字が無い。
- 暦日として存在する（[domain-model.md](domain-model.md#date)。`2026/02/30` は不可）。年は 1〜9999。

REST の JSON 本文の日付型の項目は `yyyy-MM-dd`（同じく桁数固定・暦日として存在すること）。

**[Source]** Spring の `@DateTimeFormat(pattern = "yyyy/MM/dd")` は `ResolverStyle.STRICT` で解析する。桁数と暦日の検査は [Spec] と同じだが、`+10000/01/01`（符号付きの 5 桁以上の年）と `0000/01/01`・`-0001/01/01`（0 以下の年）も受け付ける（既知差異 [D-021](abstraction.md#既知差異)）。JSON 本文は Jackson 3 が ISO 形式で解析する。

出典: spring-context 7.0.3 `DateTimeFormatterFactory`（`DateTimeFormatterUtils.createStrictDateTimeFormatter`）

## 文字クラス

**[Spec=Source]**（[ADR 10a5](../decision/10a5-text-length-and-character-classes.md)）コードポイントの閉区間で定義する。

| 名前 | 文字集合 |
| --- | --- |
| `Half` | U+0020–U+007E |
| `HalfKana` | U+FF61–U+FF9F |
| `Katakana` | U+30A0–U+30FF（`゠`, `・`, `ー`, `ヽ`, `ヾ`, `ヿ` を含む） |
| `Digit` | U+0030–U+0039 |
| `Blank` | U+0009–U+000D、U+001C–U+0020、U+1680、U+2000–U+2006、U+2008–U+200A、U+2028–U+2029、U+205F、U+3000（Java の `Character.isWhitespace` と同じ集合。改行を禁止する空白 U+00A0・U+2007・U+202F は含まない）。`Blank` 以外の文字を含む文字列を「空白でない」という（`hasText`） |

| 制約 | 合格条件（未入力は合格） | コード |
| --- | --- | --- |
| `FullWidth` | すべての文字が `Half` にも `HalfKana` にも属さない（空文字も合格） | `FullWidth` |
| `FullWidthKatakana` | 1 文字以上で、すべての文字が `Katakana` | `FullWidthKatakana` |
| `HalfWidth` | 1 文字以上で、すべての文字が `Half` | `HalfWidth` |
| `HalfWidthNumber` | 1 文字以上で、すべての文字が `Digit` | `HalfWidthNumber` |
| `Size(min, max)` | `min ≤ len ≤ max` | `Size` |
| `FixedLength(n)` | `len = n` | `FixedLength` |
| `Email` | 電子メールアドレスの形式 | `Email` |
| `Min(n)` / `Max(n)` | 数値として `≥ n` / `≤ n`。文字列項目の場合は十進整数（`[0-9]+`）として解釈し、解釈できなければ不合格。[Source] は文字列を `BigDecimal` として解釈するので `"1.5"`・`"+1"`・`"1e1"` も数として比較される（既知差異 [D-018](abstraction.md#既知差異)） | `Min` / `Max` |
| `Digits(i, f)` | 整数部 `i` 桁以下・小数部 `f` 桁以下 | `Digits` |
| `Required` | 入力がある | `NotNull`（文字列で空文字も不可の場合 `NotEmpty`） |
| `InCodeList(id)` | 値がコードリスト `id`（[master-data.md](master-data.md#空港コードリスト画面用)）に存在 | `ExistInCodeList` |

`len` は [Spec] では `scalarLen`、[Source] では `utf16Len`（既知差異 [D-006](abstraction.md#既知差異)）。

### Email

**[Spec]**（[ADR ac33](../decision/ac33-email-validation-rule.md)）原典の Hibernate Validator 9.1.0.Final `AbstractEmailValidator`・`DomainNameUtil` の規則から、IDN 変換（`IDN.toASCII`）を除いたもの。文字列 `s` について:

1. `s` が空文字なら合格（REST で空文字が送られた場合も合格）。
2. `s` に `@` が無ければ不合格。**最後の** `@` で、前をローカル部 `l`、後をドメイン部 `d` に分ける。
3. ローカル部: `len(l) ≤ 64` で、`l` が下記の `LOCAL` に一致する。
4. ドメイン部: `d` が `.` で終わらず、`d` を `.` で区切った各部分の長さが 63 以下、`len(d) ≤ 255` で、`d` が下記の `DOMAIN` に一致する。

照合は ASCII の英字の大小を区別しない（`a-z` は `A-Z` も含む）。`len` はスカラ値の数。

```
LATOM   = [a-z0-9!#$%&'*+/=?^_`{|}~-] | U+0080–U+FFFF
QATOM   = [a-z0-9!#$%&'*.(),<>\[\]:; @+/=?^_`{|}~-] | U+0080–U+FFFF | "\\" | "\""
LWORD   = LATOM+ | '"' QATOM+ '"'
LOCAL   = LWORD ("." LWORD)*

DCHAR   = [a-z0-9!#$%&'*+/=?^_`{|}~] | U+0080–U+FFFF
LABEL   = DCHAR+ ("-"+ DCHAR+)*
DOMAIN  = LABEL ("." LABEL)*
        | "[" IPV4 "]"
        | "[IPv6:" IPV6 "]"
IPV4    = [0-9]{1,3} "." [0-9]{1,3} "." [0-9]{1,3} "." [0-9]{1,3}   （各部の値の範囲は検査しない）
IPV6    = 下記の正規表現（原典 DomainNameUtil.IP_V6_DOMAIN と同一）
```

```
(?:(?:[0-9a-f]{1,4}:){7,7}[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,7}:|(?:[0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,5}(?::[0-9a-f]{1,4}){1,2}|(?:[0-9a-f]{1,4}:){1,4}(?::[0-9a-f]{1,4}){1,3}|(?:[0-9a-f]{1,4}:){1,3}(?::[0-9a-f]{1,4}){1,4}|(?:[0-9a-f]{1,4}:){1,2}(?::[0-9a-f]{1,4}){1,5}|[0-9a-f]{1,4}:(?:(?::[0-9a-f]{1,4}){1,6})|:(?:(?::[0-9a-f]{1,4}){1,7}|:)|fe80:(?::[0-9a-f]{0,4}){0,4}%[0-9a-z]{1,}|::(?:ffff(:0{1,4}){0,1}:){0,1}(?:(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])|(?:[0-9a-f]{1,4}:){1,4}:(?:(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9]))
```

（原典の `a-fA-F`・`a-zA-Z` は、大小を区別しない照合なので `a-f`・`a-z` と書いた。）

`QATOM` の `"\\"`・`"\""` は、それぞれ 2 文字の列 `\\`・`\"` である。U+10000 以上の文字はどの集合にも属さない。
各部分の長さ 63 以下という条件は、原典では `IDN.toASCII` の検査として課される（ASCII のドメインでも課される）。

**[Source]** ドメイン部に `IDN.toASCII` を適用し、失敗すれば不合格、変換後の長さ（UTF-16 単位）が 255 を超えれば不合格とする。正規表現の照合は変換前の文字列に対して行う。ドメイン部が ASCII だけからなる場合は [Spec] と一致する（既知差異 [D-011](abstraction.md#既知差異)）。

出典: hibernate-validator 9.1.0.Final `AbstractEmailValidator.isValid`, `DomainNameUtil.isValidEmailDomainAddress`

## 検証の順序とエラーの並び

**[Spec=Source]**

1. 単項目検証を全項目について行う。1 項目に複数の違反があればすべて報告する。
2. 相関検証を下記の順で行う。相関検証は、参照する項目に単項目エラーが無い場合にだけ行う。

**[Spec]** 結果は次の順に並べる（[ADR e24e](../decision/e24e-validation-error-ordering.md)）。

1. 単項目検証のフィールドエラー: 項目の宣言順（各表の行の順。配列の要素は添字の昇順で、要素の中は表の順）。同じ項目のエラーは制約表（[文字クラス](#文字クラス)）の列挙順。
2. 相関検証で生じるフィールドエラー（例 `homewardDate` の `NotNull`、`selectFlights` の `Invalid`、`passengers[i].*` の `NotNull`）: 発生順。
3. グローバルエラー: 発生順。

画面の表示、`/api/flights` の `messages`、REST の ApiError の `details` はこの順に従う。

**[Source]** 原典の Hibernate Validator は単項目の違反を `HashSet` に集め、Spring はその反復順で `BindingResult` に積む。そのため単項目エラーの並びは、項目をまたいでも決まらない（相関検証のエラーはその後に発生順で積まれる）。[Source] の結果はエラーの多重集合として扱い、[Spec] とは順序を無視して比較する（既知差異 [D-022](abstraction.md#既知差異)、[abstraction.md](abstraction.md#抽象化関数-α)）。

## 項目名の対応

本書の項目名は抽象名である。HTTP の項目名（`FieldError` の `field`、ApiError の `target`）は原典の名前を使う。

| 抽象名 | 画面（フォーム） | REST（`/api/v1/ticket`） |
| --- | --- | --- |
| `selectFlights[i].<項目>` | `selectFlightFormList[i].<項目>` | `selectFlightResourceList[i].<項目>` |
| `passengers[i].<項目>` | `passengerFormList[i].<項目>` | `passengerResourceList[i].<項目>` |
| グローバルエラーのオブジェクト名 | — | `ticketReserveResource`, `flightSearchQuery` など（リソースのクラス名の先頭を小文字にしたもの） |

出典: `w/app/b0/ReservationFlightForm.java`, `w/app/b2/TicketReserveForm.java`, `w/api/ticket/TicketReserveResource.java`, `w/api/common/error/ApiErrorCreator.java`

## 空席照会（B1）

### TicketSearchInput（画面）

| 項目 | 型 | 制約 |
| --- | --- | --- |
| `flightType` | FlightType | Required |
| `depAirportCd` | String | Required(NotEmpty), InCodeList(CL_AIRPORT) |
| `arrAirportCd` | String | Required(NotEmpty), InCodeList(CL_AIRPORT) |
| `outwardDate` | Date | Required |
| `homewardDate` | Date | （下記相関） |
| `boardingClassCd` | BoardingClassCd | Required |

相関:

1. `depAirportCd = arrAirportCd` → `GlobalError("e.ar.b1.5001")`
2. `flightType = RT` のとき `homewardDate` 未入力 → `FieldError(homewardDate, "NotNull")`。入力済みで `homewardDate < outwardDate` → `GlobalError("e.ar.b1.5002")`（同日は可）

### FlightSearchInput（`GET /api/flights`, `GET /api/v1/flight`）

`flightType`, `depAirportCd`, `arrAirportCd`, `depDate`, `boardingClassCd`（制約は上と同じ、`depDate` は Required）。相関は 1 のみ。

出典: atrs-web/.../app/b1/TicketSearchForm.java, TicketSearchValidator.java, FlightSearchCriteriaForm.java, FlightSearchCriteriaValidator.java, atrs-web/.../api/flight/FlightSearchQuery.java, FlightValidator.java

## フライト選択（B0）

### ReservationFlightInput

| 項目 | 制約 |
| --- | --- |
| `flightType` | Required |
| `selectFlights[i].depDate` | Required（Date） |
| `selectFlights[i].flightName` | Required(NotEmpty) |
| `selectFlights[i].boardingClassCd` | Required |
| `selectFlights[i].fareTypeCd` | Required |

相関（`flightType` に単項目エラーが無い場合）:

| flightType | 選択数 | 結果 |
| --- | --- | --- |
| RT | 0 | `GlobalError("NotNull", [outwardFlight])`, `GlobalError("NotNull", [homewardFlight])` |
| RT | 1 | `GlobalError("e.ar.b2.5001")` |
| RT | 2 | 合格 |
| RT | 3 以上 | `FieldError(selectFlights, "Invalid")`（改竄扱い） |
| OW | 0 | `GlobalError("NotNull", [outwardFlight])` |
| OW | 1 | 合格 |
| OW | 2 以上 | `FieldError(selectFlights, "Invalid")`（改竄扱い） |

`selectFlights` 配下または `flightType` のフィールドエラーは、画面では改竄として 400 にする（[http-contract.md](http-contract.md)）。

出典: atrs-web/.../app/b0/ReservationFlightForm.java, SelectFlightForm.java, ReservationFlightValidator.java

## 予約入力（B2）

### TicketReserveInput

| 項目 | 制約 |
| --- | --- |
| `repFamilyName`, `repGivenName` | Required, Size(1,10), FullWidthKatakana |
| `repAge` | Required, Min(0), Digits(3,1) |
| `repGender` | Required |
| `repMembershipNumber` | FixedLength(10), HalfWidthNumber |
| `repTel1` | Required, Size(2,5), HalfWidthNumber |
| `repTel2` | Required, Size(1,4), HalfWidthNumber |
| `repTel3` | Required, FixedLength(4), HalfWidthNumber |
| `repMail` | Required, Size(1,256), HalfWidth, Email |
| `passengers[0..5].familyName`, `.givenName` | Size(1,10), FullWidthKatakana |
| `passengers[0..5].age` | Min(0), Digits(3,1) |
| `passengers[0..5].gender` | — |
| `passengers[0..5].membershipNumber` | FixedLength(10), HalfWidthNumber |
| `flightType`, `selectFlights` | フライト選択と同じ |

搭乗者欄は常に 6 欄（最初の表示は 3 欄、最大 6 欄）。[Source] は `passengerFormList[6]` 以降の欄を送られるとリストを伸ばし（Spring のデータバインダ。上限 256）、搭乗者数の上限を検査しないので、7 名以上の予約を受け付ける（既知差異 [D-038](abstraction.md#既知差異)）。

相関（この順）:

1. `repTel1`, `repTel2` に単項目エラーが無く、`len(repTel1) + len(repTel2)` が 6〜7 の範囲外 → `GlobalError("e.ar.b2.5003", [repTel1 の表示名, repTel2 の表示名, 6, 7])`
2. 空でない搭乗者欄（[reservation.md](reservation.md#予約内容の組み立て)）それぞれについて、未入力の `familyName`, `givenName`, `age`, `gender` に `FieldError(passengers[i].<項目>, "NotNull")`
3. 空でない搭乗者欄が 0 → `GlobalError("e.ar.b2.5002")` を加えて **終了**（4 を行わない）
4. フライト選択の相関検証

**[Source]** の REST 予約 API（`POST /api/v1/ticket`）では、相関検証 1〜4 が **適用されない**（原典の不具合: `@InitBinder("ticketReserveForm")` が引数名 `ticketReserveResource` と一致しない）。単項目検証のみ行い、`passengerResourceList` の各要素は `familyName`, `givenName`, `age`, `gender` が Required。**[Spec]** では相関検証を適用する（既知差異 [D-007](abstraction.md#既知差異)）。

**[Spec]** REST には「空の搭乗者欄」が無いので、`passengerResourceList` の各要素をそのまま搭乗者とし、相関 2・3 を次で置き換える。

- 要素数が 0 → `GlobalError("e.ar.b2.5002")` を加えて **終了**（相関 4 を行わない）。
- 要素数が 7 以上 → `FieldError(passengerResourceList, "Invalid")`（改竄扱い）を加えて **終了**。
- 相関 1 と 4 は画面と同じ。

[Source] は要素数を検査しない（D-007 に含める）。

出典: atrs-web/.../app/b2/TicketReserveForm.java, PassengerForm.java, TicketReserveValidator.java, atrs-web/.../api/ticket/TicketReserveResource.java, PassengerResource.java, TicketRestController.java

## 会員入力（C1/C2）

### MemberInput（共通）

| 項目 | 制約 |
| --- | --- |
| `kanjiFamilyName`, `kanjiGivenName` | Required, FullWidth, Size(1,10) |
| `kanaFamilyName`, `kanaGivenName` | Required, FullWidthKatakana, Size(1,10) |
| `gender` | Required |
| `dateOfBirth` | Required（Date） |
| `tel1` | Required, HalfWidthNumber, Size(2,5) |
| `tel2` | Required, HalfWidthNumber, Size(1,4) |
| `tel3` | Required, HalfWidthNumber, FixedLength(4) |
| `zipCode1` | Required, HalfWidthNumber, FixedLength(3) |
| `zipCode2` | Required, HalfWidthNumber, FixedLength(4) |
| `address` | Required, FullWidth, Size(1,60) |
| `mail`, `reEnterMail` | Required, Email, Size(1,256), HalfWidth |
| `creditTypeCd` | Required(NotEmpty), InCodeList(CL_CREDITTYPE) |
| `creditNo` | Required, FixedLength(16), HalfWidthNumber |
| `creditMonth` | Required(NotEmpty), Min(1), Max(12) |
| `creditYear` | Required(NotEmpty), Min(0) |

### 登録（C1）の追加項目

`password`, `reEnterPassword`: Required, Size(8,20), HalfWidth

相関（この順）:

1. `password ≠ reEnterPassword` → `GlobalError("e.ar.c1.5001")`
2. 共通相関

### 変更（C2）の追加項目

`currentPassword`, `password`, `reEnterPassword`: Size(8,20), HalfWidth（いずれも任意）

相関（この順）:

1. 3 項目すべてに単項目エラーが無く、いずれかが入力されているとき: いずれかが未入力 → `GlobalError("e.ar.c2.5002")`。すべて入力済みで `password ≠ reEnterPassword` → `GlobalError("e.ar.c2.5001")`
2. 共通相関

### 共通相関（この順）

1. `mail ≠ reEnterMail` → `GlobalError("e.ar.c0.5001")`
2. `len(tel1) + len(tel2)` が 6〜7 の範囲外 → `GlobalError("e.ar.c0.5002")`
3. `dateOfBirth < dateOfBirthMinDate ∨ dateOfBirth > today` → `GlobalError("e.ar.c0.5003", [fmtDate(dateOfBirthMinDate), fmtDate(today)])`（両端を含めて可）

出典: atrs-web/.../app/c1/MemberRegisterForm.java, MemberRegisterValidator.java, atrs-web/.../app/c2/MemberUpdateForm.java, MemberUpdateValidator.java, atrs-web/.../app/c0/MemberValidator.java

## ログイン

ログインの入力検査は検証関数ではなく [authentication.md](authentication.md#ログインlogin) の事前検査として定義する。
