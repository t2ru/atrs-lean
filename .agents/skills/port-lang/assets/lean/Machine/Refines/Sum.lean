import Machine.Refines
import Machine.Machine.Sum
import Machine.Concrete.Sum
import Machine.Glue.Sum

/-!
# Machine.Refines.Sum

並置はリファインメントを保つ（`Refines.sum`。`Machine.Sum` の表）。
-/

namespace Machine


variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Refines

variable {ιa₁ ιa₂ οa₁ οa₂ : Type} {A₁ : Machine σ₁ ιa₁ οa₁} {A₂ : Machine σ₂ ιa₂ οa₂}
  {C₁ : Concrete τ₁ ιc₁ οc₁ ε} {C₂ : Concrete τ₂ ιc₂ οc₂ ε}
  {g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂}

/-- 並置はリファインメントを保つ。 -/
theorem sum (h₁ : Refines A₁ C₁ g₁) (h₂ : Refines A₂ C₂ g₂) : Refines (A₁.sum A₂) (C₁.sum C₂) (g₁.sum g₂) where
  init t ht := by
    obtain ⟨s₁, hs₁, hJ₁⟩ := h₁.init t.1 ht.1
    obtain ⟨s₂, hs₂, hJ₂⟩ := h₂.init t.2 ht.2
    exact ⟨(s₁, s₂), ⟨hs₁, hs₂⟩, hJ₁, hJ₂⟩
  input_total ic hd := by
    cases ic with
    | inl c => obtain ⟨a, ha⟩ := h₁.input_total c hd; exact ⟨.inl a, ha⟩
    | inr c => obtain ⟨a, ha⟩ := h₂.input_total c hd; exact ⟨.inr a, ha⟩
  applicable s t ic ia hi hJ ha hp hd := by
    match ic, ia, ha with
    | .inl c, .inl a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₁.applicable s.1 t.1 c a hi.1 hJ.1 ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok ((t', t.2), .inl o), hr, rfl⟩
      | .error e, hr => exact ⟨.error e, hr⟩
    | .inr c, .inr a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₂.applicable s.2 t.2 c a hi.2 hJ.2 ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok ((t.1, t'), .inr o), hr, rfl⟩
      | .error e, hr => exact ⟨.error e, hr⟩
  correct s t ic ia t' oc hi hJ ha hp hd hs := by
    match ic, ia, oc, ha, hs with
    | .inl c, .inl a, .inl o, ha, ⟨hs, he⟩ =>
      obtain ⟨s₁', oa, hst, hJ', ho⟩ := h₁.correct s.1 t.1 c a t'.1 o hi.1 hJ.1 ha hp hd hs
      exact ⟨(s₁', s.2), .inl oa, ⟨hst, rfl⟩, ⟨hJ', he ▸ hJ.2⟩, ho⟩
    | .inr c, .inr a, .inr o, ha, ⟨hs, he⟩ =>
      obtain ⟨s₂', oa, hst, hJ', ho⟩ := h₂.correct s.2 t.2 c a t'.2 o hi.2 hJ.2 ha hp hd hs
      exact ⟨(s.1, s₂'), .inr oa, ⟨hst, rfl⟩, ⟨he ▸ hJ.1, hJ'⟩, ho⟩

end Refines

end Machine
