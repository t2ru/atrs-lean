import LangSemantics.Java.Exception
import LangSemantics.Java.JLocalDate
import LangSemantics.Java.JLocalTime

/-!
# LangSemantics.Java.JLocalDateTime

`java.time.LocalDateTime` の、分の精度の最小の写し（秒・ナノ秒は 0 とする）。暦日と時・分で、比較と分の加算は
通算の分（1970-01-01 0:00 を 0）を介して行う。値域（`LocalDateTime` の年の範囲）を超える加算の `DateTimeException` は
写さない（使う側の値域で除く）。`localDate.atTime(t)`・`localDate.atStartOfDay()` は、この名前空間の
`JLocalDateTime.atTime d t`・`JLocalDateTime.atStartOfDay d` とする（宣言をモジュール名の下に置くため）。

lang: `dep:java.base#java.time.LocalDateTime`
-/

namespace LangSemantics.Java

/-- 日時（暦日と時刻。秒は 0）。 -/
structure JLocalDateTime where
  date : JLocalDate
  time : JLocalTime
  deriving Repr, BEq, DecidableEq

namespace JLocalDateTime

/-- 時。 -/
def hour (x : JLocalDateTime) : Nat := x.time.hour

/-- 分。 -/
def minute (x : JLocalDateTime) : Nat := x.time.minute

/-- `localDate.atTime(localTime)`。 -/
def atTime (d : JLocalDate) (t : JLocalTime) : JLocalDateTime := ⟨d, t⟩

/-- `localDate.atStartOfDay()`。 -/
def atStartOfDay (d : JLocalDate) : JLocalDateTime := ⟨d, ⟨0, 0, by decide⟩⟩

/-- 通算の分（1970-01-01 0:00 を 0）。 -/
def toEpochMinute (x : JLocalDateTime) : Int := x.date.toEpochDay * 1440 + (x.hour * 60 + x.minute : Nat)

/-- 通算の分から日時へ。 -/
def ofEpochMinute (n : Int) : JLocalDateTime :=
  let r := (n % 1440).toNat
  have hr : r < 1440 := by
    have := Int.emod_lt_of_pos n (by decide : (0 : Int) < 1440)
    have := Int.emod_nonneg n (by decide : (1440 : Int) ≠ 0)
    omega
  ⟨JLocalDate.ofEpochDay (n / 1440), ⟨r / 60, r % 60, by omega, Nat.mod_lt _ (by decide)⟩⟩

/-- `plusMinutes(n)`。 -/
def plusMinutes (x : JLocalDateTime) (n : Int) : JLocalDateTime := ofEpochMinute (x.toEpochMinute + n)

/-- `isBefore(other)`。 -/
def isBefore (a b : JLocalDateTime) : Bool := a.toEpochMinute < b.toEpochMinute

end JLocalDateTime

end LangSemantics.Java
