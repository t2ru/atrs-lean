/-!
# LangSemantics.Java.Exception

Java の例外を値として表す。`SourceModel` / `TargetModel` は `JResult` を返し、
抽象化（α）では `illegalArgument`・`nullPointer` を「前提違反」に写す。

lang: `lang:java#JLS-11`
-/

namespace LangSemantics.Java.Exception

/-- Java の例外（モデルに必要な分類だけを持つ）。 -/
inductive JThrow where
  /-- `IllegalArgumentException`（Spring の `Assert` を含む）。 -/
  | illegalArgument (message : String)
  /-- `NullPointerException`。 -/
  | nullPointer (message : String)
  /-- `ArithmeticException`（整数の 0 除算など）。 -/
  | arithmetic (message : String)
  /-- その他の例外。`cls` は完全修飾クラス名。 -/
  | other (cls : String) (message : String)
  deriving Repr, BEq, DecidableEq

/-- 例外を投げうる計算。 -/
abbrev JResult (α : Type) := Except JThrow α

/-- Java の参照型（`null` になりうる）。 -/
abbrev JRef (α : Type) := Option α

/-- 参照外し。`null` なら `NullPointerException`。 -/
def JRef.deref {α : Type} (r : JRef α) (what : String := "") : JResult α :=
  match r with
  | some a => .ok a
  | none => .error (.nullPointer what)

end LangSemantics.Java.Exception
