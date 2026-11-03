import Trace

/-!
# Spec.Prim.Date

先発グレゴリオ暦の暦日（`lean/Spec/Prim/Date.lean#date`、ADR 6eb2）。タイムゾーンを持たない。

- 年は 1〜9999。通算日数 `ordinal`（0001-01-01 を 0 とする）と `epochDay`（1970-01-01 を 0 とする）で
  比較・加減算する。
- `ofOrdinal?` は、年と月を見積もって候補を調べ、結果を検算して返す。構成上、返した暦日の `ordinal` は
  引数と一致する（`ordinal_ofOrdinal?`）。範囲内の全日で値を返すこと（取りこぼしが無いこと）は、
  `lake test`（`Tests.DateExhaustive`）で 0001-01-01〜9999-12-31 の全日について確かめる。
-/

namespace Spec.Prim

namespace Date

/-!
## 暦日と時刻

**[Spec=Source]**（[ADR 6eb2](../../../docs/decision/6eb2-date-and-time-model.md)）[Spec] の Lean: [`Spec.Prim.Date`](Date.lean)、[`Spec.Prim.Time`](Time.lean)。

### Date

- `Date`: 先発グレゴリオ暦の年月日（年 1〜9999）。妥当性を型で保証する。
- 通算日数 `ordinal`（0001-01-01 を 0）と `epochDay`（1970-01-01 を 0）で比較・加減算する。順序は年月日の辞書順と一致する（`lt_iff_lex`）。
- `addDays(d, n)` は `epochDay` 上の加算で、範囲外なら無し。`daysBetween(a, b)` は `b − a` の日数。
- `fullYearsBetween(b, d)` は満年齢。誕生日の到来を `(month, day)` の辞書順で判定するので、閏日生まれは平年の 2 月 28 日には加齢せず 3 月 1 日に加齢する。`d < b` のときの値は使わない。
- 閏年・月末・年越しの境界は、Lean の例と、0001-01-01〜9999-12-31 の全日の検査（`lake test`。`lean/Tests/DateExhaustive.lean`）で確かめている。
-/

/-- 閏年。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def isLeap (y : Nat) : Bool := y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)

/-- 月の日数。月が 1〜12 でなければ 0。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def daysInMonth (y m : Nat) : Nat :=
  match m with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => if isLeap y then 29 else 28
  | _ => 0

/-- 年月日が暦日として妥当である。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def IsValidYmd (y m d : Nat) : Prop :=
  1 ≤ y ∧ y ≤ 9999 ∧ 1 ≤ m ∧ m ≤ 12 ∧ 1 ≤ d ∧ d ≤ daysInMonth y m

instance (y m d : Nat) : Decidable (IsValidYmd y m d) := by unfold IsValidYmd; infer_instance

end Date

open Date in
/-- 暦日。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
structure Date where
  year : Nat
  month : Nat
  day : Nat
  valid : IsValidYmd year month day
  deriving DecidableEq

namespace Date


/-- 年月日から暦日を作る。妥当でなければ無し。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def ofYmd? (y m d : Nat) : Option Date :=
  if h : IsValidYmd y m d then some ⟨y, m, d, h⟩ else none

instance : Repr Date where
  reprPrec d _ := s!"{d.year}-{d.month}-{d.day}"


/-- `y` 年 1 月 1 日より前の日数（0001-01-01 から数える）。 -/
def daysBeforeYear (y : Nat) : Nat :=
  365 * (y - 1) + (y - 1) / 4 - (y - 1) / 100 + (y - 1) / 400

/-- 年の日数。 -/
def daysInYear (y : Nat) : Nat := if isLeap y then 366 else 365

/-- `y` 年 `m` 月 1 日より前の、その年の日数（`1 ≤ m ≤ 13`）。 -/
def daysBeforeMonth (y m : Nat) : Nat :=
  let base :=
    match m with
    | 1 => 0 | 2 => 31 | 3 => 59 | 4 => 90 | 5 => 120 | 6 => 151 | 7 => 181
    | 8 => 212 | 9 => 243 | 10 => 273 | 11 => 304 | 12 => 334 | _ => 365
  if m > 2 && isLeap y then base + 1 else base


/-- 0001-01-01 を 0 とする通算日数。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def ordinal (d : Date) : Nat := daysBeforeYear d.year + daysBeforeMonth d.year d.month + (d.day - 1)

