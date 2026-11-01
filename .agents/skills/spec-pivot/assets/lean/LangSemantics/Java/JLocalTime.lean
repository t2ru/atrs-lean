import LangSemantics.Java.Exception
import LangSemantics.Java.JLocalDate

/-!
# LangSemantics.Java.JLocalTime

`java.time.LocalTime` の、分の精度の最小の写し（秒・ナノ秒は 0 とする）。
- `JLocalTime.parseHHmm s`: `LocalTime.from(DateTimeFormatter.ofPattern("HHmm").parse(s))`。解決は既定の
  `ResolverStyle.SMART` で、`HH` は 2 桁の数字、`mm` は 2 桁の数字、全体がちょうど 4 文字でなければ
  `DateTimeParseException`。`HH` が 0〜23 で `mm` が 0〜59 ならその時刻。`HH = 24` かつ `mm = 0` は
  0:00（翌日に繰り越す 1 日は `LocalTime.from` が捨てる）。それ以外の `HH = 24`、`HH ≥ 25`、`mm ≥ 60` は
  `DateTimeParseException`（SMART の範囲検査）。数字は ASCII の `0`〜`9` に限る（既定の `DecimalStyle`）。
- 日時は `LangSemantics.Java.JLocalDateTime`。

lang: `dep:java.base#java.time.LocalTime`,
`dep:java.base#java.time.format.DateTimeFormatter`, `dep:java.base#java.time.format.ResolverStyle.SMART`
-/

namespace LangSemantics.Java
open LangSemantics.Java.Exception

/-- 時刻（時・分。秒は 0）。 -/
structure JLocalTime where
  hour : Nat
  minute : Nat
  deriving Repr, BEq, DecidableEq

namespace JLocalTime

/-- `DateTimeParseException` のクラス名。 -/
def parseExceptionClass : String := "java.time.format.DateTimeParseException"

/-- ASCII の数字の値。 -/
def asciiDigit? (c : Char) : Option Nat := if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat) else none

/-- `LocalTime.from(DateTimeFormatter.ofPattern("HHmm").parse(s))`（`ResolverStyle.SMART`）。 -/
def parseHHmm (s : String) : JResult JLocalTime :=
  let err : JResult JLocalTime := .error (.other parseExceptionClass s!"Text '{s}' could not be parsed")
  match s.toList with
  | [a, b, c, d] =>
    match asciiDigit? a, asciiDigit? b, asciiDigit? c, asciiDigit? d with
    | some a, some b, some c, some d =>
      let h := a * 10 + b
      let m := c * 10 + d
      if m ≥ 60 then err
      else if h ≤ 23 then .ok ⟨h, m⟩
      else if h = 24 ∧ m = 0 then .ok ⟨0, 0⟩
      else err
    | _, _, _, _ => err
  | _ => err

/-- 0:00 からの分数。 -/
def toMinuteOfDay (t : JLocalTime) : Nat := t.hour * 60 + t.minute

end JLocalTime

end LangSemantics.Java
