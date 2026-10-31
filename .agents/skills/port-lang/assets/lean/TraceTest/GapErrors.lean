import Trace

/-!
# TraceTest.GapErrors

`@[gap_entry]` の値の誤り（種類ごとの必須の欄・禁じる欄、読めない値）が、付けた時点でエラーになることを確かめる。
-/

namespace TraceTest.GapErrors

open Trace

/-- error: @[gap_entry] D-001: impact is required for pre; backlog is required for pre (the impact table) -/
#guard_msgs in
@[gap_entry] def noImpact : Gap :=
  { id := "D-001", kind := .pre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p", rTasks := ["ABS-001"],
    wTask := some "ABS-101" }

/-- error: @[gap_entry] D-002: impact is only for pre, not observational -/
#guard_msgs in
@[gap_entry] def obsWithImpact : Gap :=
  { id := "D-002", kind := .observational, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    rTasks := ["ABS-001"], wTask := some "ABS-102", impact := some (.outputOnly, "r") }

/-- error: @[gap_entry] D-003: rTasks is only for pre / observational, not out_of_model; wTask is only for pre / observational, not out_of_model -/
#guard_msgs in
@[gap_entry] def outOfModelWithTasks : Gap :=
  { id := "D-003", kind := .outOfModel, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    rTasks := ["ABS-001"], wTask := some "ABS-103" }

/-- error: @[gap_entry] D-004: resolution is required for undetermined -/
#guard_msgs in
@[gap_entry] def undeterminedNoResolution : Gap :=
  { id := "D-004", kind := .undetermined, sites := [⟨"a", "docs/a.md", ""⟩] }

/-- error: @[gap_entry] X-1: id "X-1" is not D-NNN / T-NNN; sites must not be empty -/
#guard_msgs in
@[gap_entry] def badId : Gap := { id := "X-1", kind := .outsidePre, sites := [], premise := "p" }

/-- 文字列を関数で組み立てると読めない。 -/
def suffix : String := "05"

/-- error: @[gap_entry]: expected a string literal (only definitions are unfolded; no function calls) -/
#guard_msgs in
@[gap_entry] def computed : Gap := { id := "D-0" ++ suffix, kind := .outsidePre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p" }

/-- error: @[gap_entry]: TraceTest.GapErrors.notGap must have type Trace.Gap -/
#guard_msgs in
@[gap_entry] def notGap : Nat := 0

end TraceTest.GapErrors
