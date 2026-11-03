import Spec.UseCase.Reserve
import LangSemantics.Core.List

/-!
# Abstraction.Reserve.SpecFacts

ABS-041 の補題: [Spec] の予約の操作の値から読み取れる事実（backlog aedf の第 3 段）。選択フライトの検証が成功すれば、
各フライトは主キーで存在し、その運賃種別はマスタにある（`World.RefMaster`）。
-/

namespace Abstraction.Reserve.SpecFacts
open Spec.Ticket Spec.Error Spec.Model

theorem exists_forall₂ {α β : Type} {R : α → β → Prop} :
    ∀ {l : List α}, (∀ a ∈ l, ∃ b, R a b) → ∃ bs, LangSemantics.Core.List.Forall₂ R l bs
  | [], _ => ⟨[], .nil⟩
  | a :: l, h => by
    obtain ⟨b, hb⟩ := h a (List.mem_cons_self ..)
    obtain ⟨bs, hbs⟩ := exists_forall₂ (l := l) fun x hx => h x (List.mem_cons_of_mem _ hx)
    exact ⟨b :: bs, .cons hb hbs⟩

theorem checkFlight_ok {w : Spec.Port.World} {f : ResolvedFlight} {m : Spec.MasterData.FlightMaster}
    (h : checkFlight w f = .ok m) : w.existsFlight f.key = true ∧ f.master = some m := by
  unfold checkFlight at h
  split at h
  · cases h
  · rename_i m' hm
    split at h
    · cases h; exact ⟨by assumption, hm⟩
    · cases h

/-- 選択フライトの検証が成功すれば、各フライトは主キーで存在する。 -/
theorem validateFlightList_ok {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World}
    {fs : List ResolvedFlight} (h : validateFlightList cfg md w fs = some (.ok ())) :
    ∀ f ∈ fs, w.existsFlight f.key = true := by
  unfold validateFlightList at h
  split at h
  · rename_i o
    simp only [Option.some.injEq] at h
    cases hc : checkFlight w o with
    | error e => simp [hc, bind, Except.bind] at h
    | ok m =>
      intro f hf
      simp only [List.mem_singleton] at hf
      subst hf
      exact (checkFlight_ok hc).1
  · rename_i o h0
    cases hc : checkFlight w o with
    | error e => simp [hc] at h
    | ok om =>
      cases hc' : checkFlight w h0 with
      | error e => simp [hc, hc'] at h
      | ok hm =>
        intro f hf
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hf
        rcases hf with rfl | rfl
        · exact (checkFlight_ok hc).1
        · exact (checkFlight_ok hc').1
  · cases h

/-- 選択フライトの検証の値があれば、選択フライトは 1〜2 件。 -/
theorem validateFlightList_len {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World}
    {fs : List ResolvedFlight} {x : Except AtrsError Unit} (h : validateFlightList cfg md w fs = some x) :
    1 ≤ fs.length ∧ fs.length ≤ 2 := by
  unfold validateFlightList at h
  split at h
  · simp
  · simp
  · cases h

/-- 主キーで存在するフライトの運賃種別は、マスタにある。 -/
theorem fareTypeOf_of_exists {md : Spec.MasterData} {w : Spec.Port.World} (href : w.RefMaster md) {k : FlightKey}
    (he : w.existsFlight k = true) : ∃ FT, md.fareTypeOf k.fareTypeCd = some FT := by
  simp only [Spec.Port.World.existsFlight, List.any_eq_true, beq_iff_eq] at he
  obtain ⟨g, hg, rfl⟩ := he
  obtain ⟨-, -, ⟨t, htm, hte⟩⟩ := href g hg
  apply Option.isSome_iff_exists.mp
  unfold Spec.MasterData.fareTypeOf
  rw [List.find?_isSome]
  exact ⟨t, htm, by simp [hte]⟩

open Spec.UseCase.Reserve in
/-- 予約確認の操作の値の分解。 -/
theorem confirmOp_cases {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World} {r : Request}
    {x : Except AtrsError Nat} (h : confirmOp cfg md w r = some x) :
    ∃ v, validateFlightList cfg md w (r.selects.map (resolve md)) = some v ∧
      ((∃ e, v = .error e ∧ x = .error (asInvalidRequest e)) ∨
        (v = .ok () ∧ ∃ d vr, buildDraft { r.form with passengers := compactPassengers r.form.passengers }
            (r.selects.map (·.key)) = some d ∧ validateReservation cfg md w d = some vr ∧
          ((∃ e, vr = .error e ∧ x = .error e) ∨
            (vr = .ok () ∧ ∃ n, Spec.Fare.totalFareOfKeys cfg md (r.selects.map (·.key)) (d.passengers.map (·.age)) =
              some n ∧ x = .ok n)))) := by
  unfold confirmOp checkSelects at h
  cases hv : validateFlightList cfg md w (r.selects.map (resolve md)) with
  | none => simp [hv] at h
  | some v =>
    refine ⟨v, rfl, ?_⟩
    simp only [hv, Option.map_some, Option.bind_eq_bind, Option.bind_some] at h
    cases v with
    | error e =>
      left
      simp only [Except.mapError, Option.pure_def, Option.some.injEq] at h
      exact ⟨e, rfl, h.symm⟩
    | ok u =>
      cases u
      right
      refine ⟨rfl, ?_⟩
      simp only [Except.mapError, reserveConfirm, Option.bind_eq_bind] at h
      cases hd : buildDraft { r.form with passengers := compactPassengers r.form.passengers } (r.selects.map (·.key)) with
      | none => simp [hd] at h
      | some d =>
        cases hvr : validateReservation cfg md w d with
        | none => simp [hd, hvr] at h
        | some vr =>
          refine ⟨d, vr, rfl, hvr, ?_⟩
          simp only [hd, hvr, Option.bind_some] at h
          cases vr with
          | error e =>
            left
            simp only [Option.pure_def, Option.some.injEq] at h
            exact ⟨e, rfl, h.symm⟩
          | ok u =>
            cases u
            right
            refine ⟨rfl, ?_⟩
            cases ht : Spec.Fare.totalFareOfKeys cfg md (r.selects.map (·.key)) (d.passengers.map (·.age)) with
            | none => simp [ht] at h
            | some n =>
              simp only [ht, Option.bind_some, Option.pure_def, Option.some.injEq] at h
              exact ⟨n, rfl, h.symm⟩

end Abstraction.Reserve.SpecFacts
