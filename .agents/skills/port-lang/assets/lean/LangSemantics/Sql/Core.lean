/-!
# LangSemantics.Sql.Core

SQL の DBMS に依存しない共通部分: 値と NULL、三値論理、比較、エラー。
型の値域・暗黙の型変換・照合順序は方言（`LangSemantics.Sql.<Dbms>`）が与える。

lang: `lang:sql#ISO-9075-2`
-/

namespace LangSemantics.Sql

/-- SQL の値。`date` は 1970-01-01 を 0 とする通算日数。 -/
inductive SqlValue where
  | null
  | int (v : Int)
  | text (v : String)
  | bool (v : Bool)
  | date (epochDay : Int)
  deriving Repr, BEq, DecidableEq

/-- 三値論理の真理値。 -/
inductive Truth where
  | true
  | false
  | unknown
  deriving Repr, BEq, DecidableEq

namespace Truth

def and : Truth → Truth → Truth
  | .false, _ | _, .false => .false
  | .true, .true => .true
  | _, _ => .unknown

def or : Truth → Truth → Truth
  | .true, _ | _, .true => .true
  | .false, .false => .false
  | _, _ => .unknown

def not : Truth → Truth
  | .true => .false
  | .false => .true
  | .unknown => .unknown

def ofBool (b : Bool) : Truth := if b then .true else .false

/-- `WHERE` 句での採否（`UNKNOWN` は偽として扱う）。 -/
def holds : Truth → Bool
  | .true => Bool.true
  | _ => Bool.false

end Truth

/-- 文字列の照合順序（方言・設定のパラメータ）。 -/
abbrev Collation := String → String → Ordering

/-- Unicode スカラ値の辞書順（UTF-8 のバイト順と一致する。PostgreSQL の `C` 照合）。 -/
def Collation.codepoint : Collation := fun a b => compare a b

/-- 非 NULL の値どうしの比較。型が異なる場合は `none`（方言が暗黙の変換を与える）。 -/
def SqlValue.cmp (coll : Collation) : SqlValue → SqlValue → Option Ordering
  | .int a, .int b => some (compare a b)
  | .text a, .text b => some (coll a b)
  | .bool a, .bool b => some (compare a b)
  | .date a, .date b => some (compare a b)
  | _, _ => none

/-- 比較演算子の結果（NULL を含めば `UNKNOWN`）。 -/
def SqlValue.compareWith (coll : Collation) (accept : Ordering → Bool) (a b : SqlValue) : Truth :=
  match a, b with
  | .null, _ | _, .null => .unknown
  | _, _ => match a.cmp coll b with
    | some o => Truth.ofBool (accept o)
    | none => .unknown

def SqlValue.eq (coll : Collation) (a b : SqlValue) : Truth := a.compareWith coll (· == .eq) b
def SqlValue.lt (coll : Collation) (a b : SqlValue) : Truth := a.compareWith coll (· == .lt) b
def SqlValue.le (coll : Collation) (a b : SqlValue) : Truth := a.compareWith coll (· != .gt) b

/-- `x BETWEEN lo AND hi` ≡ `x >= lo AND x <= hi`。 -/
def between (coll : Collation) (x lo hi : SqlValue) : Truth :=
  (SqlValue.le coll lo x).and (SqlValue.le coll x hi)

/-- `x IN (v1, …)`。一致が無く NULL を含めば `UNKNOWN`。 -/
def inList (coll : Collation) (x : SqlValue) (vs : List SqlValue) : Truth :=
  vs.foldl (fun acc v => acc.or (SqlValue.eq coll x v)) .false

/-- `x IS NULL`。 -/
def isNull (x : SqlValue) : Truth := Truth.ofBool (x == .null)

/-- SQL のエラー。 -/
inductive SqlError where
  | uniqueViolation (constraintName : String)
  | notNullViolation (column : String)
  | foreignKeyViolation (constraintName : String)
  | numericOutOfRange
  | stringTooLong (column : String)
  | dateOutOfRange
  | sequenceExhausted (sequenceName : String)
  | other (message : String)
  deriving Repr, BEq, DecidableEq

abbrev SqlResult (α : Type) := Except SqlError α

end LangSemantics.Sql
