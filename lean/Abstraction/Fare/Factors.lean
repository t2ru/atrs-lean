import Abstraction.Fare.Double
import Spec.Fare

/-!
# Abstraction.Fare.Factors

[Source] の運賃計算の double の因子と、差異の条件（既知差異 D-001・D-002）。

- 基本運賃の因子 `basicFactor c = (double) c * 0.01`（`c` は積算比率、MD-8 で 0〜1000）
- 運賃の因子 `fareFactor r = 1 − (double) r * 0.01`（`r` は割引率、0〜100）

どの因子も、正確な値（`c/100`・`(100−r)/100`）の相対誤差 `2^-48` 以内にある（`Close`。カーネルの評価で確かめる）。
`X·c` が 100 で割り切れないとき、[Source] の `(int)(X * F)` は [Spec] の `⌊X·c/100⌋` に等しい。
割り切れるとき、[Source] は等しいか 1 小さい。因子が安全（`Safe`）なら等しい。
-/

set_option exponentiation.threshold 2048

namespace Abstraction.Fare

open LangSemantics.Java LangSemantics.Java.JDouble

/-- 基本運賃の因子 `ratio * 0.01`（`calculateBasicFare`）。 -/
def basicFactor (c : Nat) : JDouble := jdmul (jd (c : Int)) (jdLit "0.01")

/-- 運賃の因子 `1 − discountRate * 0.01`（`calculateFare`）。 -/
def fareFactor (r : Nat) : JDouble := jdsub (jd 1) (jdmul (jd (r : Int)) (jdLit "0.01"))

/-- 因子が正の有限値 `fm·2^(−fs)`（`fs ≤ 1000`）で、正確な値 `c/100` に近い。 -/
def FactorOk (F : JDouble) (c : Nat) : Prop :=
  ∃ fm fs : Nat, F = .finite false fm (-(fs : Int)) ∧ fs ≤ 1000 ∧ Close c fm fs

/-- 因子が安全（`Safe`）。 -/
def FactorSafe (F : JDouble) (c : Nat) : Prop :=
  ∃ fm fs : Nat, F = .finite false fm (-(fs : Int)) ∧ Safe c fm fs

/-- 判定（カーネルの評価用）。 -/
def factorOk? (F : JDouble) (c : Nat) : Bool :=
  match F with
  | .finite false fm e => decide (e < 0) && decide ((-e).toNat ≤ 1000) && decide (Close c fm (-e).toNat)
  | _ => false

def factorSafe? (F : JDouble) (c : Nat) : Bool :=
  match F with
  | .finite false fm e => decide (e < 0) && decide (Safe c fm (-e).toNat)
  | _ => false

theorem factorOk_of {F : JDouble} {c : Nat} (h : factorOk? F c = true) : FactorOk F c := by
  unfold factorOk? at h
  split at h
  · rename_i fm e
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨he, hfs⟩, hc⟩ := h
    exact ⟨fm, (-e).toNat, by congr 1; omega, hfs, hc⟩
  · cases h

theorem factorSafe_of {F : JDouble} {c : Nat} (h : factorSafe? F c = true) : FactorSafe F c := by
  unfold factorSafe? at h
  split at h
  · rename_i fm e
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    exact ⟨fm, (-e).toNat, by congr 1; omega, h.2⟩
  · cases h

set_option maxRecDepth 100000 in
/-- 積算比率 1〜1000 の基本運賃の因子は、どれも正確な値に近い。 -/
theorem basicFactor_ok_all : ((List.range 1000).map (· + 1)).all (fun c => factorOk? (basicFactor c) c) = true := by
  decide +kernel

set_option maxRecDepth 100000 in
/-- 割引率 0〜99 の運賃の因子は、どれも正確な値に近い（割引率 100 の因子は 0）。 -/
theorem fareFactor_ok_all : (List.range 100).all (fun r => factorOk? (fareFactor r) (100 - r)) = true := by
  decide +kernel

theorem basicFactor_ok {c : Nat} (h0 : c ≠ 0) (h : c ≤ 1000) : FactorOk (basicFactor c) c := by
  apply factorOk_of
  have := List.all_eq_true.mp basicFactor_ok_all c (List.mem_map.mpr ⟨c - 1, List.mem_range.mpr (by omega), by omega⟩)
  exact this

