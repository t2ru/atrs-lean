/-!
# LangSemantics.Java.Exception

Java の例外を値として表す。`SourceModel` / `TargetModel` は `JResult` を返し、
抽象化（α）では `illegalArgument`・`nullPointer` を「前提違反」に写す。

lang: `lang:java#JLS-11`
-/

namespace LangSemantics.Java.Exception

/-- Java の識別子の先頭の文字か（ASCII の英字・`_`・`$`）。 -/
def isIdentStart (c : Char) : Bool := c.isAlpha || c == '_' || c == '$'

/-- Java の識別子の 2 文字目以降の文字か（ASCII の英数字・`_`・`$`）。 -/
def isIdentPart (c : Char) : Bool := c.isAlphanum || c == '_' || c == '$'

/-- 完全修飾クラス名の形を、文字の列の上で読む。`atStart` は節（`.` で区切った識別子）の先頭か、`dotted` は `.` を
読んだか。 -/
def JClassName.validChars : Bool → Bool → List Char → Bool
  | atStart, dotted, [] => !atStart && dotted
  | true, dotted, c :: cs => isIdentStart c && validChars false dotted cs
  | false, dotted, c :: cs => if c == '.' then validChars true true cs else isIdentPart c && validChars false dotted cs

/-- 完全修飾クラス名の形: `.` で区切った 2 つ以上の空でない識別子（ASCII の英数字・`_`・`$` で、数字で始まらない）
（`toList` で見る）。 -/
def JClassName.valid (s : String) : Bool := JClassName.validChars true false s.toList

/-- Java の完全修飾クラス名（`java.lang.StringIndexOutOfBoundsException` など）。形（`JClassName.valid`）の証明を持つ。
字面は `cls!"…"` で書く。 -/
structure JClassName where
  val : String
  wf : JClassName.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 完全修飾クラス名を読む。形に合わなければ無し。 -/
def JClassName.ofString? (s : String) : Option JClassName := if h : JClassName.valid s then some ⟨s, h⟩ else none

/-- クラス名は値で決まる。 -/
theorem JClassName.ext {a b : JClassName} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めたクラス名の値は、読んだ文字列そのもの。 -/
theorem JClassName.val_of_ofString? {s : String} {c : JClassName} (h : JClassName.ofString? s = some c) : c.val = s := by
  unfold JClassName.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- クラス名の値を読むと、そのクラス名。 -/
@[simp] theorem JClassName.ofString?_val (c : JClassName) : JClassName.ofString? c.val = some c := by
  simp [JClassName.ofString?, c.wf]

/-- 読めるのは、形に合うときに限る。 -/
theorem JClassName.ofString?_isSome_iff {s : String} : (JClassName.ofString? s).isSome ↔ JClassName.valid s = true := by
  unfold JClassName.ofString?
  split <;> simp_all

instance : ToString JClassName := ⟨JClassName.val⟩

/-- 完全修飾クラス名の字面。形に合わない字面は、エラボレートの時点で型の誤りになる（形の証明は、長い名前の
`decide` が遅いので、文字列の簡約の `simp` で付ける）。 -/
syntax:max "cls!" str : term

macro_rules
  | `(cls! $s) => `((⟨$s, by simp [JClassName.valid, JClassName.validChars, isIdentStart, isIdentPart]⟩ :
      LangSemantics.Java.Exception.JClassName))

/-- Java の例外（モデルに必要な分類だけを持つ）。 -/
inductive JThrow where
  /-- `IllegalArgumentException`（Spring の `Assert` を含む）。 -/
  | illegalArgument (message : String)
  /-- `NullPointerException`。 -/
  | nullPointer (message : String)
  /-- `ArithmeticException`（整数の 0 除算など）。 -/
  | arithmetic (message : String)
  /-- その他の例外。`cls` は完全修飾クラス名（`JClassName`。形の証明を持つ）。 -/
  | other (cls : JClassName) (message : String)
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
