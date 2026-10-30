import LangSemantics.Sql

/-!
# LangSemantics.Sql.Postgresql

PostgreSQL 方言。共通部分（`LangSemantics.Sql`）との差分だけを定義する。
説明は port-lang スキルの `references/sql/dialects/postgresql/semantics.md`。

lang: `lang:postgresql#datatype-numeric`, `lang:postgresql#functions-formatting`,
`lang:postgresql#sql-createsequence`, `lang:postgresql#queries-order`, `lang:postgresql#collation`
-/

namespace LangSemantics.Sql.Postgresql

open LangSemantics.Sql

/-- 整数型の範囲。範囲外はエラー（折り返さない）。 -/
def int2 (v : Int) : SqlResult Int := if -32768 ≤ v && v ≤ 32767 then .ok v else .error .numericOutOfRange
def int4 (v : Int) : SqlResult Int :=
  if -2147483648 ≤ v && v ≤ 2147483647 then .ok v else .error .numericOutOfRange
def int8 (v : Int) : SqlResult Int :=
  if -(2 ^ 63) ≤ v && v ≤ 2 ^ 63 - 1 then .ok v else .error .numericOutOfRange

/-- `VARCHAR(n)` への格納。文字数（スカラ値数）が n を超えるとエラー。 -/
def varchar (column : String) (n : Nat) (v : String) : SqlResult String :=
  if v.length ≤ n then .ok v else .error (.stringTooLong column)

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
