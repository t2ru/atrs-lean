import LangSemantics.Rust.Panic

/-!
# LangSemantics.Rust.Int

Rust の固定長整数（`u8`〜`u64`, `i8`〜`i64`）。値は `BitVec n`、符号の有無は演算で区別する。
既定の演算（`+ - *`）の溢れはプロファイルに従い、`checked_*`・`wrapping_*`・`saturating_*` を明示的に持つ。
除算・剰余は 0 方向切捨てで、0 除算と符号付きの `MIN / -1` はパニック。

lang: `lang:rust#integer-overflow`, `lang:rust#arithmetic-and-logical-binary-operators`
-/

namespace LangSemantics.Rust

abbrev U8 := BitVec 8
abbrev U16 := BitVec 16
abbrev U32 := BitVec 32
abbrev U64 := BitVec 64
abbrev I8 := BitVec 8
abbrev I16 := BitVec 16
abbrev I32 := BitVec 32
abbrev I64 := BitVec 64

/-- 符号の有無。 -/
inductive Signedness where
  | unsigned
  | signed
  deriving Repr, BEq, DecidableEq

/-- 型の値域。 -/
def minVal (sg : Signedness) (n : Nat) : Int :=
  match sg with
  | .unsigned => 0
  | .signed => -(2 ^ (n - 1) : Nat)

def maxVal (sg : Signedness) (n : Nat) : Int :=
  match sg with
  | .unsigned => (2 ^ n - 1 : Nat)
  | .signed => (2 ^ (n - 1) - 1 : Nat)

/-- ビット列の値（符号の有無に応じて解釈）。 -/
def val {n : Nat} (sg : Signedness) (x : BitVec n) : Int :=
  match sg with
  | .unsigned => x.toNat
  | .signed => x.toInt

def inRange (sg : Signedness) (n : Nat) (v : Int) : Bool := minVal sg n ≤ v && v ≤ maxVal sg n

/-- 数学的な結果 `exact` が値域に入れば `some`。 -/
private def checkedOf {n : Nat} (sg : Signedness) (exact : Int) : Option (BitVec n) :=
  if inRange sg n exact then some (BitVec.ofInt n exact) else none

def checkedAdd {n : Nat} (sg : Signedness) (a b : BitVec n) : Option (BitVec n) :=
  checkedOf sg (val sg a + val sg b)
def checkedSub {n : Nat} (sg : Signedness) (a b : BitVec n) : Option (BitVec n) :=
  checkedOf sg (val sg a - val sg b)
def checkedMul {n : Nat} (sg : Signedness) (a b : BitVec n) : Option (BitVec n) :=
  checkedOf sg (val sg a * val sg b)

def wrappingAdd {n : Nat} (a b : BitVec n) : BitVec n := a + b
def wrappingSub {n : Nat} (a b : BitVec n) : BitVec n := a - b
def wrappingMul {n : Nat} (a b : BitVec n) : BitVec n := a * b

private def saturateOf {n : Nat} (sg : Signedness) (exact : Int) : BitVec n :=
  BitVec.ofInt n (max (minVal sg n) (min (maxVal sg n) exact))

def saturatingAdd {n : Nat} (sg : Signedness) (a b : BitVec n) : BitVec n := saturateOf sg (val sg a + val sg b)
def saturatingSub {n : Nat} (sg : Signedness) (a b : BitVec n) : BitVec n := saturateOf sg (val sg a - val sg b)
def saturatingMul {n : Nat} (sg : Signedness) (a b : BitVec n) : BitVec n := saturateOf sg (val sg a * val sg b)

/-- 既定の演算子（`+ - *`）: プロファイルが `checked` なら溢れでパニック、`wrapping` なら折り返す。 -/
private def defaultOp {n : Nat} (p : Profile) (checked : Option (BitVec n)) (wrapped : BitVec n) (what : String) :
    RExec (BitVec n) :=
  match p with
  | .wrapping => .ok wrapped
  | .checked => match checked with
    | some r => .ok r
    | none => rpanic s!"attempt to {what} with overflow"

def add {n : Nat} (p : Profile) (sg : Signedness) (a b : BitVec n) : RExec (BitVec n) :=
  defaultOp p (checkedAdd sg a b) (wrappingAdd a b) "add"
def sub {n : Nat} (p : Profile) (sg : Signedness) (a b : BitVec n) : RExec (BitVec n) :=
  defaultOp p (checkedSub sg a b) (wrappingSub a b) "subtract"
def mul {n : Nat} (p : Profile) (sg : Signedness) (a b : BitVec n) : RExec (BitVec n) :=
  defaultOp p (checkedMul sg a b) (wrappingMul a b) "multiply"

/-- `/`。0 除算はパニック。符号付きの `MIN / -1` もパニック（プロファイルに依らない）。 -/
def div {n : Nat} (sg : Signedness) (a b : BitVec n) : RExec (BitVec n) :=
  if b = 0 then rpanic "attempt to divide by zero"
  else match sg with
    | .unsigned => .ok (BitVec.udiv a b)
    | .signed =>
      if val sg a = minVal sg n && val sg b = -1 then rpanic "attempt to divide with overflow"
      else .ok (BitVec.sdiv a b)

/-- `%`。 -/
def rem {n : Nat} (sg : Signedness) (a b : BitVec n) : RExec (BitVec n) :=
  if b = 0 then rpanic "attempt to calculate the remainder with a divisor of zero"
  else match sg with
    | .unsigned => .ok (BitVec.umod a b)
    | .signed =>
      if val sg a = minVal sg n && val sg b = -1 then rpanic "attempt to calculate the remainder with overflow"
      else .ok (BitVec.srem a b)

/-- `TryFrom` による変換（値域外は `Err`）。 -/
def tryFrom {n : Nat} (sg : Signedness) (v : Int) : Option (BitVec n) := checkedOf sg v

/-- 値域内では `u64` の加算は自然数の加算と一致する。 -/
theorem u64_add_toNat_of_lt (a b : U64) (h : a.toNat + b.toNat < 2 ^ 64) :
    (wrappingAdd a b).toNat = a.toNat + b.toNat := by
  unfold wrappingAdd
  rw [BitVec.toNat_add, Nat.mod_eq_of_lt h]

end LangSemantics.Rust
