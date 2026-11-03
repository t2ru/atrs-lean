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

/-- 要素ごとの関係の、左辺の写像を関係に移す。 -/
theorem forall₂_of_map {α β γ : Type} {R : β → γ → Prop} {f : α → β} :
    ∀ {as : List α} {cs : List γ}, LangSemantics.Core.List.Forall₂ R (as.map f) cs →
      LangSemantics.Core.List.Forall₂ (fun a c => R (f a) c) as cs
  | [], [], .nil => .nil
  | _ :: _, _ :: _, .cons h hs => .cons h (forall₂_of_map hs)

/-- 要素ごとの関係の、右辺の要素には、関係する左辺の要素がある。 -/
theorem forall₂_right_mem {α β : Type} {R : α → β → Prop} :
    ∀ {as : List α} {bs : List β}, LangSemantics.Core.List.Forall₂ R as bs → ∀ b ∈ bs, ∃ a ∈ as, R a b
  | [], [], .nil, _, hb => absurd hb (List.not_mem_nil)
  | a :: _, _ :: _, .cons h hs, b, hb => by
    rcases List.mem_cons.mp hb with rfl | hb
    · exact ⟨a, List.mem_cons_self .., h⟩
    · obtain ⟨a', ha', h'⟩ := forall₂_right_mem hs b hb
      exact ⟨a', List.mem_cons_of_mem _ ha', h'⟩

/-- 要素ごとの関係の、左辺の要素には、関係する右辺の要素がある。 -/
theorem forall₂_left_mem {α β : Type} {R : α → β → Prop} :
    ∀ {as : List α} {bs : List β}, LangSemantics.Core.List.Forall₂ R as bs → ∀ a ∈ as, ∃ b ∈ bs, R a b
  | [], [], .nil, _, ha => absurd ha (List.not_mem_nil)
  | _ :: _, b :: _, .cons h hs, a, ha => by
    rcases List.mem_cons.mp ha with rfl | ha
    · exact ⟨b, List.mem_cons_self .., h⟩
    · obtain ⟨b', hb', h'⟩ := forall₂_left_mem hs a ha
      exact ⟨b', List.mem_cons_of_mem _ hb', h'⟩

theorem forall₂_len {α β : Type} {R : α → β → Prop} :
    ∀ {as : List α} {bs : List β}, LangSemantics.Core.List.Forall₂ R as bs → as.length = bs.length
  | [], [], .nil => rfl
  | _ :: _, _ :: _, .cons _ hs => by simp [forall₂_len hs]

theorem checkFlight_ok {w : Spec.Port.World} {f : Option ResolvedFlight} {r : ResolvedFlight}
    (h : checkFlight w f = .ok r) : w.existsFlight r.key = true ∧ f = some r := by
  unfold checkFlight at h
  split at h
  · cases h
  · split at h
    · cases h; exact ⟨by assumption, rfl⟩
    · cases h

