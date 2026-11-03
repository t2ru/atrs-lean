import LangSemantics.Java.JDouble.Lemmas

/-!
# LangSemantics.Java.JDouble.Compare

double の式 `(int)(X * F)` と、整数の式 `⌊X·c/100⌋` の比較（百分率の因子を掛けて切り捨てる式）。
`F = fm·2^(−fs)` は `c/100` を double に丸めた因子である（`JDouble.jd2i_mul_nat` で
`rneTrunc (X·fm) (2^fs)` に書き直してから比べる）。

- `rneTrunc_le`・`le_rneTrunc`・`pred_le_rneTrunc`・`le_rneTrunc_safe`: 丸めて切り捨てた値の上下の評価
- `Close`・`Safe`: 因子が正確な値に近い（相対誤差 `2^-48` 以内）、安全（`2^-54` 未満しか下回らない）
- `rneTrunc_factor`・`jd2i_factor`・`jd2i_factor'`: `X·c` が 100 で割り切れないなら等しく、割り切れるなら等しいか 1 小さい。
  因子が安全なら等しい
- `FactorOk`・`FactorSafe` と判定 `factorOk?`・`factorSafe?`（カーネルの評価で因子の表を確かめる）
-/

set_option exponentiation.threshold 2048

namespace LangSemantics.Java.JDouble
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.Int

/-- 上からの評価: `X·F ≤ (k + 99/100)·(1 + 2^-48)` なら `rneTrunc ≤ k`。 -/
theorem rneTrunc_le {N D k : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 29)
    (hk : k < 2 ^ 30) (h : 100 * 2 ^ 48 * N ≤ (2 ^ 48 + 1) * (100 * k + 99) * D) : rneTrunc N D ≤ k := by
  obtain ⟨Q, M, ht, hQ, -, -, r1, -⟩ := rneTrunc_spec hN hD hlo hhi
  rw [ht]
  apply Nat.lt_succ_iff.mp
  apply (Nat.div_lt_iff_lt_mul (by omega)).mpr
  -- M < (k+1)·Q を、D を掛けた形で示す
  apply Nat.lt_of_mul_lt_mul_right (a := D)
  have h1 := Nat.mul_le_mul_right Q h
  have h2 : 2 ^ 23 * D ≤ Q * D := Nat.mul_le_mul_right D hQ
  have h3 : k * (Q * D) ≤ 2 ^ 30 * (Q * D) := Nat.mul_le_mul_right _ (Nat.le_of_lt hk)
  have e1 : 100 * 2 ^ 48 * N * Q = 100 * 2 ^ 48 * (N * Q) := by simp only [Nat.mul_assoc]
  have e2 : (2 ^ 48 + 1) * (100 * k + 99) * D * Q = (2 ^ 48 + 1) * 100 * (k * (Q * D)) + (2 ^ 48 + 1) * 99 * (Q * D) := by
    simp only [Nat.mul_add, Nat.add_mul, Nat.mul_assoc, Nat.mul_comm D Q, Nat.mul_left_comm k]
  have e3 : (k + 1) * Q * D = k * (Q * D) + Q * D := by simp only [Nat.add_mul, Nat.one_mul, Nat.mul_assoc]
  rw [e1, e2] at h1
  rw [e3]
  generalize N * Q = A at *
  generalize M * D = B at *
  generalize k * (Q * D) = P at *
  generalize Q * D = R at *
  omega

/-- 下からの評価: `X·F ≥ k` なら `rneTrunc ≥ k`。 -/
theorem le_rneTrunc {N D k : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 29)
    (h : k * D ≤ N) : k ≤ rneTrunc N D := by
  obtain ⟨Q, M, ht, hQ, -, -, -, r2⟩ := rneTrunc_spec hN hD hlo hhi
  rw [ht]
  apply (Nat.le_div_iff_mul_le (by have := Nat.two_pow_pos 23; omega)).mpr
  apply Nat.le_of_lt_succ
  apply Nat.lt_of_mul_lt_mul_right (a := D)
  have h1 := Nat.mul_le_mul_right Q h
  have e1 : k * D * Q = k * (Q * D) := by simp only [Nat.mul_assoc, Nat.mul_comm D Q]
  have e3 : (M + 1) * D = M * D + D := by simp only [Nat.add_mul, Nat.one_mul]
  have e4 : k * Q * D = k * (Q * D) := by simp only [Nat.mul_assoc]
  rw [e1] at h1
  rw [e3, e4]
  have hD0 : 0 < D := Nat.pos_of_ne_zero hD
  generalize N * Q = A at *
  generalize M * D = B at *
  generalize k * (Q * D) = P at *
  omega

