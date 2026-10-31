import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData

/-!
# Spec.Fare

運賃計算（`docs/spec/fare-calculation.md`）。厳密整数で計算する（ADR e41d）。
[Source] との差異は D-001・D-002・D-012（`docs/spec/abstraction.md#既知差異`）で、
リファインメントの証明は backlog bbcc で行う。
-/

namespace Spec.Fare

open Spec.Prim Spec.MasterData

/-- 基本運賃。`floorDiv((routeBasicFare + extra) * ratio, 100)`。搭乗クラスがマスタに無ければ `none`（PRE: MD-3）。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃", gap "D-001"]
def basicFare (md : MasterData) (routeBasicFare : Nat) (cd : BoardingClassCd) (depDate : Date) : Option Nat :=
  (md.boardingClassOf cd).map fun bc => (routeBasicFare + bc.extraCharge) * md.multiplicationRatioOn depDate / 100

/-- 運賃（大人 1 名・1 区間）。基本運賃に `(100 − discountRate)`% を掛けて 1 円未満を切り捨て、100 円単位に切り上げる。 -/
@[spec_doc "docs/spec/fare-calculation.md#運賃", gap "D-002"]
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
@[spec_doc "docs/spec/fare-calculation.md#合計金額", gap "D-003", "D-012"]
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

/-! ## 抽象機械（R 課題 ABS-001・ABS-002 の抽象側） -/

/-- 基本運賃の入力。マスタ・設定は不変の入力である。 -/
structure BasicFareInput where
  cfg : Config
  md : MasterData
  routeBasicFare : Nat
  boardingClassCd : BoardingClassCd
  depDate : Date

/-- 基本運賃の PRE: 設定とマスタの不変条件、搭乗クラスがマスタに在ること（MD-3）、
`routeBasicFare + extraCharge` の値域（`docs/spec/domain-model.md#値域`）。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def BasicFareInput.Pre (i : BasicFareInput) : Prop :=
  i.cfg.Valid ∧ i.md.Valid i.cfg ∧
    (i.md.boardingClassOf i.boardingClassCd).any (fun bc => decide (i.routeBasicFare + bc.extraCharge ≤ Range.maxBasicFareWithCharge)) = true

instance (i : BasicFareInput) : Decidable i.Pre := by unfold BasicFareInput.Pre; infer_instance

/-- 基本運賃の抽象機械（状態を持たない）。PRE の下で、`basicFare` は値を持つ。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def basicFareMachine : Machine.Machine Unit BasicFareInput Nat :=
  Machine.Machine.pure BasicFareInput.Pre fun i => (basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).getD 0

/-- 運賃の入力。 -/
structure FareInput where
  basicFare : Nat
  discountRate : Nat

/-- 運賃の PRE: 基本運賃と割引率の値域。 -/
@[spec_doc "docs/spec/fare-calculation.md#運賃"]
def FareInput.Pre (i : FareInput) : Prop := i.basicFare ≤ Range.maxBasicFare ∧ i.discountRate ≤ Range.maxDiscountRate

instance (i : FareInput) : Decidable i.Pre := by unfold FareInput.Pre; infer_instance

/-- 運賃の抽象機械（状態を持たない）。 -/
@[spec_doc "docs/spec/fare-calculation.md#運賃"]
def fareMachine : Machine.Machine Unit FareInput Nat :=
  Machine.Machine.pure FareInput.Pre fun i => fare i.basicFare i.discountRate

/-- SPEC-001: PRE の下で、標準の選択は関係に含まれる。 -/
@[obligation "SPEC-001"]
theorem basicFareMachine_run_step :
    ∀ s i, basicFareMachine.Pre s i → basicFareMachine.step s i (basicFareMachine.run s i).1 (basicFareMachine.run s i).2 :=
  basicFareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem basicFareMachine_sound : basicFareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem basicFareMachine_initIs : basicFareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- SPEC-001。 -/
@[obligation "SPEC-001"]
theorem fareMachine_run_step :
    ∀ s i, fareMachine.Pre s i → fareMachine.step s i (fareMachine.run s i).1 (fareMachine.run s i).2 :=
  fareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem fareMachine_sound : fareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem fareMachine_initIs : fareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- PRE の下で、基本運賃は値を持つ。 -/
theorem basicFare_isSome {i : BasicFareInput} (h : i.Pre) :
    (basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).isSome = true := by
  obtain ⟨-, -, h⟩ := h
  unfold basicFare
  cases hb : i.md.boardingClassOf i.boardingClassCd <;> simp_all

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1100 円（[Source] は 1000 円）。 -/
theorem fare_1430_30 : fare 1430 30 = 1100 := by decide

end Spec.Fare
