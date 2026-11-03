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

set_option exponentiation.threshold 2048

namespace LangSemantics.Java
open LangSemantics.Java.Int

namespace JDouble

/-- 仮数の幅（暗黙の 1 を含む）。 -/
def precision : Nat := 53
/-- 最小の指数（非正規化数の指数）。 -/
def minExp : Int := -1074
/-- 正規化数の最大の指数。 -/
def maxExp : Int := 971

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

/-- `pow2 z = (2^z⁺, 2^z⁻)`（符号によらない形）。 -/
theorem pow2_eq (z : Int) : pow2 z = (2 ^ z.toNat, 2 ^ (-z).toNat) := by
  unfold pow2
  split
  · rename_i h; simp only [Prod.mk.injEq, true_and]; rw [show (-z).toNat = 0 by omega]
  · rename_i h; simp only [Prod.mk.injEq, and_true]; rw [show z.toNat = 0 by omega]

theorem pow2_fst_pos (z : Int) : 0 < (pow2 z).1 := by rw [pow2_eq]; exact Nat.two_pow_pos _

theorem pow2_snd_pos (z : Int) : 0 < (pow2 z).2 := by rw [pow2_eq]; exact Nat.two_pow_pos _

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

theorem scale_lt {N D x y c : Nat} : N * 2 ^ x < D * 2 ^ y ↔ N * 2 ^ (x + c) < D * 2 ^ (y + c) := by
  rw [Nat.pow_add, Nat.pow_add, ← Nat.mul_assoc, ← Nat.mul_assoc]
  exact (Nat.mul_lt_mul_right (Nat.two_pow_pos c)).symm

theorem scale_le {N D x y c : Nat} : N * 2 ^ x ≤ D * 2 ^ y ↔ N * 2 ^ (x + c) ≤ D * 2 ^ (y + c) := by
  rw [Nat.pow_add, Nat.pow_add, ← Nat.mul_assoc, ← Nat.mul_assoc]
  exact (Nat.mul_le_mul_right_iff (Nat.two_pow_pos c)).symm

