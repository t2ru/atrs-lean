import Machine.Machine.Preserves
import Machine.Sum

/-!
# Machine.Machine.Alt

同じ状態の上の抽象機械の並置 `Machine.alt` と、`Sound`・`InitIs`・`TotalUnder` の並置（`Machine.Alt` の表）。
-/

namespace Machine
open Machine.Sum

variable {σ ι₁ ι₂ ο₁ ο₂ : Type}

namespace Machine

/-- 同じ状態の上の並置: 入力 `inl` は左の機械を、`inr` は右の機械を 1 歩動かす。INV と初期状態は両方の積。 -/
def alt (A₁ : Machine σ ι₁ ο₁) (A₂ : Machine σ ι₂ ο₂) : Machine σ (ι₁ ⊕ ι₂) (ο₁ ⊕ ο₂) where
  Inv s := A₁.Inv s ∧ A₂.Inv s
  Init s := A₁.Init s ∧ A₂.Init s
  Pre s i := match i with
    | .inl j => A₁.Pre s j
    | .inr j => A₂.Pre s j
  step s i s' o := match i, o with
    | .inl j, .inl o => A₁.step s j s' o
    | .inr j, .inr o => A₂.step s j s' o
    | _, _ => False
  run s i := match i with
    | .inl j => ((A₁.run s j).1, .inl (A₁.run s j).2)
    | .inr j => ((A₂.run s j).1, .inr (A₂.run s j).2)
  run_step s i h := by
    cases i with
    | inl j => exact A₁.run_step s j h
    | inr j => exact A₂.run_step s j h

/-- 並置の `Sound`: 両方の INV が等しければ、それぞれの `Sound` から従う。 -/
theorem Sound.alt {A₁ : Machine σ ι₁ ο₁} {A₂ : Machine σ ι₂ ο₂} (h₁ : A₁.Sound) (h₂ : A₂.Sound)
    (hInv : A₁.Inv = A₂.Inv) : (A₁.alt A₂).Sound where
  init_inv s h := ⟨h₁.init_inv s h.1, h₂.init_inv s h.2⟩
  step_inv s i s' o hi hp hs := by
    match i, o, hs with
    | .inl j, .inl o, hs =>
      have h := h₁.step_inv s j s' o hi.1 hp hs
      exact ⟨h, hInv ▸ h⟩
    | .inr j, .inr o, hs =>
      have h := h₂.step_inv s j s' o hi.2 hp hs
      exact ⟨hInv ▸ h, h⟩

theorem InitIs.alt {A₁ : Machine σ ι₁ ο₁} {A₂ : Machine σ ι₂ ο₂} {s₀ : σ} (h₁ : A₁.InitIs s₀)
    (h₂ : A₂.InitIs s₀) : (A₁.alt A₂).InitIs s₀ := fun s => by
  show A₁.Init s ∧ A₂.Init s ↔ s = s₀
  rw [h₁ s, h₂ s, and_self]

theorem TotalUnder.alt {A₁ : Machine σ ι₁ ο₁} {A₂ : Machine σ ι₂ ο₂} {E₁ : ι₁ → Prop} {E₂ : ι₂ → Prop}
    (h₁ : A₁.TotalUnder E₁) (h₂ : A₂.TotalUnder E₂) : (A₁.alt A₂).TotalUnder (sumPred E₁ E₂) := fun s i hi he => by
  cases i with
  | inl j => exact h₁ s j hi.1 he
  | inr j => exact h₂ s j hi.2 he

end Machine

end Machine
