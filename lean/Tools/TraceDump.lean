import Trace.Dump
import Spec
import SourceModel
import Abstraction
import TargetModel
import Refinement

/-!
# Tools.TraceDump

`lake exe trace-dump [--module <M>]… [--root <R>]…`

全定義の層・追跡属性・Merkle ハッシュ・参照を JSON で標準出力へ書く（port-lang の `lean/trace-attributes.md`）。

- 既定では、モデルの全モジュール（`Spec`, `SourceModel`, `Abstraction`, `TargetModel`, `Refinement`）を読む。
  `--module` を与えると、そのモジュールだけを読む。
- `--root` は、層として扱うトップレベル名前空間を足す（テストのフィクスチャ用）。
-/

open Lean

/-- 既定で読むモジュール。 -/
def defaultModules : Array Name := #[`Spec, `SourceModel, `Abstraction, `TargetModel, `Refinement]

/-- 引数を解釈する。 -/
def parseArgs : List String → Array Name → List String → Except String (Array Name × List String)
  | [], ms, rs => .ok (ms, rs)
  | "--module" :: m :: rest, ms, rs => parseArgs rest (ms.push m.toName) rs
  | "--root" :: r :: rest, ms, rs => parseArgs rest ms (rs ++ [r])
  | a :: _, _, _ => .error s!"unknown argument: {a}"

unsafe def main (args : List String) : IO UInt32 := do
  match parseArgs args #[] [] with
  | .error e =>
    IO.eprintln s!"trace-dump: {e}"
    return 2
  | .ok (ms, roots) =>
    let env ← Trace.Dump.loadEnv (if ms.isEmpty then defaultModules else ms)
    IO.println (Trace.Dump.dumpJson env (Trace.Dump.defaultConfig roots)).pretty
    return 0