/-- 選択フライトの検証が成功すれば、返す便の主キーは、解決した選択フライトの主キーで、主キーで存在する。 -/
theorem validateFlightList_ok {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World}
    {fs : List (Option ResolvedFlight)} {it : Itinerary FlightKey} (h : validateFlightList cfg md w fs = some (.ok it)) :
    LangSemantics.Core.List.Forall₂ (fun f k => ∃ r, f = some r ∧ r.key = k ∧ w.existsFlight k = true) fs it.toList := by
  unfold validateFlightList at h
  split at h
  · rename_i o
    simp only [Option.some.injEq] at h
    cases hc : checkFlight w o with
    | error e => simp [hc, bind, Except.bind] at h
    | ok r =>
      cases hf : checkFareTypes [r.key] with
      | error e => simp [hc, hf, bind, Except.bind] at h
      | ok u =>
        simp only [hc, hf, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at h
        subst h
        obtain ⟨he, rfl⟩ := checkFlight_ok hc
        exact .cons ⟨r, rfl, rfl, he⟩ .nil
  · rename_i o h0
    cases hc : checkFlight w o with
    | error e => simp [hc] at h
    | ok ro =>
      cases hc' : checkFlight w h0 with
      | error e => simp [hc, hc'] at h
      | ok rh =>
        cases hi : checkInterval cfg ro.key ro.master rh.key rh.master with
        | error e => simp [hc, hc', hi] at h
        | ok u =>
          cases u
          cases hr : checkReverse md ro.master rh.master with
          | none => simp [hc, hc', hi, hr] at h
          | some rv =>
            cases rv with
            | error e => simp [hc, hc', hi, hr, Except.bind] at h
            | ok u' =>
              cases hf : checkFareTypes [ro.key, rh.key] with
              | error e => simp [hc, hc', hi, hr, hf, Except.bind, Except.map] at h
              | ok u'' =>
                simp only [hc, hc', hi, hr, hf, Except.bind, Except.map, Option.bind_eq_bind, Option.bind_some,
                  Option.pure_def, Option.some.injEq, Except.ok.injEq] at h
                subst h
                obtain ⟨he, rfl⟩ := checkFlight_ok hc
                obtain ⟨he', rfl⟩ := checkFlight_ok hc'
                exact .cons ⟨_, rfl, rfl, he⟩ (.cons ⟨_, rfl, rfl, he'⟩ .nil)
  · cases h

/-- 選択フライトの検証が成功すれば、選択フライトはどれも便マスタで解決でき、返す便の主キーは、解決した選択フライトの
主キーで、主キーで存在する。 -/
theorem selects_ok {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World} {ss : List SelectFlight}
    {it : Itinerary FlightKey} (h : validateFlightList cfg md w (ss.map (resolve md)) = some (.ok it)) :
    LangSemantics.Core.List.Forall₂ (fun s k => ∃ r, resolve md s = some r ∧ r.key = k ∧ w.existsFlight k = true)
      ss it.toList :=
  forall₂_of_map (validateFlightList_ok h)

/-- 解決した選択フライトの主キー: 出発日・搭乗クラス・運賃種別は選択フライトのもの、便名は便マスタの便名で、その値は
選択フライトの便名。 -/
theorem resolve_key {md : Spec.MasterData} {s : SelectFlight} {r : ResolvedFlight} (h : resolve md s = some r) :
    md.flightMasterOf s.flightName = some r.master ∧ r.key = ⟨s.depDate, r.master.flightName, s.boardingClassCd, s.fareTypeCd⟩ ∧
      r.master.flightName.val = s.flightName := by
  simp only [resolve, Option.map_eq_some_iff] at h
  obtain ⟨m, hm, rfl⟩ := h
  refine ⟨hm, rfl, ?_⟩
  have := List.find?_some hm
  simpa using this

/-- 選択フライトの検証の値があれば、選択フライトは 1〜2 件。 -/
theorem validateFlightList_len {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World}
    {fs : List (Option ResolvedFlight)} {x : Except AtrsError (Itinerary FlightKey)}
    (h : validateFlightList cfg md w fs = some x) : 1 ≤ fs.length ∧ fs.length ≤ 2 := by
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
        (∃ it, v = .ok it ∧ ∃ d vr, buildDraft { r.form with passengers := compactPassengers r.form.passengers }
            it.toList = some d ∧ validateReservation cfg md w d = some vr ∧
          ((∃ e, vr = .error e ∧ x = .error e) ∨
            (vr = .ok () ∧ ∃ n, Spec.Fare.totalFareOfKeys cfg md it.toList (d.passengers.map (·.age)) =
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
    | ok it =>
      right
      refine ⟨it, rfl, ?_⟩
      simp only [Except.mapError, reserveConfirm, Option.bind_eq_bind] at h
      cases hd : buildDraft { r.form with passengers := compactPassengers r.form.passengers } it.toList with
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
            cases ht : Spec.Fare.totalFareOfKeys cfg md it.toList (d.passengers.map (·.age)) with
            | none => simp [ht] at h
            | some n =>
              simp only [ht, Option.bind_some, Option.pure_def, Option.some.injEq] at h
              exact ⟨n, rfl, h.symm⟩

end Abstraction.Reserve.SpecFacts
