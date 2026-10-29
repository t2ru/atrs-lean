import Trace.Dump

/-!
# Trace.Obligation

`lake exe obligation-check` の本体。リファインメントの主定理（R 課題）が、空虚化を防ぐ形と付帯の義務を
備えているかを、環境を走査して判定する（TR-G。ADR 0038）。`Machine` の定数は名前で照合し、import しない。

R 課題は、型の結論が `Machine.Refines` の `@[obligation]` 定理である。各 R 課題について次を判定する。

| 規則 | 内容 |
| --- | --- |
| G1 | 型が閉じている（∀ の仮定が無い。差異は `restrict` の述語として型の中に置く） |
| G2 | 抽象機械・具体機械は、基底の定数に `.restrict p`・`.restrictState p` を連ねた形で、`p` は `@[deviation]` |
| G3 | 抽象側の基底は `Machine.ofChoice` か `Machine.pure`。選択の型の葉は `@[nondet]` か `Unit` |
| G4 | 具体側の基底は `Concrete.ofFun`・`Concrete.pure`、または `Dom` を既定（全体）にした構造体 |
| G5 | 貼り合わせは `Glue.ofStd`（展開は `@[reducible]` だけ）。β・ai・ao は `@[std_abs]`、OJ・OO は `never` か `@[deviation]` |
| G6 | 付帯の定理 `Refines.InitSurj` と、抽象側の基底が `ofChoice` なら `Refines.Pinned`（同じ `f`）がある |

あわせて、環境全体について次を判定する。

| 規則 | 内容 |
| --- | --- |
| G7 | `@[std_abs]` は、葉（`KernelIs` の定理があり、K がその定数を参照しない）か、許可した構成だけからなる合成 |
| G8 | `@[deviation]` の各定数に `Nontrivial`・`Nontrivial₂` の定理がある |

