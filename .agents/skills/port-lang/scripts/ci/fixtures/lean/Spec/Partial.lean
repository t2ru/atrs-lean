-- expect: LEAN-UNSAFE
partial def loop (n : Nat) : Nat := loop n
def g (xs : Array Nat) : Nat := xs[0]!
def h : Nat := panic! "x"
def k (xs : Array Nat) : Nat := xs.get! 0