theorem fareFactor_ok {r : Nat} (h : r < 100) : FactorOk (fareFactor r) (100 - r) :=
  factorOk_of (List.all_eq_true.mp fareFactor_ok_all r (List.mem_range.mpr h))

/-! ## 式の比較 -/

theorem mul_zero_right' (s : Bool) (m : Nat) (e : Int) :
    JDouble.mul (.finite s m e) (.finite false 0 0) = .finite (s != false) 0 0 := by
  simp [JDouble.mul, toRat?, ofRat]

theorem mul_zero_left' (t : Bool) (m : Nat) (e : Int) :
    JDouble.mul (.finite false 0 0) (.finite t m e) = .finite (false != t) 0 0 := by
  simp [JDouble.mul, toRat?, ofRat]

theorem toJ32_zero (s : Bool) : (toJ32 (.finite s 0 0)).val = 0 := by cases s <;> decide

/-- `X < 2^53` の `(double) X` は正の有限値（`X = 0` なら `+0`）。 -/
theorem jd_nat_finite {X : Nat} (h : X < 2 ^ 53) : ∃ m e, jd (X : Int) = .finite false m e := by
  by_cases h0 : X = 0
  · subst h0; exact ⟨0, 0, by decide⟩
  · exact ⟨_, _, ofInt_nat h0 h⟩

