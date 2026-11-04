import Spec.Prim.Int
import Spec.Prim.Date
import Spec.Prim.Time
import Spec.Prim.Format
import Spec.Prim.Text

/-!
# 基礎の演算と値（`Spec.Prim`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

すべての章が使う、業務に依存しない演算と値を定める。整数の除算・切上げ、暦日と時刻、表示の書式、文字列の長さと
文字クラスである。仕様の計算は厳密な整数で行い、浮動小数点数・ロケール・タイムゾーンに依存しない。

| 章 | 内容 |
| --- | --- |
| [`Spec.Prim.Int`](Prim/Int.lean) | 整数の除算と百分率: `floorDiv`・`ceilDiv`・`ceilTo`・`pct` |
| [`Spec.Prim.Date`](Prim/Date.lean) | 暦日 `Date`: `epochDay`・`addDays`・`daysBetween`・`fullYearsBetween`・`dayOfWeek` |
| [`Spec.Prim.Time`](Prim/Time.lean) | 時分 `HourMinute`・`parseHHmm`、到着時刻 `ArrivalTime`、日時 `DateTime` |
| [`Spec.Prim.Format`](Prim/Format.lean) | 表示の書式: `fmtDate`・`fmtIsoDate`・`fmtTime`・`fmtArrTime`・`fmtTimestamp`・`fmtYen`・`fmtPaymentDate` |
| [`Spec.Prim.Text`](Prim/Text.lean) | 文字列の長さ `scalarLen` と文字クラス |
-/
