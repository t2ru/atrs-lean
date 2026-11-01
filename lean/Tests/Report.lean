import ConformanceKit

/-!
# Tests.Report

`lake test`（`Tests.Main`）と長い検査（`Tests.Long`）が共有する、結果の表示と失敗の数え上げ。
節ごとの経過時間を表示し、検査の層（常時の段・変更時の段）の分類の根拠にする（`docs/rules/checks.md`）。
-/

namespace Tests.Report

/-- 失敗した検査の数。 -/
initialize failures : IO.Ref Nat ← IO.mkRef 0

/-- 検査の結果を 1 行表示し、失敗を数える。 -/
def check (label : String) (ok : Bool) : IO Unit := do
  if ok then IO.println s!"  ok   {label}"
  else
    IO.eprintln s!"  FAIL {label}"
    failures.modify (· + 1)

/-- 節を実行し、経過時間を表示する。閉じた項がモジュールの初期化で評価された場合、その時間は含まない。 -/
def timed (label : String) (act : IO Unit) : IO Unit := do
  let t0 ← IO.monoMsNow
  act
  let t1 ← IO.monoMsNow
  IO.println s!"  time {label}: {t1 - t0} ms"

/-- 適合テストベクタのディレクトリの照合の結果を表示する（ファイルが無いことも失敗とする）。 -/
def reportConformance (label : String) (results : Array ConformanceKit.Runner.FileResult) : IO Unit := do
  check s!"conformance: {label}: files found" (!results.isEmpty)
  for r in results do
    for f in r.failures do IO.eprintln s!"    {label}/{r.path.fileName.getD ""}: {f}"
    check s!"conformance: {label}/{r.path.fileName.getD ""} ({r.passed} cases)" (r.failures.isEmpty && r.passed > 0)

/-- 結果の要約を表示し、終了コードを返す。 -/
def finish : IO UInt32 := do
  let n ← failures.get
  if n == 0 then
    IO.println "all tests passed"
    return 0
  else
    IO.eprintln s!"{n} test(s) failed"
    return 1

end Tests.Report
