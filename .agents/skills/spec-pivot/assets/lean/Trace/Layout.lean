import Trace.Dump

/-!
# Trace.Layout

`layout-check` の本体。宣言の完全名がモジュール名の下にあること（NS-1）を、環境の全定数について確かめる
（spec-pivot の `lang/lean/rules.md#モジュールと名前空間`）。

宣言 `n` のモジュールを `M` とする。`n = M` か、`n` が `M.` で始まれば合格とする。例外は次の 3 つだけである。

- **E1 型の名前空間（ドット記法）**: `n` が型（帰納型・構造体・クラス）`T` の下にあり、`T` を定義するモジュールが
  `M` の真の祖先である（型のモジュールの下位モジュールが、ドット記法で使う補題を型の名前空間に足す）。
  例: モジュール `LangSemantics.Java.JDouble.Lemmas` の `LangSemantics.Java.JDouble.pow2_eq`。
- **E2 実行ファイルの入口**: ルートの `main`。
- **E3 明示した例外**: `n` 自身か、その接頭辞の定数に `@[ns_exception "<理由>"]` が付いている。
- **E4 型名のモジュールのインスタンス**: `M` 自身が `M` で定義された型（型名のモジュール）で、`n` が `M` の親の名前空間に
  直接置かれたインスタンスか、その下の補助の定数である（`deriving` などが、型の外の名前空間に `instReprT` と名付けるため）。

自動生成の補助定数（`Trace.Dump.isHidden`）は対象にしない。`private` の名前も対象にしない。

モジュールの組は、組ごとに別のプロセス（同じ実行ファイルを `--layout-group <i>` で起動したもの）で読み込んで判定し、
親のプロセスは結果の JSON を合わせるだけで環境を読み込まない。読み込んだ環境（.olean の領域）はプロセスの終了で
解放されるので、メモリの最大は組 1 つ分になる（スキルの ADR 89f2）。
-/

namespace Trace.Layout
open Trace.Attr

open Lean

/-- 違反の 1 件。 -/
structure Item where
  name : Name
  module : Name

/-- 明示した例外の 1 件（理由は 1 つ以上）。 -/
structure ExceptionItem extends Item where
  reason : Trace.Id.NEList String

/-- 判定の結果。 -/
structure Result where
  violations : Array Item := #[]
  exceptions : Array ExceptionItem := #[]
  /-- 検査した定数の数。 -/
  checked : Nat := 0
  /-- 範囲のモジュール（環境の読み込みの順）と、それぞれで検査した定数の数。数が 0 のモジュールも含む。 -/
  modules : Array (Name × Nat) := #[]

/-- 定数が型（帰納型。構造体・クラスを含む）か。 -/
def isType (env : Environment) (n : Name) : Bool :=
  match env.find? n with
  | some (.inductInfo _) => true
  | _ => false

/-- `n` の真の祖先（`n` 自身と匿名を除く）。近いものから。 -/
def ancestors (n : Name) : List Name :=
  match n with
  | .str p _ | .num p _ => if p.isAnonymous then [] else p :: ancestors p
  | .anonymous => []

/-- `n` 自身か、その祖先の定数に付いた `@[ns_exception]` の理由（1 つ以上）。 -/
def exceptionOf (env : Environment) (n : Name) : Option (Trace.Id.NEList String) :=
  (n :: ancestors n).findSome? fun m => (strsOf nsExceptionAttr env m).bind (Trace.Id.NEList.ofList? ·.toList)

/-- 定数を定義したモジュール。 -/
def moduleOf? (env : Environment) (n : Name) : Option Name := do
  let idx ← env.getModuleIdxFor? n
  env.header.moduleNames[idx.toNat]?

/-- `a` が `b` の真の祖先か。 -/
def isStrictPrefix (a b : Name) : Bool := a != b && a.isPrefixOf b

