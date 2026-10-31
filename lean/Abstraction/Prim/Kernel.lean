import Machine
import Trace

/-!
# Abstraction.Prim.Kernel

標準の抽象化（`@[std_abs]` の葉）の核の定理（`KernelIs`。ABS-048）に使う、汎用の核。

- `undefOrEq f`: 部分写像 `f` の核が「どちらも定義されないか、等しい」であること（定義域の上で単射）。
  葉の核の定理では、この核をその葉自身に適用して書く（`KernelIs f (undefOrEq f)`。obligation-check の G7 が受ける）。
-/

namespace Abstraction.Prim

open Machine

/-- 部分写像 `f` の汎用の核: どちらも定義されないか、等しい。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def undefOrEq {α β : Type} (f : α → Option β) (x y : α) : Prop := (f x = none ∧ f y = none) ∨ x = y

/-- 定義域の上で単射な部分写像の核は `undefOrEq`。 -/
theorem kernelIs_undefOrEq {α β : Type} {f : α → Option β}
    (h : ∀ x y b, f x = some b → f y = some b → x = y) : KernelIs f (undefOrEq f) := by
  intro x y
  constructor
  · intro e
    cases hx : f x with
    | none => exact Or.inl ⟨hx, by rw [← e, hx]⟩
    | some b => exact Or.inr (h x y b hx (by rw [← e, hx]))
  · rintro (⟨hx, hy⟩ | rfl)
    · rw [hx, hy]
    · rfl

end Abstraction.Prim
