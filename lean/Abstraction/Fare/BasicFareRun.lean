import Abstraction.Fare.Alpha

/-!
# Abstraction.Fare.BasicFareRun

R 課題 ABS-001（基本運賃。`Abstraction.Fare.basicFareRefines`）と W 課題 ABS-101（`Abstraction.Fare.need_D001`）の補題。
`SourceModel.FareQuery.basicFareConcrete`（起動時の読み込みと `calculateBasicFare`）の実行と、L 課題 ABS-007
（[Source] は [Spec] に等しいか 1 小さい。`runBasicFare_spec`）、D-001 の必要性の証人の実行（`runBasicFare_icBF29`）を示す。
-/

namespace Abstraction.Fare.BasicFareRun
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.Alpha Abstraction.Fare.Factors Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf
  Abstraction.MasterData.Lookup Abstraction.MasterData.Query Abstraction.MasterData.QueryRun
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas

open LangSemantics.Java Spec LangSemantics.Core SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Spring SourceModel.MasterQuery SourceModel.FareQuery

/-- 積算比率は値域内（MD-8）。 -/
theorem ratioOn_le {md : MasterData} (h8 : md.MD8) (d : Spec.Prim.Date) : md.multiplicationRatioOn d ≤ 1000 := by
  unfold MasterData.multiplicationRatioOn MasterData.peakTimeOn
  split
  · rename_i p hp
    exact h8.2.2.1 p (List.mem_of_find?_eq_some hp)
  · decide

