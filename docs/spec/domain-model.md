---
type: Specification
title: "ドメインモデル"
description: "型・列挙・値域・不変条件と、仕様全体で使う基本演算（除算・丸め・暦日・書式）の定義。"
tags: [spec, domain-model, types]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# ドメインモデル

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

## 基本演算（Spec.Prim）

**[Spec]** 以下は [Spec] の全定義で使う基本演算である。引数は数学的整数。

| 演算 | 事前条件 | 定義 |
| --- | --- | --- |
| `floorDiv(a, b)` | `b > 0` | `a / b` 以下の最大の整数 |
| `ceilDiv(a, b)` | `b > 0` | `a / b` 以上の最小の整数 |
| `ceilTo(a, m)` | `a ≥ 0`, `m > 0` | `ceilDiv(a, m) * m` |
| `pct(a, r)` | `a ≥ 0`, `r ≥ 0` | `floorDiv(a * r, 100)`（a の r% を切捨て） |

**[Source]** の基本演算（`j32add`, `jdiv32`, `jdmul`, `jd2i`, `bdCeilHundredUp`, `utf16Len` など）は [ADR 0005](../decision/0005-java-primitive-semantics.md) に定義する。
[Source] の Java 参照型（`Integer` 等）が `null` のまま演算された場合は、その操作の結果を `PreconditionViolation("NullPointerException")` とする。

## 暦日と時刻

**[Spec=Source]**（[ADR 0009](../decision/0009-date-and-time-model.md)）

### Date

- 先発グレゴリオ暦の `(year, month, day)`。`1 ≤ year ≤ 9999`、`1 ≤ month ≤ 12`、`1 ≤ day ≤ daysInMonth(year, month)`。
- 閏年: `year % 4 = 0 ∧ (year % 100 ≠ 0 ∨ year % 400 = 0)`。
- `epochDay(d)`: 1970-01-01 を 0 とする通算日数。`addDays(d, n)` は `epochDay` 上の加算、`daysBetween(a, b) = epochDay(b) − epochDay(a)`。
- 比較 `a < b` は `epochDay(a) < epochDay(b)`。「`a` 以前」は `a ≤ b`。
- `fullYearsBetween(b, d)`（満年齢）= `d.year − b.year − (if (d.month, d.day) < (b.month, b.day) then 1 else 0)`（`(month, day)` の辞書順比較）。閏日生まれは平年の 2 月 28 日には加齢せず 3 月 1 日に加齢する。`d < b` のときの値は使わない。

### HourMinute

- `(hour, minute)`、`0 ≤ hour ≤ 23`、`0 ≤ minute ≤ 59`。分換算 `toMinutes = hour * 60 + minute`。
- 原典の便マスタは時刻を 4 桁文字列 `HHmm`（例 `"0945"`）で持つ。`parseHHmm` は 4 文字の数字列のみ受け付ける。

### DateTime

- `Date` と `(hour, minute, second)`。`toEpochMinutes(dt) = epochDay(dt.date) * 1440 + hour * 60 + minute`。
- 「日付 d と時刻 t の日時」を `at(d, t)` と書く。`at(d, t) + n 分` は分換算で加算し、日付の繰り上がりを含む。

### 書式

| 名前 | 形式 | 例 |
| --- | --- | --- |
| `fmtDate` | `yyyy/MM/dd`（ゼロ埋め固定 10 文字） | `2026/10/29` |
| `fmtIsoDate` | `yyyy-MM-dd`（JSON・テストベクタ） | `2026-10-29` |
| `fmtTime` | `HH:mm`。原典 `DateTimeUtil.toFormatTimeString` は長さ 3 以上の文字列 s を `s[0..2] ++ ":" ++ s[2..]` とする | `09:45` |
| `fmtTimestamp` | `yyyyMMddHHmmss` | `20261029213809` |
| `fmtYen` | 3 桁区切り（`###,###`）。`0` は `"0"`。負数は扱わない | `28,800` |
| `fmtPaymentDate` | `MM月dd日(E)`。`E` は曜日の 1 文字（`日月火水木金土`）。括弧は半角 | `11月10日(火)` |

