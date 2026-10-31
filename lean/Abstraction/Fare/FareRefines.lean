import Abstraction.Fare.Alpha

/-!
# Abstraction.Fare.FareRefines

R 課題 ABS-002（運賃）: `SourceModel.FareQuery.fareConcrete`（`calculateFare`）は、既知差異 D-002・D-027 の前提の下で、
[Spec] の `Spec.Fare.fareMachine` をリファインする。あわせて、C 課題 ABS-003（差は 0〜100 円）と、
D-002 の必要性（W 課題 ABS-102）を示す。
-/

namespace Abstraction.Fare

open Machine LangSemantics.Java Spec LangSemantics.Core Abstraction.MasterData SourceModel.FareQuery

/-- 入力の像があり PRE を満たすとき、`calculateFare` は例外を投げず、double の式の値を返す。 -/
theorem calculateFare_eq {ic : FareInput} {i : Spec.Fare.FareInput} (h : aiF ic = some i) (hp : i.Pre) :
    SourceModel.Fare.calculateFare ic.basicFare ic.discountRate =
      .ok (bdCeilHundredUp (jd2i (jdmul (jd (i.basicFare : Int)) (fareFactor i.discountRate)))) := by
  simp only [aiF, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨b, hb, r, hr, rfl⟩ := h
  rw [natOfJ32_eq_some] at hb hr
  have hr100 : r ≤ 100 := hp.2
  have e1 : jAssert (decide ((b : Int) ≥ 0)) "basicFare must be 0 or higher." = .ok () := by simp [jAssert]
  have e2 : jAssert (decide ((r : Int) ≥ 0)) "discountRate must be 0 or higher." = .ok () := by simp [jAssert]
  have e3 : jAssert (decide ((r : Int) ≤ 100)) "discountRate must be 100 or less." = .ok () := by
    simp [jAssert]; omega
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

/-- R 課題 ABS-002。 -/
@[obligation "ABS-002"]
theorem fareRefines : Refines (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    have e := calculateFare_eq hα hpre.1
    refine ⟨⟨_, rfl⟩, fun err he => ?_⟩
    have he' : Except.error err =
        (SourceModel.Fare.calculateFare ic.basicFare ic.discountRate).map fun o => ((), o) := he
    rw [e] at he'
    cases he'
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    have e := calculateFare_eq hα hpre.1
    have hs' : Except.ok (t', oc) =
        (SourceModel.Fare.calculateFare ic.basicFare ic.discountRate).map fun o => ((), o) := hs
    rw [e] at hs'
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at hs'
    obtain ⟨-, rfl⟩ := hs'
    refine ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ?_⟩
    obtain ⟨hr, hb, hbr⟩ := fare_range hpre.1
    exact natOfJ32_eq_some.mpr (fare_src_eq' hr hb hbr hpre.2)

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem fareRefines_initSurj :
    Refines.InitSurj (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- C 課題 ABS-003: 値域内では、[Source] の運賃は [Spec] の運賃に等しいか 100 円少ない（D-002 の前提によらない）。 -/
@[obligation "ABS-003"]
theorem fare_diff {ic : FareInput} {i : Spec.Fare.FareInput} (h : aiF ic = some i) (hp : i.Pre) :
    ∃ v, SourceModel.Fare.calculateFare ic.basicFare ic.discountRate = .ok v ∧
      (v.val = Spec.Fare.fare i.basicFare i.discountRate ∨
        v.val + 100 = Spec.Fare.fare i.basicFare i.discountRate) := by
  refine ⟨_, calculateFare_eq h hp, ?_⟩
  obtain ⟨hr, hb, hbr⟩ := fare_range hp
  rcases fare_src hr hb hbr with e | ⟨-, -, e⟩
  · exact Or.inl e
  · exact Or.inr e

/-- W 課題 ABS-102（D-002 の必要性。G9）: 前提を外すと、ABS-002 は成り立たない。基本運賃 1430 円・割引率 30% で、
[Source] は 1000 円、[Spec] は 1100 円。 -/
@[obligation "ABS-102"]
theorem need_D002 : ¬ Refines Spec.Fare.fareMachine (fareConcrete.restrict dev_D027F) glueF := fun h => by
  have hα : aiF icF1430 = some ⟨1430, 30⟩ := rfl
  have hpre : Spec.Fare.FareInput.Pre ⟨1430, 30⟩ := by decide
  obtain ⟨s', oa, hst, -, ho⟩ := h.correct () () icF1430 ⟨1430, 30⟩ () (J32.ofInt 1000) trivial
    (Or.inl ⟨rfl, trivial⟩) hα hpre ⟨trivial, by unfold dev_D027F; decide⟩ (by
      show Except.ok ((), J32.ofInt 1000) = _
      rfl)
  have : oa = 1100 := hst
  subst this
  rcases ho with ho | ho
  · exact absurd ho (by decide)
  · exact ho

end Abstraction.Fare
