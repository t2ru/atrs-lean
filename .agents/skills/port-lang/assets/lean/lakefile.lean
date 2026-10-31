import Lake
open Lake DSL

/-- アプリに依存しない Lean ライブラリ（port-lang スキルの assets）。core のみに依存する。

- `LangSemantics`: 言語意味論モデル
- `Machine`: 抽象機械と B メソッドのリファインメントの枠組み
- `ConformanceKit`: 適合テストベクタの実行器（メタ層）
- `Trace`: 追跡属性・ギャップの登録簿と、`trace-dump`・`obligation-check` の本体（入口の `main` はアプリの側に置く） -/
package langSemantics where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LangSemantics where

@[default_target]
lean_lib Machine where

@[default_target]
lean_lib Trace where

/-- 適合テストベクタの実行器と、SQL の差分実行の結果の表を読む道具（メタ層）。 -/
@[default_target]
lean_lib ConformanceKit where

/-- `#guard` による検査。`lake build LangSemanticsTest` で実行される。 -/
@[default_target]
lean_lib LangSemanticsTest where

/-- `Machine` の例・反例と公理の確認。`lake build MachineTest` で実行される。 -/
@[default_target]
lean_lib MachineTest where

/-- `ConformanceKit` の実行器の検査（`#guard`）。`lake build ConformanceKitTest` で実行される。 -/
@[default_target]
lean_lib ConformanceKitTest where

/-- `Trace` の属性の誤りの検査（`#guard_msgs`）とフィクスチャ。`lake build TraceTest` で実行される。 -/
@[default_target]
lean_lib TraceTest where

/-- `Trace.Dump`・`Trace.Obligation` をフィクスチャにかける検査。`lake exe trace-test` で実行する。 -/
@[default_target]
lean_exe «trace-test» where
  root := `TraceTest.Main
  supportInterpreter := true
