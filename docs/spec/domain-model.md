---
type: Specification
title: "ドメインモデル"
description: "型・列挙・値域・不変条件と、仕様全体で使う基本演算（除算・丸め・暦日・書式）の定義。"
tags: [spec, domain-model, types]
status: draft
spec_role: [informative, draft]
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# ドメインモデル

> **区分: 要約（informative）と草案（draft）の混在。** [Spec] の定義は Lean `Spec` に形式化した（[backlog 591d](../backlog/591d-abstract-domain-types-and-master-data.md)）。各節の本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。**[Source]** と書いた記述は、`SourceModel` に形式化するまでの草案（draft）である。

## 基本演算（Spec.Prim）

**[Spec]** Lean: [`Spec.Prim.Int`](../../lean/Spec/Prim/Int.lean)。引数は数学的整数で、溢れは無い。

| 演算 | 事前条件 | 要約 |
| --- | --- | --- |
| `floorDiv(a, b)` | `b > 0` | 床除算（`floorDiv_eq_iff` で特徴付け） |
| `ceilDiv(a, b)` | `b > 0` | 天井除算 |
| `ceilTo(a, m)` | `a ≥ 0`, `m > 0` | `a` 以上の `m` の倍数のうち最小のもの（`ceilTo_le_of_dvd`） |
| `pct(a, r)` | `a ≥ 0`, `r ≥ 0` | `a` の `r`% の切捨て |

**[Source]**（draft）の基本演算（`j32add`, `jdiv32`, `jdmul`, `jd2i`, `bdCeilHundredUp`, `utf16Len` など）は [ADR 935b](../decision/935b-java-primitive-semantics.md) に定義する。
[Source] の Java 参照型（`Integer` 等）が `null` のまま演算された場合は、その操作の結果を `PreconditionViolation("NullPointerException")` とする。

## 暦日と時刻

**[Spec=Source]**（[ADR 6eb2](../decision/6eb2-date-and-time-model.md)）[Spec] の Lean: [`Spec.Prim.Date`](../../lean/Spec/Prim/Date.lean)、[`Spec.Prim.Time`](../../lean/Spec/Prim/Time.lean)。

### Date

- `Date`: 先発グレゴリオ暦の年月日（年 1〜9999）。妥当性を型で保証する。
- 通算日数 `ordinal`（0001-01-01 を 0）と `epochDay`（1970-01-01 を 0）で比較・加減算する。順序は年月日の辞書順と一致する（`lt_iff_lex`）。
- `addDays(d, n)` は `epochDay` 上の加算で、範囲外なら無し。`daysBetween(a, b)` は `b − a` の日数。
- `fullYearsBetween(b, d)` は満年齢。誕生日の到来を `(month, day)` の辞書順で判定するので、閏日生まれは平年の 2 月 28 日には加齢せず 3 月 1 日に加齢する。`d < b` のときの値は使わない。
- 閏年・月末・年越しの境界は、Lean の例と、0001-01-01〜9999-12-31 の全日の検査（`lake exe long-tests`。`lean/Tests/DateExhaustive.lean`）で確かめている。

### HourMinute

- `HourMinute`: 時（0〜23）と分（0〜59）。分換算 `toMinutes`。
- 原典の便マスタは時刻を 4 桁文字列 `HHmm`（例 `"0945"`）で持つ。`parseHHmm` は、4 文字の数字列で時分の範囲内のものだけを受け付ける。

### ArrivalTime

- `ArrivalTime`: 便マスタの到着時刻。出発日 0:00 からの時（0〜47）と分（0〜59）で、24 時以降は翌日着を表す（例 `24:15` は翌日 0:15。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。分換算 `toMinutes`。
- `ArrivalTime.parseHHmm` は、4 文字の数字列で到着時刻の範囲内のものだけを受け付ける（上流のシードの `2415` を含む）。

### DateTime

- `DateTime`: `Date` と時・分・秒。`toEpochMinutes` は 1970-01-01 0:00 からの分数。
- 「日付 d と時刻 t の日時」`at(d, t)` は Lean の `DateTime.atTime`。

### 書式

**[Spec]** Lean: [`Spec.Prim.Format`](../../lean/Spec/Prim/Format.lean)。いずれもゼロ埋めの固定桁である。

