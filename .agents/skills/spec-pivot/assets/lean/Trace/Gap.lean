import Trace.Attr
import Trace.Id

/-!
# Trace.Gap

`Spec` と移植元・移植先のモデルのギャップ（既知差異 `D-NNN` / `T-NNN` と、それに準じて明示するもの）の登録簿。
登録簿の正は Lean である。文書の表は、`trace-dump` の `gaps` から道具が生成する
（spec-pivot の `lang/lean/trace-attributes.md`、`spec/traceability.md`）。

- **登録の宣言**: ギャップごとに、型 `Trace.Gap` の定数を 1 つ置き、`@[gap_entry]` を付ける。
  説明（文書の表の「差異」「振る舞い」「状況」の列）は、その定数の docstring に Markdown で書く。
  値は、定義の展開だけで構築子と文字列リテラルの組み合わせになる式で書く（文字列の連結などの計算はできない）。
- **箇所の印**: ギャップが生じる `Spec`・`SourceModel`・`TargetModel` の定義に `@[gap "<ID>", …]` を付ける
  （`Trace.Attr`）。上流の版上げで印の付いた定義が変わると、見直すギャップが道具で出る。

- **型**（ADR bf1b。不正な状態を表現できない型）: 種類ごとに要る欄と許す証明の状態を、和型 `Gap.Body` の構築子と、
  種類ごとの証明の状態の型（`TypedEvidence`・`UndeterminedEvidence`）で表す。ID・空でない文字列と列は `Trace.Id` の型で、
  形式に合わない値はエラボレートの時点で型の誤りになる。
- **証明の状態**: ギャップは、リファインメントの証明の中で証明できない部分である。それを公理や `sorry` で
  仮定せず（ギャップが実在すれば矛盾する）、状態を裏付ける Lean の宣言で示す。裏付けの宣言には `@[gap "<ID>"]` を付ける。
  - `refuted`: 差異を外した R 課題の否定の定理（偽を証明済み。W 課題の必要性）
  - `covered`: 必要な差異がこの差異を覆う定理（`Machine.Preserves.Covers`）
  - `pending`: 前提で制限して証明したが、偽も真もまだ示していない（制限は仮定を強めるだけなので、安全に証明できる）
  - `unformalized`: Lean の命題として書けない主張。証明も公理も持たない `opaque` な命題（どの定理からも参照しない）
  - `excludedBy`: 差異ではない（`Spec` の PRE・INV の外。その前提の述語）

`@[gap_entry]` は、付けた時点で値を読めることを確かめる（字面の形。読めない値は誤り）。
docstring の有無・層・ID の重複、差異の定数と裏付けの宣言の照合は `obligation-check` が検査する（GK）。
環境の全体にわたる性質なので、型ではなく検査に置く（ADR bf1b の規則 3）。
-/

namespace Trace
open Trace.Attr Trace.Id

open Lean

namespace Gap

/-- ギャップの種類（references/docs/spec/architecture.md#リファインメントb-メソッド の差異の種類に、差異ではないが明示するものを足したもの）。
登録の値 `Gap.Body` から導く見え方で、表と JSON の列に使う。 -/
inductive GapKind where
  /-- 前提型（抽象側の入力・状態の述語。抽象側の PRE を強める） -/
  | pre
  /-- 前提型（具体側だけにある入力の述語） -/
  | preConcreteInput
  /-- 前提型（具体側だけにある状態の述語） -/
  | preConcreteState
  /-- 前提型（具体側だけにある環境の述語） -/
  | preConcreteEnv
  /-- 観測型（貼り合わせ・出力の対応の名前付きの成分） -/
  | observational
  /-- モデル外（どのモデルにも現れない。保証の限界に載せる） -/
  | outOfModel
  /-- `Spec` の PRE・INV の外での移植元・移植先の振る舞い（差異ではない） -/
  | outsidePre
  /-- 未確定（種類を確かめる作業が残っている） -/
  | undetermined
  deriving Repr, BEq, DecidableEq, Inhabited

