import Abstraction.Fare.Loop

/-!
# Abstraction.Fare.TotalFareRun

R 課題 ABS-004（合計金額。`Abstraction.Fare.totalFareRefines`）と W 課題 ABS-112（`Abstraction.Fare.need_D012`）の補題。
`SourceModel.FareQuery.totalFareConcrete`（起動時の読み込み・`toFlightList`・`calculateTotalFare`）の実行と、L 課題 ABS-005
（int32 の溢れが無いこと。`runTotalFare_eq`）、D-012 の必要性の証人の実行（`runTotalFare_icTF012`）を示す。
-/

namespace Abstraction.Fare.TotalFareRun
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.BasicFareRun Abstraction.Fare.Factors Abstraction.Fare.Load Abstraction.Fare.Loop
  Abstraction.Fare.TotalAlpha Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Lookup
  Abstraction.MasterData.Pre Abstraction.MasterData.QueryRun Spec.CodeList Spec.Model
  Spec.Prim.Int Spec.Prim.Text
open LangSemantics.Java.DoubleOps
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception
  LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas

open LangSemantics.Java Spec Spec.Prim LangSemantics.Core
  SourceModel.Domain.Common.Masterdata SourceModel.MasterQuery SourceModel.FareQuery SourceModel.App.B0
  SourceModel.App.B0.TicketHelper

/-- `toFlight` が作るフライト情報（読み込んだ Provider で引く）。 -/
def mkFlight (p : Providers) (f : SelectFlightForm) : SourceModel.Domain.Model.Flight :=
  { departureDate := f.depDate, flightMaster := f.flightName.bind p.flightMaster.flightMasterMap.get,
    fareType := f.fareTypeCd.bind p.fareType.fareTypeMap.get,
    boardingClass := f.boardingClassCd.bind p.boardingClass.boardingClassCodeMap.get }

theorem keyOfForm_eq {f : SelectFlightForm} {k : FlightKey} (h : keyOfForm f = some k) :
    ∃ dj, f.depDate = some dj ∧ dateOfJ dj = some k.departureDate ∧ f.flightName = some k.flightName.val ∧
      f.boardingClassCd = some k.boardingClassCd ∧ f.fareTypeCd = some k.fareTypeCd := by
  simp only [keyOfForm, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨d, ⟨dj, hdj, hd⟩, n, ⟨sn, hn, en⟩, bc, hbc, ft, hft, rfl⟩ := h
  exact ⟨dj, hdj, hd, by rw [hn, flightNameOf_eq_some en], hbc, hft⟩

/-- 便名・搭乗クラス・運賃種別の欄があり、便名が空白でなければ、`toFlight` は `mkFlight` のフライト情報を作る。 -/
theorem toFlight_ok_of (p : Providers) {f : SelectFlightForm} {n : String} {bc : BoardingClassCd} {ft : FareTypeCd}
    (hn : f.flightName = some n) (ht : hasText n = true) (hbc : f.boardingClassCd = some bc)
    (hft : f.fareTypeCd = some ft) : toFlight (SourceModel.FareQuery.ticketHelper p) f = .ok (some (mkFlight p f)) := by
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, toFlight, hn, FlightMasterProvider.getFlightMaster, assertHasText_ok ht, FareTypeProvider.getFareType, hft, BoardingClassProvider.getBoardingClass, hbc, ok_bind,
    pure_bind, SourceModel.FareQuery.ticketHelper, mkFlight, Option.bind_some]
  rfl

theorem toFlight_ok (p : Providers) {f : SelectFlightForm} {k : FlightKey} (h : keyOfForm f = some k)
    (ht : hasText k.flightName.val = true) : toFlight (SourceModel.FareQuery.ticketHelper p) f = .ok (some (mkFlight p f)) := by
  obtain ⟨-, -, -, hn, hbc, hft⟩ := keyOfForm_eq h
  exact toFlight_ok_of p hn ht hbc hft

theorem assertNotEmpty_cons {α : Type} (x : α) (xs : List α) (m : String) :
    LangSemantics.Java.Spring.Assert.notEmptyValue (some (x :: xs)) m = .ok (x :: xs) := rfl