`fmtYen(n)`: n の十進表記を右から 3 桁ごとに `,` で区切る。

`fmtPaymentDate` の曜日は、[Spec] では常に日本語とする。[Source]（`#temporals.format(paymentDate,'MM月dd日(E)')`）は要求の `Accept-Language` に従い、英語なら `Wed` などになる（既知差異 [D-019](abstraction.md#既知差異)）。

## 列挙

**[Spec=Source]** 列挙値の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う。

| 型 | 値 | 意味 |
| --- | --- | --- |
| `FlightType` | `RT`, `OW` | 往復, 片道 |
| `BoardingClassCd` | `N`, `S` | 一般席, 特別席 |
| `FareTypeCd` | `OW`, `RT`, `RD1`, `RD7`, `ED`, `LD`, `GD`, `SOW`, `SRT`, `SRD` | [master-data.md](master-data.md#運賃種別) |
| `Gender` | `F`, `M` | 女性, 男性 |
| `LineType` | `OUTWARD`, `HOMEWARD` | 往路, 復路（表示用ラベル「往路」「復路」） |

運賃種別の分類（出典: atrs-domain/.../common/util/FareTypeUtil.java）:

- `oneWayFareTypes = [OW, RD1, RD7, ED, LD, GD, SOW, SRD]`（この順序）
- `roundTripFareTypes = [RT, SRT]`（この順序）
- `fareTypesFor(OW) = oneWayFareTypes`、`fareTypesFor(RT) = roundTripFareTypes`

## コード値

| 型 | 形式 | 例 |
| --- | --- | --- |
| `AirportCd` | 英大文字 3 文字（マスタに存在するもの）。空席照会の条件の空港コードは、入力検証を通った文字列（区切り行の `NOP` を含みうる）であり `AirportCd` とは限らない。区間の検索で見つからなければ業務エラーになる（[master-data.md](master-data.md#空港コードリスト画面用)） | `HND` |
| `FlightName` | 1〜6 文字（マスタに存在するもの）。`"`・`,`・改行を含まない（[Spec] の前提。原典の列 `FLIGHT_NAME VARCHAR(6)` に文字種の制約は無い） | `NTT001` |
| `MembershipNumber` | 数字 10 文字 | `0000000001` |
| `ReserveNo` | 数字 10 文字 | `0000000123` |
| `CreditTypeCd` | 3 文字（マスタに存在するもの） | `VIS` |
| `PasswordHash` | 不透明な文字列（[ADR 0015](../decision/0015-password-hashing-port.md)） | — |

## エンティティ

型は [Spec] の形で示す。`?` は省略可能（`Option`）。[Source] では原典の Java クラスの同名フィールドに対応し、参照型はすべて `null` になりうる。

### Flight

| フィールド | 型 | 不変条件 |
| --- | --- | --- |
| `departureDate` | Date | |
| `flightName` | FlightName | 便マスタに存在 |
| `boardingClassCd` | BoardingClassCd | |
| `fareTypeCd` | FareTypeCd | |
| `vacantNum` | Nat | 空席数。`0` もありうる |

主キー: `(departureDate, flightName, boardingClassCd, fareTypeCd)`。

### Passenger

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `familyName` | String | 姓（全角カタカナ 1〜10 文字） |
| `givenName` | String | 名（同上） |
| `age` | Nat | 0〜999 |
| `gender` | Gender | |
| `membershipNumber` | MembershipNumber? | 会員の場合のみ |

### Reservation

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `reserveNo` | ReserveNo | 登録時に採番 |
| `reserveDate` | Date | 予約日（今日） |
| `totalFare` | Nat | 合計金額 |
| `repFamilyName`, `repGivenName` | String | 予約代表者の姓名（全角カタカナ） |
| `repAge` | Nat | |
| `repGender` | Gender | |
| `repTel` | String | `tel1-tel2-tel3`（ハイフン区切り） |
| `repMail` | String | |
| `repMembershipNumber` | MembershipNumber? | |
| `reserveFlights` | [ReserveFlight] | 長さ 1（片道）または 2（往復: 往路, 復路の順） |

### ReserveFlight

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `reserveFlightNo` | Nat | 登録時に採番 |
| `reserveNo` | ReserveNo | |
| `flight` | Flight の主キー | |
| `passengers` | [Passenger] | 長さ 1〜6。**往路・復路で同一の搭乗者列**（原典は同じリストを共有する） |

各 `Passenger` は登録時に `passengerNo`（採番）を得る。

### Member

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `membershipNumber` | MembershipNumber | 登録時に採番 |
| `kanjiFamilyName`, `kanjiGivenName` | String | 全角 1〜10 文字 |
| `kanaFamilyName`, `kanaGivenName` | String | 全角カタカナ 1〜10 文字 |
| `birthday` | Date | |
| `gender` | Gender | |
| `tel` | String | `tel1-tel2-tel3` |
| `zipCode` | String | 数字 7 文字（ハイフン無し） |
| `address` | String | 全角 1〜60 文字 |
| `mail` | String | |
| `creditNo` | String | 数字 16 文字 |
| `creditTypeCd` | CreditTypeCd | |
| `creditTerm` | String | `creditMonth ++ "/" ++ creditYear`（ゼロ埋めしない）。画面の選択肢から選べば `MM/YY` になるが、サーバでは保証されない（[input-validation.md](input-validation.md#会員入力c1c2)）。[Source] の列は `VARCHAR(5)` で、6 文字以上はシステムエラー（既知差異 [D-018](abstraction.md#既知差異)） |
| `login` | MemberLogin | |

### MemberLogin

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `password` | PasswordHash | 現在のパスワード |
| `lastPassword` | PasswordHash? | 前回のパスワード |
| `loginDateTime` | Date? | 最終ログイン日（原典は `LocalDate` を `TIMESTAMP` 列に保存するため、時刻は常に 00:00） |
| `loginFlg` | Bool | ログイン中か |

## 値域

[Spec] は任意精度整数で定義するが、固定長整数で実装する移植先のために値域を定める（[ADR 0006](../decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
マスタデータと入力は次を満たすことを前提とする。入力の値域とマスタの値域（MD-8）は、[Spec] の各操作の事前条件 PRE に含める。リファインメントの証明義務は、PRE の内についてだけ課される（[ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md)）。値域の外での移植元・移植先の振る舞いは差異ではない。

| 量 | 範囲 |
| --- | --- |
| `Route.basicFare + BoardingClass.extraCharge` | `0 .. 10,000,000` |
| `PeakTime.multiplicationRatio` | `0 .. 1,000` |
| `FareType.discountRate` | `0 .. 100`（かつ `≤ childFareRate`） |
| 搭乗者数 | `1 .. 6` |
| 予約フライト数 | `1 .. 2` |
| `Flight.vacantNum` | `0 .. 2,147,483,647` |
| 年齢 | `0 .. 999` |

このとき基本運賃は `100,000,000` 以下、合計金額は `1,200,000,000` 以下であり、[Spec] の **結果** は符号付き 32 ビット整数に収まる。
ただし小児運賃の **途中計算** `b × (childFareRate − r)`（[fare-calculation.md](fare-calculation.md#合計金額)）は最大 `10,000,000,000` になり、32 ビットに収まらない。

- [Source] は、この途中計算が `2,147,483,647` を超えると int32 で折り返す（既知差異 [D-012](abstraction.md#既知差異)、課題 [ABS-005](abstraction.md#証明課題)）。値域は狭めず、差異として扱う。
- 移植先（`TargetModel`）は、途中計算に 64 ビット以上の整数を使わなければならない。