/-- 前提型（抽象側・具体側）か。 -/
def GapKind.isPre : GapKind → Bool
  | .pre | .preConcreteInput | .preConcreteState | .preConcreteEnv => true
  | _ => false

/-- 名前付きの仮定・成分としてリファインメント定理に現れる種類（前提型・観測型）か。 -/
def GapKind.isTyped (k : GapKind) : Bool := k.isPre || k == .observational

/-- JSON の値。 -/
def GapKind.code : GapKind → String
  | .pre => "pre"
  | .preConcreteInput => "pre_concrete_input"
  | .preConcreteState => "pre_concrete_state"
  | .preConcreteEnv => "pre_concrete_env"
  | .observational => "observational"
  | .outOfModel => "out_of_model"
  | .outsidePre => "outside_pre"
  | .undetermined => "undetermined"

/-- 文書の表に出す名前。 -/
def GapKind.label : GapKind → String
  | .pre => "前提型"
  | .preConcreteInput => "前提型（具体側の入力）"
  | .preConcreteState => "前提型（具体側の状態）"
  | .preConcreteEnv => "前提型（具体側の環境）"
  | .observational => "観測型"
  | .outOfModel => "モデル外"
  | .outsidePre => "PRE の外"
  | .undetermined => "未確定"

/-- 前提型の差異の影響（前提を破る 1 歩の後で、状態が貼り合わせを保つか。references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
inductive Impact where
  /-- 前提を破っても、変わるのは出力だけ（R 課題に `StateSafe` を課す） -/
  | outputOnly
  /-- 前提を破ると、状態が `Spec` から離れうる -/
  | abort
  deriving Repr, BEq, DecidableEq, Inhabited

/-- JSON の値。 -/
def Impact.code : Impact → String
  | .outputOnly => "output_only"
  | .abort => "abort"

/-- 文書の表に出す名前。 -/
def Impact.label : Impact → String
  | .outputOnly => "出力のみ"
  | .abort => "中断"

/-- 文書の節への参照。表では `[label](path)note` と書く（path は文書からの相対パスに直す）。 -/
structure DocRef where
  /-- リンクの文字列 -/
  label : NEString
  /-- リポジトリのルートからのパスと、任意のアンカー（例: `docs/spec/pricing.md#税込み価格`） -/
  path : NEString
  /-- リンクの後に続ける注記（例: `（規範節）`） -/
  note : String := ""
  deriving Repr

/-- 前提型の差異の述語が掛かる側。 -/
inductive PreSide where
  /-- 抽象側の入力・状態 -/
  | abstract
  /-- 具体側だけにある入力 -/
  | concreteInput
  /-- 具体側だけにある状態 -/
  | concreteState
  /-- 具体側だけにある環境 -/
  | concreteEnv
  deriving Repr, BEq, DecidableEq

/-- 前提型・観測型の証明の状態。名前は ``` ``名前`` ``` で書く（エラボレートの時点で、存在しない名前は誤りになる）。
`deviations` は、その ID の `@[deviation]` の定数のすべて（R 課題ごとに定数を分けてよい）。 -/
inductive TypedEvidence where
  /-- 偽を証明済み: 差異を外した R 課題の否定の定理（`¬ Refines …`。W 課題の必要性。obligation-check の G9 の形） -/
  | refuted (deviations : NEList Name) (necessity : NEList Name)
  /-- 被覆: 必要な差異の述語 `coverer` が、この差異を覆う定理（`Machine.Preserves.Covers coverer d`・`Covers₂`） -/
  | covered (deviations : NEList Name) (coverer : Name) (covers : NEList Name)
  /-- 未証明: 前提で制限して証明したが、必要性（偽）も一致（真）もまだ示していない。理由と、予定の W 課題。
  Lean に述語がまだ無ければ `deviations` は空 -/
  | pending (deviations : List Name) (reason : NEString) (wTask : Option ObligationId)
  deriving Repr

