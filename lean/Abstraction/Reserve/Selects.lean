import Abstraction.Reserve.ValidateFlights
import Abstraction.Reserve.Input
import Abstraction.Reserve.Select
import SourceModel.App.B2.TicketReserveHelper

/-!
# Abstraction.Reserve.Selects

ABS-041 の補題: 予約の前段の選択フライトの検証（`TicketReserveHelper.validateFlightList`）と、[Spec] の `checkSelects`
の対応（backlog aedf の第 3 段）。原典は `InvalidFlightException` と業務例外を `BadRequestException` に包み、[Spec] は
選択フライトの検証の失敗をすべて改竄（`InvalidRequest`）とする（`asInvalidRequest`）。
-/

namespace Abstraction.Reserve.Selects
open Spec.Reserve.FlightSelection Spec.Error

/-- 改竄に写るエラー（`InvalidRequest` か `Business`）。 -/
def IsReq (e : AtrsError) : Prop := ∃ s, Spec.Reserve.asInvalidRequest e = .invalidRequest s

theorem isReq_invalid (s : String) : IsReq (.invalidRequest s) := ⟨s, rfl⟩

theorem isReq_business (be : BusinessError) : IsReq (.business be) := ⟨be.code, rfl⟩

theorem checkFlight_req {w : Spec.World} {f : Option ResolvedFlight} {m : Except AtrsError ResolvedFlight}
    (h : checkFlight w f = m) : ∀ e, m = .error e → IsReq e := by
  intro e he
  subst h
  unfold checkFlight at he
  split at he
  · cases he; exact isReq_invalid _
  · split at he <;> cases he; exact isReq_invalid _

