import Abstraction.FlightSearch.Alpha
import Abstraction.Prim.Date

/-!
# Abstraction.FlightSearch.Format

ABS-011 の補題: 空席照会の書式（運賃の 3 桁区切り・時刻・日付）が、[Source] と [Spec] で一致すること。

- `formatGrouped_comma`: `DecimalFormat("###,###")`（区切り文字 `,`）は `fmtYen` と同じ。
- `toFormatTimeString_hm`・`toFormatTimeString_arr`: `HHmm` の時刻の文字列の `toFormatTimeString` は、
  読んだ時刻の `fmtTime`・`fmtArrTime` と同じ（時刻の文字列は α で定義される 4 桁の数字列）。
- `toFormatDateString_eq`: `toFormatDateString` は `fmtDate` と同じ。
-/

namespace Abstraction.FlightSearch.Format
open Abstraction.MasterData.AlphaLeaf Spec.Prim.Format Spec.Prim.Time LangSemantics.Java.DecimalFormat
open Machine.Kernel

open LangSemantics.Java Spec.Prim

theorem group3_comma : ∀ l : List Char, group3 ',' l = insertCommas l
  | a :: b :: c :: d :: rest => by simp only [group3, insertCommas, group3_comma (d :: rest)]
  | [] => rfl
  | [_] => rfl
  | [_, _] => rfl
  | [_, _, _] => rfl

/-- 区切り文字 `,` の `DecimalFormat("###,###")` は `fmtYen`。 -/
theorem formatGrouped_comma (n : Nat) : formatGrouped ',' (n : Int) = fmtYen n := by
  have h : ¬ ((n : Int) < 0) := by omega
  simp only [formatGrouped, h, if_false, groupNat, Int.toNat_natCast, group3_comma, fmtYen]

theorem formatJ32_comma {x : LangSemantics.Java.Int.J32} {n : Nat} (h : x.val = (n : Int)) :
    formatJ32 ',' x = fmtYen n := by
  simp only [formatJ32, h, formatGrouped_comma]

/-- 時分の 4 桁の文字列（`HHmm`）。 -/
def hhmm (h m : Nat) : String := padNat 2 h ++ padNat 2 m

/-- 到着時刻の範囲の各時分で、`HHmm` の文字列を読むと元の時分になり、`toFormatTimeString` は `HH:mm` になる。 -/
theorem hhmm_table : ∀ h < 48, ∀ m < 60,
    ArrivalTime.parseHHmm (hhmm h m) = ArrivalTime.ofHm? h m ∧
    (h < 24 → HourMinute.parseHHmm (hhmm h m) = HourMinute.ofHm? h m) ∧
    (SourceModel.FlightSearch.toFormatTimeString (some (hhmm h m))).toOption = some (some (padNat 2 h ++ ":" ++ padNat 2 m)) := by
  decide +kernel

/-! ## 時刻 -/

theorem toOption_ok {α : Type} {x : LangSemantics.Java.Exception.JResult α} {a : α} (h : x.toOption = some a) :
    x = .ok a := by
  cases x <;> simp_all [Except.toOption]

theorem arr_eq_hhmm {s : String} {t : ArrivalTime} (h : arrOfStr s = some t) : s = hhmm t.hour t.minute := by
  have hv := t.valid
  have ht := (hhmm_table t.hour (by omega) t.minute (by omega)).1
  have ht' : arrOfStr (hhmm t.hour t.minute) = some t := by
    unfold arrOfStr; rw [ht]; unfold ArrivalTime.ofHm?; rw [dif_pos hv]
  exact inj_of_kernel arrOfStr_kernel h ht'

theorem hm_eq_hhmm {s : String} {t : HourMinute} (h : hmOfStr s = some t) : s = hhmm t.hour t.minute := by
  have hv := t.valid
  have ht := (hhmm_table t.hour (by omega) t.minute (by omega)).2.1 (by omega)
  have ht' : hmOfStr (hhmm t.hour t.minute) = some t := by
    unfold hmOfStr; rw [ht]; unfold HourMinute.ofHm?; rw [dif_pos hv]
  exact inj_of_kernel hmOfStr_kernel h ht'

