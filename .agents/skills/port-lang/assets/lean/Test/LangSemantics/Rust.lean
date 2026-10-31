import LangSemantics.Rust

/-! LangSemantics.Rust の検査。 -/

open LangSemantics.Rust

def u64 (n : Nat) : U64 := BitVec.ofNat 64 n
def i32 (n : Int) : I32 := BitVec.ofInt 32 n

-- 既定の演算: checked はパニック、wrapping は折り返し
#guard (add .checked .unsigned (u64 (2^64 - 1)) (u64 1)) matches .error _
#guard (add .wrapping .unsigned (u64 (2^64 - 1)) (u64 1)).toOption == some (u64 0)
#guard (checkedAdd .unsigned (u64 (2^64 - 1)) (u64 1)) == none
#guard (saturatingAdd .unsigned (u64 (2^64 - 1)) (u64 1)) == u64 (2^64 - 1)
#guard (checkedSub .unsigned (u64 0) (u64 1)) == none
#guard (saturatingSub .signed (i32 (-2147483648)) (i32 1)) == i32 (-2147483648)
-- 除算
#guard (div .signed (i32 (-7)) (i32 2)).toOption.map (val .signed) == some (-3)
#guard (rem .signed (i32 (-7)) (i32 2)).toOption.map (val .signed) == some (-1)
#guard (div .signed (i32 (-2147483648)) (i32 (-1))) matches .error _
#guard (div .unsigned (u64 1) (u64 0)) matches .error _
#guard (tryFrom (n := 8) .unsigned 256) == none

-- 文字列
#guard strLen "a𠮷" == 5
#guard charsCount "a𠮷" == 2
#guard trim "　ab " == "ab"
#guard splitChar "a--" '-' == ["a", "", ""]
#guard splitChar "" '-' == [""]
#guard (index [1, 2, 3] 3) matches .error _
#guard get [1, 2, 3] 1 == some 2