/-- 因子 `F`（`c/100` に近い）について、[Source] の `(int)(X * F)` は [Spec] の `⌊X·c/100⌋` に等しいか、
`X·c` が 100 で割り切れ、因子が安全でなく、1 小さい。 -/
theorem jd2i_factor {X c : Nat} {F : JDouble} (hF : FactorOk F c) (hX : X ≠ 0) (hc : c ≠ 0)
    (hr : X * c < 100 * 2 ^ 28) :
    (jd2i (jdmul (jd (X : Int)) F)).val = ((X * c / 100 : Nat) : Int) ∨
    (X * c % 100 = 0 ∧ 0 < X * c ∧ ¬ FactorSafe F c ∧ (jd2i (jdmul (jd (X : Int)) F)).val + 1 = ((X * c / 100 : Nat) : Int)) := by
  obtain ⟨fm, fs, rfl, hfs, hcl⟩ := hF
  obtain ⟨hfm, hlo, hhi⟩ := close_range hX hc hfs hr hcl
  have hX53 : X < 2 ^ 53 := by
    have : X ≤ X * c := Nat.le_mul_of_pos_right _ (Nat.pos_of_ne_zero hc)
    omega
  have hhi' : X * fm < 2 ^ fs * 2 ^ 31 :=
    Nat.lt_of_lt_of_le hhi (Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by decide)))
  rw [jd2i_mul_nat hX hX53 hfm hlo hhi']
  obtain ⟨r1, r2, r3⟩ := rneTrunc_factor hX hc hfs hr hcl
  have hk : X * c / 100 < 2 ^ 28 := by omega
  have hmax : J32.maxValue = 2147483647 := rfl
  rw [hmax]
  by_cases hj : X * c % 100 = 0
  · by_cases hs : FactorSafe (.finite false fm (-(fs : Int))) c
    · obtain ⟨fm', fs', he, hs'⟩ := hs
      simp only [JDouble.finite.injEq, true_and] at he
      obtain ⟨rfl, he⟩ := he
      have : fs = fs' := by omega
      subst this
      have := r3 hj hs'
      left; rw [this]; omega
    · rcases r2 hj with h | h
      · left; rw [h]; omega
      · right; refine ⟨hj, Nat.mul_pos (Nat.pos_of_ne_zero hX) (Nat.pos_of_ne_zero hc), hs, ?_⟩; omega
  · left; rw [r1 hj]; omega

/-- `c = 0`・`X = 0` を含めた形（因子 `F` は `c = 0` なら `+0`）。 -/
theorem jd2i_factor' {X c : Nat} {F : JDouble} (hX53 : X < 2 ^ 53) (h0 : c = 0 → F = .finite false 0 0)
    (hF : c ≠ 0 → FactorOk F c) (hr : X * c < 100 * 2 ^ 28) :
    (jd2i (jdmul (jd (X : Int)) F)).val = ((X * c / 100 : Nat) : Int) ∨
    (X * c % 100 = 0 ∧ 0 < X * c ∧ ¬ FactorSafe F c ∧ (jd2i (jdmul (jd (X : Int)) F)).val + 1 = ((X * c / 100 : Nat) : Int)) := by
  by_cases hc : c = 0
  · subst hc; rw [h0 rfl]
    obtain ⟨m, e, he⟩ := jd_nat_finite hX53
    left; rw [he]; simp [jdmul, jd2i, mul_zero_right', toJ32_zero]
  by_cases hX : X = 0
  · subst hX
    obtain ⟨fm, fs, rfl, -, -⟩ := hF hc
    left; simp [jd, ofInt, ofRat, jdmul, jd2i, mul_zero_left', toJ32_zero]
  exact jd2i_factor (hF hc) hX hc hr

/-- 積算比率 0〜1000 の因子。 -/
theorem basicFactor_ok' {c : Nat} (h : c ≤ 1000) :
    (c = 0 → basicFactor c = .finite false 0 0) ∧ (c ≠ 0 → FactorOk (basicFactor c) c) :=
  ⟨fun h0 => by subst h0; decide, fun h0 => basicFactor_ok h0 h⟩

/-- 割引率 0〜100 の因子（`100 − r` に対して）。 -/
theorem fareFactor_ok' {r : Nat} (h : r ≤ 100) :
    (100 - r = 0 → fareFactor r = .finite false 0 0) ∧ (100 - r ≠ 0 → FactorOk (fareFactor r) (100 - r)) :=
  ⟨fun h0 => by rw [show r = 100 by omega]; decide, fun h0 => fareFactor_ok (by omega)⟩

/-! ## 基本運賃（D-001） -/

/-- [Source] の基本運賃の式 `(int)(X * (c * 0.01))` は [Spec] の `X·c/100` に等しいか、
`X·c` が 100 で割り切れ、積算比率 `c` の因子が安全でなく、1 小さい。 -/
theorem basicFare_src {X c : Nat} (hc : c ≤ 1000) (hX : X < 2 ^ 53) (hr : X * c < 100 * 2 ^ 28) :
    (jd2i (jdmul (jd (X : Int)) (basicFactor c))).val = ((X * c / 100 : Nat) : Int) ∨
    (X * c % 100 = 0 ∧ 0 < X * c ∧ ¬ FactorSafe (basicFactor c) c ∧
      (jd2i (jdmul (jd (X : Int)) (basicFactor c))).val + 1 = ((X * c / 100 : Nat) : Int)) :=
  jd2i_factor' hX (basicFactor_ok' hc).1 (basicFactor_ok' hc).2 hr

/-- 差異が起きない条件（D-001 の前提）: `X·c` が 100 で割り切れないか、因子が安全。 -/
theorem basicFare_src_eq {X c : Nat} (hc : c ≤ 1000) (hX : X < 2 ^ 53) (hr : X * c < 100 * 2 ^ 28)
    (h : X * c % 100 ≠ 0 ∨ FactorSafe (basicFactor c) c) :
    (jd2i (jdmul (jd (X : Int)) (basicFactor c))).val = ((X * c / 100 : Nat) : Int) := by
  rcases basicFare_src hc hX hr with e | ⟨h1, -, h2, -⟩
  · exact e
  · rcases h with h | h <;> contradiction

set_option maxRecDepth 100000 in
/-- 安全でない積算比率（1〜1000 のうち 49 個）。 -/
theorem basicFactor_unsafe :
    (List.range 1001).filter (fun c => c != 0 && !factorSafe? (basicFactor c) c) =
      [29, 58, 116, 117, 141, 205, 207, 209, 211, 232, 234, 257, 282, 410, 414, 418, 422, 439, 443, 447, 464, 468,
       489, 493, 514, 539, 564, 803, 811, 819, 820, 828, 836, 844, 845, 853, 861, 869, 878, 886, 894, 903, 911, 928,
       936, 953, 961, 978, 986] := by
  decide +kernel

set_option maxRecDepth 100000 in
/-- シードの積算比率（100・110・120・125・130・140・150）の因子は安全。 -/
theorem basicFactor_safe_seed : [100, 110, 120, 125, 130, 140, 150].all (fun c => factorSafe? (basicFactor c) c) = true := by
  decide +kernel

/-- D-001 の差異の証拠: 基本運賃 100 円・積算比率 29% で、[Source] は 28 円、[Spec] は 29 円。 -/
theorem basicFare_witness : (jd2i (jdmul (jd 100) (basicFactor 29))).val = 28 := by decide

/-! ## 運賃（D-002） -/

/-- [Source] の運賃の式 `ceilFare((int)(b * (1 − r * 0.01)))` は [Spec] の `fare b r` に等しいか、
`b·(100−r) ≡ 100 (mod 10000)`（切り捨てた値が `≡ 1 (mod 100)`）で、割引率 `r` の因子が安全でなく、100 円少ない。 -/
theorem fare_src {b r : Nat} (hr : r ≤ 100) (hb : b < 2 ^ 53) (hbr : b * (100 - r) < 100 * 2 ^ 28) :
    (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))).val = (Spec.Fare.fare b r : Int) ∨
    (b * (100 - r) % 10000 = 100 ∧ ¬ FactorSafe (fareFactor r) (100 - r) ∧
      (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))).val + 100 = (Spec.Fare.fare b r : Int)) := by
  have hv : ∀ (S : J32) (k : Nat), S.val = (k : Int) → k < 2 ^ 28 →
      (bdCeilHundredUp S).val = (((k + 99) / 100 * 100 : Nat) : Int) := fun S k e hk => by
    rw [bdCeilHundredUp_val (by rw [e]; omega) (by rw [e, Int.toNat_natCast]; omega), e, Int.toNat_natCast]
  have hspec : Spec.Fare.fare b r = (b * (100 - r) / 100 + 99) / 100 * 100 := by
    simp only [Spec.Fare.fare, Spec.Prim.ceilTo, Spec.Prim.pct]
    congr 2
  rw [hspec]
  rcases jd2i_factor' hb (fareFactor_ok' hr).1 (fareFactor_ok' hr).2 hbr with e | ⟨h1, h0, h2, e⟩
  · left
    rw [hv _ _ e (by omega)]
  · have e' : (jd2i (jdmul (jd (b : Int)) (fareFactor r))).val = ((b * (100 - r) / 100 - 1 : Nat) : Int) := by
      omega
    rw [hv _ _ e' (by omega)]
    generalize b * (100 - r) = P at *
    by_cases hk : P % 10000 = 100
    · right; refine ⟨hk, h2, ?_⟩; omega
    · left; omega

/-- 差異が起きない条件（D-002 の前提）。 -/
theorem fare_src_eq {b r : Nat} (hr : r ≤ 100) (hb : b < 2 ^ 53) (hbr : b * (100 - r) < 100 * 2 ^ 28)
    (h : b * (100 - r) % 10000 ≠ 100 ∨ FactorSafe (fareFactor r) (100 - r)) :
    (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))).val = (Spec.Fare.fare b r : Int) := by
  rcases fare_src hr hb hbr with e | ⟨h1, h2, -⟩
  · exact e
  · rcases h with h | h <;> contradiction

