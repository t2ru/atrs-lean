import LangSemantics.Java

/-!
# Test.LangSemantics.JavaJvm

**生成物（手で編集しない）。** `Test/LangSemantics/jvm/JavaTable.java` が JVM で計算した値と、
`LangSemantics.Java` の結果を突き合わせる。再生成: `java Test/LangSemantics/jvm/JavaTable.java > Test/LangSemantics/JavaJvm.lean`
-/

open LangSemantics.Java
open LangSemantics.Java.BigDecimal LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.String
open LangSemantics.Java.DoubleOps

/-! ## BigDecimal -/

-- new BigDecimal(n).setScale(-2, RoundingMode.UP).intValue()
#guard (bdCeilHundredUp (J32.ofInt 0)).val == 0
#guard (bdCeilHundredUp (J32.ofInt 1)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 49)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 50)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 51)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 99)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 100)).val == 100
#guard (bdCeilHundredUp (J32.ofInt 101)).val == 200
#guard (bdCeilHundredUp (J32.ofInt 150)).val == 200
#guard (bdCeilHundredUp (J32.ofInt 250)).val == 300
#guard (bdCeilHundredUp (J32.ofInt 1000)).val == 1000
#guard (bdCeilHundredUp (J32.ofInt 1001)).val == 1100
#guard (bdCeilHundredUp (J32.ofInt 1099)).val == 1100
#guard (bdCeilHundredUp (J32.ofInt 1100)).val == 1100
#guard (bdCeilHundredUp (J32.ofInt 28800)).val == 28800
#guard (bdCeilHundredUp (J32.ofInt 28801)).val == 28900
#guard (bdCeilHundredUp (J32.ofInt (-1))).val == (-100)
#guard (bdCeilHundredUp (J32.ofInt (-49))).val == (-100)
#guard (bdCeilHundredUp (J32.ofInt (-50))).val == (-100)
#guard (bdCeilHundredUp (J32.ofInt (-51))).val == (-100)
#guard (bdCeilHundredUp (J32.ofInt (-150))).val == (-200)
#guard (bdCeilHundredUp (J32.ofInt (-250))).val == (-300)
#guard (bdCeilHundredUp (J32.ofInt (-1001))).val == (-1100)
#guard (bdCeilHundredUp (J32.ofInt (-1100))).val == (-1100)
#guard (bdCeilHundredUp (J32.ofInt 2147483599)).val == 2147483600
#guard (bdCeilHundredUp (J32.ofInt 2147483600)).val == 2147483600
#guard (bdCeilHundredUp (J32.ofInt 2147483647)).val == (-2147483596)
#guard (bdCeilHundredUp (J32.ofInt (-2147483600))).val == (-2147483600)
#guard (bdCeilHundredUp (J32.ofInt (-2147483601))).val == 2147483596
#guard (bdCeilHundredUp (J32.ofInt (-2147483648))).val == 2147483596
-- new BigDecimal(n).setScale(-2, mode).unscaledValue()
#guard ((JBigDecimal.ofInt 0).setScale (-2) .up).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .up).unscaled == 1
#guard ((JBigDecimal.ofInt 50).setScale (-2) .up).unscaled == 1
#guard ((JBigDecimal.ofInt 51).setScale (-2) .up).unscaled == 1
#guard ((JBigDecimal.ofInt 149).setScale (-2) .up).unscaled == 2
#guard ((JBigDecimal.ofInt 150).setScale (-2) .up).unscaled == 2
#guard ((JBigDecimal.ofInt 151).setScale (-2) .up).unscaled == 2
#guard ((JBigDecimal.ofInt 250).setScale (-2) .up).unscaled == 3
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .up).unscaled == 11
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .up).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .up).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .up).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .up).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .up).unscaled == (-3)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .up).unscaled == (-11)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt 50).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt 51).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt 149).setScale (-2) .down).unscaled == 1
#guard ((JBigDecimal.ofInt 150).setScale (-2) .down).unscaled == 1
#guard ((JBigDecimal.ofInt 151).setScale (-2) .down).unscaled == 1
#guard ((JBigDecimal.ofInt 250).setScale (-2) .down).unscaled == 2
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .down).unscaled == 10
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .down).unscaled == 0
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .down).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .down).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .down).unscaled == (-10)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .ceiling).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .ceiling).unscaled == 1
#guard ((JBigDecimal.ofInt 50).setScale (-2) .ceiling).unscaled == 1
#guard ((JBigDecimal.ofInt 51).setScale (-2) .ceiling).unscaled == 1
#guard ((JBigDecimal.ofInt 149).setScale (-2) .ceiling).unscaled == 2
#guard ((JBigDecimal.ofInt 150).setScale (-2) .ceiling).unscaled == 2
#guard ((JBigDecimal.ofInt 151).setScale (-2) .ceiling).unscaled == 2
#guard ((JBigDecimal.ofInt 250).setScale (-2) .ceiling).unscaled == 3
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .ceiling).unscaled == 11
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .ceiling).unscaled == 0
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .ceiling).unscaled == 0
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .ceiling).unscaled == 0
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .ceiling).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .ceiling).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .ceiling).unscaled == (-10)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .floor).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .floor).unscaled == 0
#guard ((JBigDecimal.ofInt 50).setScale (-2) .floor).unscaled == 0
#guard ((JBigDecimal.ofInt 51).setScale (-2) .floor).unscaled == 0
#guard ((JBigDecimal.ofInt 149).setScale (-2) .floor).unscaled == 1
#guard ((JBigDecimal.ofInt 150).setScale (-2) .floor).unscaled == 1
#guard ((JBigDecimal.ofInt 151).setScale (-2) .floor).unscaled == 1
#guard ((JBigDecimal.ofInt 250).setScale (-2) .floor).unscaled == 2
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .floor).unscaled == 10
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .floor).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .floor).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .floor).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .floor).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .floor).unscaled == (-3)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .floor).unscaled == (-11)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .halfUp).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .halfUp).unscaled == 0
#guard ((JBigDecimal.ofInt 50).setScale (-2) .halfUp).unscaled == 1
#guard ((JBigDecimal.ofInt 51).setScale (-2) .halfUp).unscaled == 1
#guard ((JBigDecimal.ofInt 149).setScale (-2) .halfUp).unscaled == 1
#guard ((JBigDecimal.ofInt 150).setScale (-2) .halfUp).unscaled == 2
#guard ((JBigDecimal.ofInt 151).setScale (-2) .halfUp).unscaled == 2
#guard ((JBigDecimal.ofInt 250).setScale (-2) .halfUp).unscaled == 3
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .halfUp).unscaled == 10
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .halfUp).unscaled == 0
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .halfUp).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .halfUp).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .halfUp).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .halfUp).unscaled == (-3)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .halfUp).unscaled == (-10)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .halfDown).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .halfDown).unscaled == 0
#guard ((JBigDecimal.ofInt 50).setScale (-2) .halfDown).unscaled == 0
#guard ((JBigDecimal.ofInt 51).setScale (-2) .halfDown).unscaled == 1
#guard ((JBigDecimal.ofInt 149).setScale (-2) .halfDown).unscaled == 1
#guard ((JBigDecimal.ofInt 150).setScale (-2) .halfDown).unscaled == 1
#guard ((JBigDecimal.ofInt 151).setScale (-2) .halfDown).unscaled == 2
#guard ((JBigDecimal.ofInt 250).setScale (-2) .halfDown).unscaled == 2
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .halfDown).unscaled == 10
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .halfDown).unscaled == 0
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .halfDown).unscaled == 0
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .halfDown).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .halfDown).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .halfDown).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .halfDown).unscaled == (-10)
#guard ((JBigDecimal.ofInt 0).setScale (-2) .halfEven).unscaled == 0
#guard ((JBigDecimal.ofInt 49).setScale (-2) .halfEven).unscaled == 0
#guard ((JBigDecimal.ofInt 50).setScale (-2) .halfEven).unscaled == 0
#guard ((JBigDecimal.ofInt 51).setScale (-2) .halfEven).unscaled == 1
#guard ((JBigDecimal.ofInt 149).setScale (-2) .halfEven).unscaled == 1
#guard ((JBigDecimal.ofInt 150).setScale (-2) .halfEven).unscaled == 2
#guard ((JBigDecimal.ofInt 151).setScale (-2) .halfEven).unscaled == 2
#guard ((JBigDecimal.ofInt 250).setScale (-2) .halfEven).unscaled == 2
#guard ((JBigDecimal.ofInt 1001).setScale (-2) .halfEven).unscaled == 10
#guard ((JBigDecimal.ofInt (-49)).setScale (-2) .halfEven).unscaled == 0
#guard ((JBigDecimal.ofInt (-50)).setScale (-2) .halfEven).unscaled == 0
#guard ((JBigDecimal.ofInt (-51)).setScale (-2) .halfEven).unscaled == (-1)
#guard ((JBigDecimal.ofInt (-150)).setScale (-2) .halfEven).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-250)).setScale (-2) .halfEven).unscaled == (-2)
#guard ((JBigDecimal.ofInt (-1001)).setScale (-2) .halfEven).unscaled == (-10)