文書との突き合わせ（N-NNN と `@[nondet]` の対応、入口の `TotalUnder`、出力のみの差異の `StateSafe`）は、
出力する JSON を使って `tools/ci/check_obligations.py` が行う（TR-N）。
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
def cOfFun : Name := `Machine.Concrete.ofFun
def cPure : Name := `Machine.Concrete.pure
def cMk : Name := `Machine.Concrete.mk
def ofStd : Name := `Machine.Glue.ofStd
def never : Name := `Machine.never
def initSurj : Name := `Machine.Refines.InitSurj
def pinned : Name := `Machine.Refines.Pinned
def stateSafe : Name := `Machine.Refines.StateSafe
def stateSafeC : Name := `Machine.Refines.StateSafeConcrete
def totalUnder : Name := `Machine.Machine.TotalUnder
def nontrivial : Name := `Machine.Nontrivial
def nontrivial₂ : Name := `Machine.Nontrivial₂
def kernelIs : Name := `Machine.KernelIs
end N

/-- 合成の標準の抽象化が参照してよい関数（構成子・射影・型を除く）。分岐（`ite`・`match`）は含めない。 -/
def allowedCombinators : List Name :=
  [`Option.map, `Option.bind, `List.map, `Prod.map, `Function.comp, `id]

/-- mdata を除き、η 簡約した式の頭部の定数。 -/
def headConst? (e : Expr) : Option Name :=
  e.consumeMData.eta.getAppFn.consumeMData.constName?

/-- 定数の頭部に `@[reducible]` の定義があれば展開する（最大 16 回）。 -/
def unfoldReducible (env : Environment) (e : Expr) : Expr := Id.run do
  let mut e := e.consumeMData
  for _ in [0:16] do
    let .const c us := e.getAppFn | return e
    unless getReducibilityStatusCore env c == .reducible do return e
    let some ci := env.find? c | return e
    unless ci.hasValue do return e
    e := (mkAppN (ci.instantiateValueLevelParams! us) e.getAppArgs).headBeta.consumeMData
  return e

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
  nondets : Array Name := #[]
  hasInitSurj : Bool := false
  hasPinned : Bool := false
  errors : Array String := #[]

/-- 付帯の定理の一覧。 -/
structure Companions where
  /-- `InitSurj A C g` の (A, C, g) -/
  initSurj : Array (Expr × Expr × Expr) := #[]
  /-- `Pinned A C g f ce` の (A, C, g, f) -/
  pinned : Array (Expr × Expr × Expr × Expr) := #[]
  /-- `TotalUnder A Env` の A の基底の定数 -/
  totalUnder : Array Name := #[]
  /-- `StateSafe`・`StateSafeConcrete` の述語の頭部の定数 -/
  stateSafe : Array Name := #[]
  /-- `Nontrivial`・`Nontrivial₂` の述語の頭部の定数 -/
  nontrivial : Array Name := #[]
  /-- `KernelIs f K` の f の頭部の定数で、K が f を参照しないもの -/
  kernel : Array Name := #[]

/-- 走査全体の結果。 -/
structure Report where
  rs : Array RInfo
  nondets : Array (Name × Array String)
  deviations : Array (Name × Array String)
  stdAbs : Array (Name × Array String)
  totalUnder : Array Name
  stateSafe : Array Name
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

/-- 1 つの R 課題を判定する。 -/
def checkR (env : Environment) (cs : Companions) (name : Name) (ids : Array String) (ty : Expr) :
    RInfo := Id.run do
  let mut r : RInfo := { name, ids }
  let (concl, nForall) := conclusion ty
  if nForall > 0 then
    r := { r with errors := r.errors.push "G1: the type has hypotheses (∀); state deviations with restrict" }
  let args := concl.getAppArgs
  let a := args[args.size - 3]!
  let c := args[args.size - 2]!
  let g := args[args.size - 1]!
  -- G2: 制限の述語
  let (aBase, aPs) := peelRestrict env [N.restrict, N.restrictState] a
  let (cBase, cPs) := peelRestrict env [N.cRestrict] c
  for p in aPs ++ cPs do
    match headConst? p with
    | some pc =>
      if hasAttr deviationAttr env pc then r := { r with devs := r.devs.push pc }
      else r := { r with errors := r.errors.push s!"G2: restrict predicate {pc} has no @[deviation]" }
    | none => r := { r with errors := r.errors.push "G2: restrict predicate is not a named constant" }
  -- G3: 抽象側の基底
  r := { r with absBase := aBase.getAppFn.constName? }
  let mut choiceF : Option Expr := none
  match unfoldTo env [N.ofChoice, N.pure] aBase with
  | some v =>
    if v.getAppFn.constName? == some N.pure then r := { r with absKind := "pure" }
    else
      r := { r with absKind := "ofChoice" }
      let vs := v.getAppArgs
      choiceF := some vs[8]!
      for leaf in prodLeaves vs[3]! ++ prodLeaves vs[4]! do
        match headConst? leaf with
        | some lc =>
          if lc == ``Unit || lc == ``PUnit then pure ()
          else if hasAttr nondetAttr env lc then
            unless r.nondets.contains lc do r := { r with nondets := r.nondets.push lc }
          else r := { r with errors := r.errors.push s!"G3: choice type {lc} has no @[nondet]" }
        | none => r := { r with errors := r.errors.push "G3: choice type is not a named type" }
  | none =>
    r := { r with errors := r.errors.push "G3: abstract base is not built with Machine.ofChoice or Machine.pure" }
  -- G4: 具体側の基底
  r := { r with conBase := cBase.getAppFn.constName? }
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
  -- G5: 貼り合わせ
  let gv := unfoldReducible env g
  if gv.isAppOfArity N.ofStd 12 then
    let gs := gv.getAppArgs
    for (label, e) in [("β", gs[6]!), ("ai", gs[8]!), ("ao", gs[9]!)] do
      match headConst? e with
      | some sc =>
        if hasAttr stdAbsAttr env sc then
          unless r.stdAbs.contains sc do r := { r with stdAbs := r.stdAbs.push sc }
        else r := { r with errors := r.errors.push s!"G5: {label} = {sc} has no @[std_abs]" }
      | none => r := { r with errors := r.errors.push s!"G5: {label} is not a named constant" }
    for (label, e) in [("OJ", gs[10]!), ("OO", gs[11]!)] do
      match headConst? e with
      | some oc =>
        if oc == N.never then pure ()
        else if hasAttr deviationAttr env oc then r := { r with obs := r.obs.push oc }
        else r := { r with errors := r.errors.push s!"G5: {label} = {oc} is neither Machine.never nor @[deviation]" }
      | none => r := { r with errors := r.errors.push s!"G5: {label} is not a named constant" }
  else
    r := { r with errors := r.errors.push "G5: glue is not written as Machine.Glue.ofStd in the theorem type" }
  -- G6: 付帯の定理
  let hasInit := cs.initSurj.any fun (a', c', g') => a' == a && c' == c && g' == g
  r := { r with hasInitSurj := hasInit }
  unless hasInit do r := { r with errors := r.errors.push "G6: no Refines.InitSurj theorem for this machine pair and glue" }
  if let some f := choiceF then
    let hasP := cs.pinned.any fun (a', c', g', f') => a' == a && c' == c && g' == g && f' == f
    r := { r with hasPinned := hasP }
    unless hasP do
      r := { r with errors := r.errors.push "G6: no Refines.Pinned theorem with the f of Machine.ofChoice" }
  return r

/-- 付帯の定理を集める。 -/
def collectCompanions (env : Environment) (inScope : Name → Bool) : Companions := Id.run do
  let mut cs : Companions := {}
  for (n, ci) in env.constants.toList do
    unless inScope n do continue
    let .thmInfo _ := ci | continue
    let (concl, nForall) := conclusion ci.type
    unless nForall == 0 do continue
    let some h := concl.getAppFn.constName? | continue
    let args := concl.getAppArgs
    if h == N.initSurj && args.size == 10 then
      cs := { cs with initSurj := cs.initSurj.push (args[7]!, args[8]!, args[9]!) }
    else if h == N.pinned && args.size == 14 then
      cs := { cs with pinned := cs.pinned.push (args[9]!, args[10]!, args[11]!, args[12]!) }
    else if h == N.totalUnder && args.size == 5 then
      let (b, _) := peelRestrict env [N.restrict, N.restrictState] args[3]!
      if let some bc := b.getAppFn.constName? then cs := { cs with totalUnder := cs.totalUnder.push bc }
    else if (h == N.stateSafe || h == N.stateSafeC) && args.size == 11 then
      if let some pc := headConst? args[10]! then cs := { cs with stateSafe := cs.stateSafe.push pc }
    else if h == N.nontrivial && args.size == 2 then
      if let some pc := headConst? args[1]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if h == N.nontrivial₂ && args.size == 3 then
      if let some pc := headConst? args[2]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if h == N.kernelIs && args.size == 4 then
      if let some fc := headConst? args[2]! then
        unless args[3]!.getUsedConstants.contains fc do cs := { cs with kernel := cs.kernel.push fc }
  return cs

/-- 合成の標準の抽象化（G7）の参照が許可した構成に収まるか。収まらない参照を返す。 -/
def disallowedRefs (env : Environment) (n : Name) : Array Name := Id.run do
  let some ci := env.find? n | return #[]
  let some v := ci.value? | return #[]
  let mut bad := #[]
  for c in v.getUsedConstants do
    let some cci := env.find? c | continue
    let ok := hasAttr stdAbsAttr env c || cci.isCtor || env.isProjectionFn c ||
      allowedCombinators.contains c || isTypeFormer cci
    unless ok do bad := bad.push c
  return bad

/-- 環境を走査する。`inScope` は対象とする定数（モデルの層）を決める。 -/
def check (env : Environment) (inScope : Name → Bool) : Report := Id.run do
  let cs := collectCompanions env inScope
  let mut rs := #[]
  let mut nondets := #[]
  let mut devs := #[]
  let mut stds := #[]
  let mut errors := #[]
  let consts := env.constants.toList.filter (inScope ·.1) |>.toArray.qsort fun a b =>
    a.1.toString < b.1.toString
  for (n, ci) in consts do
    if let some ids := nondetAttr.getParam? env n then nondets := nondets.push (n, ids)
    if let some ids := deviationAttr.getParam? env n then
      devs := devs.push (n, ids)
      unless cs.nontrivial.contains n do
        errors := errors.push s!"G8: {n} (@[deviation]) has no Nontrivial/Nontrivial₂ theorem"
    if let some ids := stdAbsAttr.getParam? env n then
      stds := stds.push (n, ids)
      unless cs.kernel.contains n do
        let bad := disallowedRefs env n
        unless bad.isEmpty do
          errors := errors.push
            s!"G7: {n} (@[std_abs]) has no KernelIs theorem and refers to {bad.toList}"
    if let some ids := obligationAttr.getParam? env n then
      if let .thmInfo _ := ci then
        let (concl, _) := conclusion ci.type
        if concl.isAppOfArity N.refines 10 then rs := rs.push (checkR env cs n ids ci.type)
  return { rs, nondets, deviations := devs, stdAbs := stds, totalUnder := cs.totalUnder,
           stateSafe := cs.stateSafe, errors }

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
    ("obligations", Json.arr (r.rs.map fun ri => Json.mkObj [
      ("name", Lean.toJson ri.name.toString), ("ids", Lean.toJson ri.ids),
      ("abstract_base", opt ri.absBase), ("abstract_kind", Lean.toJson ri.absKind),
      ("concrete_base", opt ri.conBase), ("deviations", names ri.devs), ("observations", names ri.obs),
      ("std_abs", names ri.stdAbs), ("nondet", names ri.nondets),
      ("init_surj", Lean.toJson ri.hasInitSurj), ("pinned", Lean.toJson ri.hasPinned),
      ("errors", Lean.toJson ri.errors)])),
    ("nondet", attrd r.nondets), ("deviation", attrd r.deviations), ("std_abs", attrd r.stdAbs),
    ("total_under", names r.totalUnder), ("state_safe", names r.stateSafe),
    ("errors", Lean.toJson r.errors)]

end Trace.Obligation
