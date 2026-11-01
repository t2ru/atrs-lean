import Machine.Glue
import Machine.Preserves.Pred

/-!
# Machine.Glue.Preserves

標準の貼り合わせ `Glue.ofStd`（references/docs/spec/architecture.md#空虚化を防ぐ義務）。
-/

namespace Machine

open Machine.Preserves (never)

variable {σ τ ιa ιc οa οc ε E F : Type}

/-! ## 貼り合わせ -/

namespace Glue

/-- 標準の貼り合わせ。

- `β`・`ai`・`ao`: 標準の抽象化（部分写像。`none` は α/β の未定義）。利用側で `@[std_abs]` を付ける
- `Ic`: 具体側の不変条件
- `OJ`・`OO`: 観測型の差異の名前付きの成分（既定は `never`）。利用側で `@[deviation]` を付ける -/
def ofStd (β : τ → Option σ) (Ic : τ → Prop) (ai : ιc → Option ιa) (ao : οc → Option οa)
    (OJ : σ → τ → Prop := never) (OO : οc → οa → Prop := never) : Glue σ τ ιa ιc οa οc where
  J s t := (β t = some s ∧ Ic t) ∨ OJ s t
  αi c a := ai c = some a
  αo c a := ao c = some a ∨ OO c a


end Glue


/-- 標準の貼り合わせでは、具体側の入力の全域性は `ai` が定義域で `none` にならないことに帰着する。 -/
theorem Glue.ofStd_input_total {β : τ → Option σ} {Ic : τ → Prop} {ai : ιc → Option ιa}
    {ao : οc → Option οa} {OJ : σ → τ → Prop} {OO : οc → οa → Prop} {Dom : ιc → Prop}
    (h : ∀ ic, Dom ic → (ai ic).isSome) :
    ∀ ic, Dom ic → ∃ ia, (Glue.ofStd β Ic ai ao OJ OO).αi ic ia := by
  intro ic hd
  have hs := h ic hd
  match hai : ai ic, hs with
  | some ia, _ => exact ⟨ia, hai⟩
  | none, hs => simp at hs


end Machine
