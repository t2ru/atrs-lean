-- expect:
-- Tests では native_decide と Float を使ってよい
theorem t : 2 + 2 = 4 := by native_decide
def f (x : Float) : Float := x
partial def loop (n : Nat) : Nat := loop n
import Lean
