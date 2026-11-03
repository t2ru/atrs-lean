import Abstraction.MasterData.AlphaLeaf
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import Spec.Ticket

/-!
# Abstraction.Reserve.Flights

ABS-041 の補題: 選択フライトの検証（`TicketSharedServiceImpl.validateFlightList`）の純粋な部分と、[Spec] の
`Spec.Ticket.validateFlightList` の対応（backlog aedf の第 3 段）。

- 時刻: 便マスタの到着時刻（24:00 より前。既知差異 D-031 の前提）・出発時刻の `HHmm` の解釈
- 搭乗間隔: `validateFlightDepartureDateForRoundTripFlight` と `checkInterval`
- 運賃種別: `validateFlightFareType` と `checkFareTypes`
-/

namespace Abstraction.Reserve.Flights
open Abstraction.MasterData.AlphaLeaf Spec.Model Spec.Prim Spec.Prim.Time
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Domain.Model SourceModel.Domain.Service.B0 SourceModel.Domain.Common.Util

/-! ## 時刻 -/

theorem asciiDigit?_eq : JLocalTime.asciiDigit? = HourMinute.digitVal? := rfl

/-- 到着時刻が 24:00 より前なら、`HHmm` の解釈（`LocalTime`）は同じ時分。 -/
theorem parseHHmm_arr {s : String} {a : ArrivalTime} (h : arrOfStr s = some a) (hlt : a.toMinutes < 1440) :
    JLocalTime.parseHHmm s = .ok ⟨a.hour, a.minute⟩ := by
  unfold arrOfStr ArrivalTime.parseHHmm at h
  unfold JLocalTime.parseHHmm
  rw [asciiDigit?_eq]
  split at h
  · rename_i a0 b0 c0 d0 hs
    simp only [hs]
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
    obtain ⟨h1, e1, h2, e2, m1, e3, m2, e4, h⟩ := h
    simp only [e1, e2, e3, e4]
    unfold ArrivalTime.ofHm? at h
    split at h
    · rename_i hv
      cases h
      have := digitVal?_lt e3
      have := digitVal?_lt e4
      simp only [ArrivalTime.toMinutes] at hlt
      have hm : ¬ (m1 * 10 + m2 ≥ 60) := by omega
      have hh : h1 * 10 + h2 ≤ 23 := by omega
      simp [hm, hh]
    · cases h
  · cases h

/-- 出発時刻の `HHmm` の解釈（`LocalTime`）は同じ時分。 -/
theorem parseHHmm_dep {s : String} {t : HourMinute} (h : hmOfStr s = some t) :
    JLocalTime.parseHHmm s = .ok ⟨t.hour, t.minute⟩ := by
  unfold hmOfStr HourMinute.parseHHmm at h
  unfold JLocalTime.parseHHmm
  rw [asciiDigit?_eq]
  split at h
  · rename_i a0 b0 c0 d0 hs
    simp only [hs]
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
    obtain ⟨h1, e1, h2, e2, m1, e3, m2, e4, h⟩ := h
    simp only [e1, e2, e3, e4]
    unfold HourMinute.ofHm? at h
    split at h
    · rename_i hv
      cases h
      have hm : ¬ (m1 * 10 + m2 ≥ 60) := by omega
      simp [hm, hv.1]
    · cases h
  · cases h

theorem toEpochMinute_ofEpochMinute (n : Int) : (JLocalDateTime.ofEpochMinute n).toEpochMinute = n := by
  simp only [JLocalDateTime.ofEpochMinute, JLocalDateTime.toEpochMinute, JLocalDate.toEpochDay_ofEpochDay]
  have h0 : 0 ≤ n % 1440 := Int.emod_nonneg n (by decide)
  have h1 : n % 1440 < 1440 := Int.emod_lt_of_pos n (by decide)
  have e : ((n % 1440).toNat / 60 * 60 + (n % 1440).toNat % 60 : Nat) = (n % 1440).toNat := Nat.div_add_mod' _ _
  rw [e, Int.toNat_of_nonneg h0]
  omega

theorem toEpochMinute_atTime (d : JLocalDate) (t : JLocalTime) :
    (JLocalDateTime.atTime d t).toEpochMinute = d.toEpochDay * 1440 + (t.hour * 60 + t.minute : Nat) := rfl

/-! ## 搭乗間隔 -/

