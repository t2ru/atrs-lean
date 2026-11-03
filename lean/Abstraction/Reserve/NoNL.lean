import Abstraction.Reserve.MemberCheck
import Abstraction.Reserve.Catch
import Abstraction.Reserve.ValidateReservation
import Abstraction.MasterData.Pre

/-!
# Abstraction.Reserve.NoNL

ABS-041 の補題: 予約内容の検証の業務例外のコードと引数は改行を含まない（backlog aedf の第 3 段）。引数は、設定の整数・
位置（自然数の文字列）とマスタの運賃種別名で、運賃種別名は D-027 の前提で改行を含まない。具体機械の `catchReserve`
が業務例外のメッセージをコードと引数に戻すのに使う（`Abstraction.Reserve.Catch.catch_business`）。
-/

namespace Abstraction.Reserve.NoNL
open Abstraction.Reserve.Catch Abstraction.Reserve.Validate Abstraction.Reserve.MemberCheck Spec.Error

theorem noNL_toString (n : Nat) : NoNL (toString n) := by
  intro h
  have e : (toString n).toList = Nat.toDigits 10 n := by
    simp [toString, Nat.repr]
  rw [e] at h
  have := Nat.isDigit_of_mem_toDigits (by decide) (by decide) h
  exact absurd this (by decide)

theorem noNL_repr (n : Nat) : NoNL n.repr := noNL_toString n

/-- 業務例外のコードと引数が改行を含まない。 -/
def BizNL (x : Except AtrsError Unit) : Prop :=
  ∀ c args, x = .error (.business c args) → NoNL c ∧ ∀ a ∈ args, NoNL a

theorem BizNL.ok : BizNL (.ok ()) := fun _ _ h => by cases h

theorem BizNL.bind {x y : Except AtrsError Unit} (hx : BizNL x) (hy : BizNL y) : BizNL (x.bind fun _ => y) := by
  intro c args h
  cases x with
  | error e => exact hx c args h
  | ok u => exact hy c args h

