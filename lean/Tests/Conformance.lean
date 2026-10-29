import Lean.Data.Json
import Spec

/-!
# Tests.Conformance

適合テストベクタ（`conformance/`）の実行器（スキル port-lang の `conformance.md`）。

- ファイルの読み込み・形式の検査・`expected` の比較は、機能に依存しない（backlog 0012 で生成器と
  他の機能に広げる）。
- 操作ごとの割当（`operation` → `Spec` の関数）は `formatOps` のような表で与える。
- 現在は `ok` の期待値だけを扱う。
-/

open Lean Spec Spec.Prim

namespace Tests.Conformance

/-- 操作: 入力 → 結果（`expected.ok` と比べる値）。 -/
abbrev Op := Json → Except String Json

/-! ## 値の表現（`conformance.md#値の表現`） -/

/-- 固定桁の十進数字列。 -/
def digits? (s : String) (n : Nat) : Option Nat :=
  if s.length = n ∧ s.all Char.isDigit then s.toNat? else none

/-- `"yyyy-MM-dd"` -/
def decodeDate (s : String) : Except String Date :=
  match s.splitOn "-" with
  | [y, m, d] =>
    match (do Date.ofYmd? (← digits? y 4) (← digits? m 2) (← digits? d 2)) with
    | some v => .ok v
    | none => .error s!"invalid date: {s}"
  | _ => .error s!"invalid date: {s}"

/-- `"HH:mm"` -/
def decodeTime (s : String) : Except String HourMinute :=
  match s.splitOn ":" with
  | [h, m] =>
    match (do HourMinute.ofHm? (← digits? h 2) (← digits? m 2)) with
    | some v => .ok v
    | none => .error s!"invalid time: {s}"
  | _ => .error s!"invalid time: {s}"

/-- `"yyyy-MM-ddTHH:mm:ss"` -/
def decodeDateTime (s : String) : Except String DateTime :=
  match s.splitOn "T" with
  | [d, t] => do
    let date ← decodeDate d
    match t.splitOn ":" with
    | [h, m, sec] =>
      match digits? h 2, digits? m 2, digits? sec 2 with
      | some h, some m, some sec =>
        if hv : h ≤ 23 ∧ m ≤ 59 ∧ sec ≤ 59 then .ok ⟨date, h, m, sec, hv⟩
        else .error s!"invalid date-time: {s}"
      | _, _, _ => .error s!"invalid date-time: {s}"
    | _ => .error s!"invalid date-time: {s}"
  | _ => .error s!"invalid date-time: {s}"

def getStr (j : Json) (k : String) : Except String String := j.getObjValAs? String k
def getNat (j : Json) (k : String) : Except String Nat := j.getObjValAs? Nat k
def getInt (j : Json) (k : String) : Except String Int := j.getObjValAs? Int k

def optJson {α : Type} (f : α → Json) : Option α → Json
  | some a => f a
  | none => .null

/-! ## 操作の割当（`format`） -/

/-- `format.*` の操作。 -/
def formatOps : List (String × Op) := [
  ("format.fmtDate", fun i => do return .str (fmtDate (← decodeDate (← getStr i "date")))),
  ("format.fmtIsoDate", fun i => do return .str (fmtIsoDate (← decodeDate (← getStr i "date")))),
  ("format.fmtTime", fun i => do return .str (fmtTime (← decodeTime (← getStr i "time")))),
  ("format.fmtTimestamp", fun i => do return .str (fmtTimestamp (← decodeDateTime (← getStr i "dateTime")))),
  ("format.fmtYen", fun i => do return .str (fmtYen (← getNat i "amount"))),
  ("format.fmtPaymentDate", fun i => do return .str (fmtPaymentDate (← decodeDate (← getStr i "date")))),
  ("format.fullYearsBetween", fun i => do
    return toJson (Date.fullYearsBetween (← decodeDate (← getStr i "birthday")) (← decodeDate (← getStr i "date")))),
  ("format.parseHHmm", fun i => do
    return optJson (fun t => .str (fmtTime t)) (HourMinute.parseHHmm (← getStr i "text"))),
  ("format.addDays", fun i => do
    return optJson (fun d => .str (fmtIsoDate d)) ((← decodeDate (← getStr i "date")).addDays (← getInt i "days"))),
  ("format.daysBetween", fun i => do
    return toJson (Date.daysBetween (← decodeDate (← getStr i "from")) (← decodeDate (← getStr i "to"))))
]

/-! ## 実行 -/

/-- 1 ファイルの結果。 -/
structure FileResult where
  path : System.FilePath
  passed : Nat := 0
  failures : Array String := #[]

/-- ケースの必須キー。 -/
def requiredCaseKeys : List String := ["id", "description", "input", "expected", "source"]

/-- 1 ファイルを実行する。`hasDef` はモデル定義の存在の確認（`modelDef`）。 -/
def runDoc (ops : List (String × Op)) (hasDef : Name → Bool) (path : System.FilePath) (doc : Json) :
    FileResult := Id.run do
  let mut r : FileResult := { path }
  let fail (r : FileResult) (msg : String) : FileResult := { r with failures := r.failures.push msg }
  let .ok operation := getStr doc "operation" | return fail r "missing operation"
  let .ok modelDef := getStr doc "modelDef" | return fail r "missing modelDef"
  if !(hasDef modelDef.toName) then r := fail r s!"modelDef not found: {modelDef}"
  if (getStr doc "specRef").toOption.isNone then r := fail r "missing specRef"
  let some op := ops.lookup operation | return fail r s!"unknown operation: {operation}"
  let .ok cases := doc.getObjValAs? (Array Json) "cases" | return fail r "missing cases"
  let mut ids : Array String := #[]
  for c in cases do
    let id := (getStr c "id").toOption.getD "?"
    for k in requiredCaseKeys do
      if (c.getObjVal? k).toOption.isNone then r := fail r s!"{id}: missing {k}"
    if ids.contains id then r := fail r s!"{id}: duplicate id"
    ids := ids.push id
    let .ok input := c.getObjVal? "input" | continue
    let .ok expected := c.getObjVal? "expected" | continue
    match expected.getObjVal? "ok" with
    | .error _ => r := fail r s!"{id}: only `ok` expectations are supported"
    | .ok want =>
      match op input with
      | .error e => r := fail r s!"{id}: {e}"
      | .ok got =>
        if got == want then r := { r with passed := r.passed + 1 }
        else r := fail r s!"{id}: expected {want.compress}, got {got.compress}"
  return r

/-- ディレクトリの `*.json` をすべて実行する（ファイル名順）。 -/
def runDir (ops : List (String × Op)) (hasDef : Name → Bool) (dir : System.FilePath) :
    IO (Array FileResult) := do
  let entries ← dir.readDir
  let files := (entries.map (·.path)).filter (·.extension == some "json") |>.qsort (·.toString < ·.toString)
  let mut out := #[]
  for p in files do
    match Json.parse (← IO.FS.readFile p) with
    | .error e => out := out.push { path := p, failures := #[s!"invalid JSON: {e}"] }
    | .ok doc => out := out.push (runDoc ops hasDef p doc)
  return out

end Tests.Conformance
