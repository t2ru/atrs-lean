import Abstraction.FlightSearch.Order
import Abstraction.Fare.TotalAlpha
import SourceModel.FlightSearchQuery

/-!
# Abstraction.FlightSearch.Witness

W 課題 ABS-132（D-032 の必要性）の証人: 区間の運賃 100,000 円・積算比率 100%・割引率 0 のマスタ（運賃計算の証人の
`dbTF` と同じ形）に、1970-01-01 の NTT001・N・OW のフライトが 1 つある状態で、片道を照会する。配備の環境の区切り文字を
`.` にすると、[Source] の運賃の表示は `100.000`、[Spec] は `100,000` になる。
-/

namespace Abstraction.FlightSearch.Witness
open Abstraction.World.Alpha
open Abstraction.Fare.TotalAlpha Abstraction.FlightSearch.Alpha Abstraction.MasterData.Pre Spec.Model
open SourceModel.Domain.Common.Exception SourceModel.Domain.Service.B1 SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareTypeUtil
  SourceModel.Domain.Common.Util.DateTimeUtil SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl SourceModel.Domain.Service.B1.FlightVacantInfoDto
  SourceModel.Domain.Service.B1.TicketSearchServiceImpl SourceModel.FlightSearchQuery SourceModel.Db.Schema Spec.Prim.Text
  LangSemantics.Core.List

/-- 区切り文字が `.` の記号（ドイツ語など）。 -/
def symDot : LangSemantics.Java.DecimalFormat.Symbols := ⟨'.', '0', "-"⟩

/-- マスタの DB。 -/
def dbFS : MasterDb := dbTF ⟨100000, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩

/-- FLIGHT 表（1970-01-01 の NTT001・N・OW、空席 10）。 -/
def fdFS : FlightDb := { flight := [⟨⟨0, by decide⟩, ⟨"NTT001", by decide⟩, ⟨"N", by decide⟩, ⟨"OW", by decide⟩, ⟨10, by decide⟩⟩] }

/-- 配備の環境の書式の記号 `sym` で、1970-01-01 に HND→ITM の片道・N を照会する入力。 -/
def icFS (sym : LangSemantics.Java.DecimalFormat.Symbols) : SearchInput :=
  { db := dbFS, config := SourceModel.AtrsProperties.upstreamConfig, today := ⟨1970, 1, 1⟩,
    sharedClock := (⟨1970, 1, 1⟩, ⟨1970, 1, 1⟩),
    criteria := some { flightType := some .OW, departureAirportCd := some "HND", arrivalAirportCd := some "ITM",
                       depDate := some ⟨1970, 1, 1⟩, boardingClassCd := some .N },
    formatSymbols := sym }

/-- マスタの [Spec] の写し。 -/
def mdFS : Spec.MasterData :=
  { airports := [⟨⟨"HND"⟩, "Haneda", 1⟩, ⟨⟨"ITM"⟩, "Itami", 2⟩],
    routes := [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100000⟩],
    flightMasters := [⟨⟨"NTT001"⟩, 1, ⟨8, 0, by decide⟩, ⟨9, 0, by decide⟩, "B777"⟩],
    boardingClasses := [⟨.N, "N", 0, 1⟩],
    fareTypes := [⟨.OW, "OW", 0, 355, 0, 1, 1⟩],
    peakTimes := [⟨"P", day0, day0, 100⟩],
    planes := [], creditTypes := [] }

/-- [Spec] の入力。 -/
def iaFS : Spec.FlightSearch.SearchInput := ⟨Spec.Config.default, mdFS, day0, ⟨day0, .N, ⟨"HND"⟩, ⟨"ITM"⟩, .OW⟩⟩

/-- [Spec] の状態。 -/
def wFS : Spec.Port.World := { flights := [⟨⟨day0, ⟨"NTT001"⟩, .N, .OW⟩, 10⟩] }

theorem aiS_icFS : aiS (icFS symDot) = some iaFS := by decide

theorem worldOfDb_fdFS : worldOfDb fdFS = some wFS := rfl

theorem wFS_inv : wFS.Inv := by decide

theorem hasText_ok (s : String) (h : hasText s = true) (m : String) :
    LangSemantics.Java.Spring.Assert.hasText s m = .ok () := assertHasText_ok h m

