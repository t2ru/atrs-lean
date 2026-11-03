import Trace.Dump
import Trace.Gap

/-!
# Trace.Obligation

`lake exe obligation-check` の本体。リファインメントの主定理（R 課題）が、空虚化を防ぐ形と付帯の義務を
備えているかを、環境を走査して判定する（TR-G。references/docs/spec/architecture.md#空虚化を防ぐ義務）。`Machine` の定数は名前で照合し、import しない。

R 課題は、型の結論が `Machine.Refines` の `@[obligation]` 定理である。各 R 課題について次を判定する。
束と付帯の定理は、`@[reducible]` を展開した式が一致するもので探す（先頭の定数だけでは照合しない）。

| 規則 | 内容 |
| --- | --- |
| G0 | 追跡属性を付けた定数はモデルの層にある。`Machine.Refines` を含む `@[obligation]` の型は、結論が `Refines` か、必要性の形（G9）である |
| G1 | 型が閉じている（∀ の仮定が無い。差異は `restrict` の述語として型の中に置く） |
| G2 | 抽象機械・具体機械は、名前付きの基底に `.restrict p`・`.restrictState p` を連ねた形で、`p` は `@[deviation]` の定数そのもの |
| G3 | 抽象側の基底は `Machine.ofChoice` か `Machine.pure`。選択の型の葉は `@[nondet]` か `Unit`。自由な選択があれば `FreeFrame` がある |
| G4 | 具体側の基底は `Concrete.ofFun`・`Concrete.pure`、または `Dom` を既定（全体）にした構造体で、`Concrete.ofMachine` と `Spec` の関数を参照しない |
| G5 | 貼り合わせは `Glue.ofStd`。β・ai・ao は `@[std_abs]` の定数そのもの、OJ・OO は `never` か、`@[deviation]` の定数そのもの（`Machine.Preserves.anyOf` で並べてよい） |
| G6 | 束: 同じ課題 ID・同じ `A`・`C`・`g` の `@[obligation]` の `Machine.Preserves A C g s₀ Env ch outs outsC` がある（`Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness`・`envNeeded` を含む）。`ch` は、基底が `ofChoice` のときに限り `some (Choice.mk E F P f ce e₀ m)` で、`f`・`e₀` は基底のもの、`ce` は `@[std_abs]` の定数そのもの（自由な選択があれば `m` は `KernelIs` の定理を持つ定数そのもの）。`outs`・`outsC` の層の述語は R 課題の制限の述語で、層の `base` は、その層を外した機械か基底。束の有無の判定（R 課題ごとに 1 つ）は `scripts/ci/check_obligations.py` も行う（OB-P） |
| GP | 束の向きの照合: 結論が `Machine.Preserves` の `@[obligation]` 定理は、同じ課題 ID の R 課題と同じ `A`・`C`・`g` を束ねる |

あわせて、環境全体について次を判定する。

| 規則 | 内容 |
| --- | --- |
| G3' | `Spec` の層の抽象機械の定義は、すべて `ofChoice` か `pure`、またはそれらを `Machine.sum`・`Machine.alt` で並置したもので作る（SPEC-005） |
| G7 | `@[std_abs]` は 1 引数の関数で、葉（`KernelIs` の定理があり、K は `Eq` か `@[kernel]` の定数か、`@[kernel]` の定数または汎用の核 `Machine.Kernel.undefOrEq` をその葉自身に適用したもの）か、許可した構成だけからなる合成。ao と `FreeFrame` の射影は葉でなければならない |
| G8 | `@[deviation]`・`@[env_pre]` の各定数に `Nontrivial`・`Nontrivial₂` の定理がある |
| G9 | 成分の必要性（references/docs/spec/architecture.md#空虚化を防ぐ義務）。下の 3 つ |
| GK | ギャップの登録簿（`Trace.Gap`）と証明の状態の裏付け。下のとおり |

G9 の内容は次のとおりである。

- `@[deviation]` の定数は ID を 1 つだけ持つ（複数の差異を 1 つの定数に束ねない。観測型は `Machine.Preserves.anyOf` で並べる）。
- R 課題で使う各差異 ID について、その ID のどれかの定数が、少なくとも 1 つの R 課題で次のどちらかを満たす。
  - 必要性: 差異を外した R 課題の命題の否定の閉じた定理（`¬ P` か `P → False`。`@[obligation]` の W 課題でもよい）がある
    - 前提型の差異 `d`: R 課題の機械から `.restrict d`・`.restrictState d`・`Concrete.restrict d` の層を 1 つ外す
    - 観測型の差異 `d`: R 課題の `Glue.ofStd` の OJ・OO（`anyOf` の葉）のうち `d` を `Machine.Preserves.never` に替える
    - 否定する命題: `¬ Refines A C g`。抽象側の基底が `ofChoice` なら `¬ (Refines A C g ∧ Pinned A C g f ce adm)` でもよい
      （`f` は基底の `f`、`ce`・`adm` は R 課題の束の `Choice` の `ce`・`adm`）
  - 被覆: 必要性か被覆を満たす差異 `M` と同じ R 課題の制限に現れ、`Covers M d`・`Covers₂ M d` の定理がある
- R 課題の基底について `TotalUnder A Env` を示した各 `@[env_pre]` の `Env` について、その基底の `¬ TotalUnder A always` がある
  （PRE が全域なら、環境の前提を置かず `TotalUnder A always` を示す）

