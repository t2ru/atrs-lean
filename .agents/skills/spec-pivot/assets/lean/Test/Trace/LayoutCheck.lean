import Trace.Layout

/-!
# Test.Trace.LayoutCheck

`lake exe layout-check`（スキルの assets）。`LangSemantics`・`Machine`・`Trace`・`ConformanceKit`・`Test` の全宣言が、
モジュール名の下にあることを確かめる（`Trace.Layout`。spec-pivot の `lang/lean/rules.md#モジュールと名前空間`）。
違反のフィクスチャ `Test.Trace.LayoutFixture` は除く（`trace-test` が検出を確かめる）。`--json` で結果を JSON で出す。
-/

/-- 読み込むモジュールの組。道具の本体（`Trace.Dump` など）と、実行ファイルの入口（組を分ける）も含める。 -/
def Test.Trace.LayoutCheck.groups : Array (Array Lean.Name) :=
  #[#[`LangSemantics, `Machine, `Trace, `Trace.Dump, `Trace.Obligation, `Trace.Layout, `ConformanceKit, `Test,
      `Test.Trace.LayoutCheck], #[`Test.Trace.Main]]

unsafe def main (args : List String) : IO UInt32 :=
  Trace.Layout.run "layout-check" Test.Trace.LayoutCheck.groups
    [`LangSemantics, `Machine, `Trace, `ConformanceKit, `Test] [`Test.Trace.LayoutFixture] args
