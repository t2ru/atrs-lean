import ConformanceKit

/-!
# Test.ConformanceKit.Runner

`ConformanceKit` の実行器を、メモリ上のベクタで確かめる（`lake build +Test.ConformanceKit`）。
-/

open Lean ConformanceKit

open ConformanceKit.Runner ConformanceKit.SqlTable

namespace Test.ConformanceKit.Runner

/-- 2 倍する操作。 -/
def ops : List (String × Op) := [("ex.double", fun i => do return toJson (2 * (← getNat i "n")))]

def doc (expected : Nat) : Json := Json.mkObj [
  ("operation", "ex.double"), ("modelDef", Json.arr #["Spec.Ex.double", "SourceModel.Ex.double"]),
  ("specRef", "docs/spec/example.md#double"),
  ("cases", Json.arr #[Json.mkObj [("id", "c1"), ("description", "2 倍"), ("input", Json.mkObj [("n", 3)]),
    ("expected", Json.mkObj [("ok", toJson expected)]), ("source", "example")]])]

def hasDef (n : Name) : Bool := n == `Spec.Ex.double || n == `SourceModel.Ex.double

-- 正しい期待値は 1 件の合格
#guard (runDoc ops hasDef "x.json" (doc 6) (some "Spec")).passed == 1
#guard (runDoc ops hasDef "x.json" (doc 6) (some "Spec")).failures.isEmpty
-- 誤った期待値は失敗
#guard (runDoc ops hasDef "x.json" (doc 7) (some "SourceModel")).failures.size == 1
-- 層に modelDef が無ければ失敗
#guard (runDoc ops hasDef "x.json" (doc 6) (some "TargetModel")).failures == #["no modelDef in layer TargetModel"]

-- SQL の表の列の読み取り
def tbl : Json := Json.mkObj [("tables", Json.mkObj [("T", Json.mkObj [
  ("columns", Json.arr #["A", "B"]), ("rows", Json.arr #[Json.arr #["1", Json.null]])])])]

#guard ((do let t ← table tbl "T"; let r := t.rows.head!; return (← icol t r "A").val) |>.toOption) == some (1 : Int)
#guard ((do let t ← table tbl "T"; let r := t.rows.head!; icol t r "B") |>.toOption).isNone

end Test.ConformanceKit.Runner
