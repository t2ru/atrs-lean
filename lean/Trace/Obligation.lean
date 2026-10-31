import Trace.Dump

/-!
# Trace.Obligation

`lake exe obligation-check` の本体。リファインメントの主定理（R 課題）が、空虚化を防ぐ形と付帯の義務を
備えているかを、環境を走査して判定する（TR-G。ADR 0039）。`Machine` の定数は名前で照合し、import しない。

R 課題は、型の結論が `Machine.Refines` の `@[obligation]` 定理である。各 R 課題について次を判定する。
付帯の定理は、`@[reducible]` を展開した式が一致するもので探す（先頭の定数だけでは照合しない）。

| 規則 | 内容 |
| --- | --- |
| G0 | 追跡属性を付けた定数はモデルの層にある。`Machine.Refines` を含む `@[obligation]` の型は、結論が `Refines` か、必要性の形（G9）である |
| G1 | 型が閉じている（∀ の仮定が無い。差異は `restrict` の述語として型の中に置く） |
| G2 | 抽象機械・具体機械は、名前付きの基底に `.restrict p`・`.restrictState p` を連ねた形で、`p` は `@[deviation]` の定数そのもの |
| G3 | 抽象側の基底は `Machine.ofChoice` か `Machine.pure`。選択の型の葉は `@[nondet]` か `Unit`。自由な選択があれば `FreeFrame` がある |
| G4 | 具体側の基底は `Concrete.ofFun`・`Concrete.pure`、または `Dom` を既定（全体）にした構造体で、`toConcrete` と `Spec` の関数を参照しない |
| G5 | 貼り合わせは `Glue.ofStd`。β・ai・ao は `@[std_abs]` の定数そのもの、OJ・OO は `never` か、`@[deviation]` の定数そのもの（`Machine.anyOf` で並べてよい） |
| G6 | 付帯の定理: `InitSurj`、基底の `Sound`・`InitIs`、基底が `ofChoice` なら `Pinned`（同じ `f`、`ce` は `@[std_abs]`）と `NoFaultReachable`（同じ `ce`・`e₀`） |

あわせて、環境全体について次を判定する。

| 規則 | 内容 |
| --- | --- |
| G3' | `Spec` の層の抽象機械の定義は、すべて `ofChoice` か `pure` で作る（SPEC-005） |
| G7 | `@[std_abs]` は 1 引数の関数で、葉（`KernelIs` の定理があり、K は `Eq` か `@[kernel]` の定数）か、許可した構成だけからなる合成。ao と `FreeFrame` の射影は葉でなければならない |
| G8 | `@[deviation]`・`@[env_pre]` の各定数に `Nontrivial`・`Nontrivial₂` の定理がある |
| G9 | 成分の必要性（ADR 0043）。下の 3 つ |

G9 の内容は次のとおりである。

- `@[deviation]` の定数は ID を 1 つだけ持つ（複数の差異を 1 つの定数に束ねない。観測型は `Machine.anyOf` で並べる）。
- R 課題で使う各差異 ID について、その ID のどれかの定数が、少なくとも 1 つの R 課題で次のどちらかを満たす。
  - 必要性: 差異を外した R 課題の命題の否定の閉じた定理（`¬ P` か `P → False`。`@[obligation]` の W 課題でもよい）がある
    - 前提型の差異 `d`: R 課題の機械から `.restrict d`・`.restrictState d`・`Concrete.restrict d` の層を 1 つ外す
    - 観測型の差異 `d`: R 課題の `Glue.ofStd` の OJ・OO（`anyOf` の葉）のうち `d` を `Machine.never` に替える
    - 否定する命題: `¬ Refines A C g`。抽象側の基底が `ofChoice` なら `¬ (Refines A C g ∧ Pinned A C g f ce)` でもよい
      （`f` は基底の `f`、`ce` は R 課題の `Pinned` の `ce`）
  - 被覆: 必要性か被覆を満たす差異 `M` と同じ R 課題の制限に現れ、`Covers M d`・`Covers₂ M d` の定理がある
- R 課題の基底について `TotalUnder A Env` を示した各 `@[env_pre]` の `Env` について、その基底の `¬ TotalUnder A always` がある
  （PRE が全域なら、環境の前提を置かず `TotalUnder A always` を示す）

入口の全域性（`TotalUnder`・`EnvWitness`）と出力のみの差異の `StateSafe` は、R 課題ごとに事実として出力し、
文書（入口の R 課題、前提型の差異の影響）との突き合わせは `tools/ci/check_obligations.py` が行う（TR-N）。
-/

namespace Trace.Obligation

open Lean

