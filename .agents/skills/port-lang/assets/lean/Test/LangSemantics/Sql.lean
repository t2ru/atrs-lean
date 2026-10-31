import LangSemantics.Sql.Postgresql

/-! LangSemantics.Sql と PostgreSQL 方言の検査。 -/

open LangSemantics.Sql LangSemantics.Sql.Postgresql

def coll := collationC

-- 三値論理
#guard (Truth.and .unknown .false) == .false
#guard (Truth.or .unknown .true) == .true
#guard (Truth.not .unknown) == .unknown
#guard (SqlValue.eq coll .null .null) == .unknown
#guard (between coll (.int 10) (.int 1) (.int 60)) == .true
#guard (between coll (.int 0) (.int 1) (.int 60)) == .false
#guard (inList coll (.int 3) [.int 1, .null]) == .unknown
#guard (inList coll (.int 1) [.int 1, .null]) == .true

-- ORDER BY: 同順位の並びは未規定（どちらも許される）
def rows : List (String × Int) := [("a", 2), ("b", 1), ("c", 2)]
def key (r : String × Int) : List SqlValue := [.int r.2]
#guard isAllowedOrder (sortConfig) [.asc] key rows [("b", 1), ("a", 2), ("c", 2)]
#guard isAllowedOrder (sortConfig) [.asc] key rows [("b", 1), ("c", 2), ("a", 2)]
#guard !isAllowedOrder (sortConfig) [.asc] key rows [("a", 2), ("b", 1), ("c", 2)]
#guard !isAllowedOrder (sortConfig) [.asc] key rows [("b", 1), ("a", 2)]
#guard isAllowedOrder (sortConfig) [.asc] key rows (orderByStable (sortConfig) [.asc] key rows)
-- NULL は昇順で後
#guard compareKey (sortConfig) .asc .null (.int 1) == .gt

-- UPDATE の右辺は更新前の行で評価する（last_password = password, password = new）
structure Login where
  password : String
  lastPassword : String
  deriving BEq, Repr
#guard updateWhere (fun (_ : Login) => Truth.true) (fun r => ({ password := "new", lastPassword := r.password } : Login))
    [({ password := "old", lastPassword := "older" } : Login)] == ([({ password := "new", lastPassword := "old" } : Login)], 1)

-- 主キー違反
#guard (insertUnique (fun (r : String × Int) => r.1) "pk" ("a", 9) rows) matches .error (.uniqueViolation _)

-- シーケンス（CYCLE）
def sq : SequenceDef := { name := "sq", maxValue := 3, cycle := true }
#guard (do
    let (a, s) ← nextval sq none
    let (b, s) ← nextval sq s
    let (c, s) ← nextval sq s
    let (d, _) ← nextval sq s
    pure [a, b, c, d]).toOption == some [1, 2, 3, 1]
#guard (nextval { sq with cycle := false } (some 3)) matches .error (.sequenceExhausted _)

-- PostgreSQL: TO_CHAR(n, 'FM0999999999')
#guard toChar 123 "FM0999999999" == some "0000000123"
#guard toChar 9999999999 "FM0999999999" == some "9999999999"
#guard toChar 12345678901 "FM0999999999" == some "##########"
#guard toChar 123 "FM9999" == some "123"
#guard toChar 123 "FM9909" == some "123"
#guard toChar 5 "FM9909" == some "05"
#guard toChar (-42) "FM0999" == some "-0042"
#guard toChar 123 "999" == none
-- 整数型の範囲・VARCHAR
#guard int4 2147483648 matches .error .numericOutOfRange
#guard (varchar "c" 3 "𠮷𠮷𠮷").toOption == some "𠮷𠮷𠮷"
#guard varchar "c" 2 "abc" matches .error (.stringTooLong _)

-- ORDER BY の許される順列の一意性（キーが単射のとき）の公理
/-- info: 'LangSemantics.Sql.isAllowedOrder_unique' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LangSemantics.Sql.isAllowedOrder_unique

-- 列の型: 範囲の内だけを作る
#guard (Int4.ofInt 2147483647).toOption.map (·.val) == some 2147483647
#guard Int4.ofInt (-2147483649) matches .error .numericOutOfRange
#guard (date dateMin).toOption.map (·.val) == some (-2440588)
#guard date (dateMax + 1) matches .error .dateOutOfRange
#guard (Varchar.ofString "c" 2 "ab ").toOption.map (·.val) == some "ab"
#guard Varchar.ofString "c" 2 "abc" matches .error (.stringTooLong _)
