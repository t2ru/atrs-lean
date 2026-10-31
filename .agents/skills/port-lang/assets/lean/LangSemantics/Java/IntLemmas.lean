import LangSemantics.Java.Int
import LangSemantics.Core.List

/-!
# LangSemantics.Java.IntLemmas

値域内の `int` の演算（自然数の値）と、`int` の累積をとる `for` 文（`forIn`）の補題。

- `ofInt_nat`・`j32add_nat`・`j32sub_nat`・`j32mul_nat`・`jdiv32_nat`: 値域内なら、`int` の演算は自然数の演算に一致する。
- `forIn_sum_eq`: 各要素の本体が累積に値を足す `for` 文は、値の和を返す（溢れないとき）。
- `forIn_count_eq`: 各要素の本体が条件を満たせば累積に 1 を足す `for` 文は、条件を満たす要素の数を返す。
-/

namespace LangSemantics.Java.IntLemmas
open LangSemantics.Core.List LangSemantics.Java.Exception LangSemantics.Java.Int

open LangSemantics.Core

theorem J32.ofInt_val (x : J32) : J32.ofInt x.val = x := by
  simp only [J32.ofInt, J32.val, BitVec.ofInt_toInt]

theorem j32add_ofInt {b : J32} {s v : Nat} (hb : b.val = s) (hr : s + v ≤ 2147483647) :
    (j32add b (J32.ofInt v)).val = ((s + v : Nat) : Int) := by
  have hv : (J32.ofInt v).val = v := J32.val_ofInt_of_inRange _ ⟨by simp only [J32.minValue]; omega,
    by simp only [J32.maxValue]; omega⟩
  rw [j32add_val_of_inRange _ _ (by rw [hb, hv]; simp only [J32.minValue, J32.maxValue]; omega), hb, hv]
  push_cast; rfl

/-! ## 値域内の `int` の演算（自然数の値） -/

theorem ofInt_nat {x : Nat} (h : x ≤ 2147483647) : (J32.ofInt (x : Int)).val = (x : Int) :=
  J32.val_ofInt_of_inRange _ ⟨by simp only [J32.minValue]; omega, by simp only [J32.maxValue]; omega⟩

theorem j32add_nat {a b : J32} {x y : Nat} (ha : a.val = (x : Int)) (hb : b.val = (y : Int))
    (h : x + y ≤ 2147483647) : (j32add a b).val = ((x + y : Nat) : Int) := by
  rw [j32add_val_of_inRange _ _ (by rw [ha, hb]; simp only [J32.minValue, J32.maxValue]; omega), ha, hb]
  push_cast; rfl

theorem j32sub_nat {a b : J32} {x y : Nat} (ha : a.val = (x : Int)) (hb : b.val = (y : Int))
    (h : y ≤ x) (hx : x ≤ 2147483647) : (j32sub a b).val = ((x - y : Nat) : Int) := by
  rw [j32sub_val_of_inRange _ _ (by rw [ha, hb]; simp only [J32.minValue, J32.maxValue]; omega), ha, hb]
  omega

theorem j32mul_nat {a b : J32} {x y : Nat} (ha : a.val = (x : Int)) (hb : b.val = (y : Int))
    (h : x * y ≤ 2147483647) : (j32mul a b).val = ((x * y : Nat) : Int) := by
  have e : (x : Int) * (y : Int) = ((x * y : Nat) : Int) := (Int.natCast_mul x y).symm
  rw [j32mul_val_of_inRange _ _ (by rw [ha, hb, e]; simp only [J32.minValue, J32.maxValue]; omega), ha, hb, e]

theorem jdiv32_nat {a : J32} {x : Nat} (ha : a.val = (x : Int)) :
    ∃ c, jdiv32 a (J32.ofInt 100) = .ok c ∧ c.val = ((x / 100 : Nat) : Int) := by
  have h100 : (J32.ofInt 100).val = 100 := ofInt_nat (x := 100) (by decide)
  obtain ⟨c, hc, hcv⟩ := jdiv32_val_of_nonneg a (J32.ofInt 100) (by rw [ha]; omega) (by rw [h100]; decide)
  refine ⟨c, hc, ?_⟩
  rw [hcv, ha, h100]
  omega

/-- 和をとる `for` 文: 各要素の本体が、累積に `V k` を `int` で足す。 -/
theorem forIn_sum_eq {α κ ε : Type} {f : α → J32 → Except ε (ForInStep J32)} {V : κ → Nat} :
    ∀ (xs : List α) (ks : List κ) (init : J32) (s : Nat),
      Forall₂ (fun x k => ∀ b, f x b = .ok (.yield (j32add b (J32.ofInt (V k))))) xs ks →
      init.val = s → s + (ks.map V).sum ≤ 2147483647 →
      forIn xs init f = .ok (J32.ofInt ((s + (ks.map V).sum : Nat) : Int))
  | [], [], init, s, _, hi, _ => by
    simp only [List.forIn_nil, List.map_nil, List.sum_nil, Nat.add_zero, ← hi, J32.ofInt_val]; rfl
  | x :: xs, k :: ks, init, s, .cons hxk hr, hi, hb => by
    simp only [List.map_cons, List.sum_cons] at hb
    rw [List.forIn_cons, hxk init]
    show forIn xs (j32add init (J32.ofInt (V k))) f = _
    rw [forIn_sum_eq xs ks _ (s + V k) hr (j32add_ofInt hi (by omega)) (by omega)]
    simp only [List.map_cons, List.sum_cons, Nat.add_assoc]

/-- 数える `for` 文: 各要素の本体が、条件を満たせば累積に 1 を `int` で足す。 -/
theorem forIn_count_eq {α ε : Type} {f : α → J32 → Except ε (ForInStep J32)} {P : Nat → Bool} :
    ∀ (xs : List α) (ns : List Nat) (init : J32) (s : Nat),
      Forall₂ (fun x n => ∀ b, f x b = .ok (.yield (if P n then j32add b (J32.ofInt 1) else b))) xs ns →
      init.val = s → s + ns.length ≤ 2147483647 →
      forIn xs init f = .ok (J32.ofInt ((s + (ns.filter P).length : Nat) : Int))
  | [], [], init, s, _, hi, _ => by
    simp only [List.forIn_nil, List.filter_nil, List.length_nil, Nat.add_zero, ← hi, J32.ofInt_val]; rfl
  | x :: xs, n :: ns, init, s, .cons hxn hr, hi, hb => by
    simp only [List.length_cons] at hb
    rw [List.forIn_cons, hxn init]
    cases hP : P n
    · show forIn xs init f = _
      rw [forIn_count_eq xs ns init s hr hi (by omega)]
      simp only [List.filter_cons, hP]; rfl
    · show forIn xs (j32add init (J32.ofInt 1)) f = _
      have h1 : (j32add init (J32.ofInt 1)).val = ((s + 1 : Nat) : Int) := j32add_ofInt (v := 1) hi (by omega)
      rw [forIn_count_eq xs ns (j32add init (J32.ofInt 1)) (s + 1) hr h1 (by omega)]
      simp only [List.filter_cons, hP, ite_true, List.length_cons]
      congr 2; omega

end LangSemantics.Java.IntLemmas
