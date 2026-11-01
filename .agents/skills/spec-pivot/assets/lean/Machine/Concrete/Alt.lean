import Machine.Concrete
import Machine.Sum

/-!
# Machine.Concrete.Alt

同じ状態の上の具体機械の並置 `Concrete.alt`（`Machine.Alt` の表）。
-/

namespace Machine
open Machine.Sum

variable {τ ιc₁ ιc₂ οc₁ οc₂ ε : Type}

namespace Concrete

/-- 同じ状態の上の具体機械の並置。正常終了でない結果（`ε`）は、動かした側の結果をそのまま返す。 -/
def alt (C₁ : Concrete τ ιc₁ οc₁ ε) (C₂ : Concrete τ ιc₂ οc₂ ε) : Concrete τ (ιc₁ ⊕ ιc₂) (οc₁ ⊕ οc₂) ε where
  Init t := C₁.Init t ∧ C₂.Init t
  Dom := sumPred C₁.Dom C₂.Dom
  step t i r := match i, r with
    | .inl j, .ok (t', .inl o) => C₁.step t j (.ok (t', o))
    | .inr j, .ok (t', .inr o) => C₂.step t j (.ok (t', o))
    | .inl j, .error e => C₁.step t j (.error e)
    | .inr j, .error e => C₂.step t j (.error e)
    | _, _ => False

end Concrete

end Machine