theorem checkInterval_req {cfg : Spec.Env.Config} {o h' : Spec.Model.FlightKey} {om hm : Spec.Env.MasterData.FlightMaster}
    {e : AtrsError} (h : checkInterval cfg o om h' hm = .error e) : IsReq e := by
  unfold checkInterval at h; split at h <;> cases h; exact isReq_business _

theorem checkFareTypes_req {ks : List Spec.Model.FlightKey} {e : AtrsError} (h : checkFareTypes ks = .error e) :
    IsReq e := by
  unfold checkFareTypes at h
  split at h
  · split at h <;> cases h; exact isReq_invalid _
  · split at h
    · cases h; exact isReq_invalid _
    · split at h <;> cases h; exact isReq_invalid _
  · cases h; exact isReq_invalid _

theorem checkReverse_req {md : Spec.Env.MasterData} {om hm : Spec.Env.MasterData.FlightMaster} {r : Except AtrsError Unit}
    (h : checkReverse md om hm = some r) : ∀ e, r = .error e → IsReq e := by
  intro e he
  unfold checkReverse at h
  cases h1 : routeOfMaster md om <;> cases h2 : routeOfMaster md hm <;>
    simp only [h1, h2, Option.bind_eq_bind, Option.bind_none, Option.bind_some, reduceCtorEq, Option.pure_def,
      Option.some.injEq] at h
  subst h
  split at he <;> cases he
  exact isReq_invalid _

/-- 選択フライトの検証の失敗は、改竄に写る。 -/
theorem validateFlightList_req {cfg : Spec.Env.Config} {md : Spec.Env.MasterData} {w : Spec.World}
    {fs : List (Option ResolvedFlight)} {x : Except AtrsError (Itinerary Spec.Model.FlightKey)}
    (h : validateFlightList cfg md w fs = some x) : ∀ e, x = .error e → IsReq e := by
  intro e he
  unfold validateFlightList at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    rename_i o
    cases hc : checkFlight w o with
    | error e' => simp only [hc, bind, Except.bind] at he; cases he; exact checkFlight_req hc _ rfl
    | ok m =>
      cases hf : checkFareTypes [m.key] with
      | error e' => simp only [hc, hf, bind, Except.bind] at he; cases he; exact checkFareTypes_req hf
      | ok u => simp [hc, hf, bind, Except.bind, pure, Except.pure] at he
  · rename_i o h0
    cases hc : checkFlight w o with
    | error e' => simp only [hc, Option.some.injEq] at h; subst h; cases he; exact checkFlight_req hc _ rfl
    | ok om =>
      cases hc' : checkFlight w h0 with
      | error e' => simp only [hc, hc', Option.some.injEq] at h; subst h; cases he; exact checkFlight_req hc' _ rfl
      | ok hm =>
        cases hi : checkInterval cfg om.key om.master hm.key hm.master with
        | error e' => simp only [hc, hc', hi, Option.some.injEq] at h; subst h; cases he; exact checkInterval_req hi
        | ok u =>
          cases u
          simp only [hc, hc', hi, Option.bind_eq_bind, Option.pure_def] at h
          cases hr : checkReverse md om.master hm.master with
          | none => simp [hr] at h
          | some r =>
            simp only [hr, Option.bind_some, Option.some.injEq] at h
            subst h
            cases r with
            | error e' => cases he; exact checkReverse_req hr _ rfl
            | ok u =>
              cases hf : checkFareTypes [om.key, hm.key] with
              | error e' =>
                simp only [hf, Except.bind, Except.map] at he; cases he; exact checkFareTypes_req hf
              | ok u' => simp [hf, Except.bind, Except.map] at he
  · cases h

/-! ## 選択フライトの検証の三つ組 -/

theorem routeOfMaster_some {md : Spec.Env.MasterData} (h3 : md.MD3) {n : String}
    {X : Spec.Env.MasterData.FlightMaster} (h : md.flightMasterOf n = some X) : ∃ rt, routeOfMaster md X = some rt := by
  obtain ⟨r, hr, hrn⟩ := h3.2 X (List.mem_of_find?_eq_some h)
  apply Option.isSome_iff_exists.mp
  unfold routeOfMaster
  rw [List.find?_isSome]
  exact ⟨r, hr, by simp [hrn]⟩

section
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Select Abstraction.Reserve.Flights
open Abstraction.Fare.TotalFareRun Abstraction.Fare.TotalAlpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha
  Abstraction.World.Alpha
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.MasterQuery SourceModel.App.B0 SourceModel.Domain.Service.B0
open SourceModel.Domain.Common.Masterdata Spec.Model Spec.Prim Spec.Prim.Text

variable {P : St → Prop} {fd : FlightDb} {cfg : Spec.Env.Config} {md : Spec.Env.MasterData} {p : Providers}
  {w : Spec.World}
  (hP : Stable P fd) (h3 : md.MD3)
  (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
    some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
  (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
    some (.fareType ((md.fareTypeOf cd).map (·.info))))
  (hmn : ∀ name : String, hasText name = true → md.flightMasterOf name = none →
    FlightMasterProvider.getFlightMaster p.flightMaster name = .ok none)
  (hmc : ∀ name : String, hasText name = true →
    ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
    ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name = .ok (some fm) ∧
      fm.flightName = some name ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
      fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
      r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
      aa.code = some rt.arrAirportCd.val)
  (hw : worldOfDb fd = some w) (href : w.RefMaster md)
include hP h3 hbq hfq hmn hmc hw href

/-- 1 便の選択フライトの検証。 -/
theorem vf_one (ri : LangSemantics.Java.Int.J32) {f : SelectFlightForm} {s : SelectFlight}
    (hs : Abstraction.Reserve.Alpha.selectOfForm f = some s) (ht : hasText s.flightName = true)
    {v : Except AtrsError (Itinerary FlightKey)} (hv : validateFlightList cfg md w [resolve md s] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some (mkFlight p f)])) (Post P v) (PostE P v) := by
  obtain ⟨-, -, -, hn, -⟩ := Abstraction.Reserve.Input.selectOfForm_eq hs
  cases hR : resolve md s with
  | none =>
    rw [hR] at hv
    have hX : md.flightMasterOf s.flightName = none := by
      simpa [resolve] using hR
    exact one_none hP ri (mkFlight_master_none hmn hn ht hX) hv
  | some R =>
    rw [hR] at hv
    obtain ⟨hX, -, hRv⟩ := Abstraction.Reserve.SpecFacts.resolve_key hR
    have hk := Abstraction.Reserve.Input.keyOfForm_of_resolve hs hR
    have hkn : R.key.flightName.val = s.flightName := by
      rw [(Abstraction.Reserve.SpecFacts.resolve_key hR).2.1]; exact hRv
    obtain ⟨rt, hrt⟩ := routeOfMaster_some h3 hX
    obtain ⟨fm, -, -, hfm, hfn, -⟩ := mkFlight_master_some hmc hk (hkn ▸ ht) (hkn ▸ hX) hrt
    exact one_some hP ri hfm (exists_mkFlight hbq hfq hw href hk hfn)
      (fun he => flightFareType_one (mkFlight_fareType hfq href hk he)) hv

