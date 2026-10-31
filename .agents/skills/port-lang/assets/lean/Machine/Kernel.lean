import Machine.Adequacy

/-!
# Machine.Kernel

標準の抽象化（`@[std_abs]` の葉）の核の定理（`KernelIs`）に使う、汎用の核
（スキルの `references/docs/architecture.md#空虚化を防ぐ義務` の「標準の抽象化の核」）。

- `undefOrEq f`: 部分写像 `f` の核が「どちらも定義されないか、等しい」であること（定義域の上で単射）。
  葉の核の定理は、この核をその葉自身に適用して書く（`KernelIs f (Machine.undefOrEq f)`）。
  obligation-check の G7 は、この形を `@[kernel]` の定数と同じく受け付ける。
- `kernelIs_undefOrEq`: 定義域の上で単射な部分写像の核は `undefOrEq`。
- `inj_of_kernel`: 核の定理から、定義域の上の単射性を取り出す。
-/

namespace Machine

/-- 部分写像 `f` の汎用の核: どちらも定義されないか、等しい。 -/
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

/-- 核から、定義域の上の単射性を取り出す。 -/
theorem inj_of_kernel {α β : Type} {f : α → Option β} (hk : KernelIs f (undefOrEq f)) {x y : α} {b : β}
    (hx : f x = some b) (hy : f y = some b) : x = y := by
  rcases (hk x y).mp (hx.trans hy.symm) with ⟨h, _⟩ | h
  · rw [hx] at h; cases h
  · exact h

end Machine
