import LangSemantics.Java

/-! LangSemantics.Java の検査（ビルド時に実行される）。 -/

open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.String
open LangSemantics.Java LangSemantics.Java.Spring

namespace Test.LangSemantics.Java

-- int: 折り返し・0 方向切捨て・MIN / -1・0 除算
#guard (j32add (J32.ofInt 2147483647) (J32.ofInt 1)).val == -2147483648
#guard (j32mul (J32.ofInt 65536) (J32.ofInt 65536)).val == 0
#guard (jdiv32 (J32.ofInt (-7)) (J32.ofInt 2)).toOption.map (·.val) == some (-3)
#guard (jrem32 (J32.ofInt (-7)) (J32.ofInt 2)).toOption.map (·.val) == some (-1)
#guard (jdiv32 (J32.ofInt (-2147483648)) (J32.ofInt (-1))).toOption.map (·.val) == some (-2147483648)
#guard (jdiv32 (J32.ofInt 1) (J32.ofInt 0)) matches .error (.arithmetic _)

-- double: リテラル 0.01 のビット表現
#guard (jdLit "0.01").toBits == 0x3F847AE147AE147B#64
#guard (jdLit "0.1").toBits.toNat == (Float.toBits 0.1).toNat
-- 1430 * (1 - 30 * 0.01) は 1000.999… で、(int) は 1000（厳密計算では 1001）
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 1000
-- 縮小変換: NaN → 0、∞ は飽和、負は 0 方向
#guard (jd2i .nan).val == 0
#guard (jd2i (.inf false)).val == 2147483647
#guard (jd2i (jdLit "-2.9")).val == -2
#guard (jd2i (jdLit "1e3")).val == 0  -- 指数表記は未対応 → NaN → 0
-- ゼロの符号
#guard (jdadd (jd 1) (jdsub (jd 0) (jd 1))).toBits == 0#64
#guard (jdmul (jdLit "-0.0") (jd 5)).toBits == 0x8000000000000000#64
-- 除算
#guard (jddiv (jd 1) (jd 0)) == .inf false
#guard (jddiv (jd 0) (jd 0)) == .nan

/-- ネイティブ Float との差分検査: x * (1 - r * 0.01) と (x + y) と x / y のビット表現。 -/
def softMatchesNative (x r : Nat) : Bool :=
  let soft := jdmul (jd x) (jdsub (jd 1) (jdmul (jd r) (jdLit "0.01")))
  let native := x.toFloat * (1.0 - r.toFloat * 0.01)
  let soft2 := jdadd (jdmul (jd x) (jdLit "0.01")) (jdLit "0.1")
  let native2 := x.toFloat * 0.01 + 0.1
  let soft3 := jddiv (jd x) (jd (r + 1))
  let native3 := x.toFloat / (r + 1).toFloat
  soft.toBits.toNat == (Float.toBits native).toNat &&
  soft2.toBits.toNat == (Float.toBits native2).toNat &&
  soft3.toBits.toNat == (Float.toBits native3).toNat

#guard (List.range 200).all (fun i => (List.range 101).all (fun r => softMatchesNative (i * 137 + 1) r))

-- BigDecimal setScale(-2, UP).intValue()
#guard (bdCeilHundredUp (J32.ofInt 1001)).val == 1100
#guard (bdCeilHundredUp (J32.ofInt 1000)).val == 1000
#guard (bdCeilHundredUp (J32.ofInt (-1001))).val == -1100
#guard ((JBigDecimal.ofInt 1250).setScale (-2) .halfEven).unscaled == 12
#guard ((JBigDecimal.ofInt 1350).setScale (-2) .halfEven).unscaled == 14

-- String
#guard utf16Len "a𠮷" == 3
#guard jTrim " \tab \u0000" == "ab"
#guard jTrim "　ab" == "　ab"
#guard jStrip "　ab " == "ab"
#guard jSplitChar "03-1234-5678" '-' == ["03", "1234", "5678"]
#guard jSplitChar "a--" '-' == ["a"]
#guard jSplitChar "-" '-' == []
#guard jSplitChar "" '-' == [""]
#guard jSplitChar "01/25" '/' == ["01", "25"]

-- LocalDate
#guard (JLocalDate.ofYMD? 1970 1 1).map (·.toEpochDay) == some 0
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => (d.plusDays 1).formatYMD) == some "2024/02/29"
#guard (JLocalDate.ofYMD? 2023 12 31).map (fun d => (d.plusDays 1).formatYMD) == some "2024/01/01"
#guard (JLocalDate.ofYMD? 2023 2 29) == none
#guard (List.range 3000).all (fun i =>
  let z : Int := (i : Int) * 97 - 100000
  (JLocalDate.ofEpochDay z).toEpochDay == z)
#guard (do
    let a ← JLocalDate.ofYMD? 2000 2 29
    let b ← JLocalDate.ofYMD? 2001 2 28
    let c ← JLocalDate.ofYMD? 2001 3 1
    pure (a.yearsBetween b, a.yearsBetween c)) == some (0, 1)

-- HashMap: put は後勝ちで置き換え、get は無ければ null
#guard ((JHashMap.ofList [("a", 1), ("b", 2), ("a", 3)]).get "a") == some 3
#guard ((JHashMap.ofList [("a", 1), ("b", 2), ("a", 3)]).size) == 2
#guard ((JHashMap.ofList [("a", 1)] : JHashMap String Nat).get "z") == none

-- Spring の Assert: 条件を満たさなければ IllegalArgumentException(message)
#guard (Assert.isTrue false "m") matches .error (.illegalArgument "m")
#guard (Assert.notNull (none : Option Nat) "m") matches .error (.illegalArgument "m")
#guard (Assert.notNullValue (some 3) "m").toOption == some 3
#guard (Assert.notEmpty (some ([] : List Nat)) "m") matches .error (.illegalArgument "m")
#guard (Assert.notEmptyValue (some [1, 2]) "m").toOption == some [1, 2]
#guard (Assert.hasText " \t\u3000" "m") matches .error (.illegalArgument "m")
#guard (Assert.hasText " a " "m").toOption == some ()

end Test.LangSemantics.Java