theorem checkRepAge_nl (cfg : Spec.Config) (d : Spec.UseCase.Reserve.Draft) :
    BizNL (Spec.UseCase.Reserve.checkRepAge cfg d) := by
  intro c args h
  unfold Spec.UseCase.Reserve.checkRepAge at h
  split at h
  · simp only [Except.error.injEq, AtrsError.business.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    refine ⟨by decide, ?_⟩
    intro a ha
    simp only [List.mem_singleton] at ha
    subst ha
    exact noNL_toString _
  · cases h

theorem specFareTypeOf_nl {FT : Spec.MasterData.FareType} (hft : NoNL FT.fareTypeName)
    (qs : List Spec.Model.Passenger) : BizNL (specFareTypeOf FT qs) := by
  intro c args h
  unfold specFareTypeOf at h
  split at h
  · split at h
    · simp only [Except.error.injEq, AtrsError.business.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact ⟨by decide, by simp⟩
    · cases h
  · split at h
    · simp only [Except.error.injEq, AtrsError.business.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      refine ⟨by decide, ?_⟩
      intro a ha
      simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with rfl | rfl
      · exact hft
      · exact noNL_toString _
    · cases h
  · cases h

theorem firstErr_nl : ∀ {xs : List (Except AtrsError Unit)}, (∀ x ∈ xs, BizNL x) → BizNL (firstErr xs)
  | [], _ => BizNL.ok
  | x :: xs, h => by
    cases x with
    | error e => exact h _ (List.mem_cons_self ..)
    | ok u =>
      cases u
      show BizNL (firstErr xs)
      exact firstErr_nl fun y hy => h y (List.mem_cons_of_mem _ hy)

theorem checkRepMember_nl (w : Spec.Port.World) (d : Spec.UseCase.Reserve.Draft) :
    BizNL (Spec.UseCase.Reserve.checkRepMember w d) := by
  intro c args h
  unfold Spec.UseCase.Reserve.checkRepMember at h
  split at h
  · cases h
  · split at h
    · simp only [Except.error.injEq, AtrsError.business.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact ⟨by decide, by simp⟩
    · split at h
      · cases h
      · simp only [Except.error.injEq, AtrsError.business.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨by decide, by simp⟩

theorem checkOne_nl (w : Spec.Port.World) (p : Spec.Model.Passenger) (i : Nat) : BizNL (checkOne w p i) := by
  intro c args h
  unfold checkOne at h
  split at h
  · cases h
  · split at h
    · simp only [Except.error.injEq, AtrsError.business.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact ⟨by decide, fun a ha => by simp only [List.mem_singleton] at ha; subst ha; exact noNL_toString _⟩
    · split at h
      · cases h
      · simp only [Except.error.injEq, AtrsError.business.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨by decide, fun a ha => by simp only [List.mem_singleton] at ha; subst ha; exact noNL_toString _⟩

theorem pmFrom_nl (w : Spec.Port.World) : ∀ (ps : List Spec.Model.Passenger) (i : Nat), BizNL (pmFrom w ps i)
  | [], _ => BizNL.ok
  | p :: ps, i => BizNL.bind (checkOne_nl w p i) (pmFrom_nl w ps (i + 1))

/-- マスタの運賃種別名は、表の行の運賃種別名（D-027 の前提で改行を含まない）。 -/
theorem fareTypeNames_noNL {db : SourceModel.Db.Schema.MasterDb} {md : Spec.MasterData}
    (hm : Abstraction.MasterData.Alpha.masterDataOf db = some md)
    (h : ∀ ft ∈ db.fareType, '\n' ∉ ft.fareTypeName.val.toList) : ∀ FT ∈ md.fareTypes, NoNL FT.fareTypeName := by
  intro FT hFT
  have hft := (Abstraction.MasterData.Pre.masterDataOf_eq_some.mp hm).2.2.2.2.1
  obtain ⟨r, hr, hrf⟩ := LangSemantics.Core.MapM.mapM_some_mem' hft hFT
  simp only [Abstraction.MasterData.Alpha.fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hrf
  obtain ⟨_, -, _, -, _, -, _, -, _, -, _, -, rfl⟩ := hrf
  exact h r hr

theorem forall₂_mem_right {α β : Type} {R : α → β → Prop} :
    ∀ {l : List α} {l' : List β}, LangSemantics.Core.List.Forall₂ R l l' → ∀ b ∈ l', ∃ a ∈ l, R a b
  | [], [], .nil, _, hb => by simp at hb
  | a :: l, b' :: l', .cons hab hr, b, hb => by
    simp only [List.mem_cons] at hb
    rcases hb with rfl | hb
    · exact ⟨a, List.mem_cons_self .., hab⟩
    · obtain ⟨a', ha', h⟩ := forall₂_mem_right hr b hb
      exact ⟨a', List.mem_cons_of_mem _ ha', h⟩

/-- 予約内容の検証の業務例外のコードと引数は、改行を含まない。 -/
theorem validate_nl {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World} {d : Spec.UseCase.Reserve.Draft}
    {FTs : List Spec.MasterData.FareType}
    (hkf : LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) d.flights FTs)
    (hft : ∀ FT ∈ md.fareTypes, NoNL FT.fareTypeName) {v : Except AtrsError Unit}
    (hv : Spec.UseCase.Reserve.validateReservation cfg md w d = some v) : BizNL v := by
  simp only [Spec.UseCase.Reserve.validateReservation, Abstraction.Reserve.ValidateReservation.checkFareTypes_eq hkf,
    Option.bind_eq_bind, Option.bind_some, Option.pure_def, Option.some.injEq] at hv
  subst hv
  refine BizNL.bind (checkRepAge_nl cfg d) (BizNL.bind (firstErr_nl ?_)
    (BizNL.bind (checkRepMember_nl w d) ?_))
  · intro x hx
    simp only [List.mem_map] at hx
    obtain ⟨FT, hFT, rfl⟩ := hx
    obtain ⟨k, -, hk⟩ := forall₂_mem_right hkf FT hFT
    exact specFareTypeOf_nl (hft FT (by unfold Spec.MasterData.fareTypeOf at hk; exact List.mem_of_find?_eq_some hk)) _
  · rw [checkPassengerMembers_eq]
    exact pmFrom_nl w _ 0

end Abstraction.Reserve.NoNL
