import LangSemantics.Java.Exception

/-!
# LangSemantics.Java.JList

`java.util.List` の、添字による読み出し。

lang: `dep:java.base#java.util.List.get`
-/

namespace LangSemantics.Java
open LangSemantics.Java.Exception

namespace JList

/-- `list.get(index)`: 範囲外なら `IndexOutOfBoundsException`。 -/
def get {α : Type} (list : List α) (index : Nat) : JResult α :=
  match list[index]? with
  | some a => .ok a
  | none => .error (.other "java.lang.IndexOutOfBoundsException" s!"Index {index} out of bounds for length {list.length}")

theorem get_cons_zero {α : Type} (a : α) (l : List α) : get (a :: l) 0 = .ok a := rfl

end JList

end LangSemantics.Java