/-- 1970-01-01 の `ordinal`。 -/
def epochOrdinal : Nat := 719162

/-- 1970-01-01 を 0 とする通算日数。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def epochDay (d : Date) : Int := (d.ordinal : Int) - epochOrdinal

instance : LT Date := ⟨fun a b => a.ordinal < b.ordinal⟩
instance : LE Date := ⟨fun a b => a.ordinal ≤ b.ordinal⟩
instance (a b : Date) : Decidable (a < b) := inferInstanceAs (Decidable (a.ordinal < b.ordinal))
instance (a b : Date) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.ordinal ≤ b.ordinal))

/-- 年の候補から、`n` を含む年を探す（年は 1 以上）。 -/
def findYear (n : Nat) : List Nat → Option Nat
  | [] => none
  | y :: ys =>
    if 1 ≤ y ∧ daysBeforeYear y ≤ n ∧ n < daysBeforeYear y + daysInYear y then some y else findYear n ys

/-- その年の日数 `doy` を含む月を探す（12 月から順に調べる）。 -/
def findMonth (y doy : Nat) : List Nat → Option Nat
  | [] => none
  | m :: ms => if daysBeforeMonth y m ≤ doy then some m else findMonth y doy ms

/-- 通算日数から暦日を求める。範囲外なら無し。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def ofOrdinal? (n : Nat) : Option Date :=
  let y₀ := n * 400 / 146097 + 1
  match findYear n [y₀ - 1, y₀, y₀ + 1] with
  | none => none
  | some y =>
    let doy := n - daysBeforeYear y
    match findMonth y doy [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1] with
    | none => none
    | some m =>
      let dd := doy - daysBeforeMonth y m + 1
      if h : IsValidYmd y m dd then
        let d : Date := ⟨y, m, dd, h⟩
        if d.ordinal = n then some d else none
      else none

/-- `epochDay` から暦日を求める。範囲外なら無し。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def ofEpochDay? (k : Int) : Option Date :=
  let n := k + epochOrdinal
  if n < 0 then none else ofOrdinal? n.toNat

/-- `n` 日後（負なら前）の暦日。範囲外なら無し。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def addDays (d : Date) (n : Int) : Option Date := ofEpochDay? (d.epochDay + n)

/-- `b − a` の日数（負もありうる）。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def daysBetween (a b : Date) : Int := b.epochDay - a.epochDay

/-- 満年齢: 誕生日 `b` から日付 `d` までの満年数。`(month, day)` の辞書順で誕生日の到来を判定するので、
閏日生まれは平年の 2 月 28 日には加齢せず 3 月 1 日に加齢する。`d < b` のときの値は使わない（0 になる）。 -/
@[spec_doc "lean/Spec/Prim/Date.lean#date"]
def fullYearsBetween (b d : Date) : Nat :=
  let before := decide (d.month < b.month ∨ (d.month = b.month ∧ d.day < b.day))
  d.year - b.year - (if before then 1 else 0)

/-- 曜日。0 が日曜、6 が土曜（1970-01-01 は木曜）。 -/
@[spec_doc "lean/Spec/Prim/Format.lean#書式"]
def dayOfWeek (d : Date) : Nat := (d.ordinal + 1) % 7

/-! ## 性質 -/

theorem ordinal_ofOrdinal? {n : Nat} {d : Date} (h : ofOrdinal? n = some d) : d.ordinal = n := by
  unfold ofOrdinal? at h
  dsimp only at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · split at h
        · cases h; assumption
        · cases h
      · cases h

theorem epochDay_ofEpochDay? {k : Int} {d : Date} (h : ofEpochDay? k = some d) : d.epochDay = k := by
  unfold ofEpochDay? at h
  dsimp only at h
  split at h
  · cases h
  · have := ordinal_ofOrdinal? h
    simp only [epochDay, this]
    omega

/-- `addDays` は `epochDay` 上の加算である。 -/
theorem epochDay_addDays {d d' : Date} {n : Int} (h : d.addDays n = some d') :
    d'.epochDay = d.epochDay + n := epochDay_ofEpochDay? h

theorem daysBetween_addDays {d d' : Date} {n : Int} (h : d.addDays n = some d') : daysBetween d d' = n := by
  simp only [daysBetween, epochDay_addDays h]; omega

theorem daysBetween_self (d : Date) : daysBetween d d = 0 := by simp [daysBetween]

