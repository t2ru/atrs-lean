import LangSemantics.Java.Int

/-!
# LangSemantics.Java.JDouble

Java の `double`（IEEE 754 binary64）の **検証可能なソフトモデル**。
Lean 標準の `Float` は不透明で性質を証明できないため使わない。値の意味は有理数で与え、
演算は「正確な有理数の結果を round-to-nearest-even で丸める」として定義する。

範囲: 有限値（正規化数・非正規化数）、±0、±∞、NaN。演算は変換・加減乗除・縮小変換。
平方根・超越関数は含めない（必要になった時点で同じ方針で追加する）。

lang: `lang:java#JLS-4.2.3`, `lang:java#JLS-4.2.4`, `lang:java#JLS-5.1.3`, `lang:java#JLS-15.17`
-/

namespace LangSemantics.Java
open LangSemantics.Java.Exception LangSemantics.Java.Int

/-- binary64 の値。有限値は `(-1)^sign * mant * 2^exp`。
正規化数は `2^52 ≤ mant < 2^53` かつ `-1074 ≤ exp ≤ 971`、
非正規化数は `0 < mant < 2^52` かつ `exp = -1074`、ゼロは `mant = 0`。 -/
inductive JDouble where
  | finite (sign : Bool) (mant : Nat) (exp : Int)
  | inf (sign : Bool)
  | nan
  deriving Repr, BEq, DecidableEq

namespace JDouble

/-- 仮数の幅（暗黙の 1 を含む）。 -/
def precision : Nat := 53
/-- 最小の指数（非正規化数の指数）。 -/
def minExp : Int := -1074
/-- 正規化数の最大の指数。 -/
def maxExp : Int := 971

def posZero : JDouble := .finite false 0 0
def negZero : JDouble := .finite true 0 0

/-- 符号付きの有理数 `(-1)^sign * num / den`（`den > 0`）。 -/
structure Rat' where
  sign : Bool
  num : Nat
  den : Nat
  deriving Repr

/-- `2^k`（`k` は整数）を分子・分母で表す。 -/
def pow2 (k : Int) : Nat × Nat :=
  if 0 ≤ k then (2 ^ k.toNat, 1) else (1, 2 ^ (-k).toNat)

/-- `num/den ≥ 2^k` か。 -/
def geTwoPow (num den : Nat) (k : Int) : Bool :=
  let (p, q) := pow2 k
  num * q ≥ den * p

/-- `⌊log2 (num/den)⌋`（`num, den > 0`）。 -/
def floorLog2 (num den : Nat) : Int :=
  let k : Int := (Nat.log2 num : Int) - (Nat.log2 den : Int)
  if geTwoPow num den k then k else k - 1

/-- 正の有理数 `num/den` を、指数 `e` の格子で round-to-nearest-even する。結果は `mant`。 -/
def roundAtExp (num den : Nat) (e : Int) : Nat :=
  let (p, q) := pow2 e
  -- num/den / 2^e = (num * q) / (den * p)
  let n := num * q
  let d := den * p
  let m := n / d
  let r := n % d
  if 2 * r > d then m + 1
  else if 2 * r < d then m
  else if m % 2 = 1 then m + 1 else m