/-! ## String -/

-- String.length()
#guard utf16Len "" == 0
#guard utf16Len "a" == 1
#guard utf16Len "abc" == 3
#guard utf16Len "a𠮷" == 3
#guard utf16Len "𠮷𠮷" == 4
#guard utf16Len "山田" == 2
#guard utf16Len "ﾔﾏﾀﾞ" == 4
#guard utf16Len " \x09ab \x00" == 6
#guard utf16Len "　ab　" == 4
#guard utf16Len " ab " == 4
#guard utf16Len " " == 1
#guard utf16Len " x " == 3
#guard utf16Len "ab\x0a" == 3
#guard utf16Len "\x1fab\x1c" == 4
-- String.trim()
#guard jTrim "" == ""
#guard jTrim "a" == "a"
#guard jTrim "abc" == "abc"
#guard jTrim "a𠮷" == "a𠮷"
#guard jTrim "𠮷𠮷" == "𠮷𠮷"
#guard jTrim "山田" == "山田"
#guard jTrim "ﾔﾏﾀﾞ" == "ﾔﾏﾀﾞ"
#guard jTrim " \x09ab \x00" == "ab"
#guard jTrim "　ab　" == "　ab　"
#guard jTrim " ab " == " ab "
#guard jTrim " " == ""
#guard jTrim " x " == " x "
#guard jTrim "ab\x0a" == "ab"
#guard jTrim "\x1fab\x1c" == "ab"
-- String.strip()
#guard jStrip "" == ""
#guard jStrip "a" == "a"
#guard jStrip "abc" == "abc"
#guard jStrip "a𠮷" == "a𠮷"
#guard jStrip "𠮷𠮷" == "𠮷𠮷"
#guard jStrip "山田" == "山田"
#guard jStrip "ﾔﾏﾀﾞ" == "ﾔﾏﾀﾞ"
#guard jStrip " \x09ab \x00" == "ab \x00"
#guard jStrip "　ab　" == "ab"
#guard jStrip " ab " == " ab "
#guard jStrip " " == ""
#guard jStrip " x " == "x"
#guard jStrip "ab\x0a" == "ab"
#guard jStrip "\x1fab\x1c" == "ab"
-- String.split(sep)
#guard jSplitChar "03-1234-5678" '-' == ["03", "1234", "5678"]
#guard jSplitChar "a--" '-' == ["a"]
#guard jSplitChar "-" '-' == []
#guard jSplitChar "" '-' == [""]
#guard jSplitChar "--a" '-' == ["", "", "a"]
#guard jSplitChar "-a-b-" '-' == ["", "a", "b"]
#guard jSplitChar "a" '-' == ["a"]
#guard jSplitChar "01/25" '/' == ["01", "25"]
#guard jSplitChar "1/" '/' == ["1"]
#guard jSplitChar "/1" '/' == ["", "1"]
#guard jSplitChar "12345" '/' == ["12345"]
#guard jSplitChar "a//b" '/' == ["a", "", "b"]