-- `Machine` の定数の名前。
namespace N
def refines : Name := `Machine.Refines
def restrict : Name := `Machine.Machine.restrict
def restrictState : Name := `Machine.Machine.restrictState
def cRestrict : Name := `Machine.Concrete.restrict
def ofChoice : Name := `Machine.Machine.ofChoice
def pure : Name := `Machine.Machine.pure
def toConcrete : Name := `Machine.Machine.toConcrete
def cOfFun : Name := `Machine.Concrete.ofFun
def cPure : Name := `Machine.Concrete.pure
def cMk : Name := `Machine.Concrete.mk
def machine : Name := `Machine.Machine
def ofStd : Name := `Machine.Glue.ofStd
def never : Name := `Machine.never
def initSurj : Name := `Machine.Refines.InitSurj
def pinned : Name := `Machine.Refines.Pinned
def noFault : Name := `Machine.Refines.NoFaultReachable
def envWitness : Name := `Machine.Refines.EnvWitness
def stateSafe : Name := `Machine.Refines.StateSafe
def stateSafeC : Name := `Machine.Refines.StateSafeConcrete
def totalUnder : Name := `Machine.Machine.TotalUnder
def sound : Name := `Machine.Machine.Sound
def initIs : Name := `Machine.Machine.InitIs
def freeFrame : Name := `Machine.Machine.FreeFrame
def nontrivial : Name := `Machine.Nontrivial
def nontrivial₂ : Name := `Machine.Nontrivial₂
def kernelIs : Name := `Machine.KernelIs
def always : Name := `Machine.always
def anyOf : Name := `Machine.anyOf
def covers : Name := `Machine.Covers
def covers₂ : Name := `Machine.Covers₂
end N

/-- 合成の標準の抽象化が参照してよい関数（構成子・射影・インスタンス・型を除く）。分岐（`ite`・`match`）は含めない。 -/
def allowedCombinators : List Name :=
  [`Option.map, `Option.bind, `List.map, `List.mapM, `Prod.map, `Function.comp, `id]

/-- 走査の対象とする層の決め方。 -/
structure Scope where
  /-- 定数の層（`Trace.Dump.defaultLayerOf` と同じ規則）。`none` は層の外。 -/
  layerOf : Name → Option String

/-- モデルの層（`Machine`・`LangSemantics` を除く）にあるか。 -/
def Scope.isModel (sc : Scope) (n : Name) : Bool :=
  match sc.layerOf n with
  | some l => !(l == "Machine" || l.startsWith "LangSemantics")
  | none => false

/-- 既定の対象。 -/
def defaultScope : Scope := { layerOf := Trace.Dump.defaultLayerOf [] }

/-- mdata を除き、η 簡約した式。 -/
def clean (e : Expr) : Expr := e.consumeMData.eta

/-- η 簡約した式が定数そのもの（引数なし）なら、その名前。 -/
def bareConst? (e : Expr) : Option Name := (clean e).constName?

/-- 式の頭部の定数。 -/
def headConst? (e : Expr) : Option Name := (clean e).getAppFn.consumeMData.constName?

/-- 頭部が `@[reducible]` の定義なら展開する（最大 16 回）。 -/
def unfoldReducible (env : Environment) (e : Expr) : Expr := Id.run do
  let mut e := e.consumeMData
  for _ in [0:16] do
    let .const c us := e.getAppFn | return e
    unless getReducibilityStatusCore env c == .reducible do return e
    let some ci := env.find? c | return e
    unless ci.hasValue do return e
    e := (mkAppN (ci.instantiateValueLevelParams! us) e.getAppArgs).headBeta.consumeMData
  return e

/-- 式のすべての部分項で、頭部の `@[reducible]` を展開する（照合用の正規形）。 -/
partial def normalize (env : Environment) (e : Expr) : Expr :=
  e.replace fun sub =>
    match sub.getAppFn.consumeMData with
    | .const c _ =>
      if getReducibilityStatusCore env c == .reducible && (env.find? c).any (·.hasValue) then
        let u := unfoldReducible env sub
        if u == sub then none else some (normalize env u)
      else none
    | _ => none

/-- 定数の定義を 1 段展開する（値を引数に適用して β 簡約する）。定義でなければ `none`。 -/
def unfoldOnce? (env : Environment) (e : Expr) : Option Expr := do
  let .const c us := e.consumeMData.getAppFn | none
  let ci ← env.find? c
  guard ci.isDefinition
  return (mkAppN (ci.instantiateValueLevelParams! us) e.consumeMData.getAppArgs).headBeta.consumeMData

/-- 型の結論（∀ を除いたもの）と、∀ の数。 -/
def conclusion (t : Expr) : Expr × Nat :=
  go t 0
where
  go : Expr → Nat → Expr × Nat
    | .forallE _ _ b _, n => go b (n + 1)
    | .mdata _ e, n => go e n
    | e, n => (e, n)

/-- 定数に追跡属性が付いているか。 -/
def hasAttr (attr : ParametricAttribute (Array String)) (env : Environment) (n : Name) : Bool :=
  (attr.getParam? env n).isSome

/-- 型の形成子（型が `Sort` で終わる定数）か。 -/
def isTypeFormer (ci : ConstantInfo) : Bool :=
  match (conclusion ci.type).1 with
  | .sort _ => true
  | _ => false

/-- 定数が定義されたモジュールの先頭の成分。 -/
def moduleRoot? (env : Environment) (n : Name) : Option Name := do
  let idx ← env.getModuleIdxFor? n
  let m ← env.header.moduleNames[idx.toNat]?
  return m.getRoot

/-- 枠組み・標準ライブラリのモジュール（参照の閉包をたどらない）。 -/
def libraryRoots : List Name := [`Init, `Std, `Lean, `Lake, `Batteries, `Machine, `LangSemantics]

