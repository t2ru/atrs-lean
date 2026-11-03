import Trace

/-!
# Spec.Prim.Int

整数の基本演算（`lean/Spec/Prim/Int.lean#基本演算specprim`）。引数は数学的整数で、溢れは無い（ADR e41d）。
-/

namespace Spec.Prim.Int

/-!
## 基本演算（Spec.Prim）

**[Spec]** Lean: [`Spec.Prim.Int`](Int.lean)。引数は数学的整数で、溢れは無い。

| 演算 | 事前条件 | 要約 |
| --- | --- | --- |
| `floorDiv(a, b)` | `b > 0` | 床除算（`floorDiv_eq_iff` で特徴付け） |
| `ceilDiv(a, b)` | `b > 0` | 天井除算 |
| `ceilTo(a, m)` | `a ≥ 0`, `m > 0` | `a` 以上の `m` の倍数のうち最小のもの（`ceilTo_le_of_dvd`） |
| `pct(a, r)` | `a ≥ 0`, `r ≥ 0` | `a` の `r`% の切捨て |

**[Source]**（draft）の基本演算（`j32add`, `jdiv32`, `jdmul`, `jd2i`, `bdCeilHundredUp`, `utf16Len` など）は [ADR 935b](../../../docs/decision/935b-java-primitive-semantics.md) に定義する。
[Source] の Java 参照型（`Integer` 等）が `null` のまま演算された場合は、その操作の結果を `PreconditionViolation("NullPointerException")` とする。
-/

/-- `a / b` 以下の最大の整数（`b > 0`）。Lean の `Int` の `/` は、`b > 0` で床除算に一致する。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#基本演算specprim"]
def floorDiv (a b : Int) : Int := a / b

/-- `a / b` 以上の最小の整数（`b > 0`）。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#基本演算specprim"]
def ceilDiv (a b : Int) : Int := -((-a) / b)

/-- `a` を `m` の倍数に切り上げる（`a ≥ 0`, `m > 0`）。`ceilDiv a m * m` と同じ。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#基本演算specprim"]
def ceilTo (a m : Nat) : Nat := (a + m - 1) / m * m

/-- `a` の `r`% を切り捨てたもの（`a ≥ 0`, `r ≥ 0`）。`floorDiv (a * r) 100` と同じ。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#基本演算specprim"]
def pct (a r : Nat) : Nat := a * r / 100

theorem floorDiv_mul_le (a : Int) {b : Int} (hb : 0 < b) : floorDiv a b * b ≤ a :=
  Int.ediv_mul_le a (Int.ne_of_gt hb)

theorem lt_floorDiv_add_one_mul (a : Int) {b : Int} (hb : 0 < b) : a < (floorDiv a b + 1) * b :=
  Int.lt_ediv_add_one_mul_self a hb

/-- 床除算の特徴付け: `q * b ≤ a < (q + 1) * b` を満たす `q` は `floorDiv a b` だけである。 -/
theorem floorDiv_eq_iff (a : Int) {b q : Int} (hb : 0 < b) :
    floorDiv a b = q ↔ q * b ≤ a ∧ a < (q + 1) * b := by
  constructor
  · intro h; subst h; exact ⟨floorDiv_mul_le a hb, lt_floorDiv_add_one_mul a hb⟩
  · intro ⟨h₁, h₂⟩
    have e₁ := floorDiv_mul_le a hb
    have e₂ := lt_floorDiv_add_one_mul a hb
    have : q < floorDiv a b + 1 := by
      have : q * b < (floorDiv a b + 1) * b := Int.lt_of_le_of_lt h₁ e₂
      exact Int.lt_of_mul_lt_mul_right this (Int.le_of_lt hb)
    have : floorDiv a b < q + 1 := by
      have : floorDiv a b * b < (q + 1) * b := Int.lt_of_le_of_lt e₁ h₂
      exact Int.lt_of_mul_lt_mul_right this (Int.le_of_lt hb)
    omega

theorem le_ceilDiv_mul (a : Int) {b : Int} (hb : 0 < b) : a ≤ ceilDiv a b * b := by
  have := floorDiv_mul_le (-a) hb
  simp only [ceilDiv, floorDiv] at *
  rw [Int.neg_mul]; omega

theorem ceilDiv_sub_one_mul_lt (a : Int) {b : Int} (hb : 0 < b) : (ceilDiv a b - 1) * b < a := by
  have := lt_floorDiv_add_one_mul (-a) hb
  simp only [ceilDiv, floorDiv] at *
  rw [Int.sub_mul, Int.neg_mul, Int.one_mul]
  rw [Int.add_mul, Int.one_mul] at this
  omega

theorem le_ceilTo (a : Nat) {m : Nat} (hm : 0 < m) : a ≤ ceilTo a m := by
  unfold ceilTo
  have := Nat.lt_div_mul_add (a := a + m - 1) hm
  omega

theorem ceilTo_lt (a : Nat) {m : Nat} (hm : 0 < m) : ceilTo a m < a + m := by
  unfold ceilTo
  have := Nat.div_mul_le_self (a + m - 1) m
  omega

theorem dvd_ceilTo (a m : Nat) : m ∣ ceilTo a m := Nat.dvd_mul_left m _

/-- `ceilTo a m` は、`a` 以上の `m` の倍数のうち最小のもの。 -/
theorem ceilTo_le_of_dvd {a m n : Nat} (hm : 0 < m) (hd : m ∣ n) (ha : a ≤ n) : ceilTo a m ≤ n := by
  obtain ⟨k, rfl⟩ := hd
  have h₁ := le_ceilTo a hm
  have h₂ := ceilTo_lt a hm
  obtain ⟨j, hj⟩ := dvd_ceilTo a m
  rw [hj] at h₁ h₂ ⊢
  have : j < k + 1 := by
    have : m * j < m * (k + 1) := by rw [Nat.mul_add, Nat.mul_one]; omega
    exact Nat.lt_of_mul_lt_mul_left this
  exact Nat.mul_le_mul_left m (by omega)

theorem pct_eq_floorDiv (a r : Nat) : (pct a r : Int) = floorDiv (a * r) 100 := by
  simp [pct, floorDiv]

#guard floorDiv (-7) 2 == -4
#guard ceilDiv (-7) 2 == -3
#guard ceilDiv 7 2 == 4
#guard ceilTo 1001 100 == 1100
#guard ceilTo 1000 100 == 1000
#guard ceilTo 0 100 == 0
#guard pct 1430 70 == 1001

end Spec.Prim.Int
