import Trace.Dump
import Machine
import Spec
import SourceModel
import Abstraction
import TargetModel
import Refinement

/-!
# Tools.AxiomCheck

`lake exe axiom-check`

モデルの全定義（`trace-dump` の対象と同じ）が依存する公理を集め、`propext`, `Quot.sound`,
`Classical.choice` 以外（`sorryAx`, `Lean.ofReduceBool`, 新規の `axiom` など）があれば失敗する
（port-lang の `lean/rules.md#全域性と安全性`）。`Tests` は対象にしない（`native_decide` を許すため）。
-/

open Lean

/-- 許可する公理。 -/
def allowedAxioms : List Name := [``propext, ``Quot.sound, ``Classical.choice]

unsafe def main : IO UInt32 := do
  let env ← Trace.Dump.loadEnv #[`Machine, `Spec, `SourceModel, `Abstraction, `TargetModel, `Refinement]
  let entries := Trace.Dump.dump env (Trace.Dump.defaultConfig)
  let mut bad := 0
  for e in entries do
    let axs ← Trace.Dump.disallowedAxioms env allowedAxioms e.name
    unless axs.isEmpty do
      IO.eprintln s!"axiom-check: {e.name} depends on {axs.toList}"
      bad := bad + 1
  if bad == 0 then
    IO.println s!"axiom-check: OK ({entries.size} definitions)"
    return 0
  else
    return 1
