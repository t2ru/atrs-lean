/-!
# LangSemantics.Java.JLocalDate

`java.time.LocalDate`（先発グレゴリオ暦、タイムゾーン無し）の暦日と演算。
通算日数（1970-01-01 を 0）を介して演算する。

- `LocalDate` は妥当でない日付を作れないので、妥当性（月が 1〜12、日がその月の日数の範囲）を型の証明フィールドで持つ
  （不正な状態を表現できない型。spec-pivot の ADR bf1b）。
- 通算日数から暦日への変換が妥当な暦日を返すことは、400 年の周期の 146097 日を自然数の計算のカーネルの評価で確かめる（`civilChunks`）。

lang: `dep:java.base#java.time.LocalDate`, `dep:java.base#java.time.temporal.ChronoUnit.YEARS`
-/

namespace LangSemantics.Java

namespace JLocalDate

/-- 閏年か（先発グレゴリオ暦）。 -/
def isLeapYear (y : Int) : Bool := (y % 4 == 0 && y % 100 != 0) || y % 400 == 0

/-- 月の日数。 -/
def daysInMonth (y : Int) (m : Nat) : Nat :=
  match m with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => if isLeapYear y then 29 else 28
  | _ => 0

/-- 妥当な暦日か（月が 1〜12、日がその月の日数の範囲）。 -/
def IsValid (y : Int) (m d : Nat) : Prop := 1 ≤ m ∧ m ≤ 12 ∧ 1 ≤ d ∧ d ≤ daysInMonth y m

instance (y : Int) (m d : Nat) : Decidable (IsValid y m d) := by unfold IsValid; infer_instance

/-- 閏年の判定は 400 年で繰り返す。 -/
theorem isLeapYear_add (y k : Int) : isLeapYear (y + 400 * k) = isLeapYear y := by
  unfold isLeapYear
  have h4 : (y + 400 * k) % 4 = y % 4 := by omega
  have h100 : (y + 400 * k) % 100 = y % 100 := by omega
  have h400 : (y + 400 * k) % 400 = y % 400 := by omega
  rw [h4, h100, h400]

theorem daysInMonth_add (y k : Int) (m : Nat) : daysInMonth (y + 400 * k) m = daysInMonth y m := by
  unfold daysInMonth; rw [isLeapYear_add]

/-- 400 年の周期の中の日 `doe`（0〜146096）から、周期の中の年（0〜399。3 月始まり）。 -/
def yoeOfDoe (doe : Int) : Int := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365

/-- 周期の中の日 `doe` から、3 月 1 日を 0 とする年の中の日（0〜365）。 -/
def doyOfDoe (doe : Int) : Int := doe - (365 * yoeOfDoe doe + yoeOfDoe doe / 4 - yoeOfDoe doe / 100)

/-- 年の中の日から、3 月を 0 とする月（0〜11）。 -/
def mpOfDoy (doy : Int) : Int := (5 * doy + 2) / 153

/-- 周期の中の日 `doe` の月（1〜12）。 -/
def civilMonth (doe : Int) : Int :=
  if mpOfDoy (doyOfDoe doe) < 10 then mpOfDoy (doyOfDoe doe) + 3 else mpOfDoy (doyOfDoe doe) - 9

/-- 周期の中の日 `doe` の日（1〜31）。 -/
def civilDay (doe : Int) : Int := doyOfDoe doe - (153 * mpOfDoy (doyOfDoe doe) + 2) / 5 + 1

/-- 自然数で書いた `yoeOfDoe`（周期の中の日は負でない）。 -/
def yoeN (doe : Nat) : Nat := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365

/-- 自然数で書いた `doyOfDoe`。 -/
def doyN (doe : Nat) : Nat := doe - (365 * yoeN doe + yoeN doe / 4 - yoeN doe / 100)

/-- 自然数で書いた 3 月始まりの月（0〜11）。 -/
def mpN (doe : Nat) : Nat := (5 * doyN doe + 2) / 153

/-- 自然数で書いた月（1〜12）。 -/
def monthN (doe : Nat) : Nat := if mpN doe < 10 then mpN doe + 3 else mpN doe - 9

/-- 自然数で書いた日。 -/
def dayN (doe : Nat) : Nat := doyN doe - (153 * mpN doe + 2) / 5 + 1

/-- 周期 0 での年（1・2 月は 3 月始まりの年の翌年）。 -/
def yearN (doe : Nat) : Nat := if monthN doe ≤ 2 then yoeN doe + 1 else yoeN doe

