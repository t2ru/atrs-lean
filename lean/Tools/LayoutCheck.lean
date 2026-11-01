import Trace.Layout

/-!
# Tools.LayoutCheck

`lake exe layout-check`（ATRS）。`Spec`・`SourceModel`・`Abstraction`・`TargetModel`・`Refinement`・`Tests`・`Tools` の
全宣言が、モジュール名の下にあることを確かめる（spec-pivot の `Trace.Layout`、`lang/lean/rules.md#モジュールと名前空間`）。
スキルの assets（`LangSemantics`・`Machine`・`Trace`・`ConformanceKit`）は、スキル側の `layout-check` が確かめる。
`--json` で結果を JSON で出す。
-/

/-- 読み込むモジュールの組。実行ファイルの入口は、どれも `main` を持つため組を分ける。
組は 1 つずつ別のプロセスで判定する（`Trace.Layout.run`）ので、組を増やすと時間は増えるが、メモリの最大は組 1 つ分のままである。 -/
def Tools.LayoutCheck.groups : Array (Array Lean.Name) :=
  #[#[`Spec, `SourceModel, `Abstraction, `TargetModel, `Refinement, `Tests, `Tests.Long, `Tools.LayoutCheck],
    #[`Tests.Main], #[`Tests.LongMain], #[`Tools.AxiomCheck], #[`Tools.ObligationCheck], #[`Tools.TraceDump]]

unsafe def main (args : List String) : IO UInt32 :=
  Trace.Layout.run "layout-check" Tools.LayoutCheck.groups
    [`Spec, `SourceModel, `Abstraction, `TargetModel, `Refinement, `Tests, `Tools] [] args