/-- 整数の場合の下からの評価: `X·F ≥ k·(1 − 2^-48)` なら `rneTrunc ≥ k − 1`。 -/
theorem pred_le_rneTrunc {N D k : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 29)
    (hk : k < 2 ^ 30) (h : 2 ^ 48 * (k * D) ≤ 2 ^ 48 * N + k * D) : k - 1 ≤ rneTrunc N D := by
  obtain ⟨Q, M, ht, hQ, -, -, -, r2⟩ := rneTrunc_spec hN hD hlo hhi
  rw [ht]
  apply (Nat.le_div_iff_mul_le (by have := Nat.two_pow_pos 23; omega)).mpr
  apply Nat.le_of_lt_succ
  apply Nat.lt_of_mul_lt_mul_right (a := D)
  have h1 := Nat.mul_le_mul_right Q h
  have h2 : 2 ^ 23 * D ≤ Q * D := Nat.mul_le_mul_right D hQ
  have h3 : k * (Q * D) ≤ 2 ^ 30 * (Q * D) := Nat.mul_le_mul_right _ (Nat.le_of_lt hk)
  have e1 : (2 ^ 48 * (k * D) * Q) = 2 ^ 48 * (k * (Q * D)) := by
    simp only [Nat.mul_assoc, Nat.mul_comm D Q]
  have e2 : (2 ^ 48 * N + k * D) * Q = 2 ^ 48 * (N * Q) + k * (Q * D) := by
    simp only [Nat.add_mul, Nat.mul_assoc, Nat.mul_comm D Q]
  have e3 : (M + 1) * D = M * D + D := by simp only [Nat.add_mul, Nat.one_mul]
  have e4 : (k - 1) * Q * D = k * (Q * D) - Q * D := by
    rw [Nat.mul_assoc, Nat.sub_mul, Nat.one_mul]
  rw [e1, e2] at h1
  rw [e3, e4]
  have hD0 : 0 < D := Nat.pos_of_ne_zero hD
  generalize N * Q = A at *
  generalize M * D = B at *
  generalize k * (Q * D) = P at *
  generalize Q * D = R at *
  omega

/-- 安全な因子の整数の場合: `2^54·(k·D − X·fm) < k·D` なら `rneTrunc ≥ k`。 -/
theorem le_rneTrunc_safe {N D k : Nat} (hN : N ≠ 0) (hD : D ≠ 0) (hlo : D ≤ N * 2 ^ 1000) (hhi : N < D * 2 ^ 29)
    (h : 2 ^ 54 * (k * D) < 2 ^ 54 * N + k * D) : k ≤ rneTrunc N D := by
  obtain ⟨Q, M, ht, hQ, -, h53, -, r2⟩ := rneTrunc_spec hN hD hlo hhi
  rw [ht]
  apply (Nat.le_div_iff_mul_le (by have := Nat.two_pow_pos 23; omega)).mpr
  apply Nat.le_of_lt_succ
  apply Nat.lt_of_mul_lt_mul_right (a := D)
  have h1 := Nat.mul_lt_mul_of_pos_right h (show 0 < Q by have := Nat.two_pow_pos 23; omega)
  have e1 : (2 ^ 54 * (k * D) * Q) = 2 ^ 54 * (k * (Q * D)) := by
    simp only [Nat.mul_assoc, Nat.mul_comm D Q]
  have e2 : (2 ^ 54 * N + k * D) * Q = 2 ^ 54 * (N * Q) + k * (Q * D) := by
    simp only [Nat.add_mul, Nat.mul_assoc, Nat.mul_comm D Q]
  rw [e1, e2] at h1
  -- k·Q ≤ 2^53
  have hP : k * (Q * D) < (2 ^ 53 + 1) * D := by
    generalize N * Q = A at *
    generalize k * (Q * D) = P at *
    omega
  have hkQ : k * Q ≤ 2 ^ 53 := by
    have : k * Q * D < (2 ^ 53 + 1) * D := by rw [Nat.mul_assoc]; exact hP
    have := Nat.lt_of_mul_lt_mul_right this
    omega
  have hP' : k * (Q * D) ≤ 2 ^ 53 * D := by rw [← Nat.mul_assoc]; exact Nat.mul_le_mul_right D hkQ
  have e3 : (M + 1) * D = M * D + D := by simp only [Nat.add_mul, Nat.one_mul]
  have e4 : k * Q * D = k * (Q * D) := by simp only [Nat.mul_assoc]
  rw [e3, e4]
  have hD0 : 0 < D := Nat.pos_of_ne_zero hD
  generalize N * Q = A at *
  generalize M * D = B at *
  generalize k * (Q * D) = P at *
  omega