/-- NS-1 と E1・E2・E4 に照らして、置き場所が正しいか（E3 は別に見る）。 -/
def placedOk (env : Environment) (m n : Name) : Bool :=
  n == m || m.isPrefixOf n || n == `main ||
  -- E1: 型 T の下で、T のモジュールが M の真の祖先
  (ancestors n).any (fun t => isType env t && (moduleOf? env t).any (isStrictPrefix · m)) ||
  -- E4: 型名のモジュールの、親の名前空間のインスタンス
  (isType env m && moduleOf? env m == some m &&
    (n :: ancestors n).any fun c => c.getPrefix == m.getPrefix && Meta.isInstanceCore env c)

/-- `roots` を根とするモジュールの、`exclude` 以外の全定数を判定する（名前順）。 -/
def check (env : Environment) (roots : List Name) (exclude : List Name := []) : Result := Id.run do
  let mods := env.header.moduleNames
  let inScope (m : Name) : Bool :=
    roots.any (·.isPrefixOf m) && !exclude.contains m
  let mut r : Result := {}
  -- 範囲のモジュールと、その位置（数を足すため）
  let mut modules : Array (Name × Nat) := #[]
  let mut pos : NameMap Nat := {}
  for m in mods do
    if inScope m then
      pos := pos.insert m modules.size
      modules := modules.push (m, 0)
  let mut names : Array (Name × Name) := #[]
  for (n, _) in env.constants.map₁.toList do
    let some idx := env.getModuleIdxFor? n | continue
    let some m := mods[idx.toNat]? | continue
    unless inScope m do continue
    if Trace.Dump.isHidden env n then continue
    names := names.push (n, m)
  names := names.qsort (fun a b => Trace.Dump.nameLt a.1 b.1)
  for (n, m) in names do
    r := { r with checked := r.checked + 1 }
    if let some k := pos.find? m then
      modules := modules.modify k fun (m', c) => (m', c + 1)
    if placedOk env m n then continue
    match exceptionOf env n with
    | some why => r := { r with exceptions := r.exceptions.push { name := n, module := m, reason := why } }
    | none => r := { r with violations := r.violations.push { name := n, module := m } }
  return { r with modules := modules }

/-- 同じモジュールで祖先も違反（または例外）の名前は、祖先の 1 件にまとめる（構築子・射影・自動生成の補題など）。
同じモジュールの中だけでまとめるので、組ごとに行ってよい（1 つのモジュールは、合わせた結果では 1 つの組から来る）。 -/
def Result.collapse (r : Result) : Result :=
  let heads : NameMap Name :=
    (r.violations ++ r.exceptions.map (·.toItem)).foldl (fun s i => s.insert i.name i.module) {}
  let isTop (i : Item) := !(ancestors i.name).any (heads.find? · == some i.module)
  { r with violations := r.violations.filter isTop, exceptions := r.exceptions.filter (isTop ·.toItem) }

/-- 組の子プロセスが返す違反の 1 件（名前は文字列。環境の外へ持ち出すため）。 -/
structure OutItem where
  name : String
  module : String

/-- 組の子プロセスが返す例外の 1 件（理由は 1 つ以上）。 -/
structure OutException extends OutItem where
  reason : Trace.Id.NEList String

/-- 組の子プロセスが返す結果。 -/
structure GroupOut where
  /-- 範囲のモジュールと、それぞれで検査した定数の数（`Result.modules`）。 -/
  modules : Array (String × Nat) := #[]
  violations : Array OutItem := #[]
  exceptions : Array OutException := #[]

def Item.out (i : Item) : OutItem := { name := i.name.toString, module := i.module.toString }

def ExceptionItem.out (i : ExceptionItem) : OutException := { i.toItem.out with reason := i.reason }

def Result.out (r : Result) : GroupOut :=
  { modules := r.modules.map fun (m, k) => (m.toString, k),
    violations := r.violations.map (·.out), exceptions := r.exceptions.map (·.out) }

/-- 違反の 1 件を JSON にする（`reason` は空の配列）。 -/
def OutItem.toJson (i : OutItem) : Json :=
  Json.mkObj [("name", Lean.toJson i.name), ("module", Lean.toJson i.module), ("reason", Json.arr #[])]

/-- 例外の 1 件を JSON にする。 -/
def OutException.toJson (i : OutException) : Json :=
  Json.mkObj [("name", Lean.toJson i.name), ("module", Lean.toJson i.module),
    ("reason", Lean.toJson i.reason.toList)]

def OutItem.fromJson? (j : Json) : Except String OutItem := do
  let name ← j.getObjValAs? String "name"
  let module ← j.getObjValAs? String "module"
  return { name, module }

def OutException.fromJson? (j : Json) : Except String OutException := do
  let i ← OutItem.fromJson? j
  let some reason := Trace.Id.NEList.ofList? (← j.getObjValAs? (List String) "reason")
    | throw "an exception needs at least one reason"
  return { i with reason }

def GroupOut.toJson (g : GroupOut) : Json :=
  Json.mkObj [
    ("modules", Json.arr (g.modules.map fun (m, k) =>
      Json.mkObj [("module", Lean.toJson m), ("checked", Lean.toJson k)])),
    ("violations", Json.arr (g.violations.map (·.toJson))),
    ("exceptions", Json.arr (g.exceptions.map (·.toJson)))]

def GroupOut.fromJson? (j : Json) : Except String GroupOut := do
  let modules ← (← j.getObjValAs? (Array Json) "modules").mapM fun m => do
    return (← m.getObjValAs? String "module", ← m.getObjValAs? Nat "checked")
  let violations ← (← j.getObjValAs? (Array Json) "violations").mapM OutItem.fromJson?
  let exceptions ← (← j.getObjValAs? (Array Json) "exceptions").mapM OutException.fromJson?
  return { modules, violations, exceptions }

/--
組ごとの結果を、組の順に合わせる。前の組に現れたモジュールは数えず、その件も採らない（同じモジュールを読み込む
組が複数あっても、最初の組の判定だけを使う）。検査した定数の数の合計とともに返す。
-/
def mergeGroups (gs : Array GroupOut) : GroupOut × Nat := Id.run do
  let mut seen : Array String := #[]
  let mut out : GroupOut := {}
  let mut checked := 0
  for g in gs do
    let fresh := g.modules.filter fun (m, _) => !seen.contains m
    let names := fresh.map (·.1)
    checked := fresh.foldl (fun s (_, k) => s + k) checked
    let keep (i : OutItem) := names.contains i.module
    out := { modules := out.modules ++ fresh, violations := out.violations ++ g.violations.filter keep,
             exceptions := out.exceptions ++ g.exceptions.filter (keep ·.toOutItem) }
    seen := seen ++ names
  return (out, checked)

/-- 子プロセスの本体: 組 `i` の環境を読み込んで判定し、結果（`GroupOut`）を JSON で標準出力に出す。 -/
unsafe def runGroup (label : String) (groups : Array (Array Name)) (roots : List Name) (exclude : List Name)
    (i : Nat) : IO UInt32 := do
  let some g := groups[i]? | do
    IO.eprintln s!"{label}: no module group {i}"
    return 2
  let env ← Trace.Dump.loadEnv g
  IO.println (check env roots exclude).collapse.out.toJson.compress
  return 0

/-- 親のプロセスの本体: 組ごとに子プロセスを順に起動し、結果を合わせて報告する。 -/
def runAll (label : String) (groups : Array (Array Name)) (args : List String) : IO UInt32 := do
  let app ← IO.appPath
  let mut outs : Array GroupOut := #[]
  let mut i := 0
  for g in groups do
    let o ← IO.Process.output { cmd := app.toString, args := #["--layout-group", toString i] }
    unless o.stderr.isEmpty do IO.eprint o.stderr
    if o.exitCode != 0 then
      IO.eprintln s!"{label}: module group {i} {g} failed (exit code {o.exitCode})"
      return 2
    match Json.parse o.stdout >>= GroupOut.fromJson? with
    | .ok r => outs := outs.push r
    | .error e =>
      IO.eprintln s!"{label}: module group {i} {g}: unreadable result: {e}"
      return 2
    i := i + 1
  let (r, checked) := mergeGroups outs
  if args.contains "--json" then
    IO.println (Json.mkObj [("violations", Json.arr (r.violations.map (·.toJson))),
      ("exceptions", Json.arr (r.exceptions.map (·.toJson))), ("checked", Lean.toJson checked)]).pretty
  else
    for it in r.exceptions do
      IO.println s!"{label}: exception {it.name} (module {it.module}): {String.intercalate "; " it.reason.toList}"
    for it in r.violations do
      IO.eprintln s!"{label}: {it.name} is not under its module {it.module}"
  if r.violations.isEmpty then
    unless args.contains "--json" do
      IO.println s!"{label}: OK ({checked} declarations, {r.exceptions.size} exception(s))"
    return 0
  else
    unless args.contains "--json" do
      IO.eprintln s!"{label}: {r.violations.size} violation(s)"
    return 1

/--
道具の入口の本体。`groups` のモジュールの組ごとに環境を読み込み、`roots` の根のモジュールの全定数を判定する。
実行ファイルの入口のモジュールは、どれも `main` を持ち同時には読み込めないため、組を分ける。
組は 1 つずつ別のプロセスで判定する（同じ実行ファイルを `--layout-group <i>` で起動する。この引数は内部用）ので、
組を増やしても、メモリの最大は組 1 つ分のままである（時間は増える）。
`--json` なら結果を JSON（`{violations, exceptions, checked}`）で標準出力に出す。
違反があれば終了コード 1 を、組の判定が失敗すれば 2 を返す。
-/
unsafe def run (label : String) (groups : Array (Array Name)) (roots : List Name) (exclude : List Name)
    (args : List String) : IO UInt32 :=
  match args with
  | "--layout-group" :: i :: _ =>
    match i.toNat? with
    | some i => runGroup label groups roots exclude i
    | none => do
      IO.eprintln s!"{label}: invalid module group {i}"
      return 2
  | _ => runAll label groups args

end Trace.Layout
