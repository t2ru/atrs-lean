import Trace.Attr

/-!
# Trace.Gap

`Spec` と移植元・移植先のモデルのギャップ（既知差異 `D-NNN` / `T-NNN` と、それに準じて明示するもの）の登録簿。
登録簿の正は Lean である。文書の表は、`trace-dump` の `gaps` から道具が生成する
（port-lang の `lang/lean/trace-attributes.md`、`spec/traceability.md`）。

- **登録の宣言**: ギャップごとに、型 `Trace.Gap` の定数を 1 つ置き、`@[gap_entry]` を付ける。
  説明（文書の表の「差異」「振る舞い」「状況」の列）は、その定数の docstring に Markdown で書く。
  値は、定義の展開だけで構築子と文字列リテラルの組み合わせになる式で書く（文字列の連結などの計算はできない）。
- **箇所の印**: ギャップが生じる `Spec`・`SourceModel`・`TargetModel` の定義に `@[gap "<ID>", …]` を付ける
  （`Trace.Attr`）。上流の版上げで印の付いた定義が変わると、見直すギャップが道具で出る。

- **証明の状態**（`Evidence`）: ギャップは、リファインメントの証明の中で証明できない部分である。それを公理や `sorry` で
  仮定せず（ギャップが実在すれば矛盾する）、状態を裏付ける Lean の宣言で示す。裏付けの宣言には `@[gap "<ID>"]` を付ける。
  - `refuted`: 差異を外した R 課題の否定の定理（偽を証明済み。W 課題の必要性）
  - `covered`: 必要な差異がこの差異を覆う定理（`Machine.Adequacy.Covers`）
  - `pending`: 前提で制限して証明したが、偽も真もまだ示していない（制限は仮定を強めるだけなので、安全に証明できる）
  - `unformalized`: Lean の命題として書けない主張。証明も公理も持たない `opaque` な命題（どの定理からも参照しない）
  - `excludedBy`: 差異ではない（`Spec` の PRE・INV の外。その前提の述語）

`@[gap_entry]` は、付けた時点で値を読み、種類と状態・欄の組み合わせを検査する（`Gap.problems`）。
docstring の有無・層・ID の重複、差異の定数と裏付けの宣言の照合は `obligation-check` が検査する（GK）。
-/

namespace Trace
open Trace.Attr

open Lean

namespace Gap

/-- ギャップの種類（references/docs/spec/architecture.md#リファインメントb-メソッド の差異の種類に、差異ではないが明示するものを足したもの）。 -/
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
  label : String
  /-- リポジトリのルートからのパスと、任意のアンカー（例: `docs/spec/pricing.md#税込み価格`） -/
  path : String
  /-- リンクの後に続ける注記（例: `（規範節）`） -/
  note : String := ""
  deriving Repr, BEq, Inhabited

/-- ギャップの証明の状態（ギャップが「証明できない部分」であることの裏付け）。名前は ``` ``名前`` ``` で書く
（エラボレートの時点で、存在しない名前は誤りになる）。 -/
inductive Evidence where
  /-- 偽を証明済み: 差異を外した R 課題の否定の定理（`¬ Refines …`。W 課題の必要性。obligation-check の G9 の形） -/
  | refuted (necessity : List Name)
  /-- 被覆: 必要な差異の述語 `coverer` が、この差異を覆う定理（`Machine.Adequacy.Covers coverer d`・`Covers₂`） -/
  | covered (coverer : Name) (covers : List Name)
  /-- 未確定: 前提で制限して証明したが、必要性（偽）も一致（真）もまだ示していない。理由と、予定の W 課題 -/
  | pending (reason : String) (wTask : Option String)
  /-- 形式化していない: Lean の命題として書けない主張（`opaque … : Prop`）と、確定させる作業（無ければ空） -/
  | unformalized (claim : Name) (resolution : String)
  /-- 差異ではない: `Spec` の PRE・INV の外。その前提の述語（Lean にまだ無ければ空） -/
  | excludedBy (pre : List Name)
  deriving Repr, Inhabited

