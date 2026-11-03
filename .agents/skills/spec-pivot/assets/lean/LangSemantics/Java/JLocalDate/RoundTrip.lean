import LangSemantics.Java.JLocalDate.Lemmas

/-!
# LangSemantics.Java.JLocalDate.RoundTrip

`LocalDate` の通算日数の変換の逆向き: 妥当な暦日（月が 1〜12、日がその月の日数の範囲）では、
`ofEpochDay (toEpochDay x) = x`。

- 400 年の周期の中の、年（0〜399）・3 月始まりの月（0〜11）・日のすべての組で、`days_from_civil` の周期の中の日から
  `civil_from_days` が年・月・日を取り戻すことを、カーネルの評価（`decide +kernel`）で確かめる（`invAll`）。
- 周期の外へは、閏年の判定が 400 年で繰り返すこと（`isLeapYear_add`）で広げる。
-/

namespace LangSemantics.Java

namespace JLocalDate

/-- 3 月始まりの月 `mp` の日数（周期の中の年 `yoe`。1・2 月は翌年の閏年で決まる）。 -/
def monthLenN (yoe mp : Nat) : Nat :=
  if mp < 10 then daysInMonth (yoe : Int) (mp + 3) else daysInMonth ((yoe : Int) + 1) (mp - 9)

/-- 周期の中の年 `yoe`・3 月始まりの月 `mp`・日 `k + 1` で、周期の中の日から年・年の中の日・月が取り戻せるか
（その月に無い日は対象外）。自然数で計算する。 -/
def invOk (yoe mp k : Nat) : Bool :=
  let doy := (153 * mp + 2) / 5 + k
  let doe := 365 * yoe + yoe / 4 - yoe / 100 + doy
  decide (k + 1 > monthLenN yoe mp) ||
    (decide (doe ≤ 146096) && yoeN doe == yoe &&
      doe - (365 * yoe + yoe / 4 - yoe / 100) == doy && (5 * doy + 2) / 153 == mp)

/-- 周期の中の年 `yoe` のすべての月・日で `invOk`。 -/
def invYear (yoe : Nat) : Bool := (List.range 12).all fun mp => (List.range 31).all fun k => invOk yoe mp k

/-- 周期の中の年の、`a` から 50 年分。 -/
def invBlock (a : Nat) : Bool := (List.range 50).all fun i => invYear (a + i)

set_option maxRecDepth 20000 in
theorem invBlock0 : invBlock 0 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock50 : invBlock 50 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock100 : invBlock 100 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock150 : invBlock 150 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock200 : invBlock 200 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock250 : invBlock 250 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock300 : invBlock 300 = true := by decide +kernel
set_option maxRecDepth 20000 in
theorem invBlock350 : invBlock 350 = true := by decide +kernel

theorem invYear_of {yoe : Nat} (hy : yoe < 400) : invYear yoe = true := by
  have hb : ∀ a, a % 50 = 0 → a < 400 → invBlock a = true := by
    intro a h0 h1
    have : a = 0 ∨ a = 50 ∨ a = 100 ∨ a = 150 ∨ a = 200 ∨ a = 250 ∨ a = 300 ∨ a = 350 := by omega
    rcases this with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact invBlock0
    · exact invBlock50
    · exact invBlock100
    · exact invBlock150
    · exact invBlock200
    · exact invBlock250
    · exact invBlock300
    · exact invBlock350
  have := List.all_eq_true.mp (hb (yoe / 50 * 50) (by omega) (by omega)) (yoe % 50) (List.mem_range.mpr (by omega))
  rwa [show yoe / 50 * 50 + yoe % 50 = yoe by omega] at this

theorem invOk_of {yoe mp k : Nat} (hy : yoe < 400) (hm : mp < 12) (hk : k < 31) : invOk yoe mp k = true :=
  List.all_eq_true.mp (List.all_eq_true.mp (invYear_of hy) mp (List.mem_range.mpr hm)) k (List.mem_range.mpr hk)

