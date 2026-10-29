import LangSemantics.Java.Int

/-!
# LangSemantics.Java.BigDecimal

`java.math.BigDecimal` のうち、整数値の丸め（`setScale`）と `intValue()` を定義する。
値は「整数 `unscaled` × 10^(-scale)」で表す。

lang: `dep:java.base#java.math.BigDecimal.setScale`, `dep:java.base#java.math.RoundingMode`
-/

namespace LangSemantics.Java

/-- `java.math.RoundingMode`。 -/
inductive RoundingMode where
  /-- 0 から遠ざかる方向。 -/
  | up
  /-- 0 に近づく方向（切捨て）。 -/
  | down
  /-- +∞ 方向。 -/
  | ceiling
  /-- -∞ 方向。 -/
  | floor
  /-- 四捨五入（0.5 は 0 から遠ざかる）。 -/
  | halfUp
  /-- 0.5 は 0 に近づく。 -/
  | halfDown
  /-- 0.5 は偶数へ。 -/
  | halfEven
  deriving Repr, BEq, DecidableEq

/-- `BigDecimal`（`unscaled × 10^(-scale)`）。 -/
structure JBigDecimal where
  unscaled : Int
  scale : Int
  deriving Repr, BEq, DecidableEq

namespace JBigDecimal

/-- `new BigDecimal(int)` / `BigDecimal.valueOf(long)`。 -/
def ofInt (n : Int) : JBigDecimal := ⟨n, 0⟩

/-- 正の整数 `n` を正の整数 `d` で割り、モードに従って丸めた商（符号 `neg` を考慮）。 -/
private def roundDiv (neg : Bool) (n d : Nat) (mode : RoundingMode) : Nat :=
  let q := n / d
  let r := n % d
  if r = 0 then q
  else
    let twice := 2 * r
    match mode with
    | .up => q + 1
    | .down => q
    | .ceiling => if neg then q else q + 1
    | .floor => if neg then q + 1 else q
    | .halfUp => if twice ≥ d then q + 1 else q
    | .halfDown => if twice > d then q + 1 else q
    | .halfEven => if twice > d then q + 1 else if twice < d then q else if q % 2 = 1 then q + 1 else q

/-- `setScale(newScale, mode)`。`newScale` が負なら 10^(-newScale) の倍数に丸める（例: `-2` は 100 単位）。
`UNNECESSARY` は扱わない。 -/
def setScale (x : JBigDecimal) (newScale : Int) (mode : RoundingMode) : JBigDecimal :=
  if newScale ≥ x.scale then
    ⟨x.unscaled * 10 ^ (newScale - x.scale).toNat, newScale⟩
  else
    let d := 10 ^ (x.scale - newScale).toNat
    let neg := x.unscaled < 0
    let q := roundDiv neg x.unscaled.natAbs d mode
    ⟨if neg then -(q : Int) else q, newScale⟩

/-- 整数部（0 方向切捨て）。 -/
def toIntegerPart (x : JBigDecimal) : Int :=
  if x.scale ≤ 0 then x.unscaled * 10 ^ (-x.scale).toNat
  else x.unscaled.tdiv (10 ^ x.scale.toNat)

/-- `intValue()`: 整数部の下位 32 ビット。 -/
def intValue (x : JBigDecimal) : J32 := J32.ofInt x.toIntegerPart

end JBigDecimal

/-- `new BigDecimal(n).setScale(-2, RoundingMode.UP).intValue()`（100 単位に 0 から遠ざかる方向へ丸める）。 -/
def bdCeilHundredUp (n : J32) : J32 :=
  ((JBigDecimal.ofInt n.toInt).setScale (-2) .up).intValue

end LangSemantics.Java