/-- 搭乗クラスのキャッシュの答えから、加算料金を取り出す。 -/
theorem extraCharge_of_answer {r : JRef SourceModel.Domain.Model.BoardingClass} {bc : BoardingClass}
    (h : answerOf? (.boardingClass r) = some (.boardingClass (some bc.info))) :
    ∃ b e, r = some b ∧ b.extraCharge = some e ∧ e.val = (bc.extraCharge : Int) := by
  cases r with
  | none => simp [answerOf?, AnswerOf.opt] at h
  | some b =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, Spec.MasterQuery.Answer.boardingClass.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [AnswerOf.boardingClass, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, -, nm, -, ex, hex, he⟩ := hx
    obtain ⟨e, he1, he2⟩ := hex
    refine ⟨b, e, rfl, he1, ?_⟩
    rw [natOfJ32_eq_some] at he2
    have : ex = bc.extraCharge := by
      have := congrArg MasterData.BoardingClassInfo.extraCharge he
      simpa [BoardingClass.info] using this
    rw [he2, this]

/-- L 課題 ABS-007: 前提（D-027 と [Spec] の PRE）を満たす入力では、どの許される並びでも、[Source] の基本運賃は
例外を投げず、[Spec] の基本運賃 `X·c/100` に等しいか、`X·c` が 100 で割り切れ、積算比率 `c` が安全でない一覧にあり、
1 小さい。 -/
@[obligation "ABS-007"]
theorem runBasicFare_spec {ic : BasicFareInput} {ia : Spec.Fare.BasicFareInput} (hα : aiBF ic = some ia)
    (hp : ia.Pre) {o : Order} (ho : o.Allowed ic.db) :
    ∃ v X c, runBasicFare ic o = .ok v ∧
      Spec.Fare.basicFare ia.md ia.routeBasicFare ia.boardingClassCd ia.depDate = some (X * c / 100) ∧
      c = ia.md.multiplicationRatioOn ia.depDate ∧
      (∃ bc, ia.md.boardingClassOf ia.boardingClassCd = some bc ∧ X = ia.routeBasicFare + bc.extraCharge) ∧
      (v.val = ((X * c / 100 : Nat) : Int) ∨
        (X * c % 100 = 0 ∧ 0 < X * c ∧ c ∈ unsafeBasicRatios ∧ v.val + 1 = ((X * c / 100 : Nat) : Int))) := by
  simp only [aiBF, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hα
  obtain ⟨cfg, -, md, hm, b, hb, cd, hcd, d, hd, rfl⟩ := hα
  obtain ⟨dj, hdj, hD⟩ := hd
  rw [natOfJ32_eq_some] at hb
  obtain ⟨hok, hbx⟩ := hp
  obtain ⟨-, hv⟩ := hok.valid
  simp only at hv hbx
  cases hbc : md.boardingClassOf cd with
  | none => rw [hbc] at hbx; cases hbx
  | some bc =>
  rw [hbc] at hbx
  simp only [Option.any_some, decide_eq_true_eq] at hbx
  have hbx' : b + bc.extraCharge ≤ 10000000 := hbx
  obtain ⟨p, hl, hpt, hbq⟩ := load_correct hm hv ho
  obtain ⟨bJ, e, hget, hex, heval⟩ := extraCharge_of_answer (by rw [hbq cd, hbc]; rfl)
  obtain ⟨-, -, -, -, hppt, -⟩ := ho
  obtain ⟨n, hn, hna⟩ := ratio_query hm hv.md4 hppt hD p.boardingClass
  simp only [answerOf?, Option.map_eq_some_iff, Spec.MasterQuery.Answer.ratio.injEq] at hna
  obtain ⟨c, hc, rfl⟩ := hna
  rw [natOfJ32_eq_some] at hc
  have hshared : p.shared = { boardingClassProvider := p.boardingClass, peakTimeProvider := PeakTimeProvider.load o.peakTime } := by
    rw [← hpt]; rfl
  have hadd : (j32add ic.basicFareOfRoute e).val = ((b + bc.extraCharge : Nat) : Int) := by
    rw [j32add_val_of_inRange _ _ (by simp only [J32.minValue, J32.maxValue]; omega), hb, heval]; push_cast; rfl
  have hc1000 := ratioOn_le hv.md8 d
  obtain ⟨X, hXdef⟩ : ∃ X, X = b + bc.extraCharge := ⟨_, rfl⟩
  obtain ⟨C, hCdef⟩ : ∃ C, C = md.multiplicationRatioOn d := ⟨_, rfl⟩
  rw [← hXdef] at hadd hbx'
  rw [← hCdef] at hc hc1000
  have hr : X * C < 100 * 2 ^ 28 :=
    Nat.lt_of_le_of_lt (Nat.mul_le_mul hbx' hc1000) (by decide)
  have hX : X < 2 ^ 53 := by omega
  have hrun : runBasicFare ic o = .ok (jd2i (jdmul (jd (X : Int)) (basicFactor C))) := by
    simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, runBasicFare, hl, ok_bind, SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare, hcd, hdj, hshared]
    simp only [Assert.isTrue, hb, Option.isSome_some, decide_true, ite_true, ok_bind, Int.natCast_nonneg, ge_iff_le,
      BoardingClassProvider.getBoardingClass, LangSemantics.Java.Spring.Assert.notNullValue_some, pure_bind, hget, JRef.deref, hex]
    rw [hn]
    simp only [ok_bind, hadd, hc, basicFactor]
    rfl
  refine ⟨_, X, C, hrun, ?_, hCdef, ⟨bc, rfl, hXdef⟩, ?_⟩
  · simp only [Spec.Fare.basicFare, hbc, Option.map_some, hXdef, hCdef]
  · rcases basicFare_src hc1000 hX hr with h | ⟨h1, h2, h3, h4⟩
    · exact Or.inl h
    · right
      refine ⟨h1, h2, ?_, h4⟩
      by_cases hm' : C ∈ unsafeBasicRatios
      · exact hm'
      · exact absurd (basicFactor_safe_of (by rintro h0; rw [h0] at h2; simp at h2) hc1000 hm') h3

/-- `icBF29` の [Source] の基本運賃は 28 円（`(int)(100 * (29 * 0.01))`）。 -/
theorem runBasicFare_icBF29 : runBasicFare icBF29 (mergeOrder db29) = .ok (J32.ofInt 28) := by
  rfl

end Abstraction.Fare.BasicFareRun
