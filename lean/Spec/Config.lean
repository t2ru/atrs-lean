import Spec.Model

/-!
# Spec.Config

業務規則に影響する設定値（`docs/spec/configuration.md`）。純粋関数・ユースケースに明示的に渡す。
既定値 `Config.default` は原典の設定ファイル（`atrs.properties`）の値である。
-/

namespace Spec

open Spec.Prim

/-- 設定値。 -/
@[spec_doc "docs/spec/configuration.md#config"]
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
@[spec_doc "docs/spec/configuration.md#config"]
def default : Config where
  limitDay := 90
  reserveIntervalTime := 120
  representativeMinAge := 18
  adultPassengerMinAge := 12
  childFareRate := 60
  dateOfBirthMinDate := ⟨1900, 1, 1, by decide⟩
  defaultFlightType := .RT
  defaultDepAirportCd := ⟨"HND"⟩
  defaultArrAirportCd := ⟨"HND"⟩
  defaultBoardingClassCd := .N

/-- 設定の不変条件。運賃種別の `discountRate ≤ childFareRate` は `MasterData.Valid`（MD-7）で課す。 -/
@[spec_doc "docs/spec/configuration.md#不変条件"]
structure Valid (c : Config) : Prop where
  childFareRate_le : c.childFareRate ≤ 100
  adultMinAge_le : c.adultPassengerMinAge ≤ c.representativeMinAge

instance (c : Config) : Decidable c.Valid :=
  decidable_of_iff (c.childFareRate ≤ 100 ∧ c.adultPassengerMinAge ≤ c.representativeMinAge)
    ⟨fun ⟨a, b⟩ => ⟨a, b⟩, fun ⟨a, b⟩ => ⟨a, b⟩⟩

theorem default_valid : default.Valid := by decide

/-! ## 画面・入力に関する定数 -/

/-- 予約画面で最初に表示する搭乗者欄の数。 -/
@[spec_doc "docs/spec/configuration.md#画面入力に関する定数"]
def initialPassengersNumber : Nat := 3

/-- 1 予約の最大搭乗者数。 -/
@[spec_doc "docs/spec/configuration.md#画面入力に関する定数"]
def maxPassengersNumber : Nat := 6

/-- 電話番号[1]+[2] の合計桁数の下限。 -/
@[spec_doc "docs/spec/configuration.md#画面入力に関する定数"]
def telAreaAndLocalMinLength : Nat := 6

/-- 電話番号[1]+[2] の合計桁数の上限。 -/
@[spec_doc "docs/spec/configuration.md#画面入力に関する定数"]
def telAreaAndLocalMaxLength : Nat := 7

end Config

end Spec