/-- 搭乗間隔の検査: 往路便の到着時刻が 24:00 より前なら、復路便の出発日時が往路便の到着日時の `reserveIntervalTime` 分後より
前のときに限って業務例外 `e.ar.b2.2001`。 -/
theorem roundTrip_interval {ri : J32} {ofl hfl : SourceModel.Domain.Model.Flight}
    {ofm hfm : SourceModel.Domain.Model.FlightMaster} {dj hj : JLocalDate} {od hd : Date}
    {art dt : String} {oA : ArrivalTime} {hD : HourMinute}
    (hod : ofl.departureDate = some dj) (hdj : dateOfJ dj = some od) (hom : ofl.flightMaster = some ofm)
    (hart : ofm.arrivalTime = some art) (hoA : arrOfStr art = some oA) (hlt : oA.toMinutes < 1440)
    (hhd : hfl.departureDate = some hj) (hhj : dateOfJ hj = some hd) (hhm : hfl.flightMaster = some hfm)
    (hdt : hfm.departureTime = some dt) (hhD : hmOfStr dt = some hD) :
    TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight ri ofl hfl =
      if hd.epochDay * 1440 + (hD.toMinutes : Int) < od.epochDay * 1440 + (oA.toMinutes : Int) + ri.val then
        .error (SourceModel.Domain.Common.Exception.AtrsBusinessException.new
          (SourceModel.Domain.Service.B2.TicketReserveErrorCode.code "e.ar.b2.2001"))
      else .ok () := by
  have eo := (dateOfJ_eq_some hdj).2
  have eh := (dateOfJ_eq_some hhj).2
  unfold TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight DateTimeUtil.toLocalDateTime
    DateTimeUtil.toLocalTime
  simp only [JRef.deref]
  simp only [hom, hhm, hart, hdt, parseHHmm_arr hoA hlt, parseHHmm_dep hhD, hod, hhd, bind, Except.bind, pure,
    Except.pure]
  simp only [JLocalDateTime.isBefore, JLocalDateTime.plusMinutes, toEpochMinute_ofEpochMinute, toEpochMinute_atTime,
    eo, eh, ArrivalTime.toMinutes, HourMinute.toMinutes]
  split
  · rename_i hc
    simp only [decide_eq_true_eq] at hc
    simp only [hc, ite_true]
    rfl
  · rename_i hc
    simp only [decide_eq_true_eq] at hc
    simp only [hc, ite_false]

/-! ## 検査の結果の対応 -/

/-- 検査の結果の対応: どちらも成功するか、[Source] が不正要求に包まれる例外（`InvalidFlightException`・業務例外）を投げ、
[Spec] がエラーを返す（エラーの中身は、選択フライトの検証ではすべて不正要求に写り、詳細は自由な選択 N-004）。 -/
def AgreeV (r : JResult Unit) (x : Except Spec.Error.AtrsError Unit) : Prop :=
  (r = .ok () ∧ x = .ok ()) ∨
    (∃ cls msg, r = .error (.other cls msg) ∧
      (cls = InvalidFlightException.className ∨ cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className) ∧
      ∃ e, x = .error e)

theorem AgreeV.ok : AgreeV (.ok ()) (.ok ()) := .inl ⟨rfl, rfl⟩

theorem AgreeV.invalid (msg : String) (e : Spec.Error.AtrsError) :
    AgreeV (.error (InvalidFlightException.new msg)) (.error e) :=
  .inr ⟨_, msg, rfl, .inl rfl, e, rfl⟩

theorem AgreeV.business (c : String) (e : Spec.Error.AtrsError) :
    AgreeV (.error (SourceModel.Domain.Common.Exception.AtrsBusinessException.new c)) (.error e) :=
  .inr ⟨_, c, rfl, .inr rfl, e, rfl⟩

/-! ## 運賃種別 -/

/-- フライト情報の運賃種別のコード。 -/
def HasFareType (f : JRef SourceModel.Domain.Model.Flight) (c : FareTypeCd) : Prop :=
  ∃ fl ft, f = some fl ∧ fl.fareType = some ft ∧ ft.fareTypeCd = some c

theorem isOneWay_eq (c : FareTypeCd) : FareTypeUtil.isOneWay (some c) = oneWayFareTypes.contains c := rfl

theorem isRoundTrip_eq (c : FareTypeCd) : FareTypeUtil.isRoundTrip (some c) = roundTripFareTypes.contains c := rfl

