import Machine.Preserves
import Machine.Machine.Alt
import Machine.Concrete.Alt
import Machine.Glue.Alt

/-!
# Machine.Preserves.Alt

同じ状態の上の並置は、全 R 課題に共通の 6 成分の束 `Preserves` を保つ（`Preserves.alt`。`Machine.Alt` の表）。
`Refines` を使わない。条件付きの成分（`ch`・`outs`・`outsC`）を持つ束は、`Preserves.core` で忘れてから並置する。
-/

namespace Machine

open Machine.Preserves (always)
open Machine.Sum

variable {σ τ ιa₁ ιa₂ ιc₁ ιc₂ οa₁ οa₂ οc₁ οc₂ ε : Type}

namespace Preserves

variable {A₁ : Machine σ ιa₁ οa₁} {A₂ : Machine σ ιa₂ οa₂}
  {C₁ : Concrete τ ιc₁ οc₁ ε} {C₂ : Concrete τ ιc₂ οc₂ ε}
  {g₁ : Glue σ τ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ τ ιa₂ ιc₂ οa₂ οc₂}
  {s₀ : σ} {E₁ : σ → ιa₁ → Prop} {E₂ : σ → ιa₂ → Prop}

/-- 同じ状態の上の並置は束 `Preserves` を保つ。抽象側の INV が等しく、左の具体側の初期状態が右の初期状態でもあること
を仮定する（初期状態は束の `initIs` で同じ 1 点 `s₀`）。 -/
theorem alt (h₁ : Preserves A₁ C₁ g₁ s₀ E₁) (h₂ : Preserves A₂ C₂ g₂ s₀ E₂) (hInv : A₁.Inv = A₂.Inv)
    (hCInit : ∀ t, C₁.Init t → C₂.Init t) :
    Preserves (A₁.alt A₂) (C₁.alt C₂) (g₁.alt g₂) s₀ (altEnv E₁ E₂) where
  sound := h₁.sound.alt h₂.sound hInv
  initIs := h₁.initIs.alt h₂.initIs
  initSurj s hs := by
    obtain ⟨t, ht, hJ⟩ := h₁.initSurj s hs.1
    exact ⟨t, ⟨ht, hCInit t ht⟩, hJ⟩
  total := h₁.total.alt h₂.total
  envWitness := by
    obtain ⟨c, a, hd, ha, he⟩ := h₁.envWitness
    exact ⟨.inl c, .inl a, hd, ha, he⟩
  envNeeded := by
    rcases h₁.envNeeded with e₁ | n₁
    · rcases h₂.envNeeded with e₂ | n₂
      · left
        funext s i
        cases i <;> simp [altEnv, e₁, e₂, always]
      · right
        intro h
        exact n₂ fun s i hi _ => h s (.inr i) ⟨hInv ▸ hi, hi⟩ trivial
    · right
      intro h
      exact n₁ fun s i hi _ => h s (.inl i) ⟨hi, hInv ▸ hi⟩ trivial

end Preserves

end Machine