/-- 到着時刻の文字列の `toFormatTimeString` は、読んだ到着時刻の `fmtArrTime`。 -/
theorem toFormatTimeString_arr {s : String} {t : ArrivalTime} (h : arrOfStr s = some t) :
    SourceModel.FlightSearch.toFormatTimeString (some s) = .ok (some (fmtArrTime t)) := by
  rw [arr_eq_hhmm h]
  have hv := t.valid
  exact toOption_ok (hhmm_table t.hour (by omega) t.minute (by omega)).2.2

/-- 出発時刻の文字列の `toFormatTimeString` は、読んだ時刻の `fmtTime`。 -/
theorem toFormatTimeString_hm {s : String} {t : HourMinute} (h : hmOfStr s = some t) :
    SourceModel.FlightSearch.toFormatTimeString (some s) = .ok (some (fmtTime t)) := by
  rw [hm_eq_hhmm h]
  have hv := t.valid
  exact toOption_ok (hhmm_table t.hour (by omega) t.minute (by omega)).2.2

/-! ## 日付 -/

theorem beq_mod (y n : Nat) : (((y : Int) % (n : Int)) == 0) = ((y % n) == 0) := by
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]
  constructor <;> intro h <;> omega

theorem isLeapYear_nat (y : Nat) : JLocalDate.isLeapYear (y : Int) = Date.isLeap y := by
  unfold JLocalDate.isLeapYear Date.isLeap
  have h4 : (((y : Int) % 4) == 0) = ((y % 4) == 0) := beq_mod y 4
  have h100 : (((y : Int) % 100) == 0) = ((y % 100) == 0) := beq_mod y 100
  have h400 : (((y : Int) % 400) == 0) = ((y % 400) == 0) := beq_mod y 400
  simp only [bne, h4, h100, h400]
  have imp : (y % 400 == 0) = true → (y % 4 == 0) = true := by simp only [beq_iff_eq]; omega
  generalize (y % 4 == 0) = a at imp ⊢
  generalize (y % 100 == 0) = b
  generalize (y % 400 == 0) = c at imp ⊢
  cases a <;> cases b <;> cases c <;> simp_all

theorem daysInMonth_nat (y : Nat) : ∀ m, JLocalDate.daysInMonth (y : Int) m = Date.daysInMonth y m
  | 0 => rfl | 1 => rfl | 3 => rfl | 4 => rfl | 5 => rfl | 6 => rfl | 7 => rfl | 8 => rfl | 9 => rfl
  | 10 => rfl | 11 => rfl | 12 => rfl | _ + 13 => rfl
  | 2 => by simp only [JLocalDate.daysInMonth, Date.daysInMonth, isLeapYear_nat]

/-- `LocalDate` の写しが [Spec] の暦日 `D` に写るなら、その年月日は `D` の年月日。 -/
theorem dateOfJ_fields {j : JLocalDate} {D : Date} (h : dateOfJ j = some D) :
    j = ⟨(D.year : Int), D.month, D.day⟩ := by
  obtain ⟨hj, -⟩ := dateOfJ_eq_some h
  rw [hj, ← Abstraction.Prim.Date.toEpochDay_eq_epochDay D]
  obtain ⟨_, _, hm1, hm2, hd1, hd2⟩ := D.valid
  exact JLocalDate.ofEpochDay_toEpochDay _ hm1 hm2 hd1 (by simp only [daysInMonth_nat]; exact hd2)

/-- `toFormatDateString` は、写した暦日の `fmtDate`。 -/
theorem toFormatDateString_eq {j : JLocalDate} {D : Date} (h : dateOfJ j = some D) :
    SourceModel.FlightSearch.toFormatDateString (some j) = fmtDate D := by
  rw [dateOfJ_fields h]
  simp only [SourceModel.FlightSearch.toFormatDateString, JLocalDate.formatYMD, fmtDate, Int.toNat_natCast]
  rfl

end Abstraction.FlightSearch.Format
