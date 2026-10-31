import Lean.Data.Json

/-!
# ConformanceKit.Runner

言語中立な適合テストベクタの実行器（スキルの `references/docs/spec/conformance.md`）。機能に依存しない部分だけを置く。

- 操作の割当（`operation` → モデルの関数）は、プロジェクトが `List (String × Op)` の表として与える。
  共有入力（`fixtures`）を使う操作の表は、`Fixtures` から作る（`runDirFx`）。
- `modelDef` は文字列か、モデルごとの名前の配列（`shared/` 用）。実行するモデルの層の名前を選ぶ（`selectModelDef`）。
- 現在は `ok` の期待値だけを扱う。
-/

open Lean

namespace ConformanceKit

/-- 操作: 入力 → 結果（`expected.ok` と比べる値）。 -/
abbrev Op := Json → Except String Json

/-! ## 値の取り出し -/

/-- 固定桁の十進数字列。 -/
def digits? (s : String) (n : Nat) : Option Nat :=
  if s.length = n ∧ s.all Char.isDigit then s.toNat? else none

def getStr (j : Json) (k : String) : Except String String := j.getObjValAs? String k
def getNat (j : Json) (k : String) : Except String Nat := j.getObjValAs? Nat k
def getInt (j : Json) (k : String) : Except String Int := j.getObjValAs? Int k

def optJson {α : Type} (f : α → Json) : Option α → Json
  | some a => f a
  | none => .null

def getArr (j : Json) (k : String) : Except String (List Json) := (j.getObjValAs? (Array Json) k).map (·.toList)

/-- `Option` の値を取り出す（無ければ `msg` の誤り）。 -/
def need {α : Type} (o : Option α) (msg : String) : Except String α :=
  match o with
  | some a => .ok a
  | none => .error msg

/-! ## 実行 -/

/-- 1 ファイルの結果。 -/
structure FileResult where
  path : System.FilePath
  passed : Nat := 0
  failures : Array String := #[]

/-- ベクタの共有入力（`fixtures` の `master`・`config`。無ければ `null`）。 -/
structure Fixtures where
  master : Json := .null
  config : Json := .null

/-- `modelDef` のうち、層 `layer`（`Spec`・`SourceModel` など）の名前。`layer` が無ければ文字列だけを受ける。 -/
def selectModelDef (doc : Json) (layer : Option String) : Except String String :=
  match doc.getObjVal? "modelDef", layer with
  | .ok (.str s), none => .ok s
  | .ok (.str s), some l => if s.startsWith (l ++ ".") then .ok s else .error s!"modelDef {s} is not in layer {l}"
  | .ok (.arr xs), some l =>
    match xs.toList.filterMap (fun x => match x with | .str s => if s.startsWith (l ++ ".") then some s else none | _ => none) with
    | [s] => .ok s
    | [] => .error s!"no modelDef in layer {l}"
    | _ => .error s!"more than one modelDef in layer {l}"
  | _, _ => .error "missing modelDef"

/-- ケースの必須キー。 -/
def requiredCaseKeys : List String := ["id", "description", "input", "expected", "source"]

/-- 1 ファイルを実行する。`hasDef` はモデル定義の存在の確認（`modelDef`）。 -/
def runDoc (ops : List (String × Op)) (hasDef : Name → Bool) (path : System.FilePath) (doc : Json)
    (layer : Option String := none) : FileResult := Id.run do
  let mut r : FileResult := { path }
  let fail (r : FileResult) (msg : String) : FileResult := { r with failures := r.failures.push msg }
  let .ok operation := getStr doc "operation" | return fail r "missing operation"
  let modelDef ← match selectModelDef doc layer with
    | .ok m => pure m
    | .error e => return fail r e
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

/-- ベクタの `fixtures`（`{"master": …, "config": …}`。`conformance/` からの相対パス）を読む。`root` は `conformance/`。 -/
def loadFixtures (root : System.FilePath) (doc : Json) : IO (Except String Fixtures) := do
  let fxs := (doc.getObjVal? "fixtures").toOption.getD (.obj {})
  let read (k : String) : IO (Except String Json) := do
    match fxs.getObjValAs? String k with
    | .error _ => return .ok .null
    | .ok n =>
      let p := root / n
      if !(← p.pathExists) then return .error s!"fixture not found: {n}"
      return (Json.parse (← IO.FS.readFile p)).mapError (s!"{n}: invalid JSON: " ++ ·)
  match ← read "master", ← read "config" with
  | .ok master, .ok config => return .ok { master, config }
  | .error e, _ | _, .error e => return .error e

/-- 共有入力を使うディレクトリの実行。操作の表は、ベクタごとの `Fixtures` から作る。
`layer` は実行するモデルの層で、`modelDef` の配列から名前を選ぶのに使う。 -/
def runDirFx (mkOps : Fixtures → Except String (List (String × Op))) (layer : String) (hasDef : Name → Bool)
    (root dir : System.FilePath) : IO (Array FileResult) := do
  let entries ← dir.readDir
  let files := (entries.map (·.path)).filter (·.extension == some "json") |>.qsort (·.toString < ·.toString)
  let mut out := #[]
  for p in files do
    match Json.parse (← IO.FS.readFile p) with
    | .error e => out := out.push { path := p, failures := #[s!"invalid JSON: {e}"] }
    | .ok doc =>
      match ← loadFixtures root doc with
      | .error e => out := out.push { path := p, failures := #[e] }
      | .ok fx =>
        match mkOps fx with
        | .error e => out := out.push { path := p, failures := #[s!"fixtures: {e}"] }
        | .ok ops => out := out.push (runDoc ops hasDef p doc (some layer))
  return out

end ConformanceKit
