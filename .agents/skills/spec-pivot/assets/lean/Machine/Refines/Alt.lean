import Machine.Refines
import Machine.Machine.Alt
import Machine.Concrete.Alt
import Machine.Glue.Alt

/-!
# Machine.Refines.Alt

同じ状態の上の並置はリファインメントを保つ（`Refines.alt`。`Machine.Alt` の表）。
-/

namespace Machine

variable {σ τ ιa₁ ιa₂ ιc₁ ιc₂ οa₁ οa₂ οc₁ οc₂ ε : Type}

namespace Refines

variable {A₁ : Machine σ ιa₁ οa₁} {A₂ : Machine σ ιa₂ οa₂}
  {C₁ : Concrete τ ιc₁ οc₁ ε} {C₂ : Concrete τ ιc₂ οc₂ ε}
  {g₁ : Glue σ τ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ τ ιa₂ ιc₂ οa₂ οc₂}

/-- 同じ状態の上の並置はリファインメントを保つ。2 つの貼り合わせの `J` が等しく、左の抽象側の初期状態が右の初期状態でも
あること（例: どちらも fixture の 1 点）を仮定する。 -/
theorem alt (h₁ : Refines A₁ C₁ g₁) (h₂ : Refines A₂ C₂ g₂) (hJ : g₂.J = g₁.J)
    (hInit : ∀ s, A₁.Init s → A₂.Init s) : Refines (A₁.alt A₂) (C₁.alt C₂) (g₁.alt g₂) where
  init t ht := by
    obtain ⟨s, hs, hJ'⟩ := h₁.init t ht.1
    exact ⟨s, ⟨hs, hInit s hs⟩, hJ'⟩
  input_total ic hd := by
    cases ic with
    | inl c => obtain ⟨a, ha⟩ := h₁.input_total c hd; exact ⟨.inl a, ha⟩
    | inr c => obtain ⟨a, ha⟩ := h₂.input_total c hd; exact ⟨.inr a, ha⟩
  applicable s t ic ia hi hJ' ha hp hd := by
    match ic, ia, ha with
    | .inl c, .inl a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₁.applicable s t c a hi.1 hJ' ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok (t', .inl o), hr⟩
      | .error e, hr => exact ⟨.error e, hr⟩
    | .inr c, .inr a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₂.applicable s t c a hi.2 (hJ ▸ hJ') ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok (t', .inr o), hr⟩
      | .error e, hr => exact ⟨.error e, hr⟩
  correct s t ic ia t' oc hi hJ' ha hp hd hs := by
    match ic, ia, oc, ha, hs with
    | .inl c, .inl a, .inl o, ha, hs =>
      obtain ⟨s', oa, hst, hJ'', ho⟩ := h₁.correct s t c a t' o hi.1 hJ' ha hp hd hs
      exact ⟨s', .inl oa, hst, hJ'', ho⟩
    | .inr c, .inr a, .inr o, ha, hs =>
      obtain ⟨s', oa, hst, hJ'', ho⟩ := h₂.correct s t c a t' o hi.2 (hJ ▸ hJ') ha hp hd hs
      exact ⟨s', .inr oa, hst, hJ ▸ hJ'', ho⟩

end Refines

end Machine