GK の内容は次のとおりである。

- `@[gap_entry]` の宣言の値が読める。宣言は `D-NNN` なら `Abstraction`、`T-NNN` なら `Refinement` の層にあり、docstring（説明）を持つ
- 同じ ID の宣言は 1 つだけ
- `@[gap]` の印は、`D-NNN` なら `Spec`・`SourceModel`、`T-NNN` なら `Spec`・`TargetModel` の層の定数にだけ付き、ID の宣言がある
- `@[deviation]` の ID に、前提型・観測型の宣言がある
- 印・差異の定数と種類が矛盾しない（モデル外は、裏付けの宣言のほかに印を持たない。前提型・観測型のほかは `@[deviation]` を持たない）
- 前提型・観測型の宣言の `deviations` は、その ID の `@[deviation]` の定数のすべてである
- 証明の状態（`Trace.Gap.Evidence`）の裏付け。裏付けの宣言は `@[gap "<ID>"]` を持ち、証明の層（`Abstraction`・`Refinement`）にも置いてよい
  - `refuted`: 各定理が、どれかの R 課題について、`deviations` のどれかの必要性の定理（G9 の形）である
  - `covered`: 各定理が `Covers coverer d`（d は `deviations` のどれか）であり、`coverer` の差異から被覆をたどると、循環せずに `refuted` の差異に着く
  - `pending`: 必要性の定理が無い（あれば `refuted` にする）。G9 の誤りは警告に下げる（段階導入は `trace check` が作業項目の状態で判定する）
  - `unformalized`: 主張は `opaque … : Prop` で、どの定数からも参照されない（公理を足さず、推論に持ち込まない）
  - `excludedBy`: 前提の述語が `@[gap "<ID>"]` を持つ

G9・GK の誤りのうち、`pending` の差異の G9 だけは `warnings` に出す。

入口の全域性（束の `total`・`envWitness`、または別の定理の `TotalUnder`・`EnvWitness`）と、出力のみの差異の `StateSafe`（束の `outs`・`outsC` の層）は、R 課題ごとに事実として出力し、
文書（入口の R 課題、前提型の差異の影響）との突き合わせは `scripts/ci/check_obligations.py` が行う（TR-N）。
-/

namespace Trace.Obligation
open Trace.Gap
open Trace.Attr

open Lean

-- `Machine` の定数の名前。
namespace N
def refines : Name := `Machine.Refines
def preserves : Name := `Machine.Preserves
def choiceMk : Name := `Machine.Preserves.Choice.mk
def outLayerMk : Name := `Machine.Preserves.OutLayer.mk
def outLayerCMk : Name := `Machine.Preserves.OutLayerC.mk
def sum : Name := `Machine.Machine.sum
def alt : Name := `Machine.Machine.alt
def restrict : Name := `Machine.Machine.restrict
def restrictState : Name := `Machine.Machine.restrictState
def cRestrict : Name := `Machine.Concrete.restrict
def ofChoice : Name := `Machine.Machine.ofChoice
def pure : Name := `Machine.Machine.pure
def ofMachine : Name := `Machine.Concrete.ofMachine
def cOfFun : Name := `Machine.Concrete.ofFun
def cPure : Name := `Machine.Concrete.pure
def cMk : Name := `Machine.Concrete.mk
def machine : Name := `Machine.Machine
def ofStd : Name := `Machine.Glue.ofStd
def never : Name := `Machine.Preserves.never
def initSurj : Name := `Machine.Refines.InitSurj
def pinned : Name := `Machine.Refines.Pinned
def sameEnv : Name := `Machine.Preserves.sameEnv
def noFault : Name := `Machine.Refines.NoFaultReachable
def envWitness : Name := `Machine.Refines.EnvWitness
def stateSafe : Name := `Machine.Refines.StateSafe
def stateSafeC : Name := `Machine.Refines.StateSafeConcrete
def totalUnder : Name := `Machine.Machine.TotalUnder
def sound : Name := `Machine.Machine.Sound
def initIs : Name := `Machine.Machine.InitIs
def freeFrame : Name := `Machine.Machine.FreeFrame
def nontrivial : Name := `Machine.Preserves.Nontrivial
def nontrivial₂ : Name := `Machine.Preserves.Nontrivial₂
def kernelIs : Name := `Machine.Preserves.KernelIs
def undefOrEq : Name := `Machine.Kernel.undefOrEq
def always : Name := `Machine.Preserves.always
def anyOf : Name := `Machine.Preserves.anyOf
def covers : Name := `Machine.Preserves.Covers
def covers₂ : Name := `Machine.Preserves.Covers₂
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

/-- 帰納型について処理系が生成する補助の定数か（構成子の番号 `ctorIdx`、列挙型の番号からの構成 `ofNat`。
`deriving DecidableEq` などが使う）。 -/
def isInductiveAux (env : Environment) (n : Name) : Bool :=
  match n with
  | .str p s =>
    match env.find? p with
    | some (.inductInfo iv) =>
      s == "ctorIdx" || (s == "ofNat" && iv.ctors.all fun c =>
        (env.find? c).any fun cc => match cc with | .ctorInfo ci => ci.numFields == 0 | _ => false)
    | _ => false
  | _ => false

