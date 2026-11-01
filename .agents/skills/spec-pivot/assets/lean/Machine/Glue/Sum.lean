import Machine.Glue
import Machine.Sum

/-!
# Machine.Glue.Sum

貼り合わせの並置 `Glue.sum`（`Machine.Sum` の表）。
-/

namespace Machine


variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Glue

/-- 貼り合わせの並置。和の左右が食い違う入力・出力は対応しない。 -/
def sum {σ₁ σ₂ τ₁ τ₂ ιa₁ ιa₂ ιc₁ ιc₂ οa₁ οa₂ οc₁ οc₂ : Type} (g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁)
    (g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂) : Glue (σ₁ × σ₂) (τ₁ × τ₂) (ιa₁ ⊕ ιa₂) (ιc₁ ⊕ ιc₂) (οa₁ ⊕ οa₂) (οc₁ ⊕ οc₂) where
  J s t := g₁.J s.1 t.1 ∧ g₂.J s.2 t.2
  αi c a := match c, a with
    | .inl c, .inl a => g₁.αi c a
    | .inr c, .inr a => g₂.αi c a
    | _, _ => False
  αo c a := match c, a with
    | .inl c, .inl a => g₁.αo c a
    | .inr c, .inr a => g₂.αo c a
    | _, _ => False

end Glue

end Machine
