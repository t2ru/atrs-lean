import LangSemantics.Core.EStateSimp
import LangSemantics.Java.Exception
import LangSemantics.Java.JList
import LangSemantics.Java.Spring
import LangSemantics.Java.ResultLemmas

/-!
# LangSemantics.Java.EStateSimp

Java の写しの命令型の計算を、状態を与えた形で簡約するタクティク `java_estate_simp`。`estate_simp` に、Java の写しの
検査・参照の簡約（`null` でない参照の `deref`、`Assert` の成功、`List.get` の 0・1 番目、`Except` の束縛）を加える。
-/

namespace LangSemantics.Java.EStateSimp
open LangSemantics.Java.Exception LangSemantics.Java.Spring

theorem deref_some {α : Type} (a : α) (what : String) : JRef.deref (some a) what = .ok a := rfl

theorem isTrue_of {b : Bool} (h : b = true) (message : String) : Assert.isTrue b message = pure () := by
  subst h; rfl

theorem except_ok_bind {ε α β : Type} (a : α) (f : α → Except ε β) : (Except.ok a >>= f) = f a := rfl

theorem except_error_bind {ε α β : Type} (e : ε) (f : α → Except ε β) : (Except.error e >>= f) = .error e := rfl

theorem except_pure {ε α : Type} (a : α) : (pure a : Except ε α) = .ok a := rfl

open Lean Parser Tactic in
/-- Java の写しの `EStateM` の計算を、状態を与えた形で簡約する。 -/
syntax (name := javaEstateSimp) "java_estate_simp" (" [" withoutPosition((simpErase <|> simpLemma),*,?) "]")?
  (location)? : tactic

macro_rules
  | `(tactic| java_estate_simp $[[$args,*]]? $[$loc]?) => do
    let args := args.map (·.getElems) |>.getD #[]
    let dummy ← `(Lean.Parser.Tactic.simpLemma| id_eq)
    let args := if args.isEmpty then #[⟨dummy.raw⟩] else args
    `(tactic| estate_simp [$args,*, LangSemantics.Java.EStateSimp.deref_some, Assert.notNullValue_some,
        Assert.notNull_some, Assert.notEmptyValue_cons, Assert.isTrue_true, LangSemantics.Java.JList.get_cons_zero,
        LangSemantics.Java.JList.get_cons_one, LangSemantics.Java.EStateSimp.except_ok_bind,
        LangSemantics.Java.EStateSimp.except_error_bind, LangSemantics.Java.EStateSimp.except_pure] $[$loc]?)

end LangSemantics.Java.EStateSimp
