import LangSemantics.Core.EStateHoare
import LangSemantics.Core.EStateSimp

/-!
# Test.LangSemantics.EStateHoare

`LangSemantics.Core.EStateHoare`（Hoare 三つ組）と `estate_simp` の例と反例。
-/

namespace Test.LangSemantics.EStateHoare
open _root_.LangSemantics.Core.EStateHoare

/-- 状態を 1 増やして読む。 -/
def incGet : EStateM String Nat Nat := do
  modify (· + 1)
  get

/-- 例: `estate_simp` で計算の形を求める。 -/
example (s : Nat) : incGet s = .ok (s + 1) (s + 1) := by
  estate_simp [incGet]

/-- 例: 逐次の合成の規則。 -/
example : Hoare (fun s => s = 0) incGet (fun r s => r = 1 ∧ s = 1) (fun _ _ => False) := by
  intro s hs
  subst hs
  estate_simp [incGet]

/-- 負の数で例外を投げる。 -/
def check (n : Int) : EStateM String Nat Unit := if n < 0 then throw "negative" else pure ()

/-- 例: 分岐と例外の規則。 -/
example (n : Int) : Hoare (fun _ => True) (check n) (fun _ _ => 0 ≤ n) (fun e _ => e = "negative" ∧ n < 0) := by
  unfold check
  refine Hoare.ite' (fun h => Hoare.throw' fun _ _ => ⟨rfl, h⟩) (fun h => Hoare.pure' fun _ _ => by omega)

/-- 例: `for` の規則（不変条件: 状態は処理済みの要素の和）。 -/
def sumAll (xs : List Nat) : EStateM String Nat Unit := do
  for x in xs do
    modify (· + x)

example (xs : List Nat) : Hoare (fun s => s = 0) (sumAll xs) (fun _ s => s = xs.sum) (fun _ _ => False) := by
  unfold sumAll
  have := Hoare.forIn' (E := fun (_ : String) (_ : Nat) => False) xs PUnit.unit
    (fun x _ => do modify (· + x); pure (ForInStep.yield PUnit.unit))
    (fun pre _ s => s = pre.sum) (fun pre x suf acc _ s hs => by
      estate_simp
      exact ⟨PUnit.unit, trivial, by simp [hs]⟩)
  simpa using this

/-- 反例: 例外で終わる計算に、例外の事後条件 `False` の三つ組は成り立たない。 -/
example : ¬ Hoare (fun _ => True) (throw "x" : EStateM String Nat Unit) (fun _ _ => True) (fun _ _ => False) :=
  fun h => h 0 trivial

end Test.LangSemantics.EStateHoare