/-- 計算の中身を持たない、参照してよい定数か（型・構成子・射影・インスタンス・再帰子・matcher・定理・帰納型の補助）。 -/
def isStructural (env : Environment) (n : Name) (ci : ConstantInfo) : Bool :=
  isTypeFormer ci || ci.isCtor || ci.isInductive || ci.isTheorem || env.isProjectionFn n ||
    Meta.isInstanceCore env n || isAuxRecursor env n || Meta.isMatcherCore env n || isInductiveAux env n ||
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
  /-- 束の `outs`・`outsC` に層がある差異の述語（`StateSafe`・`StateSafeConcrete`） -/
  stateSafe : Array Name := #[]
  /-- 必要性の定理（G9）がある差異 -/
  necessity : Array Name := #[]
  /-- 差異と、その必要性の定理（GK が `Evidence.refuted` と照合する） -/
  necessityBy : Array (Name × Name) := #[]
  /-- 抽象側の基底に `¬ TotalUnder A always` があるか -/
  envNecessary : Bool := false
  errors : Array String := #[]

/-- 付帯の定理の一覧（引数は正規形）。 -/
structure Companions where
  /-- `EnvWitness C g Env` の (C, g, Env) -/
  envWitness : Array (Expr × Expr × Expr) := #[]
  /-- `TotalUnder A Env` の (A, Env) -/
  totalUnder : Array (Expr × Expr) := #[]
  /-- `Nontrivial`・`Nontrivial₂` の述語の定数 -/
  nontrivial : Array Name := #[]
  /-- `KernelIs f K` の f の定数で、K が `Eq` か `@[kernel]` の定数であるもの -/
  kernel : Array Name := #[]
  /-- 必要性の定理（G9）の (定理, A, C, g, `Pinned` の (f, ce, adm)) -/
  necessity : Array (Name × Expr × Expr × Expr × Option (Expr × Expr × Expr)) := #[]
  /-- `¬ TotalUnder A always` の A -/
  envNecessity : Array Expr := #[]
  /-- `Covers M d`・`Covers₂ M d` の (定理, M, d) -/
  covers : Array (Name × Name × Name) := #[]

/-- 束 `Machine.Preserves`（`@[obligation]`）の読み取り結果（引数は正規形）。 -/
structure Bundle where
  name : Name
  ids : Array String
  a : Expr
  c : Expr
  g : Expr
  env : Expr
  /-- `ch`: `none` は `none`、`some (f, ce, adm, e₀, m)` は `some (Choice.mk … f ce adm d₀ e₀ m)`。読めなければ `.error` -/
  ch : Except String (Option (Expr × Expr × Expr × Expr × Expr))
  /-- `outs`・`outsC` の層の (base, P)。読めなければ `.error` -/
  outs : Except String (Array (Expr × Expr))
  outsC : Except String (Array (Expr × Expr))

/-- 走査全体の結果。 -/
structure Report where
  rs : Array RInfo
  obligations : Array (Name × Array String × Bool)
  /-- 結論が `Machine.Preserves` の `@[obligation]` 定理（GP） -/
  preserves : Array Name := #[]
  nondets : Array (Name × Array String)
  deviations : Array (Name × Array String)
  stdAbs : Array (Name × Array String)
  envPres : Array (Name × Array String)
  errors : Array String
  /-- 警告（証明の状態が `pending` の差異の G9。段階導入の判定は道具が作業項目の状態で行う） -/
  warnings : Array String := #[]
  /-- ギャップの登録簿（`Trace.Gap.gapsJson`） -/
  gaps : Json := Json.arr #[]

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

/-- 型が必要性の形（`¬ Refines A C g` か `¬ (Refines A C g ∧ Pinned A C g f ce adm)`。`→ False` でもよい）なら、正規形の
(A, C, g, (f, ce, adm)) を返す（G9）。 -/
def necessityForm? (env : Environment) (ty : Expr) : Option (Expr × Expr × Expr × Option (Expr × Expr × Expr)) := do
  let x ← negated? env ty
  let nz := normalize env
  if x.isAppOfArity N.refines 10 then
    let a := x.getAppArgs
    return (nz a[7]!, nz a[8]!, nz a[9]!, none)
  guard (x.isAppOfArity ``And 2)
  let l := unfoldReducible env x.appFn!.appArg!
  let r := unfoldReducible env x.appArg!
  guard (l.isAppOfArity N.refines 10 && r.isAppOfArity N.pinned 16)
  let la := l.getAppArgs
  let ra := r.getAppArgs
  let (a, c, g) := (nz la[7]!, nz la[8]!, nz la[9]!)
  guard (nz ra[10]! == a && nz ra[11]! == c && nz ra[12]! == g)
  return (a, c, g, some (nz ra[13]!, nz ra[14]!, nz ra[15]!))

/-- 型が `¬ TotalUnder A always` なら、正規形の A を返す（G9）。 -/
def envNecessityForm? (env : Environment) (ty : Expr) : Option Expr := do
  let x ← negated? env ty
  guard (x.isAppOfArity N.totalUnder 5)
  let a := x.getAppArgs
  guard (headConst? a[4]! == some N.always && (clean a[4]!).getAppNumArgs == 2)
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