| 名前 | 形式 | 例 |
| --- | --- | --- |
| `fmtDate` | `yyyy/MM/dd` | `2026/10/29` |
| `fmtIsoDate` | `yyyy-MM-dd`（JSON・テストベクタ） | `2026-10-29` |
| `fmtTime` | `HH:mm` | `09:45` |
| `fmtArrTime` | `HH:mm`（到着時刻。24 時以降はそのまま） | `24:15` |
| `fmtTimestamp` | `yyyyMMddHHmmss` | `20261029213809` |
| `fmtYen` | 3 桁区切り（`###,###`） | `28,800` |
| `fmtPaymentDate` | `MM月dd日(E)`。曜日は日本語の 1 文字、括弧は半角 | `11月10日(火)` |

適合テストベクタは `conformance/shared/format/`（[conformance.md](conformance.md#操作名)）。

**[Source]**（draft）原典 `DateTimeUtil.toFormatTimeString` は、長さ 3 以上の文字列 s を `s[0..2] ++ ":" ++ s[2..]` とする。`fmtPaymentDate` に当たる `#temporals.format(paymentDate,'MM月dd日(E)')` は要求の `Accept-Language` に従い、英語なら `Wed` などになる。予約入力・予約確認・予約失敗の画面の搭乗日（`#temporals.format(departureDate,'MM月dd日(E)')`）も同じ（既知差異 [D-019](abstraction.md#既知差異)）。

## 列挙

**[Spec=Source]** Lean: [`Spec.Model`](../../lean/Spec/Model.lean)。列挙値の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（Lean の `toCode`・`ofCode?`）。

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

**[Spec]** Lean: [`Spec.Model`](../../lean/Spec/Model.lean)。`String` を包む structure で、形式は述語 `WellFormed` で表す。マスタに存在することは、マスタの参照関数と不変条件で表す（[master-data.md](master-data.md)）。

| 型 | 形式 | 例 |
| --- | --- | --- |
| `AirportCd` | 英大文字 3 文字（マスタに存在するもの）。空席照会の条件の空港コードは、入力検証を通った文字列（区切り行の `NOP` を含みうる）であり `AirportCd` とは限らない。区間の検索で見つからなければ業務エラーになる（[master-data.md](master-data.md#空港コードリスト画面用)） | `HND` |
| `FlightName` | 1〜6 文字（マスタに存在するもの）。`"`・`,`・改行を含まない（[Spec] の前提。原典の列 `FLIGHT_NAME VARCHAR(6)` に文字種の制約は無い）。マスタの参照の問い合わせでは、空白でない（`hasText`）ことも課す | `NTT001` |
| `MembershipNumber` | 数字 10 文字 | `0000000001` |
| `ReserveNo` | 数字 10 文字 | `0000000123` |
| `CreditTypeCd` | 3 文字（マスタに存在するもの） | `VIS` |
| `PasswordHash` | 不透明な文字列（[ADR 2d1f](../decision/2d1f-password-hashing-port.md)） | — |

## エンティティ

**[Spec]** Lean: [`Spec.Model`](../../lean/Spec/Model.lean)。型は [Spec] の形で示す。`?` は省略可能（`Option`）。[Source] では原典の Java クラスの同名フィールドに対応し、参照型はすべて `null` になりうる。

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

[Spec] は任意精度整数で定義するが、固定長整数で実装する移植先のために値域を定める（[ADR e41d](../decision/e41d-exact-integer-arithmetic-in-abstract-model.md)）。上限の値は Lean の `Spec.Range`（[`Spec.Model`](../../lean/Spec/Model.lean)）にある。マスタの値域は `MasterData.MD8`（[master-data.md](master-data.md#不変条件spec)）である。
マスタデータと入力は次を満たすことを前提とする。入力の値域とマスタの値域（MD-8）は、[Spec] の各操作の事前条件 PRE に含める。入口の機械（画面・REST・レポート要求の受信）では、入力の値域とマスタの値域を環境の前提（`@[env_pre]`）に含め、その下で PRE が成り立つことを示す（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)、[abstraction.md](abstraction.md#入口の-r-課題)）。リファインメントの証明義務は、PRE の内についてだけ課される（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)）。値域の外での移植元・移植先の振る舞いは差異ではない。

| 量 | 範囲 |
| --- | --- |
| 空港コード（マスタの `Airport.code`） | 英大文字 3 文字（`AirportCd.WellFormed`）で、コードリストの区切り行のコード `NOP` でない |
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