set_option maxRecDepth 100000 in
/-- 安全でない割引率（0〜99 のうち 33 個）。 -/
theorem fareFactor_unsafe :
    (List.range 101).filter (fun r => r != 100 && !factorSafe? (fareFactor r) (100 - r)) =
      [6, 7, 30, 31, 32, 33, 34, 35, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70, 77, 78, 79, 80, 81, 82, 83, 89, 90,
       91, 92, 93, 94, 95] := by
  decide +kernel

/-- シードの割引率（0・5・10・20）の因子は安全。 -/
theorem fareFactor_safe_seed : [0, 5, 10, 20].all (fun r => factorSafe? (fareFactor r) (100 - r)) = true := by
  decide +kernel

/-- D-002 の差異の証拠: 基本運賃 1430 円・割引率 30% で、[Source] は 1000 円、[Spec] は 1100 円。 -/
theorem fare_witness :
    (bdCeilHundredUp (jd2i (jdmul (jd 1430) (fareFactor 30)))).val = 1000 ∧ Spec.Fare.fare 1430 30 = 1100 := by
  decide

/-! ## 安全でない因子の一覧（差異の前提に使う） -/

/-- 安全でない積算比率（`basicFactor_unsafe`）。D-001 の前提 `dev_D001` に使う。 -/
def unsafeBasicRatios : List Nat :=
  [29, 58, 116, 117, 141, 205, 207, 209, 211, 232, 234, 257, 282, 410, 414, 418, 422, 439, 443, 447, 464, 468,
   489, 493, 514, 539, 564, 803, 811, 819, 820, 828, 836, 844, 845, 853, 861, 869, 878, 886, 894, 903, 911, 928,
   936, 953, 961, 978, 986]