/-- 因子 `F = fm·2^(−fs)` が `c/100` の相対誤差 `2^-48` 以内にある。 -/
def Close (c fm fs : Nat) : Prop :=
  2 ^ 48 * (100 * fm) ≤ (2 ^ 48 + 1) * (c * 2 ^ fs) ∧ 2 ^ 48 * (c * 2 ^ fs) ≤ (2 ^ 48 + 1) * (100 * fm)

/-- 安全な因子: `F` が `c/100` より小さくても、その相対誤差が `2^-54` 未満（大きい場合も含む）。 -/
def Safe (c fm fs : Nat) : Prop := 2 ^ 54 * (c * 2 ^ fs) < 2 ^ 54 * (100 * fm) + c * 2 ^ fs

instance (c fm fs : Nat) : Decidable (Close c fm fs) := by unfold Close; infer_instance
instance (c fm fs : Nat) : Decidable (Safe c fm fs) := by unfold Safe; infer_instance

/-- `Close` な因子の値域: `fm ≠ 0`、`2^fs ≤ X·fm·2^1000`、`X·fm < 2^fs·2^29`（`jd2i_mul_nat`・`rneTrunc_spec` の前提）。 -/
theorem close_range {X c fm fs : Nat} (hX : X ≠ 0) (hc : c ≠ 0) (hfs : fs ≤ 1000) (hr : X * c < 100 * 2 ^ 28)
    (hcl : Close c fm fs) : fm ≠ 0 ∧ 2 ^ fs ≤ X * fm * 2 ^ 1000 ∧ X * fm < 2 ^ fs * 2 ^ 29 := by
  obtain ⟨h1, h2⟩ := hcl
  have hfm : fm ≠ 0 := by
    intro e; subst e
    have : 0 < c * 2 ^ fs := Nat.mul_pos (Nat.pos_of_ne_zero hc) (Nat.two_pow_pos _)
    simp at h2; omega
  refine ⟨hfm, ?_, ?_⟩
  · have : 2 ^ fs ≤ 2 ^ 1000 := Nat.pow_le_pow_right (by decide) hfs
    have : 1 ≤ X * fm := Nat.pos_of_ne_zero (Nat.mul_ne_zero hX hfm)
    calc 2 ^ fs ≤ 1 * 2 ^ 1000 := by omega
      _ ≤ X * fm * 2 ^ 1000 := Nat.mul_le_mul_right _ this
  · have g1 := Nat.mul_le_mul_left X h1
    have a1 : X * (2 ^ 48 * (100 * fm)) = 2 ^ 48 * (100 * (X * fm)) := by ac_rfl
    have a2 : X * ((2 ^ 48 + 1) * (c * 2 ^ fs)) = (2 ^ 48 + 1) * (X * c * 2 ^ fs) := by ac_rfl
    have hY : X * c * 2 ^ fs ≤ (100 * 2 ^ 28 - 1) * 2 ^ fs := Nat.mul_le_mul_right _ (by omega)
    rw [a1, a2] at g1
    have hT : 0 < 2 ^ fs := Nat.two_pow_pos _
    generalize X * fm = N at *
    generalize X * c * 2 ^ fs = P at *
    generalize 2 ^ fs = T at *
    omega