/-- 周期の中の年・3 月始まりの月・日から作った周期の中の日を、`civilOfDoe` の年・月・日の式は年・月・日に戻す。 -/
theorem civilOfDoe_inv (era : Int) {yoe mp k : Nat} (hy : yoe < 400) (hm : mp < 12) (hk : k < 31)
    (hlen : k + 1 ≤ monthLenN yoe mp) :
    let doe : Int := ((365 * yoe + yoe / 4 - yoe / 100 + ((153 * mp + 2) / 5 + k) : Nat) : Int)
    (if civilMonth doe ≤ 2 then yoeOfDoe doe + era * 400 + 1 else yoeOfDoe doe + era * 400) =
        (if mp < 10 then (yoe : Int) + era * 400 else (yoe : Int) + era * 400 + 1) ∧
      (civilMonth doe).toNat = (if mp < 10 then mp + 3 else mp - 9) ∧ (civilDay doe).toNat = k + 1 := by
  intro doe
  have h := invOk_of hy hm hk
  simp only [invOk, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  rcases h with h | ⟨⟨⟨hle, hyoe⟩, hdoy⟩, hmp⟩
  · omega
  simp only [doe]
  generalize hD : 365 * yoe + yoe / 4 - yoe / 100 + ((153 * mp + 2) / 5 + k) = doe at hle hyoe hdoy hmp
  have hY := yoeOfDoe_nat doe
  rw [hyoe] at hY
  have hdo : doyOfDoe (doe : Int) = (((153 * mp + 2) / 5 + k : Nat) : Int) := by
    unfold doyOfDoe; rw [hY]
    have : ((yoe : Int) / 4) = ((yoe / 4 : Nat) : Int) := by omega
    have : ((yoe : Int) / 100) = ((yoe / 100 : Nat) : Int) := by omega
    omega
  have hmpI : mpOfDoy (((153 * mp + 2) / 5 + k : Nat) : Int) = (mp : Int) := by
    unfold mpOfDoy; omega
  simp only [civilMonth, civilDay]
  simp only [hY, hdo]
  simp only [hmpI]
  by_cases h10 : mp < 10
  · have a : ((mp : Int) < 10) := by omega
    simp only [a, ite_true, h10]
    have b : ¬ ((mp : Int) + 3 ≤ 2) := by omega
    simp only [b, ite_false]
    refine ⟨?_, ?_, ?_⟩ <;> first | trivial | omega
  · have a : ¬ ((mp : Int) < 10) := by omega
    simp only [a, ite_false, h10]
    have b : ((mp : Int) - 9 ≤ 2) := by omega
    simp only [b, ite_true]
    refine ⟨?_, ?_, ?_⟩ <;> first | trivial | omega

theorem doe_le {yoe mp k : Nat} (hy : yoe < 400) (hm : mp < 12) (hk : k < 31) (hlen : k + 1 ≤ monthLenN yoe mp) :
    365 * yoe + yoe / 4 - yoe / 100 + ((153 * mp + 2) / 5 + k) ≤ 146096 := by
  have h := invOk_of hy hm hk
  simp only [invOk, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  rcases h with h | ⟨⟨⟨hle, -⟩, -⟩, -⟩
  · omega
  · exact hle

/-- 妥当な暦日（月が 1〜12、日がその月の日数の範囲）では、`ofEpochDay (toEpochDay x) = x`。 -/
theorem ofEpochDay_toEpochDay (x : JLocalDate) : ofEpochDay x.toEpochDay = x := by
  obtain ⟨Y, M, D, ⟨hm1, hm2, hd1, hd2⟩⟩ := x
  -- 3 月始まりの年 `y'`、周期 `era`、周期の中の年 `yoe`、3 月始まりの月 `mp`、日 `k + 1`
  let y' : Int := if M ≤ 2 then Y - 1 else Y
  have hyoe0 : 0 ≤ y' - y' / 400 * 400 := by omega
  obtain ⟨yoe, hyoe⟩ : ∃ n : Nat, (n : Int) = y' - y' / 400 * 400 := ⟨_, Int.toNat_of_nonneg hyoe0⟩
  have hy : yoe < 400 := by omega
  let mp : Nat := if M > 2 then M - 3 else M + 9
  have hm : mp < 12 := by simp only [mp]; split <;> omega
  have hk : D - 1 < 31 := by
    have : daysInMonth Y M ≤ 31 := by unfold daysInMonth; split <;> (try split) <;> omega
    omega
  have hlen : D - 1 + 1 ≤ monthLenN yoe mp := by
    have hY : (if mp < 10 then (yoe : Int) else (yoe : Int) + 1) + 400 * (y' / 400) = Y := by
      have h' := hyoe
      simp only [mp, y'] at h' ⊢
      by_cases h2 : M ≤ 2
      · have : ¬ (M > 2) := by omega
        have h10 : ¬ (M + 9 < 10) := by omega
        simp only [h2, this, h10, ite_true, ite_false] at h' ⊢; omega
      · have : M > 2 := by omega
        have h10 : M - 3 < 10 := by omega
        simp only [h2, this, h10, ite_true, ite_false] at h' ⊢; omega
    have hM : (if mp < 10 then mp + 3 else mp - 9) = M := by simp only [mp]; split <;> split <;> omega
    unfold monthLenN
    rw [← hY, ← hM, daysInMonth_add] at hd2
    split <;> rename_i h <;> simp only [h, ite_true, ite_false] at hd2 <;> omega
  have hdoe := doe_le hy hm hk hlen
  have key : JLocalDate.toEpochDay ⟨Y, M, D, ⟨hm1, hm2, hd1, hd2⟩⟩ = y' / 400 * 146097 +
      ((365 * yoe + yoe / 4 - yoe / 100 + ((153 * mp + 2) / 5 + (D - 1)) : Nat) : Int) - 719468 := by
    unfold toEpochDay
    simp only [mp, y'] at hyoe ⊢
    have e4 : ((yoe : Int) / 4) = ((yoe / 4 : Nat) : Int) := by omega
    have e100 : ((yoe : Int) / 100) = ((yoe / 100 : Nat) : Int) := by omega
    by_cases h2 : M ≤ 2
    · have : ¬ (M > 2) := by omega
      simp only [h2, this, ite_true, ite_false] at hyoe ⊢
      have e5 : ((153 * ((M : Int) + 9) + 2) / 5) = (((153 * (M + 9) + 2) / 5 : Nat) : Int) := by omega
      rw [← hyoe] at *
      omega
    · have : M > 2 := by omega
      simp only [h2, this, ite_true, ite_false] at hyoe ⊢
      have e5 : ((153 * ((M : Int) - 3) + 2) / 5) = (((153 * (M - 3) + 2) / 5 : Nat) : Int) := by omega
      rw [← hyoe] at *
      omega
  apply ext
  all_goals
    simp only [ofEpochDay, civilOfDoe]
    rw [key]
    generalize hdv : 365 * yoe + yoe / 4 - yoe / 100 + ((153 * mp + 2) / 5 + (D - 1)) = doe at hdoe
    have q : (y' / 400 * 146097 + (doe : Int) - 719468 + 719468) / 146097 = y' / 400 := by omega
    have r : (y' / 400 * 146097 + (doe : Int) - 719468 + 719468) % 146097 = (doe : Int) := by omega
    simp only [q, r]
    rw [← hdv]
    obtain ⟨e1, e2, e3⟩ := civilOfDoe_inv (y' / 400) hy hm hk hlen
    try simp only at e1 e2 e3
    try rw [e1]
    try rw [e2]
    try rw [e3]
    simp only [mp, y'] at hyoe ⊢
    by_cases h2 : M ≤ 2
    · have : ¬ (M > 2) := by omega
      have h10 : ¬ (M + 9 < 10) := by omega
      simp only [this, h2, h10, ite_true, ite_false] at hyoe ⊢
      omega
    · have : M > 2 := by omega
      have h10 : M - 3 < 10 := by omega
      simp only [this, h2, h10, ite_true, ite_false] at hyoe ⊢
      omega

end JLocalDate

end LangSemantics.Java
