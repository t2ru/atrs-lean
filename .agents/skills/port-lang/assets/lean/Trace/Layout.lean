import Trace.Dump

/-!
# Trace.Layout

`layout-check` の本体。宣言の完全名がモジュール名の下にあること（NS-1）を、環境の全定数について確かめる
（port-lang の `lang/lean/rules.md#モジュールと名前空間`）。

宣言 `n` のモジュールを `M` とする。`n = M` か、`n` が `M.` で始まれば合格とする。例外は次の 3 つだけである。

- **E1 型の名前空間（ドット記法）**: `n` が型（帰納型・構造体・クラス）`T` の下にあり、`T` を定義するモジュールが
  `M` の真の祖先である（型のモジュールの下位モジュールが、ドット記法で使う補題を型の名前空間に足す）。
  例: モジュール `LangSemantics.Java.JDouble.Lemmas` の `LangSemantics.Java.JDouble.pow2_eq`。
- **E2 実行ファイルの入口**: ルートの `main`。
- **E3 明示した例外**: `n` 自身か、その接頭辞の定数に `@[ns_exception "<理由>"]` が付いている。
- **E4 型名のモジュールのインスタンス**: `M` 自身が `M` で定義された型（型名のモジュール）で、`n` が `M` の親の名前空間に
  直接置かれたインスタンスか、その下の補助の定数である（`deriving` などが、型の外の名前空間に `instReprT` と名付けるため）。

自動生成の補助定数（`Trace.Dump.isHidden`）は対象にしない。`private` の名前も対象にしない。
-/

namespace Trace.Layout
open Trace.Attr

open Lean

/-- 違反、または明示した例外の 1 件。 -/
structure Item where
  name : Name
  module : Name
  /-- 明示した例外の理由（違反では空）。 -/
  reason : Array String := #[]

/-- 判定の結果。 -/
structure Result where
  violations : Array Item := #[]
  exceptions : Array Item := #[]
  /-- 検査した定数の数。 -/
  checked : Nat := 0

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

/-- `n` 自身か、その祖先の定数に付いた `@[ns_exception]` の理由。 -/
def exceptionOf (env : Environment) (n : Name) : Option (Array String) :=
  (n :: ancestors n).findSome? (nsExceptionAttr.getParam? env ·)

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
    if placedOk env m n then continue
    match exceptionOf env n with
    | some why => r := { r with exceptions := r.exceptions.push { name := n, module := m, reason := why } }
    | none => r := { r with violations := r.violations.push { name := n, module := m } }
  return r

/-- 1 件を JSON にする。 -/
def Item.toJson (i : Item) : Json :=
  Json.mkObj [("name", Lean.toJson i.name.toString), ("module", Lean.toJson i.module.toString),
    ("reason", Lean.toJson i.reason)]

/-- 2 つの結果を合わせる（同じ名前は 1 度だけ数える）。 -/
def Result.merge (a b : Result) : Result :=
  let seen : NameSet := (a.violations ++ a.exceptions).foldl (fun s i => s.insert i.name) {}
  let fresh (xs : Array Item) := xs.filter (!seen.contains ·.name)
  { violations := a.violations ++ fresh b.violations, exceptions := a.exceptions ++ fresh b.exceptions,
    checked := a.checked + b.checked }

/--
道具の入口の本体。`groups` のモジュールの組ごとに環境を読み込み、`roots` の根のモジュールの全定数を判定する。
実行ファイルの入口のモジュールは、どれも `main` を持ち同時には読み込めないため、組を分ける。
`--json` なら結果を JSON（`{violations, exceptions, checked}`）で標準出力に出す。
違反があれば終了コード 1 を返す。
-/
unsafe def run (label : String) (groups : Array (Array Name)) (roots : List Name) (exclude : List Name)
    (args : List String) : IO UInt32 := do
  let mut r : Result := {}
  let mut done : List Name := exclude
  for g in groups do
    let env ← Trace.Dump.loadEnv g
    let r' := check env roots done
    r := r.merge r'
    -- 検査済みのモジュールは次の組で数えない
    done := done ++ env.header.moduleNames.toList.filter fun m => roots.any (·.isPrefixOf m)
  -- 同じモジュールで祖先も違反（または例外）の名前は、祖先の 1 件にまとめる（構築子・射影・自動生成の補題など）
  let heads : NameMap Name := (r.violations ++ r.exceptions).foldl (fun s i => s.insert i.name i.module) {}
  let top (xs : Array Item) := xs.filter fun i => !(ancestors i.name).any (heads.find? · == some i.module)
  r := { r with violations := top r.violations, exceptions := top r.exceptions }
  if args.contains "--json" then
    IO.println (Json.mkObj [("violations", Json.arr (r.violations.map (·.toJson))),
      ("exceptions", Json.arr (r.exceptions.map (·.toJson))), ("checked", Lean.toJson r.checked)]).pretty
  else
    for i in r.exceptions do
      IO.println s!"{label}: exception {i.name} (module {i.module}): {String.intercalate "; " i.reason.toList}"
    for i in r.violations do
      IO.eprintln s!"{label}: {i.name} is not under its module {i.module}"
  if r.violations.isEmpty then
    unless args.contains "--json" do
      IO.println s!"{label}: OK ({r.checked} declarations, {r.exceptions.size} exception(s))"
    return 0
  else
    unless args.contains "--json" do
      IO.eprintln s!"{label}: {r.violations.size} violation(s)"
    return 1

end Trace.Layout