/-- 未確定の差異の証明の状態。 -/
inductive UndeterminedEvidence where
  /-- 未証明（前提で制限して証明した）。理由と、予定の W 課題 -/
  | pending (reason : NEString) (wTask : Option ObligationId)
  /-- 形式化していない: 命題をまだ書けない主張（`opaque … : Prop`）と、確定させる作業 -/
  | unformalized (claim : Name) (resolution : NEString)
  deriving Repr

/-- 前提型の差異。 -/
structure PreGap where
  /-- 述語が掛かる側 -/
  side : PreSide
  /-- 前提（表の「前提」の列） -/
  premise : NEString
  evidence : TypedEvidence
  /-- 差異を仮定に持つ R 課題（予定を含む） -/
  rTasks : NEList ObligationId
  /-- 前提を破ったときの影響と、その理由 -/
  impact : Impact
  impactReason : NEString
  /-- Lean 側（箇所の印・裏付けの宣言）を完了させる作業項目（影響の表の列。TR-K の段階導入） -/
  backlog : NEList BacklogId
  deriving Repr

/-- 観測型の差異。 -/
structure ObsGap where
  /-- 成分（表の「前提」の列） -/
  component : NEString
  evidence : TypedEvidence
  /-- 差異を成分に持つ R 課題（予定を含む） -/
  rTasks : NEList ObligationId
  backlog : List BacklogId := []
  deriving Repr

/-- モデル外の差異（証明の状態は「形式化していない」だけ）。 -/
structure OutOfModelGap where
  /-- モデル外とする理由（表の「前提」の列） -/
  reason : NEString
  /-- 主張（`opaque claim : Prop`） -/
  claim : Name
  /-- 確定させる作業（無ければ空） -/
  resolution : String := ""
  backlog : List BacklogId := []
  deriving Repr

/-- `Spec` の PRE・INV の外での振る舞い（差異ではない。証明の状態は「PRE の外」だけ）。 -/
structure OutsidePreGap where
  /-- それを除く `Spec` の前提（表の「前提」の列） -/
  excludingPre : NEString
  /-- 前提の述語（Lean にまだ無ければ空） -/
  pre : List Name
  backlog : List BacklogId := []
  deriving Repr

/-- 未確定の差異。 -/
structure UndeterminedGap where
  evidence : UndeterminedEvidence
  backlog : List BacklogId := []
  deriving Repr

/-- ギャップの本体。種類ごとに、要る欄と許す証明の状態だけを持つ。 -/
inductive Body where
  | pre (g : PreGap)
  | observational (g : ObsGap)
  | outOfModel (g : OutOfModelGap)
  | outsidePre (g : OutsidePreGap)
  | undetermined (g : UndeterminedGap)
  deriving Repr

/-- JSON の値。 -/
def TypedEvidence.code : TypedEvidence → String
  | .refuted .. => "refuted"
  | .covered .. => "covered"
  | .pending .. => "pending"

/-- 差異の述語・成分。 -/
def TypedEvidence.deviations : TypedEvidence → List Name
  | .refuted ds _ | .covered ds _ _ => ds.toList
  | .pending ds _ _ => ds

end Gap

open Gap in
/-- ギャップの登録の値。 -/
structure Gap where
  /-- `D-NNN`（`Abstraction`）/ `T-NNN`（`Refinement`） -/
  id : GapId
  /-- 箇所（仕様文書・意思決定記録の節） -/
  sites : NEList DocRef
  body : Body
  deriving Repr

namespace Gap

/-- ID の文字列。 -/
def idStr (g : Gap) : String := g.id.val

/-- 種類。 -/
def kind (g : Gap) : GapKind :=
  match g.body with
  | .pre p =>
    match p.side with
    | .abstract => .pre
    | .concreteInput => .preConcreteInput
    | .concreteState => .preConcreteState
    | .concreteEnv => .preConcreteEnv
  | .observational _ => .observational
  | .outOfModel _ => .outOfModel
  | .outsidePre _ => .outsidePre
  | .undetermined _ => .undetermined

