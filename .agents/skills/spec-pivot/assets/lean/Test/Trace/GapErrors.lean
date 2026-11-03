import Trace

/-!
# Test.Trace.GapErrors

ギャップの登録の値の誤りが、エラボレートの時点で誤りになることを確かめる。

- 種類ごとに要る欄・許す証明の状態は型（`Trace.Gap.Body`・`TypedEvidence`・`UndeterminedEvidence`）が表すので、
  不正な組み合わせは型の誤りになる（ADR bf1b）。ここでは、その代表を確かめる。
- ID・空でない文字列の形式は、証明フィールド（既定 `by decide`）の誤りになる。
- 値を式から読めない（関数で組み立てた文字列・名前）ことは、`@[gap_entry]` が付けた時点で誤りにする。
-/

open _root_.Trace Trace.Gap Trace.Id

namespace Test.Trace.GapErrors

/-! ## 型が表す組み合わせ -/

-- 前提型は、影響と作業項目を含むすべての欄を持つ（正例）。
example : PreGap :=
  { side := .abstract, premise := ne!"p", evidence := .pending [] ne!"r" none, rTasks := ne![oid!"ABS-001"],
              impact := .abort, impactReason := ne!"r", backlog := ne![bid!"00000000-0000-4000-8000-000000000001"] }

-- 前提型には影響が要る（欄を省けない）。
/-- error: Fields missing: `impact`, `impactReason`, `backlog` -/
#guard_msgs (substring := true) in
example : PreGap :=
  { side := .abstract, premise := ne!"p", evidence := .pending [] ne!"r" none, rTasks := ne![oid!"ABS-001"] }

-- 観測型は影響の欄を持たない。
/-- error: `impact` is not a field of structure `ObsGap` -/
#guard_msgs in
example : ObsGap :=
  { component := ne!"p", evidence := .pending [] ne!"r" none, rTasks := ne![oid!"ABS-001"], impact := .abort }

-- モデル外は R 課題の欄を持たない。
/-- error: `rTasks` is not a field of structure `OutOfModelGap` -/
#guard_msgs in
example : OutOfModelGap := { reason := ne!"p", claim := ``Nat, rTasks := ne![oid!"ABS-001"] }

-- PRE の外は、偽を証明済みの状態を持てない（証明の状態の欄が無い）。
/-- error: `evidence` is not a field of structure `OutsidePreGap` -/
#guard_msgs in
example : OutsidePreGap := { excludingPre := ne!"p", pre := [], evidence := .refuted ne![``Nat] ne![``Nat.le_refl] }

-- 偽を証明済みには、差異の定数と必要性の定理が 1 つ以上要る。
/-- error: Application type mismatch: The argument
  []
has type
  List ?m.1
but is expected to have type
  NEList Lean.Name
in the application
  TypedEvidence.refuted []
-/
#guard_msgs in
example : TypedEvidence := .refuted [] []

/-! ## 形式 -/

/-- error: could not synthesize default value for field 'wf' of 'Trace.Id.GapId' using tactics
---
error: Tactic `decide` proved that the proposition
  GapId.valid "X-1" = true
is false -/
#guard_msgs in
example : GapId := gid!"X-1"

/-- error: could not synthesize default value for field 'ne' of 'Trace.Id.NEString' using tactics
---
error: unsolved goals
⊢ False -/
#guard_msgs in
example : NEString := ne!""

/-- error: could not synthesize default value for field 'wf' of 'Trace.Id.ObligationId' using tactics
---
error: Tactic `decide` proved that the proposition
  ObligationId.valid "ABS-1" = true
is false -/
#guard_msgs in
example : ObligationId := oid!"ABS-1"

/-- error: could not synthesize default value for field 'wf' of 'Trace.Id.BacklogId' using tactics
---
error: Tactic `decide` proved that the proposition
  BacklogId.valid "backlog-x" = true
is false -/
#guard_msgs in
example : BacklogId := bid!"backlog-x"

/-! ## 式から読めない値 -/

/-- 文字列を関数で組み立てると読めない。 -/
def suffix : String := "PRE X"

/-- error: @[gap_entry]: expected a string literal (only definitions are unfolded; no function calls) -/
#guard_msgs in
@[gap_entry] def computed : Gap :=
  { id := gid!"D-005", sites := ne![⟨ne!"a", ne!"docs/a.md", ""⟩],
    body := .outsidePre { excludingPre := ⟨"p " ++ suffix, by decide⟩, pre := [] } }

/-- 名前を関数で組み立てると読めない。 -/
def nameSuffix : String := "x"

/-- error: @[gap_entry]: expected a string literal (only definitions are unfolded; no function calls) -/
#guard_msgs in
@[gap_entry] def computedName : Gap :=
  { id := gid!"D-009", sites := ne![⟨ne!"a", ne!"docs/a.md", ""⟩],
    body := .outsidePre { excludingPre := ne!"p", pre := [Lean.Name.str .anonymous ("a" ++ nameSuffix)] } }

/-- error: @[gap_entry]: Test.Trace.GapErrors.notGap must have type Trace.Gap -/
#guard_msgs in
@[gap_entry] def notGap : Nat := 0

end Test.Trace.GapErrors
