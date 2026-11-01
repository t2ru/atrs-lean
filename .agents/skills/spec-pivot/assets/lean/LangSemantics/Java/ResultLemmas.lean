import LangSemantics.Java.Exception

/-!
# LangSemantics.Java.ResultLemmas

例外を投げうる計算 `JResult` の補題（`Except.ok` の `bind`・`mapM`・`for`）。
-/

namespace LangSemantics.Java.ResultLemmas
open LangSemantics.Java.Exception

/-- `Except.ok` の `bind` は関数の適用。 -/
theorem ok_bind {β γ : Type} (x : β) (f : β → JResult γ) : (Except.ok x >>= f) = f x := rfl

/-- 各要素で `f` が例外を投げなければ、`mapM` は例外を投げず、値は各要素の値の列。 -/
theorem mapM_ok {β γ : Type} (l : List β) (f : β → JResult γ) (g : β → γ) (h : ∀ x ∈ l, f x = .ok (g x)) :
    l.mapM f = .ok (l.map g) := by
  induction l with
  | nil => rfl
  | cons x l ih =>
    rw [List.mapM_cons, h x (List.mem_cons_self ..), ih fun y hy => h y (List.mem_cons_of_mem _ hy)]
    rfl

/-- 本体が各要素で例外を投げず `yield` するなら、`for` は例外を投げず、値は `foldl`。 -/
theorem forIn_ok {β γ : Type} (l : List β) (f : β → γ → JResult (ForInStep γ)) (g : β → γ → γ)
    (h : ∀ x ∈ l, ∀ b, f x b = .ok (.yield (g x b))) (init : γ) :
    forIn l init f = .ok (l.foldl (fun b x => g x b) init) := by
  induction l generalizing init with
  | nil => rfl
  | cons x l ih =>
    rw [List.forIn_cons, h x (List.mem_cons_self ..)]
    exact ih (fun y hy => h y (List.mem_cons_of_mem _ hy)) _

/-- `for` の模倣: 元の列 `l` を `E` で写した列の `for` と、`C` で写した列の `foldl` が、各要素で関係 `R` を保つなら、
`for` は例外を投げず、結果は `foldl` の結果と `R` で結ばれる。 -/
theorem forIn_map_sim {ρ β γ σ α : Type} (l : List ρ) (E : ρ → β) (C : ρ → α) (f : β → γ → JResult (ForInStep γ))
    (R : γ → σ → Prop) (step : σ → α → σ) (init : γ) (s0 : σ) (h0 : R init s0)
    (h : ∀ r ∈ l, ∀ b s, R b s → ∃ b', f (E r) b = .ok (.yield b') ∧ R b' (step s (C r))) :
    ∃ b, forIn (l.map E) init f = .ok b ∧ R b ((l.map C).foldl step s0) := by
  induction l generalizing init s0 with
  | nil => exact ⟨init, rfl, h0⟩
  | cons r l ih =>
    obtain ⟨b', hb', hR⟩ := h r (List.mem_cons_self ..) init s0 h0
    rw [List.map_cons, List.forIn_cons, hb']
    exact ih b' (step s0 (C r)) hR fun r' hr' => h r' (List.mem_cons_of_mem _ hr')

end LangSemantics.Java.ResultLemmas
