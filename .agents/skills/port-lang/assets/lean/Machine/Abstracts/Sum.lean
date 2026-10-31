import Machine.Abstracts
import Machine.Preserves.Sum
import Machine.Refines.Sum

/-!
# Machine.Abstracts.Sum

並置は `Abstracts`（A abstracts B = A preserves B ∧ B refines A）を保つ（`Abstracts.sum`）。PRE と定義域を各点で同値なものに
替えても保たれる（`Abstracts.congrPre`。`Machine.Sum` の表）。成分ごとに `Preserves.sum`・`Refines.sum` と
`Preserves.congrPre`・`Refines.congrPre` を使う。
-/

namespace Machine

open Machine.Sum

variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

namespace Abstracts

variable {ιa₁ ιa₂ οa₁ οa₂ : Type} {A₁ : Machine σ₁ ιa₁ οa₁} {A₂ : Machine σ₂ ιa₂ οa₂}
  {C₁ : Concrete τ₁ ιc₁ οc₁ ε} {C₂ : Concrete τ₂ ιc₂ οc₂ ε}
  {g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂}
  {s₁ : σ₁} {s₂ : σ₂} {E₁ : ιa₁ → Prop} {E₂ : ιa₂ → Prop}

/-- 並置は `Abstracts` を保つ。 -/
theorem sum (h₁ : Abstracts A₁ C₁ g₁ s₁ E₁) (h₂ : Abstracts A₂ C₂ g₂ s₂ E₂) :
    Abstracts (A₁.sum A₂) (C₁.sum C₂) (g₁.sum g₂) (s₁, s₂) (sumPred E₁ E₂) :=
  ⟨h₁.preserves.sum h₂.preserves, h₁.refines.sum h₂.refines⟩

/-- PRE と具体側の定義域を、各点で同値なものに替えても、`Abstracts` は保たれる。INV・初期状態・歩みは同じものとする。 -/
theorem congrPre {σ τ ιa ιc οa οc : Type} {A A' : Machine σ ιa οa} {C C' : Concrete τ ιc οc ε}
    {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : ιa → Prop} (h : Abstracts A C g s₀ Env)
    (hInv : A'.Inv = A.Inv) (hInit : A'.Init = A.Init) (hstep : A'.step = A.step)
    (hPre : ∀ s i, A'.Pre s i ↔ A.Pre s i) (hCInit : C'.Init = C.Init) (hCstep : C'.step = C.step)
    (hDom : ∀ i, C'.Dom i ↔ C.Dom i) : Abstracts A' C' g s₀ Env :=
  ⟨h.preserves.congrPre hInv hInit hstep hPre hCInit hDom,
    h.refines.congrPre hInv hInit hstep hPre hCInit hCstep hDom⟩

end Abstracts

end Machine
