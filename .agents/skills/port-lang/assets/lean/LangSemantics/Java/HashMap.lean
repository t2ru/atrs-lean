/-!
# LangSemantics.Java.HashMap

`java.util.HashMap` の、業務ロジックが使う範囲（`put`・`get`・`containsKey`・`size`）。
反復の順序は未規定なので、モデルは反復を与えない（反復に依存する原典は、順序を非決定性として別に写す）。
キーの等しさは `DecidableEq` とする。enum（同一性）と `String`（値の `equals`）の `equals` に一致する。
`hashCode` と `equals` が整合しないキーは、対象外である。

lang: `lang:java#java.util.HashMap`, `lang:java#java.util.LinkedHashMap`
-/

namespace LangSemantics.Java.HashMap

/-- `HashMap<K, V>`。項目は挿入順に並べるが、順序に意味は無い（キーは重複しない）。 -/
structure JHashMap (κ υ : Type) where
  entries : List (κ × υ) := []
  deriving Repr

namespace JHashMap

variable {κ υ : Type} [DecidableEq κ]

/-- 空の `new HashMap<>()`。 -/
def empty : JHashMap κ υ := {}

/-- `get(k)`。キーが無ければ `null`。 -/
def get (m : JHashMap κ υ) (k : κ) : Option υ :=
  (m.entries.find? fun e => e.1 == k).map (·.2)

/-- `containsKey(k)`。 -/
def containsKey (m : JHashMap κ υ) (k : κ) : Bool :=
  m.entries.any fun e => e.1 == k

/-- `put(k, v)`。同じキーがあれば値を置き換える（後勝ち）。 -/
def put (m : JHashMap κ υ) (k : κ) (v : υ) : JHashMap κ υ :=
  if m.containsKey k then ⟨m.entries.map fun e => if e.1 == k then (k, v) else e⟩
  else ⟨m.entries ++ [(k, v)]⟩

/-- `size()`。 -/
def size (m : JHashMap κ υ) : Nat := m.entries.length

/-- 項目を順に `put` した結果（`for (x : xs) map.put(key(x), x)`）。 -/
def ofList (xs : List (κ × υ)) : JHashMap κ υ :=
  xs.foldl (fun m e => m.put e.1 e.2) empty

end JHashMap

/-- `java.util.LinkedHashMap`（挿入順）。`JHashMap` と同じ表し方で、反復の順序は `entries` の順と定める
（同じキーの `put` は位置を保って値を置き換える。`LinkedHashMap` の既定の挿入順の動作に一致する）。 -/
abbrev JLinkedHashMap (κ υ : Type) := JHashMap κ υ

end LangSemantics.Java.HashMap
