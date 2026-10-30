import Trace.Obligation
import Machine
import Spec
import SourceModel
import Abstraction
import TargetModel
import Refinement

/-!
# Tools.ObligationCheck

`lake exe obligation-check`

R 課題の形と付帯の義務（TR-G の Lean 側。ADR 0038）を判定し、結果を JSON で標準出力へ書く。
誤りがあれば標準エラーに書き、終了コード 1 で終わる。文書との突き合わせは `tools/ci/check_obligations.py` が行う。
追跡属性はモデルの層（`Spec`・`SourceModel`・`Abstraction`・`TargetModel`・`Refinement`）の定数にだけ付けてよい（G0）。
-/

open Lean

unsafe def main : IO UInt32 := do
  let env ← Trace.Dump.loadEnv #[`Machine, `Spec, `SourceModel, `Abstraction, `TargetModel, `Refinement]
  let r := Trace.Obligation.check env
  IO.println r.toJson.pretty
  for e in r.errors do IO.eprintln s!"obligation-check: {e}"
  for ri in r.rs do
    for e in ri.errors do IO.eprintln s!"obligation-check: {ri.name}: {e}"
  if r.errorCount == 0 then
    IO.eprintln s!"obligation-check: OK ({r.rs.size} refinement obligations)"
    return 0
  else
    return 1