/-- 因子の比較の結論。`X·c` が 100 で割り切れなければ一致し、割り切れれば一致するか 1 小さく、安全な因子なら一致する。 -/
theorem rneTrunc_factor {X c fm fs : Nat} (hX : X ≠ 0) (hc : c ≠ 0) (hfs : fs ≤ 1000) (hr : X * c < 100 * 2 ^ 28)
    (hcl : Close c fm fs) :
    (X * c % 100 ≠ 0 → rneTrunc (X * fm) (2 ^ fs) = X * c / 100) ∧
    (X * c % 100 = 0 → rneTrunc (X * fm) (2 ^ fs) = X * c / 100 ∨ rneTrunc (X * fm) (2 ^ fs) + 1 = X * c / 100) ∧
    (X * c % 100 = 0 → Safe c fm fs → rneTrunc (X * fm) (2 ^ fs) = X * c / 100) := by
  obtain ⟨h1, h2⟩ := hcl
  have hD : (2 : Nat) ^ fs ≠ 0 := Nat.pos_iff_ne_zero.mp (Nat.two_pow_pos _)
  have hD1 : 1 ≤ 2 ^ fs := Nat.two_pow_pos _
  -- X 倍して、原子 N = X·fm、K = k·2^fs、J = j·2^fs の線形の式にする
  have g1 := Nat.mul_le_mul_left X h1
  have g2 := Nat.mul_le_mul_left X h2
  have ek : X * c = 100 * (X * c / 100) + X * c % 100 := (Nat.div_add_mod _ _).symm
  generalize hk : X * c / 100 = k at *
  generalize hj : X * c % 100 = j at *
  have hj99 : j < 100 := by rw [← hj]; exact Nat.mod_lt _ (by decide)
  have eN : X * (100 * fm) = 100 * (X * fm) := by rw [Nat.mul_left_comm]
  have eC : X * (c * 2 ^ fs) = 100 * (k * 2 ^ fs) + j * 2 ^ fs := by
    rw [← Nat.mul_assoc, ek, Nat.add_mul, Nat.mul_assoc]
  have hjD : j * 2 ^ fs ≤ 99 * 2 ^ fs := Nat.mul_le_mul_right _ (by omega)
  have hfm : fm ≠ 0 := by
    intro e; subst e
    have : 0 < c * 2 ^ fs := Nat.mul_pos (Nat.pos_of_ne_zero hc) (Nat.two_pow_pos _)
    simp at h2; omega
  have hN : X * fm ≠ 0 := Nat.mul_ne_zero hX hfm
  have hk30 : k < 2 ^ 30 := by omega
  have a1 : X * (2 ^ 48 * (100 * fm)) = 2 ^ 48 * (X * (100 * fm)) := by ac_rfl
  have a2 : X * ((2 ^ 48 + 1) * (c * 2 ^ fs)) = (2 ^ 48 + 1) * (X * (c * 2 ^ fs)) := by ac_rfl
  have a3 : X * (2 ^ 48 * (c * 2 ^ fs)) = 2 ^ 48 * (X * (c * 2 ^ fs)) := by ac_rfl
  have a4 : X * ((2 ^ 48 + 1) * (100 * fm)) = (2 ^ 48 + 1) * (X * (100 * fm)) := by ac_rfl
  rw [a1, a2, eN, eC] at g1
  rw [a3, a4, eN, eC] at g2
  have hlo : 2 ^ fs ≤ X * fm * 2 ^ 1000 := by
    have : 2 ^ fs ≤ 2 ^ 1000 := Nat.pow_le_pow_right (by decide) hfs
    have : 1 ≤ X * fm := Nat.pos_of_ne_zero hN
    calc 2 ^ fs ≤ 1 * 2 ^ 1000 := by omega
      _ ≤ X * fm * 2 ^ 1000 := Nat.mul_le_mul_right _ this
  have hkD : k * 2 ^ fs ≤ 2 ^ 28 * 2 ^ fs := Nat.mul_le_mul_right _ (by omega)
  have hhi : X * fm < 2 ^ fs * 2 ^ 29 := by
    rw [Nat.mul_comm (2 ^ fs)]
    have : 2 ^ 29 * 2 ^ fs = 2 * (2 ^ 28 * 2 ^ fs) := by rw [← Nat.mul_assoc]
    rw [this]
    generalize X * fm = N at *
    generalize k * 2 ^ fs = K at *
    generalize j * 2 ^ fs = J at *
    generalize 2 ^ 28 * 2 ^ fs = T at *
    omega
  have up : rneTrunc (X * fm) (2 ^ fs) ≤ k := by
    apply rneTrunc_le hN hD hlo hhi hk30
    have e : (2 ^ 48 + 1) * (100 * k + 99) * 2 ^ fs = (2 ^ 48 + 1) * (100 * (k * 2 ^ fs) + 99 * 2 ^ fs) := by
      rw [Nat.mul_assoc]; congr 1; rw [Nat.add_mul, Nat.mul_assoc]
    rw [e, Nat.mul_assoc]
    generalize X * fm = N at *
    generalize k * 2 ^ fs = K at *
    generalize j * 2 ^ fs = J at *
    omega
  refine ⟨fun hj0 => ?_, fun hj0 => ?_, fun hj0 hs => ?_⟩
  · apply Nat.le_antisymm up
    apply le_rneTrunc hN hD hlo hhi
    have : 2 ^ fs ≤ j * 2 ^ fs := by
      have := Nat.mul_le_mul_right (2 ^ fs) (show 1 ≤ j by omega); simpa using this
    generalize X * fm = N at *
    generalize k * 2 ^ fs = K at *
    generalize j * 2 ^ fs = J at *
    omega
  · subst hj0
    simp only [Nat.zero_mul, Nat.add_zero] at g1 g2
    rcases Nat.lt_or_ge (X * fm) (k * 2 ^ fs) with hlt | hge
    · have := pred_le_rneTrunc hN hD hlo hhi hk30 (by
        generalize X * fm = N at *
        generalize k * 2 ^ fs = K at *
        omega)
      omega
    · exact Or.inl (Nat.le_antisymm up (le_rneTrunc hN hD hlo hhi hge))
  · subst hj0
    simp only [Nat.zero_mul, Nat.add_zero] at g1 g2
    apply Nat.le_antisymm up
    apply le_rneTrunc_safe hN hD hlo hhi
    have hs' := Nat.mul_lt_mul_of_pos_left hs (Nat.pos_of_ne_zero hX)
    have b1 : X * (2 ^ 54 * (c * 2 ^ fs)) = 2 ^ 54 * (X * (c * 2 ^ fs)) := by ac_rfl
    have b2 : X * (2 ^ 54 * (100 * fm)) = 2 ^ 54 * (X * (100 * fm)) := by ac_rfl
    rw [Nat.mul_add, b1, b2, eC, eN] at hs'
    simp only [Nat.zero_mul, Nat.add_zero] at hs'
    generalize X * fm = N at *
    generalize k * 2 ^ fs = K at *
    omega

