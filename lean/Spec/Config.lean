import Spec.Model

/-!
# 設定パラメータ（`Spec.Config`）

業務規則に影響する設定値。純粋関数・ユースケースに明示的に渡す。
既定値 `Config.default` は原典の設定ファイル（`atrs.properties`）の値である。

> **区分: 要約（informative）と草案（draft）の混在。** [Spec] は Lean に形式化した（[`Spec.Config`](Config.lean)。[backlog 591d](../../docs/backlog/591d-abstract-domain-types-and-master-data.md)）。本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。原典キーと出典は、`SourceModel` に形式化するまでの草案（draft）である。

**[Spec=Source]** 業務規則に影響する設定値は `Config` レコードにまとめ、純粋関数・ユースケースに明示的に渡す。
既定値は原典の設定ファイルの値である。

出典: atrs-domain/src/main/resources/META-INF/spring/atrs.properties, atrs-env/src/main/resources/META-INF/spring/atrs-infra.properties
-/

namespace Spec
open Spec.Model

open Spec.Prim

/-!
## Config

Lean: `Spec.Config`（既定値は `Spec.Config.default`）。

| フィールド | 原典キー | 型 | 既定値 | 意味 |
| --- | --- | --- | --- | --- |
| `limitDay` | `atrs.limitDay` | Nat | `90` | 照会可能限界日数。今日から何日後の搭乗日まで空席照会できるか。予約（`validateFlightList`・`reserve`）では検査しない（予約で見るのは運賃種別の予約可能期間だけ。[`Spec.Ticket`](Ticket.lean#validateflightlist)）。出典: d/service/b0/TicketSharedServiceImpl.java `getSearchLimitDate` |
| `reserveIntervalTime` | `atrs.reserveIntervalTime` | Nat（分） | `120` | 往路の到着時刻から、復路として予約可能になる出発時刻までの最小間隔 |
| `representativeMinAge` | `atrs.representativeMinAge` | Nat | `18` | 予約代表者の最小年齢 |
| `adultPassengerMinAge` | `atrs.adultPassengerMinAge` | Nat | `12` | 大人運賃が適用される最小年齢（未満は小児） |
| `childFareRate` | `atrs.childFareRate` | Nat（%） | `60` | 大人運賃に対する小児運賃の比率 |
| `dateOfBirthMinDate` | `atrs.dateOfBirthMinDate` | Date | `1900-01-01` | 会員登録できる生年月日の下限 |
| `defaultFlightType` | `default.flightType` | FlightType | `RT` | 空席照会画面の初期値 |
| `defaultDepAirportCd` | `default.depAirportCd` | AirportCd | `HND` | 空席照会画面の初期値 |
| `defaultArrAirportCd` | `default.arrAirportCd` | AirportCd | `HND` | 空席照会画面の初期値（出発と同じ値が既定である点も原典どおり） |
| `defaultBoardingClassCd` | `default.boardingClassCd` | BoardingClassCd | `N` | 空席照会画面の初期値 |
-/

/-- 設定値。 -/
@[spec_doc "lean/Spec/Config.lean#config"]
structure Config where
  /-- 照会可能限界日数。 -/
  limitDay : Nat
  /-- 往路の到着から復路の出発までの最小間隔（分）。 -/
  reserveIntervalTime : Nat
  /-- 予約代表者の最小年齢。 -/
  representativeMinAge : Nat
  /-- 大人運賃が適用される最小年齢。 -/
  adultPassengerMinAge : Nat
  /-- 小児運賃の比率（%）。 -/
  childFareRate : Nat
  /-- 会員登録できる生年月日の下限。 -/
  dateOfBirthMinDate : Date
  defaultFlightType : FlightType
  defaultDepAirportCd : AirportCd
  defaultArrAirportCd : AirportCd
  defaultBoardingClassCd : BoardingClassCd
  deriving DecidableEq

namespace Config

/-- 原典の既定値。 -/
@[spec_doc "lean/Spec/Config.lean#config"]
def default : Config where
  limitDay := 90
  reserveIntervalTime := 120
  representativeMinAge := 18
  adultPassengerMinAge := 12
  childFareRate := 60
  dateOfBirthMinDate := ⟨1900, 1, 1, by decide⟩
  defaultFlightType := .RT
  defaultDepAirportCd := { val := "HND" }
  defaultArrAirportCd := { val := "HND" }
  defaultBoardingClassCd := .N

/-!
## 不変条件

[Spec] は次を前提とする（[Source] では検査しない）。Lean: `Spec.Config.Valid`。運賃種別の条件は `Spec.MasterData.MD7` で課す。

- `childFareRate ≤ 100`（破れた場合、[Source] の合計金額の途中計算は int32 で折り返しうる。参考 [D-030](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）
- すべての運賃種別について `discountRate ≤ childFareRate`（[`Spec.Fare`](Fare.lean#合計金額) の小児運賃が負にならないため。破れた場合の [Source] の振る舞いは、参考 [D-003](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない）
- `adultPassengerMinAge ≤ representativeMinAge`
-/

/-- 設定の不変条件。運賃種別の `discountRate ≤ childFareRate` は `MasterData.Valid`（MD-7）で課す。 -/
@[spec_doc "lean/Spec/Config.lean#不変条件", gap "D-030"]
structure Valid (c : Config) : Prop where
  childFareRate_le : c.childFareRate ≤ 100
  adultMinAge_le : c.adultPassengerMinAge ≤ c.representativeMinAge

instance (c : Config) : Decidable c.Valid :=
  decidable_of_iff (c.childFareRate ≤ 100 ∧ c.adultPassengerMinAge ≤ c.representativeMinAge)
    ⟨fun ⟨a, b⟩ => ⟨a, b⟩, fun ⟨a, b⟩ => ⟨a, b⟩⟩

theorem default_valid : default.Valid := by decide

/-!
## 画面・入力に関する定数

Lean: `Spec.Config.initialPassengersNumber` ほか。

| 名前 | 値 | 意味 | 出典 |
| --- | --- | --- | --- |
| `initialPassengersNumber` | `3` | 予約画面で最初に表示する搭乗者欄の数 | atrs-web/.../app/b2/TicketReserveForm.java |
| `maxPassengersNumber` | `6` | 1 予約の最大搭乗者数 | 同上 |
| `telAreaAndLocalMinLength` | `6` | 電話番号[1]+[2] の合計桁数の下限 | atrs-domain/.../common/validate/ValidationUtil.java |
| `telAreaAndLocalMaxLength` | `7` | 同上限 | 同上 |
| `transactionTokenSizePerNamespace` | `20` | トランザクショントークンの保持数（契約外。参考） | atrs-web/.../config/web/SpringMvcConfig.java |
-/


/-- 予約画面で最初に表示する搭乗者欄の数。 -/
@[spec_doc "lean/Spec/Config.lean#画面入力に関する定数"]
def initialPassengersNumber : Nat := 3

/-- 1 予約の最大搭乗者数。 -/
@[spec_doc "lean/Spec/Config.lean#画面入力に関する定数"]
def maxPassengersNumber : Nat := 6

/-- 電話番号[1]+[2] の合計桁数の下限。 -/
@[spec_doc "lean/Spec/Config.lean#画面入力に関する定数"]
def telAreaAndLocalMinLength : Nat := 6

/-- 電話番号[1]+[2] の合計桁数の上限。 -/
@[spec_doc "lean/Spec/Config.lean#画面入力に関する定数"]
def telAreaAndLocalMaxLength : Nat := 7

end Config

end Spec
