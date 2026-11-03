import LangSemantics.Java.DoubleOps

/-!
# LangSemantics.Java.JDouble.Lemmas

double の演算の閉じた形。非負の整数 `X` と有限の正の double `F = fm · 2^(-fs)` について、
`(int)(X * F)`（`jd2i (jdmul (jd X) F)`）は、正確な値 `X·fm / 2^fs` を 53 ビットの格子で
round-to-nearest-even し、0 方向に切り捨てた値 `rneTrunc (X·fm) (2^fs)` に等しい（正規数の範囲で）。
-/

set_option exponentiation.threshold 2048

namespace LangSemantics.Java
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.Int

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
theorem toJ32_ofRat {N D : Nat} {hDp : 0 < D} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000)
    (hhi : N < D * 2 ^ 31) : (toJ32 (ofRat ⟨false, N, D, hDp⟩)).val = min J32.maxValue (rneTrunc N D) := by
  obtain ⟨r1, r2⟩ := floorLog2_range hN hD hlo hhi
  have hp : ∃ m e, roundParts N D = some (m, e) ∧ m * 2 ^ e.toNat / 2 ^ (-e).toNat = rneTrunc N D := by
    unfold roundParts rneTrunc
    generalize floorLog2 N D = L at r1 r2
    have hmax : max (L - 52) minExp = L - 52 := by simp only [minExp]; omega
    simp only [hmax]
    generalize roundAtExp N D (L - 52) = m
    have t1 : (L - 52).toNat = 0 := by omega
    by_cases hm : m = 2 ^ precision
    · subst hm
      have h1 : ¬ (L - 52 + 1 > maxExp) := by simp only [maxExp]; omega
      refine ⟨2 ^ (precision - 1), L - 52 + 1, by simp [h1, precision], ?_⟩
      have t2 : (L - 52 + 1).toNat = 0 := by omega
      rw [t2, t1, Nat.pow_zero, Nat.mul_one, Nat.mul_one]
      have : (-(L - 52)).toNat = (-(L - 52 + 1)).toNat + 1 := by omega
      rw [this, Nat.pow_succ, show precision = 53 by rfl, show (2 : Nat) ^ 53 = 2 ^ 52 * 2 by rfl]
      rw [Nat.mul_div_mul_right _ _ (by decide : 0 < 2)]
    · have h1 : ¬ (L - 52 > maxExp) := by simp only [maxExp]; omega
      by_cases h0 : m = 0
      · subst h0
        exact ⟨0, 0, by simp [hm, h1], by simp⟩
      · exact ⟨m, L - 52, by simp [hm, h1, h0], rfl⟩
  obtain ⟨m, e, hp, ht⟩ := hp
  obtain ⟨hc, he⟩ := ofRat_some (s := false) (hD := hDp) hN hp
  rw [he]
  have key : truncInt (.finite false m e hc) = some ((rneTrunc N D : Nat) : Int) := by
    simp only [truncInt, pow2_eq, ht, Bool.false_eq_true, ite_false]
  unfold toJ32
  simp only [key, Option.getD_some]
  · show (J32.ofInt (max J32.minValue (min J32.maxValue (rneTrunc N D : Int)))).val = _
    have : max J32.minValue (min J32.maxValue (rneTrunc N D : Int)) = min J32.maxValue (rneTrunc N D : Int) := by
      simp only [J32.minValue, J32.maxValue]; omega
    rw [this]
    apply J32.val_ofInt_of_inRange
    simp only [J32.minValue, J32.maxValue]
    omega