/-- 周期の中の日 `doe` で、周期の中の年が 0〜399、年の中の日が切り捨てなしに 0〜365 で求まり、年・月・日が妥当な暦日か。 -/
def civilValidN (doe : Nat) : Bool :=
  decide (365 * yoeN doe + yoeN doe / 4 - yoeN doe / 100 ≤ doe) && decide (yoeN doe / 100 ≤ yoeN doe / 4) &&
    decide (yoeN doe ≤ 399) && decide (doe ≤ 365 * yoeN doe + yoeN doe / 4 - yoeN doe / 100 + 365) &&
    decide (1 ≤ monthN doe) && decide (monthN doe ≤ 12) && decide (1 ≤ dayN doe) &&
    decide (dayN doe ≤ daysInMonth (yearN doe : Int) (monthN doe))

/-- 1000 日ずつの検査（周期の外の日は対象外）。 -/
def civilChunk (k : Nat) : Bool :=
  (List.range 1000).all fun i => decide (146096 < k * 1000 + i) || civilValidN (k * 1000 + i)

set_option maxRecDepth 20000 in
/-- 周期のすべての日（147 × 1000 日）で、年・月・日が妥当な暦日になる。 -/
theorem civilChunks : (List.range 147).all civilChunk = true := by decide +kernel

theorem civilValidN_of {n : Nat} (h : n ≤ 146096) : civilValidN n = true := by
  have hk := List.all_eq_true.mp civilChunks (n / 1000) (List.mem_range.mpr (by omega))
  have := List.all_eq_true.mp hk (n % 1000) (List.mem_range.mpr (by omega))
  rw [show n / 1000 * 1000 + n % 1000 = n by omega] at this
  simp only [Bool.or_eq_true, decide_eq_true_eq] at this
  rcases this with h' | h'
  · omega
  · exact h'

theorem yoeOfDoe_nat (n : Nat) : yoeOfDoe (n : Int) = ((yoeN n : Nat) : Int) := by
  unfold yoeOfDoe yoeN
  have e1 : (n : Int) / 1460 = ((n / 1460 : Nat) : Int) := by omega
  have e2 : (n : Int) / 36524 = ((n / 36524 : Nat) : Int) := by omega
  have e3 : (n : Int) / 146096 = ((n / 146096 : Nat) : Int) := by omega
  rw [e1, e2, e3]
  omega

/-- 周期の中の日の月・日は、自然数で書いたものに等しい。 -/
theorem civil_nat {n : Nat} (h : n ≤ 146096) :
    civilMonth (n : Int) = ((monthN n : Nat) : Int) ∧ civilDay (n : Int) = ((dayN n : Nat) : Int) := by
  have hc := civilValidN_of h
  simp only [civilValidN, Bool.and_eq_true, decide_eq_true_eq] at hc
  obtain ⟨⟨⟨⟨⟨⟨⟨hb, hq⟩, -⟩, -⟩, -⟩, -⟩, -⟩, -⟩ := hc
  have hY := yoeOfDoe_nat n
  have h4 : ((yoeN n : Nat) : Int) / 4 = ((yoeN n / 4 : Nat) : Int) := by omega
  have h100 : ((yoeN n : Nat) : Int) / 100 = ((yoeN n / 100 : Nat) : Int) := by omega
  have hdoy : doyOfDoe (n : Int) = ((doyN n : Nat) : Int) := by
    unfold doyOfDoe doyN; rw [hY, h4, h100]; omega
  have hmp : mpOfDoy ((doyN n : Nat) : Int) = ((mpN n : Nat) : Int) := by unfold mpOfDoy mpN; omega
  have hle : (153 * mpN n + 2) / 5 ≤ doyN n := by unfold mpN; omega
  refine ⟨?_, ?_⟩
  · unfold civilMonth monthN; rw [hdoy, hmp]; split <;> split <;> omega
  · unfold civilDay dayN; rw [hdoy, hmp]; omega