/-- JSON の値。 -/
def Evidence.code : Evidence → String
  | .refuted _ => "refuted"
  | .covered .. => "covered"
  | .pending .. => "pending"
  | .unformalized .. => "unformalized"
  | .excludedBy _ => "excluded_by"

/-- 文書の表に出す名前。 -/
def Evidence.label : Evidence → String
  | .refuted _ => "偽を証明済み"
  | .covered .. => "被覆"
  | .pending .. => "未証明"
  | .unformalized .. => "形式化していない"
  | .excludedBy _ => "PRE の外"

/-- 裏付けの宣言の名前（`@[gap]` を付けるもの）。 -/
def Evidence.witnesses : Evidence → List Name
  | .refuted ns => ns
  | .covered _ ns => ns
  | .unformalized c _ => [c]
  | .excludedBy ns => ns
  | .pending .. => []

end Gap

open Gap in
/-- ギャップの登録の値。 -/
structure Gap where
  /-- `D-NNN`（`Abstraction`）/ `T-NNN`（`Refinement`） -/
  id : String
  kind : GapKind
  /-- 箇所（仕様文書・意思決定記録の節）。1 つ以上 -/
  sites : List DocRef
  /-- 種類ごとの本文（Markdown）。前提型: 前提、観測型: 成分、モデル外: 理由、PRE の外: それを除く `Spec` の前提 -/
  premise : String := ""
  /-- 前提型・観測型の差異の述語・成分（その ID の `@[deviation]` の定数のすべて。R 課題ごとに定数を分けてよい）。
  Lean にまだ無ければ空（状態は `pending`） -/
  deviations : List Name := []
  /-- 証明の状態 -/
  evidence : Evidence
  /-- 差異を仮定・成分に持つ R 課題（予定を含む）。前提型・観測型だけ -/
  rTasks : List String := []
  /-- 前提型の差異の影響と、その理由。前提型だけ -/
  impact : Option (Impact × String) := none
  /-- Lean 側（箇所の印・裏付けの宣言）を完了させる backlog 項目の ID。段階導入に使う -/
  backlog : List String := []
  deriving Repr, Inhabited

/-- `D-NNN` / `T-NNN` の形か。 -/
def Gap.idWellFormed (id : String) : Bool :=
  match id.toList with
  | [p, '-', a, b, c] => (p == 'D' || p == 'T') && a.isDigit && b.isDigit && c.isDigit
  | _ => false

/-- 種類ごとの必須の欄・禁じる欄の誤り（空なら正しい）。 -/
def Gap.problems (g : Gap) : List String := Id.run do
  let mut out := []
  unless Gap.idWellFormed g.id do out := out ++ [s!"id {g.id.quote} is not D-NNN / T-NNN"]
  if g.sites.isEmpty then out := out ++ ["sites must not be empty"]
  for s in g.sites do
    if s.label.isEmpty || s.path.isEmpty then out := out ++ ["sites: label and path must not be empty"]
  if g.premise.isEmpty && g.kind != .undetermined then
    out := out ++ [s!"premise is required for {g.kind.code}"]
  -- 種類と状態の組み合わせ
  let ok : Bool := match g.kind, g.evidence with
    | k, .refuted ns => k.isTyped && !ns.isEmpty
    | k, .covered _ ns => k.isTyped && !ns.isEmpty
    | k, .pending .. => k.isTyped || k == .undetermined
    | .outOfModel, .unformalized .. => true
    | .undetermined, .unformalized _ res => !res.isEmpty
    | .outsidePre, .excludedBy _ => true
    | _, _ => false
  unless ok do
    out := out ++ [s!"evidence {g.evidence.code} does not fit kind {g.kind.code} (or lacks its theorems / resolution)"]
  match g.evidence with
  | .refuted _ | .covered .. =>
    if g.deviations.isEmpty then
      out := out ++ [s!"evidence {g.evidence.code} needs the deviations (the @[deviation] constants)"]
  | _ => pure ()
  if !g.deviations.isEmpty && !g.kind.isTyped then
    out := out ++ [s!"deviations are only for pre / observational, not {g.kind.code}"]
  if g.kind.isTyped then
    if g.rTasks.isEmpty then out := out ++ [s!"rTasks is required for {g.kind.code}"]
  else
    unless g.rTasks.isEmpty do out := out ++ [s!"rTasks is only for pre / observational, not {g.kind.code}"]
  if g.kind.isPre then
    match g.impact with
    | none => out := out ++ [s!"impact is required for {g.kind.code}"]
    | some (_, reason) => if reason.isEmpty then out := out ++ ["impact: the reason must not be empty"]
    if g.backlog.isEmpty then out := out ++ [s!"backlog is required for {g.kind.code} (the impact table)"]
  else if g.impact.isSome then
    out := out ++ [s!"impact is only for pre, not {g.kind.code}"]
  if g.kind == .undetermined then
    unless g.premise.isEmpty do out := out ++ ["premise is not used for undetermined"]
  return out

