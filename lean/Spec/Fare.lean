import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData

/-!
# Spec.Fare

運賃計算（`docs/spec/fare-calculation.md`）。厳密整数で計算する（ADR 0006）。
[Source] との差異は D-001・D-002・D-012（`docs/spec/abstraction.md#既知差異`）で、
リファインメントの証明は backlog 0005 で行う。
-/

namespace Spec.Fare

open Spec.Prim Spec.MasterData

/-- 基本運賃。`floorDiv((routeBasicFare + extra) * ratio, 100)`。搭乗クラスがマスタに無ければ `none`（PRE: MD-3）。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def basicFare (md : MasterData) (routeBasicFare : Nat) (cd : BoardingClassCd) (depDate : Date) : Option Nat :=
  (md.boardingClassOf cd).map fun bc => (routeBasicFare + bc.extraCharge) * md.multiplicationRatioOn depDate / 100

/-- 運賃（大人 1 名・1 区間）。基本運賃に `(100 − discountRate)`% を掛けて 1 円未満を切り捨て、100 円単位に切り上げる。 -/
@[spec_doc "docs/spec/fare-calculation.md#運賃"]
def fare (basicFare discountRate : Nat) : Nat :=
  ceilTo (pct basicFare (100 - discountRate)) 100

/-- 便の区間（便マスタの区間番号で引く）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def routeOfFlight (md : MasterData) (f : Flight) : Option Route := do
  let fm ← md.flightMasterOf f.key.flightName
  md.routes.find? fun r => r.routeNo == fm.routeNo

/-- 小児（`age < adultPassengerMinAge`）の人数。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def childNum (cfg : Config) (passengers : List Passenger) : Nat :=
  (passengers.filter fun p => decide (p.age < cfg.adultPassengerMinAge)).length

/-- 1 便の合計（100 円単位の切上げ前）。小児 1 名分は `floorDiv(b * (childFareRate − r), 100)`。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def flightTotal (cfg : Config) (md : MasterData) (passengers : List Passenger) (f : Flight) : Option Nat := do
  let route ← routeOfFlight md f
  let b ← basicFare md route.basicFare f.key.boardingClassCd f.key.departureDate
  let ft ← md.fareTypeOf f.key.fareTypeCd
  let r := ft.discountRate
  let child := childNum cfg passengers
  let adult := passengers.length - child
  return fare b r * adult + pct b (cfg.childFareRate - r) * child

/-- 合計金額。すべてのフライトに同じ搭乗者列が搭乗する。100 円単位の切上げは合計にだけ行う。
マスタに便・区間・搭乗クラス・運賃種別が無ければ `none`（PRE: MD-3）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def totalFare (cfg : Config) (md : MasterData) (flights : List Flight) (passengers : List Passenger) : Option Nat := do
  let parts ← flights.mapM (flightTotal cfg md passengers)
  return ceilTo parts.sum 100

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1100 円（[Source] は 1000 円）。 -/
theorem fare_1430_30 : fare 1430 30 = 1100 := by decide

end Spec.Fare
