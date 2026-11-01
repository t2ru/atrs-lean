import Spec.Prim.Date

/-!
# Tests.DateExhaustive

暦日の全日の検査（`Tests.Long` が実行する。`lake exe long-tests`。`Spec` の土台、backlog 591d）。

- `dateExhaustive`: 0001-01-01〜9999-12-31 の全日について、`ofOrdinal?` が値を返し（取りこぼしが無い）、
  翌日が年月日の繰り上がりの規則どおりであることを確かめる（`Spec.Prim.Date` の冒頭を参照）。

365 万日を回すため、`lake test` から分け、関係する変更があったときと全数の検査でだけ実行する（`docs/rules/checks.md`）。
`Spec.Prim.Date` だけを import する。
-/

open Spec.Prim

namespace Tests.DateExhaustive
open Spec.Prim.Date

/-- `d` の翌日の年月日（規則から直接求める）。 -/
def nextYmd (d : Date) : Nat × Nat × Nat :=
  if d.day < daysInMonth d.year d.month then (d.year, d.month, d.day + 1)
  else if d.month < 12 then (d.year, d.month + 1, 1)
  else (d.year + 1, 1, 1)

/-- 全日の検査。失敗した通算日数の一覧（先頭の数件）と、検査した日数を返す。 -/
def dateExhaustive : Array Nat × Nat := Id.run do
  let last : Date := ⟨9999, 12, 31, by decide⟩
  let mut bad : Array Nat := #[]
  let mut prev : Option Date := none
  for n in [0:last.ordinal + 1] do
    match Date.ofOrdinal? n with
    | none => if bad.size < 10 then bad := bad.push n
    | some d =>
      if let some p := prev then
        if nextYmd p != (d.year, d.month, d.day) then
          if bad.size < 10 then bad := bad.push n
      prev := some d
  if Date.ofOrdinal? (last.ordinal + 1) != none then bad := bad.push (last.ordinal + 1)
  return (bad, last.ordinal + 1)

end Tests.DateExhaustive