theorem routeOfFlightName_mem {md : MasterData} {n : FlightName} {rt : Route}
    (h : Spec.Fare.routeOfFlightName md n = some rt) : rt ∈ md.routes := by
  simp only [Spec.Fare.routeOfFlightName, Option.bind_eq_bind, Option.bind_eq_some_iff] at h
  obtain ⟨fm, -, h⟩ := h
  exact List.mem_of_find?_eq_some h

theorem boardingClassOf_mem {md : MasterData} {cd : BoardingClassCd} {bc : BoardingClass}
    (h : md.boardingClassOf cd = some bc) : bc ∈ md.boardingClasses ∧ bc.boardingClassCd = cd := by
  unfold Spec.MasterData.boardingClassOf at h
  exact ⟨List.mem_of_find?_eq_some h, by simpa using List.find?_some h⟩

theorem fareTypeOf_mem {md : MasterData} {cd : FareTypeCd} {ft : FareType}
    (h : md.fareTypeOf cd = some ft) : ft ∈ md.fareTypes := by
  unfold Spec.MasterData.fareTypeOf at h
  exact List.mem_of_find?_eq_some h

/-- 1 便の合計（[Spec]）の分解。 -/
theorem flightTotalOfKey_eq {cfg : Config} {md : MasterData} {ages : List Nat} {k : FlightKey} {v : Nat}
    (h : Spec.Fare.flightTotalOfKey cfg md ages k = some v) :
    ∃ rt bc ft, Spec.Fare.routeOfFlightName md k.flightName = some rt ∧ md.boardingClassOf k.boardingClassCd = some bc ∧
      md.fareTypeOf k.fareTypeCd = some ft ∧
      v = Spec.Fare.fare ((rt.basicFare + bc.extraCharge) * md.multiplicationRatioOn k.departureDate / 100)
          ft.discountRate * (ages.length - Spec.Fare.childNumOfAges cfg ages) +
        pct ((rt.basicFare + bc.extraCharge) * md.multiplicationRatioOn k.departureDate / 100)
          (cfg.childFareRate - ft.discountRate) * Spec.Fare.childNumOfAges cfg ages := by
  simp only [Spec.Fare.flightTotalOfKey, Spec.Fare.basicFare, Option.bind_eq_bind, Option.bind_eq_some_iff,
    Option.map_eq_some_iff, Option.pure_def, Option.some.injEq] at h
  obtain ⟨rt, hrt, b, ⟨bc, hbc, rfl⟩, ft, hft, rfl⟩ := h
  exact ⟨rt, bc, ft, hrt, hbc, hft, rfl⟩

/-- 1 便の合計（[Spec]）の上限: 基本運賃は 1 億円以下、搭乗者 1 名あたり 1 億円以下。 -/
theorem flightTotalOfKey_le {cfg : Config} {md : MasterData} (hcv : cfg.Valid) (hv : md.Valid cfg) {ages : List Nat}
    {k : FlightKey} {v : Nat} (h : Spec.Fare.flightTotalOfKey cfg md ages k = some v) :
    v ≤ 100000000 * ages.length := by
  obtain ⟨rt, bc, ft, hrt, hbc, hft, rfl⟩ := flightTotalOfKey_eq h
  have hX : rt.basicFare + bc.extraCharge ≤ 10000000 :=
    hv.md8.2.1 rt (routeOfFlightName_mem hrt) bc (boardingClassOf_mem hbc).1
  have hC := ratioOn_le hv.md8 k.departureDate
  have hcr : cfg.childFareRate ≤ 100 := hcv.childFareRate_le
  generalize (rt.basicFare + bc.extraCharge) = X at *
  generalize md.multiplicationRatioOn k.departureDate = C at *
  have hb : X * C / 100 ≤ 100000000 := by
    have := Nat.mul_le_mul hX hC
    omega
  generalize X * C / 100 = b at *
  have hf : Spec.Fare.fare b ft.discountRate ≤ 100000000 := by
    simp only [Spec.Fare.fare, Spec.Prim.Int.ceilTo, Spec.Prim.Int.pct]
    have : b * (100 - ft.discountRate) ≤ b * 100 := Nat.mul_le_mul_left _ (by omega)
    omega
  have hq : pct b (cfg.childFareRate - ft.discountRate) ≤ 100000000 := by
    simp only [Spec.Prim.Int.pct]
    have : b * (cfg.childFareRate - ft.discountRate) ≤ b * 100 := Nat.mul_le_mul_left _ (by omega)
    omega
  have hc : Spec.Fare.childNumOfAges cfg ages ≤ ages.length := by
    simp only [Spec.Fare.childNumOfAges]; exact List.length_filter_le _ _
  generalize Spec.Fare.fare b ft.discountRate = F at *
  generalize pct b (cfg.childFareRate - ft.discountRate) = Q at *
  generalize Spec.Fare.childNumOfAges cfg ages = c at *
  have e1 := Nat.mul_le_mul_right (ages.length - c) hf
  have e2 := Nat.mul_le_mul_right c hq
  have e3 : 100000000 * (ages.length - c) + 100000000 * c = 100000000 * ages.length := by
    rw [← Nat.mul_add]; congr 1; omega
  rw [Nat.mul_comm _ (ages.length - c), Nat.mul_comm _ c] at e3
  omega

