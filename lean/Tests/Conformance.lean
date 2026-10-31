import ConformanceKit
import Spec

/-!
# Tests.Conformance

適合テストベクタ（`conformance/`）の実行器（スキル port-lang の `spec/conformance.md`）。

- ファイルの読み込み・形式の検査・`expected` の比較・共有入力・`modelDef` の選択は、スキルの `ConformanceKit` にある。
- ここには、[Spec] の値の表現の読み取り（日付・時刻）と、`format.*` の操作の割当（`formatOps`）を置く。
  共有入力（`fixtures`）を使う操作の表は、`Tests.ConformanceFare`・`Tests.ConformanceMaster` にある。
-/

open Lean Spec Spec.Prim ConformanceKit

open ConformanceKit.Runner ConformanceKit.SqlTable

open Spec.CodeList Spec.Config Spec.EnvPre Spec.MasterQuery Spec.Model Spec.Prim.Format Spec.Prim.Int Spec.Prim.Text Spec.Prim.Time

namespace Tests.Conformance

/-! ## 値の表現（`spec/conformance.md#値の表現`） -/

/-- `"yyyy-MM-dd"` -/
def decodeDate (s : String) : Except String Date :=
  match s.splitOn "-" with
  | [y, m, d] =>
    match (do Date.ofYmd? (← digits? y 4) (← digits? m 2) (← digits? d 2)) with
    | some v => .ok v
    | none => .error s!"invalid date: {s}"
  | _ => .error s!"invalid date: {s}"

/-- `"HH:mm"` -/
def decodeTime (s : String) : Except String HourMinute :=
  match s.splitOn ":" with
  | [h, m] =>
    match (do HourMinute.ofHm? (← digits? h 2) (← digits? m 2)) with
    | some v => .ok v
    | none => .error s!"invalid time: {s}"
  | _ => .error s!"invalid time: {s}"

/-- `"yyyy-MM-ddTHH:mm:ss"` -/
def decodeDateTime (s : String) : Except String DateTime :=
  match s.splitOn "T" with
  | [d, t] => do
    let date ← decodeDate d
    match t.splitOn ":" with
    | [h, m, sec] =>
      match digits? h 2, digits? m 2, digits? sec 2 with
      | some h, some m, some sec =>
        if hv : h ≤ 23 ∧ m ≤ 59 ∧ sec ≤ 59 then .ok ⟨date, h, m, sec, hv⟩
        else .error s!"invalid date-time: {s}"
      | _, _, _ => .error s!"invalid date-time: {s}"
    | _ => .error s!"invalid date-time: {s}"
  | _ => .error s!"invalid date-time: {s}"

/-! ## 操作の割当（`format`） -/

/-- `format.*` の操作。 -/
def formatOps : List (String × Op) := [
  ("format.fmtDate", fun i => do return .str (fmtDate (← decodeDate (← getStr i "date")))),
  ("format.fmtIsoDate", fun i => do return .str (fmtIsoDate (← decodeDate (← getStr i "date")))),
  ("format.fmtTime", fun i => do return .str (fmtTime (← decodeTime (← getStr i "time")))),
  ("format.fmtTimestamp", fun i => do return .str (fmtTimestamp (← decodeDateTime (← getStr i "dateTime")))),
  ("format.fmtYen", fun i => do return .str (fmtYen (← getNat i "amount"))),
  ("format.fmtPaymentDate", fun i => do return .str (fmtPaymentDate (← decodeDate (← getStr i "date")))),
  ("format.fullYearsBetween", fun i => do
    return toJson (Date.fullYearsBetween (← decodeDate (← getStr i "birthday")) (← decodeDate (← getStr i "date")))),
  ("format.parseHHmm", fun i => do
    return optJson (fun t => .str (fmtTime t)) (HourMinute.parseHHmm (← getStr i "text"))),
  ("format.addDays", fun i => do
    return optJson (fun d => .str (fmtIsoDate d)) ((← decodeDate (← getStr i "date")).addDays (← getInt i "days"))),
  ("format.daysBetween", fun i => do
    return toJson (Date.daysBetween (← decodeDate (← getStr i "from")) (← decodeDate (← getStr i "to"))))
]

end Tests.Conformance
