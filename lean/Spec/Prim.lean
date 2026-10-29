import Spec.Prim.Int
import Spec.Prim.Date
import Spec.Prim.Time
import Spec.Prim.Format
import Spec.Prim.Text

/-!
# Spec.Prim

[Spec] の基本演算（`docs/spec/domain-model.md#基本演算specprim`）。

| モジュール | 内容 |
| --- | --- |
| `Spec.Prim.Int` | `floorDiv`・`ceilDiv`・`ceilTo`・`pct` |
| `Spec.Prim.Date` | 暦日 `Date`、`epochDay`・`addDays`・`daysBetween`・`fullYearsBetween`・`dayOfWeek` |
| `Spec.Prim.Time` | 時分 `HourMinute`・`parseHHmm`、日時 `DateTime` |
| `Spec.Prim.Format` | `fmtDate`・`fmtIsoDate`・`fmtTime`・`fmtTimestamp`・`fmtYen`・`fmtPaymentDate` |
| `Spec.Prim.Text` | `scalarLen` と文字クラス |
-/
