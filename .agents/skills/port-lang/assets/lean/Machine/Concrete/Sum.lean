import Machine.Concrete
import Machine.Sum

/-!
# Machine.Concrete.Sum

具体機械の並置 `Concrete.sum`（`Machine.Sum` の表）。
-/

namespace Machine

open Machine.Sum

variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Concrete

/-- 具体機械の並置。正常終了でない結果（`ε`）は、動かした側の結果をそのまま返す。 -/
def sum (C₁ : Concrete τ₁ ιc₁ οc₁ ε) (C₂ : Concrete τ₂ ιc₂ οc₂ ε) : Concrete (τ₁ × τ₂) (ιc₁ ⊕ ιc₂) (οc₁ ⊕ οc₂) ε where
  Init t := C₁.Init t.1 ∧ C₂.Init t.2
  Dom := sumPred C₁.Dom C₂.Dom
  step t i r := match i, r with
    | .inl j, .ok (t', .inl o) => C₁.step t.1 j (.ok (t'.1, o)) ∧ t'.2 = t.2
    | .inr j, .ok (t', .inr o) => C₂.step t.2 j (.ok (t'.2, o)) ∧ t'.1 = t.1
    | .inl j, .error e => C₁.step t.1 j (.error e)
    | .inr j, .error e => C₂.step t.2 j (.error e)
    | _, _ => False

end Concrete

end Machine
