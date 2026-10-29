import LangSemantics.Java

/-!
# Tests.JavaDouble

運賃計算の [Source] の double 式（`docs/spec/fare-calculation.md`）を、`LangSemantics.Java` のソフトモデルと
ネイティブ `Float`（ホストの IEEE 754 binary64）とでビット単位に突き合わせる（backlog 0002）。
値域は `docs/spec/domain-model.md#値域` による。

- 基本運賃: `jd2i(jdmul(jd b, jdmul(jd q, 0.01)))`。`b ≤ 10,000,000`、積算比率 `q ≤ 1,000`
- 運賃: `jd2i(jdmul(jd f, jdsub(jd 1, jdmul(jd r, 0.01))))`。`f ≤ 100,000,000`、割引率 `r ≤ 100`

突き合わせる入力（件数は実行時に表示する）:

1. 因子 `jdmul(jd q, 0.01)`（q = 0..1000）と `jdsub(jd 1, jdmul(jd r, 0.01))`（r = 0..100）を全件
2. 全因子 × `b` = 0..2,000 を全件
3. シードの積算比率（100・125・140）と代表的な割引率（0・5・10・20・30）の因子 × `b` = 0..100,000 を全件
4. 全因子 × `b` を値域の上限まで、決定的な疑似乱数（LCG）で 1,000,000 件
-/

open LangSemantics.Java

namespace Tests.JavaDouble

/-- 0.01 に最も近い binary64。 -/
def nat001 : Float := Float.ofBits 0x3F847AE147AE147B

/-- 因子の組: (ソフトモデル, ネイティブ, 上限の `b`) -/
structure Factor where
  soft : JDouble
  native : Float
  maxB : Nat
  label : String

def ratioFactor (q : Nat) : Factor :=
  ⟨jdmul (jd q) (jdLit "0.01"), q.toFloat * nat001, 10000000, s!"ratio {q}"⟩

def discountFactor (r : Nat) : Factor :=
  ⟨jdsub (jd 1) (jdmul (jd r) (jdLit "0.01")), 1.0 - r.toFloat * nat001, 100000000, s!"discount {r}"⟩

def allFactors : Array Factor :=
  ((List.range 1001).map ratioFactor ++ (List.range 101).map discountFactor).toArray

/-- `(int) x`（x は非負で、int の範囲を超えうる）。 -/
def nativeToInt (x : Float) : Int :=
  if x ≥ 2147483647.0 then 2147483647 else (x.floor.toUInt64.toNat : Int)

/-- 1 件の突き合わせ: 積のビット表現と `(int)` の値。 -/
def agree (f : Factor) (b : Nat) : Bool :=
  let soft := jdmul (jd b) f.soft
  let native := b.toFloat * f.native
  soft.toBits.toNat == native.toBits.toNat && (jd2i soft).val == nativeToInt native

/-- 結果: (件数, 不一致の例) -/
structure Result where
  count : Nat := 0
  bad : Array String := #[]

def Result.check (r : Result) (f : Factor) (b : Nat) : Result :=
  if agree f b then { r with count := r.count + 1 }
  else { count := r.count + 1, bad := if r.bad.size < 10 then r.bad.push s!"{f.label}, b = {b}" else r.bad }

/-- 突き合わせを実行する。 -/
def run : Result := Id.run do
  let mut r : Result := {}
  -- 1. 因子
  for f in allFactors do
    r := { r with count := r.count + 1 }
    if f.soft.toBits.toNat != f.native.toBits.toNat then r := { r with bad := r.bad.push s!"factor {f.label}" }
  -- 2. 全因子 × 小さな b
  for f in allFactors do
    for b in [0:2001] do r := r.check f b
  -- 3. シードの比率・代表的な割引率 × b = 0..100,000
  for f in [ratioFactor 100, ratioFactor 125, ratioFactor 140, discountFactor 0, discountFactor 5,
      discountFactor 10, discountFactor 20, discountFactor 30] do
    for b in [0:100001] do r := r.check f b
  -- 4. LCG による標本（値域の上限まで）
  let mut s : UInt64 := 0x2545F4914F6CDD1D
  for _ in [0:1000000] do
    s := s * 6364136223846793005 + 1442695040888963407
    let f := allFactors[((s >>> 33).toNat % allFactors.size)]?.getD (ratioFactor 100)
    s := s * 6364136223846793005 + 1442695040888963407
    let b := (s >>> 20).toNat % (f.maxB + 1)
    r := r.check f b
  return r

end Tests.JavaDouble
