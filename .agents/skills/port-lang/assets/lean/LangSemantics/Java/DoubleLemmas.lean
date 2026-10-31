import LangSemantics.Java.Double

/-!
# LangSemantics.Java.DoubleLemmas

double の演算の閉じた形。非負の整数 `X` と有限の正の double `F = fm · 2^(-fs)` について、
`(int)(X * F)`（`jd2i (jdmul (jd X) F)`）は、正確な値 `X·fm / 2^fs` を 53 ビットの格子で
round-to-nearest-even し、0 方向に切り捨てた値 `rneTrunc (X·fm) (2^fs)` に等しい（正規数の範囲で）。
-/

namespace LangSemantics.Java

namespace JDouble

theorem pow2_ofNat (k : Nat) : pow2 (k : Int) = (2 ^ k, 1) := by
  simp [pow2]

theorem pow2_neg (k : Nat) : pow2 (-(k : Int)) = (1, 2 ^ k) := by
  unfold pow2
  split
  · rename_i h
    have : k = 0 := by omega
    subst this; rfl
  · simp

/-- `pow2 z = (2^z⁺, 2^z⁻)`（符号によらない形）。 -/
theorem pow2_eq (z : Int) : pow2 z = (2 ^ z.toNat, 2 ^ (-z).toNat) := by
  unfold pow2
  split
  · rename_i h; simp only [Prod.mk.injEq, true_and]; rw [show (-z).toNat = 0 by omega]
  · rename_i h; simp only [Prod.mk.injEq, and_true]; rw [show z.toNat = 0 by omega]

theorem log2_mul_pow2 {n : Nat} (hn : n ≠ 0) (s : Nat) : Nat.log2 (n * 2 ^ s) = Nat.log2 n + s := by
  have h1 : n * 2 ^ s ≠ 0 := Nat.mul_ne_zero hn (Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _))
  apply Nat.le_antisymm
  · have : Nat.log2 (n * 2 ^ s) < Nat.log2 n + s + 1 := by
      rw [Nat.log2_lt h1, Nat.pow_succ, Nat.pow_add]
      have := Nat.lt_log2_self (n := n)
      rw [Nat.pow_succ] at this
      calc n * 2 ^ s < 2 ^ Nat.log2 n * 2 * 2 ^ s := Nat.mul_lt_mul_of_pos_right this (Nat.two_pow_pos _)
        _ = _ := by rw [Nat.mul_right_comm]
    omega
  · rw [Nat.le_log2 h1, Nat.pow_add]
    exact Nat.mul_le_mul_right _ (Nat.log2_self_le hn)

theorem two_pow_mul_two_pow (i j : Nat) : 2 ^ i * 2 ^ j = 2 ^ (i + j) := (Nat.pow_add 2 i j).symm

/-- `⌊log2 (N/D)⌋` の性質: `2^L ≤ N/D < 2^(L+1)`（分子・分母の積で書く）。 -/
theorem floorLog2_spec {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) :
    D * 2 ^ (floorLog2 N D).toNat ≤ N * 2 ^ (-(floorLog2 N D)).toNat ∧
      N * 2 ^ (-(floorLog2 N D + 1)).toNat < D * 2 ^ (floorLog2 N D + 1).toNat := by
  have ha1 := Nat.log2_self_le hN
  have ha2 := Nat.lt_log2_self (n := N)
  have hb1 := Nat.log2_self_le hD
  have hb2 := Nat.lt_log2_self (n := D)
  generalize ha : Nat.log2 N = a at *
  generalize hb : Nat.log2 D = b at *
  unfold floorLog2 geTwoPow
  rw [ha, hb]
  simp only [pow2_eq, ge_iff_le, decide_eq_true_eq]
  split
  · rename_i hg
    refine ⟨hg, ?_⟩
    -- N/D < 2^(a+1)/2^b
    calc N * 2 ^ (-((a : Int) - b + 1)).toNat < 2 ^ (a + 1) * 2 ^ (-((a : Int) - b + 1)).toNat :=
          Nat.mul_lt_mul_of_pos_right ha2 (Nat.two_pow_pos _)
      _ = 2 ^ b * 2 ^ ((a : Int) - b + 1).toNat := by
          rw [two_pow_mul_two_pow, two_pow_mul_two_pow]; congr 1; omega
      _ ≤ D * 2 ^ ((a : Int) - b + 1).toNat := Nat.mul_le_mul_right _ hb1
  · rename_i hg
    constructor
    · calc D * 2 ^ ((a : Int) - b - 1).toNat ≤ 2 ^ (b + 1) * 2 ^ ((a : Int) - b - 1).toNat :=
            Nat.mul_le_mul_right _ (Nat.le_of_lt hb2)
        _ = 2 ^ a * 2 ^ (-((a : Int) - b - 1)).toNat := by
            rw [two_pow_mul_two_pow, two_pow_mul_two_pow]; congr 1; omega
        _ ≤ N * 2 ^ (-((a : Int) - b - 1)).toNat := Nat.mul_le_mul_right _ ha1
    · have : (a : Int) - b - 1 + 1 = (a : Int) - b := by omega
      rw [this]
      simpa using hg