/-- 種類ごとの本文（前提型: 前提、観測型: 成分、モデル外: 理由、PRE の外: それを除く `Spec` の前提、未確定: 空）。 -/
def premise (g : Gap) : String :=
  match g.body with
  | .pre p => p.premise.val
  | .observational o => o.component.val
  | .outOfModel m => m.reason.val
  | .outsidePre x => x.excludingPre.val
  | .undetermined _ => ""

/-- 前提型・観測型の証明の状態。 -/
def typedEvidence? (g : Gap) : Option TypedEvidence :=
  match g.body with
  | .pre p => some p.evidence
  | .observational o => some o.evidence
  | _ => none

/-- 前提型・観測型の差異の述語・成分。 -/
def deviations (g : Gap) : List Name := (g.typedEvidence?.map TypedEvidence.deviations).getD []

/-- 差異を仮定・成分に持つ R 課題。 -/
def rTasks (g : Gap) : List String :=
  match g.body with
  | .pre p => p.rTasks.toList.map (·.val)
  | .observational o => o.rTasks.toList.map (·.val)
  | _ => []

/-- 前提型の差異の影響と、その理由。 -/
def impact (g : Gap) : Option (Impact × String) :=
  match g.body with
  | .pre p => some (p.impact, p.impactReason.val)
  | _ => none

/-- Lean 側を完了させる作業項目。 -/
def backlog (g : Gap) : List String :=
  let ids := match g.body with
    | .pre p => p.backlog.toList
    | .observational o => o.backlog
    | .outOfModel m => m.backlog
    | .outsidePre x => x.backlog
    | .undetermined u => u.backlog
  ids.map (·.val)

/-- 形式化していない主張（モデル外・未確定の `unformalized`）。 -/
def claim? (g : Gap) : Option Name :=
  match g.body with
  | .outOfModel m => some m.claim
  | .undetermined { evidence := .unformalized c _, .. } => some c
  | _ => none

/-- 証明の状態の JSON の値。 -/
def evidenceCode (g : Gap) : String :=
  match g.body with
  | .pre p => p.evidence.code
  | .observational o => o.evidence.code
  | .outOfModel _ => "unformalized"
  | .outsidePre _ => "excluded_by"
  | .undetermined { evidence := .pending .., .. } => "pending"
  | .undetermined { evidence := .unformalized .., .. } => "unformalized"

/-- 証明の状態の、文書の表に出す名前。 -/
def evidenceLabel (g : Gap) : String :=
  match g.evidenceCode with
  | "refuted" => "偽を証明済み"
  | "covered" => "被覆"
  | "pending" => "未証明"
  | "unformalized" => "形式化していない"
  | _ => "PRE の外"

/-- 裏付けの宣言の名前（`@[gap]` を付けるもの）。 -/
def witnesses (g : Gap) : List Name :=
  match g.body with
  | .pre { evidence := e, .. } | .observational { evidence := e, .. } =>
    match e with
    | .refuted _ ns => ns.toList
    | .covered _ _ ns => ns.toList
    | .pending .. => []
  | .outOfModel m => [m.claim]
  | .outsidePre x => x.pre
  | .undetermined { evidence := .unformalized c _, .. } => [c]
  | .undetermined { evidence := .pending .., .. } => []

/-- 未証明の理由。 -/
def pendingReason (g : Gap) : String :=
  match g.typedEvidence? with
  | some (.pending _ r _) => r.val
  | _ =>
    match g.body with
    | .undetermined { evidence := .pending r _, .. } => r.val
    | _ => ""

/-- 被覆の差異の述語。 -/
def coverer? (g : Gap) : Option Name :=
  match g.typedEvidence? with
  | some (.covered _ c _) => some c
  | _ => none

/-- PRE の外の前提の述語。 -/
def excludedPre (g : Gap) : List Name :=
  match g.body with
  | .outsidePre x => x.pre
  | _ => []

/-- 未証明か。 -/
def isPending (g : Gap) : Bool := g.evidenceCode == "pending"