/-- 往復の選択フライトの検証。往路便の到着時刻は 24:00 より前（D-031 の前提）。 -/
theorem vf_two {ri : LangSemantics.Java.Int.J32} (hri : ri.val = (cfg.reserveIntervalTime : Int))
    {f0 f1 : SelectFlightForm} {s0 s1 : SelectFlight} (hs0 : Abstraction.Reserve.Alpha.selectOfForm f0 = some s0)
    (hs1 : Abstraction.Reserve.Alpha.selectOfForm f1 = some s1)
    (ht0 : hasText s0.flightName = true) (ht1 : hasText s1.flightName = true)
    (hlt : ∀ X0, md.flightMasterOf s0.flightName = some X0 → X0.arrivalTime.toMinutes < 1440)
    {v : Except AtrsError (Itinerary FlightKey)}
    (hv : validateFlightList cfg md w [resolve md s0, resolve md s1] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some (mkFlight p f0), some (mkFlight p f1)]))
      (Post P v) (PostE P v) := by
  obtain ⟨-, -, -, hn0, -⟩ := Abstraction.Reserve.Input.selectOfForm_eq hs0
  obtain ⟨-, -, -, hn1, -⟩ := Abstraction.Reserve.Input.selectOfForm_eq hs1
  cases hR0 : resolve md s0 with
  | none =>
    rw [hR0] at hv
    have hX0 : md.flightMasterOf s0.flightName = none := by simpa [resolve] using hR0
    exact two_none0 hP ri (mkFlight_master_none hmn hn0 ht0 hX0) hv
  | some R0 =>
    rw [hR0] at hv
    obtain ⟨hX0, hk0e, hR0v⟩ := Abstraction.Reserve.SpecFacts.resolve_key hR0
    have hk0 := Abstraction.Reserve.Input.keyOfForm_of_resolve hs0 hR0
    have hkn0 : R0.key.flightName.val = s0.flightName := by rw [hk0e]; exact hR0v
    obtain ⟨rt0, hrt0⟩ := routeOfMaster_some h3 hX0
    obtain ⟨fm0, dt0, art0, hfm0, hfn0, hdt0, hD0, hart0, hA0, hR0'⟩ :=
      mkFlight_master_some hmc hk0 (hkn0 ▸ ht0) (hkn0 ▸ hX0) hrt0
    have he0 := exists_mkFlight hbq hfq hw href hk0 hfn0
    cases hR1 : resolve md s1 with
    | none =>
      rw [hR1] at hv
      have hX1 : md.flightMasterOf s1.flightName = none := by simpa [resolve] using hR1
      exact two_none1 hP ri hfm0 (mkFlight_master_none hmn hn1 ht1 hX1) he0 hv
    | some R1 =>
      rw [hR1] at hv
      obtain ⟨hX1, hk1e, hR1v⟩ := Abstraction.Reserve.SpecFacts.resolve_key hR1
      have hk1 := Abstraction.Reserve.Input.keyOfForm_of_resolve hs1 hR1
      have hkn1 : R1.key.flightName.val = s1.flightName := by rw [hk1e]; exact hR1v
      obtain ⟨rt1, hrt1⟩ := routeOfMaster_some h3 hX1
      obtain ⟨fm1, dt1, art1, hfm1, hfn1, hdt1, hD1, hart1, hA1, hR1'⟩ :=
        mkFlight_master_some hmc hk1 (hkn1 ▸ ht1) (hkn1 ▸ hX1) hrt1
      have he1 := exists_mkFlight hbq hfq hw href hk1 hfn1
      obtain ⟨dj0, hdj0, hd0, -⟩ := keyOfForm_eq hk0
      obtain ⟨dj1, hdj1, hd1, -⟩ := keyOfForm_eq hk1
      have hiv : w.existsFlight R0.key = true → w.existsFlight R1.key = true →
          AgreeV (TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight ri (mkFlight p f0)
            (mkFlight p f1)) (checkInterval cfg R0.key R0.master R1.key R1.master) := by
        intro _ _
        rw [roundTrip_interval (ofl := mkFlight p f0) (hfl := mkFlight p f1) hdj0 hd0 hfm0 hart0 hA0 (hlt _ hX0)
          hdj1 hd1 hfm1 hdt1 hD1]
        unfold checkInterval departureMinute availableMinute
        rw [hri]
        split
        · exact AgreeV.business _ _
        · exact AgreeV.ok
      have hrv : checkReverse md R0.master R1.master = some
          (if rt0.depAirportCd == rt1.arrAirportCd && rt0.arrAirportCd == rt1.depAirportCd then .ok ()
            else .error (.invalidRequest "homeward route is not outward route reverse")) := by
        simp only [checkReverse, hrt0, hrt1, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
      exact two_some hP ri hfm0 hfm1 he0 he1 hiv hrv (flightRoute hfm0 hfm1 hR0' hR1')
        (fun h0 h1 => flightFareType_two (mkFlight_fareType hfq href hk0 h0) (mkFlight_fareType hfq href hk1 h1)) hv

end

section
open LangSemantics.Core.EStateHoare LangSemantics.Java.Exception
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights
open SourceModel.Db.Tx SourceModel.App.B2

/-- 前段の検証の例外の事後条件: 障害か、不正要求（`BadRequestException`）で [Spec] の結果が改竄。 -/
def PostS {α : Type} (P : St → Prop) (v : Except AtrsError α) : JThrow → St → Prop :=
  fun e s => P s ∧ (IsIoFault s.env e ∨
    (∃ msg, e = .other TicketReserveHelper.badRequestClass msg) ∧
      ∃ str, v.mapError Spec.Reserve.asInvalidRequest = .error (.invalidRequest str))

theorem fault_cls {env : SourceModel.Db.Tx.Env} {e : JThrow} (h : IsIoFault env e) : ∃ cls msg, e = .other cls msg ∧
    ¬ (cls = SourceModel.Domain.Service.B0.InvalidFlightException.className ∨
      cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className) := by
  obtain ⟨m, rfl, -⟩ := h
  exact ⟨_, m, rfl, by decide⟩

/-- 前段の選択フライトの検証（`InvalidFlightException`・業務例外を `BadRequestException` に包む）。 -/
theorem helper_vf {α : Type} {P : St → Prop} {h : TicketReserveHelper} {fl : List (JRef SourceModel.Domain.Model.Flight)}
    {v : Except AtrsError α}
    (hm : Hoare P (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList h.reserveIntervalTime
      (some fl)) (Post P v) (PostE P v))
    (hreq : ∀ e, v = .error e → IsReq e) :
    Hoare P (TicketReserveHelper.validateFlightList h fl) (Post P v) (PostS P v) := by
  unfold TicketReserveHelper.validateFlightList
  refine Hoare.tryCatch' hm fun e => ?_
  intro s ⟨hs, he⟩
  rcases he with ⟨⟨cls, msg, rfl, hcls⟩, e', rfl⟩ | hf
  · simp only [hcls, ite_true]
    obtain ⟨str, hstr⟩ := hreq e' rfl
    exact ⟨hs, .inr ⟨⟨msg, rfl⟩, str, by simp only [Except.mapError, hstr]⟩⟩
  · obtain ⟨cls, msg, rfl, hcls⟩ := fault_cls hf
    simp only [hcls, ite_false]
    exact ⟨hs, .inl hf⟩

end

end Abstraction.Reserve.Selects
