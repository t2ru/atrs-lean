import Machine.Adequate
import Machine.Refines.Sum

/-!
# Machine.Adequate.Sum

並置は義務の束を保つ（`Adequate.sum`）。PRE と定義域を各点で同値なものに替えても束は保たれる（`Adequate.congrPre`。`Machine.Sum` の表）。
-/

namespace Machine

open Machine.Adequacy
open Machine.Sum

variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Adequate

variable {ιa₁ ιa₂ οa₁ οa₂ : Type} {A₁ : Machine σ₁ ιa₁ οa₁} {A₂ : Machine σ₂ ιa₂ οa₂}
  {C₁ : Concrete τ₁ ιc₁ οc₁ ε} {C₂ : Concrete τ₂ ιc₂ οc₂ ε}
  {g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂}
  {s₁ : σ₁} {s₂ : σ₂} {E₁ : ιa₁ → Prop} {E₂ : ιa₂ → Prop}

/-- 並置は義務の束を保つ。 -/
theorem sum (h₁ : Adequate A₁ C₁ g₁ s₁ E₁) (h₂ : Adequate A₂ C₂ g₂ s₂ E₂) :
    Adequate (A₁.sum A₂) (C₁.sum C₂) (g₁.sum g₂) (s₁, s₂) (sumPred E₁ E₂) where
  refines := h₁.refines.sum h₂.refines
  sound := h₁.sound.sum h₂.sound
  initIs := h₁.initIs.sum h₂.initIs
  initSurj s hs := by
    obtain ⟨t₁, ht₁, hJ₁⟩ := h₁.initSurj s.1 hs.1
    obtain ⟨t₂, ht₂, hJ₂⟩ := h₂.initSurj s.2 hs.2
    exact ⟨(t₁, t₂), ⟨ht₁, ht₂⟩, hJ₁, hJ₂⟩
  total := h₁.total.sum h₂.total
  envWitness := by
    obtain ⟨c, a, hd, ha, he⟩ := h₁.envWitness
    exact ⟨.inl c, .inl a, hd, ha, he⟩
  envNeeded := by
    have hi₁ := h₁.initIs.inv h₁.sound
    have hi₂ := h₂.initIs.inv h₂.sound
    rcases h₁.envNeeded with e₁ | n₁
    · rcases h₂.envNeeded with e₂ | n₂
      · left
        funext i
        cases i <;> simp [sumPred, e₁, e₂, always]
      · right
        intro h
        exact n₂ fun s i hi _ => h (s₁, s) (.inr i) ⟨hi₁, hi⟩ trivial
    · right
      intro h
      exact n₁ fun s i hi _ => h (s, s₂) (.inl i) ⟨hi, hi₂⟩ trivial

/-- PRE と具体側の定義域を、各点で同値なものに替えても、義務の束は保たれる。INV・初期状態・歩みは同じものとする。
並置した機械の制限（`(A₁.sum A₂).restrict (sumPred P₁ P₂)`）と、制限した機械の並置を結ぶのに使う。 -/
theorem congrPre {σ τ ιa ιc οa οc : Type} {A A' : Machine σ ιa οa} {C C' : Concrete τ ιc οc ε}
    {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : ιa → Prop} (h : Adequate A C g s₀ Env)
    (hInv : A'.Inv = A.Inv) (hInit : A'.Init = A.Init) (hstep : A'.step = A.step)
    (hPre : ∀ s i, A'.Pre s i ↔ A.Pre s i) (hCInit : C'.Init = C.Init) (hCstep : C'.step = C.step)
    (hDom : ∀ i, C'.Dom i ↔ C.Dom i) : Adequate A' C' g s₀ Env where
  refines :=
    { init := fun t ht => by
        obtain ⟨s, hs, hJ⟩ := h.refines.init t (hCInit ▸ ht)
        exact ⟨s, hInit ▸ hs, hJ⟩
      input_total := fun ic hd => h.refines.input_total ic ((hDom ic).1 hd)
      applicable := fun s t ic ia hi hJ ha hp hd => by
        rw [hCstep]
        exact h.refines.applicable s t ic ia (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd)
      correct := fun s t ic ia t' oc hi hJ ha hp hd hs => by
        rw [hstep]
        exact h.refines.correct s t ic ia t' oc (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd) (hCstep ▸ hs) }
  sound :=
    { init_inv := fun s hs => hInv ▸ h.sound.init_inv s (hInit ▸ hs)
      step_inv := fun s i s' o hi hp hs =>
        hInv ▸ h.sound.step_inv s i s' o (hInv ▸ hi) ((hPre s i).1 hp) (hstep ▸ hs) }
  initIs s := hInit ▸ h.initIs s
  initSurj s hs := by
    obtain ⟨t, ht, hJ⟩ := h.initSurj s (hInit ▸ hs)
    exact ⟨t, hCInit ▸ ht, hJ⟩
  total s i hi he := (hPre s i).2 (h.total s i (hInv ▸ hi) he)
  envWitness := by
    obtain ⟨c, a, hd, ha, he⟩ := h.envWitness
    exact ⟨c, a, (hDom c).2 hd, ha, he⟩
  envNeeded := by
    rcases h.envNeeded with e | n
    · exact .inl e
    · exact .inr fun hT => n fun s i hi he => (hPre s i).1 (hT s i (hInv ▸ hi) he)

end Adequate

end Machine
