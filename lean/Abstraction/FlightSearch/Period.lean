import Abstraction.FlightSearch.Alpha
import Abstraction.Prim.Date

/-!
# Abstraction.FlightSearch.Period

ABS-011 の補題と L 課題 ABS-010: 照会可能期間と、運賃種別の予約可能判定。

- `validateDepatureDate_eq`: [Source] の搭乗日の検査（`plusDays`・`isBefore`・`isAfter`）は、[Spec] の `outOfPeriod`
  （日数の比較）と同じ結果になる。
- `beforeDayNum_val`: 照会の `beforeDayNum`（`long`）の値は、[Spec] の `daysBetween`。
- `isAvailableFareType_between`（ABS-010）: [Source] の `isAvailableFareType`（日付の形）は、SQL の条件
  `beforeDayNum BETWEEN end AND start` と同値である。
-/

namespace Abstraction.FlightSearch.Period
open Abstraction.MasterData.AlphaLeaf LangSemantics.Java.Int LangSemantics.Sql.Core

open LangSemantics.Java Spec.Prim LangSemantics.Sql.Postgresql LangSemantics.Java.Exception

theorem le_int_holds (a b : Int) : (SqlValue.le collationC (.int a) (.int b)).holds = decide (a ≤ b) := by
  simp only [SqlValue.le, SqlValue.compareWith, SqlValue.cmp, Truth.holds_ofBool]
  rcases Int.lt_trichotomy a b with h | rfl | h
  · simp [Int.compare_eq_lt.mpr h, Int.le_of_lt h]
  · simp
  · simp [Int.compare_eq_gt.mpr h, Int.not_le.mpr h]

theorem between_int_holds (x lo hi : Int) :
    (between collationC (.int x) (.int lo) (.int hi)).holds = (decide (lo ≤ x) && decide (x ≤ hi)) := by
  simp only [between, Truth.holds_and, le_int_holds]

/-- L 課題 ABS-010: `isAvailableFareType`（予約可能期間の始まり `depDate − start`・終わり `depDate − end` に今日が
入るか）は、`beforeDayNum = daysBetween(today, depDate)` についての `beforeDayNum BETWEEN end AND start` と同値。 -/
@[obligation "ABS-010"]
theorem isAvailableFareType_between (ft : SourceModel.Domain.Model.FareType) (s e : J32)
    (hs : ft.rsrvAvailableStartDayNum = some s) (he : ft.rsrvAvailableEndDayNum = some e) (dep today : JLocalDate) :
    SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType (some ft) (some dep) today =
      .ok (between collationC (.int (JLocalDate.daysBetween today dep)) (.int e.val) (.int s.val)).holds := by
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType, JRef.deref, between_int_holds]
  simp only [JLocalDate.minusDays, JLocalDate.isBefore, JLocalDate.isAfter, JLocalDate.toEpochDay_ofEpochDay]
  have hdb : JLocalDate.daysBetween today dep = dep.toEpochDay - today.toEpochDay := rfl
  simp only [pure_bind]
  rw [hs, he]
  simp only [bind, Except.bind, pure, Except.pure]
  congr 1
  rw [Bool.eq_iff_iff]
  simp only [Bool.not_eq_true', Bool.or_eq_false_iff, decide_eq_false_iff_not, Bool.and_eq_true, decide_eq_true_eq]
  constructor
  · intro ⟨h1, h2⟩; exact ⟨by omega, by omega⟩
  · intro ⟨h1, h2⟩; exact ⟨by omega, by omega⟩

/-- 搭乗日の検査: [Source] の `validateDepatureDate` は、[Spec] の `outOfPeriod` が真のときだけ業務例外 2001 を投げる。 -/
theorem validateDepatureDate_eq {cfg : Spec.Config} {limitDay : J32} (hL : limitDay.val = (cfg.limitDay : Int))
    {tJ dJ : JLocalDate} {T D : Date} (hT : dateOfJ tJ = some T) (hD : dateOfJ dJ = some D) :
    SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateDepatureDate limitDay tJ tJ (some dJ) =
      if Spec.FlightSearch.outOfPeriod cfg T D = true then
        .error (SourceModel.Domain.Common.Exception.AtrsBusinessException.new (SourceModel.Domain.Service.B1.TicketSearchErrorCode.code "e.ar.b1.2001"))
      else .ok () := by
  have eT := (dateOfJ_eq_some hT).2
  have eD := (dateOfJ_eq_some hD).2
  have hcond : (dJ.isBefore tJ || dJ.isAfter (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getSearchLimitDate limitDay tJ)) =
      Spec.FlightSearch.outOfPeriod cfg T D := by
    simp only [SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getSearchLimitDate, JLocalDate.plusDays, JLocalDate.isBefore,
      JLocalDate.isAfter, JLocalDate.toEpochDay_ofEpochDay, Spec.FlightSearch.outOfPeriod]
    have hdb : Date.daysBetween T D = D.epochDay - T.epochDay := rfl
    rw [eT, eD, hL]
    have hlt : (D < T) ↔ D.epochDay < T.epochDay := Date.lt_iff_epochDay_lt D T
    rw [Bool.eq_iff_iff]
    simp only [Bool.or_eq_true, decide_eq_true_eq, hlt]
    constructor <;> rintro (h | h) <;> first | (left; omega) | (right; omega)
  unfold SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateDepatureDate
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, pure_bind]
  rw [← hcond]
  cases (dJ.isBefore tJ || dJ.isAfter (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getSearchLimitDate limitDay tJ)) <;> rfl

/-- 照会の `beforeDayNum`（`long`）の値は、[Spec] の `daysBetween`。 -/
theorem beforeDayNum_val {tJ dJ : JLocalDate} {T D : Date} (hT : dateOfJ tJ = some T) (hD : dateOfJ dJ = some D) :
    (J64.ofInt (JLocalDate.daysBetween tJ dJ)).val = Date.daysBetween T D := by
  have eT := (dateOfJ_eq_some hT).2
  have eD := (dateOfJ_eq_some hD).2
  have hb : JLocalDate.daysBetween tJ dJ = Date.daysBetween T D := by
    simp only [JLocalDate.daysBetween, Date.daysBetween, eT, eD]
  rw [hb]
  apply J64.val_ofInt_of_inRange
  have bound : ∀ X : Date, X.ordinal ≤ 4000000 := by
    intro X
    have h1 := Date.dayOfYear_lt X
    have h2 : Date.daysInYear X.year ≤ 366 := by unfold Date.daysInYear; split <;> omega
    have h3 := X.valid.2.1
    simp only [Date.ordinal, Date.daysBeforeYear]
    omega
  have := bound T; have := bound D
  simp only [Date.daysBetween, Date.epochDay]
  omega

end Abstraction.FlightSearch.Period