/-- 運賃種別の検査（片道）。 -/
theorem flightFareType_one {f : JRef SourceModel.Domain.Model.Flight} {k : FlightKey} (h : HasFareType f k.fareTypeCd) :
    AgreeV (TicketSharedServiceImpl.validateFlightFareType [f]) (Spec.Ticket.checkFareTypes [k]) := by
  obtain ⟨fl, ft, rfl, h1, h2⟩ := h
  unfold TicketSharedServiceImpl.validateFlightFareType Spec.Ticket.checkFareTypes
  simp only [JRef.deref, h1, h2, isOneWay_eq, bind, Except.bind, pure, Except.pure]
  by_cases hc : oneWayFareTypes.contains k.fareTypeCd = true
  · simp only [hc, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
    exact AgreeV.ok
  · simp only [Bool.not_eq_true] at hc
    simp only [hc, Bool.not_false, ↓reduceIte, Bool.false_eq_true]
    exact AgreeV.invalid _ _

/-- 運賃種別の検査（往復）。 -/
theorem flightFareType_two {f g : JRef SourceModel.Domain.Model.Flight} {k l : FlightKey}
    (hf : HasFareType f k.fareTypeCd) (hg : HasFareType g l.fareTypeCd) :
    AgreeV (TicketSharedServiceImpl.validateFlightFareType [f, g]) (Spec.Ticket.checkFareTypes [k, l]) := by
  obtain ⟨fl, ft, rfl, h1, h2⟩ := hf
  obtain ⟨gl, gt, rfl, h3, h4⟩ := hg
  unfold TicketSharedServiceImpl.validateFlightFareType Spec.Ticket.checkFareTypes
  simp only [JRef.deref, h1, h2, h3, h4, isRoundTrip_eq, bind, Except.bind, pure, Except.pure]
  by_cases a : roundTripFareTypes.contains k.fareTypeCd = true
  · by_cases b : roundTripFareTypes.contains l.fareTypeCd = true
    · simp only [a, b, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      exact AgreeV.ok
    · simp only [Bool.not_eq_true] at b
      simp only [a, b, Bool.not_true, Bool.not_false, Bool.false_eq_true, ↓reduceIte]
      exact AgreeV.invalid _ _
  · simp only [Bool.not_eq_true] at a
    simp only [a, Bool.not_false, ↓reduceIte]
    exact AgreeV.invalid _ _

/-! ## 逆区間 -/

/-- 便マスタの区間の空港コード。 -/
def HasRoute (fm : SourceModel.Domain.Model.FlightMaster) (rt : Spec.MasterData.Route) : Prop :=
  ∃ r da aa, fm.route = some r ∧ r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧
    r.arrivalAirport = some aa ∧ aa.code = some rt.arrAirportCd.val

/-- 逆区間の検査。 -/
theorem flightRoute {ofl hfl : SourceModel.Domain.Model.Flight} {ofm hfm : SourceModel.Domain.Model.FlightMaster}
    {orr hr : Spec.MasterData.Route} (hom : ofl.flightMaster = some ofm) (hhm : hfl.flightMaster = some hfm)
    (ho : HasRoute ofm orr) (hh : HasRoute hfm hr) :
    AgreeV (TicketSharedServiceImpl.validateFlightRouteForRoundTripFlight ofl hfl)
      (if orr.depAirportCd == hr.arrAirportCd && orr.arrAirportCd == hr.depAirportCd then .ok ()
        else .error (.invalidRequest "homeward route is not outward route reverse")) := by
  obtain ⟨r1, d1, a1, e1, e2, e3, e4, e5⟩ := ho
  obtain ⟨r2, d2, a2, f1, f2, f3, f4, f5⟩ := hh
  unfold TicketSharedServiceImpl.validateFlightRouteForRoundTripFlight
  simp only [JRef.deref, hom, hhm, e1, e2, e3, e4, e5, f1, f2, f3, f4, f5, bind, Except.bind, pure, Except.pure]
  by_cases a : orr.depAirportCd.val = hr.arrAirportCd.val
  · by_cases b : orr.arrAirportCd.val = hr.depAirportCd.val
    · have ea : (orr.depAirportCd == hr.arrAirportCd) = true := by
        cases h1 : orr.depAirportCd; cases h2 : hr.arrAirportCd; simp_all
      have eb : (orr.arrAirportCd == hr.depAirportCd) = true := by
        cases h1 : orr.arrAirportCd; cases h2 : hr.depAirportCd; simp_all
      simp [a, b, ea, eb]
      exact AgreeV.ok
    · have eb : (orr.arrAirportCd == hr.depAirportCd) = false := by
        cases h1 : orr.arrAirportCd; cases h2 : hr.depAirportCd; simp_all
      simp [a, b, eb]
      exact AgreeV.invalid _ _
  · have ea : (orr.depAirportCd == hr.arrAirportCd) = false := by
      cases h1 : orr.depAirportCd; cases h2 : hr.arrAirportCd; simp_all
    simp [a, ea]
    exact AgreeV.invalid _ _

end Abstraction.Reserve.Flights
