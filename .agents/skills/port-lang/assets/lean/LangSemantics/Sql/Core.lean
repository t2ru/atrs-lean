/-!
# LangSemantics.Sql.Core

SQL の DBMS に依存しない共通部分: 値と NULL、三値論理、比較、エラー。
型の値域・暗黙の型変換・照合順序は方言（`LangSemantics.Sql.<Dbms>`）が与える。

lang: `lang:sql#ISO-9075-2`
-/

namespace LangSemantics.Sql.Core

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

/-- `AND` の採否は、両方の採否の論理積（`UNKNOWN` は偽として扱うので、三値論理でも成り立つ）。 -/
@[simp] theorem holds_and (a b : Truth) : (a.and b).holds = (a.holds && b.holds) := by
  cases a <;> cases b <;> rfl

@[simp] theorem holds_ofBool (b : Bool) : (ofBool b).holds = b := by cases b <;> rfl

/-- `OR` の採否は、両方の採否の論理和（`UNKNOWN` は偽として扱う）。 -/
@[simp] theorem holds_or (a b : Truth) : (a.or b).holds = (a.holds || b.holds) := by
  cases a <;> cases b <;> rfl

end Truth

/-- 文字列の照合順序（方言・設定のパラメータ）。 -/
abbrev Collation := String → String → Ordering

/-- Unicode スカラ値の辞書順（UTF-8 のバイト順と一致する。PostgreSQL の `C` 照合）。 -/
def Collation.codepoint : Collation := fun a b => compare a b

/-- 符号位置の照合で「より大きくない」は、文字列の `≤`。 -/
theorem Collation.codepoint_ne_gt (a b : String) : Collation.codepoint a b ≠ .gt ↔ a ≤ b := by
  show compareOfLessAndEq a b ≠ .gt ↔ a ≤ b
  unfold compareOfLessAndEq
  by_cases h : a < b
  · simp only [h, ↓reduceIte]; exact ⟨fun _ => String.lt_asymm h, fun _ => by decide⟩
  · by_cases e : a = b
    · subst e; simp
    · simp only [h, e, ↓reduceIte]
      exact ⟨fun h' => absurd rfl h', fun h' => absurd (String.le_antisymm h' (String.not_lt.mp h)) e⟩

/-- 符号位置の照合で「等しい」は、文字列の等しさ。 -/
theorem Collation.codepoint_eq (a b : String) : Collation.codepoint a b = .eq ↔ a = b := by
  show compareOfLessAndEq a b = .eq ↔ a = b
  unfold compareOfLessAndEq
  by_cases h : a < b
  · simp only [h, ↓reduceIte]
    exact ⟨fun h' => absurd h' (by decide), fun e => absurd h (e ▸ String.lt_irrefl a)⟩
  · by_cases e : a = b <;> simp [h, e]

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

/-- 符号位置の照合での文字列の等号の採否は、文字列の等しさ。 -/
theorem SqlValue.eq_text_holds (a b : String) :
    (SqlValue.eq Collation.codepoint (.text a) (.text b)).holds = (a == b) := by
  simp only [SqlValue.eq, SqlValue.compareWith, SqlValue.cmp, Collation.codepoint, Truth.holds_ofBool]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, Std.compare_eq_iff_eq]

/-- 整数の等号の採否は、整数の等しさ。 -/
theorem SqlValue.eq_int_holds (coll : Collation) (a b : Int) :
    (SqlValue.eq coll (.int a) (.int b)).holds = (a == b) := by
  simp only [SqlValue.eq, SqlValue.compareWith, SqlValue.cmp, Truth.holds_ofBool]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, Int.compare_eq_eq]

/-- 日付の等号の採否は、通算日数の等しさ。 -/
theorem SqlValue.eq_date_holds (coll : Collation) (a b : Int) :
    (SqlValue.eq coll (.date a) (.date b)).holds = (a == b) := by
  simp only [SqlValue.eq, SqlValue.compareWith, SqlValue.cmp, Truth.holds_ofBool]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, Int.compare_eq_eq]

/-- `x BETWEEN lo AND hi` ≡ `x >= lo AND x <= hi`。 -/
def between (coll : Collation) (x lo hi : SqlValue) : Truth :=
  (SqlValue.le coll lo x).and (SqlValue.le coll x hi)

/-- `x IN (v1, …)`。一致が無く NULL を含めば `UNKNOWN`。 -/
def inList (coll : Collation) (x : SqlValue) (vs : List SqlValue) : Truth :=
  vs.foldl (fun acc v => acc.or (SqlValue.eq coll x v)) .false

/-- 符号位置の照合で、文字列の `IN` の採否は、列にその文字列があるか。 -/
theorem inList_text_holds (a : String) (vs : List String) :
    (inList Collation.codepoint (.text a) (vs.map .text)).holds = vs.contains a := by
  unfold inList
  suffices h : ∀ acc : Truth, ((vs.map SqlValue.text).foldl (fun acc v => acc.or (SqlValue.eq Collation.codepoint (.text a) v)) acc).holds =
      (acc.holds || vs.contains a) by
    rw [h]; rfl
  induction vs with
  | nil => intro acc; simp
  | cons v vs ih =>
    intro acc
    simp only [List.map_cons, List.foldl_cons, ih, Truth.holds_or, SqlValue.eq_text_holds, List.contains_cons]
    rw [Bool.or_assoc]

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

end LangSemantics.Sql.Core