theorem daysBetween_swap (a b : Date) : daysBetween b a = - daysBetween a b := by
  simp only [daysBetween]; omega

theorem lt_iff_epochDay_lt (a b : Date) : a < b ↔ a.epochDay < b.epochDay := by
  show a.ordinal < b.ordinal ↔ _
  simp only [epochDay]; omega


/-! ## 通算日数と年月日の辞書順 -/

theorem daysBeforeYear_succ {y : Nat} (hy : 1 ≤ y) :
    daysBeforeYear (y + 1) = daysBeforeYear y + daysInYear y := by
  unfold daysBeforeYear daysInYear isLeap
  cases h₄ : y % 4 == 0 <;> cases h₁ : y % 100 != 0 <;> cases h₀ : y % 400 == 0 <;>
    simp_all <;> omega

theorem daysBeforeYear_mono {a b : Nat} (ha : 1 ≤ a) (h : a < b) :
    daysBeforeYear a + daysInYear a ≤ daysBeforeYear b := by
  obtain ⟨k, rfl⟩ : ∃ k, b = a + 1 + k := ⟨b - a - 1, by omega⟩
  induction k with
  | zero => rw [daysBeforeYear_succ ha]; exact Nat.le_refl _
  | succ k ih =>
    rw [show a + 1 + (k + 1) = (a + 1 + k) + 1 by omega, daysBeforeYear_succ (by omega)]
    have := ih (by omega); omega

theorem daysBeforeMonth_succ (y : Nat) {m : Nat} (h₁ : 1 ≤ m) (h₂ : m ≤ 12) :
    daysBeforeMonth y (m + 1) = daysBeforeMonth y m + daysInMonth y m := by
  have : m = 1 ∨ m = 2 ∨ m = 3 ∨ m = 4 ∨ m = 5 ∨ m = 6 ∨ m = 7 ∨ m = 8 ∨ m = 9 ∨ m = 10 ∨ m = 11 ∨
    m = 12 := by omega
  cases hl : isLeap y <;>
    rcases this with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [daysBeforeMonth, daysInMonth, hl]

theorem daysBeforeMonth_mono (y : Nat) {a b : Nat} (ha : 1 ≤ a) (h : a < b) (hb : b ≤ 13) :
    daysBeforeMonth y a + daysInMonth y a ≤ daysBeforeMonth y b := by
  obtain ⟨k, rfl⟩ : ∃ k, b = a + 1 + k := ⟨b - a - 1, by omega⟩
  induction k with
  | zero => rw [daysBeforeMonth_succ y ha (by omega)]; exact Nat.le_refl _
  | succ k ih =>
    rw [show a + 1 + (k + 1) = (a + 1 + k) + 1 by omega, daysBeforeMonth_succ y (by omega) (by omega)]
    have := ih (by omega) (by omega); omega

theorem daysBeforeMonth_thirteen (y : Nat) : daysBeforeMonth y 13 = daysInYear y := by
  cases hl : isLeap y <;> simp [daysBeforeMonth, daysInYear, hl]


/-- その年の中の日数（0 始まり）は、年の日数より小さい。 -/
theorem dayOfYear_lt (d : Date) : daysBeforeMonth d.year d.month + (d.day - 1) < daysInYear d.year := by
  have v := d.valid
  unfold IsValidYmd at v
  rcases Nat.lt_or_ge d.month 12 with h | h
  · have := daysBeforeMonth_mono d.year (a := d.month) (b := 13) v.2.2.1 (by omega) (by omega)
    rw [daysBeforeMonth_thirteen] at this; omega
  · have hm : d.month = 12 := by omega
    have := daysBeforeMonth_succ d.year (m := 12) (by omega) (by omega)
    rw [daysBeforeMonth_thirteen, ← hm] at this; omega

/-- 年月日の辞書順。 -/
def Lex (a b : Date) : Prop :=
  a.year < b.year ∨ (a.year = b.year ∧ (a.month < b.month ∨ (a.month = b.month ∧ a.day < b.day)))

theorem lt_of_lex {a b : Date} (h : Lex a b) : a < b := by
  show a.ordinal < b.ordinal
  have va := a.valid; have vb := b.valid
  unfold IsValidYmd at va vb
  unfold ordinal
  rcases h with hy | ⟨hy, hm | ⟨hm, hd⟩⟩
  · have := daysBeforeYear_mono va.1 hy
    have := a.dayOfYear_lt
    omega
  · rw [hy] at va ⊢
    have := daysBeforeMonth_mono b.year va.2.2.1 hm (by omega)
    omega
  · rw [hy, hm]; omega