theorem iaFS_pre : Spec.FlightSearch.SearchInput.Pre wFS iaFS := by
  have hN : hasText "NTT001" = true := by rw [hasText, string_any_toList]; decide
  have hH : hasText "HND" = true := by rw [hasText, string_any_toList]; decide
  have hI : hasText "ITM" = true := by rw [hasText, string_any_toList]; decide
  refine ⟨by decide, ⟨by decide, by decide, by decide, by decide, by decide, by decide, by decide, ?_⟩, rfl, hH, hI, ?_⟩
  · refine ⟨?_, by decide, by decide, by decide⟩
    intro a ha
    simp only [iaFS, mdFS, List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl <;> exact ⟨⟨by decide, by rw [String.all_bool_eq]; decide⟩, by decide⟩
  · intro _ _ fm hfm _
    simp only [iaFS, mdFS, List.mem_cons, List.not_mem_nil, or_false] at hfm
    subst hfm
    exact hN

theorem iaFS_devs : dev_D001S iaFS ∧ dev_D002S iaFS := by
  refine ⟨fun r hr _ => ?_, fun r b hr _ hb ft hft _ => ?_⟩
  · have : r = ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100000⟩ := by
      have e : iaFS.md.routeOf iaFS.criteria.depAirportCd iaFS.criteria.arrAirportCd = some ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100000⟩ :=
        by decide
      rw [e] at hr; exact (Option.some.inj hr).symm
    subst this
    decide
  · have : r = ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100000⟩ := by
      have e : iaFS.md.routeOf iaFS.criteria.depAirportCd iaFS.criteria.arrAirportCd = some ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100000⟩ :=
        by decide
      rw [e] at hr; exact (Option.some.inj hr).symm
    subst this
    have : b = 100000 := by
      have e : Spec.Fare.basicFare iaFS.md 100000 iaFS.criteria.boardingClassCd iaFS.criteria.depDate = some 100000 :=
        by decide
      rw [e] at hb; exact (Option.some.inj hb).symm
    subst this
    simp only [iaFS, mdFS, List.mem_cons, List.not_mem_nil, or_false] at hft
    subst hft
    decide

theorem assertHasText_eq (s m : String) :
    LangSemantics.Java.Spring.Assert.hasText s m =
      LangSemantics.Java.Spring.Assert.isTrue (s.toList.any fun c => !LangSemantics.Java.String.isJavaWhitespace c) m := by
  simp only [LangSemantics.Java.Spring.Assert.hasText, string_any_toList]

/-- [Source] の結果の写し（区切り文字 `.`）: 運賃の表示は `100.000`。 -/
def vDot : Spec.FlightSearch.FlightVacantInfo :=
  ⟨⟨"NTT001"⟩, "Haneda", "Itami", "08:00", "09:00", "1970/01/01", .N, [(.OW, ⟨"OW", "100.000", 10⟩)]⟩

/-- 区切り文字 `.` での [Source] の 1 歩（許される並びの 1 つ）の結果の写しは `vDot` の 1 件。 -/
theorem run_icFS_dot :
    ∃ oc, catchBusiness (runSearchFlight fdFS (icFS symDot) (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) = .ok oc ∧ aoS oc = some (.ok [vDot]) := by
  have h : (match catchBusiness (runSearchFlight fdFS (icFS symDot) (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) with
      | .ok oc => match aoS oc with
        | some (.ok l) => l == [vDot]
        | _ => false
      | .error _ => false) = true := by
    simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, runSearchFlight, SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight, SourceModel.Domain.Common.Masterdata.RouteProvider.getRouteByAirportCd,
      SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster, assertHasText_eq]
    decide +kernel
  split at h
  · rename_i oc hoc
    refine ⟨oc, hoc, ?_⟩
    split at h
    · rename_i l hl
      rw [hl, beq_iff_eq.mp h]
    · cases h
  · cases h

/-- [Spec] の出力は `vDot` の 1 件ではない（運賃の表示は `100,000`）。 -/
theorem answer_ne_dot : Spec.FlightSearch.answer wFS iaFS ≠ .ok [vDot] := by
  have h : (match Spec.FlightSearch.answer wFS iaFS with
      | .ok l => l == [vDot]
      | .error _ => false) = false := by decide +kernel
  intro e
  rw [e] at h
  simp at h

/-! ## W 課題 ABS-114（D-014 の必要性）の証人 -/

/-- 1970-01-02。 -/
def day1 : Spec.Prim.Date := ⟨1970, 1, 2, by decide⟩

/-- 照会の途中で日付をまたいだ入力: `TicketSharedServiceImpl` が読む今日（`validateDepatureDate`・`getSearchLimitDate`）は
1970-01-01、その後に `searchFlight` が読む今日は 1970-01-02（Clock は進むだけ）。 -/
def icFS14 : SearchInput := { icFS LangSemantics.Java.DecimalFormat.Symbols.ascii with today := ⟨1970, 1, 2⟩ }

/-- `icFS14` の [Spec] の入力（今日は 1970-01-02）。 -/
def iaFS14 : Spec.FlightSearch.SearchInput := { iaFS with today := day1 }

theorem aiS_icFS14 : aiS icFS14 = some iaFS14 := by decide

theorem iaFS14_pre : Spec.FlightSearch.SearchInput.Pre wFS iaFS14 := iaFS_pre

/-- 搭乗日が照会可能期間の外なので、D-001・D-002 の前提は空虚に成り立つ。 -/
theorem iaFS14_devs : dev_D001S iaFS14 ∧ dev_D002S iaFS14 := by
  have hop : Spec.FlightSearch.outOfPeriod iaFS14.cfg iaFS14.today iaFS14.criteria.depDate = true := by decide
  exact ⟨fun _ _ h => absurd h (by rw [hop]; decide), fun _ _ _ h => absurd h (by rw [hop]; decide)⟩

/-- [Source] の 1 歩の結果は `FlightNotFoundException`（`e.ar.b1.2003`）: 照会可能期間の検査は共有サービスの今日で
通り、`beforeDayNum = daysBetween(1970-01-02, 1970-01-01) = −1` は予約可能期間に入らない。 -/
theorem run_icFS14 :
    catchBusiness (runSearchFlight fdFS icFS14 (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) = .ok (.error (.notFound "e.ar.b1.2003")) := by
  have h : (match catchBusiness (runSearchFlight fdFS icFS14 (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) with
      | .ok (.error (.notFound c)) => c == "e.ar.b1.2003"
      | _ => false) = true := by
    simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, runSearchFlight, SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight, SourceModel.Domain.Common.Masterdata.RouteProvider.getRouteByAirportCd,
      SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster, assertHasText_eq]
    decide +kernel
  split at h
  · rename_i c hc
    rw [hc, beq_iff_eq.mp h]
  · cases h

/-- [Spec] の出力は `NotFound` ではない（搭乗日が今日より前なので `Business("e.ar.b1.2001")`）。 -/
theorem answer_ne14 : Spec.FlightSearch.answer wFS iaFS14 ≠ .error (.notFound "e.ar.b1.2003") := by
  have h : (match Spec.FlightSearch.answer wFS iaFS14 with
      | .error (.notFound _) => false
      | _ => true) = true := by decide +kernel
  intro e
  rw [e] at h
  cases h

/-! ## 差異の述語の非自明性（G8） -/

open Machine.Preserves (Nontrivial) in
theorem dev_D032_nontrivial : Nontrivial dev_D032 :=
  ⟨⟨icFS LangSemantics.Java.DecimalFormat.Symbols.ascii, rfl⟩, ⟨icFS symDot, by unfold dev_D032; decide⟩⟩

open Machine.Preserves (Nontrivial) in
theorem dev_D027S_nontrivial : Nontrivial dev_D027S :=
  ⟨⟨icFS LangSemantics.Java.DecimalFormat.Symbols.ascii, by unfold dev_D027S; decide⟩, ⟨{ icFS LangSemantics.Java.DecimalFormat.Symbols.ascii with criteria := none }, by unfold dev_D027S; decide⟩⟩

/-- D-001 の前提を破るマスタ: 区間の運賃 100 円・積算比率 29%（`100·29` は 100 で割り切れ、29 は安全でない）。 -/
def mdFS29 : Spec.MasterData := { mdFS with routes := [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100⟩], peakTimes := [⟨"P", day0, day0, 29⟩] }

/-- D-002 の前提を破るマスタ: 基本運賃 1430 円・割引率 30%。 -/
def mdFS1430 : Spec.MasterData :=
  { mdFS with routes := [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 1430⟩], fareTypes := [⟨.OW, "OW", 30, 355, 0, 1, 1⟩] }

open Machine.Preserves (Nontrivial) in
theorem dev_D001S_nontrivial : Nontrivial dev_D001S := by
  refine ⟨⟨iaFS, iaFS_devs.1⟩, ⟨{ iaFS with md := mdFS29 }, fun h => ?_⟩⟩
  have := h ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100⟩ (by decide) (by decide)
  revert this
  decide

open Machine.Preserves (Nontrivial) in
theorem dev_D002S_nontrivial : Nontrivial dev_D002S := by
  refine ⟨⟨iaFS, iaFS_devs.2⟩, ⟨{ iaFS with md := mdFS1430 }, fun h => ?_⟩⟩
  have := h ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 1430⟩ 1430 (by decide) (by decide) (by decide) ⟨.OW, "OW", 30, 355, 0, 1, 1⟩
    (by simp [mdFS1430]) (by decide)
  revert this
  decide

open Machine.Preserves (Nontrivial) in
theorem dev_D014S_nontrivial : Nontrivial dev_D014S :=
  ⟨⟨icFS LangSemantics.Java.DecimalFormat.Symbols.ascii, rfl⟩, ⟨icFS14, by unfold dev_D014S; decide⟩⟩

end Abstraction.FlightSearch.Witness
