import Machine

/-!
# Test.Machine.Counter

状態を持つ機械の例。抽象側は上限の無いカウンタ、具体側は 255 で溢れを誤りとするカウンタ
（溢れを誤りとする言語の固定長整数の模擬。`LangSemantics` には依存しない）。

- 抽象機械の `Sound`（INIT ⇒ INV、INV の保存）
- 制限しなければ `Refines` は成り立たない（前提型の差異の証拠の模擬）
- `Machine.restrictState` で抽象側の PRE を強めると成り立つ
- `Refines.refl`・`Refines.trans` の使用例
-/

namespace Test.Machine.Counter

open Machine

/-- 上限の無いカウンタ。出力は増やす前の値。 -/
def counter : Machine Nat Unit Nat where
  Inv s := 0 < s
  Init s := s = 1
  Pre _ _ := True
  step s _ s' o := s' = s + 1 ∧ o = s
  run s _ := (s + 1, s)
  run_step _ _ _ := ⟨rfl, rfl⟩

theorem counter_sound : counter.Sound where
  init_inv s h := by simp only [counter] at h ⊢; omega
  step_inv s _ s' _ hi _ hs := by simp only [counter] at hi hs ⊢; omega

#guard counter.run 1 () == (2, 1)

/-- 255 で溢れを誤りとするカウンタ。 -/
def counter8 : Concrete Nat Unit Nat String :=
  Concrete.ofFun (· = 1) fun t _ => if t < 255 then .ok (t + 1, t) else .error "overflow"

def glue : Glue Nat Nat Unit Unit Nat Nat := Glue.id Nat Unit Nat

/-- 前提型の差異の述語の模擬（抽象側の状態の述語）。 -/
def devNoOverflow (s : Nat) (_ : Unit) : Prop := s < 255

/-- 差異の証拠の模擬: 状態 255 で、具体側は溢れて誤る。 -/
theorem counter8_not_refines : ¬ Refines counter counter8 glue := fun h =>
  (h.applicable 255 255 () () (show 0 < 255 by decide) rfl rfl trivial trivial).2 "overflow" rfl

theorem counter8_refines : Refines (counter.restrictState devNoOverflow) counter8 glue where
  init t ht := ⟨t, ht, rfl⟩
  input_total _ _ := ⟨(), rfl⟩
  applicable s t _ _ _ hJ _ hp _ := by
    cases hJ
    have hlt : s < 255 := hp.2
    refine ⟨⟨_, rfl⟩, fun e h => ?_⟩
    simp only [counter8, Concrete.ofFun_step, hlt, ↓reduceIte] at h
    cases h
  correct s t _ _ t' oc _ hJ _ hp _ hs := by
    cases hJ
    have hlt : s < 255 := hp.2
    simp only [counter8, Concrete.ofFun_step, hlt, ↓reduceIte] at hs
    cases hs
    exact ⟨s + 1, s, ⟨rfl, rfl⟩, rfl, rfl⟩

/-- 推移性の例: 制限したカウンタ自身を経由しても、具体側はリファインする。 -/
theorem counter8_refines_trans :
    Refines (counter.restrictState devNoOverflow) counter8
      ((Glue.id Nat Unit Nat).comp glue (counter.restrictState devNoOverflow).Inv) :=
  Refines.trans (counter_sound.restrictState _) (Refines.refl _) counter8_refines

end Test.Machine.Counter
