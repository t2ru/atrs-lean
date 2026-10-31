import Lean

/-!
# Trace.Attr

追跡属性を定義する。引数は文字列リテラルの並びで、環境拡張に `Array String` として記録する。
属性を付けた定義と同じモジュールでは使えないため、使う側は別のモジュールに置く。

| 属性 | 付ける対象 | 引数 |
| --- | --- | --- |
| `@[source "<locator>@<hash>", …]` | `SourceModel`、移植元の `LangSemantics` | 移植元ロケータと検査済みハッシュ |
| `@[target "<locator>@<hash>", …]` | `TargetModel`、移植先の `LangSemantics` | 移植先ロケータと検査済みハッシュ |
| `@[obligation "<ID>"]` | `Abstraction`・`Refinement`・`Spec` の証明課題の定理 | `ABS-NNN` / `REF-NNN` / `SPEC-NNN` |
| `@[deviation "<ID>"]` | 既知差異の述語・成分 | `D-NNN` / `T-NNN` |
| `@[gap "<ID>", …]` | ギャップが生じる `Spec`・`SourceModel`・`TargetModel` の定義（箇所の印） | `D-NNN` / `T-NNN` |
| `@[nondet "<ID>"]` | `Spec` の非決定性の選択の型 | `N-NNN` |
| `@[std_abs "<path>#<anchor>"]` | 標準の抽象化の関数（`Abstraction`・`Refinement`） | α・β の表の節 |
| `@[kernel "<path>#<anchor>"]` | 標準の抽象化の核（同一視する関係） | α・β の表の節 |
| `@[env_pre "<ID>"]` | 入口の機械の環境の前提（マスタ・設定の妥当性と入力の値域） | `MD-N` など |
| `@[spec_doc "<path>#<anchor>"]` | `Spec` の公開定義 | 仕様文書の節 |
| `@[no_source "<理由>"]` | 移植元に対応の無い `Spec` の定義 | 理由 |
| `@[ns_exception "<理由>"]` | モジュール名の下に置けない宣言（`layout-check` の例外 E3。`Trace.Layout`） | 技術的な必要性 |

ギャップの登録の宣言 `@[gap_entry]`（引数なし。値は型 `Trace.Gap`）は `Trace.Gap` にある。
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
/-- `@[gap "<ID>", …]` -/
syntax (name := gap) "gap" ppSpace str (atomic(", " str))* : attr
/-- `@[nondet "<ID>", …]` -/
syntax (name := nondet) "nondet" ppSpace str (atomic(", " str))* : attr
/-- `@[std_abs "<path>#<anchor>", …]` -/
syntax (name := std_abs) "std_abs" ppSpace str (atomic(", " str))* : attr
/-- `@[kernel "<path>#<anchor>", …]` -/
syntax (name := kernel) "kernel" ppSpace str (atomic(", " str))* : attr
/-- `@[env_pre "<ID>", …]` -/
syntax (name := env_pre) "env_pre" ppSpace str (atomic(", " str))* : attr
/-- `@[spec_doc "<path>#<anchor>", …]` -/
syntax (name := spec_doc) "spec_doc" ppSpace str (atomic(", " str))* : attr
/-- `@[no_source "<理由>"]` -/
syntax (name := no_source) "no_source" ppSpace str (atomic(", " str))* : attr
/-- `@[ns_exception "<理由>"]` -/
syntax (name := ns_exception) "ns_exception" ppSpace str (atomic(", " str))* : attr

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
  registerTraceAttr `obligation "証明課題の ID（ABS-NNN / REF-NNN / SPEC-NNN）" `Trace.obligationAttr
initialize deviationAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `deviation "既知差異の ID（D-NNN / T-NNN）" `Trace.deviationAttr
initialize gapAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `gap "ギャップが生じる定義の印（D-NNN / T-NNN）" `Trace.gapAttr
initialize nondetAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `nondet "Spec の非決定性の ID（N-NNN）" `Trace.nondetAttr
initialize stdAbsAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `std_abs "標準の抽象化の表の節（<path>#<anchor>）" `Trace.stdAbsAttr
initialize kernelAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `kernel "標準の抽象化の核の表の節（<path>#<anchor>）" `Trace.kernelAttr
initialize envPreAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `env_pre "入口の環境の前提の ID（MD-N など）" `Trace.envPreAttr
initialize specDocAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `spec_doc "仕様文書の節（<path>#<anchor>）" `Trace.specDocAttr
initialize noSourceAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `no_source "移植元に対応が無い理由" `Trace.noSourceAttr
/-- `layout-check` の例外（E3）。`trace-dump` の属性には含めない（追跡の対象ではないため）。 -/
initialize nsExceptionAttr : ParametricAttribute (Array String) ←
  registerTraceAttr `ns_exception "モジュール名の下に置けない理由" `Trace.nsExceptionAttr

/-- 追跡属性の一覧（JSON のキー名と属性）。キー名は属性名と同じ。 -/
def traceAttrs : List (String × ParametricAttribute (Array String)) :=
  [("source", sourceAttr), ("target", targetAttr), ("obligation", obligationAttr),
   ("deviation", deviationAttr), ("gap", gapAttr), ("nondet", nondetAttr), ("std_abs", stdAbsAttr),
   ("kernel", kernelAttr), ("env_pre", envPreAttr),
   ("spec_doc", specDocAttr), ("no_source", noSourceAttr)]

/-- 定義に付いた追跡属性を、属性名と引数の組で返す（`traceAttrs` の順）。 -/
def attrsOf (env : Environment) (decl : Name) : List (String × Array String) :=
  traceAttrs.filterMap fun (key, attr) => (attr.getParam? env decl).map (key, ·)

end Trace