theorem assertNotEmpty_ok {α : Type} {l : List α} (h : l ≠ []) (m : String) :
    LangSemantics.Java.Spring.Assert.notEmptyValue (some l) m = .ok l := by
  cases l with
  | nil => exact absurd rfl h
  | cons x xs => rfl

theorem configOf_fields {c : SourceModel.AtrsProperties.AtrsConfig} {cfg : Config} (h : configOf c = some cfg) :
    c.adultPassengerMinAge.val = (cfg.adultPassengerMinAge : Int) ∧ c.childFareRate.val = (cfg.childFareRate : Int) := by
  simp only [configOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨a1, e1, a2, e2, a3, e3, a4, e4, a5, e5, a6, e6, a7, e7, a8, e8, rfl⟩ := h
  exact ⟨natOfJ32_eq_some.mp e4, natOfJ32_eq_some.mp e5⟩

theorem ageOfPassenger_eq {p : JRef SourceModel.Domain.Model.Passenger} {a : Nat} (h : ageOfPassenger p = some a) :
    ∃ pp aJ, p = some pp ∧ pp.age = some aJ ∧ aJ.val = (a : Int) := by
  simp only [ageOfPassenger, Option.bind_eq_some_iff] at h
  obtain ⟨aJ, ⟨pp, rfl, hpp⟩, ha⟩ := h
  exact ⟨pp, aJ, rfl, hpp, natOfJ32_eq_some.mp ha⟩

/-- L 課題 ABS-005: 前提（D-001・D-002・D-012・D-027 と [Spec] の PRE）を満たす入力では、どの許される並びでも、
[Source] の合計金額の計算（読み込み・`toFlightList`・`calculateTotalFare`）は例外も int32 の溢れも無く、[Spec] の
合計金額を返す。 -/
@[obligation "ABS-005"]
theorem runTotalFare_eq {ic : TotalFareInput} {ia : Spec.Fare.TotalFareInput} (hα : aiTF ic = some ia) (hp : ia.Pre)
    (h1 : dev_D001T ia) (h2 : dev_D002T ia) (h12 : dev_D012 ia) {o : Order} (ho : o.Allowed ic.db) :
    runTotalFare ic o = .ok (J32.ofInt ((Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0)) := by
  simp only [aiTF, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hα
  obtain ⟨cfg, hcfg, md, hm, ks, hks, ages, hages, rfl⟩ := hα
  obtain ⟨hcv, hv, hf1, hf2, hp1, hp2, hpa, hpt, hsome⟩ := hp
  simp only [Range.minReserveFlights, Range.maxReserveFlights, Range.minPassengers, Range.maxPassengers,
    Range.maxAge] at hcv hv hf1 hf2 hp1 hp2 hpa hpt hsome
  obtain ⟨p, hl, hptp, hbq, hfq, hmf⟩ := load_correct' hm hv ho
  have htf : toFlightList (SourceModel.FareQuery.ticketHelper p) ic.flights = .ok (ic.flights.map fun f => some (mkFlight p f)) := by
    apply LangSemantics.Java.ResultLemmas.mapM_ok
    intro f hf
    obtain ⟨k, hk, hfk⟩ := mapM_some_mem hks hf
    exact toFlight_ok p hfk (hpt k hk)
  obtain ⟨hamin, hcfr⟩ := configOf_fields hcfg
  obtain ⟨parts, hparts⟩ : ∃ parts, ks.mapM (Spec.Fare.flightTotalOfKey cfg md ages) = some parts := by
    simp only [Spec.Fare.totalFareOfKeys, Option.bind_eq_bind, Option.isSome_iff_exists, Option.bind_eq_some_iff,
      Option.pure_def] at hsome
    obtain ⟨_, parts, hp, -⟩ := hsome
    exact ⟨parts, hp⟩
  have hVle : ∀ k ∈ ks, (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0 ≤ 100000000 * ages.length := by
    intro k hk
    obtain ⟨v, -, hv'⟩ := mapM_some_mem hparts hk
    rw [hv', Option.getD_some]
    exact flightTotalOfKey_le hcv hv hv'
  have hsum : (ks.map fun k => (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0).sum ≤ 1200000000 := by
    have := sum_map_le ks hVle
    have : ks.length * (100000000 * ages.length) ≤ 2 * (100000000 * 6) :=
      Nat.mul_le_mul hf2 (Nat.mul_le_mul_left _ hp2)
    omega
  have hfne : ic.flights.map (fun f => some (mkFlight p f)) ≠ [] := by
    have := mapM_length hks; intro e; rw [List.map_eq_nil_iff] at e; rw [e] at this; simp at this; omega
  have hpne : ic.passengers ≠ [] := by
    have := mapM_length hages; intro e; rw [e] at this; simp at this; omega
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, runTotalFare, hl, ok_bind, htf, SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare, assertNotEmpty_ok hfne,
    assertNotEmpty_ok hpne]
  rw [forIn_count_eq (P := fun a => decide (a < cfg.adultPassengerMinAge)) ic.passengers ages (J32.ofInt 0) 0 ?_
    (by decide) (by have := mapM_length hages; omega)]
  · simp only [ok_bind, Nat.zero_add]
    rw [forIn_sum_eq (V := fun k => (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0)
      (ic.flights.map fun f => some (mkFlight p f)) ks (J32.ofInt 0) 0 ?_ (by decide) ?_]
    · have htot : Spec.Fare.totalFareOfKeys cfg md ks ages =
          some (ceilTo (ks.map fun k => (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0).sum 100) := by
        simp only [Spec.Fare.totalFareOfKeys, hparts, mapM_eq_map_getD 0 hparts, Option.bind_eq_bind,
          Option.bind_some, Option.pure_def]
      rw [htot, Option.getD_some, Nat.zero_add]
      generalize (ks.map fun k => (Spec.Fare.flightTotalOfKey cfg md ages k).getD 0).sum = S at hsum ⊢
      have hS : (J32.ofInt (S : Int)).val = (S : Int) := J32.val_ofInt_of_inRange _ ⟨by
        simp only [J32.minValue]; omega, by simp only [J32.maxValue]; omega⟩
      show Except.ok _ = _
      rw [← J32.ofInt_val (SourceModel.Domain.Common.Util.FareUtil.ceilFare _), SourceModel.Domain.Common.Util.FareUtil.ceilFare,
        bdCeilHundredUp_val (by rw [hS]; omega) (by rw [hS, Int.toNat_natCast]; omega), hS, Int.toNat_natCast]
      simp only [ceilTo]
      congr 4
    · refine forall₂_of_mapM (fun f => some (mkFlight p f)) ic.flights ks hks fun f hf k hk hfk b => ?_
      obtain ⟨dj, hdj, hD, hn, hbcd, hftd⟩ := keyOfForm_eq hfk
      obtain ⟨v, -, hv'⟩ := mapM_some_mem hparts hk
      obtain ⟨rt, bc, ft, hrt, hbc, hft, hvdef⟩ := flightTotalOfKey_eq hv'
      obtain ⟨fm, r, bJ, hgfm, hfmr, hrb, hbJ⟩ := hmf k.flightName (hpt k hk) rt hrt
      have hgetfm : p.flightMaster.flightMasterMap.get k.flightName.val = some fm := by
        simp only [FlightMasterProvider.getFlightMaster, assertHasText_ok (hpt k hk), ok_bind] at hgfm
        exact Except.ok.inj hgfm
      obtain ⟨bcJ, e, hgetbc, hbccd, hex, heval⟩ := boardingClass_of_answer
        (r := p.boardingClass.boardingClassCodeMap.get k.boardingClassCd) (by rw [hbq, hbc]; rfl)
      obtain ⟨fJ, dJ, hgetft, hdr, hdval⟩ := fareType_of_answer
        (r := p.fareType.fareTypeMap.get k.fareTypeCd) (by rw [hfq, hft]; rfl)
      have hbcmem := boardingClassOf_mem hbc
      have hftmem := fareTypeOf_mem hft
      have hX : rt.basicFare + bc.extraCharge ≤ 10000000 :=
        hv.md8.2.1 rt (routeOfFlightName_mem hrt) bc hbcmem.1
      have hr100 : ft.discountRate ≤ 100 := hv.md8.2.2.2 ft hftmem
      have hrcr : ft.discountRate ≤ cfg.childFareRate := (hv.md7 ft hftmem).2.1
      have hcr : cfg.childFareRate ≤ 100 := hcv.childFareRate_le
      have hkb : keyBasic md k = some (rt.basicFare + bc.extraCharge, md.multiplicationRatioOn k.departureDate) := by
        simp only [keyBasic, hrt, hbc, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
      have hkf : keyFare md k = some ((rt.basicFare + bc.extraCharge) * md.multiplicationRatioOn k.departureDate / 100,
          ft.discountRate) := by
        simp only [keyFare, hkb, hft, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
      have hd1 := h1 k hk
      have hd2 := h2 k hk
      have hd12 := h12 k hk
      simp only [hkb, hkf, Option.all_some, decide_eq_true_eq] at hd1 hd2 hd12
      obtain ⟨vb, hcb, hvb⟩ := calculateBasicFare_eq hm hv ho.2.2.2.2.1 hptp hgetbc hex heval hbJ hD hX hd1
      have hC := ratioOn_le hv.md8 k.departureDate
      generalize md.multiplicationRatioOn k.departureDate = C at *
      generalize hXd : rt.basicFare + bc.extraCharge = X at *
      have hb8 : X * C / 100 ≤ 100000000 := by have := Nat.mul_le_mul hX hC; omega
      generalize hbd : X * C / 100 = bb at *
      simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, mkFlight, pure_bind, hn, Option.bind_some, hgetfm, JRef.deref, ok_bind, hfmr, hrb, hbcd, hgetbc,
        SourceModel.FareQuery.ticketReserveService, hftd, hgetft, hdr]
      rw [hbccd, hbcmem.2, hdj, hcb, ok_bind,
        calculateFare_ok (b := bb) (r := ft.discountRate) hvb hdval hr100, ok_bind]
      have hsub := j32sub_nat (x := cfg.childFareRate) (y := ft.discountRate) hcfr hdval hrcr (by omega)
      have hmul := j32mul_nat hvb hsub hd12
      obtain ⟨cp, hcp, hcpv⟩ := jdiv32_nat hmul
      rw [hcp, ok_bind]
      simp only [pure_bind]
      -- 値
      have hlen : ic.passengers.length = ages.length := mapM_length hages
      rw [hlen]
      generalize hcnt : (List.filter (fun a => decide (a < cfg.adultPassengerMinAge)) ages).length = cnt
      have hcl : cnt ≤ ages.length := by rw [← hcnt]; exact List.length_filter_le _ _
      have hBF : (bdCeilHundredUp (jd2i (jdmul (jd (bb : Int)) (fareFactor ft.discountRate)))).val =
          (Spec.Fare.fare bb ft.discountRate : Int) :=
        fare_src_eq' hr100 (by omega) (Nat.lt_of_le_of_lt (Nat.mul_le_mul hb8 (Nat.sub_le 100 _)) (by decide)) hd2
      have hF : Spec.Fare.fare bb ft.discountRate ≤ 100000000 := by
        simp only [Spec.Fare.fare, Spec.Prim.Int.ceilTo, Spec.Prim.Int.pct]
        have : bb * (100 - ft.discountRate) ≤ bb * 100 := Nat.mul_le_mul_left _ (by omega)
        omega
      have hQ : bb * (cfg.childFareRate - ft.discountRate) / 100 ≤ 100000000 := by
        have : bb * (cfg.childFareRate - ft.discountRate) ≤ bb * 100 := Nat.mul_le_mul_left _ (by omega)
        omega
      have hadult := j32sub_nat (ofInt_nat (x := ages.length) (by omega)) (ofInt_nat (x := cnt) (by omega)) hcl
        (by omega)
      have e1 : Spec.Fare.fare bb ft.discountRate * (ages.length - cnt) ≤ 100000000 * 6 :=
        Nat.mul_le_mul hF (by omega)
      have e2 : bb * (cfg.childFareRate - ft.discountRate) / 100 * cnt ≤ 100000000 * 6 :=
        Nat.mul_le_mul hQ (by omega)
      have hm1 := j32mul_nat hBF hadult (by omega)
      have hm2 := j32mul_nat hcpv (ofInt_nat (x := cnt) (by omega)) (by omega)
      have hsum := j32add_nat hm1 hm2 (by omega)
      rw [← J32.ofInt_val (j32add (j32mul _ _) _), hsum, hv', Option.getD_some, hvdef]
      simp only [Spec.Fare.childNumOfAges, hcnt, ← hXd, ← hbd, Spec.Prim.Int.pct]
      rfl
    · simp only [Nat.zero_add]; omega
  · refine forall₂_of_mapM_id ic.passengers ages hages fun x hx a _ ha b => ?_
    obtain ⟨pp, aJ, rfl, hage, haJ⟩ := ageOfPassenger_eq ha
    simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, pure_bind, JRef.deref, hage, ok_bind, SourceModel.FareQuery.ticketReserveService, haJ, hamin]
    by_cases hlt : a < cfg.adultPassengerMinAge
    · simp [hlt]; rfl
    · simp [hlt]; rfl

/-- [Spec] の合計金額は 12 億円以下（予約フライト 2・搭乗者 6 名・基本運賃 1 億円以下）。 -/
theorem totalFareOfKeys_le {ia : Spec.Fare.TotalFareInput} (hp : ia.Pre) :
    (Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0 ≤ 1200000000 := by
  obtain ⟨hcv, hv, -, hf2, -, hp2, -, -, hsome⟩ := hp
  simp only [Range.maxReserveFlights, Range.maxPassengers] at hf2 hp2
  obtain ⟨parts, hparts⟩ : ∃ parts, ia.flights.mapM (Spec.Fare.flightTotalOfKey ia.cfg ia.md ia.ages) = some parts := by
    simp only [Spec.Fare.totalFareOfKeys, Option.bind_eq_bind, Option.isSome_iff_exists, Option.bind_eq_some_iff,
      Option.pure_def] at hsome
    obtain ⟨_, parts, hp, -⟩ := hsome
    exact ⟨parts, hp⟩
  have hVle : ∀ k ∈ ia.flights, (Spec.Fare.flightTotalOfKey ia.cfg ia.md ia.ages k).getD 0 ≤ 100000000 * ia.ages.length := by
    intro k hk
    obtain ⟨v, -, hv'⟩ := mapM_some_mem hparts hk
    rw [hv', Option.getD_some]
    exact flightTotalOfKey_le hcv hv hv'
  have hsum := sum_map_le ia.flights hVle
  have : ia.flights.length * (100000000 * ia.ages.length) ≤ 2 * (100000000 * 6) :=
    Nat.mul_le_mul hf2 (Nat.mul_le_mul_left _ hp2)
  simp only [Spec.Fare.totalFareOfKeys, hparts, mapM_eq_map_getD 0 hparts, Option.bind_eq_bind, Option.bind_some,
    Option.pure_def, Option.getD_some, ceilTo]
  generalize (ia.flights.map fun k => (Spec.Fare.flightTotalOfKey ia.cfg ia.md ia.ages k).getD 0).sum = S at *
  omega

/-- `icTF012` の [Source] の合計金額は 17,050,400 円（小児分の途中計算 `100,000,000 × 60` が int32 で折り返す）。 -/
theorem runTotalFare_icTF012 : runTotalFare icTF012 (mergeOrder icTF012.db) = .ok (J32.ofInt 17050400) := by
  have ht : hasText "NTT001" = true := by rw [hasText, string_any_toList]; decide
  have hA : ∀ m, LangSemantics.Java.Spring.Assert.hasText "NTT001" m = .ok () := fun m => assertHasText_ok ht m
  have hfl : icTF012.flights = [⟨some ⟨1970, 1, 1, by decide⟩, some "NTT001", some .OW, some .N⟩] := rfl
  simp only [runTotalFare, hfl, toFlightList, List.mapM_cons, List.mapM_nil, toFlight, pure_bind, FlightMasterProvider.getFlightMaster, hA,
    ok_bind]
  rfl

end Abstraction.Fare.TotalFareRun
