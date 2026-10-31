import TargetModel
import Spec
import Trace
import Refinement.Gap

/-!
# Refinement

具体化証明課題（REF-NNN）。`TargetModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `TargetModel`, `Spec`, `LangSemantics.Rust`, `Machine`, `Trace`。

## トップレベルの主定理（本ファイル）

`Abstraction.lean` と同じ形で、本ファイルのトップレベルに置く（[ADR 91be](../docs/decision/91be-top-level-preserves-refines-abstracts.md)）。

| 定理 | 内容 |
| --- | --- |
| `Refinement.refines` | `Machine.Refines (Spec.machine.restrict dev) (TargetModel.machine.restrict devC) glue` |
| `Refinement.preserves` | `Machine.Preserves (Spec.machine.restrict dev) (TargetModel.machine.restrict devC) glue Spec.init env` |
| `Refinement.abstracts` | `Machine.Abstracts (Spec.machine.restrict dev) (TargetModel.machine.restrict devC) glue Spec.init env` |

- `TargetModel.machine` は、`Spec.machine` と同じ並びで、移植先の機能の具体機械を並置したもの（`Machine.Concrete.sum`）。
- `refines` は R 課題（REF-NNN）の主定理を `Machine.Refines.sum` で、`preserves` は R 課題ごとの束 `Machine.Preserves`（同じ課題 ID の `@[obligation]`）を `Machine.Preserves.sum` で並べて示す。`abstracts` は両者の組である。

`TargetModel` はまだ無い。最初の R 課題（REF-001・REF-004。[backlog eff6](../docs/backlog/eff6-target-model-fare-and-refinement.md)）で、
`TargetModel.machine` と主定理をここに置く。それまでは、主定理を `sorry` や公理で置かない（実装済みの範囲だけを主張する）。

## R 課題（下の名前空間）

| ID | 機能 | 主定理（`Machine.Refines`） | 束（`Machine.Preserves`） |
| --- | --- | --- | --- |
| — | （未着手） | — | — |
-/

namespace Refinement
end Refinement
