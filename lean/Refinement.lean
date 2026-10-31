import TargetModel
import Spec
import Trace
import Refinement.Gap

/-!
# Refinement

具体化証明課題（REF-NNN）。`TargetModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `TargetModel`, `Spec`, `LangSemantics.Rust`, `Machine`, `Trace`。

## トップレベルの主定理（本ファイル）

`Abstraction.lean` と同じ形で、本ファイルのトップレベルに置く（[ADR a41d](../docs/decision/a41d-top-level-refines-adequate-and-source-side-gate.md)）。

| 定理 | 内容 |
| --- | --- |
| `Refinement.refines` | `Machine.Refines (Spec.machine.restrict dev) (TargetModel.machine.restrict devC) glue` |
| `Refinement.adequate` | `Machine.Adequate (Spec.machine.restrict dev) (TargetModel.machine.restrict devC) glue Spec.init env` |

- `TargetModel.machine` は、`Spec.machine` と同じ並びで、移植先の機能の具体機械を並置したもの（`Machine.Concrete.sum`）。
- 主定理は、R 課題（REF-NNN）ごとの義務の束 `Machine.Adequate`（同じ課題 ID の `@[obligation]`）を `Machine.Adequate.sum` で並べて示す。

`TargetModel` はまだ無い。最初の R 課題（REF-001・REF-004。[backlog eff6](../docs/backlog/eff6-target-model-fare-and-refinement.md)）で、
`TargetModel.machine` と主定理をここに置く。それまでは、主定理を `sorry` や公理で置かない（実装済みの範囲だけを主張する）。

## R 課題（下の名前空間）

| ID | 機能 | 主定理（`Machine.Refines`） | 義務の束（`Machine.Adequate`） |
| --- | --- | --- | --- |
| — | （未着手） | — | — |
-/

namespace Refinement
end Refinement
