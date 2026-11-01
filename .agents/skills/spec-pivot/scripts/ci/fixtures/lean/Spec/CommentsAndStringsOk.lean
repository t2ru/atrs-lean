-- expect:
/-! sorry axiom native_decide Float partial panic! /- 入れ子 sorry -/ まだコメント -/
-- sorry Float
/-- docstring: `axiom`, `xs[i]!` -/
def s : String := "sorry axiom Float partial \" native_decide"
def c : Char := '"'
def c2 : Char := '\''
def x' : Nat := 1
def sorryFree : Nat := x' + 1
def axioms : List String := ["propext"]
def floatLike : Nat := 0
def partialSum : Nat := 0
def getD' (xs : Array Nat) : Nat := xs.getD 0 0
def notBang : Bool := !true