/-- `rneTrunc` の性質（不等式の形）: 値 `N/D` を `[2^52, 2^53)` に移す 2 の冪 `Q` と、`N·Q/D` を
最近接に丸めた整数 `M` があって、`rneTrunc N D = M / Q`。値が `[2^-1000, 2^29)` にあるとき、`Q ≥ 2^23`。 -/
theorem rneTrunc_spec {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 29) :
    ∃ Q M, rneTrunc N D = M / Q ∧ 2 ^ 23 ≤ Q ∧ D * 2 ^ 52 ≤ N * Q ∧ N * Q < D * 2 ^ 53 ∧
      2 * (M * D) ≤ 2 * (N * Q) + D ∧ 2 * (N * Q) ≤ 2 * (M * D) + D := by
  have hhi' : N < D * 2 ^ 31 := Nat.lt_of_lt_of_le hhi (Nat.mul_le_mul_left _ (by decide))
  obtain ⟨r1, r2⟩ := floorLog2_range hN hD hlo hhi'
  obtain ⟨f1, f2⟩ := floorLog2_spec hN hD
  obtain ⟨g1, g2⟩ := roundAtExp_spec N D (floorLog2 N D - 52) hD
  have hL29 : floorLog2 N D ≤ 28 := by
    rcases Int.lt_or_le 28 (floorLog2 N D) with hc | hc
    · exfalso
      have e1 : (-(floorLog2 N D)).toNat = 0 := by omega
      rw [e1, Nat.pow_zero, Nat.mul_one] at f1
      have : D * 2 ^ 29 ≤ D * 2 ^ (floorLog2 N D).toNat :=
        Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by omega))
      omega
    · exact hc
  generalize hL : floorLog2 N D = L at *
  refine ⟨2 ^ (52 - L).toNat, roundAtExp N D (L - 52), ?_, ?_, ?_, ?_, ?_, ?_⟩
  · simp only [rneTrunc, hL, show (L - 52).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one,
      show (-(L - 52)).toNat = (52 - L).toNat by omega]
  · exact Nat.pow_le_pow_right (by decide) (by omega)
  · rcases Int.lt_or_le L 0 with hl | hl
    · rw [show L.toNat = 0 by omega, Nat.pow_zero, Nat.mul_one] at f1
      calc D * 2 ^ 52 ≤ N * 2 ^ (-L).toNat * 2 ^ 52 := Nat.mul_le_mul_right _ f1
        _ = N * 2 ^ (52 - L).toNat := by rw [Nat.mul_assoc, two_pow_mul_two_pow]; congr 2; omega
    · rw [show (-L).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one] at f1
      calc D * 2 ^ 52 = D * 2 ^ L.toNat * 2 ^ (52 - L).toNat := by
            rw [Nat.mul_assoc, two_pow_mul_two_pow]; congr 2; omega
        _ ≤ N * 2 ^ (52 - L).toNat := Nat.mul_le_mul_right _ f1
  · rcases Int.lt_or_le L (-1) with hl | hl
    · rw [show (L + 1).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one] at f2
      calc N * 2 ^ (52 - L).toNat = N * 2 ^ (-(L + 1)).toNat * 2 ^ 53 := by
            rw [Nat.mul_assoc, two_pow_mul_two_pow]; congr 2; omega
        _ < D * 2 ^ 53 := Nat.mul_lt_mul_of_pos_right f2 (Nat.two_pow_pos _)
    · rw [show (-(L + 1)).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one] at f2
      calc N * 2 ^ (52 - L).toNat < D * 2 ^ (L + 1).toNat * 2 ^ (52 - L).toNat :=
            Nat.mul_lt_mul_of_pos_right f2 (Nat.two_pow_pos _)
        _ = D * 2 ^ 53 := by rw [Nat.mul_assoc, two_pow_mul_two_pow]; congr 2; omega
  · simpa only [show (L - 52).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one,
      show (-(L - 52)).toNat = (52 - L).toNat by omega] using g1
  · simpa only [show (L - 52).toNat = 0 by omega, Nat.pow_zero, Nat.mul_one,
      show (-(L - 52)).toNat = (52 - L).toNat by omega] using g2

/-! ## 2 の冪の倍での不変性 -/

