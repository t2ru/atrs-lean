import Lean.Data.Json
import LangSemantics.Sql.Postgresql

/-!
# ConformanceKit.SqlTable

SQL の差分実行の結果（スキルの `references/sql/harness.md#差分実行の結果`）の表を読む道具。
表は `{"columns": [...], "rows": [[...]]}` の形で、値は文字列か `null`。
列の値は、`LangSemantics.Sql.Postgresql` の型（`Varchar n`・`Int4`）に、型の範囲を検査して読む。
-/

open Lean LangSemantics.Sql LangSemantics.Sql.Postgresql

namespace ConformanceKit

/-- 表の行（列の値は文字列か `null`）。 -/
abbrev Row := List (Option String)

def rowOf (j : Json) : Except String Row := do
  let .arr xs := j | throw "row is not an array"
  return xs.toList.map fun v => match v with | .str s => some s | _ => none

/-- 表: 列名と行。 -/
structure Table where
  columns : List String
  rows : List Row

/-- 文書の `tables.<name>` の表。 -/
def table (doc : Json) (name : String) : Except String Table := do
  let t ← doc.getObjVal? "tables" >>= (·.getObjVal? name)
  let cols ← (t.getObjValAs? (Array String) "columns").map (·.toList)
  let rows ← (t.getObjValAs? (Array Json) "rows").map (·.toList)
  return { columns := cols, rows := ← rows.mapM rowOf }

/-- 行 `r` の列 `c` の値。 -/
def col (t : Table) (r : Row) (c : String) : Except String (Option String) := do
  let some i := t.columns.idxOf? c | throw s!"no column {c}"
  return (r[i]?).getD none

/-- SQL の結果（`SqlResult`）を、誤りの文に直す。 -/
def liftSql {α : Type} (r : SqlResult α) (what : String) : Except String α :=
  match r with
  | .ok a => .ok a
  | .error e => .error s!"{what}: {repr e}"

/-- `null` でない列の値。 -/
def notNull (o : Option String) (c : String) : Except String String :=
  match o with | some s => .ok s | none => .error s!"{c} is NULL"

/-- `VARCHAR(n)` の列。 -/
def vcol (n : Nat) (t : Table) (r : Row) (c : String) : Except String (Varchar n) := do
  liftSql (Varchar.ofString c n (← notNull (← col t r c) c)) c

/-- `INTEGER` の列。 -/
def icol (t : Table) (r : Row) (c : String) : Except String Int4 := do
  let s ← notNull (← col t r c) c
  let some v := s.toInt? | throw s!"{c}: not an integer: {s}"
  liftSql (Int4.ofInt v) c

end ConformanceKit