/-- `Spec` の層の機械の定義が、`ofChoice`・`pure` か、それらを `Machine.sum`（状態の積）・`Machine.alt`（同じ状態）で
並置したものか（G3'）。 -/
partial def specMachineOk (env : Environment) (e : Expr) : Bool :=
  match unfoldTo env [N.ofChoice, N.pure, N.sum, N.alt] e with
  | some e' =>
    if e'.getAppFn.constName? == some N.sum then
      let args := e'.getAppArgs
      args.size == 8 && specMachineOk env (unfoldReducible env args[6]!) && specMachineOk env (unfoldReducible env args[7]!)
    else if e'.getAppFn.constName? == some N.alt then
      let args := e'.getAppArgs
      args.size == 7 && specMachineOk env (unfoldReducible env args[5]!) && specMachineOk env (unfoldReducible env args[6]!)
    else true
  | none => false

/-- 選択の型を `Prod` で分解した葉。 -/
partial def prodLeaves (e : Expr) : Array Expr :=
  let e := e.consumeMData
  if e.isAppOfArity ``Prod 2 then prodLeaves e.appFn!.appArg! ++ prodLeaves e.appArg!
  else #[e]

/-- 束の `ch`（`Option (Choice …)`）を読む。 -/
def readChoice (env : Environment) (e : Expr) : Except String (Option (Expr × Expr × Expr × Expr × Expr)) :=
  let nz := normalize env
  match unfoldTo env [``Option.none, ``Option.some] e with
  | some v =>
    if v.isAppOfArity ``Option.none 1 then .ok none
    else match unfoldTo env [N.choiceMk] v.appArg! with
      | some c =>
        let xs := c.getAppArgs
        -- 型引数 σ ιa οa ιc と、欄 E F D P f ce adm d₀ e₀ m
        if xs.size == 14 then .ok (some (nz xs[8]!, nz xs[9]!, nz xs[10]!, nz xs[12]!, nz xs[13]!))
        else .error "ch is not Machine.Preserves.Choice.mk with all fields"
      | none => .error "ch is not some (Machine.Preserves.Choice.mk …)"
  | none => .error "ch is not none or some _"

/-- 束の `outs`・`outsC`（層の列）を読む。`mk` は層の構成子、`nTy` はその型引数の数。 -/
partial def readLayers (env : Environment) (mk : Name) (nTy : Nat) (e : Expr) :
    Except String (Array (Expr × Expr)) :=
  let nz := normalize env
  match unfoldTo env [``List.nil, ``List.cons] e with
  | some v =>
    if v.isAppOfArity ``List.nil 1 then .ok #[]
    else if v.isAppOfArity ``List.cons 3 then
      let xs := v.getAppArgs
      match unfoldTo env [mk] xs[1]! with
      | some l =>
        let ls := l.getAppArgs
        if ls.size == nTy + 2 then
          (readLayers env mk nTy xs[2]!).map fun rest => #[(nz ls[nTy]!, ls[nTy + 1]!)] ++ rest
        else .error s!"a layer is not {mk} with all fields"
      | none => .error s!"a layer is not {mk} …"
    else .error "the layers are not a list literal"
  | none => .error "the layers are not a list literal"

/-- 結論が `Machine.Preserves` の型を読む（GP・G6）。 -/
def readBundle (env : Environment) (name : Name) (ids : Array String) (concl : Expr) : Bundle :=
  let nz := normalize env
  let xs := concl.getAppArgs
  { name, ids, a := nz (unfoldReducible env xs[7]!), c := nz (unfoldReducible env xs[8]!),
    g := nz (unfoldReducible env xs[9]!), env := xs[11]!, ch := readChoice env xs[12]!,
    outs := readLayers env N.outLayerMk 3 xs[13]!, outsC := readLayers env N.outLayerCMk 4 xs[14]! }

/-- 付帯の定理を集める。 -/
def collectCompanions (env : Environment) : Companions := Id.run do
  let mut cs : Companions := {}
  let nz := normalize env
  for (n, ci) in env.constants.toList do
    let .thmInfo _ := ci | continue
    if let some (a, c, g, pin) := necessityForm? env ci.type then
      cs := { cs with necessity := cs.necessity.push (n, a, c, g, pin) }
      continue
    if let some a := envNecessityForm? env ci.type then
      cs := { cs with envNecessity := cs.envNecessity.push a }
      continue
    let (concl, nForall) := conclusion ci.type
    unless nForall == 0 do continue
    let some h := concl.getAppFn.constName? | continue
    let a := concl.getAppArgs
    if h == N.envWitness && a.size == 11 then
      cs := { cs with envWitness := cs.envWitness.push (nz a[7]!, nz a[8]!, nz a[10]!) }
    else if h == N.totalUnder && a.size == 5 then
      cs := { cs with totalUnder := cs.totalUnder.push (nz a[3]!, nz a[4]!) }
    else if h == N.nontrivial && a.size == 2 then
      if let some pc := bareConst? a[1]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if h == N.nontrivial₂ && a.size == 3 then
      if let some pc := bareConst? a[2]! then cs := { cs with nontrivial := cs.nontrivial.push pc }
    else if (h == N.covers && a.size == 3) || (h == N.covers₂ && a.size == 4) then
      if let (some m, some d) := (bareConst? a[a.size - 2]!, bareConst? a[a.size - 1]!) then
        cs := { cs with covers := cs.covers.push (n, m, d) }
    else if h == N.kernelIs && a.size == 4 then
      if let some fc := bareConst? a[2]! then
        let k := clean a[3]!
        -- K は `Eq`、`@[kernel]` の定数、または `@[kernel]` の定数か汎用の核 `Machine.Kernel.undefOrEq`
        -- （部分写像が「どちらも定義されないか、等しい」。Machine.Kernel）をその葉自身に適用したもの
        let kf := k.getAppFn
        let applied := k.isApp && kf.isConst &&
          (hasAttr kernelAttr env kf.constName! || kf.constName! == N.undefOrEq) &&
          bareConst? k.appArg! == some fc
        let ok := k.isAppOfArity ``Eq 1 || (k.constName?.any (hasAttr kernelAttr env ·)) || applied
        if ok then cs := { cs with kernel := cs.kernel.push fc }
  return cs

