import Machine.Sum

/-!
# Machine.Alt

同じ状態を共有する機能の機械の並置（スキルの ADR a303）。

`Machine.sum` は状態を積にするので、状態の成分を共有する 2 つの機能（例: 状態を読む照会と、同じ成分を書く登録）を
並置すると、それぞれが別の写しを持ってしまう。`alt` は、同じ状態 σ（具体側は同じ状態 τ）の上で、入力と出力を和にする。
両方の機械は INV と初期状態を共有し、貼り合わせの `J` も共有する。

| 定義・定理 | モジュール | 内容 |
| --- | --- | --- |
| `Machine.alt`（`Machine.Machine.alt`）・`Sound.alt`・`InitIs.alt`・`TotalUnder.alt` | `Machine.Machine.Alt` | 抽象機械の並置と、その義務（INV が等しいとき） |
| `Concrete.alt` | `Machine.Concrete.Alt` | 具体機械の並置 |
| `Glue.alt` | `Machine.Glue.Alt` | 貼り合わせの並置（`J` は左のもの。右の `J` と等しいことは定理の仮定に置く） |
| `Refines.alt` | `Machine.Refines.Alt` | 並置はリファインメントを保つ（`J` が等しく、左の初期状態が右の初期状態でもあるとき） |
| `Preserves.alt` | `Machine.Preserves.Alt` | 同じことを、全 R 課題に共通の 6 成分の束について示す（INV・`J`・具体側の初期状態が等しいとき） |

トップレベルでは、`alt` で並置した機能を、ほかの機能と `sum` で並べる（例: `A₁.sum (A₂.sum (search.alt reserve))`）。
-/
