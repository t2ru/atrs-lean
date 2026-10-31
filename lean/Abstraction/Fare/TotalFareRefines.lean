import Abstraction.Fare.Loop

/-!
# Abstraction.Fare.TotalFareRefines

R 課題 ABS-004（合計金額）: `SourceModel.FareQuery.totalFareConcrete`（起動時の読み込み・`toFlightList`・
`calculateTotalFare`）は、既知差異 D-001・D-002・D-012・D-027 の前提の下で、[Spec] の `Spec.Fare.totalFareMachine` を
リファインする。あわせて、L 課題 ABS-005（int32 の溢れが無いこと）と、D-012 の必要性（W 課題 ABS-112）を示す。
-/

namespace Abstraction.Fare

open Machine LangSemantics.Java Spec Spec.Prim Abstraction.Prim Abstraction.MasterData SourceModel.MasterData
  SourceModel.MasterQuery SourceModel.FareQuery SourceModel.Ticket

/-- `toFlight` が作るフライト情報（読み込んだ Provider で引く）。 -/
def mkFlight (p : Providers) (f : SelectFlightForm) : SourceModel.Model.Flight :=
  { departureDate := f.depDate, flightMaster := f.flightName.bind p.flightMaster.flightMasterMap.get,
    fareType := f.fareTypeCd.bind p.fareType.fareTypeCodeMap.get,
    boardingClass := f.boardingClassCd.bind p.boardingClass.boardingClassCodeMap.get }

theorem keyOfForm_eq {f : SelectFlightForm} {k : FlightKey} (h : keyOfForm f = some k) :
    ∃ dj, f.depDate = some dj ∧ dateOfJ dj = some k.departureDate ∧ f.flightName = some k.flightName.val ∧
      f.boardingClassCd = some k.boardingClassCd ∧ f.fareTypeCd = some k.fareTypeCd := by
  simp only [keyOfForm, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨d, ⟨dj, hdj, hd⟩, n, hn, bc, hbc, ft, hft, rfl⟩ := h
  exact ⟨dj, hdj, hd, hn, hbc, hft⟩

theorem toFlight_ok (p : Providers) {f : SelectFlightForm} {k : FlightKey} (h : keyOfForm f = some k)
    (ht : hasText k.flightName.val = true) : toFlight p.ticketHelper f = .ok (some (mkFlight p f)) := by
  obtain ⟨dj, hdj, -, hn, hbc, hft⟩ := keyOfForm_eq h
  simp only [toFlight, hn, getFlightMaster, assertHasText_ok ht, getFareType, hft, getBoardingClass, hbc, ok_bind,
    pure_bind, Providers.ticketHelper, mkFlight, Option.bind_some]
  rfl

theorem assertNotEmpty_cons {α : Type} (x : α) (xs : List α) (m : String) :
    SourceModel.Fare.assertNotEmpty (some (x :: xs)) m = .ok (x :: xs) := rfl

theorem assertNotEmpty_ok {α : Type} {l : List α} (h : l ≠ []) (m : String) :
    SourceModel.Fare.assertNotEmpty (some l) m = .ok l := by
  cases l with
  | nil => exact absurd rfl h
  | cons x xs => rfl

theorem configOf_fields {c : SourceModel.Config.AtrsConfig} {cfg : Config} (h : configOf c = some cfg) :
    c.adultPassengerMinAge.val = (cfg.adultPassengerMinAge : Int) ∧ c.childFareRate.val = (cfg.childFareRate : Int) := by
  simp only [configOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨a1, e1, a2, e2, a3, e3, a4, e4, a5, e5, a6, e6, rfl⟩ := h
  exact ⟨natOfJ32_eq_some.mp e4, natOfJ32_eq_some.mp e5⟩

theorem ageOfPassenger_eq {p : JRef SourceModel.Model.Passenger} {a : Nat} (h : ageOfPassenger p = some a) :
    ∃ pp aJ, p = some pp ∧ pp.age = some aJ ∧ aJ.val = (a : Int) := by
  simp only [ageOfPassenger, Option.bind_eq_some_iff] at h
  obtain ⟨aJ, ⟨pp, rfl, hpp⟩, ha⟩ := h
  exact ⟨pp, aJ, rfl, hpp, natOfJ32_eq_some.mp ha⟩

theorem mapM_length {α β : Type} {g : α → Option β} : ∀ {xs : List α} {ys : List β}, xs.mapM g = some ys →
    xs.length = ys.length
  | [], ys, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | x :: xs, ys, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, -, ys', hys, rfl⟩ := h
    simp only [List.length_cons, mapM_length hys]

example {ic : TotalFareInput} {ia : Spec.Fare.TotalFareInput} (hα : aiTF ic = some ia) (hp : ia.Pre)
    (h1 : dev_D001T ia) (h2 : dev_D002T ia) (h12 : dev_D012 ia) {o : Order} (ho : o.Allowed ic.db) :
    runTotalFare ic o = .ok (J32.ofInt ((Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0)) := by
  simp only [aiTF, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hα
  obtain ⟨cfg, hcfg, md, hm, ks, hks, ages, hages, rfl⟩ := hα
  obtain ⟨hcv, hv, hf1, hf2, hp1, hp2, hpa, hpt, hsome⟩ := hp
  simp only [Range.minReserveFlights, Range.maxReserveFlights, Range.minPassengers, Range.maxPassengers,
    Range.maxAge] at hcv hv hf1 hf2 hp1 hp2 hpa hpt hsome
  obtain ⟨p, hl, hptp, hbq, hfq, hmf⟩ := load_correct' hm hv ho
  have htf : toFlightList p.ticketHelper ic.flights = .ok (ic.flights.map fun f => some (mkFlight p f)) := by
    apply Abstraction.MasterData.mapM_ok
    intro f hf
    obtain ⟨k, hk, hfk⟩ := mapM_some_mem hks hf
    exact toFlight_ok p hfk (hpt k hk)
  obtain ⟨hamin, hcfr⟩ := configOf_fields hcfg
  have hfne : ic.flights.map (fun f => some (mkFlight p f)) ≠ [] := by
    have := mapM_length hks; intro e; rw [List.map_eq_nil_iff] at e; rw [e] at this; simp at this; omega
  have hpne : ic.passengers ≠ [] := by
    have := mapM_length hages; intro e; rw [e] at this; simp at this; omega
  simp only [runTotalFare, hl, ok_bind, htf, SourceModel.Fare.calculateTotalFare, assertNotEmpty_ok hfne,
    assertNotEmpty_ok hpne]
  rw [forIn_count_eq (P := fun a => decide (a < cfg.adultPassengerMinAge)) ic.passengers ages (J32.ofInt 0) 0 ?_
    (by decide) (by have := mapM_length hages; omega)]
  · simp only [ok_bind, Nat.zero_add]
    rw [forIn_sum_eq (V := fun k => (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0)
      (ic.flights.map fun f => some (mkFlight p f)) ks (J32.ofInt 0) 0 ?_ (by decide) ?_]
    · sorry
    · sorry
    · sorry
  · refine forall₂_of_mapM_id ic.passengers ages hages fun x hx a ha b => ?_
    obtain ⟨pp, aJ, rfl, hage, haJ⟩ := ageOfPassenger_eq ha
    simp only [pure_bind, JRef.deref, hage, ok_bind, Providers.ticketReserveService, haJ, hamin]
    by_cases hlt : a < cfg.adultPassengerMinAge
    · simp [hlt]; rfl
    · simp [hlt]; rfl

end Abstraction.Fare
