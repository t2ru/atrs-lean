import Lake
open Lake DSL

/-- アプリに依存しない言語意味論モデル（port-lang スキルの assets）。core のみに依存する。 -/
package langSemantics where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LangSemantics where

/-- `#guard` による検査。`lake build LangSemanticsTest` で実行される。 -/
@[default_target]
lean_lib LangSemanticsTest where
