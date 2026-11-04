import Trace

/-!
# 整数の除算と百分率（`Spec.Prim.Int`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

運賃などの計算に使う整数の演算を定める。引数は数学的な整数（または自然数）で、桁あふれは無い。除算は記号 `/` で
書かず、切り捨て・切り上げを明示した演算で書く。
-/

namespace Spec.Prim.Int

/-!
## 整数の除算と百分率

**[Spec]**

| 演算 | 事前条件 | 定義 |
| --- | --- | --- |
| `floorDiv(a, b)` | `b > 0` | `a / b` 以下の最大の整数（床除算。`floorDiv_eq_iff` で特徴付ける） |
| `ceilDiv(a, b)` | `b > 0` | `a / b` 以上の最小の整数（天井除算） |
| `ceilTo(a, m)` | `a ≥ 0`, `m > 0` | `a` 以上の `m` の倍数のうち最小のもの（`ceilDiv(a, m) * m`。`ceilTo_le_of_dvd`） |
| `pct(a, r)` | `a ≥ 0`, `r ≥ 0` | `a` の `r`% を切り捨てたもの（`floorDiv(a * r, 100)`） |

例: `floorDiv(-7, 2) = -4`、`ceilDiv(-7, 2) = -3`、`ceilTo(1001, 100) = 1100`、`pct(1430, 70) = 1001`。

**[Source]** 移植元の Java の基本演算（32 ビット整数の演算 `j32add`・`jdiv32`、double の演算 `jdmul`・`jd2i`、
`BigDecimal` の切り上げ `bdCeilHundredUp`、UTF-16 の長さ `utf16Len` など）は、言語意味論 `LangSemantics.Java` が定める。
参照型（`Integer` など）が `null` のまま演算された場合、その操作の結果は前提違反
`PreconditionViolation("NullPointerException")` とする。
-/

/-- `a / b` 以下の最大の整数（`b > 0`）。Lean の `Int` の `/` は、`b > 0` で床除算に一致する。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#整数の除算と百分率"]
def floorDiv (a b : Int) : Int := a / b

/-- `a / b` 以上の最小の整数（`b > 0`）。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#整数の除算と百分率"]
def ceilDiv (a b : Int) : Int := -((-a) / b)

/-- `a` を `m` の倍数に切り上げる（`a ≥ 0`, `m > 0`）。`ceilDiv a m * m` と同じ。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#整数の除算と百分率"]
def ceilTo (a m : Nat) : Nat := (a + m - 1) / m * m

/-- `a` の `r`% を切り捨てたもの（`a ≥ 0`, `r ≥ 0`）。`floorDiv (a * r) 100` と同じ。 -/
@[spec_doc "lean/Spec/Prim/Int.lean#整数の除算と百分率"]
def pct (a r : Nat) : Nat := a * r / 100

/-! ## 性質 -/

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

/-!
## 根拠と対応

- 根拠: [ADR e41d](../../../docs/decision/e41d-exact-integer-arithmetic-in-abstract-model.md)（抽象モデルの厳密な整数）、[ADR 935b](../../../docs/decision/935b-java-primitive-semantics.md)（Java の基本演算の意味論）
-/
