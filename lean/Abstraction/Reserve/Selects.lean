import Abstraction.Reserve.ValidateFlights
import Abstraction.Reserve.Select
import SourceModel.App.B2.TicketReserveHelper

/-!
# Abstraction.Reserve.Selects

ABS-041 の補題: 予約の前段の選択フライトの検証（`TicketReserveHelper.validateFlightList`）と、[Spec] の `checkSelects`
の対応（backlog aedf の第 3 段）。原典は `InvalidFlightException` と業務例外を `BadRequestException` に包み、[Spec] は
選択フライトの検証の失敗をすべて改竄（`InvalidRequest`）とする（`asInvalidRequest`）。
-/

namespace Abstraction.Reserve.Selects
open Spec.Ticket Spec.Error

/-- 改竄に写るエラー（`InvalidRequest` か `Business`）。 -/
def IsReq (e : AtrsError) : Prop := ∃ s, Spec.UseCase.Reserve.asInvalidRequest e = .invalidRequest s

theorem isReq_invalid (s : String) : IsReq (.invalidRequest s) := ⟨s, rfl⟩

theorem isReq_business (c : String) (a : List String) : IsReq (.business c a) := ⟨c, rfl⟩

theorem checkFlight_req {w : Spec.Port.World} {f : ResolvedFlight} {m : Except AtrsError Spec.MasterData.FlightMaster}
    (h : checkFlight w f = m) : ∀ e, m = .error e → IsReq e := by
  intro e he
  subst h
  unfold checkFlight at he
  split at he
  · cases he; exact isReq_invalid _
  · split at he <;> cases he; exact isReq_invalid _

theorem checkInterval_req {cfg : Spec.Config} {o h' : Spec.Model.FlightKey} {om hm : Spec.MasterData.FlightMaster}
    {e : AtrsError} (h : checkInterval cfg o om h' hm = .error e) : IsReq e := by
  unfold checkInterval at h; split at h <;> cases h; exact isReq_business _ _

theorem checkFareTypes_req {ks : List Spec.Model.FlightKey} {e : AtrsError} (h : checkFareTypes ks = .error e) :
    IsReq e := by
  unfold checkFareTypes at h
  split at h
  · split at h <;> cases h; exact isReq_invalid _
  · split at h
    · cases h; exact isReq_invalid _
    · split at h <;> cases h; exact isReq_invalid _
  · cases h; exact isReq_invalid _

theorem checkReverse_req {md : Spec.MasterData} {om hm : Spec.MasterData.FlightMaster} {r : Except AtrsError Unit}
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
theorem validateFlightList_req {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World}
    {fs : List ResolvedFlight} {x : Except AtrsError Unit} (h : validateFlightList cfg md w fs = some x) :
    ∀ e, x = .error e → IsReq e := by
  intro e he
  unfold validateFlightList at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    rename_i o
    cases hc : checkFlight w o with
    | error e' => simp only [hc, bind, Except.bind] at he; cases he; exact checkFlight_req hc _ rfl
    | ok m => simp only [hc, bind, Except.bind] at he; exact checkFareTypes_req he
  · rename_i o h0
    cases hc : checkFlight w o with
    | error e' => simp only [hc, Option.some.injEq] at h; subst h; cases he; exact checkFlight_req hc _ rfl
    | ok om =>
      cases hc' : checkFlight w h0 with
      | error e' => simp only [hc, hc', Option.some.injEq] at h; subst h; cases he; exact checkFlight_req hc' _ rfl
      | ok hm =>
        cases hi : checkInterval cfg o.key om h0.key hm with
        | error e' => simp only [hc, hc', hi, Option.some.injEq] at h; subst h; cases he; exact checkInterval_req hi
        | ok u =>
          cases u
          simp only [hc, hc', hi, Option.bind_eq_bind, Option.pure_def] at h
          cases hr : checkReverse md om hm with
          | none => simp [hr] at h
          | some r =>
            simp only [hr, Option.bind_some, Option.some.injEq] at h
            subst h
            cases r with
            | error e' => cases he; exact checkReverse_req hr _ rfl
            | ok u => cases u; exact checkFareTypes_req (ks := [o.key, h0.key]) he
  · cases h

/-! ## 選択フライトの検証の三つ組 -/

theorem routeOfMaster_some {md : Spec.MasterData} (h3 : md.MD3) {n : Spec.Model.FlightName}
    {X : Spec.MasterData.FlightMaster} (h : md.flightMasterOf n = some X) : ∃ rt, routeOfMaster md X = some rt := by
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

variable {P : St → Prop} {fd : FlightDb} {cfg : Spec.Config} {md : Spec.MasterData} {p : Providers}
  {w : Spec.Port.World}
  (hP : Stable P fd) (h3 : md.MD3)
  (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
    some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
  (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
    some (.fareType ((md.fareTypeOf cd).map (·.info))))
  (hmn : ∀ name : FlightName, hasText name.val = true → md.flightMasterOf name = none →
    FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok none)
  (hmc : ∀ name : FlightName, hasText name.val = true →
    ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
    ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok (some fm) ∧
      fm.flightName = some name.val ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
      fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
      r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
      aa.code = some rt.arrAirportCd.val)
  (hw : worldOfDb fd = some w) (href : w.RefMaster md)
include hP h3 hbq hfq hmn hmc hw href

/-- 1 便の選択フライトの検証。 -/
theorem vf_one (ri : LangSemantics.Java.Int.J32) {f : SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    (ht : hasText k.flightName.val = true) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some (mkFlight p f)]))
      (Post P (checkFlight w ⟨k, md.flightMasterOf k.flightName⟩ >>= fun _ => checkFareTypes [k]))
      (PostE P (checkFlight w ⟨k, md.flightMasterOf k.flightName⟩ >>= fun _ => checkFareTypes [k])) := by
  cases hX : md.flightMasterOf k.flightName with
  | none => exact one_none hP ri (mkFlight_master_none hmn hk ht hX) k
  | some X =>
    obtain ⟨rt, hrt⟩ := routeOfMaster_some h3 hX
    obtain ⟨fm, -, -, hfm, hfn, -⟩ := mkFlight_master_some hmc hk ht hX hrt
    exact one_some hP ri hfm (exists_mkFlight hbq hfq hw href hk hfn)
      fun he => flightFareType_one (mkFlight_fareType hfq href hk he)

