import Abstraction.Fare.Alpha

/-!
# Abstraction.Fare.FareRun

R 課題 ABS-002（運賃。`Abstraction.Fare.fareRefines`）・C 課題 ABS-003・W 課題 ABS-102 の補題。
`SourceModel.FareQuery.fareConcrete`（`calculateFare`）の値（`calculateFare_eq`）と、[Spec] の運賃の値域（`fare_range`）を示す。
-/

namespace Abstraction.Fare.FareRun
open Abstraction.Fare.Alpha Abstraction.Fare.Factors Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Lookup
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.ResultLemmas

open LangSemantics.Java SourceModel.FareQuery
open LangSemantics.Java.Spring

/-- 入力の像があり PRE を満たすとき、`calculateFare` は例外を投げず、double の式の値を返す。 -/
theorem calculateFare_eq {ic : FareInput} {i : Spec.Fare.FareInput} (h : aiF ic = some i) (hp : i.Pre) :
    SourceModel.Fare.calculateFare ic.basicFare ic.discountRate =
      .ok (bdCeilHundredUp (jd2i (jdmul (jd (i.basicFare : Int)) (fareFactor i.discountRate)))) := by
  simp only [aiF, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨b, hb, r, hr, rfl⟩ := h
  rw [natOfJ32_eq_some] at hb hr
  have hr100 : r ≤ 100 := hp.2
  have e1 : Assert.isTrue (decide ((b : Int) ≥ 0)) "basicFare must be 0 or higher." = .ok () := by simp [Assert.isTrue]
  have e2 : Assert.isTrue (decide ((r : Int) ≥ 0)) "discountRate must be 0 or higher." = .ok () := by simp [Assert.isTrue]
  have e3 : Assert.isTrue (decide ((r : Int) ≤ 100)) "discountRate must be 100 or less." = .ok () := by
    simp [Assert.isTrue]; omega
  simp only [SourceModel.Fare.calculateFare, hb, hr, e1, e2, e3, ok_bind, SourceModel.Fare.ceilFare, fareFactor]
  rfl

/-- 値域内の運賃の式の値（`fare_src` の前提）。 -/
theorem fare_range {i : Spec.Fare.FareInput} (hp : i.Pre) :
    i.discountRate ≤ 100 ∧ i.basicFare < 2 ^ 53 ∧ i.basicFare * (100 - i.discountRate) < 100 * 2 ^ 28 := by
  obtain ⟨h1, h2⟩ := hp
  have h1' : i.basicFare ≤ 100000000 := h1
  have h2' : i.discountRate ≤ 100 := h2
  refine ⟨h2', by omega, ?_⟩
  calc i.basicFare * (100 - i.discountRate) ≤ 100000000 * 100 := Nat.mul_le_mul h1' (by omega)
    _ < 100 * 2 ^ 28 := by decide

end Abstraction.Fare.FareRun
