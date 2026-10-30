import Lake
open Lake DSL

/-- アプリに依存しない Lean ライブラリ（port-lang スキルの assets）。core のみに依存する。

- `LangSemantics`: 言語意味論モデル
- `Machine`: 抽象機械と B メソッドのリファインメントの枠組み -/
package langSemantics where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LangSemantics where

@[default_target]
lean_lib Machine where

/-- `#guard` による検査。`lake build LangSemanticsTest` で実行される。 -/
@[default_target]
lean_lib LangSemanticsTest where

/-- `Machine` の例・反例と公理の確認。`lake build MachineTest` で実行される。 -/
@[default_target]
lean_lib MachineTest where
