import Machine

/-!
# Test.Machine.Nondet

状態を持たない機械で、非決定性の向きを確かめる。

- 非決定的な抽象機械を、決定的な具体機械がリファインする（抽象側の非決定性は減らしてよい）。
- 具体側の非決定性のすべての分岐を、抽象側が模倣する。
- 具体側が抽象側より大きな非決定性を持つと、`Refines` は成り立たない（反例）。出力の対応に名前付きの
  成分（観測型の差異の模擬）を加えると成り立つ。
- 具体側だけにある入力（要求ヘッダの模擬）で具体側が誤る場合、制限しなければ成り立たず、
  `Concrete.restrict`（前提型の差異の模擬）で成り立つ。
-/

open Machine.Adequacy
open _root_.Machine _root_.Machine.Adequacy

namespace Test.Machine.Nondet

/-- 恒等の入出力の対応。 -/
def eqGlue (ι ο : Type) : Glue Unit Unit ι ι ο ο := Glue.pure (· = ·) (· = ·)

/-! ## 抽象側の非決定性を具体側で減らす -/

/-- `n` 以下の任意の値を返してよい。標準の選択は `n`。 -/
def chooseLe : Machine Unit Nat Nat where
  Inv _ := True
  Init _ := True
  Pre _ _ := True
  step _ n _ o := o ≤ n
  run _ n := ((), n)
  run_step _ n _ := Nat.le_refl n

/-- 常に `n / 2` を返す。 -/
def halve : Concrete Unit Nat Nat String := Concrete.pure fun n => .ok (n / 2)

theorem halve_refines_chooseLe : Refines chooseLe halve (eqGlue Nat Nat) where
  init _ _ := ⟨(), trivial, trivial⟩
  input_total ic _ := ⟨ic, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ ic ia _ _ _ _ ha _ _ hs := by
    cases ha; cases hs
    exact ⟨(), ic / 2, Nat.div_le_self ic 2, trivial, rfl⟩

#guard (chooseLe.run () 7).2 == 7

/-! ## 具体側の非決定性のすべての分岐を模倣する -/

/-- 2 つの値を、どちらの順で返してもよい（SQL の未規定の並び順の模擬）。 -/
def anyOrder : Machine Unit (Nat × Nat) (List Nat) where
  Inv _ := True
  Init _ := True
  Pre _ _ := True
  step _ p _ o := o = [p.1, p.2] ∨ o = [p.2, p.1]
  run _ p := ((), [p.1, p.2])
  run_step _ _ _ := Or.inl rfl

/-- どちらの順でも返しうる具体機械。 -/
def bagQuery : Concrete Unit (Nat × Nat) (List Nat) String where
  Init _ := True
  step _ p r := r = .ok ((), [p.1, p.2]) ∨ r = .ok ((), [p.2, p.1])

theorem bagQuery_refines_anyOrder : Refines anyOrder bagQuery (eqGlue _ _) where
  init _ _ := ⟨(), trivial, trivial⟩
  input_total ic _ := ⟨ic, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, Or.inl rfl⟩, fun _ h => by rcases h with h | h <;> cases h⟩
  correct _ _ ic ia _ _ _ _ ha _ _ hs := by
    cases ha
    rcases hs with h | h <;> cases h
    · exact ⟨(), _, Or.inl rfl, trivial, rfl⟩
    · exact ⟨(), _, Or.inr rfl, trivial, rfl⟩

/-! ## 反例: 具体側の非決定性が抽象側より大きい -/

/-- 常に入力の順で返す（定順の `Spec` の模擬）。 -/
def fixedOrder : Machine Unit (Nat × Nat) (List Nat) :=
  Machine.pure (fun _ => True) fun p => [p.1, p.2]

/-- 定順の抽象機械を、順序不定の具体機械はリファインしない。 -/
theorem bagQuery_not_refines_fixedOrder : ¬ Refines fixedOrder bagQuery (eqGlue _ _) := by
  intro h
  obtain ⟨_, oa, hst, _, ho⟩ :=
    h.correct () () (1, 2) (1, 2) () [2, 1] trivial trivial rfl trivial trivial (Or.inr rfl)
  have : [2, 1] = [1, 2] := ho.trans hst
  simp at this

/-- 出力の対応の名前付きの成分（観測型の差異の模擬）: 逆順も同じ出力とみなす。 -/
def devOrderUnspecified (oc oa : List Nat) : Prop := oc = oa ∨ oc = oa.reverse

theorem bagQuery_refines_fixedOrder_mod_order :
    Refines fixedOrder bagQuery (Glue.pure (· = ·) devOrderUnspecified) where
  init _ _ := ⟨(), trivial, trivial⟩
  input_total ic _ := ⟨ic, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, Or.inl rfl⟩, fun _ h => by rcases h with h | h <;> cases h⟩
  correct _ _ ic ia _ _ _ _ ha _ _ hs := by
    cases ha
    rcases hs with h | h <;> cases h
    · exact ⟨(), _, rfl, trivial, Or.inl rfl⟩
    · exact ⟨(), _, rfl, trivial, Or.inr rfl⟩

/-! ## 具体側だけにある入力で具体機械を制限する -/

/-- 後者関数。 -/
def succSpec : Machine Unit Nat Nat := Machine.pure (fun _ => True) (· + 1)

/-- 2 つ目の成分（要求ヘッダの模擬）が `false` だと誤る。 -/
def succWithHeader : Concrete Unit (Nat × Bool) Nat String :=
  Concrete.pure fun c => if c.2 then .ok (c.1 + 1) else .error "header"

/-- ヘッダは抽象側に写らない。 -/
def headerGlue : Glue Unit Unit Nat (Nat × Bool) Nat Nat := Glue.pure (fun c a => c.1 = a) (· = ·)

/-- 前提型の差異の述語の模擬（具体側だけにある入力の述語）。 -/
def devHeaderPresent (c : Nat × Bool) : Prop := c.2 = true

/-- 差異の証拠の模擬: ヘッダが無いと、適用可能性が破れる。 -/
theorem succWithHeader_not_refines : ¬ Refines succSpec succWithHeader headerGlue := fun h =>
  (h.applicable () () (0, false) 0 trivial trivial rfl trivial trivial).2 "header" rfl

theorem succWithHeader_refines :
    Refines succSpec (succWithHeader.restrict devHeaderPresent) headerGlue where
  init _ _ := ⟨(), trivial, trivial⟩
  input_total ic _ := ⟨ic.1, rfl⟩
  applicable _ _ ic _ _ _ _ _ hd := by
    obtain ⟨n, b⟩ := ic
    cases hd.2
    exact ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ ic ia _ _ _ _ ha _ hd hs := by
    obtain ⟨n, b⟩ := ic
    cases hd.2; cases ha; cases hs
    exact ⟨(), _, rfl, trivial, rfl⟩

/-! ## `Refines.of_pure` -/

/-- `Except` を返す後者関数（溢れの無い場合）。 -/
def succConcrete : Concrete Unit Nat Nat String := Concrete.pure fun n => .ok (n + 1)

theorem succConcrete_refines : Refines succSpec succConcrete (eqGlue _ _) :=
  Refines.of_pure (fun ic => ⟨ic, rfl⟩) fun ic _ ha _ => ⟨ic + 1, rfl, by cases ha; rfl⟩

end Test.Machine.Nondet