/-- `N/D < 2^k` の、`k` の増加についての単調性。 -/
theorem ltPow_mono {N D : Nat} {k k' : Int} (h : N * 2 ^ (-k).toNat < D * 2 ^ k.toNat) (hk : k ≤ k') :
    N * 2 ^ (-k').toNat < D * 2 ^ k'.toNat := by
  have h1 : N * 2 ^ ((-k').toNat + ((-k).toNat - (-k').toNat)) < D * 2 ^ (k.toNat + ((-k).toNat - (-k').toNat)) := by
    rw [show (-k').toNat + ((-k).toNat - (-k').toNat) = (-k).toNat by omega]
    exact Nat.lt_of_lt_of_le h (Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by omega)))
  have h2 : D * 2 ^ (k.toNat + ((-k).toNat - (-k').toNat)) ≤ D * 2 ^ (k'.toNat + ((-k).toNat - (-k').toNat)) :=
    Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by decide) (by omega))
  exact scale_lt.mpr (Nat.lt_of_lt_of_le h1 h2)

/-- `N/D < 2^(e+j)` は、`n = N·2^e⁻`・`d = D·2^e⁺` で `n < 2^j·d`。 -/
theorem ltPow_shift {N D : Nat} (e : Int) (j : Nat) :
    N * 2 ^ (-(e + j)).toNat < D * 2 ^ (e + j).toNat ↔
      N * 2 ^ (-e).toNat < 2 ^ j * (D * 2 ^ e.toNat) := by
  rw [show 2 ^ j * (D * 2 ^ e.toNat) = D * 2 ^ (e.toNat + j) by rw [Nat.pow_add]; ac_rfl]
  have := @scale_lt N D (-(e + j)).toNat (e + j).toNat ((-e).toNat - (-(e + j)).toNat)
  rw [this, show (-(e + j)).toNat + ((-e).toNat - (-(e + j)).toNat) = (-e).toNat by omega,
    show (e + j).toNat + ((-e).toNat - (-(e + j)).toNat) = e.toNat + j by omega]

/-- `2^(e+j) ≤ N/D` は、`2^j·d ≤ n`。 -/
theorem lePow_shift {N D : Nat} (e : Int) (j : Nat) :
    D * 2 ^ (e + j).toNat ≤ N * 2 ^ (-(e + j)).toNat ↔
      2 ^ j * (D * 2 ^ e.toNat) ≤ N * 2 ^ (-e).toNat := by
  rw [show 2 ^ j * (D * 2 ^ e.toNat) = D * 2 ^ (e.toNat + j) by rw [Nat.pow_add]; ac_rfl]
  have := @scale_le D N (e + j).toNat (-(e + j)).toNat ((-e).toNat - (-(e + j)).toNat)
  rw [this, show (-(e + j)).toNat + ((-e).toNat - (-(e + j)).toNat) = (-e).toNat by omega,
    show (e + j).toNat + ((-e).toNat - (-(e + j)).toNat) = e.toNat + j by omega]

/-- 丸めの結果の範囲: 指数 `e` が `⌊log2⌋ − 52` 以上なら仮数は `2^53` 以下。`e` が `⌊log2⌋ − 52` ならちょうど 53 ビット
（`2^52` 以上）、それより大きければ `2^52` 以下。 -/
theorem roundAtExp_bounds {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) {e : Int} (he : floorLog2 N D - 52 ≤ e) :
    roundAtExp N D e ≤ 2 ^ 53 ∧ (e = floorLog2 N D - 52 → 2 ^ 52 ≤ roundAtExp N D e) ∧
      (floorLog2 N D - 52 < e → roundAtExp N D e ≤ 2 ^ 52) := by
  obtain ⟨f1, f2⟩ := floorLog2_spec hN hD
  obtain ⟨r1, r2⟩ := roundAtExp_spec N D e hD
  generalize hL : floorLog2 N D = L at *
  generalize hm : roundAtExp N D e = m at *
  have hd0 : 0 < D * 2 ^ e.toNat := Nat.mul_pos (Nat.pos_of_ne_zero hD) (Nat.two_pow_pos _)
  have up (j : Nat) (hj : L + 1 ≤ e + j) : N * 2 ^ (-e).toNat < 2 ^ j * (D * 2 ^ e.toNat) :=
    (ltPow_shift e j).mp (ltPow_mono f2 hj)
  generalize hn : N * 2 ^ (-e).toNat = n at *
  generalize hd : D * 2 ^ e.toNat = d at *
  -- `n < 2^j·d` なら `m ≤ 2^j`（`2·m·d ≤ 2n + d`）
  have mle (j : Nat) (h : n < 2 ^ j * d) : m ≤ 2 ^ j := by
    have h2 : (2 * m) * d < (2 * 2 ^ j + 1) * d := by
      rw [Nat.mul_assoc, Nat.add_mul, Nat.one_mul, Nat.mul_assoc]
      generalize m * d = A at *
      generalize 2 ^ j * d = B at *
      omega
    have := Nat.lt_of_mul_lt_mul_right h2
    generalize 2 ^ j = P at *
    omega
  have hup : n < 2 ^ 53 * d := up 53 (by omega)
  refine ⟨mle 53 hup, ?_, ?_⟩
  · intro hE
    have h1 : 2 ^ 52 * d ≤ n := by
      have := (lePow_shift (N := N) (D := D) e 52).mp (by rw [show e + ((52 : Nat) : Int) = L by omega]; exact f1)
      rw [hn, hd] at this; exact this
    clear f1 f2 up mle hup
    have h2 : (2 * 2 ^ 52) * d ≤ (2 * m + 1) * d := by
      rw [Nat.add_mul, Nat.one_mul, Nat.mul_assoc, Nat.mul_assoc]
      generalize m * d = A at *
      generalize 2 ^ 52 * d = B at *
      omega
    have := Nat.le_of_mul_le_mul_right h2 hd0
    generalize hP : 2 ^ 52 = P at *
    omega
  · intro hE
    exact mle 52 (up 52 (by omega))

/-- 有限値の正規形: ゼロ（`mant = 0`・`exp = 0`）、非正規化数（`0 < mant < 2^52`・`exp = -1074`）、
正規化数（`2^52 ≤ mant < 2^53`・`-1074 ≤ exp ≤ 971`）。binary64 の有限値は、符号とこのどれかで一意に表される。 -/
def Canonical (mant : Nat) (exp : Int) : Prop :=
  (mant = 0 ∧ exp = 0) ∨ (0 < mant ∧ mant < 2 ^ 52 ∧ exp = -1074) ∨
    (2 ^ 52 ≤ mant ∧ mant < 2 ^ 53 ∧ -1074 ≤ exp ∧ exp ≤ 971)

instance (mant : Nat) (exp : Int) : Decidable (Canonical mant exp) := by unfold Canonical; infer_instance

theorem canon_zero : Canonical 0 0 := Or.inl ⟨rfl, rfl⟩

/-- 正の有理数 `N/D` を丸めた正規形の仮数と指数（round-to-nearest-even。仮数が `2^53` に繰り上がれば `2^52` と指数 + 1）。
指数が範囲を超えれば無し（∞）。 -/
def roundParts (N D : Nat) : Option (Nat × Int) :=
  let e := max (floorLog2 N D - 52) minExp
  let m := roundAtExp N D e
  let me : Nat × Int := if m = 2 ^ precision then (2 ^ (precision - 1), e + 1) else (m, e)
  if me.2 > maxExp then none else if me.1 = 0 then some (0, 0) else some me

/-- 丸めた仮数と指数は正規形である。 -/
theorem roundParts_canon {N D : Nat} (hN : N ≠ 0) (hD : D ≠ 0) {m : Nat} {e : Int}
    (h : roundParts N D = some (m, e)) : Canonical m e := by
  obtain ⟨b1, b2, b3⟩ := roundAtExp_bounds hN hD (e := max (floorLog2 N D - 52) minExp) (by omega)
  unfold roundParts at h
  simp only [precision, minExp, maxExp] at *
  by_cases hc : roundAtExp N D (max (floorLog2 N D - 52) (-1074)) = 2 ^ 53
  · simp only [hc, ite_true] at h
    by_cases hg : max (floorLog2 N D - 52) (-1074) + 1 > 971
    · simp [hg] at h
    · simp only [hg, ite_false, show (2 : Nat) ^ (53 - 1) ≠ 0 by decide, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact Or.inr (Or.inr ⟨by decide, by decide, by omega, by omega⟩)
  · simp only [hc, ite_false] at h
    by_cases hg : max (floorLog2 N D - 52) (-1074) > 971
    · simp [hg] at h
    · by_cases hz : roundAtExp N D (max (floorLog2 N D - 52) (-1074)) = 0
      · simp only [hg, hz, ite_false, ite_true, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h; exact canon_zero
      · simp only [hg, hz, ite_false, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        by_cases he : floorLog2 N D - 52 ≥ -1074
        · exact Or.inr (Or.inr ⟨b2 (by omega), by omega, by omega, by omega⟩)
        · have := b3 (by omega)
          by_cases h52 : roundAtExp N D (max (floorLog2 N D - 52) (-1074)) = 2 ^ 52
          · exact Or.inr (Or.inr ⟨by omega, by omega, by omega, by omega⟩)
          · exact Or.inr (Or.inl ⟨by omega, by omega, by omega⟩)

end JDouble

open JDouble in
/-- binary64 の値。有限値は `(-1)^sign * mant * 2^exp` で、`(mant, exp)` は正規形（`Canonical`。正規化数・非正規化数・
ゼロ）である。正規形でない組（正規化されていない仮数、ゼロの多重表現）は表せない。 -/
inductive JDouble where
  | finite (sign : Bool) (mant : Nat) (exp : Int) (canon : Canonical mant exp)
  | inf (sign : Bool)
  | nan
  deriving Repr, DecidableEq

instance : BEq JDouble := ⟨fun a b => decide (a = b)⟩

namespace JDouble

def posZero : JDouble := .finite false 0 0 canon_zero
def negZero : JDouble := .finite true 0 0 canon_zero

/-- 符号付きの有理数 `(-1)^sign * num / den`（`den > 0`）。 -/
structure Rat' where
  sign : Bool
  num : Nat
  den : Nat
  den_pos : 0 < den
  deriving Repr

/-- 正確な有理数を binary64 に丸める（round-to-nearest-even）。 -/
def ofRat (x : Rat') : JDouble :=
  if hn : x.num = 0 then .finite x.sign 0 0 canon_zero
  else
    match h : roundParts x.num x.den with
    | some (m, e) => .finite x.sign m e (roundParts_canon hn (Nat.pos_iff_ne_zero.mp x.den_pos) h)
    | none => .inf x.sign

/-- 丸めが有限値なら、`ofRat` はその正規形の有限値。 -/
theorem ofRat_some {s : Bool} {N D : Nat} {hD : 0 < D} (hN : N ≠ 0) {m : Nat} {e : Int}
    (h : roundParts N D = some (m, e)) : ∃ hc, ofRat ⟨s, N, D, hD⟩ = .finite s m e hc := by
  refine ⟨roundParts_canon hN (Nat.pos_iff_ne_zero.mp hD) h, ?_⟩
  unfold ofRat
  simp only [hN, ↓reduceDIte]
  split
  · rename_i h'; rw [h] at h'; cases h'; rfl
  · rename_i h'; rw [h] at h'; cases h'

/-- 丸めが範囲を超えれば、`ofRat` は ∞。 -/
theorem ofRat_none {s : Bool} {N D : Nat} {hD : 0 < D} (hN : N ≠ 0) (h : roundParts N D = none) :
    ofRat ⟨s, N, D, hD⟩ = .inf s := by
  unfold ofRat
  simp only [hN, ↓reduceDIte]
  split
  · rename_i h'; rw [h] at h'; cases h'
  · rfl

/-- 有限値の正確な値。 -/
def toRat? : JDouble → Option Rat'
  | .finite s m e _ => some ⟨s, m * (pow2 e).1, (pow2 e).2, pow2_snd_pos e⟩
  | _ => none

/-- `(double) n`（`int`・`long` からの拡大変換。大きな値は丸められる）。 -/
def ofInt (n : Int) : JDouble := ofRat ⟨n < 0, n.natAbs, 1, by decide⟩

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
    some (ofRat ⟨neg, n, 10 ^ fracPart.length, Nat.pow_pos (by decide)⟩)

private def isZero : JDouble → Bool
  | .finite _ 0 _ _ => true
  | _ => false

private def negSign : JDouble → JDouble
  | .finite s m e h => .finite (!s) m e h
  | .inf s => .inf (!s)
  | .nan => .nan

/-- `-a`（double）。符号だけを反転する（`-0.0`・`-∞` を作る。NaN は NaN）。 -/
def neg (a : JDouble) : JDouble := negSign a

/-- 有理数の加算（同符号・異符号を扱う）。結果がちょうど 0 になる場合は `none`。 -/
private def addRat (a b : Rat') : Option Rat' :=
  let an := a.num * b.den
  let bn := b.num * a.den
  let d := a.den * b.den
  have hd : 0 < d := Nat.mul_pos a.den_pos b.den_pos
  if a.sign == b.sign then some ⟨a.sign, an + bn, d, hd⟩
  else if an > bn then some ⟨a.sign, an - bn, d, hd⟩
  else if bn > an then some ⟨b.sign, bn - an, d, hd⟩
  else none

/-- `a + b`（double）。 -/
def add (a b : JDouble) : JDouble :=
  match a, b with
  | .nan, _ | _, .nan => .nan
  | .inf s, .inf t => if s == t then .inf s else .nan
  | .inf s, _ | _, .inf s => .inf s
  | .finite s _ _ _, .finite t _ _ _ =>
    if isZero a && isZero b then .finite (s && t) 0 0 canon_zero
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
  | .inf s, .finite t m _ _ | .finite t m _ _, .inf s => if m = 0 then .nan else .inf (s != t)
  | .finite s _ _ _, .finite t _ _ _ =>
    match a.toRat?, b.toRat? with
    | some x, some y => ofRat ⟨s != t, x.num * y.num, x.den * y.den, Nat.mul_pos x.den_pos y.den_pos⟩
    | _, _ => .nan

/-- `a / b`（double）。 -/
def div (a b : JDouble) : JDouble :=
  match a, b with
  | .nan, _ | _, .nan => .nan
  | .inf _, .inf _ => .nan
  | .inf s, .finite t _ _ _ => .inf (s != t)
  | .finite s _ _ _, .inf t => .finite (s != t) 0 0 canon_zero
  | .finite s m e _, .finite t n f _ =>
    if hn : n = 0 then (if m = 0 then .nan else .inf (s != t))
    else ofRat ⟨s != t, m * (pow2 e).1 * (pow2 f).2, (pow2 e).2 * (n * (pow2 f).1),
      Nat.mul_pos (pow2_snd_pos e) (Nat.mul_pos (Nat.pos_of_ne_zero hn) (pow2_fst_pos f))⟩

/-- 0 方向切捨ての整数値（有限値のみ）。 -/
def truncInt : JDouble → Option Int
  | .finite s m e _ =>
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
  | .finite s m e _ =>
    let signBit := if s then 2 ^ 63 else 0
    if m = 0 then BitVec.ofNat 64 signBit
    else if m < 2 ^ 52 then BitVec.ofNat 64 (signBit + m)  -- 非正規化数（e = -1074）
    else
      let biased := (e + 1075).toNat
      BitVec.ofNat 64 (signBit + biased * 2 ^ 52 + (m - 2 ^ 52))


end JDouble

end LangSemantics.Java
