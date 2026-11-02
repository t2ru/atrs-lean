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
open Spec.Config Spec.Model Spec.Prim.Int Spec.Prim.Text

open Spec.Prim Spec.MasterData

/-- 基本運賃。`floorDiv((routeBasicFare + extra) * ratio, 100)`。搭乗クラスがマスタに無ければ `none`（PRE: `BasicFareInput.Pre`。MD-3 は搭乗クラスの存在を課さない）。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃", gap "D-001"]
def basicFare (md : MasterData) (routeBasicFare : Nat) (cd : BoardingClassCd) (depDate : Date) : Option Nat :=
  (md.boardingClassOf cd).map fun bc => (routeBasicFare + bc.extraCharge) * md.multiplicationRatioOn depDate / 100

/-- 運賃（大人 1 名・1 区間）。基本運賃に `(100 − discountRate)`% を掛けて 1 円未満を切り捨て、100 円単位に切り上げる。 -/
@[spec_doc "docs/spec/fare-calculation.md#運賃", gap "D-002"]
def fare (basicFare discountRate : Nat) : Nat :=
  ceilTo (pct basicFare (100 - discountRate)) 100

/-- 便名の区間（便マスタの区間番号で引く）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def routeOfFlightName (md : MasterData) (name : FlightName) : Option Route := do
  let fm ← md.flightMasterOf name
  md.routes.find? fun r => r.routeNo == fm.routeNo

/-- 便の区間。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def routeOfFlight (md : MasterData) (f : Flight) : Option Route := routeOfFlightName md f.key.flightName

/-- 小児（`age < adultPassengerMinAge`）の人数（搭乗者の年齢の列から）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def childNumOfAges (cfg : Config) (ages : List Nat) : Nat :=
  (ages.filter fun a => decide (a < cfg.adultPassengerMinAge)).length

/-- 小児（`age < adultPassengerMinAge`）の人数。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def childNum (cfg : Config) (passengers : List Passenger) : Nat := childNumOfAges cfg (passengers.map (·.age))

/-- 1 便の合計（100 円単位の切上げ前）。フライトのキーと搭乗者の年齢の列から決まる。
小児 1 名分は `floorDiv(b * (childFareRate − r), 100)`。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額", gap "D-003", "D-012"]
def flightTotalOfKey (cfg : Config) (md : MasterData) (ages : List Nat) (k : FlightKey) : Option Nat := do
  let route ← routeOfFlightName md k.flightName
  let b ← basicFare md route.basicFare k.boardingClassCd k.departureDate
  let ft ← md.fareTypeOf k.fareTypeCd
  let r := ft.discountRate
  let child := childNumOfAges cfg ages
  let adult := ages.length - child
  return fare b r * adult + pct b (cfg.childFareRate - r) * child

/-- 1 便の合計（100 円単位の切上げ前）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def flightTotal (cfg : Config) (md : MasterData) (passengers : List Passenger) (f : Flight) : Option Nat :=
  flightTotalOfKey cfg md (passengers.map (·.age)) f.key

/-- 合計金額（フライトのキーの列と搭乗者の年齢の列から）。100 円単位の切上げは合計にだけ行う。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def totalFareOfKeys (cfg : Config) (md : MasterData) (keys : List FlightKey) (ages : List Nat) : Option Nat := do
  let parts ← keys.mapM (flightTotalOfKey cfg md ages)
  return ceilTo parts.sum 100

/-- 合計金額。すべてのフライトに同じ搭乗者列が搭乗する。100 円単位の切上げは合計にだけ行う。
マスタに便・区間・搭乗クラス・運賃種別が無ければ `none`（PRE: `TotalFareInput.Pre` の `totalFareOfKeys` の連言。MD-3 は区間の空港と便マスタの区間だけを課す）。合計金額が観測するのは、フライトのキーと
搭乗者の年齢だけである（`totalFare`＝`totalFareOfKeys`）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def totalFare (cfg : Config) (md : MasterData) (flights : List Flight) (passengers : List Passenger) : Option Nat :=
  totalFareOfKeys cfg md (flights.map (·.key)) (passengers.map (·.age))

theorem totalFare_eq (cfg : Config) (md : MasterData) (flights : List Flight) (passengers : List Passenger) :
    totalFare cfg md flights passengers = totalFareOfKeys cfg md (flights.map (·.key)) (passengers.map (·.age)) := rfl

/-! ## 抽象機械（R 課題 ABS-001・ABS-002 の抽象側） -/

/-- 基本運賃の入力。マスタ・設定は不変の入力である。 -/
structure BasicFareInput where
  cfg : Config
  md : MasterData
  routeBasicFare : Nat
  boardingClassCd : BoardingClassCd
  depDate : Date

/-- 基本運賃の PRE: 設定とマスタの不変条件、搭乗クラスがマスタに在ること、
`routeBasicFare + extraCharge` の値域（`docs/spec/domain-model.md#値域`）。 -/
@[spec_doc "docs/spec/fare-calculation.md#基本運賃", gap "D-035"]
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
@[spec_doc "docs/spec/fare-calculation.md#運賃", gap "D-030"]
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

/-- 合計金額の入力: 設定・マスタ・フライトのキーの列・搭乗者の年齢の列。 -/
structure TotalFareInput where
  cfg : Config
  md : MasterData
  flights : List FlightKey
  ages : List Nat

/-- 合計金額の PRE: 設定とマスタの不変条件、予約フライト数（1〜2）と搭乗者数（1〜6）と年齢（0〜999）の値域、
便名が空白でないこと（原典の `Assert.hasText`）、各フライトの便マスタ・区間・搭乗クラス・運賃種別がマスタに在ること。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額", gap "D-035"]
def TotalFareInput.Pre (i : TotalFareInput) : Prop :=
  i.cfg.Valid ∧ i.md.Valid i.cfg ∧
    Range.minReserveFlights ≤ i.flights.length ∧ i.flights.length ≤ Range.maxReserveFlights ∧
    Range.minPassengers ≤ i.ages.length ∧ i.ages.length ≤ Range.maxPassengers ∧
    (∀ a ∈ i.ages, a ≤ Range.maxAge) ∧
    (∀ k ∈ i.flights, hasText k.flightName.val = true) ∧
    (totalFareOfKeys i.cfg i.md i.flights i.ages).isSome = true

instance (i : TotalFareInput) : Decidable i.Pre := by unfold TotalFareInput.Pre; infer_instance

/-- 合計金額の抽象機械（状態を持たない）。 -/
@[spec_doc "docs/spec/fare-calculation.md#合計金額"]
def totalFareMachine : Machine.Machine Unit TotalFareInput Nat :=
  Machine.Machine.pure TotalFareInput.Pre fun i => (totalFareOfKeys i.cfg i.md i.flights i.ages).getD 0

/-- SPEC-001。 -/
@[obligation "SPEC-001"]
theorem totalFareMachine_run_step :
    ∀ s i, totalFareMachine.Pre s i → totalFareMachine.step s i (totalFareMachine.run s i).1 (totalFareMachine.run s i).2 :=
  totalFareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem totalFareMachine_sound : totalFareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem totalFareMachine_initIs : totalFareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- PRE の下で、基本運賃は値を持つ。 -/
theorem basicFare_isSome {i : BasicFareInput} (h : i.Pre) :
    (basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).isSome = true := by
  obtain ⟨-, -, h⟩ := h
  unfold basicFare
  cases hb : i.md.boardingClassOf i.boardingClassCd <;> simp_all

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1100 円（[Source] は 1000 円）。 -/
theorem fare_1430_30 : fare 1430 30 = 1100 := by decide

end Spec.Fare