theorem ext' {a b : Date} (hy : a.year = b.year) (hm : a.month = b.month) (hd : a.day = b.day) :
    a = b := by
  cases a; cases b; simp_all

/-- 通算日数は単射である。 -/
theorem ordinal_inj {a b : Date} (h : a.ordinal = b.ordinal) : a = b := by
  have trich : Lex a b ∨ Lex b a ∨ (a.year = b.year ∧ a.month = b.month ∧ a.day = b.day) := by
    unfold Lex; omega
  rcases trich with h' | h' | ⟨hy, hm, hd⟩
  · have : a.ordinal < b.ordinal := lt_of_lex h'; omega
  · have : b.ordinal < a.ordinal := lt_of_lex h'; omega
  · exact ext' hy hm hd

/-- 暦日の順序は、年月日の辞書順と一致する。 -/
theorem lt_iff_lex (a b : Date) : a < b ↔ Lex a b := by
  constructor
  · intro h
    have trich : Lex a b ∨ Lex b a ∨ (a.year = b.year ∧ a.month = b.month ∧ a.day = b.day) := by
      unfold Lex; omega
    rcases trich with h' | h' | ⟨hy, hm, hd⟩
    · exact h'
    · have : b.ordinal < a.ordinal := lt_of_lex h'
      have : a.ordinal < b.ordinal := h
      omega
    · rw [ext' hy hm hd] at h; exact absurd h (Nat.lt_irrefl _)
  · exact lt_of_lex

theorem epochDay_inj {a b : Date} (h : a.epochDay = b.epochDay) : a = b :=
  ordinal_inj (by simp only [epochDay] at h; omega)

/-- 通算日数から暦日への変換は、値を返せば一意である。 -/
theorem ofEpochDay?_epochDay_of_isSome {d : Date} {d' : Date} (h : ofEpochDay? d.epochDay = some d') : d' = d :=
  epochDay_inj (epochDay_ofEpochDay? h)


/-! ## 境界の例（閏年・月末・年越し） -/


/-- 例を書くための補助。 -/
def ymd! (y m d : Nat) (h : IsValidYmd y m d := by decide) : Date := ⟨y, m, d, h⟩

example : (ymd! 1970 1 1).epochDay = 0 := by decide
example : (ymd! 2026 10 29).epochDay = 20755 := by decide
example : isLeap 2000 = true ∧ isLeap 1900 = false ∧ isLeap 2024 = true ∧ isLeap 2026 = false := by decide
example : daysInMonth 2024 2 = 29 ∧ daysInMonth 2026 2 = 28 ∧ daysInMonth 2026 4 = 30 := by decide
example : ¬ IsValidYmd 2026 2 29 ∧ ¬ IsValidYmd 1900 2 29 ∧ IsValidYmd 2000 2 29 := by decide
example : (ymd! 2024 2 28).addDays 1 = some (ymd! 2024 2 29) := by decide
example : (ymd! 2026 2 28).addDays 1 = some (ymd! 2026 3 1) := by decide
example : (ymd! 2026 12 31).addDays 1 = some (ymd! 2027 1 1) := by decide
example : (ymd! 2026 11 1).addDays 120 = some (ymd! 2027 3 1) := by decide
example : (ymd! 2027 1 1).addDays (-1) = some (ymd! 2026 12 31) := by decide
example : (ymd! 9999 12 31).addDays 1 = none := by decide
example : (ymd! 1 1 1).addDays (-1) = none := by decide
example : daysBetween (ymd! 2026 11 1) (ymd! 2027 3 1) = 120 := by decide
example : fullYearsBetween (ymd! 2000 2 29) (ymd! 2001 2 28) = 0 := by decide
example : fullYearsBetween (ymd! 2000 2 29) (ymd! 2001 3 1) = 1 := by decide
example : fullYearsBetween (ymd! 2000 2 29) (ymd! 2004 2 29) = 4 := by decide
example : (ymd! 1970 1 1).dayOfWeek = 4 ∧ (ymd! 2026 11 10).dayOfWeek = 2 := by decide


end Date

end Spec.Prim