/-! ## LocalDate -/

-- toEpochDay / ofEpochDay
#guard (JLocalDate.ofYMD? 1970 1 1).map (·.toEpochDay) == some 0
#guard (let r := JLocalDate.ofEpochDay 0; (r.year, r.month, r.day)) == (1970, 1, 1)
#guard (JLocalDate.ofYMD? 2024 2 28).map (·.toEpochDay) == some 19781
#guard (let r := JLocalDate.ofEpochDay 19781; (r.year, r.month, r.day)) == (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (·.toEpochDay) == some 19782
#guard (let r := JLocalDate.ofEpochDay 19782; (r.year, r.month, r.day)) == (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (·.toEpochDay) == some 19416
#guard (let r := JLocalDate.ofEpochDay 19416; (r.year, r.month, r.day)) == (2023, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (·.toEpochDay) == some (-25509)
#guard (let r := JLocalDate.ofEpochDay (-25509); (r.year, r.month, r.day)) == (1900, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (·.toEpochDay) == some 11016
#guard (let r := JLocalDate.ofEpochDay 11016; (r.year, r.month, r.day)) == (2000, 2, 29)
#guard (JLocalDate.ofYMD? 2026 12 31).map (·.toEpochDay) == some 20818
#guard (let r := JLocalDate.ofEpochDay 20818; (r.year, r.month, r.day)) == (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (·.toEpochDay) == some 20819
#guard (let r := JLocalDate.ofEpochDay 20819; (r.year, r.month, r.day)) == (2027, 1, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (·.toEpochDay) == some 20758
#guard (let r := JLocalDate.ofEpochDay 20758; (r.year, r.month, r.day)) == (2026, 11, 1)
#guard (JLocalDate.ofYMD? 1 1 1).map (·.toEpochDay) == some (-719162)
#guard (let r := JLocalDate.ofEpochDay (-719162); (r.year, r.month, r.day)) == (1, 1, 1)
#guard (JLocalDate.ofYMD? 9999 12 31).map (·.toEpochDay) == some 2932896
#guard (let r := JLocalDate.ofEpochDay 2932896; (r.year, r.month, r.day)) == (9999, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (·.toEpochDay) == some (-1)
#guard (let r := JLocalDate.ofEpochDay (-1); (r.year, r.month, r.day)) == (1969, 12, 31)
#guard (JLocalDate.ofYMD? 0 3 1).map (·.toEpochDay) == some (-719468)
#guard (let r := JLocalDate.ofEpochDay (-719468); (r.year, r.month, r.day)) == (0, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (·.toEpochDay) == some (-719834)
#guard (let r := JLocalDate.ofEpochDay (-719834); (r.year, r.month, r.day)) == (-1, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (·.toEpochDay) == some (-865200)
#guard (let r := JLocalDate.ofEpochDay (-865200); (r.year, r.month, r.day)) == (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (·.toEpochDay) == some (-865567)
#guard (let r := JLocalDate.ofEpochDay (-865567); (r.year, r.month, r.day)) == (-400, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (·.toEpochDay) == some (-865566)
#guard (let r := JLocalDate.ofEpochDay (-865566); (r.year, r.month, r.day)) == (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (·.toEpochDay) == some (-865565)
#guard (let r := JLocalDate.ofEpochDay (-865565); (r.year, r.month, r.day)) == (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (·.toEpochDay) == some (-865626)
#guard (let r := JLocalDate.ofEpochDay (-865626); (r.year, r.month, r.day)) == (-401, 12, 31)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (·.toEpochDay) == some (-1011662)
#guard (let r := JLocalDate.ofEpochDay (-1011662); (r.year, r.month, r.day)) == (-800, 3, 1)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (·.toEpochDay) == some (-2440588)
#guard (let r := JLocalDate.ofEpochDay (-2440588); (r.year, r.month, r.day)) == (-4713, 11, 24)
#guard (JLocalDate.ofYMD? 10000 1 1).map (·.toEpochDay) == some 2932897
#guard (let r := JLocalDate.ofEpochDay 2932897; (r.year, r.month, r.day)) == (10000, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (·.toEpochDay) == some 2145042905
#guard (let r := JLocalDate.ofEpochDay 2145042905; (r.year, r.month, r.day)) == (5874897, 12, 31)
-- plusDays / minusDays
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (1970, 1, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (1970, 1, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (1970, 1, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (1969, 12, 31)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (1969, 12, 31)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (1970, 1, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (1970, 1, 31)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (1969, 12, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (1970, 3, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (1969, 11, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (1970, 4, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (1969, 10, 3)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (1970, 5, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (1969, 9, 3)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (1971, 1, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (1969, 1, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (1971, 1, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (1968, 12, 31)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (1968, 12, 31)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (1971, 1, 2)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (1974, 1, 1)
#guard (JLocalDate.ofYMD? 1970 1 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (1966, 1, 1)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2024, 2, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2024, 2, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2024, 3, 29)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2024, 1, 29)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2024, 4, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2023, 12, 30)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2024, 5, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2023, 11, 30)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2024, 6, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2023, 10, 31)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2025, 2, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2023, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2025, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2023, 2, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2023, 2, 27)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2025, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2028, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 28).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2020, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2024, 3, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2024, 3, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2024, 3, 30)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2024, 1, 30)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2024, 4, 29)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2023, 12, 31)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2024, 5, 29)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2023, 12, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2024, 6, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2023, 11, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2025, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2023, 3, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2025, 3, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2023, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2023, 2, 28)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2025, 3, 1)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2028, 2, 29)
#guard (JLocalDate.ofYMD? 2024 2 29).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2020, 2, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2023, 2, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2023, 2, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2023, 3, 1)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2023, 2, 27)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2023, 2, 27)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2023, 3, 1)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2023, 3, 30)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2023, 1, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2023, 4, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2022, 12, 30)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2023, 5, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2022, 11, 30)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2023, 6, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2022, 10, 31)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2024, 2, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2022, 2, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2022, 2, 27)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2022, 2, 27)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2024, 2, 29)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2027, 2, 28)
#guard (JLocalDate.ofYMD? 2023 2 28).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2019, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (1900, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (1900, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (1900, 3, 1)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (1900, 2, 27)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (1900, 2, 27)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (1900, 3, 1)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (1900, 3, 30)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (1900, 1, 29)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (1900, 4, 29)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (1899, 12, 30)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (1900, 5, 29)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (1899, 11, 30)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (1900, 6, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (1899, 10, 31)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (1901, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (1899, 2, 28)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (1901, 3, 1)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (1899, 2, 27)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (1899, 2, 27)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (1901, 3, 1)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (1904, 2, 29)
#guard (JLocalDate.ofYMD? 1900 2 28).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (1896, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2000, 2, 29)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2000, 2, 29)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2000, 3, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2000, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2000, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2000, 3, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2000, 3, 30)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2000, 1, 30)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2000, 4, 29)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (1999, 12, 31)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2000, 5, 29)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (1999, 12, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2000, 6, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (1999, 11, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2001, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (1999, 3, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2001, 3, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (1999, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (1999, 2, 28)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2001, 3, 1)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2004, 2, 29)
#guard (JLocalDate.ofYMD? 2000 2 29).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (1996, 2, 29)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2027, 1, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2026, 12, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2026, 12, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2027, 1, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2027, 1, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2026, 12, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2027, 3, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2026, 11, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2027, 3, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2026, 10, 2)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2027, 4, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2026, 9, 2)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2027, 12, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2025, 12, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2028, 1, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2025, 12, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2025, 12, 30)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2028, 1, 1)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2030, 12, 31)
#guard (JLocalDate.ofYMD? 2026 12 31).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2022, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2027, 1, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2027, 1, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2027, 1, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2027, 1, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2027, 1, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2026, 12, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2027, 3, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2026, 11, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2027, 4, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2026, 10, 3)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2027, 5, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2026, 9, 3)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2028, 1, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2026, 1, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2028, 1, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2025, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2025, 12, 31)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2028, 1, 2)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2031, 1, 1)
#guard (JLocalDate.ofYMD? 2027 1 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2023, 1, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (2026, 11, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (2026, 11, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (2026, 11, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (2026, 10, 31)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (2026, 10, 31)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (2026, 11, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (2026, 12, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (2026, 10, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (2026, 12, 31)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (2026, 9, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (2027, 1, 30)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (2026, 8, 3)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (2027, 3, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (2026, 7, 4)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (2027, 11, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (2025, 11, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (2027, 11, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (2025, 10, 31)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (2025, 10, 31)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (2027, 11, 2)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (2030, 11, 1)
#guard (JLocalDate.ofYMD? 2026 11 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (2022, 11, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (1969, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (1969, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (1970, 1, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (1969, 12, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (1969, 12, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (1970, 1, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (1970, 1, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (1969, 12, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (1970, 3, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (1969, 11, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (1970, 3, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (1969, 10, 2)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (1970, 4, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (1969, 9, 2)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (1970, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (1968, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (1971, 1, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (1968, 12, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (1968, 12, 30)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (1971, 1, 1)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (1973, 12, 31)
#guard (JLocalDate.ofYMD? 1969 12 31).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (1965, 12, 31)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (0, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (0, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (0, 3, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (0, 2, 29)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (0, 2, 29)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (0, 3, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (0, 3, 31)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (0, 1, 31)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (0, 4, 30)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (0, 1, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (0, 5, 30)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-1, 12, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (0, 6, 29)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-1, 11, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (1, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-1, 3, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (1, 3, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-1, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-1, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (1, 3, 2)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (4, 3, 1)
#guard (JLocalDate.ofYMD? 0 3 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-4, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-1, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-1, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-1, 3, 2)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-1, 2, 28)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-1, 2, 28)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-1, 3, 2)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-1, 3, 31)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-1, 1, 30)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-1, 4, 30)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-2, 12, 31)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-1, 5, 30)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-2, 12, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-1, 6, 29)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-2, 11, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (0, 2, 29)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-2, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (0, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-2, 2, 28)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-2, 2, 28)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (0, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (3, 3, 1)
#guard (JLocalDate.ofYMD? (-1) 3 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-5, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-399, 3, 2)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-399, 2, 28)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-399, 2, 28)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-399, 3, 2)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-399, 3, 31)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-399, 1, 30)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-399, 4, 30)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-400, 12, 31)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-399, 5, 30)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-400, 12, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-399, 6, 29)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-400, 11, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-398, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-398, 3, 2)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-398, 3, 2)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-395, 3, 1)
#guard (JLocalDate.ofYMD? (-399) 3 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-403, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-400, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-400, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-400, 2, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-400, 2, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-400, 3, 29)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-400, 1, 29)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-400, 4, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-401, 12, 30)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-400, 5, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-401, 11, 30)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-400, 6, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-401, 10, 31)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-399, 2, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-401, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-399, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-401, 2, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-401, 2, 27)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-399, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-396, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 28).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-404, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-400, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-400, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-400, 3, 30)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-400, 1, 30)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-400, 4, 29)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-401, 12, 31)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-400, 5, 29)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-401, 12, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-400, 6, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-401, 11, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-399, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-401, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-401, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-401, 2, 28)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-396, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 2 29).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-404, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-400, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-400, 3, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-400, 3, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-400, 3, 31)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-400, 1, 31)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-400, 4, 30)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-400, 1, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-400, 5, 30)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-401, 12, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-400, 6, 29)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-401, 11, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-399, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-401, 3, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-399, 3, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-401, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-401, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-399, 3, 2)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-396, 3, 1)
#guard (JLocalDate.ofYMD? (-400) 3 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-404, 3, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-401, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-401, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-400, 1, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-401, 12, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-401, 12, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-400, 1, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-400, 1, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-401, 12, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-400, 2, 29)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-401, 11, 1)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-400, 3, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-401, 10, 2)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-400, 4, 29)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-401, 9, 2)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-400, 12, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-402, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-400, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-402, 12, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-402, 12, 30)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-400, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-397, 12, 31)
#guard (JLocalDate.ofYMD? (-401) 12 31).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-405, 12, 31)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-800, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-800, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-800, 3, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-800, 2, 29)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-800, 2, 29)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-800, 3, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-800, 3, 31)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-800, 1, 31)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-800, 4, 30)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-800, 1, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-800, 5, 30)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-801, 12, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-800, 6, 29)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-801, 11, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-799, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-801, 3, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-799, 3, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-801, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-801, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-799, 3, 2)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-796, 3, 1)
#guard (JLocalDate.ofYMD? (-800) 3 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-804, 3, 1)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (-4713, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (-4713, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (-4713, 11, 25)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (-4713, 11, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (-4713, 11, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (-4713, 11, 25)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (-4713, 12, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (-4713, 10, 25)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (-4712, 1, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (-4713, 9, 25)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (-4712, 2, 22)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (-4713, 8, 26)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (-4712, 3, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (-4713, 7, 27)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (-4712, 11, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (-4714, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (-4712, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (-4714, 11, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (-4714, 11, 23)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (-4712, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (-4709, 11, 24)
#guard (JLocalDate.ofYMD? (-4713) 11 24).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (-4717, 11, 24)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (10000, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (10000, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (10000, 1, 2)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (9999, 12, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (9999, 12, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (10000, 1, 2)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (10000, 1, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (9999, 12, 2)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (10000, 3, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (9999, 11, 2)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (10000, 3, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (9999, 10, 3)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (10000, 4, 30)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (9999, 9, 3)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (10000, 12, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (9999, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (10001, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (9998, 12, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (9998, 12, 31)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (10001, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (10004, 1, 1)
#guard (JLocalDate.ofYMD? 10000 1 1).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (9996, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 0; (r.year, r.month, r.day)) == some (5874897, 12, 31)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 0; (r.year, r.month, r.day)) == some (5874897, 12, 31)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 1; (r.year, r.month, r.day)) == some (5874898, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 1; (r.year, r.month, r.day)) == some (5874897, 12, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays (-1); (r.year, r.month, r.day)) == some (5874897, 12, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays (-1); (r.year, r.month, r.day)) == some (5874898, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 30; (r.year, r.month, r.day)) == some (5874898, 1, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 30; (r.year, r.month, r.day)) == some (5874897, 12, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 60; (r.year, r.month, r.day)) == some (5874898, 3, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 60; (r.year, r.month, r.day)) == some (5874897, 11, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 90; (r.year, r.month, r.day)) == some (5874898, 3, 31)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 90; (r.year, r.month, r.day)) == some (5874897, 10, 2)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 120; (r.year, r.month, r.day)) == some (5874898, 4, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 120; (r.year, r.month, r.day)) == some (5874897, 9, 2)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 365; (r.year, r.month, r.day)) == some (5874898, 12, 31)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 365; (r.year, r.month, r.day)) == some (5874896, 12, 31)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 366; (r.year, r.month, r.day)) == some (5874899, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 366; (r.year, r.month, r.day)) == some (5874896, 12, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays (-366); (r.year, r.month, r.day)) == some (5874896, 12, 30)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays (-366); (r.year, r.month, r.day)) == some (5874899, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.plusDays 1461; (r.year, r.month, r.day)) == some (5874902, 1, 1)
#guard (JLocalDate.ofYMD? 5874897 12 31).map (fun d => let r := d.minusDays 1461; (r.year, r.month, r.day)) == some (5874893, 12, 31)
-- LocalDate.of の検査
#guard (JLocalDate.ofYMD? 2023 2 29).isSome == false
#guard (JLocalDate.ofYMD? 1900 2 29).isSome == false
#guard (JLocalDate.ofYMD? 2026 4 31).isSome == false
#guard (JLocalDate.ofYMD? 2026 13 1).isSome == false
#guard (JLocalDate.ofYMD? 2026 0 1).isSome == false
#guard (JLocalDate.ofYMD? 2026 1 0).isSome == false
-- isBefore / isAfter / ChronoUnit.DAYS.between / ChronoUnit.YEARS.between
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 2 28); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 2 28); pure (a.daysBetween b)) == some 365
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 2 28); pure (a.yearsBetween b)) == some 0
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 3 1); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 3 1); pure (a.daysBetween b)) == some 366
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2001 3 1); pure (a.yearsBetween b)) == some 1
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2004 2 29); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2004 2 29); pure (a.daysBetween b)) == some 1461
#guard (do let a ← (JLocalDate.ofYMD? 2000 2 29); let b ← (JLocalDate.ofYMD? 2004 2 29); pure (a.yearsBetween b)) == some 4
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.daysBetween b)) == some 13149
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.yearsBetween b)) == some 36
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 30); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 30); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.daysBetween b)) == some 13148
#guard (do let a ← (JLocalDate.ofYMD? 1990 10 30); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.yearsBetween b)) == some 35
#guard (do let a ← (JLocalDate.ofYMD? 2026 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.isBefore b, a.isAfter b)) == some (false, false)
#guard (do let a ← (JLocalDate.ofYMD? 2026 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.daysBetween b)) == some 0
#guard (do let a ← (JLocalDate.ofYMD? 2026 10 29); let b ← (JLocalDate.ofYMD? 2026 10 29); pure (a.yearsBetween b)) == some 0
#guard (do let a ← (JLocalDate.ofYMD? 1900 1 1); let b ← (JLocalDate.ofYMD? 2026 12 31); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 1900 1 1); let b ← (JLocalDate.ofYMD? 2026 12 31); pure (a.daysBetween b)) == some 46385
#guard (do let a ← (JLocalDate.ofYMD? 1900 1 1); let b ← (JLocalDate.ofYMD? 2026 12 31); pure (a.yearsBetween b)) == some 126
#guard (do let a ← (JLocalDate.ofYMD? 2026 11 1); let b ← (JLocalDate.ofYMD? 2027 3 1); pure (a.isBefore b, a.isAfter b)) == some (true, false)
#guard (do let a ← (JLocalDate.ofYMD? 2026 11 1); let b ← (JLocalDate.ofYMD? 2027 3 1); pure (a.daysBetween b)) == some 120
#guard (do let a ← (JLocalDate.ofYMD? 2026 11 1); let b ← (JLocalDate.ofYMD? 2027 3 1); pure (a.yearsBetween b)) == some 0
#guard (do let a ← (JLocalDate.ofYMD? 2027 3 1); let b ← (JLocalDate.ofYMD? 2026 11 1); pure (a.isBefore b, a.isAfter b)) == some (false, true)
#guard (do let a ← (JLocalDate.ofYMD? 2027 3 1); let b ← (JLocalDate.ofYMD? 2026 11 1); pure (a.daysBetween b)) == some (-120)