/-- 計算の中身を持たない、参照してよい定数か（型・構成子・射影・インスタンス・再帰子・matcher・定理）。 -/
def isStructural (env : Environment) (n : Name) (ci : ConstantInfo) : Bool :=
  isTypeFormer ci || ci.isCtor || ci.isInductive || ci.isTheorem || env.isProjectionFn n ||
    Meta.isInstanceCore env n || isAuxRecursor env n || Meta.isMatcherCore env n ||
    (match ci with | .recInfo _ => true | _ => false)

/-- 定数の値から参照をたどった閉包（枠組み・標準ライブラリのモジュールは除く）。 -/
partial def closure (env : Environment) (start : Name) : Array Name := Id.run do
  let mut seen : NameSet := {}
  let mut stack := #[start]
  let mut out := #[]
  while h : stack.size > 0 do
    let n := stack[stack.size - 1]
    stack := stack.pop
    if seen.contains n then continue
    seen := seen.insert n
    if (moduleRoot? env n).any libraryRoots.contains then
      if n != start then out := out.push n
      continue
    out := out.push n
    let some ci := env.find? n | continue
    let es := match ci.value? (allowOpaque := true) with
      | some v => #[ci.type, v]
      | none => #[ci.type]
    for e in es do
      for c in e.getUsedConstants do
        unless seen.contains c do stack := stack.push c
  return out

/-- 1 つの R 課題の判定結果。 -/
structure RInfo where
  name : Name
  ids : Array String
  absBase : Option Name := none
  absKind : String := "?"
  conBase : Option Name := none
  devs : Array Name := #[]
  obs : Array Name := #[]
  stdAbs : Array Name := #[]
  envLeaves : Array Name := #[]
  freeLeaves : Array Name := #[]
  hasInitSurj : Bool := false
  hasSound : Bool := false
  hasInitIs : Bool := false
  hasPinned : Bool := false
  hasNoFault : Bool := false
  hasFreeFrame : Bool := false
  /-- 抽象側の基底についての `TotalUnder` の環境の前提と、その `EnvWitness` の有無 -/
  totalUnder : Array (Name × Bool) := #[]
  /-- `StateSafe`・`StateSafeConcrete` の定理がある差異の述語 -/
  stateSafe : Array Name := #[]
  /-- 必要性の定理（G9）がある差異 -/
  necessity : Array Name := #[]
  /-- 抽象側の基底に `¬ TotalUnder A always` があるか -/
  envNecessary : Bool := false
  errors : Array String := #[]

/-- 付帯の定理の一覧（引数は正規形）。 -/
structure Companions where
  /-- `InitSurj A C g` の (A, C, g) -/
  initSurj : Array (Expr × Expr × Expr) := #[]
  /-- `Pinned A C g f ce` の (A, C, g, f, ce) -/
  pinned : Array (Expr × Expr × Expr × Expr × Expr) := #[]
  /-- `NoFaultReachable C g ce e₀` の (C, g, ce, e₀) -/
  noFault : Array (Expr × Expr × Expr × Expr) := #[]
  /-- `EnvWitness C g Env` の (C, g, Env) -/
  envWitness : Array (Expr × Expr × Expr) := #[]
  /-- `TotalUnder A Env` の (A, Env) -/
  totalUnder : Array (Expr × Expr) := #[]
  /-- `StateSafe`・`StateSafeConcrete A C g P` の (A, C, g, P) -/
  stateSafe : Array (Expr × Expr × Expr × Expr) := #[]
  /-- `Sound A` の A -/
  sound : Array Expr := #[]
  /-- `InitIs A s₀` の A -/
  initIs : Array Expr := #[]
  /-- `FreeFrame f m` の (f, m) -/
  freeFrame : Array (Expr × Expr) := #[]
  /-- `Nontrivial`・`Nontrivial₂` の述語の定数 -/
  nontrivial : Array Name := #[]
  /-- `KernelIs f K` の f の定数で、K が `Eq` か `@[kernel]` の定数であるもの -/
  kernel : Array Name := #[]
  /-- 必要性の定理（G9）の (A, C, g, `Pinned` の (f, ce)) -/
  necessity : Array (Expr × Expr × Expr × Option (Expr × Expr)) := #[]
  /-- `¬ TotalUnder A always` の A -/
  envNecessity : Array Expr := #[]
  /-- `Covers M d`・`Covers₂ M d` の (M, d) -/
  covers : Array (Name × Name) := #[]

/-- 走査全体の結果。 -/
structure Report where
  rs : Array RInfo
  obligations : Array (Name × Array String × Bool)
  nondets : Array (Name × Array String)
  deviations : Array (Name × Array String)
  stdAbs : Array (Name × Array String)
  envPres : Array (Name × Array String)
  errors : Array String

