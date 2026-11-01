import Machine.Machine.Preserves
import Machine.Sum

/-!
# Machine.Machine.Sum

抽象機械の並置 `Machine.sum` と、`Sound`・`InitIs`・`TotalUnder` の並置（`Machine.Sum` の表）。
-/

namespace Machine

open Machine.Sum

variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Machine

/-- 抽象機械の並置: 入力 `inl` は左の機械を、`inr` は右の機械を 1 歩動かす。 -/
def sum (A₁ : Machine σ₁ ι₁ ο₁) (A₂ : Machine σ₂ ι₂ ο₂) : Machine (σ₁ × σ₂) (ι₁ ⊕ ι₂) (ο₁ ⊕ ο₂) where
  Inv s := A₁.Inv s.1 ∧ A₂.Inv s.2
  Init s := A₁.Init s.1 ∧ A₂.Init s.2
  Pre s i := match i with
    | .inl j => A₁.Pre s.1 j
    | .inr j => A₂.Pre s.2 j
  step s i s' o := match i, o with
    | .inl j, .inl o => A₁.step s.1 j s'.1 o ∧ s'.2 = s.2
    | .inr j, .inr o => A₂.step s.2 j s'.2 o ∧ s'.1 = s.1
    | _, _ => False
  run s i := match i with
    | .inl j => (((A₁.run s.1 j).1, s.2), .inl (A₁.run s.1 j).2)
    | .inr j => ((s.1, (A₂.run s.2 j).1), .inr (A₂.run s.2 j).2)
  run_step s i h := by
    cases i with
    | inl j => exact ⟨A₁.run_step s.1 j h, rfl⟩
    | inr j => exact ⟨A₂.run_step s.2 j h, rfl⟩

theorem Sound.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} (h₁ : A₁.Sound) (h₂ : A₂.Sound) :
    (A₁.sum A₂).Sound where
  init_inv s h := ⟨h₁.init_inv _ h.1, h₂.init_inv _ h.2⟩
  step_inv s i s' o hi hp hs := by
    match i, o, hs with
    | .inl j, .inl o, ⟨hs, he⟩ => exact ⟨h₁.step_inv _ j _ o hi.1 hp hs, he ▸ hi.2⟩
    | .inr j, .inr o, ⟨hs, he⟩ => exact ⟨he ▸ hi.1, h₂.step_inv _ j _ o hi.2 hp hs⟩

theorem InitIs.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} {s₁ : σ₁} {s₂ : σ₂} (h₁ : A₁.InitIs s₁)
    (h₂ : A₂.InitIs s₂) : (A₁.sum A₂).InitIs (s₁, s₂) := fun s => by
  show A₁.Init s.1 ∧ A₂.Init s.2 ↔ s = (s₁, s₂)
  rw [h₁ s.1, h₂ s.2]
  obtain ⟨a, b⟩ := s
  simp

theorem TotalUnder.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} {E₁ : ι₁ → Prop} {E₂ : ι₂ → Prop}
    (h₁ : A₁.TotalUnder E₁) (h₂ : A₂.TotalUnder E₂) : (A₁.sum A₂).TotalUnder (sumPred E₁ E₂) := fun s i hi he => by
  cases i with
  | inl j => exact h₁ s.1 j hi.1 he
  | inr j => exact h₂ s.2 j hi.2 he

end Machine

end Machine