/-- 1 つの R 課題を判定する。 -/
def checkR (env : Environment) (sc : Scope) (cs : Companions) (bundles : Array Bundle) (name : Name)
    (ids : Array String) (ty : Expr) : RInfo := Id.run do
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
  let mut pinCes : Array (Expr × Expr) := #[]
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
      if n == N.ofMachine then
        r := { r with errors := r.errors.push "G4: concrete base uses Machine.Concrete.ofMachine" }
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
          else r := { r with errors := r.errors.push s!"G5: {label} = {oc} is neither Machine.Preserves.never nor @[deviation]" }
        | none => r := { r with errors := r.errors.push s!"G5: {label} is not Machine.Preserves.never or Machine.Preserves.anyOf of bare @[deviation] constants" }
  else
    r := { r with errors := r.errors.push "G5: glue is not Machine.Glue.ofStd" }
  -- G6: 束 `Preserves`（同じ課題 ID・同じ A・C・g の `@[obligation]`）と、その `ch`・`outs` が R 課題の構造に合うこと
  let bs := bundles.filter fun b => b.ids.any ids.contains && b.a == a && b.c == c && b.g == g
  if bs.isEmpty then
    r := { r with errors := r.errors.push "G6: no Machine.Preserves bundle (@[obligation] with the same ID, A, C and g) for this R obligation" }
  else
    r := { r with hasInitSurj := true, hasSound := true, hasInitIs := true }
  for b in bs do
    -- 選択の像の材料
    match b.ch, choice with
    | .error e, _ => r := { r with errors := r.errors.push s!"G6: {b.name}: {e}" }
    | .ok none, none => pure ()
    | .ok (some _), none =>
      r := { r with errors := r.errors.push s!"G6: {b.name}: ch must be none for a Machine.pure base" }
    | .ok none, some _ =>
      r := { r with errors := r.errors.push s!"G6: {b.name}: ch must be some (Choice.mk …) with the f and e₀ of Machine.ofChoice" }
    | .ok (some (f', ce, adm, e₀', m)), some (f, e₀) =>
      -- `adm`: 等号 `Machine.Preserves.sameEnv` か、`Spec` の層の裸の定数（環境の記述が許す環境の選択）
      let admOk := headConst? adm == some N.sameEnv ||
        (bareConst? adm).any fun ac => sc.layerOf ac == some "Spec"
      if f' != f then r := { r with errors := r.errors.push s!"G6: {b.name}: Choice.f is not the f of Machine.ofChoice" }
      else if e₀' != e₀ then r := { r with errors := r.errors.push s!"G6: {b.name}: Choice.e₀ is not the e₀ of Machine.ofChoice" }
      else if !admOk then
        r := { r with errors := r.errors.push s!"G6: {b.name}: Choice.adm is neither Machine.Preserves.sameEnv nor a bare constant of the Spec layer" }
      else match bareConst? ce with
        | some cc =>
          if hasAttr stdAbsAttr env cc then
            pinCes := pinCes.push (ce, adm)
            r := { r with hasPinned := true, hasNoFault := true }
          else r := { r with errors := r.errors.push s!"G6: {b.name}: Choice.ce = {cc} has no @[std_abs]" }
        | none => r := { r with errors := r.errors.push s!"G6: {b.name}: Choice.ce is not a bare @[std_abs] constant" }
      if !r.freeLeaves.isEmpty && (bareConst? m).any fun mc => cs.kernel.contains mc then
        r := { r with hasFreeFrame := true }
    -- 「出力のみ」の差異の層（base は、その層を外した機械か基底）
    for (label, ls, whole, base, names) in
        [("outs", b.outs, a, aBase, [N.restrict, N.restrictState]), ("outsC", b.outsC, c, cBase, [N.cRestrict])] do
      match ls with
      | .error e => r := { r with errors := r.errors.push s!"G6: {b.name}: {label}: {e}" }
      | .ok xs =>
        for (lb, lp) in xs do
          match bareConst? lp with
          | some pc =>
            let dropped := (dropRestrict env names (mkConst pc) whole).map (normalize env)
            if !r.devs.contains pc then
              r := { r with errors := r.errors.push s!"G6: {b.name}: {label} has the layer {pc}, which is not a restrict predicate of the R obligation" }
            else if lb == base || dropped == some lb then
              unless r.stateSafe.contains pc do r := { r with stateSafe := r.stateSafe.push pc }
            else
              r := { r with errors := r.errors.push s!"G6: {b.name}: {label}: the base of the layer {pc} is neither the base nor the machine without the layer" }
          | none => r := { r with errors := r.errors.push s!"G6: {b.name}: {label}: a layer predicate is not a bare @[deviation] constant" }
    -- 入口の全域性（束の `total`・`envWitness`）
    if headConst? b.env == some N.always && (clean b.env).getAppNumArgs == 2 then
      r := { r with totalUnder := r.totalUnder.push (N.always, true) }
    else if let some ec := bareConst? b.env then
      if hasAttr envPreAttr env ec then r := { r with totalUnder := r.totalUnder.push (ec, true) }
  if choice.isSome && !r.freeLeaves.isEmpty && !r.hasFreeFrame then
    let msg := "G3: free choices, but no bundle whose Choice.m is a bare constant with a KernelIs theorem (FreeFrame)"
    r := { r with errors := r.errors.push msg }
  -- G9: 成分の必要性（どの R 課題にも無い成分の誤りは、全体の判定で出す）
  let pinOk (pin : Option (Expr × Expr × Expr)) : Bool :=
    match choice, pin with
    | some (f, _), some (f', ce', adm') => f' == f && pinCes.contains (ce', adm')
    | some _, none => true
    | none, none => r.absKind == "pure"
    | none, some _ => false
  let found (a' c' g' : Expr) : Array Name :=
    (cs.necessity.filter fun (_, a'', c'', g'', pin) => a'' == a' && c'' == c' && g'' == g' && pinOk pin).map (·.1)
  let record (r : RInfo) (d : Name) (ts : Array Name) : RInfo :=
    if ts.isEmpty then r
    else { r with necessity := r.necessity.push d, necessityBy := r.necessityBy ++ ts.map (d, ·) }
  for p in aPs ++ cPs do
    if let some pc := bareConst? p then
      if r.devs.contains pc && !r.necessity.contains pc then
        let a' := (dropRestrict env [N.restrict, N.restrictState] p a).getD a
        let c' := (dropRestrict env [N.cRestrict] p c).getD c
        r := record r pc (found a' c' g)
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
            r := record r oc (found a c g')
  -- 入口の全域性（別の定理の `TotalUnder`・`EnvWitness`。事実として出す）
  r := { r with envNecessary := cs.envNecessity.contains aBase }
  for (a', env') in cs.totalUnder do
    if a' == aBase then
      let w := cs.envWitness.any fun (c', g', e') => c' == c && g' == g && e' == env'
      let add (r : RInfo) (e : Name) : RInfo :=
        if r.totalUnder.any (·.1 == e) then r else { r with totalUnder := r.totalUnder.push (e, w) }
      if headConst? env' == some N.always && (clean env').getAppNumArgs == 2 then
        r := add r N.always
      else match bareConst? env' with
        | some ec =>
          if hasAttr envPreAttr env ec then r := add r ec
        | none => pure ()
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

/-- GK: ギャップの登録簿と、印・差異の定数・証明の状態の裏付けの整合。 -/
def checkGaps (env : Environment) (sc : Scope) (rs : Array RInfo) (cs : Companions) : Array String := Id.run do
  let mut errors := #[]
  let mut byId : Std.HashMap String (Name × Gap) := {}
  let mut order : Array String := #[]
  for (n, r) in gapEntries env do
    match r with
    | .error e => errors := errors.push s!"GK: {n} (@[gap_entry]): {e}"
    | .ok g =>
      let want := g.id.side.proofLayer
      if sc.layerOf n != some want then
        errors := errors.push s!"GK: {n} (@[gap_entry] {g.idStr}) must be in the {want} layer"
      if ((gapDoc? env n).getD "").trimAscii.isEmpty then
        errors := errors.push s!"GK: {n} (@[gap_entry] {g.idStr}) has no docstring (the description)"
      match byId[g.idStr]? with
      | some (m, _) => errors := errors.push s!"GK: {g.idStr} is declared by both {m} and {n}"
      | none => byId := byId.insert g.idStr (n, g); order := order.push g.idStr
  -- 裏付けの宣言（`@[gap]` を付け、証明の層に置いてよい）
  let mut witnessOf : Std.HashMap Name (Array String) := {}
  for i in order do
    let some (_, g) := byId[i]? | continue
    for w in g.witnesses do witnessOf := witnessOf.insert w ((witnessOf.getD w #[]).push i)
  for (n, ids) in gapMarkers env do
    for i in ids do
      let isWitness := (witnessOf.getD n #[]).contains i
      let base := if i.startsWith "T-" then ["Spec", "TargetModel"] else ["Spec", "SourceModel"]
      let proof := if i.startsWith "T-" then "Refinement" else "Abstraction"
      let allowed := if isWitness then base ++ [proof] else base
      unless (sc.layerOf n).any allowed.contains do
        errors := errors.push
          s!"GK: {n} has @[gap \"{i}\"] but is not in the {allowed} layers (the {proof} layer is only for the evidence of {i})"
      match byId[i]? with
      | none => errors := errors.push s!"GK: {n} has @[gap \"{i}\"] but {i} has no @[gap_entry]"
      | some (_, g) =>
        if g.kind == .outOfModel && !isWitness then
          errors := errors.push s!"GK: {n} has @[gap \"{i}\"] but {i} is out_of_model (it appears in no model)"
  for (n, ids) in deviationConsts env do
    for i in ids do
      match byId[i]? with
      | none => errors := errors.push s!"GK: {n} has @[deviation \"{i}\"] but {i} has no @[gap_entry]"
      | some (_, g) =>
        if !g.kind.isTyped then
          errors := errors.push s!"GK: {n} has @[deviation \"{i}\"] but {i} is {g.kind.code}, not pre / observational"
        else if !g.deviations.contains n then
          errors := errors.push s!"GK: {n} has @[deviation \"{i}\"] but the @[gap_entry] of {i} does not list it in deviations"
  -- 証明の状態ごとの裏付け
  let idOfDev (d : Name) : Option String := (deviationAttr.getParam? env d).bind (·[0]?)
  let mut claims : Array (Name × String) := #[]
  for i in order do
    let some (_, g) := byId[i]? | continue
    let code := g.evidenceCode
    for d in g.deviations do
      unless (deviationAttr.getParam? env d).any (·.contains i) do
        errors := errors.push s!"GK: {i}: deviations lists {d}, which has no @[deviation \"{i}\"]"
    for w in g.witnesses do
      unless (gapAttr.getParam? env w).any (·.contains i) do
        errors := errors.push s!"GK: {i}: {w} (the evidence {code}) must have @[gap \"{i}\"]"
    if let some c := g.claim? then
      match env.find? c with
      | some (.opaqueInfo oi) =>
        if oi.type.consumeMData == .sort .zero then claims := claims.push (c, i)
        else errors := errors.push s!"GK: {i}: the claim {c} must be an opaque Prop"
      | _ => errors := errors.push s!"GK: {i}: the claim {c} must be an opaque Prop (opaque {c} : Prop)"
    match g.typedEvidence? with
    | none => pure ()
    | some (.refuted _ ts) =>
      for t in ts.toList do
        match env.find? t with
        | some (.thmInfo _) =>
          let ok := rs.any fun ri => ri.necessityBy.any fun (d, t') => t' == t && g.deviations.contains d
          unless ok do
            errors := errors.push
              s!"GK: {i}: {t} is not a necessity theorem of {g.deviations} (¬ of an R obligation with one of them removed)"
        | _ => errors := errors.push s!"GK: {i}: {t} (refuted) is not a theorem"
    | some (.covered _ m ts) =>
      for t in ts.toList do
        unless cs.covers.any (fun (t', m', d) => t' == t && m' == m && g.deviations.contains d) do
          errors := errors.push s!"GK: {i}: {t} is not a theorem Covers {m} d with d in {g.deviations}"
      -- 被覆の連鎖は、偽を証明済みの差異で終わる（循環しない）
      let mut cur := m
      let mut seen : Array String := #[i]
      for _ in [0:order.size + 1] do
        let some j := idOfDev cur
          | errors := errors.push s!"GK: {i}: the coverer {cur} has no @[deviation]"; break
        if seen.contains j then
          errors := errors.push s!"GK: {i}: the covered chain is cyclic ({seen.toList ++ [j]})"; break
        let some (_, gj) := byId[j]? | break
        match gj.typedEvidence? with
        | some (.refuted ..) => break
        | some (.covered _ m' _) => seen := seen.push j; cur := m'
        | _ =>
          errors := errors.push s!"GK: {i}: the coverer {cur} ({j}) is {gj.evidenceCode}, not refuted / covered"; break
    | some (.pending ..) =>
      if g.deviations.any (fun d => rs.any fun ri => ri.necessity.contains d) then
        errors := errors.push s!"GK: {i} is pending but has a necessity theorem; make it refuted"
  -- 形式化していない主張は、どの定数からも参照しない（仮定として推論に持ち込まない）
  unless claims.isEmpty do
    for (n, ci) in env.constants.toList do
      if (moduleRoot? env n).any libraryRoots.contains then continue
      let used := ci.type.getUsedConstants ++ ((ci.value?).map Expr.getUsedConstants |>.getD #[])
      for (c, i) in claims do
        if n != c && used.contains c then
          errors := errors.push s!"GK: {n} refers to {c} (the unformalized claim of {i}); a claim must not be used"
  return errors

/-- 環境を走査する。 -/
def check (env : Environment) (sc : Scope := defaultScope) : Report := Id.run do
  let cs := collectCompanions env
  let mut rs := #[]
  let mut obligations := #[]
  let mut preserves : Array Name := #[]
  -- R 課題の (ID, A, C, g)（GP の照合）
  let mut rArgs : Array (Array String × Array Expr) := #[]
  let mut nondets := #[]
  let mut devs := #[]
  let mut stds := #[]
  let mut envPres := #[]
  let mut errors := #[]
  let consts := env.constants.toList.toArray.qsort fun a b => a.1.toString < b.1.toString
  -- 1 回目: 束 `Preserves` を集める（G6 が R 課題ごとに引く）
  let mut bundles : Array Bundle := #[]
  for (n, ci) in consts do
    if let some ids := obligationAttr.getParam? env n then
      if let .thmInfo _ := ci then
        let concl := unfoldReducible env (conclusion ci.type).1
        if concl.isAppOfArity N.preserves 15 then bundles := bundles.push (readBundle env n ids concl)
  for (n, ci) in consts do
    let attrs := [("nondet", nondetAttr), ("deviation", deviationAttr), ("std_abs", stdAbsAttr),
      ("kernel", kernelAttr), ("env_pre", envPreAttr), ("obligation", obligationAttr)]
    let mine := (attrs.filter fun (_, attr) => hasAttr attr env n).map (·.1) ++
      (if hasAttr gapAttr env n then ["gap"] else []) ++ (if gapEntryAttr.hasTag env n then ["gap_entry"] else [])
    if !mine.isEmpty && !sc.isModel n then
      errors := errors.push s!"G0: {n} has @[{mine}] but is not in a model layer"
    if let some ids := nondetAttr.getParam? env n then nondets := nondets.push (n, ids)
    if let some ids := deviationAttr.getParam? env n then
      devs := devs.push (n, ids)
      if ids.size > 1 then
        errors := errors.push
          s!"G9: {n} (@[deviation]) has {ids.size} IDs {ids.toList}; give each deviation its own constant (Machine.Preserves.anyOf for observational components)"
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
        if !specMachineOk env (unfoldReducible env v) then
          errors := errors.push s!"G3: {n} (Spec machine) is not built with Machine.ofChoice or Machine.pure"
    if let some ids := obligationAttr.getParam? env n then
      if let .thmInfo _ := ci then
        let (concl, _) := conclusion ci.type
        let concl := unfoldReducible env concl
        let isR := concl.isAppOfArity N.refines 10
        let isP := concl.isAppOfArity N.preserves 15
        obligations := obligations.push (n, ids, isR)
        let acg (e : Expr) (i : Nat) : Array Expr :=
          (e.getAppArgs.extract i (i + 3)).map fun x => normalize env (unfoldReducible env x)
        if isP then preserves := preserves.push n
        if isR then
          rs := rs.push (checkR env sc cs bundles n ids ci.type)
          rArgs := rArgs.push (ids, acg concl 7)
        else if (normalize env ci.type).getUsedConstants.contains N.refines &&
            (necessityForm? env ci.type).isNone then
          errors := errors.push s!"G0: {n} mentions Machine.Refines but its conclusion is not Refines"
  -- GP: 束は、同じ課題 ID の R 課題と同じ A・C・g を束ねる
  for b in bundles do
    unless rArgs.any (fun (rids, ys) => b.ids.any rids.contains && #[b.a, b.c, b.g] == ys) do
      errors := errors.push s!"GP: {b.name} (Machine.Preserves) does not bundle an R obligation with the same ID {b.ids.toList} (A, C and g must match)"
  -- G9: 成分の必要性（差異 ID ごとに、少なくとも 1 つの R 課題について。被覆は必要な差異から広げる）
  let used := (rs.foldl (fun acc ri => acc ++ ri.devs ++ ri.obs) #[]).toList.eraseDups
  let mut needed := rs.foldl (fun acc ri => acc ++ ri.necessity) #[]
  for _ in [0:cs.covers.size] do
    for (_, m, d) in cs.covers do
      if needed.contains m && !needed.contains d &&
          rs.any (fun ri => ri.devs.contains m && ri.devs.contains d) then
        needed := needed.push d
  let idsOf (n : Name) : List String := ((deviationAttr.getParam? env n).getD #[]).toList
  let neededIds := needed.toList.flatMap idsOf
  let pendingIds := (gapEntries env).toList.filterMap fun (_, r) =>
    match r with | .ok g => (if g.isPending then some g.idStr else none) | .error _ => none
  let mut warnings := #[]
  for i in (used.flatMap idsOf).eraseDups do
    unless neededIds.contains i do
      let consts := used.filter fun d => (idsOf d).contains i
      let msg := s!"G9: {i} (@[deviation] {consts}) has neither a necessity theorem (¬ of an R obligation without it) nor Covers by a needed deviation in any R obligation"
      if pendingIds.contains i then warnings := warnings.push (msg ++ s!" ({i} is pending)")
      else errors := errors.push msg
  for (e, _) in envPres do
    let bases := (rs.filter fun ri => ri.totalUnder.any (·.1 == e)).toList.map fun ri => (ri.absBase, ri.envNecessary)
    for (b, ok) in bases.eraseDups do
      unless ok do
        errors := errors.push
          s!"G9: {e} (@[env_pre]) is used for the abstract base {b} of an R obligation without a ¬ TotalUnder (base) always theorem (if PRE is total, state TotalUnder (base) always instead)"
  errors := errors ++ checkGaps env sc rs cs
  let moduleOf (n : Name) : String := Trace.Dump.moduleOf env n
  return { rs, obligations, preserves, nondets, deviations := devs, stdAbs := stds, envPres, errors, warnings,
           gaps := Trace.Gap.gapsJson env moduleOf }

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
      ("name", Lean.toJson n.toString), ("ids", Lean.toJson ids), ("refines", Lean.toJson isR),
      ("preserves", Lean.toJson (r.preserves.contains n))])),
    ("nondet", attrd r.nondets), ("deviation", attrd r.deviations), ("std_abs", attrd r.stdAbs),
    ("env_pre", attrd r.envPres), ("errors", Lean.toJson r.errors),
    ("warnings", Lean.toJson r.warnings), ("gaps", r.gaps)]

end Trace.Obligation
