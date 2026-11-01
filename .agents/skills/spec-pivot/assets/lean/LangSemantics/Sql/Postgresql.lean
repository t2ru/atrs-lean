import LangSemantics.Sql

/-!
# LangSemantics.Sql.Postgresql

PostgreSQL 方言。共通部分（`LangSemantics.Sql`）との差分だけを定義する。
説明は spec-pivot スキルの `references/docs/lang/sql/dialects/postgresql/semantics.md`。

lang: `lang:postgresql#datatype-numeric`, `lang:postgresql#datatype-character`, `lang:postgresql#functions-formatting`,
`lang:postgresql#sql-createsequence`, `lang:postgresql#queries-order`, `lang:postgresql#collation`
-/

namespace LangSemantics.Sql.Postgresql
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.Sequence


/-- 整数型の範囲。範囲外はエラー（折り返さない）。 -/
def int2 (v : Int) : SqlResult Int := if -32768 ≤ v && v ≤ 32767 then .ok v else .error .numericOutOfRange
def int4 (v : Int) : SqlResult Int :=
  if -2147483648 ≤ v && v ≤ 2147483647 then .ok v else .error .numericOutOfRange
def int8 (v : Int) : SqlResult Int :=
  if -(2 ^ 63) ≤ v && v ≤ 2 ^ 63 - 1 then .ok v else .error .numericOutOfRange

/-- `VARCHAR(n)` への格納。文字数（スカラ値数）が n を超えるとエラー。
ただし、超えた部分がすべて空白（U+0020）なら、エラーにせず n 文字に切り詰める。 -/
def varchar (column : String) (n : Nat) (v : String) : SqlResult String :=
  if v.length ≤ n then .ok v
  else if (v.toList.drop n).all (· == ' ') then .ok (String.ofList (v.toList.take n))
  else .error (.stringTooLong column)

/-! ## 列の型

列の値は、処理系が許す範囲を型で持つ（物理的なビット幅ではなく、取りうる値の範囲を再現する）。
格納・変換の関数（`int4`・`date`・`varchar`）が範囲を検査し、範囲内の値だけを作る。
モデル（`SourceModel` の表の行）は、`INT`・`DATE`・`VARCHAR(n)` の列をこれらの型で持つ。 -/

/-- `INT`（int4）の値。 -/
abbrev Int4 := {v : Int // -2147483648 ≤ v ∧ v ≤ 2147483647}

/-- `INT` への格納。範囲外は `numericOutOfRange`。 -/
def Int4.ofInt (v : Int) : SqlResult Int4 :=
  if h : -2147483648 ≤ v ∧ v ≤ 2147483647 then .ok ⟨v, h⟩ else .error .numericOutOfRange

/-- `DATE` の下限（紀元前 4714 年 11 月 24 日）の通算日数（1970-01-01 を 0）。 -/
def dateMin : Int := -2440588
/-- `DATE` の上限（5874897 年 12 月 31 日）の通算日数。 -/
def dateMax : Int := 2145042905

/-- `DATE` の値（1970-01-01 を 0 とする通算日数。`SqlValue.date` と同じ表し方）。 -/
abbrev PgDate := {d : Int // dateMin ≤ d ∧ d ≤ dateMax}

/-- `DATE` への格納。範囲外は `dateOutOfRange`。 -/
def date (epochDay : Int) : SqlResult PgDate :=
  if h : dateMin ≤ epochDay ∧ epochDay ≤ dateMax then .ok ⟨epochDay, h⟩ else .error .dateOutOfRange

/-- `VARCHAR(n)` の値（文字数が n 以下）。 -/
abbrev Varchar (n : Nat) := {s : String // s.length ≤ n}

/-- `VARCHAR(n)` への格納（`varchar` と同じ規則）の結果を、型に持つ。 -/
def Varchar.ofString (column : String) (n : Nat) (v : String) : SqlResult (Varchar n) := do
  let s ← varchar column n v
  if h : s.length ≤ n then pure ⟨s, h⟩ else throw (.stringTooLong column)

/-- 列の値を `SqlValue` に写す（比較・整列に使う）。 -/
def Int4.toSql (v : Int4) : SqlValue := .int v.val
def PgDate.toSql (d : PgDate) : SqlValue := .date d.val
def Varchar.toSql {n : Nat} (s : Varchar n) : SqlValue := .text s.val

/-- 照合順序 `C`。 -/
def collationC : Collation := Collation.codepoint

/-- PostgreSQL の既定の整列（照合順序はデータベースの設定。昇順で NULL は後）。 -/
def sortConfig (coll : Collation := collationC) : SortConfig := ⟨coll, false⟩

/-- `CREATE SEQUENCE name`（既定: 1 から、BIGINT の最大値まで、循環しない）。 -/
def defaultSequence (name : String) : SequenceDef :=
  { name, minValue := 1, maxValue := 2 ^ 63 - 1, start := 1 }

/-- `TO_CHAR(n, fmt)` のうち、`FM` に続く `0`・`9` だけからなる書式を扱う。
`0` が現れた位置より右は桁が無くてもゼロで埋める。`9` の位置は桁が無ければ出さない（`FM` は空白を出さない）。
桁数が書式の桁数を超えると、書式の桁数だけ `#` を出す。負数は先頭に `-` を付ける。
それ以外の書式は `none`。 -/
def toChar (n : Int) (fmt : String) : Option String :=
  match fmt.toList with
  | 'F' :: 'M' :: pat =>
    if pat.isEmpty || !pat.all (fun c => c == '0' || c == '9') then none
    else
      let width := pat.length
      let digits := (toString n.natAbs).toList
      let sign := if n < 0 then "-" else ""
      if digits.length > width then some (sign ++ String.ofList (List.replicate width '#'))
      else
        -- 最初の '0' の位置から右は必ず出力する
        let firstZero := pat.findIdx (· == '0')
        let minDigits := if firstZero < width then width - firstZero else 0
        let shown := max minDigits digits.length
        let padded := List.replicate (shown - digits.length) '0' ++ digits
        some (sign ++ String.ofList padded)
  | _ => none

end LangSemantics.Sql.Postgresql
