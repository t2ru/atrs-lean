import Machine

/-!
# Test.Machine.Alt

同じ状態の上の並置 `Machine.alt` の例と反例。

- 例: カウンタを増やす操作と、カウンタを読む操作を `alt` で並置すると、読む操作が増やした値を見る。抽象側（上限の無い
  カウンタ）と具体側（255 で溢れを誤りとする）の並置で、`Refines.alt` によりリファインメントが成り立つ。
- 反例: 同じ 2 つの操作を `sum` で並置すると、状態が別々の写しになり、読む操作は増やした値を見ない。
-/

open _root_.Machine

namespace Test.Machine.Alt

/-- 増やす操作（上限の無いカウンタ。出力は増やす前の値）。 -/
def incr : Machine Nat Unit Nat where
  Inv s := 0 < s
  Init s := s = 1
  Pre _ _ := True
  step s _ s' o := s' = s + 1 ∧ o = s
  run s _ := (s + 1, s)
  run_step _ _ _ := ⟨rfl, rfl⟩

/-- 読む操作（状態を変えない）。 -/
def read : Machine Nat Unit Nat where
  Inv s := 0 < s
  Init s := s = 1
  Pre _ _ := True
  step s _ s' o := s' = s ∧ o = s
  run s _ := (s, s)
  run_step _ _ _ := ⟨rfl, rfl⟩

/-- 並置した機械では、増やした後に読むと、増やした値を見る。 -/
example : ((incr.alt read).run ((incr.alt read).run 1 (.inl ())).1 (.inr ())).2 = .inr 2 := rfl

/-- `sum` で並置すると、状態は別々の写し（`(incr の状態, read の状態)`）になり、読む操作は増やした値を見ない。 -/
example : ((incr.sum read).run ((incr.sum read).run (1, 1) (.inl ())).1 (.inr ())).2 = .inr 1 := rfl

/-- 255 で溢れを誤りとする具体側の増やす操作。 -/
def incr8 : Concrete Nat Unit Nat String :=
  Concrete.ofFun (· = 1) fun t _ => if t < 255 then .ok (t + 1, t) else .error "overflow"

/-- 具体側の読む操作。 -/
def read8 : Concrete Nat Unit Nat String := Concrete.ofFun (· = 1) fun t _ => .ok (t, t)

def glue : Glue Nat Nat Unit Unit Nat Nat := Glue.id Nat Unit Nat

def devNoOverflow (s : Nat) (_ : Unit) : Prop := s < 255

theorem incr8_refines : Refines (incr.restrictState devNoOverflow) incr8 glue where
  init t ht := ⟨t, ht, rfl⟩
  input_total _ _ := ⟨(), rfl⟩
  applicable s t _ _ _ hJ _ hp _ := by
    cases hJ
    have hlt : s < 255 := hp.2
    refine ⟨⟨_, rfl⟩, fun e h => ?_⟩
    simp only [incr8, Concrete.ofFun_step, hlt, ↓reduceIte] at h
    cases h
  correct s t _ _ t' oc _ hJ _ hp _ hs := by
    cases hJ
    have hlt : s < 255 := hp.2
    simp only [incr8, Concrete.ofFun_step, hlt, ↓reduceIte] at hs
    cases hs
    exact ⟨s + 1, s, ⟨rfl, rfl⟩, rfl, rfl⟩

theorem read8_refines : Refines read read8 glue where
  init t ht := ⟨t, ht, rfl⟩
  input_total _ _ := ⟨(), rfl⟩
  applicable s t _ _ _ hJ _ _ _ := by
    cases hJ
    refine ⟨⟨_, rfl⟩, fun e h => ?_⟩
    simp only [read8, Concrete.ofFun_step] at h
    cases h
  correct s t _ _ t' oc _ hJ _ _ _ hs := by
    cases hJ
    simp only [read8, Concrete.ofFun_step] at hs
    cases hs
    exact ⟨s, s, ⟨rfl, rfl⟩, rfl, rfl⟩

/-- 同じ状態の上の並置は、リファインメントを保つ。 -/
theorem alt_refines : Refines ((incr.restrictState devNoOverflow).alt read) (incr8.alt read8) (glue.alt glue) :=
  incr8_refines.alt read8_refines rfl fun _ h => h

end Test.Machine.Alt
