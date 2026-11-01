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
open Abstraction.Fare.TotalAlpha Abstraction.FlightSearch.Alpha Abstraction.MasterData.Pre Spec.Model
open SourceModel.FlightSearch SourceModel.FlightSearchQuery SourceModel.Repository.Schema Spec.Prim.Text
  LangSemantics.Core.List

/-- マスタの DB。 -/
def dbFS : MasterDb := dbTF ⟨100000, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩

/-- FLIGHT 表（1970-01-01 の NTT001・N・OW、空席 10）。 -/
def fdFS : FlightDb := ⟨[⟨⟨0, by decide⟩, ⟨"NTT001", by decide⟩, ⟨"N", by decide⟩, ⟨"OW", by decide⟩, ⟨10, by decide⟩⟩]⟩

/-- 配備の環境の区切り文字 `sep` で、1970-01-01 に HND→ITM の片道・N を照会する入力。 -/
def icFS (sep : Char) : SearchInput :=
  { db := dbFS, config := SourceModel.Config.upstreamConfig, today := ⟨1970, 1, 1⟩,
    criteria := some { flightType := some .OW, departureAirportCd := some "HND", arrivalAirportCd := some "ITM",
                       depDate := some ⟨1970, 1, 1⟩, boardingClassCd := some .N },
    groupingSeparator := sep }

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
def wFS : Spec.Port.World := ⟨[⟨⟨day0, ⟨"NTT001"⟩, .N, .OW⟩, 10⟩]⟩

theorem aiS_icFS : aiS (icFS '.') = some iaFS := by decide

theorem worldOfDb_fdFS : worldOfDb fdFS = some wFS := rfl

theorem wFS_inv : wFS.Inv := by decide

theorem hasText_ok (s : String) (h : hasText s = true) (m : String) :
    SourceModel.MasterData.assertHasText s m = .ok () := assertHasText_ok h m

theorem iaFS_pre : Spec.FlightSearch.SearchInput.Pre wFS iaFS := by
  have hN : hasText "NTT001" = true := by rw [hasText, string_any_toList]; decide
  have hH : hasText "HND" = true := by rw [hasText, string_any_toList]; decide
  have hI : hasText "ITM" = true := by rw [hasText, string_any_toList]; decide
  refine ⟨by decide, ⟨by decide, by decide, by decide, by decide, by decide, by decide, by decide, ?_⟩, rfl, hH, hI, ?_⟩
  · refine ⟨?_, by decide, by decide, by decide⟩
    intro a ha
    simp only [iaFS, mdFS, List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl <;> exact ⟨⟨by decide, by rw [String.all_bool_eq]; decide⟩, by decide⟩
  · intro fm hfm
    simp only [iaFS, mdFS, List.mem_cons, List.not_mem_nil, or_false] at hfm
    subst hfm
    exact hN

theorem iaFS_devs : dev_D001S iaFS ∧ dev_D002S iaFS := by
  refine ⟨fun r hr => ?_, fun r b hr hb ft hft => ?_⟩
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
    SourceModel.MasterData.assertHasText s m =
      LangSemantics.Java.Exception.jAssert (s.toList.any fun c => !LangSemantics.Java.String.isJavaWhitespace c) m := by
  simp only [SourceModel.MasterData.assertHasText, string_any_toList]

/-- [Source] の結果の写し（区切り文字 `.`）: 運賃の表示は `100.000`。 -/
def vDot : Spec.FlightSearch.FlightVacantInfo :=
  ⟨⟨"NTT001"⟩, "Haneda", "Itami", "08:00", "09:00", "1970/01/01", .N, [(.OW, ⟨"OW", "100.000", 10⟩)]⟩

/-- 区切り文字 `.` での [Source] の 1 歩（許される並びの 1 つ）の結果の写しは `vDot` の 1 件。 -/
theorem run_icFS_dot :
    ∃ oc, catchBusiness (runSearchFlight fdFS (icFS '.') (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) = .ok oc ∧ aoS oc = some (.ok [vDot]) := by
  have h : (match catchBusiness (runSearchFlight fdFS (icFS '.') (Abstraction.MasterData.QueryRun.mergeOrder dbFS)
      Abstraction.FlightSearch.Order.mergeSortRows) with
      | .ok oc => match aoS oc with
        | some (.ok l) => l == [vDot]
        | _ => false
      | .error _ => false) = true := by
    simp only [runSearchFlight, SourceModel.FlightSearch.searchFlight, SourceModel.MasterData.getRouteByAirportCd,
      SourceModel.MasterData.getFlightMaster, assertHasText_eq]
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

end Abstraction.FlightSearch.Witness