/-- 予定を含む W 課題（`pending` の予定）。`refuted`・`covered` の W 課題は、裏付けの定理の `@[obligation]` から引く。 -/
def Gap.plannedW (g : Gap) : Option String :=
  match g.evidence with
  | .pending _ w => w
  | _ => none

/-- 確定させる作業（`unformalized`・`pending` の文）。 -/
def Gap.resolution (g : Gap) : String :=
  match g.evidence with
  | .unformalized _ res => res
  | .pending reason _ => if g.kind == .undetermined then reason else ""
  | _ => ""

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

def kind (env : Environment) (e : Expr) : Except String GapKind :=
  match ctor? env e with
  | some (``GapKind.pre, _) => .ok .pre
  | some (``GapKind.preConcreteInput, _) => .ok .preConcreteInput
  | some (``GapKind.preConcreteState, _) => .ok .preConcreteState
  | some (``GapKind.preConcreteEnv, _) => .ok .preConcreteEnv
  | some (``GapKind.observational, _) => .ok .observational
  | some (``GapKind.outOfModel, _) => .ok .outOfModel
  | some (``GapKind.outsidePre, _) => .ok .outsidePre
  | some (``GapKind.undetermined, _) => .ok .undetermined
  | _ => .error s!"expected a GapKind constructor, got {e}"

