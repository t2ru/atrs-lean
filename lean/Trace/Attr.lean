import Lean

/-!
# Trace.Attr

追跡属性を定義する。引数は文字列リテラルの並びで、環境拡張に `Array String` として記録する。
属性を付けた定義と同じモジュールでは使えないため、使う側は別のモジュールに置く。

| 属性 | 付ける対象 | 引数 |
| --- | --- | --- |
| `@[source "<locator>@<hash>", …]` | `SourceModel`、移植元の `LangSemantics` | 移植元ロケータと検査済みハッシュ |
| `@[target "<locator>@<hash>", …]` | `TargetModel`、移植先の `LangSemantics` | 移植先ロケータと検査済みハッシュ |
| `@[obligation "<ID>"]` | `Abstraction`・`Refinement` の主定理 | `ABS-NNN` / `REF-NNN` |
| `@[deviation "<ID>"]` | 既知差異の述語・成分 | `D-NNN` / `T-NNN` |
| `@[spec_doc "<path>#<anchor>"]` | `Spec` の公開定義 | 仕様文書の節 |
| `@[no_source "<理由>"]` | 移植元に対応の無い `Spec` の定義 | 理由 |
-/

namespace Trace

open Lean

/-- `@[source "<locator>@<hash>", …]` -/
syntax (name := source) "source" ppSpace str (atomic(", " str))* : attr
/-- `@[target "<locator>@<hash>", …]` -/
syntax (name := target) "target" ppSpace str (atomic(", " str))* : attr
/-- `@[obligation "<ID>", …]` -/
syntax (name := obligation) "obligation" ppSpace str (atomic(", " str))* : attr
/-- `@[deviation "<ID>", …]` -/
syntax (name := deviation) "deviation" ppSpace str (atomic(", " str))* : attr
/-- `@[spec_doc "<path>#<anchor>", …]` -/
syntax (name := spec_doc) "spec_doc" ppSpace str (atomic(", " str))* : attr
/-- `@[no_source "<理由>"]` -/
syntax (name := no_source) "no_source" ppSpace str (atomic(", " str))* : attr

/-- 構文木に現れる文字列リテラルを、現れる順に集める。 -/
partial def collectStrLits (stx : Syntax) : Array Syntax :=
  if stx.isStrLit?.isSome then #[stx]
  else stx.getArgs.foldl (fun acc a => acc ++ collectStrLits a) #[]

/--
属性の構文から文字列引数を取り出す。空文字列は拒否する。
引数の区切りの `,` は、次が文字列リテラルのときだけ引数の区切りとみなす（`atomic`）。
そのため `@[spec_doc "…", no_source "…"]` のように、他の属性と並べて書ける。
-/
def parseStrArgs (attrName : Name) (stx : Syntax) : AttrM (Array String) := do
  let mut out := #[]
  for a in collectStrLits stx do
    let s := (a.isStrLit?).getD ""
    if s.isEmpty then throwErrorAt a "@[{attrName}]: empty string argument"
    out := out.push s
  if out.isEmpty then throwError "@[{attrName}]: at least one argument is required"
  return out

/-- 文字列引数を持つ追跡属性を登録する。 -/
def registerTraceAttr (attrName : Name) (descr : String) (ref : Name) :
    IO (ParametricAttribute (Array String)) :=
  registerParametricAttribute {
    name := attrName
    descr := descr
    ref := ref
    getParam := fun _ stx => parseStrArgs attrName stx
  }

initialize sourceAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `source "移植元ロケータと検査済みハッシュ" `Trace.sourceAttr
initialize targetAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `target "移植先ロケータと検査済みハッシュ" `Trace.targetAttr
initialize obligationAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `obligation "証明課題の ID（ABS-NNN / REF-NNN）" `Trace.obligationAttr
initialize deviationAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `deviation "既知差異の ID（D-NNN / T-NNN）" `Trace.deviationAttr
initialize specDocAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `spec_doc "仕様文書の節（<path>#<anchor>）" `Trace.specDocAttr
initialize noSourceAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `no_source "移植元に対応が無い理由" `Trace.noSourceAttr

/-- 追跡属性の一覧（JSON のキー名と属性）。キー名は属性名と同じ。 -/
def traceAttrs : List (String × ParametricAttribute (Array String)) :=
  [("source", sourceAttr), ("target", targetAttr), ("obligation", obligationAttr),
   ("deviation", deviationAttr), ("spec_doc", specDocAttr), ("no_source", noSourceAttr)]

/-- 定義に付いた追跡属性を、属性名と引数の組で返す（`traceAttrs` の順）。 -/
def attrsOf (env : Environment) (decl : Name) : List (String × Array String) :=
  traceAttrs.filterMap fun (key, attr) => (attr.getParam? env decl).map (key, ·)

end Trace
