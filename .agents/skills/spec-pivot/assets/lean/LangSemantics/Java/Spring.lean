import LangSemantics.Java.Exception
import LangSemantics.Java.String

/-!
# LangSemantics.Java.Spring

Spring Framework の `org.springframework.util.Assert`。名前と引数の順は原典と同じにする（`Assert.isTrue(expression, message)`）。
どれも、条件を満たさなければ `IllegalArgumentException(message)` を投げる。

- `Assert.isTrue`・`Assert.notNull`・`Assert.notEmpty`・`Assert.hasText` は、原典と同じく値を返さない。
- `Assert.notNullValue`・`Assert.notEmptyValue` は、検査した参照の中身を返す。原典の `Assert.notNull(x, m)` の後で
  `x` を使う 2 つの文を、モデルで 1 つにしたものである（`let x ← Assert.notNullValue x m`）。
- `Assert.hasText` は `null` でない文字列を受ける（`null` の場合は呼び出し側で `IllegalArgumentException` にする）。

- `StringUtils.hasLength`・`StringUtils.hasText` は `null` を受け、偽を返す。

依存: `dep:org.springframework:spring-core#Assert`・`dep:org.springframework:spring-core#StringUtils`（版はプロジェクトの `@[source]` に書く）
-/

namespace LangSemantics.Java.Spring
open LangSemantics.Java.Exception LangSemantics.Java.String

/-- `Assert.isTrue(expression, message)`。 -/
def Assert.isTrue (expression : Bool) (message : String) : JResult Unit :=
  if expression then .ok () else .error (.illegalArgument message)

/-- `Assert.notNull(object, message)`。 -/
def Assert.notNull {α : Type} (object : JRef α) (message : String) : JResult Unit :=
  Assert.isTrue object.isSome message

/-- `Assert.notNull(object, message)` の後で `object` を使う形: 中身を返す。 -/
def Assert.notNullValue {α : Type} (object : JRef α) (message : String) : JResult α :=
  match object with
  | some a => .ok a
  | none => .error (.illegalArgument message)

/-- `Assert.notEmpty(collection, message)`: `null` か空なら例外。 -/
def Assert.notEmpty {α : Type} (collection : JRef (List α)) (message : String) : JResult Unit :=
  match collection with
  | some (_ :: _) => .ok ()
  | _ => .error (.illegalArgument message)

/-- `Assert.notEmpty(collection, message)` の後で `collection` を使う形: 中身を返す。 -/
def Assert.notEmptyValue {α : Type} (collection : JRef (List α)) (message : String) : JResult (List α) :=
  match collection with
  | some (x :: rest) => .ok (x :: rest)
  | _ => .error (.illegalArgument message)

/-- `Assert.hasText(text, message)`: `Character.isWhitespace` でない文字を含む。 -/
def Assert.hasText (text : String) (message : String) : JResult Unit :=
  Assert.isTrue (text.any fun c => !isJavaWhitespace c) message

/-- `StringUtils.hasLength(str)`: `null` でなく、長さが 0 でない。 -/
def StringUtils.hasLength (str : JRef String) : Bool :=
  match str with
  | some s => !s.isEmpty
  | none => false

/-- `StringUtils.hasText(str)`: `null` でなく、`Character.isWhitespace` でない文字を含む。 -/
def StringUtils.hasText (str : JRef String) : Bool :=
  match str with
  | some s => s.any fun c => !isJavaWhitespace c
  | none => false

/-! ## 補題（証明で、検査を満たす場合の値に書き換えるためのもの） -/

theorem Assert.isTrue_true (message : String) : Assert.isTrue true message = pure () := rfl

theorem Assert.notNull_some {α : Type} (a : α) (message : String) : Assert.notNull (some a) message = pure () := rfl

theorem Assert.notNullValue_some {α : Type} (a : α) (message : String) :
    Assert.notNullValue (some a) message = pure a := rfl

theorem Assert.notNullValue_none {α : Type} (message : String) :
    Assert.notNullValue (none : JRef α) message = .error (.illegalArgument message) := rfl

theorem Assert.notEmptyValue_cons {α : Type} (x : α) (xs : List α) (message : String) :
    Assert.notEmptyValue (some (x :: xs)) message = pure (x :: xs) := rfl

end LangSemantics.Java.Spring