/-- 安全でない割引率（`fareFactor_unsafe`）。D-002 の前提 `dev_D002` に使う。 -/
def unsafeDiscountRates : List Nat :=
  [6, 7, 30, 31, 32, 33, 34, 35, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70, 77, 78, 79, 80, 81, 82, 83, 89, 90,
   91, 92, 93, 94, 95]

theorem basicFactor_safe_of {c : Nat} (h0 : c ≠ 0) (h : c ≤ 1000) (hn : c ∉ unsafeBasicRatios) :
    FactorSafe (basicFactor c) c := by
  apply factorSafe_of
  cases hs : factorSafe? (basicFactor c) c
  · exfalso; apply hn
    show c ∈ unsafeBasicRatios
    rw [show unsafeBasicRatios = _ from basicFactor_unsafe.symm]
    exact List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simp [hs, h0]⟩
  · rfl

theorem fareFactor_safe_of {r : Nat} (h : r < 100) (hn : r ∉ unsafeDiscountRates) :
    FactorSafe (fareFactor r) (100 - r) := by
  apply factorSafe_of
  cases hs : factorSafe? (fareFactor r) (100 - r)
  · exfalso; apply hn
    show r ∈ unsafeDiscountRates
    rw [show unsafeDiscountRates = _ from fareFactor_unsafe.symm]
    exact List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simp [hs, show r ≠ 100 by omega]⟩
  · rfl

/-- D-001 の前提（一覧の形）の下での一致。 -/
theorem basicFare_src_eq' {X c : Nat} (hc : c ≤ 1000) (hX : X < 2 ^ 53) (hr : X * c < 100 * 2 ^ 28)
    (h : X * c % 100 ≠ 0 ∨ c ∉ unsafeBasicRatios) :
    (jd2i (jdmul (jd (X : Int)) (basicFactor c))).val = ((X * c / 100 : Nat) : Int) := by
  rcases basicFare_src hc hX hr with e | ⟨h1, h2, h3, -⟩
  · exact e
  · have hc0 : c ≠ 0 := by rintro rfl; simp at h2
    rcases h with h | h
    · exact absurd h1 h
    · exact absurd (basicFactor_safe_of hc0 hc h) h3

/-- D-002 の前提（一覧の形）の下での一致。 -/
theorem fare_src_eq' {b r : Nat} (hr : r ≤ 100) (hb : b < 2 ^ 53) (hbr : b * (100 - r) < 100 * 2 ^ 28)
    (h : b * (100 - r) % 10000 ≠ 100 ∨ r ∉ unsafeDiscountRates) :
    (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))).val = (Spec.Fare.fare b r : Int) := by
  rcases fare_src hr hb hbr with e | ⟨h1, h2, -⟩
  · exact e
  · rcases h with h | h
    · exact absurd h1 h
    · have hr' : r < 100 := by
        rcases Nat.lt_or_ge r 100 with h' | h'
        · exact h'
        · exfalso; rw [show 100 - r = 0 by omega, Nat.mul_zero] at h1; simp at h1
      exact absurd (fareFactor_safe_of hr' h) h2

end Abstraction.Fare
