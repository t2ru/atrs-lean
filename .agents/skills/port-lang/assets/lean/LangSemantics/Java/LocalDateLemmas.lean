import LangSemantics.Java.LocalDate

/-!
# LangSemantics.Java.LocalDateLemmas

`LocalDate` の通算日数の変換（`toEpochDay`・`ofEpochDay`）の性質。

- `toEpochDay_ofEpochDay`: すべての整数 `z` で `toEpochDay (ofEpochDay z) = z`。
- 400 年の周期の中の位置の範囲（`civil_bounds`）は、周期の 146097 日を、カーネルの評価（`decide +kernel`）で確かめる。
  `omega` は入れ子の床除算を扱いきれないため。
-/

namespace LangSemantics.Java

namespace JLocalDate

/-- 周期の中の日 `doe` について、年と年の中の日が範囲内か（`doe > 146096` は対象外）。 -/
def civilOk (doe : Nat) : Bool :=
  let yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  146096 < doe || yoe ≤ 399 && 365 * yoe + yoe / 4 - yoe / 100 ≤ doe && doe ≤ 365 * yoe + yoe / 4 - yoe / 100 + 365
/-- 1000 日ずつの検査。 -/
def chunkOk (k : Nat) : Bool := (List.range 1000).all fun i => civilOk (k * 1000 + i)
set_option maxRecDepth 20000 in
/-- 周期のすべての日（147 × 1000 日）で範囲内。 -/
theorem allChunks : (List.range 147).all chunkOk = true := by decide +kernel

theorem civil_bounds_nat (n : Nat) (h : n ≤ 146096) :
    let yoe := (n - n / 1460 + n / 36524 - n / 146096) / 365
    yoe ≤ 399 ∧ 365 * yoe + yoe / 4 - yoe / 100 ≤ n ∧ n ≤ 365 * yoe + yoe / 4 - yoe / 100 + 365 := by
  have hk := List.all_eq_true.mp allChunks (n / 1000) (List.mem_range.mpr (by omega))
  have := List.all_eq_true.mp hk (n % 1000) (List.mem_range.mpr (by omega))
  rw [show n / 1000 * 1000 + n % 1000 = n by omega] at this
  simp only [civilOk, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at this
  rcases this with h' | ⟨⟨a, b⟩, c⟩
  · omega
  · exact ⟨a, b, c⟩

theorem civil_bounds (doe : Int) (h0 : 0 ≤ doe) (h1 : doe ≤ 146096) :
    let yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    0 ≤ yoe ∧ yoe ≤ 399 ∧ 0 ≤ doe - (365 * yoe + yoe / 4 - yoe / 100) ∧
      doe - (365 * yoe + yoe / 4 - yoe / 100) ≤ 365 := by
  intro yoe
  obtain ⟨n, rfl⟩ := Int.eq_ofNat_of_zero_le h0
  obtain ⟨a, b, c⟩ := civil_bounds_nat n (by omega)
  have e1 : (n : Int) / 1460 = ((n / 1460 : Nat) : Int) := by omega
  have e2 : (n : Int) / 36524 = ((n / 36524 : Nat) : Int) := by omega
  have e3 : (n : Int) / 146096 = ((n / 146096 : Nat) : Int) := by omega
  generalize hN : (n - n / 1460 + n / 36524 - n / 146096) / 365 = Y at a b c
  have eY : yoe = (Y : Int) := by
    simp only [yoe, e1, e2, e3]
    omega
  rw [eY]
  have e4 : (Y : Int) / 4 = ((Y / 4 : Nat) : Int) := by omega
  have e5 : (Y : Int) / 100 = ((Y / 100 : Nat) : Int) := by omega
  rw [e4, e5]
  omega

theorem toEpochDay_civilOfDoe (era doe : Int) (h0 : 0 ≤ doe) (h1 : doe ≤ 146096) :
    (civilOfDoe era doe).toEpochDay = era * 146097 + doe - 719468 := by
  obtain ⟨y0, y1, d0, d1⟩ := civil_bounds doe h0 h1
  have hy : yoeOfDoe doe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 := rfl
  have hd : doyOfDoe doe = doe - (365 * yoeOfDoe doe + yoeOfDoe doe / 4 - yoeOfDoe doe / 100) := rfl
  rw [← hy] at y0 y1 d0 d1
  rw [← hd] at d0 d1
  have hmp : mpOfDoy (doyOfDoe doe) = (5 * doyOfDoe doe + 2) / 153 := rfl
  have hmp0 : 0 ≤ mpOfDoy (doyOfDoe doe) := by omega
  have hmp1 : mpOfDoy (doyOfDoe doe) ≤ 11 := by omega
  have hq : (yoeOfDoe doe + era * 400) / 400 = era := by omega
  have hq' : (yoeOfDoe doe + era * 400 + 1 - 1) / 400 = era := by omega
  have hr : yoeOfDoe doe + era * 400 - era * 400 = yoeOfDoe doe := by omega
  have hr' : yoeOfDoe doe + era * 400 + 1 - 1 - era * 400 = yoeOfDoe doe := by omega
  have hr'' : yoeOfDoe doe + era * 400 + 1 - 1 = yoeOfDoe doe + era * 400 := by omega
  simp only [civilOfDoe, toEpochDay]
  by_cases hm : mpOfDoy (doyOfDoe doe) < 10
  · have e1 : ¬ (mpOfDoy (doyOfDoe doe) + 3 ≤ 2) := by omega
    have e2 : ¬ ((mpOfDoy (doyOfDoe doe) + 3).toNat ≤ 2) := by omega
    have e3 : (mpOfDoy (doyOfDoe doe) + 3).toNat > 2 := by omega
    simp only [hm, e1, e2, e3, ite_true, ite_false, hq, hr]
    omega
  · have e1 : mpOfDoy (doyOfDoe doe) - 9 ≤ 2 := by omega
    have e2 : (mpOfDoy (doyOfDoe doe) - 9).toNat ≤ 2 := by omega
    have e3 : ¬ ((mpOfDoy (doyOfDoe doe) - 9).toNat > 2) := by omega
    simp only [hm, e1, e2, e3, ite_true, ite_false, hr'', hq, hr]
    omega

theorem toEpochDay_ofEpochDay (z : Int) : (ofEpochDay z).toEpochDay = z := by
  unfold ofEpochDay
  rw [toEpochDay_civilOfDoe _ _ (Int.emod_nonneg _ (by decide)) (by have := Int.emod_lt_of_pos (z + 719468) (by decide : (0:Int) < 146097); omega)]
  omega

end JLocalDate

end LangSemantics.Java