/-! ## double -/

-- リテラル（Double.parseDouble）
#guard (jdLit "0.01").toBits == 0x3F847AE147AE147B#64
#guard (jdLit "0.1").toBits == 0x3FB999999999999A#64
#guard (jdLit "0.7").toBits == 0x3FE6666666666666#64
#guard (jdLit "0.69").toBits == 0x3FE6147AE147AE14#64
#guard (jdLit "0.3").toBits == 0x3FD3333333333333#64
#guard (jdLit "1.4").toBits == 0x3FF6666666666666#64
#guard (jdLit "100.0").toBits == 0x4059000000000000#64
#guard (jdLit "0.0").toBits == 0x0000000000000000#64
#guard (jdLit "-0.0").toBits == 0x8000000000000000#64
#guard (jdLit "1430").toBits == 0x4096580000000000#64
#guard (jdLit "2.5").toBits == 0x4004000000000000#64
#guard (jdLit "-2.9").toBits == 0xC007333333333333#64
#guard (jdLit "123456789.123").toBits == 0x419D6F34547DF3B6#64
#guard (jdLit "0.0000001").toBits == 0x3E7AD7F29ABCAF48#64
-- (double) n
#guard (jd 0).toBits == 0x0000000000000000#64
#guard (jd 1).toBits == 0x3FF0000000000000#64
#guard (jd (-1)).toBits == 0xBFF0000000000000#64
#guard (jd 1430).toBits == 0x4096580000000000#64
#guard (jd 100000000).toBits == 0x4197D78400000000#64
#guard (jd 2147483647).toBits == 0x41DFFFFFFFC00000#64
#guard (jd (-2147483648)).toBits == 0xC1E0000000000000#64
#guard (jd 9007199254740993).toBits == 0x4340000000000000#64
-- * と - と (int)
#guard (jdmul (jdLit "1430") (jdLit "0.7")).toBits == 0x408F47FFFFFFFFFF#64
#guard (jdsub (jdLit "1430") (jdLit "0.7")).toBits == 0x4096553333333333#64
#guard (jdmul (jdLit "28800") (jdLit "0.69")).toBits == 0x40D3680000000000#64
#guard (jdsub (jdLit "28800") (jdLit "0.69")).toBits == 0x40DC1FD3D70A3D71#64
#guard (jdmul (jdLit "1.0") (jdLit "0.01")).toBits == 0x3F847AE147AE147B#64
#guard (jdsub (jdLit "1.0") (jdLit "0.01")).toBits == 0x3FEFAE147AE147AE#64
#guard (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))).toBits == 0x3FF0000000000000#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))))).val == 1430
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))))).val == 25000
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))))).val == 28800
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))))).val == 52400
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 0) (jdLit "0.01"))))).val == 100000000
#guard (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))).toBits == 0x3FEFAE147AE147AE#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))))).val == 1415
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))))).val == 24750
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))))).val == 28512
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))))).val == 51876
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 1) (jdLit "0.01"))))).val == 99000000
#guard (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))).toBits == 0x3FEE666666666666#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))))).val == 1358
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))))).val == 23750
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))))).val == 27360
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))))).val == 49780
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 5) (jdLit "0.01"))))).val == 95000000
#guard (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))).toBits == 0x3FECCCCCCCCCCCCD#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))))).val == 1287
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))))).val == 22500
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))))).val == 25920
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))))).val == 47160
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 10) (jdLit "0.01"))))).val == 90000000
#guard (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))).toBits == 0x3FE999999999999A#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))))).val == 1144
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))))).val == 20000
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))))).val == 23040
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))))).val == 41920
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 20) (jdLit "0.01"))))).val == 80000000
#guard (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))).toBits == 0x3FE6666666666666#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 1000
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 17500
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 20160
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 36680
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val == 70000000
#guard (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))).toBits == 0x3FE0000000000000#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))))).val == 715
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))))).val == 12500
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))))).val == 14400
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))))).val == 26200
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 50) (jdLit "0.01"))))).val == 50000000
#guard (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))).toBits == 0x3F847AE147AE1480#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))))).val == 14
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))))).val == 250
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))))).val == 288
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))))).val == 524
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 99) (jdLit "0.01"))))).val == 1000000
#guard (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))).toBits == 0x0000000000000000#64
#guard (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))))).val == 0
#guard (jd2i (jdmul (jd 25000) (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))))).val == 0
#guard (jd2i (jdmul (jd 28800) (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))))).val == 0
#guard (jd2i (jdmul (jd 52400) (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))))).val == 0
#guard (jd2i (jdmul (jd 100000000) (jdsub (jd 1) (jdmul (jd 100) (jdLit "0.01"))))).val == 0
#guard (jd2i (jdmul (jd 20100) (jdmul (jd 100) (jdLit "0.01")))).val == 20100
#guard (jd2i (jdmul (jd 25000) (jdmul (jd 100) (jdLit "0.01")))).val == 25000
#guard (jd2i (jdmul (jd 52400) (jdmul (jd 100) (jdLit "0.01")))).val == 52400
#guard (jd2i (jdmul (jd 57400) (jdmul (jd 100) (jdLit "0.01")))).val == 57400
#guard (jd2i (jdmul (jd 10000000) (jdmul (jd 100) (jdLit "0.01")))).val == 10000000
#guard (jd2i (jdmul (jd 20100) (jdmul (jd 125) (jdLit "0.01")))).val == 25125
#guard (jd2i (jdmul (jd 25000) (jdmul (jd 125) (jdLit "0.01")))).val == 31250
#guard (jd2i (jdmul (jd 52400) (jdmul (jd 125) (jdLit "0.01")))).val == 65500
#guard (jd2i (jdmul (jd 57400) (jdmul (jd 125) (jdLit "0.01")))).val == 71750
#guard (jd2i (jdmul (jd 10000000) (jdmul (jd 125) (jdLit "0.01")))).val == 12500000
#guard (jd2i (jdmul (jd 20100) (jdmul (jd 140) (jdLit "0.01")))).val == 28140
#guard (jd2i (jdmul (jd 25000) (jdmul (jd 140) (jdLit "0.01")))).val == 35000
#guard (jd2i (jdmul (jd 52400) (jdmul (jd 140) (jdLit "0.01")))).val == 73360
#guard (jd2i (jdmul (jd 57400) (jdmul (jd 140) (jdLit "0.01")))).val == 80360
#guard (jd2i (jdmul (jd 10000000) (jdmul (jd 140) (jdLit "0.01")))).val == 14000000
#guard (jd2i (jdmul (jd 20100) (jdmul (jd 1000) (jdLit "0.01")))).val == 201000
#guard (jd2i (jdmul (jd 25000) (jdmul (jd 1000) (jdLit "0.01")))).val == 250000
#guard (jd2i (jdmul (jd 52400) (jdmul (jd 1000) (jdLit "0.01")))).val == 524000
#guard (jd2i (jdmul (jd 57400) (jdmul (jd 1000) (jdLit "0.01")))).val == 574000
#guard (jd2i (jdmul (jd 10000000) (jdmul (jd 1000) (jdLit "0.01")))).val == 100000000
-- 特殊値: NaN・±∞・飽和・0 方向切捨て
#guard (jdmul (.inf false) (jd 0)).toBits == 0x7FF8000000000000#64
#guard (jdsub (.inf false) (.inf false)).toBits == 0x7FF8000000000000#64
#guard (jdmul (jdLit "-1.0") (.inf false)).toBits == 0xFFF0000000000000#64
#guard (jd2i .nan).val == 0
#guard (jd2i (.inf false)).val == 2147483647
#guard (jd2i (.inf true)).val == -2147483648
#guard (jd2i (jdLit "2.9")).val == 2
#guard (jd2i (jdLit "-2.9")).val == (-2)
#guard (jd2i (jdLit "0.5")).val == 0
#guard (jd2i (jdLit "-0.5")).val == 0
#guard (jd2i (jdLit "2147483647.5")).val == 2147483647
#guard (jd2i (jdLit "2147483648.0")).val == 2147483647
#guard (jd2i (jdLit "-2147483649.0")).val == (-2147483648)
#guard (jd2i (jdmul (jd 100000) (jd 100000))).val == 2147483647