partial def name (env : Environment) (e : Expr) : Except String Name :=
  match ctor? env e with
  | some (``Name.anonymous, _) => .ok .anonymous
  | some (``Name.str, #[p, s]) => do return .str (← name env p) (← str env s)
  | some (``Name.num, #[p, i]) => do
    let some k := (whnfLite env i).rawNatLit? | throw "expected a numeral in a name"
    return .num (← name env p) k
  | _ => .error s!"expected a name literal (``x``), got {e}"

def evidence (env : Environment) (e : Expr) : Except String Evidence :=
  match ctor? env e with
  | some (``Evidence.refuted, #[ns]) => do return .refuted (← list env (name env) ns)
  | some (``Evidence.covered, #[c, ns]) => do return .covered (← name env c) (← list env (name env) ns)
  | some (``Evidence.pending, #[r, w]) => do return .pending (← str env r) (← option env (str env) w)
  | some (``Evidence.unformalized, #[c, r]) => do return .unformalized (← name env c) (← str env r)
  | some (``Evidence.excludedBy, #[ns]) => do return .excludedBy (← list env (name env) ns)
  | _ => .error s!"expected an Evidence constructor, got {e}"

def impact (env : Environment) (e : Expr) : Except String Impact :=
  match ctor? env e with
  | some (``Impact.outputOnly, _) => .ok .outputOnly
  | some (``Impact.abort, _) => .ok .abort
  | _ => .error s!"expected an Impact constructor, got {e}"

def docRef (env : Environment) (e : Expr) : Except String DocRef :=
  match ctor? env e with
  | some (``DocRef.mk, #[l, p, n]) => do return { label := ← str env l, path := ← str env p, note := ← str env n }
  | _ => .error s!"expected a DocRef literal, got {e}"

def gap (env : Environment) (e : Expr) : Except String Gap :=
  match ctor? env e with
  | some (``Gap.mk, #[id, k, sites, premise, devs, ev, rTasks, imp, backlog]) => do
    return {
      id := ← str env id, kind := ← kind env k, sites := ← list env (docRef env) sites
      premise := ← str env premise, deviations := ← list env (name env) devs
      evidence := ← evidence env ev, rTasks := ← list env (str env) rTasks
      impact := ← option env (prod env (impact env) (str env)) imp
      backlog := ← list env (str env) backlog }
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

/-- `@[gap_entry]`: ギャップの登録の宣言。付けた時点で値を読み、`Gap.problems` を検査する。 -/
initialize gapEntryAttr : TagAttribute ←
  registerTagAttribute `gap_entry "ギャップの登録の宣言（型 Trace.Gap の定数）" fun decl => do
    match Gap.ofConst? (← getEnv) decl with
    | .error e => throwError "@[gap_entry]: {e}"
    | .ok g =>
      let ps := g.problems
      unless ps.isEmpty do throwError "@[gap_entry] {g.id}: {"; ".intercalate ps}"

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
  Json.mkObj [("label", Lean.toJson r.label), ("path", Lean.toJson r.path), ("note", Lean.toJson r.note)]

/--
登録簿の JSON（`trace-dump` と `obligation-check` の `gaps`）。読めた宣言だけを、名前順に出す。
`markers` は `@[gap]` の印を付けた定数、`deviations` は `@[deviation]` を付けた定数（同じ ID のもの）。
`evidence` は証明の状態、`w_task` は W 課題（`refuted`・`covered` は裏付けの定理の `@[obligation]`、`pending` は予定）。
-/
def gapsJson (env : Environment) (moduleOf : Name → String) : Json := Id.run do
  let wTaskOf (g : Gap) : Option String :=
    match g.plannedW with
    | some w => some w
    | none => g.evidence.witnesses.findSome? fun t => (obligationAttr.getParam? env t).bind (·[0]?)
  let markers := gapMarkers env
  let devs := deviationConsts env
  let mut out := #[]
  for (n, r) in gapEntries env do
    let .ok g := r | continue
    let doc := gapDoc? env n
    let withId (xs : Array (Name × Array String)) :=
      Lean.toJson ((xs.filter fun (_, ids) => ids.contains g.id).map (·.1.toString))
    out := out.push <| Json.mkObj [
      ("name", Lean.toJson n.toString), ("module", Lean.toJson (moduleOf n)),
      ("id", Lean.toJson g.id), ("kind", Lean.toJson g.kind.code), ("kind_label", Lean.toJson g.kind.label),
      ("sites", Json.arr (g.sites.toArray.map DocRef.toJson)),
      ("doc", Lean.toJson ((doc.getD "").trimAscii.toString)),
      ("premise", Lean.toJson g.premise), ("r_tasks", Lean.toJson g.rTasks),
      ("evidence", Json.mkObj [("state", Lean.toJson g.evidence.code), ("label", Lean.toJson g.evidence.label),
        ("witnesses", Lean.toJson (g.evidence.witnesses.map (·.toString))),
        ("reason", Lean.toJson (match g.evidence with | .pending r _ => r | _ => "")),
        ("coverer", match g.evidence with | .covered c _ => Lean.toJson c.toString | _ => Json.null),
        ("pre", Lean.toJson (match g.evidence with | .excludedBy ns => ns.map Name.toString | _ => ([] : List String)))]),
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
