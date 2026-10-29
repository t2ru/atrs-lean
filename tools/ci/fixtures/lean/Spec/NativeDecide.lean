-- expect: LEAN-DECIDE
theorem t : 2 + 2 = 4 := by native_decide
theorem u : (2 : BitVec 8) + 2 = 4 := by bv_decide
