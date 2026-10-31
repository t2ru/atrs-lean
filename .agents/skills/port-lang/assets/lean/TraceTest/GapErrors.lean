import Trace

/-!
# TraceTest.GapErrors

`@[gap_entry]` の値の誤り（種類ごとの必須の欄・禁じる欄、種類と証明の状態の組み合わせ、読めない値）が、
付けた時点でエラーになることを確かめる。
-/

namespace TraceTest.GapErrors

open Trace

/-- error: @[gap_entry] D-001: impact is required for pre; backlog is required for pre (the impact table) -/
#guard_msgs in
@[gap_entry] def noImpact : Gap :=
  { id := "D-001", kind := .pre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p", rTasks := ["ABS-001"],
    evidence := .pending "Lean に述語がまだ無い" (some "ABS-101") }

/-- error: @[gap_entry] D-002: impact is only for pre, not observational -/
#guard_msgs in
@[gap_entry] def obsWithImpact : Gap :=
  { id := "D-002", kind := .observational, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    rTasks := ["ABS-001"], evidence := .pending "r" none, impact := some (.outputOnly, "r") }

/-- error: @[gap_entry] D-003: rTasks is only for pre / observational, not out_of_model -/
#guard_msgs in
@[gap_entry] def outOfModelWithTasks : Gap :=
  { id := "D-003", kind := .outOfModel, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    rTasks := ["ABS-001"], evidence := .unformalized ``Nat "" }

/-- error: @[gap_entry] D-004: evidence unformalized does not fit kind undetermined (or lacks its theorems / resolution) -/
#guard_msgs in
@[gap_entry] def undeterminedNoResolution : Gap :=
  { id := "D-004", kind := .undetermined, sites := [⟨"a", "docs/a.md", ""⟩], evidence := .unformalized ``Nat "" }

/-- error: @[gap_entry] D-006: evidence refuted does not fit kind outside_pre (or lacks its theorems / resolution); evidence refuted needs the deviations (the @[deviation] constants) -/
#guard_msgs in
@[gap_entry] def kindMismatch : Gap :=
  { id := "D-006", kind := .outsidePre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    evidence := .refuted [``Nat.le_refl] }

/-- error: @[gap_entry] D-007: evidence refuted does not fit kind pre (or lacks its theorems / resolution) -/
#guard_msgs in
@[gap_entry] def refutedWithoutTheorems : Gap :=
  { id := "D-007", kind := .pre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p", rTasks := ["ABS-001"],
    deviations := [``Nat], evidence := .refuted [], impact := some (.abort, "r"), backlog := ["b"] }

/-- error: @[gap_entry] D-008: evidence pending does not fit kind out_of_model (or lacks its theorems / resolution) -/
#guard_msgs in
@[gap_entry] def outOfModelPending : Gap :=
  { id := "D-008", kind := .outOfModel, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    evidence := .pending "r" none }

/-- error: @[gap_entry] X-1: id "X-1" is not D-NNN / T-NNN; sites must not be empty -/
#guard_msgs in
@[gap_entry] def badId : Gap :=
  { id := "X-1", kind := .outsidePre, sites := [], premise := "p", evidence := .excludedBy [] }

/-- 文字列を関数で組み立てると読めない。 -/
def suffix : String := "05"

/-- error: @[gap_entry]: expected a string literal (only definitions are unfolded; no function calls) -/
#guard_msgs in
@[gap_entry] def computed : Gap :=
  { id := "D-0" ++ suffix, kind := .outsidePre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    evidence := .excludedBy [] }

/-- 名前を関数で組み立てると読めない。 -/
def nameSuffix : String := "x"

/-- error: @[gap_entry]: expected a string literal (only definitions are unfolded; no function calls) -/
#guard_msgs in
@[gap_entry] def computedName : Gap :=
  { id := "D-009", kind := .outsidePre, sites := [⟨"a", "docs/a.md", ""⟩], premise := "p",
    evidence := .excludedBy [Lean.Name.str .anonymous ("a" ++ nameSuffix)] }

/-- error: @[gap_entry]: TraceTest.GapErrors.notGap must have type Trace.Gap -/
#guard_msgs in
@[gap_entry] def notGap : Nat := 0

end TraceTest.GapErrors
