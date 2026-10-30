import LangSemantics.Java.Exception

/-!
# LangSemantics.Java.Int

Java の `int`（32 ビット）と `long`（64 ビット）。2 の補数で、加減乗算は 2^n を法として折り返す。
除算・剰余は 0 方向切捨てで、0 除算は `ArithmeticException`。

lang: `lang:java#JLS-4.2.2`, `lang:java#JLS-15.17`, `lang:java#JLS-15.18`
-/

namespace LangSemantics.Java

/-- Java の `int`。 -/
abbrev J32 := BitVec 32
/-- Java の `long`。 -/
abbrev J64 := BitVec 64

/-- 数学的整数から `int` へ（下位 32 ビット。Java の `(int)` 縮小変換と同じ）。 -/
def J32.ofInt (i : Int) : J32 := BitVec.ofInt 32 i
/-- `int` の値（符号付き）。 -/
def J32.val (x : J32) : Int := x.toInt

def J64.ofInt (i : Int) : J64 := BitVec.ofInt 64 i
def J64.val (x : J64) : Int := x.toInt

def J32.minValue : Int := -2147483648
def J32.maxValue : Int := 2147483647

/-- `a + b`（int）。 -/
def j32add (a b : J32) : J32 := a + b
/-- `a - b`（int）。 -/
def j32sub (a b : J32) : J32 := a - b
/-- `a * b`（int）。 -/
def j32mul (a b : J32) : J32 := a * b

/-- `a / b`（int）。0 方向切捨て。`MIN_VALUE / -1 = MIN_VALUE`。 -/
def jdiv32 (a b : J32) : JResult J32 :=
  if b = 0 then .error (.arithmetic "/ by zero") else .ok (BitVec.sdiv a b)

/-- `a % b`（int）。符号は被除数に従う。 -/
def jrem32 (a b : J32) : JResult J32 :=
  if b = 0 then .error (.arithmetic "/ by zero") else .ok (BitVec.srem a b)

def j64add (a b : J64) : J64 := a + b
def j64sub (a b : J64) : J64 := a - b
def j64mul (a b : J64) : J64 := a * b
def jdiv64 (a b : J64) : JResult J64 :=
  if b = 0 then .error (.arithmetic "/ by zero") else .ok (BitVec.sdiv a b)

/-- `int` の範囲に入る数学的整数か。 -/
def J32.inRange (i : Int) : Bool := J32.minValue ≤ i && i ≤ J32.maxValue

/-- 値域内では `int` の加算は数学的整数の加算と一致する。 -/
theorem j32add_val_of_inRange (a b : J32)
    (h : J32.minValue ≤ a.val + b.val ∧ a.val + b.val ≤ J32.maxValue) :
    (j32add a b).val = a.val + b.val := by
  simp only [j32add, J32.val, J32.minValue, J32.maxValue] at *
  rw [BitVec.toInt_add]
  unfold Int.bmod
  simp only [Nat.reducePow]
  split <;> omega

end LangSemantics.Java
