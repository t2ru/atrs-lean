import Spec.Prim.Time

/-!
# Spec.Prim.Format

書式（`lean/Spec/Prim/Format.lean#書式`）。いずれもゼロ埋めの固定桁である（年は 1〜9999 なので 4 桁）。
-/

namespace Spec.Prim.Format
open Spec.Prim.Time

/-- `n` を十進で `w` 桁以上にゼロ埋めする。 -/
def padNat (w n : Nat) : String :=
  let s := toString n
  String.ofList (List.replicate (w - s.length) '0') ++ s

/-!
## 書式

**[Spec]** Lean: [`Spec.Prim.Format`](Format.lean)。いずれもゼロ埋めの固定桁である。

| 名前 | 形式 | 例 |
| --- | --- | --- |
| `fmtDate` | `yyyy/MM/dd` | `2026/10/29` |
| `fmtIsoDate` | `yyyy-MM-dd`（JSON・テストベクタ） | `2026-10-29` |
| `fmtTime` | `HH:mm` | `09:45` |
| `fmtArrTime` | `HH:mm`（到着時刻。24 時以降はそのまま） | `24:15` |
| `fmtTimestamp` | `yyyyMMddHHmmss` | `20261029213809` |
| `fmtYen` | 3 桁区切り（`###,###`） | `28,800` |
| `fmtPaymentDate` | `MM月dd日(E)`。曜日は日本語の 1 文字、括弧は半角 | `11月10日(火)` |

適合テストベクタは `conformance/shared/format/`（[conformance.md](../../../docs/spec/conformance.md#操作名)）。

**[Source]**（draft）原典 `DateTimeUtil.toFormatTimeString` は、長さ 3 以上の文字列 s を `s[0..2] ++ ":" ++ s[2..]` とする。`fmtPaymentDate` に当たる `#temporals.format(paymentDate,'MM月dd日(E)')` は要求の `Accept-Language` に従い、英語なら `Wed` などになる。予約入力・予約確認・予約失敗の画面の搭乗日（`#temporals.format(departureDate,'MM月dd日(E)')`）も同じ（既知差異 [D-019](../../../docs/spec/abstraction.md#既知差異)）。
-/

/-- `yyyy/MM/dd` -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtDate (d : Date) : String := s!"{padNat 4 d.year}/{padNat 2 d.month}/{padNat 2 d.day}"

/-- `yyyy-MM-dd`（JSON・テストベクタ） -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtIsoDate (d : Date) : String := s!"{padNat 4 d.year}-{padNat 2 d.month}-{padNat 2 d.day}"

/-- `HH:mm` -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtTime (t : HourMinute) : String := s!"{padNat 2 t.hour}:{padNat 2 t.minute}"

/-- 到着時刻の `HH:mm`（24 時以降はそのまま。例 `24:15`）。 -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtArrTime (t : ArrivalTime) : String := s!"{padNat 2 t.hour}:{padNat 2 t.minute}"

/-- `yyyyMMddHHmmss` -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtTimestamp (dt : DateTime) : String :=
  padNat 4 dt.date.year ++ padNat 2 dt.date.month ++ padNat 2 dt.date.day ++
    padNat 2 dt.hour ++ padNat 2 dt.minute ++ padNat 2 dt.second

/-- 下位の桁から 3 桁ごとに `,` を挟む（引数・結果とも下位の桁が先頭）。 -/
def insertCommas : List Char → List Char
  | a :: b :: c :: d :: rest => a :: b :: c :: ',' :: insertCommas (d :: rest)
  | l => l

/-- 3 桁区切り（`###,###`）。 -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtYen (n : Nat) : String := String.ofList (insertCommas (toString n).toList.reverse).reverse

/-- 曜日の 1 文字（日本語。0 が日曜）。 -/
def weekdayJa (w : Nat) : String :=
  match w with
  | 0 => "日" | 1 => "月" | 2 => "火" | 3 => "水" | 4 => "木" | 5 => "金" | _ => "土"

/-- `MM月dd日(E)`。曜日は常に日本語（[Source] は `Accept-Language` に従う。既知差異 D-019）。括弧は半角。 -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def fmtPaymentDate (d : Date) : String :=
  s!"{padNat 2 d.month}月{padNat 2 d.day}日({weekdayJa d.dayOfWeek})"

#guard fmtYen 0 == "0"
#guard fmtYen 999 == "999"
#guard fmtYen 1000 == "1,000"
#guard fmtYen 28800 == "28,800"
#guard fmtYen 1200000000 == "1,200,000,000"

end Spec.Prim.Format