/-- 周期 `era` と周期の中の日 `doe` の暦日は妥当である。 -/
theorem civil_valid (era doe : Int) (h0 : 0 ≤ doe) (h1 : doe ≤ 146096) :
    IsValid (if civilMonth doe ≤ 2 then yoeOfDoe doe + era * 400 + 1 else yoeOfDoe doe + era * 400)
      (civilMonth doe).toNat (civilDay doe).toNat := by
  obtain ⟨n, rfl⟩ := Int.eq_ofNat_of_zero_le h0
  have hn : n ≤ 146096 := by omega
  obtain ⟨hm, hd⟩ := civil_nat hn
  have hc := civilValidN_of hn
  simp only [civilValidN, Bool.and_eq_true, decide_eq_true_eq] at hc
  obtain ⟨⟨⟨⟨⟨⟨⟨-, -⟩, -⟩, -⟩, m1⟩, m2⟩, d1⟩, d2⟩ := hc
  rw [hm, hd, yoeOfDoe_nat]
  simp only [Int.toNat_natCast]
  refine ⟨m1, m2, d1, ?_⟩
  have hy : daysInMonth (if ((monthN n : Nat) : Int) ≤ 2 then ((yoeN n : Nat) : Int) + era * 400 + 1
      else ((yoeN n : Nat) : Int) + era * 400) (monthN n) = daysInMonth (yearN n : Int) (monthN n) := by
    unfold yearN
    by_cases h2 : monthN n ≤ 2
    · have : ((monthN n : Nat) : Int) ≤ 2 := by omega
      rw [if_pos this, if_pos h2,
        show ((yoeN n : Nat) : Int) + era * 400 + 1 = ((yoeN n + 1 : Nat) : Int) + 400 * era by omega,
        daysInMonth_add]
    · have : ¬ (((monthN n : Nat) : Int) ≤ 2) := by omega
      rw [if_neg this, if_neg h2, show ((yoeN n : Nat) : Int) + era * 400 = ((yoeN n : Nat) : Int) + 400 * era by omega,
        daysInMonth_add]
  rw [hy]; exact d2

end JLocalDate

open JLocalDate in
/-- 暦日。`LocalDate` は妥当でない日付を作れないので、妥当性を型で持つ。 -/
structure JLocalDate where
  year : Int
  month : Nat
  day : Nat
  valid : IsValid year month day := by decide
  deriving Repr, DecidableEq

instance : BEq JLocalDate := ⟨fun a b => decide (a = b)⟩

namespace JLocalDate

/-- 年・月・日が等しい暦日は等しい（妥当性は証明なので、値を決めない）。 -/
theorem ext {x y : JLocalDate} (h1 : x.year = y.year) (h2 : x.month = y.month) (h3 : x.day = y.day) : x = y := by
  obtain ⟨_, _, _, _⟩ := x
  obtain ⟨_, _, _, _⟩ := y
  simp only at h1 h2 h3
  subst h1 h2 h3
  rfl

/-- `LocalDate.of(y, m, d)`。不正な日付は `none`（Java では `DateTimeException`）。 -/
def ofYMD? (y : Int) (m d : Nat) : Option JLocalDate :=
  if h : IsValid y m d then some ⟨y, m, d, h⟩ else none

/-- 通算日数（1970-01-01 = 0）。H. Hinnant の days_from_civil を、床除算（Lean の `Int` の `/`）で書いたもの。
年・日は 400 年（146097 日）の周期の中の位置に分ける。 -/
def toEpochDay (x : JLocalDate) : Int :=
  let y : Int := if x.month ≤ 2 then x.year - 1 else x.year
  let era : Int := y / 400
  let yoe : Int := y - era * 400
  let mp : Int := if x.month > 2 then (x.month : Int) - 3 else (x.month : Int) + 9
  let doy : Int := (153 * mp + 2) / 5 + (x.day : Int) - 1
  let doe : Int := yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468

/-- 周期 `era` と周期の中の日 `doe`（0〜146096）から暦日へ（civil_from_days）。 -/
def civilOfDoe (era doe : Int) (h0 : 0 ≤ doe) (h1 : doe ≤ 146096) : JLocalDate :=
  ⟨if civilMonth doe ≤ 2 then yoeOfDoe doe + era * 400 + 1 else yoeOfDoe doe + era * 400,
    (civilMonth doe).toNat, (civilDay doe).toNat, civil_valid era doe h0 h1⟩

/-- 通算日数から暦日へ（civil_from_days。床除算で書いたもの）。 -/
def ofEpochDay (z : Int) : JLocalDate :=
  civilOfDoe ((z + 719468) / 146097) ((z + 719468) % 146097) (Int.emod_nonneg _ (by decide))
    (by have := Int.emod_lt_of_pos (z + 719468) (by decide : (0 : Int) < 146097); omega)

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
