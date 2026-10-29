/-!
# LangSemantics.Java.LocalDate

`java.time.LocalDate`（先発グレゴリオ暦、タイムゾーン無し）の暦日と演算。
通算日数（1970-01-01 を 0）を介して演算する。

lang: `dep:java.base#java.time.LocalDate`, `dep:java.base#java.time.temporal.ChronoUnit.YEARS`
-/

namespace LangSemantics.Java

/-- 閏年か（先発グレゴリオ暦）。 -/
def isLeapYear (y : Int) : Bool := (y % 4 == 0 && y % 100 != 0) || y % 400 == 0

/-- 月の日数。 -/
def daysInMonth (y : Int) (m : Nat) : Nat :=
  match m with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => if isLeapYear y then 29 else 28
  | _ => 0

/-- 暦日。`ofYMD?` で作ると妥当性が保証される。 -/
structure JLocalDate where
  year : Int
  month : Nat
  day : Nat
  deriving Repr, BEq, DecidableEq

namespace JLocalDate

/-- `LocalDate.of(y, m, d)`。不正な日付は `none`（Java では `DateTimeException`）。 -/
def ofYMD? (y : Int) (m d : Nat) : Option JLocalDate :=
  if 1 ≤ m && m ≤ 12 && 1 ≤ d && d ≤ daysInMonth y m then some ⟨y, m, d⟩ else none

/-- 通算日数（1970-01-01 = 0）。H. Hinnant の days_from_civil。 -/
def toEpochDay (x : JLocalDate) : Int :=
  let y : Int := if x.month ≤ 2 then x.year - 1 else x.year
  let era : Int := (if y ≥ 0 then y else y - 399) / 400
  let yoe : Int := y - era * 400
  let mp : Int := if x.month > 2 then (x.month : Int) - 3 else (x.month : Int) + 9
  let doy : Int := (153 * mp + 2) / 5 + (x.day : Int) - 1
  let doe : Int := yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468

/-- 通算日数から暦日へ（civil_from_days）。 -/
def ofEpochDay (z : Int) : JLocalDate :=
  let z := z + 719468
  let era : Int := (if z ≥ 0 then z else z - 146096) / 146097
  let doe : Int := z - era * 146097
  let yoe : Int := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y : Int := yoe + era * 400
  let doy : Int := doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp : Int := (5 * doy + 2) / 153
  let d : Int := doy - (153 * mp + 2) / 5 + 1
  let m : Int := if mp < 10 then mp + 3 else mp - 9
  ⟨if m ≤ 2 then y + 1 else y, m.toNat, d.toNat⟩

/-- `plusDays(n)`。 -/
def plusDays (x : JLocalDate) (n : Int) : JLocalDate := ofEpochDay (x.toEpochDay + n)

/-- `minusDays(n)`。 -/
def minusDays (x : JLocalDate) (n : Int) : JLocalDate := ofEpochDay (x.toEpochDay - n)

/-- `isBefore`。 -/
def isBefore (a b : JLocalDate) : Bool := a.toEpochDay < b.toEpochDay
/-- `isAfter`。 -/
def isAfter (a b : JLocalDate) : Bool := a.toEpochDay > b.toEpochDay

/-- `ChronoUnit.DAYS.between(a, b)`。 -/
def daysBetween (a b : JLocalDate) : Int := b.toEpochDay - a.toEpochDay

/-- `ChronoUnit.YEARS.between(a, b)`（`a ≤ b` のとき、満年数）。 -/
def yearsBetween (a b : JLocalDate) : Int :=
  let base := b.year - a.year
  let beforeAnniversary := b.month < a.month || (b.month == a.month && b.day < a.day)
  if beforeAnniversary then base - 1 else base

/-- `yyyy/MM/dd` などの固定桁の書式に使う、ゼロ埋め。 -/
def pad (n : Nat) (width : Nat) : String :=
  let s := toString n
  String.ofList (List.replicate (width - s.length) '0') ++ s

/-- `DateTimeFormatter.ofPattern("yyyy/MM/dd")`（年は 4 桁以上の正の年のみ）。 -/
def formatYMD (x : JLocalDate) (sep : String := "/") : String :=
  pad x.year.toNat 4 ++ sep ++ pad x.month 2 ++ sep ++ pad x.day 2

end JLocalDate

end LangSemantics.Java
