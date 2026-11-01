import Machine.Refines
import Machine.Machine.Sum
import Machine.Concrete.Sum
import Machine.Glue.Sum

/-!
# Machine.Refines.Sum

並置はリファインメントを保つ（`Refines.sum`）。PRE と定義域を各点で同値なものに替えても保たれる（`Refines.congrPre`。`Machine.Sum` の表）。
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

/-- PRE と具体側の定義域を、各点で同値なものに替えても、リファインメントは保たれる。INV・初期状態・歩みは同じものとする。
並置した機械の制限（`(A₁.sum A₂).restrict (sumPred P₁ P₂)`）と、制限した機械の並置を結ぶのに使う。 -/
theorem congrPre {σ τ ιa ιc οa οc : Type} {A A' : Machine σ ιa οa} {C C' : Concrete τ ιc οc ε}
    {g : Glue σ τ ιa ιc οa οc} (h : Refines A C g)
    (hInv : A'.Inv = A.Inv) (hInit : A'.Init = A.Init) (hstep : A'.step = A.step)
    (hPre : ∀ s i, A'.Pre s i ↔ A.Pre s i) (hCInit : C'.Init = C.Init) (hCstep : C'.step = C.step)
    (hDom : ∀ i, C'.Dom i ↔ C.Dom i) : Refines A' C' g where
  init t ht := by
    obtain ⟨s, hs, hJ⟩ := h.init t (hCInit ▸ ht)
    exact ⟨s, hInit ▸ hs, hJ⟩
  input_total ic hd := h.input_total ic ((hDom ic).1 hd)
  applicable s t ic ia hi hJ ha hp hd := by
    rw [hCstep]
    exact h.applicable s t ic ia (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd)
  correct s t ic ia t' oc hi hJ ha hp hd hs := by
    rw [hstep]
    exact h.correct s t ic ia t' oc (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd) (hCstep ▸ hs)

end Refines

end Machine
