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
  at: 2026-10-29T22:07:40+09:00
---

# 入力検証

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

原典の Bean Validation と相関検証（`*Validator`）の **効果** を、検証関数 `validate(input) : [FieldError | GlobalError]` として定義する。
結果が空なら合格。エラーは [errors-and-messages.md](errors-and-messages.md#入力検証エラー) の形式で表す。

## 前処理

**[Spec=Source]**

- **画面（フォーム投稿）**: すべての文字列項目は、前後の U+0000–U+0020 を除去し、結果が空文字なら「未入力」とする（原典 `StringTrimmerEditor(true)` / `String.trim()`）。
- **REST API（`/api/v1/*`）**: 前処理を行わない。JSON の `null` または項目の欠落を「未入力」とし、空文字は空文字のまま検証する。
- 数値・日付・列挙の項目は、文字列から型への変換に失敗したら `FieldError(field, "typeMismatch")` とし、その項目の他の検証は行わない。日付の書式は `yyyy/MM/dd`（画面）。
- 未入力の項目は、`Required` 以外の単項目検証をすべて合格とする。

出典: atrs-web/.../app/common/binding/GlobalBindingInitializer.java

## 文字クラス

**[Spec=Source]**（[ADR 0010](../decision/0010-text-length-and-character-classes.md)）コードポイントの閉区間で定義する。

| 名前 | 文字集合 |
| --- | --- |
| `Half` | U+0020–U+007E |
| `HalfKana` | U+FF61–U+FF9F |
| `Katakana` | U+30A0–U+30FF（`゠`, `・`, `ー`, `ヽ`, `ヾ`, `ヿ` を含む） |
| `Digit` | U+0030–U+0039 |

| 制約 | 合格条件（未入力は合格） | コード |
| --- | --- | --- |
| `FullWidth` | すべての文字が `Half` にも `HalfKana` にも属さない（空文字も合格） | `FullWidth` |
| `FullWidthKatakana` | 1 文字以上で、すべての文字が `Katakana` | `FullWidthKatakana` |
| `HalfWidth` | 1 文字以上で、すべての文字が `Half` | `HalfWidth` |
| `HalfWidthNumber` | 1 文字以上で、すべての文字が `Digit` | `HalfWidthNumber` |
| `Size(min, max)` | `min ≤ len ≤ max` | `Size` |
| `FixedLength(n)` | `len = n` | `FixedLength` |
| `Email` | 電子メールアドレスの形式 | `Email` |
| `Min(n)` / `Max(n)` | 数値として `≥ n` / `≤ n`。文字列項目の場合は十進整数として解釈し、解釈できなければ不合格 | `Min` / `Max` |
| `Digits(i, f)` | 整数部 `i` 桁以下・小数部 `f` 桁以下 | `Digits` |
| `Required` | 入力がある | `NotNull`（文字列で空文字も不可の場合 `NotEmpty`） |
| `InCodeList(id)` | 値がコードリスト `id`（[master-data.md](master-data.md#空港コードリスト画面用)）に存在 | `ExistInCodeList` |

`len` は [Spec] では `scalarLen`、[Source] では `utf16Len`（既知差異 [D-006](abstraction.md#既知差異)）。

> **TODO(spec):** `Email` の判定規則（原典は Hibernate Validator の `@Email` 実装）を言語中立に書き下す（[backlog 0008](../backlog/0008-member-usecases-and-input-validation.md)）。

## 検証の順序とエラーの並び

**[Spec=Source]**

1. 単項目検証を全項目について行う。1 項目に複数の違反があればすべて報告する。
2. 相関検証を下記の順で行う。相関検証は、参照する項目に単項目エラーが無い場合にだけ行う。
3. 結果は「フィールドエラー（項目の宣言順）→ グローバルエラー（発生順）」の順に並べる。

> **TODO(spec):** 原典で 1 項目に複数の違反が出た場合の並び順（Bean Validation は順序を保証しない）を [Source] でどう扱うか決める。[Spec] では制約表の列挙順とする。

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

搭乗者欄は常に 6 欄（最初の表示は 3 欄、最大 6 欄）。

相関（この順）:

1. `repTel1`, `repTel2` に単項目エラーが無く、`len(repTel1) + len(repTel2)` が 6〜7 の範囲外 → `GlobalError("e.ar.b2.5003", [repTel1 の表示名, repTel2 の表示名, 6, 7])`
2. 空でない搭乗者欄（[reservation.md](reservation.md#予約内容の組み立て)）それぞれについて、未入力の `familyName`, `givenName`, `age`, `gender` に `FieldError(passengers[i].<項目>, "NotNull")`
3. 空でない搭乗者欄が 0 → `GlobalError("e.ar.b2.5002")` を加えて **終了**（4 を行わない）
4. フライト選択の相関検証

**[Source]** の REST 予約 API（`POST /api/v1/ticket`）では、相関検証 1〜4 が **適用されない**（原典の不具合: `@InitBinder("ticketReserveForm")` が引数名 `ticketReserveResource` と一致しない）。単項目検証のみ行い、`passengerResourceList` の各要素は `familyName`, `givenName`, `age`, `gender` が Required。**[Spec]** では相関検証を適用する（既知差異 [D-007](abstraction.md#既知差異)）。

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
