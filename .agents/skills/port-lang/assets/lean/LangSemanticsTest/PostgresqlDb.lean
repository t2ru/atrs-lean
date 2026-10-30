import LangSemantics.Sql.Postgresql

/-!
# LangSemanticsTest.PostgresqlDb

**生成物（手で編集しない）。** `LangSemanticsTest/pg/pg_table.py` が PostgreSQL（照合順序 C・UTF8・UTC）で
計算した値と、`LangSemantics.Sql`・`LangSemantics.Sql.Postgresql` の結果を突き合わせる。
再生成: `python3 -I LangSemanticsTest/pg/pg_table.py > LangSemanticsTest/PostgresqlDb.lean`
-/

namespace LangSemanticsTest.PostgresqlDb

open LangSemantics.Sql LangSemantics.Sql.Postgresql

def coll := collationC

/-- `NEXTVAL` を n 回呼んだ値の列。 -/
def nextvals (s : SequenceDef) : Nat → SqlResult (List Int)
  | 0 => .ok []
  | n + 1 => go s none (n + 1)
where go (s : SequenceDef) (st : SequenceState) : Nat → SqlResult (List Int)
  | 0 => .ok []
  | k + 1 => do let (v, st') ← nextval s st; let vs ← go s st' k; pure (v :: vs)

/-! ## 三値論理 -/

#guard Truth.not .true == .false
#guard Truth.and .true .true == .true
#guard Truth.or .true .true == .true
#guard Truth.and .true .false == .false
#guard Truth.or .true .false == .true
#guard Truth.and .true .unknown == .unknown
#guard Truth.or .true .unknown == .true
#guard Truth.not .false == .true
#guard Truth.and .false .true == .false
#guard Truth.or .false .true == .true
#guard Truth.and .false .false == .false
#guard Truth.or .false .false == .false
#guard Truth.and .false .unknown == .false
#guard Truth.or .false .unknown == .unknown
#guard Truth.not .unknown == .unknown
#guard Truth.and .unknown .true == .unknown
#guard Truth.or .unknown .true == .true
#guard Truth.and .unknown .false == .false
#guard Truth.or .unknown .false == .unknown
#guard Truth.and .unknown .unknown == .unknown
#guard Truth.or .unknown .unknown == .unknown

/-! ## 比較・BETWEEN・IN・IS NULL（照合順序 C） -/

#guard SqlValue.eq coll (.int 1) (.int 1) == .true
#guard SqlValue.lt coll (.int 1) (.int 1) == .false
#guard SqlValue.le coll (.int 1) (.int 1) == .true
#guard SqlValue.eq coll (.int 1) (.int 2) == .false
#guard SqlValue.lt coll (.int 1) (.int 2) == .true
#guard SqlValue.le coll (.int 1) (.int 2) == .true
#guard SqlValue.eq coll (.int 1) (.int (-5)) == .false
#guard SqlValue.lt coll (.int 1) (.int (-5)) == .false
#guard SqlValue.le coll (.int 1) (.int (-5)) == .false
#guard SqlValue.eq coll (.int 1) .null == .unknown
#guard SqlValue.lt coll (.int 1) .null == .unknown
#guard SqlValue.le coll (.int 1) .null == .unknown
#guard SqlValue.eq coll (.int 2) (.int 1) == .false
#guard SqlValue.lt coll (.int 2) (.int 1) == .false
#guard SqlValue.le coll (.int 2) (.int 1) == .false
#guard SqlValue.eq coll (.int 2) (.int 2) == .true
#guard SqlValue.lt coll (.int 2) (.int 2) == .false
#guard SqlValue.le coll (.int 2) (.int 2) == .true
#guard SqlValue.eq coll (.int 2) (.int (-5)) == .false
#guard SqlValue.lt coll (.int 2) (.int (-5)) == .false
#guard SqlValue.le coll (.int 2) (.int (-5)) == .false
#guard SqlValue.eq coll (.int 2) .null == .unknown
#guard SqlValue.lt coll (.int 2) .null == .unknown
#guard SqlValue.le coll (.int 2) .null == .unknown
#guard SqlValue.eq coll (.int (-5)) (.int 1) == .false
#guard SqlValue.lt coll (.int (-5)) (.int 1) == .true
#guard SqlValue.le coll (.int (-5)) (.int 1) == .true
#guard SqlValue.eq coll (.int (-5)) (.int 2) == .false
#guard SqlValue.lt coll (.int (-5)) (.int 2) == .true
#guard SqlValue.le coll (.int (-5)) (.int 2) == .true
#guard SqlValue.eq coll (.int (-5)) (.int (-5)) == .true
#guard SqlValue.lt coll (.int (-5)) (.int (-5)) == .false
#guard SqlValue.le coll (.int (-5)) (.int (-5)) == .true
#guard SqlValue.eq coll (.int (-5)) .null == .unknown
#guard SqlValue.lt coll (.int (-5)) .null == .unknown
#guard SqlValue.le coll (.int (-5)) .null == .unknown
#guard SqlValue.eq coll .null (.int 1) == .unknown
#guard SqlValue.lt coll .null (.int 1) == .unknown
#guard SqlValue.le coll .null (.int 1) == .unknown
#guard SqlValue.eq coll .null (.int 2) == .unknown
#guard SqlValue.lt coll .null (.int 2) == .unknown
#guard SqlValue.le coll .null (.int 2) == .unknown
#guard SqlValue.eq coll .null (.int (-5)) == .unknown
#guard SqlValue.lt coll .null (.int (-5)) == .unknown
#guard SqlValue.le coll .null (.int (-5)) == .unknown
#guard SqlValue.eq coll .null .null == .unknown
#guard SqlValue.lt coll .null .null == .unknown
#guard SqlValue.le coll .null .null == .unknown
#guard SqlValue.eq coll .null (.text "a") == .unknown
#guard SqlValue.lt coll .null (.text "a") == .unknown
#guard SqlValue.le coll .null (.text "a") == .unknown
#guard SqlValue.eq coll .null (.text "B") == .unknown
#guard SqlValue.lt coll .null (.text "B") == .unknown
#guard SqlValue.le coll .null (.text "B") == .unknown
#guard SqlValue.eq coll .null (.text "ab") == .unknown
#guard SqlValue.lt coll .null (.text "ab") == .unknown
#guard SqlValue.le coll .null (.text "ab") == .unknown
#guard SqlValue.eq coll .null (.text "") == .unknown
#guard SqlValue.lt coll .null (.text "") == .unknown
#guard SqlValue.le coll .null (.text "") == .unknown
#guard SqlValue.eq coll .null (.text "あ") == .unknown
#guard SqlValue.lt coll .null (.text "あ") == .unknown
#guard SqlValue.le coll .null (.text "あ") == .unknown
#guard SqlValue.eq coll .null (.text "𠮷") == .unknown
#guard SqlValue.lt coll .null (.text "𠮷") == .unknown
#guard SqlValue.le coll .null (.text "𠮷") == .unknown
#guard SqlValue.eq coll .null (.bool true) == .unknown
#guard SqlValue.lt coll .null (.bool true) == .unknown
#guard SqlValue.le coll .null (.bool true) == .unknown
#guard SqlValue.eq coll .null (.bool false) == .unknown
#guard SqlValue.lt coll .null (.bool false) == .unknown
#guard SqlValue.le coll .null (.bool false) == .unknown
#guard SqlValue.eq coll (.text "a") .null == .unknown
#guard SqlValue.lt coll (.text "a") .null == .unknown
#guard SqlValue.le coll (.text "a") .null == .unknown
#guard SqlValue.eq coll (.text "a") (.text "a") == .true
#guard SqlValue.lt coll (.text "a") (.text "a") == .false
#guard SqlValue.le coll (.text "a") (.text "a") == .true
#guard SqlValue.eq coll (.text "a") (.text "B") == .false
#guard SqlValue.lt coll (.text "a") (.text "B") == .false
#guard SqlValue.le coll (.text "a") (.text "B") == .false
#guard SqlValue.eq coll (.text "a") (.text "ab") == .false
#guard SqlValue.lt coll (.text "a") (.text "ab") == .true
#guard SqlValue.le coll (.text "a") (.text "ab") == .true
#guard SqlValue.eq coll (.text "a") (.text "") == .false
#guard SqlValue.lt coll (.text "a") (.text "") == .false
#guard SqlValue.le coll (.text "a") (.text "") == .false
#guard SqlValue.eq coll (.text "a") (.text "あ") == .false
#guard SqlValue.lt coll (.text "a") (.text "あ") == .true
#guard SqlValue.le coll (.text "a") (.text "あ") == .true
#guard SqlValue.eq coll (.text "a") (.text "𠮷") == .false
#guard SqlValue.lt coll (.text "a") (.text "𠮷") == .true
#guard SqlValue.le coll (.text "a") (.text "𠮷") == .true
#guard SqlValue.eq coll (.text "B") .null == .unknown
#guard SqlValue.lt coll (.text "B") .null == .unknown
#guard SqlValue.le coll (.text "B") .null == .unknown
#guard SqlValue.eq coll (.text "B") (.text "a") == .false
#guard SqlValue.lt coll (.text "B") (.text "a") == .true
#guard SqlValue.le coll (.text "B") (.text "a") == .true
#guard SqlValue.eq coll (.text "B") (.text "B") == .true
#guard SqlValue.lt coll (.text "B") (.text "B") == .false
#guard SqlValue.le coll (.text "B") (.text "B") == .true
#guard SqlValue.eq coll (.text "B") (.text "ab") == .false
#guard SqlValue.lt coll (.text "B") (.text "ab") == .true
#guard SqlValue.le coll (.text "B") (.text "ab") == .true
#guard SqlValue.eq coll (.text "B") (.text "") == .false
#guard SqlValue.lt coll (.text "B") (.text "") == .false
#guard SqlValue.le coll (.text "B") (.text "") == .false
#guard SqlValue.eq coll (.text "B") (.text "あ") == .false
#guard SqlValue.lt coll (.text "B") (.text "あ") == .true
#guard SqlValue.le coll (.text "B") (.text "あ") == .true
#guard SqlValue.eq coll (.text "B") (.text "𠮷") == .false
#guard SqlValue.lt coll (.text "B") (.text "𠮷") == .true
#guard SqlValue.le coll (.text "B") (.text "𠮷") == .true
#guard SqlValue.eq coll (.text "ab") .null == .unknown
#guard SqlValue.lt coll (.text "ab") .null == .unknown
#guard SqlValue.le coll (.text "ab") .null == .unknown
#guard SqlValue.eq coll (.text "ab") (.text "a") == .false
#guard SqlValue.lt coll (.text "ab") (.text "a") == .false
#guard SqlValue.le coll (.text "ab") (.text "a") == .false
#guard SqlValue.eq coll (.text "ab") (.text "B") == .false
#guard SqlValue.lt coll (.text "ab") (.text "B") == .false
#guard SqlValue.le coll (.text "ab") (.text "B") == .false
#guard SqlValue.eq coll (.text "ab") (.text "ab") == .true
#guard SqlValue.lt coll (.text "ab") (.text "ab") == .false
#guard SqlValue.le coll (.text "ab") (.text "ab") == .true
#guard SqlValue.eq coll (.text "ab") (.text "") == .false
#guard SqlValue.lt coll (.text "ab") (.text "") == .false
#guard SqlValue.le coll (.text "ab") (.text "") == .false
#guard SqlValue.eq coll (.text "ab") (.text "あ") == .false
#guard SqlValue.lt coll (.text "ab") (.text "あ") == .true
#guard SqlValue.le coll (.text "ab") (.text "あ") == .true
#guard SqlValue.eq coll (.text "ab") (.text "𠮷") == .false
#guard SqlValue.lt coll (.text "ab") (.text "𠮷") == .true
#guard SqlValue.le coll (.text "ab") (.text "𠮷") == .true
#guard SqlValue.eq coll (.text "") .null == .unknown
#guard SqlValue.lt coll (.text "") .null == .unknown
#guard SqlValue.le coll (.text "") .null == .unknown
#guard SqlValue.eq coll (.text "") (.text "a") == .false
#guard SqlValue.lt coll (.text "") (.text "a") == .true
#guard SqlValue.le coll (.text "") (.text "a") == .true
#guard SqlValue.eq coll (.text "") (.text "B") == .false
#guard SqlValue.lt coll (.text "") (.text "B") == .true
#guard SqlValue.le coll (.text "") (.text "B") == .true
#guard SqlValue.eq coll (.text "") (.text "ab") == .false
#guard SqlValue.lt coll (.text "") (.text "ab") == .true
#guard SqlValue.le coll (.text "") (.text "ab") == .true
#guard SqlValue.eq coll (.text "") (.text "") == .true
#guard SqlValue.lt coll (.text "") (.text "") == .false
#guard SqlValue.le coll (.text "") (.text "") == .true
#guard SqlValue.eq coll (.text "") (.text "あ") == .false
#guard SqlValue.lt coll (.text "") (.text "あ") == .true
#guard SqlValue.le coll (.text "") (.text "あ") == .true
#guard SqlValue.eq coll (.text "") (.text "𠮷") == .false
#guard SqlValue.lt coll (.text "") (.text "𠮷") == .true
#guard SqlValue.le coll (.text "") (.text "𠮷") == .true
#guard SqlValue.eq coll (.text "あ") .null == .unknown
#guard SqlValue.lt coll (.text "あ") .null == .unknown
#guard SqlValue.le coll (.text "あ") .null == .unknown
#guard SqlValue.eq coll (.text "あ") (.text "a") == .false
#guard SqlValue.lt coll (.text "あ") (.text "a") == .false
#guard SqlValue.le coll (.text "あ") (.text "a") == .false
#guard SqlValue.eq coll (.text "あ") (.text "B") == .false
#guard SqlValue.lt coll (.text "あ") (.text "B") == .false
#guard SqlValue.le coll (.text "あ") (.text "B") == .false
#guard SqlValue.eq coll (.text "あ") (.text "ab") == .false
#guard SqlValue.lt coll (.text "あ") (.text "ab") == .false
#guard SqlValue.le coll (.text "あ") (.text "ab") == .false
#guard SqlValue.eq coll (.text "あ") (.text "") == .false
#guard SqlValue.lt coll (.text "あ") (.text "") == .false
#guard SqlValue.le coll (.text "あ") (.text "") == .false
#guard SqlValue.eq coll (.text "あ") (.text "あ") == .true
#guard SqlValue.lt coll (.text "あ") (.text "あ") == .false
#guard SqlValue.le coll (.text "あ") (.text "あ") == .true
#guard SqlValue.eq coll (.text "あ") (.text "𠮷") == .false
#guard SqlValue.lt coll (.text "あ") (.text "𠮷") == .true
#guard SqlValue.le coll (.text "あ") (.text "𠮷") == .true
#guard SqlValue.eq coll (.text "𠮷") .null == .unknown
#guard SqlValue.lt coll (.text "𠮷") .null == .unknown
#guard SqlValue.le coll (.text "𠮷") .null == .unknown
#guard SqlValue.eq coll (.text "𠮷") (.text "a") == .false
#guard SqlValue.lt coll (.text "𠮷") (.text "a") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "a") == .false
#guard SqlValue.eq coll (.text "𠮷") (.text "B") == .false
#guard SqlValue.lt coll (.text "𠮷") (.text "B") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "B") == .false
#guard SqlValue.eq coll (.text "𠮷") (.text "ab") == .false
#guard SqlValue.lt coll (.text "𠮷") (.text "ab") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "ab") == .false
#guard SqlValue.eq coll (.text "𠮷") (.text "") == .false
#guard SqlValue.lt coll (.text "𠮷") (.text "") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "") == .false
#guard SqlValue.eq coll (.text "𠮷") (.text "あ") == .false
#guard SqlValue.lt coll (.text "𠮷") (.text "あ") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "あ") == .false
#guard SqlValue.eq coll (.text "𠮷") (.text "𠮷") == .true
#guard SqlValue.lt coll (.text "𠮷") (.text "𠮷") == .false
#guard SqlValue.le coll (.text "𠮷") (.text "𠮷") == .true
#guard SqlValue.eq coll (.bool true) .null == .unknown
#guard SqlValue.lt coll (.bool true) .null == .unknown
#guard SqlValue.le coll (.bool true) .null == .unknown
#guard SqlValue.eq coll (.bool true) (.bool true) == .true
#guard SqlValue.lt coll (.bool true) (.bool true) == .false
#guard SqlValue.le coll (.bool true) (.bool true) == .true
#guard SqlValue.eq coll (.bool true) (.bool false) == .false
#guard SqlValue.lt coll (.bool true) (.bool false) == .false
#guard SqlValue.le coll (.bool true) (.bool false) == .false
#guard SqlValue.eq coll (.bool false) .null == .unknown
#guard SqlValue.lt coll (.bool false) .null == .unknown
#guard SqlValue.le coll (.bool false) .null == .unknown
#guard SqlValue.eq coll (.bool false) (.bool true) == .false
#guard SqlValue.lt coll (.bool false) (.bool true) == .true
#guard SqlValue.le coll (.bool false) (.bool true) == .true
#guard SqlValue.eq coll (.bool false) (.bool false) == .true
#guard SqlValue.lt coll (.bool false) (.bool false) == .false
#guard SqlValue.le coll (.bool false) (.bool false) == .true
#guard between coll (.int 5) (.int 1) (.int 10) == .true
#guard between coll (.int 1) (.int 1) (.int 10) == .true
#guard between coll (.int 10) (.int 1) (.int 10) == .true
#guard between coll (.int 0) (.int 1) (.int 10) == .false
#guard between coll (.int 11) (.int 1) (.int 10) == .false
#guard between coll (.int 5) (.int 10) (.int 1) == .false
#guard between coll .null (.int 1) (.int 10) == .unknown
#guard between coll (.int 5) .null (.int 10) == .unknown
#guard between coll (.int 0) .null (.int 10) == .unknown
#guard between coll (.text "b") (.text "a") (.text "c") == .true
#guard between coll (.text "B") (.text "a") (.text "c") == .false
#guard inList coll (.int 1) [(.int 1), (.int 2)] == .true
#guard inList coll (.int 3) [(.int 1), (.int 2)] == .false
#guard inList coll (.int 3) [(.int 1), .null] == .unknown
#guard inList coll (.int 1) [(.int 1), .null] == .true
#guard inList coll .null [(.int 1)] == .unknown
#guard inList coll (.text "a") [(.text "A"), (.text "a")] == .true
#guard isNull (.int 1) == .false
#guard isNull .null == .true
#guard isNull (.text "") == .false

/-! ## ORDER BY（同順位・NULL の位置・照合順序 C） -/

def rows : List (Nat × SqlValue × SqlValue) := [(1, (.int 2), (.text "b")), (2, .null, (.text "a")), (3, (.int 1), (.text "c")), (4, (.int 2), (.text "a")), (5, .null, .null), (6, (.int 2), (.text "b")), (7, (.int (-1)), (.text "B"))]
def byId (ids : List Nat) : List (Nat × SqlValue × SqlValue) := ids.filterMap fun i => rows.find? (·.1 == i)
-- ORDER BY k1
#guard isAllowedOrder (sortConfig) [.asc] (fun r => [r.2.1]) rows (byId [7, 3, 4, 1, 6, 2, 5])
-- ORDER BY k1 DESC
#guard isAllowedOrder (sortConfig) [.desc] (fun r => [r.2.1]) rows (byId [5, 2, 4, 1, 6, 3, 7])
-- ORDER BY k2
#guard isAllowedOrder (sortConfig) [.asc] (fun r => [r.2.2]) rows (byId [7, 2, 4, 1, 6, 3, 5])
-- ORDER BY k2 DESC
#guard isAllowedOrder (sortConfig) [.desc] (fun r => [r.2.2]) rows (byId [5, 3, 6, 1, 4, 2, 7])
-- ORDER BY k1, k2
#guard isAllowedOrder (sortConfig) [.asc, .asc] (fun r => [r.2.1, r.2.2]) rows (byId [7, 3, 4, 1, 6, 2, 5])
-- ORDER BY k1 DESC, k2
#guard isAllowedOrder (sortConfig) [.desc, .asc] (fun r => [r.2.1, r.2.2]) rows (byId [2, 5, 4, 1, 6, 3, 7])
-- ORDER BY k1, k2 DESC, id
#guard isAllowedOrder (sortConfig) [.asc, .desc, .asc] (fun r => [r.2.1, r.2.2, .int r.1]) rows (byId [7, 3, 1, 6, 4, 5, 2])
#guard orderByStable (sortConfig) [.asc, .desc, .asc] (fun r => [r.2.1, r.2.2, .int r.1]) rows == byId [7, 3, 1, 6, 4, 5, 2]
-- 照合順序 C（データベースの既定）
#guard orderByStable (sortConfig) [.asc] (fun s => [.text s]) ["b", "B", "a", "A", "", "ab", "aB", "あ", "ア", "亜", "𠮷", "_", "1", " ", "z", "Ａ"] == ["", " ", "1", "A", "B", "_", "a", "aB", "ab", "b", "z", "あ", "ア", "亜", "Ａ", "𠮷"]

/-! ## TO_CHAR（FM と 0・9 の書式） -/

#guard toChar 0 "FM0999999999" == some "0000000000"
#guard toChar 5 "FM0999999999" == some "0000000005"
#guard toChar 42 "FM0999999999" == some "0000000042"
#guard toChar 123 "FM0999999999" == some "0000000123"
#guard toChar 9999 "FM0999999999" == some "0000009999"
#guard toChar 12345 "FM0999999999" == some "0000012345"
#guard toChar 9999999999 "FM0999999999" == some "9999999999"
#guard toChar 12345678901 "FM0999999999" == some "##########"
#guard toChar (-42) "FM0999999999" == some "-0000000042"
#guard toChar (-12345) "FM0999999999" == some "-0000012345"
#guard toChar 1000000 "FM0999999999" == some "0001000000"
#guard toChar 0 "FM9999" == some "0"
#guard toChar 5 "FM9999" == some "5"
#guard toChar 42 "FM9999" == some "42"
#guard toChar 123 "FM9999" == some "123"
#guard toChar 9999 "FM9999" == some "9999"
#guard toChar 12345 "FM9999" == some "####"
#guard toChar 9999999999 "FM9999" == some "####"
#guard toChar 12345678901 "FM9999" == some "####"
#guard toChar (-42) "FM9999" == some "-42"
#guard toChar (-12345) "FM9999" == some "-####"
#guard toChar 1000000 "FM9999" == some "####"
#guard toChar 0 "FM9909" == some "00"
#guard toChar 5 "FM9909" == some "05"
#guard toChar 42 "FM9909" == some "42"
#guard toChar 123 "FM9909" == some "123"
#guard toChar 9999 "FM9909" == some "9999"
#guard toChar 12345 "FM9909" == some "####"
#guard toChar 9999999999 "FM9909" == some "####"
#guard toChar 12345678901 "FM9909" == some "####"
#guard toChar (-42) "FM9909" == some "-42"
#guard toChar (-12345) "FM9909" == some "-####"
#guard toChar 1000000 "FM9909" == some "####"
#guard toChar 0 "FM0999" == some "0000"
#guard toChar 5 "FM0999" == some "0005"
#guard toChar 42 "FM0999" == some "0042"
#guard toChar 123 "FM0999" == some "0123"
#guard toChar 9999 "FM0999" == some "9999"
#guard toChar 12345 "FM0999" == some "####"
#guard toChar 9999999999 "FM0999" == some "####"
#guard toChar 12345678901 "FM0999" == some "####"
#guard toChar (-42) "FM0999" == some "-0042"
#guard toChar (-12345) "FM0999" == some "-####"
#guard toChar 1000000 "FM0999" == some "####"
#guard toChar 0 "FM00" == some "00"
#guard toChar 5 "FM00" == some "05"
#guard toChar 42 "FM00" == some "42"
#guard toChar 123 "FM00" == some "##"
#guard toChar 9999 "FM00" == some "##"
#guard toChar 12345 "FM00" == some "##"
#guard toChar 9999999999 "FM00" == some "##"
#guard toChar 12345678901 "FM00" == some "##"
#guard toChar (-42) "FM00" == some "-42"
#guard toChar (-12345) "FM00" == some "-##"
#guard toChar 1000000 "FM00" == some "##"
#guard toChar 0 "FM9" == some "0"
#guard toChar 5 "FM9" == some "5"
#guard toChar 42 "FM9" == some "#"
#guard toChar 123 "FM9" == some "#"
#guard toChar 9999 "FM9" == some "#"
#guard toChar 12345 "FM9" == some "#"
#guard toChar 9999999999 "FM9" == some "#"
#guard toChar 12345678901 "FM9" == some "#"
#guard toChar (-42) "FM9" == some "-#"
#guard toChar (-12345) "FM9" == some "-#"
#guard toChar 1000000 "FM9" == some "#"
#guard toChar 0 "FM999990" == some "0"
#guard toChar 5 "FM999990" == some "5"
#guard toChar 42 "FM999990" == some "42"
#guard toChar 123 "FM999990" == some "123"
#guard toChar 9999 "FM999990" == some "9999"
#guard toChar 12345 "FM999990" == some "12345"
#guard toChar 9999999999 "FM999990" == some "######"
#guard toChar 12345678901 "FM999990" == some "######"
#guard toChar (-42) "FM999990" == some "-42"
#guard toChar (-12345) "FM999990" == some "-12345"
#guard toChar 1000000 "FM999990" == some "######"

/-! ## 整数型の範囲 -/

#guard int2 32767 matches .ok _
#guard int2 32768 matches .error .numericOutOfRange
#guard int2 (-32768) matches .ok _
#guard int2 (-32769) matches .error .numericOutOfRange
#guard int4 2147483647 matches .ok _
#guard int4 2147483648 matches .error .numericOutOfRange
#guard int4 (-2147483648) matches .ok _
#guard int4 (-2147483649) matches .error .numericOutOfRange
#guard int8 9223372036854775807 matches .ok _
#guard int8 9223372036854775808 matches .error .numericOutOfRange
#guard int8 (-9223372036854775808) matches .ok _
#guard int8 (-9223372036854775809) matches .error .numericOutOfRange
#guard int4 (2147483647 + 1) matches .error .numericOutOfRange
#guard int4 (2147483646 + 1) matches .ok _
#guard int4 ((-2147483648) + (-1)) matches .error .numericOutOfRange

/-! ## VARCHAR(n) への格納 -/

#guard (varchar "c" 3 "abc").toOption == some "abc"
#guard varchar "c" 2 "abc" matches .error (.stringTooLong _)
#guard (varchar "c" 3 "𠮷𠮷𠮷").toOption == some "𠮷𠮷𠮷"
#guard varchar "c" 2 "𠮷𠮷𠮷" matches .error (.stringTooLong _)
#guard (varchar "c" 2 "ab ").toOption == some "ab"
#guard (varchar "c" 2 "ab  ").toOption == some "ab"
#guard varchar "c" 2 "a b" matches .error (.stringTooLong _)
#guard varchar "c" 2 " ab" matches .error (.stringTooLong _)
#guard (varchar "c" 5 "あいうえお").toOption == some "あいうえお"
#guard varchar "c" 4 "あいうえお" matches .error (.stringTooLong _)

/-! ## シーケンス -/

#guard (nextvals ({ name := "s", maxValue := 3, cycle := true } : SequenceDef) 5).toOption == some [1, 2, 3, 1, 2]
#guard (nextvals ({ name := "s", maxValue := 3 } : SequenceDef) 3).isOk && (nextvals ({ name := "s", maxValue := 3 } : SequenceDef) 4) matches .error (.sequenceExhausted _)
#guard (nextvals ({ name := "s", start := 5, increment := 2, maxValue := 10 } : SequenceDef) 3).isOk && (nextvals ({ name := "s", start := 5, increment := 2, maxValue := 10 } : SequenceDef) 4) matches .error (.sequenceExhausted _)
#guard (nextvals ({ name := "s", start := 2, maxValue := 3, cycle := true } : SequenceDef) 5).toOption == some [2, 3, 1, 2, 3]

/-! ## UPDATE（右辺は更新前の行で評価する。WHERE の UNKNOWN は偽） -/

def urows : List (Nat × SqlValue × SqlValue) := [(1, .int 1, .int 2), (2, .int 3, .null), (3, .int 5, .int 6)]
#guard (updateWhere (fun r => SqlValue.lt coll (.int 1) r.2.2) (fun r => (r.1, r.2.2, r.2.1)) urows).1 == [(1, (.int 2), (.int 1)), (2, (.int 3), .null), (3, (.int 6), (.int 5))]

end LangSemanticsTest.PostgresqlDb
