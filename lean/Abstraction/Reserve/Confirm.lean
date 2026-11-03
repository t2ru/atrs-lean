import Abstraction.Reserve.ValidateReservation
import Abstraction.Reserve.Draft
import Abstraction.Reserve.TotalFare
import Abstraction.Reserve.Selects

/-!
# Abstraction.Reserve.Confirm

ABS-041 の補題: 予約確認（`TicketReserveHelper.reserveConfirm`）の三つ組と、[Spec] の `reserveConfirm` の対応
（backlog aedf の第 3 段）。予約情報の組み立て（`Draft`）、予約内容の検証（`ValidateReservation`）、合計金額
（`TotalFare`）をつなぐ。
-/

namespace Abstraction.Reserve.Confirm
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate
  Abstraction.Reserve.MemberCheck Abstraction.Reserve.ValidateReservation Abstraction.Reserve.Draft
  Abstraction.Reserve.Alpha
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.App.B2 SourceModel.Domain.Service.B2 SourceModel.ReserveQuery

/-- 予約確認（前段の後）。合計金額の計算の値 `T` は、検証が成功したときの値。 -/
theorem helperConfirm_hoare {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {p : SourceModel.MasterQuery.Providers}
    {ic : ReserveInput} {w : Spec.Port.World} (he : MemberEnv fd ic.db w) {cfg : Spec.Config} {md : Spec.MasterData}
    (hmin : (helperOf p ic).ticketReserveService.representativeMinAge.val = (cfg.representativeMinAge : Int))
    {ri : Spec.UseCase.Reserve.ReserveInput} (hri : reserveInputOf ic.form = some ri)
    (hlen : ri.passengers.length ≤ 6) {ks : List Spec.Model.FlightKey} {d : Spec.UseCase.Reserve.Draft}
    (hd : Spec.UseCase.Reserve.buildDraft { ri with passengers := Spec.UseCase.Reserve.compactPassengers ri.passengers }
      ks = some d)
    {f0 : SourceModel.Domain.Model.Flight} {fs : List SourceModel.Domain.Model.Flight}
    {FTs : List Spec.MasterData.FareType} (hFT : LangSemantics.Core.List.Forall₂ FareTypeFacts (f0 :: fs) FTs)
    (hkf : LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) ks FTs) {T : Int.J32}
    (hcalc : ∀ vr, Spec.UseCase.Reserve.validateReservation cfg md w d = some vr → vr = .ok () →
      TicketReserveServiceImpl.calculateTotalFare (helperOf p ic).ticketReserveService
        (some ((f0 :: fs).map some))
        (some (((ic.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).map some)) = .ok T) :
    ∃ v, Spec.UseCase.Reserve.validateReservation cfg md w d = some v ∧
      Hoare P (TicketReserveHelper.reserveConfirm (helperOf p ic) ic.form ((f0 :: fs).map some))
        (fun r s => P s ∧ v = .ok () ∧ r.2.totalFare = T) (PostBE P v) := by
  obtain ⟨hrfl, ⟨age, hage, hagev⟩, ⟨M0, hm, hn⟩, hf, hg, hgd, hR, hne, hks⟩ :=
    reservation_facts hri hd ((f0 :: fs).map some)
  subst hks
  have hlen' : ((ic.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).length ≤ 6 := by
    have := LangSemantics.Core.MapM.mapM_some_length (reserveInputOf_eq hri).2.2.2.2.2.2.2.2.2
    rw [List.length_map]
    exact Nat.le_trans (List.length_filter_le _ _) (this ▸ hlen)
  have hrfl0 := hrfl
  rw [List.map_map] at hrfl
  obtain ⟨v, hv, hH⟩ := validate_hoare hP he hrfl hage hagev hmin hm hn hf hg hgd hR hne hlen' hFT hkf
  refine ⟨v, hv, ?_⟩
  unfold TicketReserveHelper.reserveConfirm
  refine Hoare.bind' (Hoare.conseq hH (fun _ h => h) (fun _ _ h => h) fun _ _ h => h) fun _ => ?_
  intro s ⟨hs, hv0⟩
  have hc : TicketReserveHelper.calculateTotalFare (helperOf p ic) ((f0 :: fs).map some)
      (TicketReserveHelper.createReservation ic.form.resetPassengersIndex ((f0 :: fs).map some)) = .ok T := by
    unfold TicketReserveHelper.calculateTotalFare
    rw [hrfl0]
    simp only [LangSemantics.Java.EStateSimp.deref_some, List.map_cons,
      LangSemantics.Java.JList.get_cons_zero, LangSemantics.Java.EStateSimp.except_ok_bind]
    exact hcalc v hv hv0
  simp only [hc, lift_ok, pure_bind]
  exact ⟨hs, hv0, rfl⟩

/-- 予約確認の流れの例外の事後条件: 障害か、前段の不正要求（[Spec] の前段が改竄）か、後段の業務例外（[Spec] の前段が
成功し、予約内容の検証が同じコードと引数の `Business`）。 -/
def ConfirmE (P : St → Prop) (v vr : Except Spec.Error.AtrsError Unit) : JThrow → St → Prop :=
  fun e s => P s ∧ (IsIoFault s.env e ∨
    ((∃ msg, e = .other TicketReserveHelper.badRequestClass msg) ∧
      ∃ str, v.mapError Spec.UseCase.Reserve.asInvalidRequest = .error (.invalidRequest str)) ∨
    (v = .ok () ∧ ∃ be : Spec.Error.BusinessError,
      e = SourceModel.Domain.Common.Exception.AtrsBusinessException.newArgs be.code be.args ∧
      vr = .error (.business be)))

/-- 予約確認の流れ（`confirmBody`）: 前段の選択フライトの検証の三つ組と、前段が成功したときの後段の三つ組をつなぐ。 -/
theorem confirm_core {P : St → Prop} {p : SourceModel.MasterQuery.Providers} {ic : ReserveInput}
    {fl0 : SourceModel.Domain.Model.Flight} {fls : List SourceModel.Domain.Model.Flight}
    (htf : SourceModel.App.B0.TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p)
      ic.form.selectFlightFormList = .ok ((fl0 :: fls).map some))
    {v : Except Spec.Error.AtrsError Unit}
    (hvf : Hoare P (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList
      (helperOf p ic).reserveIntervalTime (some ((fl0 :: fls).map some))) (Post P v) (PostE P v))
    (hreq : ∀ e, v = .error e → Abstraction.Reserve.Selects.IsReq e)
    {vr : Except Spec.Error.AtrsError Unit} {T : Int.J32}
    (hrest : v = .ok () → Hoare P (TicketReserveHelper.reserveConfirm (helperOf p ic) ic.form ((fl0 :: fls).map some))
      (fun r s => P s ∧ vr = .ok () ∧ r.2.totalFare = T) (PostBE P vr)) :
    Hoare P (confirmBody p ic) (fun o s => P s ∧ v = .ok () ∧ vr = .ok () ∧ o.totalFare = T) (ConfirmE P v vr) := by
  unfold confirmBody
  simp only [htf, lift_ok, pure_bind]
  refine Hoare.bind' (Hoare.conseq (Abstraction.Reserve.Selects.helper_vf hvf hreq) (fun _ h => h)
    (fun _ _ h => h) fun e s ⟨hs, he⟩ => ⟨hs, ?_⟩) fun _ => ?_
  · rcases he with he | he
    · exact .inl he
    · exact .inr (.inl he)
  · intro s ⟨hs, hv⟩
    refine Hoare.bind' (Hoare.conseq (hrest hv) (fun _ h => h) (fun _ _ h => h) fun e s ⟨hs', he⟩ => ⟨hs', ?_⟩)
      (fun r => Hoare.pure' fun s' ⟨hs', hvr, hT⟩ => ⟨hs', hv, hvr, hT⟩) s hs
    rcases he with he | ⟨be, rfl, hc⟩
    · exact .inl he
    · exact .inr (.inr ⟨hv, be, rfl, hc⟩)

end Abstraction.Reserve.Confirm
