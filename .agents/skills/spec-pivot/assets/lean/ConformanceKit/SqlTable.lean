import Lean.Data.Json
import LangSemantics.Sql.Postgresql

/-!
# ConformanceKit.SqlTable

SQL の差分実行の結果（スキルの `references/docs/lang/sql/harness.md#差分実行の結果`）の表を読む道具。
表は `{"columns": [...], "rows": [[...]]}` の形で、値は文字列か `null`。
列の値は、`LangSemantics.Sql.Postgresql` の型（`Varchar n`・`Int4`）に、型の範囲を検査して読む。
-/

open Lean LangSemantics.Sql.Postgresql

namespace ConformanceKit.SqlTable
open LangSemantics.Sql.Core

/-- 表の行（列の値は文字列か `null`）。 -/
abbrev Row := List (Option String)

def rowOf (j : Json) : Except String Row := do
  let .arr xs := j | throw "row is not an array"
  return xs.toList.map fun v => match v with | .str s => some s | _ => none

/-- 表: 列名と行。どの行も、列の数と同じ数の値を持つ（`wf`）。 -/
structure Table where
  columns : List String
  rows : List Row
  wf : rows.all (·.length == columns.length) = true

/-- 列名と行から表を作る。値の数が列の数と違う行があれば誤り。 -/
def Table.ofRows (columns : List String) (rows : List Row) : Except String Table :=
  if wf : rows.all (·.length == columns.length) = true then .ok { columns, rows, wf }
  else
    let bad := (rows.zipIdx.find? fun (r, _) => r.length != columns.length).map fun (r, i) => s!"row {i} has {r.length}"
    .error s!"row width does not match {columns.length} columns: {bad.getD ""}"

/-- 文書の `tables.<name>` の表。 -/
def table (doc : Json) (name : String) : Except String Table := do
  let t ← doc.getObjVal? "tables" >>= (·.getObjVal? name)
  let cols ← (t.getObjValAs? (Array String) "columns").map (·.toList)
  let rows ← (t.getObjValAs? (Array Json) "rows").map (·.toList)
  (Table.ofRows cols (← rows.mapM rowOf)).mapError (s!"{name}: " ++ ·)

/-- 行 `r` の列 `c` の値。`r` が `t` の行でなく、列 `c` の位置まで値を持たなければ誤り。 -/
def col (t : Table) (r : Row) (c : String) : Except String (Option String) := do
  let some i := t.columns.idxOf? c | throw s!"no column {c}"
  let some v := r[i]? | throw s!"row has no value for column {c} ({r.length} of {t.columns.length} values)"
  return v

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

end ConformanceKit.SqlTable
