import Machine.Glue

/-!
# Machine.Glue.Alt

同じ状態の上の貼り合わせの並置 `Glue.alt`（`Machine.Alt` の表）。
-/

namespace Machine

namespace Glue

/-- 同じ状態の上の貼り合わせの並置。`J` は左のものを使う（右の `J` と等しいことは、`Refines.alt` などの仮定に置く）。
和の左右が食い違う入力・出力は対応しない。 -/
def alt {σ τ ιa₁ ιa₂ ιc₁ ιc₂ οa₁ οa₂ οc₁ οc₂ : Type} (g₁ : Glue σ τ ιa₁ ιc₁ οa₁ οc₁)
    (g₂ : Glue σ τ ιa₂ ιc₂ οa₂ οc₂) : Glue σ τ (ιa₁ ⊕ ιa₂) (ιc₁ ⊕ ιc₂) (οa₁ ⊕ οa₂) (οc₁ ⊕ οc₂) where
  J := g₁.J
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
