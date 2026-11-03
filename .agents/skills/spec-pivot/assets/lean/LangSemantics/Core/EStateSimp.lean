/-!
# LangSemantics.Core.EStateSimp

状態と例外を持つ計算（`EStateM`）を、状態を与えた形（`m s`）で簡約するタクティク `estate_simp`。命令型の計算の
計算の形（経路ごとの分岐と結果）を求めるのに使う（`references/docs/lang/lean/rules.md#命令型の計算の検証`）。

`estate_simp [定義, …] at …` は、与えた定義を展開し、`EStateM` の束縛・`pure`・`throw`・`get`・`set`・`modifyGet`・
`tryCatch` の定義を展開して、状態の引数を `if` の枝に押し込む `simp only` である（決定可能な命題は評価する）。名前は定義の場所で解決するので、利用側で開いた名前空間（例:
同名の `bind`）に左右されない。
-/

namespace LangSemantics.Core.EStateSimp

theorem ite_apply {α β : Type} (c : Prop) [Decidable c] (f g : α → β) (a : α) :
    (if c then f else g) a = if c then f a else g a := by
  split <;> rfl

theorem estate_ite_apply {ε σ α : Type} (c : Prop) [Decidable c] (x y : EStateM ε σ α) (s : σ) :
    (if c then x else y) s = if c then x s else y s := by
  split <;> rfl

/-- `Except` の結果で分岐する計算を、状態に適用したもの。 -/
theorem estate_match_except_apply {ε σ α β : Type} (r : Except ε β) (f : β → EStateM ε σ α) (g : ε → EStateM ε σ α)
    (s : σ) :
    (match r with | .ok a => f a | .error e => g e) s = match r with | .ok a => f a s | .error e => g e s := by
  cases r <;> rfl

theorem dite_apply {α β : Type} (c : Prop) [Decidable c] (f : c → α → β) (g : ¬ c → α → β) (a : α) :
    (if h : c then f h else g h) a = if h : c then f h a else g h a := by
  split <;> rfl

open Lean Parser Tactic in
/-- `EStateM` の計算を、状態を与えた形で簡約する。 -/
syntax (name := estateSimp) "estate_simp" (" [" withoutPosition((simpErase <|> simpLemma),*,?) "]")? (location)? :
  tactic

macro_rules
  | `(tactic| estate_simp $[[$args,*]]? $[$loc]?) => do
    let args := args.map (·.getElems) |>.getD #[]
    let dummy ← `(Lean.Parser.Tactic.simpLemma| id_eq)
    let args := if args.isEmpty then #[⟨dummy.raw⟩] else args
    `(tactic| simp (config := { decide := true }) only [$args,*, LangSemantics.Core.EStateSimp.ite_apply,
        LangSemantics.Core.EStateSimp.estate_ite_apply, LangSemantics.Core.EStateSimp.estate_match_except_apply,
        LangSemantics.Core.EStateSimp.dite_apply, Except.pure, Bind.bind, EStateM.bind, Pure.pure, EStateM.pure, MonadExcept.throw, throwThe,
        MonadExceptOf.throw, EStateM.throw, MonadState.get, getThe, MonadStateOf.get, EStateM.get, MonadState.set,
        MonadStateOf.set, EStateM.set, modify, modifyGet, MonadStateOf.modifyGet, EStateM.modifyGet, MonadExcept.tryCatch,
        tryCatchThe, MonadExceptOf.tryCatch, EStateM.tryCatch, EStateM.run, Except.map, Option.isNone_some, Option.isNone_none, Option.isSome_some,
        Option.isSome_none, Bool.not_true, Bool.not_false, Bool.false_eq_true, Bool.true_eq_false, ite_true, ite_false,
        dite_true, dite_false, List.length_cons, List.length_nil, Nat.zero_add, Nat.reduceAdd, decide_true,
        decide_false] $[$loc]?)

end LangSemantics.Core.EStateSimp
