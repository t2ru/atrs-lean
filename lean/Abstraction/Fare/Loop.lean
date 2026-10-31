import Abstraction.Fare.TotalAlpha
import Abstraction.Fare.Load
import Abstraction.Fare.BasicFareRun

/-!
# Abstraction.Fare.Loop

`calculateTotalFare` の `for` 文（`forIn`）と、合計金額の R 課題（ABS-004）で使う補題。
`for` 文・`int` の演算・`mapM` の汎用の補題は、スキルの `LangSemantics.Java.IntLemmas`・`LangSemantics.Core` にある。
-/

namespace Abstraction.Fare.Loop
open Spec.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.Alpha Abstraction.Fare.BasicFareRun Abstraction.Fare.Factors Abstraction.Fare.Load Abstraction.Fare.TotalAlpha Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.CodeList Abstraction.MasterData.Join Abstraction.MasterData.Key Abstraction.MasterData.Load Abstraction.MasterData.Lookup Abstraction.MasterData.Pre Abstraction.MasterData.Query Abstraction.MasterData.QueryRun Spec.CodeList Spec.Config Spec.EnvPre Spec.MasterQuery Spec.Model Spec.Prim.Format Spec.Prim.Int Spec.Prim.Text Spec.Prim.Time
open LangSemantics.Java.DoubleOps
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String

open LangSemantics.Java Spec Spec.Prim LangSemantics.Core Abstraction.MasterData

end Abstraction.Fare.Loop

namespace Abstraction.Fare.Loop
open Spec.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.Alpha Abstraction.Fare.BasicFareRun Abstraction.Fare.Factors Abstraction.Fare.Load Abstraction.Fare.TotalAlpha Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.CodeList Abstraction.MasterData.Join Abstraction.MasterData.Key Abstraction.MasterData.Load Abstraction.MasterData.Lookup Abstraction.MasterData.Pre Abstraction.MasterData.Query Abstraction.MasterData.QueryRun Spec.CodeList Spec.Config Spec.EnvPre Spec.MasterQuery Spec.Model Spec.Prim.Format Spec.Prim.Int Spec.Prim.Text Spec.Prim.Time
open LangSemantics.Java.DoubleOps
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String

open LangSemantics.Java Spec Spec.Prim LangSemantics.Core Abstraction.MasterData SourceModel.MasterData
  SourceModel.MasterQuery

/-- 読み込んだ Provider での `calculateBasicFare`: D-001 の前提の下で、[Spec] の基本運賃 `X·C/100` を返す。 -/
theorem calculateBasicFare_eq {db : SourceModel.Repository.Schema.MasterDb} {cfg : Config} {md : MasterData}
    (hm : masterDataOf db = some md) (hv : md.Valid cfg) {o : Order}
    (hppt : o.peakTime.Perm (SourceModel.Repository.MasterData.peakTimeFindAll db)) {p : Providers}
    (hpt : p.peakTime = PeakTimeProvider.load o.peakTime) {cd : BoardingClassCd} {bJ : SourceModel.Model.BoardingClass}
    (hget : p.boardingClass.boardingClassCodeMap.get cd = some bJ) {e : J32} (hex : bJ.extraCharge = some e)
    {ex : Nat} (heval : e.val = (ex : Int)) {rbJ : J32} {b : Nat} (hb : rbJ.val = (b : Int)) {dj : JLocalDate}
    {D : Spec.Prim.Date} (hD : dateOfJ dj = some D) (hX : b + ex ≤ 10000000)
    (hdev : (b + ex) * md.multiplicationRatioOn D % 100 ≠ 0 ∨ md.multiplicationRatioOn D ∉ unsafeBasicRatios) :
    ∃ v, SourceModel.Fare.calculateBasicFare p.shared rbJ (some cd) (some dj) = .ok v ∧
      v.val = (((b + ex) * md.multiplicationRatioOn D / 100 : Nat) : Int) := by
  obtain ⟨n, hn, hna⟩ := ratio_query hm hv.md4 hppt hD p.boardingClass
  simp only [answerOf?, Option.map_eq_some_iff, Spec.MasterQuery.Answer.ratio.injEq] at hna
  obtain ⟨c, hc, hcc⟩ := hna
  rw [natOfJ32_eq_some] at hc
  have hshared : p.shared = ⟨p.boardingClass, PeakTimeProvider.load o.peakTime⟩ := by
    rw [← hpt]; rfl
  have hadd : (j32add rbJ e).val = ((b + ex : Nat) : Int) := by
    rw [j32add_val_of_inRange _ _ (by simp only [J32.minValue, J32.maxValue]; omega), hb, heval]; push_cast; rfl
  have hc1000 := ratioOn_le hv.md8 D
  rw [← hcc] at hdev hc1000 ⊢
  have hr : (b + ex) * c < 100 * 2 ^ 28 :=
    Nat.lt_of_le_of_lt (Nat.mul_le_mul hX hc1000) (by decide)
  refine ⟨jd2i (jdmul (jd ((b + ex : Nat) : Int)) (basicFactor c)), ?_, basicFare_src_eq' hc1000 (by omega) hr hdev⟩
  simp only [SourceModel.Fare.calculateBasicFare, hshared]
  simp only [jAssert, hb, Option.isSome_some, decide_true, ite_true, ok_bind, Int.natCast_nonneg, ge_iff_le,
    getBoardingClass, pure_bind, hget, JRef.deref, hex]
  rw [hn]
  simp only [ok_bind, hadd, hc, basicFactor]
  rfl

/-- `calculateFare` の値（引数が非負で割引率が 100 以下）。 -/
theorem calculateFare_ok {bJ rJ : J32} {b r : Nat} (hb : bJ.val = (b : Int)) (hr : rJ.val = (r : Int)) (hr100 : r ≤ 100) :
    SourceModel.Fare.calculateFare bJ rJ =
      .ok (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))) := by
  have e1 : jAssert (decide ((b : Int) ≥ 0)) "basicFare must be 0 or higher." = .ok () := by simp [jAssert]
  have e2 : jAssert (decide ((r : Int) ≥ 0)) "discountRate must be 0 or higher." = .ok () := by simp [jAssert]
  have e3 : jAssert (decide ((r : Int) ≤ 100)) "discountRate must be 100 or less." = .ok () := by
    simp [jAssert]; omega
  simp only [SourceModel.Fare.calculateFare, hb, hr, e1, e2, e3, ok_bind, SourceModel.Fare.ceilFare, fareFactor]
  rfl

end Abstraction.Fare.Loop
