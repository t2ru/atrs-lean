/-!
# LangSemantics.Rust.Panic

Rust のパニックを値として表す（Lean の `panic!` は使わない）。

lang: `lang:rust#panic`
-/

namespace LangSemantics.Rust

/-- パニック（メッセージ付き）。 -/
structure RPanic where
  message : String
  deriving Repr, BEq, DecidableEq

/-- パニックしうる計算。`Result<T, E>` は値として `Except E T` で別に表す。 -/
abbrev RExec (α : Type) := Except RPanic α

def rpanic {α : Type} (message : String) : RExec α := .error ⟨message⟩

/-- ビルドプロファイル。既定の算術の溢れの扱いを決める（`overflow-checks`）。 -/
inductive Profile where
  /-- `overflow-checks = true`（`debug` の既定）: 溢れたらパニック。 -/
  | checked
  /-- `overflow-checks = false`（`release` の既定）: 折り返す。 -/
  | wrapping
  deriving Repr, BEq, DecidableEq

end LangSemantics.Rust