/-- 因子が正の有限値 `fm·2^(−fs)`（`fs ≤ 1000`）で、正確な値 `c/100` に近い。 -/
def FactorOk (F : JDouble) (c : Nat) : Prop :=
  ∃ (fm fs : Nat) (h : Canonical fm (-(fs : Int))), F = .finite false fm (-(fs : Int)) h ∧ fs ≤ 1000 ∧ Close c fm fs

/-- 因子が安全（`Safe`）。 -/
def FactorSafe (F : JDouble) (c : Nat) : Prop :=
  ∃ (fm fs : Nat) (h : Canonical fm (-(fs : Int))), F = .finite false fm (-(fs : Int)) h ∧ Safe c fm fs

/-- 判定（カーネルの評価用）。 -/
def factorOk? (F : JDouble) (c : Nat) : Bool :=
  match F with
  | .finite false fm e _ => decide (e < 0) && decide ((-e).toNat ≤ 1000) && decide (Close c fm (-e).toNat)
  | _ => false

def factorSafe? (F : JDouble) (c : Nat) : Bool :=
  match F with
  | .finite false fm e _ => decide (e < 0) && decide (Safe c fm (-e).toNat)
  | _ => false

theorem factorOk_of {F : JDouble} {c : Nat} (h : factorOk? F c = true) : FactorOk F c := by
  unfold factorOk? at h
  split at h
  · rename_i fm e hcan
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨he, hfs⟩, hc⟩ := h
    obtain ⟨k, rfl⟩ : ∃ k : Nat, e = -(k : Int) := ⟨(-e).toNat, by omega⟩
    simp only [Int.neg_neg, Int.toNat_natCast] at hfs hc
    exact ⟨fm, k, hcan, rfl, hfs, hc⟩
  · cases h