/-- `.restrict p`・`.restrictState p` の連鎖をはがし、基底と述語を返す。 -/
partial def peelRestrict (env : Environment) (names : List Name) (e : Expr) : Expr × Array Expr :=
  let e := unfoldReducible env e
  match e.getAppFn.constName? with
  | some c =>
    if names.contains c then
      let args := e.getAppArgs
      let (b, ps) := peelRestrict env names args[args.size - 2]!
      (b, ps.push args[args.size - 1]!)
    else (e, #[])
  | none => (e, #[])

/-- `.restrict p`・`.restrictState p` の連鎖から、述語が `p` の層を 1 つ外した式を返す。 -/
partial def dropRestrict (env : Environment) (names : List Name) (p : Expr) (e : Expr) : Option Expr :=
  let e := unfoldReducible env e
  match e.getAppFn.constName? with
  | some c =>
    if names.contains c then
      let args := e.getAppArgs
      let inner := args[args.size - 2]!
      if args[args.size - 1]! == p then some inner
      else (dropRestrict env names p inner).map fun i => mkAppN e.getAppFn (args.set! (args.size - 2) i)
    else none
  | none => none

/-- 型が `¬ X` か `X → False` なら X を返す。 -/
def negated? (env : Environment) (ty : Expr) : Option Expr :=
  let ty := unfoldReducible env ty.consumeMData
  if ty.isAppOfArity ``Not 1 then some (unfoldReducible env ty.appArg!)
  else match ty with
    | .forallE _ d b _ =>
      if !b.hasLooseBVars && b.consumeMData.isConstOf ``False then some (unfoldReducible env d) else none
    | _ => none

/-- `anyOf` の木の葉（OJ・OO の各成分）。 -/
partial def anyOfLeaves (e : Expr) : Array Expr :=
  let e := clean e
  if e.isAppOfArity N.anyOf 4 then anyOfLeaves e.appFn!.appArg! ++ anyOfLeaves e.appArg! else #[e]

/-- 型が必要性の形（`¬ Refines A C g` か `¬ (Refines A C g ∧ Pinned A C g f ce)`。`→ False` でもよい）なら、正規形の
(A, C, g, (f, ce)) を返す（G9）。 -/
def necessityForm? (env : Environment) (ty : Expr) : Option (Expr × Expr × Expr × Option (Expr × Expr)) := do
  let x ← negated? env ty
  let nz := normalize env
  if x.isAppOfArity N.refines 10 then
    let a := x.getAppArgs
    return (nz a[7]!, nz a[8]!, nz a[9]!, none)
  guard (x.isAppOfArity ``And 2)
  let l := unfoldReducible env x.appFn!.appArg!
  let r := unfoldReducible env x.appArg!
  guard (l.isAppOfArity N.refines 10 && r.isAppOfArity N.pinned 14)
  let la := l.getAppArgs
  let ra := r.getAppArgs
  let (a, c, g) := (nz la[7]!, nz la[8]!, nz la[9]!)
  guard (nz ra[9]! == a && nz ra[10]! == c && nz ra[11]! == g)
  return (a, c, g, some (nz ra[12]!, nz ra[13]!))

/-- 型が `¬ TotalUnder A always` なら、正規形の A を返す（G9）。 -/
def envNecessityForm? (env : Environment) (ty : Expr) : Option Expr := do
  let x ← negated? env ty
  guard (x.isAppOfArity N.totalUnder 5)
  let a := x.getAppArgs
  guard (headConst? a[4]! == some N.always && (clean a[4]!).getAppNumArgs == 1)
  return normalize env a[3]!

/-- 利用側の定義を、頭部が `targets` のどれかになるまで展開する（最大 8 回）。 -/
def unfoldTo (env : Environment) (targets : List Name) (e : Expr) : Option Expr := Id.run do
  let mut e := e.consumeMData
  for _ in [0:8] do
    if let some c := e.getAppFn.constName? then
      if targets.contains c then return some e
    match unfoldOnce? env e with
    | some e' => e := e'
    | none => return none
  return none

/-- 選択の型を `Prod` で分解した葉。 -/
partial def prodLeaves (e : Expr) : Array Expr :=
  let e := e.consumeMData
  if e.isAppOfArity ``Prod 2 then prodLeaves e.appFn!.appArg! ++ prodLeaves e.appArg!
  else #[e]

/-- 付帯の定理を集める。 -/
def collectCompanions (env : Environment) : Companions := Id.run do
  let mut cs : Companions := {}
  let nz := normalize env
  for (_, ci) in env.constants.toList do
    let .thmInfo _ := ci | continue
    if let some nf := necessityForm? env ci.type then
      cs := { cs with necessity := cs.necessity.push nf }
      continue
    if let some a := envNecessityForm? env ci.type then
      cs := { cs with envNecessity := cs.envNecessity.push a }
      continue
    let (concl, nForall) := conclusion ci.type
    unless nForall == 0 do continue
    let some h := concl.getAppFn.constName? | continue
    let a := concl.getAppArgs
    if h == N.initSurj && a.size == 10 then
      cs := { cs with initSurj := cs.initSurj.push (nz a[7]!, nz a[8]!, nz a[9]!) }
    else if h == N.pinned && a.size == 14 then
      cs := { cs with pinned := cs.pinned.push (nz a[9]!, nz a[10]!, nz a[11]!, nz a[12]!, nz a[13]!) }
    else if h == N.noFault && a.size == 12 then
      cs := { cs with noFault := cs.noFault.push (nz a[8]!, nz a[9]!, nz a[10]!, nz a[11]!) }
    else if h == N.envWitness && a.size == 10 then
      cs := { cs with envWitness := cs.envWitness.push (nz a[7]!, nz a[8]!, nz a[9]!) }
    else if h == N.totalUnder && a.size == 5 then
      cs := { cs with totalUnder := cs.totalUnder.push (nz a[3]!, nz a[4]!) }
    else if (h == N.stateSafe || h == N.stateSafeC) && a.size == 11 then
      cs := { cs with stateSafe := cs.stateSafe.push (nz a[7]!, nz a[8]!, nz a[9]!, nz a[10]!) }
    else if h == N.sound && a.size == 4 then
      cs := { cs with sound := cs.sound.push (nz a[3]!) }
    else if h == N.initIs && a.size == 5 then
      cs := { cs with initIs := cs.initIs.push (nz a[3]!) }
    else if h == N.freeFrame && a.size == 8 then
      cs := { cs with freeFrame := cs.freeFrame.push (nz a[6]!, nz a[7]!) }
    else if h == N.nontrivial && a.size == 2 then
      if let some pc := bareConst? a[1]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if h == N.nontrivial₂ && a.size == 3 then
      if let some pc := bareConst? a[2]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if (h == N.covers && a.size == 3) || (h == N.covers₂ && a.size == 4) then
      if let (some m, some d) := (bareConst? a[a.size - 2]!, bareConst? a[a.size - 1]!) then
        cs := { cs with covers := cs.covers.push (m, d) }
    else if h == N.kernelIs && a.size == 4 then
      if let some fc := bareConst? a[2]! then
        let k := clean a[3]!
        let ok := k.isAppOfArity ``Eq 1 || (k.constName?.any (hasAttr kernelAttr env ·))
        if ok then cs := { cs with kernel := cs.kernel.push fc }
  return cs

/-- 1 つの R 課題を判定する。 -/
def checkR (env : Environment) (sc : Scope) (cs : Companions) (name : Name) (ids : Array String)
    (ty : Expr) : RInfo := Id.run do
  let mut r : RInfo := { name, ids }
  let nz := normalize env
  let (concl, nForall) := conclusion ty
  let concl := unfoldReducible env concl
  if nForall > 0 then
    r := { r with errors := r.errors.push "G1: the type has hypotheses (∀); state deviations with restrict" }
  let args := concl.getAppArgs
  let a := nz args[args.size - 3]!
  let c := nz args[args.size - 2]!
  let g := nz args[args.size - 1]!
  -- G2: 制限の述語と基底
  let (aBase, aPs) := peelRestrict env [N.restrict, N.restrictState] a
  let (cBase, cPs) := peelRestrict env [N.cRestrict] c
  for p in aPs ++ cPs do
    match bareConst? p with
    | some pc =>
      if hasAttr deviationAttr env pc then r := { r with devs := r.devs.push pc }
      else r := { r with errors := r.errors.push s!"G2: restrict predicate {pc} has no @[deviation]" }
    | none => r := { r with errors := r.errors.push "G2: restrict predicate is not a bare @[deviation] constant" }
  r := { r with absBase := headConst? aBase, conBase := headConst? cBase }
  for (label, b) in [("abstract", aBase), ("concrete", cBase)] do
    match headConst? b with
    | some bc =>
      if !sc.isModel bc then
        r := { r with errors := r.errors.push s!"G2: {label} base {bc} is not a named constant of a model layer" }
    | none => r := { r with errors := r.errors.push s!"G2: {label} base is not a named constant" }
  -- G3: 抽象側の基底
  let mut choice : Option (Expr × Expr) := none
  let mut pinCes : Array Expr := #[]
  match unfoldTo env [N.ofChoice, N.pure] aBase with
  | some v =>
    if v.getAppFn.constName? == some N.pure then r := { r with absKind := "pure" }
    else
      r := { r with absKind := "ofChoice" }
      let vs := v.getAppArgs
      choice := some (nz vs[8]!, nz vs[9]!)
      for (isEnv, ty) in [(true, vs[3]!), (false, vs[4]!)] do
        for leaf in prodLeaves ty do
          match bareConst? leaf with
          | some lc =>
            if lc == ``Unit || lc == ``PUnit then pure ()
            else if hasAttr nondetAttr env lc then
              if isEnv then r := { r with envLeaves := r.envLeaves.push lc }
              else r := { r with freeLeaves := r.freeLeaves.push lc }
            else r := { r with errors := r.errors.push s!"G3: choice type {lc} has no @[nondet]" }
          | none => r := { r with errors := r.errors.push "G3: choice type is not a bare named type" }
  | none =>
    r := { r with errors := r.errors.push "G3: abstract base is not built with Machine.ofChoice or Machine.pure" }
  -- G4: 具体側の基底
  match unfoldTo env [N.cOfFun, N.cPure, N.cMk] cBase with
  | some v =>
    if v.getAppFn.constName? == some N.cMk then
      let dom := v.getAppArgs[5]!.consumeMData
      let ok := match dom with
        | .lam _ _ b _ => b.consumeMData.isConstOf ``True
        | _ => false
      unless ok do
        r := { r with errors := r.errors.push "G4: concrete base sets Dom; restrict it with Concrete.restrict and a @[deviation]" }
  | none =>
    r := { r with errors := r.errors.push "G4: concrete base is not built with Concrete.ofFun, Concrete.pure or a structure" }
  if let some cb := headConst? cBase then
    for n in closure env cb do
      if n == N.toConcrete then
        r := { r with errors := r.errors.push "G4: concrete base uses Machine.toConcrete" }
      else if sc.layerOf n == some "Spec" then
        if let some ci := env.find? n then
          unless isStructural env n ci do
            r := { r with errors := r.errors.push s!"G4: concrete base uses the Spec function {n}" }
  -- G5: 貼り合わせ
  if g.isAppOfArity N.ofStd 12 then
    let gs := g.getAppArgs
    for (label, e) in [("β", gs[6]!), ("ai", gs[8]!), ("ao", gs[9]!)] do
      match bareConst? e with
      | some sc' =>
        if hasAttr stdAbsAttr env sc' then
          unless r.stdAbs.contains sc' do r := { r with stdAbs := r.stdAbs.push sc' }
          if label == "ao" && !cs.kernel.contains sc' then
            r := { r with errors := r.errors.push s!"G7: ao = {sc'} has no KernelIs theorem" }
        else r := { r with errors := r.errors.push s!"G5: {label} = {sc'} has no @[std_abs]" }
      | none => r := { r with errors := r.errors.push s!"G5: {label} is not a bare @[std_abs] constant" }
    for (label, e) in [("OJ", gs[10]!), ("OO", gs[11]!)] do
      if headConst? e == some N.never && (clean e).getAppNumArgs == 2 then pure ()
      else for leaf in anyOfLeaves e do
        match bareConst? leaf with
        | some oc =>
          if hasAttr deviationAttr env oc then r := { r with obs := r.obs.push oc }
          else r := { r with errors := r.errors.push s!"G5: {label} = {oc} is neither Machine.never nor @[deviation]" }
        | none => r := { r with errors := r.errors.push s!"G5: {label} is not Machine.never or Machine.anyOf of bare @[deviation] constants" }
  else
    r := { r with errors := r.errors.push "G5: glue is not Machine.Glue.ofStd" }
  -- G6: 付帯の定理
  let hasInit := cs.initSurj.any fun (a', c', g') => a' == a && c' == c && g' == g
  let hasSound := cs.sound.any (· == aBase)
  let hasInitIs := cs.initIs.any (· == aBase)
  r := { r with hasInitSurj := hasInit, hasSound, hasInitIs }
  unless hasInit do r := { r with errors := r.errors.push "G6: no Refines.InitSurj theorem for this machine pair and glue" }
  unless hasSound do r := { r with errors := r.errors.push "G6: no Machine.Sound theorem for the abstract base" }
  unless hasInitIs do r := { r with errors := r.errors.push "G6: no Machine.InitIs theorem for the abstract base" }
  if let some (f, e₀) := choice then
    let ps := cs.pinned.filter fun (a', c', g', f', _) => a' == a && c' == c && g' == g && f' == f
    let mut pinnedOk := false
    let mut noFaultOk := false
    for (_, _, _, _, ce) in ps do
      match bareConst? ce with
      | some cc =>
        if hasAttr stdAbsAttr env cc then
          pinnedOk := true
          pinCes := pinCes.push ce
          if cs.noFault.any (fun (c', g', ce', e') => c' == c && g' == g && ce' == ce && e' == e₀) then
            noFaultOk := true
        else r := { r with errors := r.errors.push s!"G6: ce = {cc} of Refines.Pinned has no @[std_abs]" }
      | none => r := { r with errors := r.errors.push "G6: ce of Refines.Pinned is not a bare @[std_abs] constant" }
    r := { r with hasPinned := pinnedOk, hasNoFault := noFaultOk }
    unless pinnedOk do
      r := { r with errors := r.errors.push "G6: no Refines.Pinned theorem with the f of Machine.ofChoice" }
    if pinnedOk && !noFaultOk then
      r := { r with errors := r.errors.push "G6: no Refines.NoFaultReachable theorem with the ce of Refines.Pinned and e₀" }
    unless r.freeLeaves.isEmpty do
      let fr := cs.freeFrame.filter fun (f', _) => f' == f
      let ok := fr.any fun (_, m) => (bareConst? m).any fun mc => cs.kernel.contains mc
      r := { r with hasFreeFrame := ok }
      unless ok do
        r := { r with errors := r.errors.push "G3: free choices without a FreeFrame theorem whose projection has KernelIs" }
  -- G9: 成分の必要性（どの R 課題にも無い成分の誤りは、全体の判定で出す）
  let pinOk (pin : Option (Expr × Expr)) : Bool :=
    match choice, pin with
    | some (f, _), some (f', ce') => f' == f && pinCes.contains ce'
    | some _, none => true
    | none, none => r.absKind == "pure"
    | none, some _ => false
  let found (a' c' g' : Expr) : Bool :=
    cs.necessity.any fun (a'', c'', g'', pin) => a'' == a' && c'' == c' && g'' == g' && pinOk pin
  for p in aPs ++ cPs do
    if let some pc := bareConst? p then
      if r.devs.contains pc && !r.necessity.contains pc then
        let a' := (dropRestrict env [N.restrict, N.restrictState] p a).getD a
        let c' := (dropRestrict env [N.cRestrict] p c).getD c
        if found a' c' g then r := { r with necessity := r.necessity.push pc }
  if g.isAppOfArity N.ofStd 12 then
    let gs := g.getAppArgs
    -- OJ : σ → τ → Prop、OO : οc → οa → Prop（`ofStd` の型引数は σ τ ιa ιc οa οc の順）
    for (k, ty₁, ty₂) in [(10, gs[0]!, gs[1]!), (11, gs[5]!, gs[4]!)] do
      for leaf in anyOfLeaves gs[k]! do
        if let some oc := bareConst? leaf then
          if r.obs.contains oc && !r.necessity.contains oc then
            let nev := mkApp2 (mkConst N.never) ty₁ ty₂
            let slot := gs[k]!.replace fun sub => if bareConst? sub == some oc then some nev else none
            let g' := mkAppN g.getAppFn (gs.set! k slot)
            if found a c g' then r := { r with necessity := r.necessity.push oc }
  -- 入口の全域性と状態の安全性（事実として出す）
  r := { r with envNecessary := cs.envNecessity.contains aBase }
  for (a', env') in cs.totalUnder do
    if a' == aBase then
      let w := cs.envWitness.any fun (c', g', e') => c' == c && g' == g && e' == env'
      if headConst? env' == some N.always && (clean env').getAppNumArgs == 1 then
        r := { r with totalUnder := r.totalUnder.push (N.always, w) }
      else match bareConst? env' with
        | some ec =>
          if hasAttr envPreAttr env ec then r := { r with totalUnder := r.totalUnder.push (ec, w) }
        | none => pure ()
  for (a', c', g', p) in cs.stateSafe do
    if a' == aBase && c' == cBase && g' == g then
      if let some pc := bareConst? p then
        if r.devs.contains pc then r := { r with stateSafe := r.stateSafe.push pc }
  return r

/-- 合成の標準の抽象化（G7）の参照が許可した構成に収まるか。収まらない参照を返す。 -/
def disallowedRefs (env : Environment) (n : Name) : Array Name := Id.run do
  let some ci := env.find? n | return #[]
  let some v := ci.value? | return #[]
  let mut bad := #[]
  for c in v.getUsedConstants do
    let some cci := env.find? c | continue
    let ok := hasAttr stdAbsAttr env c || cci.isCtor || env.isProjectionFn c ||
      Meta.isInstanceCore env c || allowedCombinators.contains c || isTypeFormer cci
    unless ok do bad := bad.push c
  return bad

/-- `@[std_abs]` の型が、1 引数の関数（引数も値も関数でない）か。 -/
def isUnaryFun (ty : Expr) : Bool :=
  match ty.consumeMData with
  | .forallE _ d b bi => bi.isExplicit && !b.hasLooseBVars && !d.consumeMData.isForall &&
      !b.consumeMData.isForall
  | _ => false

/-- 環境を走査する。 -/
def check (env : Environment) (sc : Scope := defaultScope) : Report := Id.run do
  let cs := collectCompanions env
  let mut rs := #[]
  let mut obligations := #[]
  let mut nondets := #[]
  let mut devs := #[]
  let mut stds := #[]
  let mut envPres := #[]
  let mut errors := #[]
  let consts := env.constants.toList.toArray.qsort fun a b => a.1.toString < b.1.toString
  for (n, ci) in consts do
    let attrs := [("nondet", nondetAttr), ("deviation", deviationAttr), ("std_abs", stdAbsAttr),
      ("kernel", kernelAttr), ("env_pre", envPreAttr), ("obligation", obligationAttr)]
    let mine := attrs.filter fun (_, attr) => hasAttr attr env n
    if !mine.isEmpty && !sc.isModel n then
      errors := errors.push s!"G0: {n} has @[{(mine.map (·.1))}] but is not in a model layer"
    if let some ids := nondetAttr.getParam? env n then nondets := nondets.push (n, ids)
    if let some ids := deviationAttr.getParam? env n then
      devs := devs.push (n, ids)
      if ids.size > 1 then
        errors := errors.push
          s!"G9: {n} (@[deviation]) has {ids.size} IDs {ids.toList}; give each deviation its own constant (Machine.anyOf for observational components)"
      unless cs.nontrivial.contains n do
        errors := errors.push s!"G8: {n} (@[deviation]) has no Nontrivial/Nontrivial₂ theorem"
    if let some ids := envPreAttr.getParam? env n then
      envPres := envPres.push (n, ids)
      unless cs.nontrivial.contains n do
        errors := errors.push s!"G8: {n} (@[env_pre]) has no Nontrivial theorem"
    if let some ids := stdAbsAttr.getParam? env n then
      stds := stds.push (n, ids)
      unless isUnaryFun ci.type do
        errors := errors.push s!"G7: {n} (@[std_abs]) is not a function of one non-function argument"
      unless cs.kernel.contains n do
        let bad := disallowedRefs env n
        unless bad.isEmpty do
          errors := errors.push
            s!"G7: {n} (@[std_abs]) has no KernelIs theorem and refers to {bad.toList}"
    -- G3': Spec の層の抽象機械
    if sc.layerOf n == some "Spec" && ci.isDefinition then
      if (conclusion ci.type).1.isAppOf N.machine then
        let mut v := ci.value!
        while v.isLambda do v := v.bindingBody!
        if (unfoldTo env [N.ofChoice, N.pure] (unfoldReducible env v)).isNone then
          errors := errors.push s!"G3: {n} (Spec machine) is not built with Machine.ofChoice or Machine.pure"
    if let some ids := obligationAttr.getParam? env n then
      if let .thmInfo _ := ci then
        let (concl, _) := conclusion ci.type
        let concl := unfoldReducible env concl
        let isR := concl.isAppOfArity N.refines 10
        obligations := obligations.push (n, ids, isR)
        if isR then rs := rs.push (checkR env sc cs n ids ci.type)
        else if (normalize env ci.type).getUsedConstants.contains N.refines &&
            (necessityForm? env ci.type).isNone then
          errors := errors.push s!"G0: {n} mentions Machine.Refines but its conclusion is not Refines"
  -- G9: 成分の必要性（差異 ID ごとに、少なくとも 1 つの R 課題について。被覆は必要な差異から広げる）
  let used := (rs.foldl (fun acc ri => acc ++ ri.devs ++ ri.obs) #[]).toList.eraseDups
  let mut needed := rs.foldl (fun acc ri => acc ++ ri.necessity) #[]
  for _ in [0:cs.covers.size] do
    for (m, d) in cs.covers do
      if needed.contains m && !needed.contains d &&
          rs.any (fun ri => ri.devs.contains m && ri.devs.contains d) then
        needed := needed.push d
  let idsOf (n : Name) : List String := ((deviationAttr.getParam? env n).getD #[]).toList
  let neededIds := needed.toList.flatMap idsOf
  for i in (used.flatMap idsOf).eraseDups do
    unless neededIds.contains i do
      let consts := used.filter fun d => (idsOf d).contains i
      errors := errors.push
        s!"G9: {i} (@[deviation] {consts}) has neither a necessity theorem (¬ of an R obligation without it) nor Covers by a needed deviation in any R obligation"
  for (e, _) in envPres do
    let bases := (rs.filter fun ri => ri.totalUnder.any (·.1 == e)).toList.map fun ri => (ri.absBase, ri.envNecessary)
    for (b, ok) in bases.eraseDups do
      unless ok do
        errors := errors.push
          s!"G9: {e} (@[env_pre]) is used for the abstract base {b} of an R obligation without a ¬ TotalUnder (base) always theorem (if PRE is total, state TotalUnder (base) always instead)"
  return { rs, obligations, nondets, deviations := devs, stdAbs := stds, envPres, errors }

/-- 誤りの総数。 -/
def Report.errorCount (r : Report) : Nat :=
  r.errors.size + r.rs.foldl (fun acc ri => acc + ri.errors.size) 0

/-- JSON に変換する。 -/
def Report.toJson (r : Report) : Json :=
  let names (xs : Array Name) := Lean.toJson (xs.map (·.toString))
  let attrd (xs : Array (Name × Array String)) :=
    Json.arr (xs.map fun (n, ids) => Json.mkObj [("name", Lean.toJson n.toString), ("ids", Lean.toJson ids)])
  let opt (x : Option Name) := match x with | some n => Lean.toJson n.toString | none => Json.null
  Json.mkObj [
    ("refinements", Json.arr (r.rs.map fun ri => Json.mkObj [
      ("name", Lean.toJson ri.name.toString), ("ids", Lean.toJson ri.ids),
      ("abstract_base", opt ri.absBase), ("abstract_kind", Lean.toJson ri.absKind),
      ("concrete_base", opt ri.conBase), ("deviations", names ri.devs), ("observations", names ri.obs),
      ("std_abs", names ri.stdAbs), ("env_choices", names ri.envLeaves), ("free_choices", names ri.freeLeaves),
      ("init_surj", Lean.toJson ri.hasInitSurj), ("sound", Lean.toJson ri.hasSound),
      ("init_is", Lean.toJson ri.hasInitIs), ("pinned", Lean.toJson ri.hasPinned),
      ("no_fault", Lean.toJson ri.hasNoFault), ("free_frame", Lean.toJson ri.hasFreeFrame),
      ("total_under", Json.arr (ri.totalUnder.map fun (e, w) =>
        Json.mkObj [("env", Lean.toJson e.toString), ("witness", Lean.toJson w)])),
      ("state_safe", names ri.stateSafe), ("necessity", names ri.necessity),
      ("errors", Lean.toJson ri.errors)])),
    ("obligations", Json.arr (r.obligations.map fun (n, ids, isR) => Json.mkObj [
      ("name", Lean.toJson n.toString), ("ids", Lean.toJson ids), ("refines", Lean.toJson isR)])),
    ("nondet", attrd r.nondets), ("deviation", attrd r.deviations), ("std_abs", attrd r.stdAbs),
    ("env_pre", attrd r.envPres), ("errors", Lean.toJson r.errors)]

end Trace.Obligation
