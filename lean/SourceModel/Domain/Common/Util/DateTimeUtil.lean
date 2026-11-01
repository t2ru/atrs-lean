import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Common.Util.DateTimeUtil

原典の `jp.co.ntt.atrs.domain.common.util.DateTimeUtil`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/util/DateTimeUtil.java`）の写し。
-/

namespace SourceModel.Domain.Common.Util
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Common.Util

namespace DateTimeUtil

/-- `toFormatTimeString(timeString)`: 長さが 2 より大きければ `String.format("%s:%s", s.substring(0, 2), s.substring(2))`。
`%s` に非 `null` の文字列を渡す `String.format` は、連結と同じである。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatTimeString(String)@45ff7b872987b979",
  "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.TIME_FORMATTER@b3ea6e972e16ec6a",
  "lang:java#java.lang.String.format@java-17"]
def toFormatTimeString (timeString : JRef String) : JResult (JRef String) := do
  match timeString with
  | some s =>
    if 2 < utf16Len s then
      let a ← jSubstring s 0 2
      let b ← jSubstringFrom s 2
      return some (a ++ ":" ++ b)
    else return some s
  | none => return none

/-- `toFormatDateString(localDate)`: `null` なら空文字列、それ以外は `yyyy/MM/dd`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatDateString(LocalDate)@a9c17cb275f550f1",
  "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.DATE_FORMATTER@6231e4eebda71cf4"]
def toFormatDateString (localDate : JRef JLocalDate) : String :=
  match localDate with
  | some d => d.formatYMD "/"
  | none => ""

/-- `toLocalTime(timeString)`: `LocalTime.from(TIME_FORMATTER.parse(timeString))`（`HHmm`、SMART）。`null` なら
`NullPointerException`。到着時刻 `2415` などの 24:00 より後の時刻は `DateTimeParseException`、`2400` は 0:00（既知差異 D-031）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toLocalTime(String)@f681e7086ea22011",
  "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.TIME_FORMATTER@b3ea6e972e16ec6a",
  "lang:java#java.time.format.DateTimeFormatter@java-17", gap "D-031"]
def toLocalTime (timeString : JRef String) : JResult JLocalTime := do
  let s ← timeString.deref "text"
  JLocalTime.parseHHmm s

/-- `toLocalDateTime(localDate, timeString)`: `localDate.atTime(toLocalTime(timeString))`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toLocalDateTime(LocalDate,String)@77b0547624f167eb", gap "D-031"]
def toLocalDateTime (localDate : JRef JLocalDate) (timeString : JRef String) : JResult JLocalDateTime := do
  let t ← toLocalTime timeString
  let d ← localDate.deref "localDate"
  return JLocalDateTime.atTime d t

end DateTimeUtil

end SourceModel.Domain.Common.Util