theorem factorSafe_of {F : JDouble} {c : Nat} (h : factorSafe? F c = true) : FactorSafe F c := by
  unfold factorSafe? at h
  split at h
  · rename_i fm e hcan
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨k, rfl⟩ : ∃ k : Nat, e = -(k : Int) := ⟨(-e).toNat, by omega⟩
    have h2 := h.2
    simp only [Int.neg_neg, Int.toNat_natCast] at h2
    exact ⟨fm, k, hcan, rfl, h2⟩
  · cases h

/-! ## 百分率の因子の式 -/

theorem mul_zero_right' (s : Bool) (m : Nat) (e : Int) (h : Canonical m e) :
    JDouble.mul (.finite s m e h) (.finite false 0 0 canon_zero) = .finite (s != false) 0 0 canon_zero := by
  simp [JDouble.mul, toRat?, ofRat]

theorem mul_zero_left' (t : Bool) (m : Nat) (e : Int) (h : Canonical m e) :
    JDouble.mul (.finite false 0 0 canon_zero) (.finite t m e h) = .finite (false != t) 0 0 canon_zero := by
  simp [JDouble.mul, toRat?, ofRat]

theorem toJ32_zero (s : Bool) : (toJ32 (.finite s 0 0 canon_zero)).val = 0 := by cases s <;> decide

/-- `X < 2^53` の `(double) X` は正の有限値（`X = 0` なら `+0`）。 -/
theorem jd_nat_finite {X : Nat} (h : X < 2 ^ 53) : ∃ m e hc, jd (X : Int) = .finite false m e hc := by
  by_cases h0 : X = 0
  · subst h0; exact ⟨0, 0, canon_zero, by decide⟩
  · obtain ⟨hc, he⟩ := ofInt_nat h0 h
    exact ⟨_, _, hc, he⟩

/-- 因子 `F`（`c/100` に近い）について、[Source] の `(int)(X * F)` は [Spec] の `⌊X·c/100⌋` に等しいか、
`X·c` が 100 で割り切れ、因子が安全でなく、1 小さい。 -/
theorem jd2i_factor {X c : Nat} {F : JDouble} (hF : FactorOk F c) (hX : X ≠ 0) (hc : c ≠ 0)
    (hr : X * c < 100 * 2 ^ 28) :
    (jd2i (jdmul (jd (X : Int)) F)).val = ((X * c / 100 : Nat) : Int) ∨
    (X * c % 100 = 0 ∧ 0 < X * c ∧ ¬ FactorSafe F c ∧ (jd2i (jdmul (jd (X : Int)) F)).val + 1 = ((X * c / 100 : Nat) : Int)) := by
  obtain ⟨fm, fs, hcan, rfl, hfs, hcl⟩ := hF
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
  · by_cases hs : FactorSafe (.finite false fm (-(fs : Int)) hcan) c
    · obtain ⟨fm', fs', _, he, hs'⟩ := hs
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
theorem jd2i_factor' {X c : Nat} {F : JDouble} (hX53 : X < 2 ^ 53) (h0 : c = 0 → F = posZero)
    (hF : c ≠ 0 → FactorOk F c) (hr : X * c < 100 * 2 ^ 28) :
    (jd2i (jdmul (jd (X : Int)) F)).val = ((X * c / 100 : Nat) : Int) ∨
    (X * c % 100 = 0 ∧ 0 < X * c ∧ ¬ FactorSafe F c ∧ (jd2i (jdmul (jd (X : Int)) F)).val + 1 = ((X * c / 100 : Nat) : Int)) := by
  by_cases hc : c = 0
  · subst hc; rw [h0 rfl]
    obtain ⟨m, e, hc, he⟩ := jd_nat_finite hX53
    left; rw [he]; simp [jdmul, jd2i, posZero, mul_zero_right', toJ32_zero]
  by_cases hX : X = 0
  · subst hX
    obtain ⟨fm, fs, _, rfl, -, -⟩ := hF hc
    left; simp [jd, ofInt, ofRat, jdmul, jd2i, mul_zero_left', toJ32_zero]
  exact jd2i_factor (hF hc) hX hc hr

end LangSemantics.Java.JDouble