theorem floorLog2_mul_pow2 {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (s : Nat) :
    floorLog2 (N * 2 ^ s) (D * 2 ^ s) = floorLog2 N D := by
  unfold floorLog2 geTwoPow
  rw [log2_mul_pow2 hN, log2_mul_pow2 hD]
  have e : ((Nat.log2 N + s : Nat) : Int) - ((Nat.log2 D + s : Nat) : Int) = (Nat.log2 N : Int) - Nat.log2 D := by
    omega
  simp only [e, pow2_eq, ge_iff_le, decide_eq_true_eq]
  have : ∀ u v : Nat, D * 2 ^ s * u ≤ N * 2 ^ s * v ↔ D * u ≤ N * v := by
    intro u v
    rw [Nat.mul_right_comm D, Nat.mul_right_comm N]
    exact Nat.mul_le_mul_right_iff (Nat.two_pow_pos _)
  simp only [this]

theorem roundAtExp_mul_pow2 (N D : Nat) (e : Int) (s : Nat) :
    roundAtExp (N * 2 ^ s) (D * 2 ^ s) e = roundAtExp N D e := by
  unfold roundAtExp
  simp only [pow2_eq]
  have hs := Nat.two_pow_pos s
  rw [Nat.mul_right_comm N, Nat.mul_right_comm D, Nat.mul_div_mul_right _ _ hs, Nat.mul_mod_mul_right]
  generalize N * 2 ^ (-e).toNat / (D * 2 ^ e.toNat) = m
  generalize N * 2 ^ (-e).toNat % (D * 2 ^ e.toNat) = r
  generalize D * 2 ^ e.toNat = d
  have h1 : (2 * (r * 2 ^ s) > d * 2 ^ s) ↔ (2 * r > d) := by
    rw [← Nat.mul_assoc]; exact Nat.mul_lt_mul_right hs
  have h2 : (2 * (r * 2 ^ s) < d * 2 ^ s) ↔ (2 * r < d) := by
    rw [← Nat.mul_assoc]; exact Nat.mul_lt_mul_right hs
  simp only [h1, h2]

theorem rneTrunc_mul_pow2 {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (s : Nat) :
    rneTrunc (N * 2 ^ s) (D * 2 ^ s) = rneTrunc N D := by
  simp only [rneTrunc, floorLog2_mul_pow2 hN hD, roundAtExp_mul_pow2]

/-! ## `(double) X` と `(int)(X * F)` -/

/-- `(double) X`（`0 < X < 2^53`）は正確: 仮数 `X·2^(52−l)`、指数 `l − 52`（`l = ⌊log2 X⌋`）。 -/
theorem ofInt_nat {X : Nat} (h0 : X ≠ 0) (h : X < 2 ^ 53) :
    ∃ hc, ofInt (X : Int) = .finite false (X * 2 ^ (52 - Nat.log2 X)) ((Nat.log2 X : Int) - 52) hc := by
  have hl : Nat.log2 X < 53 := (Nat.log2_lt h0).mpr h
  have hl1 := Nat.log2_self_le h0
  have hl2 := Nat.lt_log2_self (n := X)
  generalize hlx : Nat.log2 X = l at *
  have hf : floorLog2 X 1 = (l : Int) := by
    unfold floorLog2 geTwoPow
    rw [hlx, show Nat.log2 1 = 0 by decide]
    simp only [Int.natCast_zero, Int.sub_zero, pow2_ofNat, ge_iff_le, Nat.mul_one, Nat.one_mul, decide_eq_true_eq,
      hl1, ite_true]
  have hmax : max ((l : Int) - 52) minExp = (l : Int) - 52 := by simp only [minExp]; omega
  have hr : roundAtExp X 1 ((l : Int) - 52) = X * 2 ^ (52 - l) := by
    unfold roundAtExp
    simp only [pow2_eq, show ((l : Int) - 52).toNat = 0 by omega, show (-((l : Int) - 52)).toNat = 52 - l by omega,
      Nat.pow_zero, Nat.mul_one, Nat.div_one, Nat.mod_one]
    simp
  have hlt : X * 2 ^ (52 - l) < 2 ^ 53 := by
    calc X * 2 ^ (52 - l) < 2 ^ (l + 1) * 2 ^ (52 - l) := Nat.mul_lt_mul_of_pos_right hl2 (Nat.two_pow_pos _)
      _ = 2 ^ 53 := by rw [two_pow_mul_two_pow]; congr 1; omega
  have hne : X * 2 ^ (52 - l) ≠ 0 := Nat.mul_ne_zero h0 (Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _))
  have hp : roundParts X 1 = some (X * 2 ^ (52 - l), (l : Int) - 52) := by
    unfold roundParts
    simp only [hf, hmax, hr, show ¬ (X * 2 ^ (52 - l) = 2 ^ precision) by simp only [precision]; omega, ite_false,
      show ¬ ((l : Int) - 52 > maxExp) by simp only [maxExp]; omega, hne]
  unfold ofInt
  simp only [show ¬ ((X : Int) < 0) by omega, decide_false, Int.natAbs_natCast]
  exact ofRat_some h0 hp

/-- `(int)(X * F)`（`X` は非負の整数、`F = fm·2^(−fs)` は正の double）は、`rneTrunc (X·fm) (2^fs)`（int の上限で飽和）。
値が `[2^-1000, 2^31)` にあるとき。 -/
theorem jd2i_mul_nat {X fm fs : Nat} {hc : Canonical fm (-(fs : Int))} (hX0 : X ≠ 0) (hX : X < 2 ^ 53)
    (hfm : fm ≠ 0) (hlo : 2 ^ fs ≤ X * fm * 2 ^ 1000) (hhi : X * fm < 2 ^ fs * 2 ^ 31) :
    (jd2i (jdmul (jd (X : Int)) (.finite false fm (-(fs : Int)) hc))).val =
      min J32.maxValue (rneTrunc (X * fm) (2 ^ fs)) := by
  have hl : Nat.log2 X < 53 := (Nat.log2_lt hX0).mpr hX
  unfold jd2i jdmul jd
  obtain ⟨hcX, hX'⟩ := ofInt_nat hX0 hX
  rw [hX']
  clear hX'
  revert hcX
  generalize hs : 52 - Nat.log2 X = s
  have hpe : ((Nat.log2 X : Int) - 52) = -(s : Int) := by omega
  rw [hpe]
  intro hcX
  simp only [mul, toRat?, pow2_neg, Bool.false_bne]
  have e1 : X * 2 ^ s * 1 * (fm * 1) = (X * fm) * 2 ^ s := by
    simp only [Nat.mul_one]; rw [Nat.mul_right_comm]
  have e2 : 2 ^ s * 2 ^ fs = 2 ^ fs * 2 ^ s := Nat.mul_comm _ _
  simp only [e1, e2]
  have hN : X * fm ≠ 0 := Nat.mul_ne_zero hX0 hfm
  have hD : (2 : Nat) ^ fs ≠ 0 := Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _)
  rw [toJ32_ofRat (Nat.mul_ne_zero hN (Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _)))
    (Nat.mul_ne_zero hD (Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _))), rneTrunc_mul_pow2 hN hD]
  · rw [Nat.mul_right_comm]; exact Nat.mul_le_mul_right _ hlo
  · rw [Nat.mul_right_comm (2 ^ fs)]; exact Nat.mul_lt_mul_of_pos_right hhi (Nat.two_pow_pos _)

end JDouble