/-- 往復の選択フライトの検証。往路便の到着時刻は 24:00 より前（D-031 の前提）。 -/
theorem vf_two {ri : LangSemantics.Java.Int.J32} (hri : ri.val = (cfg.reserveIntervalTime : Int))
    {f0 f1 : SelectFlightForm} {k0 k1 : FlightKey} (hk0 : keyOfForm f0 = some k0) (hk1 : keyOfForm f1 = some k1)
    (ht0 : hasText k0.flightName.val = true) (ht1 : hasText k1.flightName.val = true)
    (hlt : ∀ X0, md.flightMasterOf k0.flightName = some X0 → X0.arrivalTime.toMinutes < 1440)
    {v : Except AtrsError Unit}
    (hv : validateFlightList cfg md w
      [⟨k0, md.flightMasterOf k0.flightName⟩, ⟨k1, md.flightMasterOf k1.flightName⟩] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some (mkFlight p f0), some (mkFlight p f1)]))
      (Post P v) (PostE P v) := by
  cases hX0 : md.flightMasterOf k0.flightName with
  | none =>
    rw [hX0] at hv
    exact two_none0 hP ri (mkFlight_master_none hmn hk0 ht0 hX0) hv
  | some X0 =>
    rw [hX0] at hv
    obtain ⟨rt0, hrt0⟩ := routeOfMaster_some h3 hX0
    obtain ⟨fm0, dt0, art0, hfm0, hfn0, hdt0, hD0, hart0, hA0, hR0⟩ := mkFlight_master_some hmc hk0 ht0 hX0 hrt0
    have he0 := exists_mkFlight hbq hfq hw href hk0 hfn0
    cases hX1 : md.flightMasterOf k1.flightName with
    | none =>
      rw [hX1] at hv
      exact two_none1 hP ri hfm0 (mkFlight_master_none hmn hk1 ht1 hX1) he0 hv
    | some X1 =>
      rw [hX1] at hv
      obtain ⟨rt1, hrt1⟩ := routeOfMaster_some h3 hX1
      obtain ⟨fm1, dt1, art1, hfm1, hfn1, hdt1, hD1, hart1, hA1, hR1⟩ := mkFlight_master_some hmc hk1 ht1 hX1 hrt1
      have he1 := exists_mkFlight hbq hfq hw href hk1 hfn1
      obtain ⟨dj0, hdj0, hd0, -⟩ := keyOfForm_eq hk0
      obtain ⟨dj1, hdj1, hd1, -⟩ := keyOfForm_eq hk1
      have hiv : w.existsFlight k0 = true → w.existsFlight k1 = true →
          AgreeV (TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight ri (mkFlight p f0)
            (mkFlight p f1)) (checkInterval cfg k0 X0 k1 X1) := by
        intro _ _
        rw [roundTrip_interval (ofl := mkFlight p f0) (hfl := mkFlight p f1) hdj0 hd0 hfm0 hart0 hA0 (hlt X0 hX0)
          hdj1 hd1 hfm1 hdt1 hD1]
        unfold checkInterval departureMinute availableMinute
        rw [hri]
        split
        · exact AgreeV.business _ _
        · exact AgreeV.ok
      have hrv : checkReverse md X0 X1 = some
          (if rt0.depAirportCd == rt1.arrAirportCd && rt0.arrAirportCd == rt1.depAirportCd then .ok ()
            else .error (.invalidRequest "homeward route is not outward route reverse")) := by
        simp only [checkReverse, hrt0, hrt1, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
      exact two_some hP ri hfm0 hfm1 he0 he1 hiv hrv (flightRoute hfm0 hfm1 hR0 hR1)
        (fun h0 h1 => flightFareType_two (mkFlight_fareType hfq href hk0 h0) (mkFlight_fareType hfq href hk1 h1)) hv

end

section
open LangSemantics.Core.EStateHoare LangSemantics.Java.Exception
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights
open SourceModel.Db.Tx SourceModel.App.B2

/-- 前段の検証の例外の事後条件: 障害か、不正要求（`BadRequestException`）で [Spec] の結果が改竄。 -/
def PostS (P : St → Prop) (v : Except AtrsError Unit) : JThrow → St → Prop :=
  fun e s => P s ∧ (IsIoFault s.env e ∨
    (∃ msg, e = .other TicketReserveHelper.badRequestClass msg) ∧
      ∃ str, v.mapError Spec.UseCase.Reserve.asInvalidRequest = .error (.invalidRequest str))

theorem fault_cls {env : SourceModel.Db.Tx.Env} {e : JThrow} (h : IsIoFault env e) : ∃ cls msg, e = .other cls msg ∧
    ¬ (cls = SourceModel.Domain.Service.B0.InvalidFlightException.className ∨
      cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className) := by
  obtain ⟨m, rfl, -⟩ := h
  exact ⟨_, m, rfl, by decide⟩

/-- 前段の選択フライトの検証（`InvalidFlightException`・業務例外を `BadRequestException` に包む）。 -/
theorem helper_vf {P : St → Prop} {h : TicketReserveHelper} {fl : List (JRef SourceModel.Domain.Model.Flight)}
    {v : Except AtrsError Unit}
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