/-- 予定を含む W 課題（`pending` の予定）。`refuted`・`covered` の W 課題は、裏付けの定理の `@[obligation]` から引く。 -/
def plannedW (g : Gap) : Option String :=
  match g.typedEvidence? with
  | some (.pending _ _ w) => w.map (·.val)
  | _ =>
    match g.body with
    | .undetermined { evidence := .pending _ w, .. } => w.map (·.val)
    | _ => none

/-- 確定させる作業（`unformalized` の作業、未確定の `pending` の理由）。 -/
def resolution (g : Gap) : String :=
  match g.body with
  | .outOfModel m => m.resolution
  | .undetermined { evidence := .unformalized _ res, .. } => res.val
  | .undetermined { evidence := .pending r _, .. } => r.val
  | _ => ""

end Gap

/-! ## 値の読み取り

登録の値は、評価せずに式から読む（道具は `importModules` した環境だけを持つため）。
構築子・文字列リテラル・名前（``` ``x`` ```）・`List`・`Option`・`Prod` の組み合わせだけを受け付ける。
頭部が構築子でない定数（構造体の既定値など）は、定義を展開して読む。
-/

namespace Gap

namespace GapExpr

/-- 頭部が構築子でない定義なら、展開して β 簡約する（最大 32 回）。 -/
def whnfLite (env : Environment) (e : Expr) : Expr := Id.run do
  let mut e := e.consumeMData.headBeta
  for _ in [0:32] do
    let .const c us := e.getAppFn.consumeMData | return e
    match env.find? c with
    | some (.defnInfo d) =>
      e := (d.value.instantiateLevelParams d.levelParams us).beta e.getAppArgs |>.consumeMData.headBeta
    | _ => return e
  return e

/-- 構築子の名前と、明示の引数（`nparams` を除く）。 -/
def ctor? (env : Environment) (e : Expr) : Option (Name × Array Expr) :=
  let e := whnfLite env e
  match e.getAppFn.consumeMData with
  | .const c _ =>
    match env.find? c with
    | some (.ctorInfo ci) =>
      let args := e.getAppArgs
      if args.size == ci.numParams + ci.numFields then some (c, args.extract ci.numParams args.size) else none
    | _ => none
  | _ => none

def str (env : Environment) (e : Expr) : Except String String :=
  match whnfLite env e with
  | .lit (.strVal s) => .ok s
  | _ => .error "expected a string literal (only definitions are unfolded; no function calls)"

