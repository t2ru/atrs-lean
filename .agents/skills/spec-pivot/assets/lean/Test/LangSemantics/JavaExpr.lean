import LangSemantics.Java

/-! `java!`（`LangSemantics.Java.Expr`）の検査。展開した項が、原始関数を手で書いた項と **構文として同じ** であること
（`#guard_expr … =ₛ …`）と、扱わない式が誤りになることを確かめる（ビルド時に実行される）。 -/

open LangSemantics.Java.DoubleOps LangSemantics.Java.Exception LangSemantics.Java.Int
open LangSemantics.Java LangSemantics.Java.Expr

namespace Test.LangSemantics.JavaExpr

variable (a b c : J32) (l m : J64) (d e : JDouble) (p q : Bool) (r : JResult J32)

/-! ## int -/

-- 優先順位と左結合: `a + b * c - 2` は `(a + (b * c)) - 2`
#guard_expr java! a + b * c - 2 =ₛ j32sub (j32add a (j32mul b c)) (J32.ofInt 2)
#guard_expr java! (a + b) * c =ₛ j32mul (j32add a b) c
#guard_expr java! a - b - c =ₛ j32sub (j32sub a b) c
#guard_expr java! -a =ₛ j32neg a
#guard_expr java! -2147483648 =ₛ J32.ofInt (-2147483648)

-- 整数の除算・剰余は JResult（0 除算）。周りの純粋な演算は `>>=` でつなぐ
#guard_expr java! a / b =ₛ jdiv32 a b
#guard_expr java! a % 100 =ₛ jrem32 a (J32.ofInt 100)

-- 比較: 整数リテラルは値のまま、ほかは `.val`
#guard_expr java! a >= 0 =ₛ decide (a.val ≥ (0 : Int))
#guard_expr java! a < b =ₛ decide (a.val < b.val)
#guard_expr java! a <= 100 =ₛ decide (a.val ≤ (100 : Int))
#guard_expr java! a == b =ₛ decide (a.val = b.val)
#guard_expr java! a != 0 =ₛ decide (a.val ≠ (0 : Int))

/-! ## double・昇格・キャスト -/

-- 運賃計算（`TicketSharedServiceImpl#calculateBasicFare`）の式
#guard_expr java! (int) ((a + b) * (c * 0.01)) =ₛ jd2i (jdmul (jd (j32add a b).val) (jdmul (jd c.val) (jdLit "0.01")))
-- `calculateFare` の式: `1` は int のリテラルで、昇格すると `jd 1`
#guard_expr java! (int) (a * (1 - (b * 0.01))) =ₛ jd2i (jdmul (jd a.val) (jdsub (jd 1) (jdmul (jd b.val) (jdLit "0.01"))))
#guard_expr java! d + 1.5 =ₛ jdadd d (jdLit "1.5")
#guard_expr java! 2d =ₛ jdLit "2"
#guard_expr java! -d =ₛ jdneg d
#guard_expr java! d / e =ₛ jddiv d e
#guard_expr java! (double) a =ₛ jd a.val
#guard_expr java! (long) d =ₛ jd2l d

-- long: リテラル `L`、int からの昇格
#guard_expr java! l + 1L =ₛ j64add l (J64.ofInt 1)
#guard_expr java! l * a =ₛ j64mul l (J64.ofInt a.val)
#guard_expr java! a + 1L =ₛ j64add (J64.ofInt a.val) (J64.ofInt 1)
#guard_expr java! (int) l =ₛ J32.ofInt l.val
#guard_expr java! (long) a =ₛ J64.ofInt a.val
#guard_expr java! l > a =ₛ decide (l.val > a.val)

/-! ## boolean -/

#guard_expr java! a >= 0 && p =ₛ (decide (a.val ≥ (0 : Int)) && p)
#guard_expr java! !(p || q) =ₛ !(p || q)
#guard_expr java! p == q =ₛ (p == q)

/-! ## 埋め込み・呼び出し -/

#guard_expr java! ⟪a + b⟫ * c =ₛ j32mul (a + b) c
#guard_expr java! j32add(a, b * c) =ₛ j32add a (j32mul b c)

/-! ## 例外を投げうる式の値（実行して確かめる） -/

-- `calculateTotalFare` の式: 途中の `/ 100` が JResult なので、式の全体が JResult になる。部分式は左から `>>=` でつなぐ
#guard_expr (java! a * b + c * (a - b) / 100 * c : JResult J32) =ₛ
  ((jdiv32 (j32mul c (j32sub a b)) (J32.ofInt 100) >>= fun x => pure (j32mul x c)) >>= fun y =>
    pure (j32add (j32mul a b) y))
#guard ((fun (x y z : J32) => (java! x * y + z * (x - y) / 100 * z : JResult J32))
  (J32.ofInt 1000) (J32.ofInt 2) (J32.ofInt 60)).toOption.map (·.val) == some (1000 * 2 + 60 * 998 / 100 * 60)
#guard ((fun (x : J32) => (java! x / 0 + 1 : JResult J32)) (J32.ofInt 1)) matches .error (.arithmetic _)
-- 呼び出しの値が JResult なら、続きは `>>=` でつなぐ
#guard ((fun (x : J32) => (java! jdiv32(x, 2) * 3 : JResult J32)) (J32.ofInt 7)).toOption.map (·.val) == some 9
-- 短絡評価: 左辺で決まれば右辺（0 除算）を評価しない
#guard ((fun (x : J32) => (java! x != 0 && x / x == 1 : JResult Bool)) (J32.ofInt 0)).toOption == some false
#guard ((fun (x : J32) => (java! x == 0 || x / x == 1 : JResult Bool)) (J32.ofInt 0)).toOption == some true
#guard ((fun (x : J32) => (java! x != 0 && x / x == 1 : JResult Bool)) (J32.ofInt 5)).toOption == some true

/-! ## 誤り -/

/-- error: java!: int のリテラル 2147483648 は範囲外 -/
#guard_msgs in
example : J32 := java! 2147483648

/-- error: java!: 指数表記の double リテラル 1e3 は扱わない（jdLit が読めない） -/
#guard_msgs in
example : JDouble := java! 1e3

/-- error: java!: double の % は扱わない -/
#guard_msgs in
example (x y : JDouble) : JDouble := java! x % y

/-- error: java!: < を double と double に使えない -/
#guard_msgs in
example (x y : JDouble) : Bool := java! x < y

/-- error: java!: + を （Java の基本型でない） と int に使えない -/
#guard_msgs in
example (s : String) (x : J32) : J32 := java! s + x

end Test.LangSemantics.JavaExpr