/-- 正確な有理数を binary64 に丸める（round-to-nearest-even）。 -/
def ofRat (x : Rat') : JDouble :=
  if x.num = 0 then .finite x.sign 0 0
  else
    let e0 := floorLog2 x.num x.den - 52
    let e := max e0 minExp
    let m := roundAtExp x.num x.den e
    let (m, e) := if m = 2 ^ precision then (2 ^ (precision - 1), e + 1) else (m, e)
    if e > maxExp then .inf x.sign
    else if m = 0 then .finite x.sign 0 0
    else .finite x.sign m e

/-- 有限値の正確な値。 -/
def toRat? : JDouble → Option Rat'
  | .finite s m e => let (p, q) := pow2 e; some ⟨s, m * p, q⟩
  | _ => none

/-- `(double) n`（`int`・`long` からの拡大変換。大きな値は丸められる）。 -/
def ofInt (n : Int) : JDouble := ofRat ⟨n < 0, n.natAbs, 1⟩

/-- 十進表記（`[-]digits[.digits]`）のリテラルを binary64 に丸める（Java のリテラルと同じ規則）。 -/
def ofDecimal? (s : String) : Option JDouble :=
  let cs := s.toList
  let (neg, cs) := match cs with
    | '-' :: rest => (true, rest)
    | _ => (false, cs)
  let intPart := cs.takeWhile (· != '.')
  let rest := cs.dropWhile (· != '.')
  let fracPart := match rest with
    | '.' :: f => f
    | _ => []
  let allDigits := (intPart ++ fracPart).all Char.isDigit
  if intPart.isEmpty && fracPart.isEmpty || !allDigits then none
  else
    let digits := intPart ++ fracPart
    let n := digits.foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
    some (ofRat ⟨neg, n, 10 ^ fracPart.length⟩)

private def isZero : JDouble → Bool
  | .finite _ 0 _ => true
  | _ => false

private def negSign : JDouble → JDouble
  | .finite s m e => .finite (!s) m e
  | .inf s => .inf (!s)
  | .nan => .nan

/-- 有理数の加算（同符号・異符号を扱う）。結果がちょうど 0 になる場合は `none`。 -/
private def addRat (a b : Rat') : Option Rat' :=
  let an := a.num * b.den
  let bn := b.num * a.den
  let d := a.den * b.den
  if a.sign == b.sign then some ⟨a.sign, an + bn, d⟩
  else if an > bn then some ⟨a.sign, an - bn, d⟩
  else if bn > an then some ⟨b.sign, bn - an, d⟩
  else none

/-- `a + b`（double）。 -/
def add (a b : JDouble) : JDouble :=
  match a, b with
  | .nan, _ | _, .nan => .nan
  | .inf s, .inf t => if s == t then .inf s else .nan
  | .inf s, _ | _, .inf s => .inf s
  | .finite s _ _, .finite t _ _ =>
    if isZero a && isZero b then .finite (s && t) 0 0
    else match a.toRat?, b.toRat? with
      | some x, some y =>
        match addRat x y with
        | some r => ofRat r
        | none => posZero  -- x + (-x) は RNE で +0
      | _, _ => .nan

/-- `a - b`（double）。 -/
def sub (a b : JDouble) : JDouble := add a (negSign b)

/-- `a * b`（double）。 -/
def mul (a b : JDouble) : JDouble :=
  match a, b with
  | .nan, _ | _, .nan => .nan
  | .inf s, .inf t => .inf (s != t)
  | .inf s, .finite t m _ | .finite t m _, .inf s => if m = 0 then .nan else .inf (s != t)
  | .finite s _ _, .finite t _ _ =>
    match a.toRat?, b.toRat? with
    | some x, some y => ofRat ⟨s != t, x.num * y.num, x.den * y.den⟩
    | _, _ => .nan

/-- `a / b`（double）。 -/
def div (a b : JDouble) : JDouble :=
  match a, b with
  | .nan, _ | _, .nan => .nan
  | .inf _, .inf _ => .nan
  | .inf s, .finite t _ _ => .inf (s != t)
  | .finite s _ _, .inf t => .finite (s != t) 0 0
  | .finite s m _, .finite t n _ =>
    if n = 0 then (if m = 0 then .nan else .inf (s != t))
    else match a.toRat?, b.toRat? with
      | some x, some y => ofRat ⟨s != t, x.num * y.den, x.den * y.num⟩
      | _, _ => .nan

/-- 0 方向切捨ての整数値（有限値のみ）。 -/
def truncInt : JDouble → Option Int
  | .finite s m e =>
    let (p, q) := pow2 e
    let t : Int := ((m * p) / q : Nat)
    some (if s then -t else t)
  | _ => none

/-- `(int) d`（JLS 5.1.3）: NaN → 0、0 方向切捨て、範囲外は飽和。 -/
def toJ32 (d : JDouble) : J32 :=
  match d with
  | .nan => J32.ofInt 0
  | .inf s => J32.ofInt (if s then J32.minValue else J32.maxValue)
  | _ =>
    let t := (truncInt d).getD 0
    J32.ofInt (max J32.minValue (min J32.maxValue t))

/-- `(long) d`。 -/
def toJ64 (d : JDouble) : J64 :=
  let lo : Int := -(2 ^ 63)
  let hi : Int := 2 ^ 63 - 1
  match d with
  | .nan => J64.ofInt 0
  | .inf s => J64.ofInt (if s then lo else hi)
  | _ => J64.ofInt (max lo (min hi ((truncInt d).getD 0)))

/-- IEEE 754 のビット表現（`Double.doubleToRawLongBits` 相当。NaN は正準 NaN）。 -/
def toBits : JDouble → BitVec 64
  | .nan => 0x7FF8000000000000#64
  | .inf s => BitVec.ofNat 64 ((if s then 2 ^ 63 else 0) + 0x7FF0000000000000)
  | .finite s m e =>
    let signBit := if s then 2 ^ 63 else 0
    if m = 0 then BitVec.ofNat 64 signBit
    else if m < 2 ^ 52 then BitVec.ofNat 64 (signBit + m)  -- 非正規化数（e = -1074）
    else
      let biased := (e + 1075).toNat
      BitVec.ofNat 64 (signBit + biased * 2 ^ 52 + (m - 2 ^ 52))


end JDouble

end LangSemantics.Java