/-- 最近接への丸め: `m = roundAtExp N D e` は `n/d`（`n = N·2^e⁻`、`d = D·2^e⁺`）から高々 1/2 しか離れない。 -/
theorem roundAtExp_spec (N D : Nat) (e : Int) (hD : D ≠ 0) :
    2 * (roundAtExp N D e * (D * 2 ^ e.toNat)) ≤ 2 * (N * 2 ^ (-e).toNat) + D * 2 ^ e.toNat ∧
      2 * (N * 2 ^ (-e).toNat) ≤ 2 * (roundAtExp N D e * (D * 2 ^ e.toNat)) + D * 2 ^ e.toNat := by
  unfold roundAtExp
  simp only [pow2_eq]
  generalize hn : N * 2 ^ (-e).toNat = n
  generalize hd : D * 2 ^ e.toNat = d
  have hd0 : 0 < d := by rw [← hd]; exact Nat.mul_pos (Nat.pos_of_ne_zero hD) (Nat.two_pow_pos _)
  have e1 := Nat.div_add_mod n d
  have e2 := Nat.mod_lt n hd0
  generalize n / d = m at *
  generalize n % d = r at *
  rw [Nat.mul_comm d m] at e1
  split
  · constructor <;> (rw [Nat.add_mul]; omega)
  · split
    · constructor <;> omega
    · split <;> constructor <;> (try rw [Nat.add_mul]) <;> omega

/-- 正の有理数 `N/D` を 53 ビットの格子で round-to-nearest-even し、0 方向に切り捨てた整数。 -/
def rneTrunc (N D : Nat) : Nat :=
  let e := floorLog2 N D - 52
  roundAtExp N D e * 2 ^ e.toNat / 2 ^ (-e).toNat

/-- 値が `[2^-1000, 2^31)` にある正の有理数の範囲。`⌊log2⌋` は `-1000` 以上 `30` 以下。 -/
theorem floorLog2_range {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 31) :
    -1000 ≤ floorLog2 N D ∧ floorLog2 N D ≤ 30 := by
  obtain ⟨h1, h2⟩ := floorLog2_spec hN hD
  generalize floorLog2 N D = L at h1 h2
  constructor
  · rcases Int.lt_or_le L (-1000) with hc | hc
    · exfalso
      have e1 : (L + 1).toNat = 0 := by omega
      rw [e1, Nat.pow_zero, Nat.mul_one] at h2
      have : N * 2 ^ 1000 ≤ N * 2 ^ (-(L + 1)).toNat :=
        Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by omega))
      omega
    · exact hc
  · rcases Int.lt_or_le 30 L with hc | hc
    · exfalso
      have e1 : (-L).toNat = 0 := by omega
      rw [e1, Nat.pow_zero, Nat.mul_one] at h1
      have : D * 2 ^ 31 ≤ D * 2 ^ L.toNat := Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by omega))
      omega
    · exact hc

/-- 閉じた形: 値が `[2^-1000, 2^31)` の正の有理数を double に丸めて `(int)` にした値は、`rneTrunc`（int の上限で飽和）。 -/
theorem toJ32_ofRat {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 31) :
    (toJ32 (ofRat ⟨false, N, D⟩)).val = min J32.maxValue (rneTrunc N D) := by
  obtain ⟨r1, r2⟩ := floorLog2_range hN hD hlo hhi
  have key : truncInt (ofRat ⟨false, N, D⟩) = some ((rneTrunc N D : Nat) : Int) := by
    unfold ofRat rneTrunc
    simp only [hN, ite_false]
    generalize floorLog2 N D = L at r1 r2
    have hmax : max (L - 52) minExp = L - 52 := by simp only [minExp]; omega
    simp only [hmax]
    generalize roundAtExp N D (L - 52) = m
    have t1 : (L - 52).toNat = 0 := by omega
    split
    · rename_i hm
      subst hm
      have h1 : ¬ (L - 52 + 1 > maxExp) := by simp only [maxExp]; omega
      simp only [h1, ite_false, show (2 : Nat) ^ (precision - 1) ≠ 0 from Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _),
        truncInt, pow2_eq, t1, Nat.pow_zero, Nat.mul_one, Option.some.injEq, Bool.false_eq_true, ite_false]
      have t2 : (L - 52 + 1).toNat = 0 := by omega
      rw [t2, Nat.pow_zero, Nat.mul_one]
      have : (-(L - 52)).toNat = (-(L - 52 + 1)).toNat + 1 := by omega
      rw [this, Nat.pow_succ, show precision = 53 by rfl, show (2 : Nat) ^ 53 = 2 ^ 52 * 2 by rfl]
      rw [Nat.mul_div_mul_right _ _ (by decide : 0 < 2)]
    · have h1 : ¬ (L - 52 > maxExp) := by simp only [maxExp]; omega
      simp only [h1, ite_false]
      split
      · rename_i h0
        subst h0
        simp [truncInt, pow2_eq]
      · simp only [truncInt, pow2_eq, t1, Nat.pow_zero, Nat.mul_one, Bool.false_eq_true, ite_false]
  unfold toJ32
  split
  · rename_i h; rw [h] at key; simp [truncInt] at key
  · rename_i h; rw [h] at key; simp [truncInt] at key
  · rw [key, Option.getD_some]
    show (J32.ofInt (max J32.minValue (min J32.maxValue (rneTrunc N D : Int)))).val = _
    have : max J32.minValue (min J32.maxValue (rneTrunc N D : Int)) = min J32.maxValue (rneTrunc N D : Int) := by
      simp only [J32.minValue, J32.maxValue]; omega
    rw [this]
    apply J32.val_ofInt_of_inRange
    simp only [J32.minValue, J32.maxValue]
    omega

end JDouble
