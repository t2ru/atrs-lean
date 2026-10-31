import LangSemantics.Java
import Spec.Prim.Date

/-!
# Abstraction.Prim.Date

[Source] の `LocalDate`（`LangSemantics.Java.JLocalDate`）の通算日数と、[Spec] の暦日（`Spec.Prim.Date`）の通算日数が一致する。
日付の α（`LocalDate` → `Date`）が順序と差を保つことに使う（R 課題 ABS-026 など）。

- `toEpochDay_eq_epochDay`: [Spec] の妥当な暦日 `D` について、同じ年月日の `JLocalDate` の `toEpochDay` は `D.epochDay` に等しい。
- 証明は、400 年の周期の和の閉じた式（`era_sum`）と、閏年の判定を 4・100・400 の倍数の数の差で書く式（`leap_count`）を使う。
-/

namespace Abstraction.Prim.Date
open Spec.Prim.Date
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String

open LangSemantics.Java Spec.Prim

/-- 400 年の周期で数えた年の日数の和は、閉じた式に等しい。 -/
theorem era_sum (y : Int) (_h : 0 ≤ y) :
    y / 400 * 146097 + ((y - y / 400 * 400) * 365 + (y - y / 400 * 400) / 4 - (y - y / 400 * 400) / 100) =
      365 * y + y / 4 - y / 100 + y / 400 := by
  have e4 : (y - y / 400 * 400) / 4 = y / 4 - y / 400 * 100 := by omega
  have e100 : (y - y / 400 * 400) / 100 = y / 100 - y / 400 * 4 := by omega
  rw [e4, e100]; omega

/-- 閏年の判定は、4・100・400 の倍数の数の差で書ける。 -/
theorem leap_count (y : Nat) (_h : 1 ≤ y) :
    ((if isLeap y then 1 else 0 : Nat) : Int) =
      ((y : Int) / 4 - ((y : Int) - 1) / 4) - ((y : Int) / 100 - ((y : Int) - 1) / 100) +
        ((y : Int) / 400 - ((y : Int) - 1) / 400) := by
  have hl : isLeap y = (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) := rfl
  rw [hl]
  by_cases h4 : y % 4 = 0 <;> by_cases h100 : y % 100 = 0 <;> by_cases h400 : y % 400 = 0 <;>
    simp [h4, h100, h400] <;> omega
/-- [Spec] の年の前の日数を整数で書く。 -/
theorem dby_int (y : Nat) (hy : 1 ≤ y) :
    (daysBeforeYear y : Int) = 365 * ((y : Int) - 1) + ((y : Int) - 1) / 4 - ((y : Int) - 1) / 100 + ((y : Int) - 1) / 400 := by
  obtain ⟨k, rfl⟩ : ∃ k, y = k + 1 := ⟨y - 1, by omega⟩
  simp only [daysBeforeYear, Nat.add_sub_cancel]
  have h1 : ((k + 1 : Nat) : Int) - 1 = (k : Int) := by omega
  rw [h1]
  have hle : k / 100 ≤ 365 * k + k / 4 := by omega
  rw [Int.natCast_add, Int.ofNat_sub hle, Int.natCast_add, Int.natCast_mul, Int.natCast_ediv, Int.natCast_ediv,
    Int.natCast_ediv]
  rfl

/-- [Spec] の通算日数を、年・月・日の部分の和で書く。 -/
theorem epochDay_int (D : Date) :
    D.epochDay = (daysBeforeYear D.year : Int) + (daysBeforeMonth D.year D.month : Int) + ((D.day : Int) - 1) - 719162 := by
  obtain ⟨y, m, d, ⟨_, _, _, _, hd1, _⟩⟩ := D
  simp only [Date.epochDay, Date.ordinal, Date.epochOrdinal]
  omega

/-- [Spec] の暦日と同じ年月日の `LocalDate` の通算日数は、[Spec] の通算日数に等しい。 -/
theorem toEpochDay_eq_epochDay (D : Date) :
    (JLocalDate.mk (D.year : Int) D.month D.day).toEpochDay = D.epochDay := by
  rw [epochDay_int]
  obtain ⟨y, m, d, ⟨hy1, hy2, hm1, hm2, hd1, hd2⟩⟩ := D
  simp only
  rw [dby_int y hy1]
  have hlc := leap_count y hy1
  have hs := era_sum (y : Int) (by omega)
  have hs1 := era_sum ((y : Int) - 1) (by omega)
  generalize hb : isLeap y = b at hlc
  have hm : m = 1 ∨ m = 2 ∨ m = 3 ∨ m = 4 ∨ m = 5 ∨ m = 6 ∨ m = 7 ∨ m = 8 ∨ m = 9 ∨ m = 10 ∨ m = 11 ∨ m = 12 := by omega
  rcases hm with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
  · simp only [JLocalDate.toEpochDay, daysBeforeMonth, hb]
    cases b <;> simp only [Bool.false_eq_true, ite_false, ite_true, Bool.and_true, Bool.and_false] at hlc ⊢
    all_goals (repeat' split)
    all_goals (try (rw [← Int.add_assoc, hs])) <;> (try (rw [← Int.add_assoc, hs1])) <;> clear hs hs1
    all_goals (clear hd2 hb
               try simp only [decide_eq_true_eq] at *
               generalize (y : Int) / 4 = a4 at hlc ⊢
               generalize ((y : Int) - 1) / 4 = b4 at hlc ⊢
               generalize (y : Int) / 100 = a100 at hlc ⊢
               generalize ((y : Int) - 1) / 100 = b100 at hlc ⊢
               generalize (y : Int) / 400 = a400 at hlc ⊢
               generalize ((y : Int) - 1) / 400 = b400 at hlc ⊢
               omega)

end Abstraction.Prim.Date
