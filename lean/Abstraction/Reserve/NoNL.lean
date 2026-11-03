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
  ∀ be, x = .error (.business be) → NoNL be.code ∧ ∀ a ∈ be.args, NoNL a

theorem BizNL.ok : BizNL (.ok ()) := fun _ h => by cases h

/-- 業務エラーのコードは改行を含まない。 -/
theorem code_noNL (be : BusinessError) : NoNL be.code := by
  cases be <;> simp only [BusinessError.code] <;> decide

/-- 引数の無い業務エラー・自然数の文字列の引数の業務エラー。 -/
theorem bizNL_of {be : BusinessError} (h : ∀ a ∈ be.args, NoNL a) : BizNL (.error (.business be)) := by
  intro be' h'
  simp only [Except.error.injEq, AtrsError.business.injEq] at h'
  subst h'
  exact ⟨code_noNL _, h⟩

theorem BizNL.bind {x y : Except AtrsError Unit} (hx : BizNL x) (hy : BizNL y) : BizNL (x.bind fun _ => y) := by
  intro be h
  cases x with
  | error e => exact hx be h
  | ok u => exact hy be h

theorem checkRepAge_nl (cfg : Spec.Config) (d : Spec.UseCase.Reserve.Draft) :
    BizNL (Spec.UseCase.Reserve.checkRepAge cfg d) := by
  unfold Spec.UseCase.Reserve.checkRepAge
  split
  · exact bizNL_of fun a ha => by
      simp only [BusinessError.args, List.mem_singleton] at ha; subst ha; exact noNL_toString _
  · exact BizNL.ok

theorem specFareTypeOf_nl {FT : Spec.MasterData.FareType} (hft : NoNL FT.fareTypeName)
    (qs : List Spec.UseCase.Reserve.DraftPassenger) : BizNL (specFareTypeOf FT qs) := by
  unfold specFareTypeOf
  split
  · split
    · exact bizNL_of (by simp [BusinessError.args])
    · exact BizNL.ok
  · split
    · refine bizNL_of fun a ha => ?_
      simp only [BusinessError.args, List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with rfl | rfl
      · exact hft
      · exact noNL_toString _
    · exact BizNL.ok
  · exact BizNL.ok

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
  unfold Spec.UseCase.Reserve.checkRepMember
  split
  · exact BizNL.ok
  · split
    · exact bizNL_of (by simp [BusinessError.args])
    · split
      · exact BizNL.ok
      · exact bizNL_of (by simp [BusinessError.args])

theorem checkOne_nl (w : Spec.Port.World) (p : Spec.UseCase.Reserve.DraftPassenger) (i : Nat) : BizNL (checkOne w p i) := by
  unfold checkOne
  split
  · exact BizNL.ok
  · split
    · exact bizNL_of fun a ha => by
        simp only [BusinessError.args, List.mem_singleton] at ha; subst ha; exact noNL_toString _
    · split
      · exact BizNL.ok
      · exact bizNL_of fun a ha => by
          simp only [BusinessError.args, List.mem_singleton] at ha; subst ha; exact noNL_toString _

theorem pmFrom_nl (w : Spec.Port.World) : ∀ (ps : List Spec.UseCase.Reserve.DraftPassenger) (i : Nat), BizNL (pmFrom w ps i)
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