partial def list {α : Type} (env : Environment) (f : Expr → Except String α) (e : Expr) :
    Except String (List α) :=
  match ctor? env e with
  | some (``List.nil, _) => .ok []
  | some (``List.cons, #[h, t]) => do return (← f h) :: (← list env f t)
  | _ => .error s!"expected a list literal, got {e}"

def option {α : Type} (env : Environment) (f : Expr → Except String α) (e : Expr) :
    Except String (Option α) :=
  match ctor? env e with
  | some (``Option.none, _) => .ok none
  | some (``Option.some, #[x]) => do return some (← f x)
  | _ => .error s!"expected none or some, got {e}"

def prod {α β : Type} (env : Environment) (f : Expr → Except String α) (g : Expr → Except String β)
    (e : Expr) : Except String (α × β) :=
  match ctor? env e with
  | some (``Prod.mk, #[a, b]) => do return (← f a, ← g b)
  | _ => .error s!"expected a pair, got {e}"

/-- `val` と証明の構築子（`NEString`・`GapId` など）の `val` を読み、形式を検査して作り直す。 -/
def checked {α : Type} (env : Environment) (what : String) (mk : String → Option α) (e : Expr) :
    Except String α := do
  match ctor? env e with
  | some (_, args) =>
    let some v := args[0]? | throw s!"expected a {what} literal, got {e}"
    let s ← str env v
    match mk s with
    | some x => return x
    | none => throw s!"{s.quote} is not a valid {what}"
  | none => throw s!"expected a {what} literal, got {e}"

def neString (env : Environment) (e : Expr) : Except String NEString :=
  checked env "NEString" (fun s => if h : s ≠ "" then some ⟨s, h⟩ else none) e

def gapId (env : Environment) (e : Expr) : Except String GapId :=
  checked env "GapId" (fun s => if h : GapId.valid s = true then some ⟨s, h⟩ else none) e

def obligationId (env : Environment) (e : Expr) : Except String ObligationId :=
  checked env "ObligationId" (fun s => if h : ObligationId.valid s = true then some ⟨s, h⟩ else none) e

def backlogId (env : Environment) (e : Expr) : Except String BacklogId :=
  checked env "BacklogId" (fun s => if h : BacklogId.valid s = true then some ⟨s, h⟩ else none) e

def neList {α : Type} (env : Environment) (f : Expr → Except String α) (e : Expr) : Except String (NEList α) :=
  match ctor? env e with
  | some (``NEList.mk, #[h, t]) => do return ⟨← f h, ← list env f t⟩
  | _ => .error s!"expected a non-empty list literal (ne![…]), got {e}"

partial def name (env : Environment) (e : Expr) : Except String Name :=
  match ctor? env e with
  | some (``Name.anonymous, _) => .ok .anonymous
  | some (``Name.str, #[p, s]) => do return .str (← name env p) (← str env s)
  | some (``Name.num, #[p, i]) => do
    let some k := (whnfLite env i).rawNatLit? | throw "expected a numeral in a name"
    return .num (← name env p) k
  | _ => .error s!"expected a name literal (``x``), got {e}"

def impact (env : Environment) (e : Expr) : Except String Impact :=
  match ctor? env e with
  | some (``Impact.outputOnly, _) => .ok .outputOnly
  | some (``Impact.abort, _) => .ok .abort
  | _ => .error s!"expected an Impact constructor, got {e}"

def preSide (env : Environment) (e : Expr) : Except String PreSide :=
  match ctor? env e with
  | some (``PreSide.abstract, _) => .ok .abstract
  | some (``PreSide.concreteInput, _) => .ok .concreteInput
  | some (``PreSide.concreteState, _) => .ok .concreteState
  | some (``PreSide.concreteEnv, _) => .ok .concreteEnv
  | _ => .error s!"expected a PreSide constructor, got {e}"

def typedEvidence (env : Environment) (e : Expr) : Except String TypedEvidence :=
  match ctor? env e with
  | some (``TypedEvidence.refuted, #[ds, ns]) => do
    return .refuted (← neList env (name env) ds) (← neList env (name env) ns)
  | some (``TypedEvidence.covered, #[ds, c, ns]) => do
    return .covered (← neList env (name env) ds) (← name env c) (← neList env (name env) ns)
  | some (``TypedEvidence.pending, #[ds, r, w]) => do
    return .pending (← list env (name env) ds) (← neString env r) (← option env (obligationId env) w)
  | _ => .error s!"expected a TypedEvidence constructor, got {e}"

def undeterminedEvidence (env : Environment) (e : Expr) : Except String UndeterminedEvidence :=
  match ctor? env e with
  | some (``UndeterminedEvidence.pending, #[r, w]) => do
    return .pending (← neString env r) (← option env (obligationId env) w)
  | some (``UndeterminedEvidence.unformalized, #[c, r]) => do
    return .unformalized (← name env c) (← neString env r)
  | _ => .error s!"expected an UndeterminedEvidence constructor, got {e}"

def docRef (env : Environment) (e : Expr) : Except String DocRef :=
  match ctor? env e with
  | some (``DocRef.mk, #[l, p, n]) => do
    let label ← neString env l
    let path ← neString env p
    let note ← str env n
    return { label, path, note }
  | _ => .error s!"expected a DocRef literal, got {e}"

def body (env : Environment) (e : Expr) : Except String Body := do
  let backlogs := list env (backlogId env)
  match ctor? env e with
  | some (``Body.pre, #[g]) =>
    match ctor? env g with
    | some (``PreGap.mk, #[side, premise, ev, rTasks, imp, reason, backlog]) =>
      let side ← preSide env side
      let premise ← neString env premise
      let ev ← typedEvidence env ev
      let rTasks ← neList env (obligationId env) rTasks
      let imp ← impact env imp
      let reason ← neString env reason
      let backlog ← neList env (backlogId env) backlog
      return .pre { side, premise, evidence := ev, rTasks, impact := imp, impactReason := reason, backlog }
    | _ => throw s!"expected a PreGap literal, got {g}"
  | some (``Body.observational, #[g]) =>
    match ctor? env g with
    | some (``ObsGap.mk, #[c, ev, rTasks, backlog]) =>
      let component ← neString env c
      let evidence ← typedEvidence env ev
      let rTasks ← neList env (obligationId env) rTasks
      let backlog ← backlogs backlog
      return .observational { component, evidence, rTasks, backlog }
    | _ => throw s!"expected an ObsGap literal, got {g}"
  | some (``Body.outOfModel, #[g]) =>
    match ctor? env g with
    | some (``OutOfModelGap.mk, #[r, c, res, backlog]) =>
      let reason ← neString env r
      let claim ← name env c
      let resolution ← str env res
      let backlog ← backlogs backlog
      return .outOfModel { reason, claim, resolution, backlog }
    | _ => throw s!"expected an OutOfModelGap literal, got {g}"
  | some (``Body.outsidePre, #[g]) =>
    match ctor? env g with
    | some (``OutsidePreGap.mk, #[x, pre, backlog]) =>
      let excludingPre ← neString env x
      let pre ← list env (name env) pre
      let backlog ← backlogs backlog
      return .outsidePre { excludingPre, pre, backlog }
    | _ => throw s!"expected an OutsidePreGap literal, got {g}"
  | some (``Body.undetermined, #[g]) =>
    match ctor? env g with
    | some (``UndeterminedGap.mk, #[ev, backlog]) =>
      let evidence ← undeterminedEvidence env ev
      let backlog ← backlogs backlog
      return .undetermined { evidence, backlog }
    | _ => throw s!"expected an UndeterminedGap literal, got {g}"
  | _ => throw s!"expected a Gap.Body constructor, got {e}"

def gap (env : Environment) (e : Expr) : Except String Gap :=
  match ctor? env e with
  | some (``Gap.mk, #[id, sites, b]) => do
    let id ← gapId env id
    let sites ← neList env (docRef env) sites
    let body ← body env b
    return { id, sites, body }
  | _ => .error s!"expected a Trace.Gap literal, got {e}"

end GapExpr

/-- 定数の値を `Gap` として読む。 -/
def ofConst? (env : Environment) (n : Name) : Except String Gap :=
  match env.find? n with
  | some (.defnInfo d) =>
    if d.type.consumeMData.isConstOf ``Gap then GapExpr.gap env d.value
    else .error s!"{n} must have type Trace.Gap"
  | some _ => .error s!"{n} must be a definition of type Trace.Gap"
  | none => .error s!"unknown constant {n}"

/-- `@[gap_entry]`: ギャップの登録の宣言。付けた時点で、値を式から読めることを確かめる（種類ごとの欄と証明の状態の
組み合わせは型が表すので、ここでは検査しない）。 -/
initialize gapEntryAttr : TagAttribute ←
  registerTagAttribute `gap_entry "ギャップの登録の宣言（型 Trace.Gap の定数）" fun decl => do
    match Gap.ofConst? (← getEnv) decl with
    | .error e => throwError "@[gap_entry]: {e}"
    | .ok _ => pure ()

/-- 登録の宣言（名前順）と、その値。読めない宣言は誤りとして返す。 -/
def gapEntries (env : Environment) : Array (Name × Except String Gap) :=
  let names := (gapEntryAttr.ext.toEnvExtension.getState env).importedEntries.foldl
    (fun acc es => acc ++ es) (gapEntryAttr.ext.getState env).toArray
  (names.qsort fun a b => a.toString < b.toString).map fun n => (n, Gap.ofConst? env n)

/-- `@[gap]` の印を付けた定数（名前順）と、その ID。 -/
def gapMarkers (env : Environment) : Array (Name × Array String) := Id.run do
  let mut out := #[]
  for (n, _) in env.constants.toList do
    if let some ids := gapAttr.getParam? env n then out := out.push (n, ids)
  return out.qsort fun a b => a.1.toString < b.1.toString

/-- `@[deviation]` を付けた定数（名前順）と、その ID。 -/
def deviationConsts (env : Environment) : Array (Name × Array String) := Id.run do
  let mut out := #[]
  for (n, _) in env.constants.toList do
    if let some ids := deviationAttr.getParam? env n then out := out.push (n, ids)
  return out.qsort fun a b => a.1.toString < b.1.toString

/-- 登録の宣言の docstring（Markdown）。 -/
def gapDoc? (env : Environment) (n : Name) : Option String :=
  docStringExt.find? (level := .server) env n

/-- `DocRef` の JSON。 -/
def DocRef.toJson (r : DocRef) : Json :=
  Json.mkObj [("label", Lean.toJson r.label.val), ("path", Lean.toJson r.path.val), ("note", Lean.toJson r.note)]

/--
登録簿の JSON（`trace-dump` と `obligation-check` の `gaps`）。読めた宣言だけを、名前順に出す。
`markers` は `@[gap]` の印を付けた定数、`deviations` は `@[deviation]` を付けた定数（同じ ID のもの）。
`evidence` は証明の状態、`w_task` は W 課題（`refuted`・`covered` は裏付けの定理の `@[obligation]`、`pending` は予定）。
-/
def gapsJson (env : Environment) (moduleOf : Name → String) : Json := Id.run do
  let wTaskOf (g : Gap) : Option String :=
    match g.plannedW with
    | some w => some w
    | none => g.witnesses.findSome? fun t => (obligationAttr.getParam? env t).bind (·[0]?)
  let markers := gapMarkers env
  let devs := deviationConsts env
  let mut out := #[]
  for (n, r) in gapEntries env do
    let .ok g := r | continue
    let doc := gapDoc? env n
    let withId (xs : Array (Name × Array String)) :=
      Lean.toJson ((xs.filter fun (_, ids) => ids.contains g.idStr).map (·.1.toString))
    out := out.push <| Json.mkObj [
      ("name", Lean.toJson n.toString), ("module", Lean.toJson (moduleOf n)),
      ("id", Lean.toJson g.idStr), ("kind", Lean.toJson g.kind.code), ("kind_label", Lean.toJson g.kind.label),
      ("sites", Json.arr (g.sites.toList.toArray.map DocRef.toJson)),
      ("doc", Lean.toJson ((doc.getD "").trimAscii.toString)),
      ("premise", Lean.toJson g.premise), ("r_tasks", Lean.toJson g.rTasks),
      ("evidence", Json.mkObj [("state", Lean.toJson g.evidenceCode), ("label", Lean.toJson g.evidenceLabel),
        ("witnesses", Lean.toJson (g.witnesses.map (·.toString))),
        ("reason", Lean.toJson g.pendingReason),
        ("coverer", match g.coverer? with | some c => Lean.toJson c.toString | none => Json.null),
        ("pre", Lean.toJson (g.excludedPre.map Name.toString))]),
      ("w_task", match wTaskOf g with | some w => Lean.toJson w | none => Json.null),
      ("impact", match g.impact with
        | some (i, reason) => Json.mkObj [("kind", Lean.toJson i.code), ("label", Lean.toJson i.label),
            ("reason", Lean.toJson reason)]
        | none => Json.null),
      ("resolution", Lean.toJson g.resolution), ("backlog", Lean.toJson g.backlog),
      ("markers", withId markers), ("deviations", withId devs)]
  return Json.arr out

end Gap

end Trace
