import LangSemantics.Sql.Core

/-!
# LangSemantics.Sql.Sequence

シーケンス（`CREATE SEQUENCE` / `NEXTVAL`）。状態付きカウンタで、トランザクションの取消では巻き戻らない
（巻き戻らないことは、呼び出し側が状態を取消の対象に含めないことで表す）。

lang: `lang:sql#ISO-9075-2-11.72`
-/

namespace LangSemantics.Sql.Sequence
open LangSemantics.Sql.Core

/-- シーケンスの定義。 -/
structure SequenceDef where
  name : String
  minValue : Int := 1
  maxValue : Int
  increment : Int := 1
  start : Int := 1
  cycle : Bool := false
  deriving Repr, BEq

/-- シーケンスの状態（最後に返した値。未使用なら `none`）。 -/
abbrev SequenceState := Option Int

/-- `NEXTVAL`。最大値を超えると、`CYCLE` なら最小値に戻り、そうでなければエラー。 -/
def nextval (s : SequenceDef) (st : SequenceState) : SqlResult (Int × SequenceState) :=
  match st with
  | none => .ok (s.start, some s.start)
  | some cur =>
    let n := cur + s.increment
    if n > s.maxValue || n < s.minValue then
      if s.cycle then
        let wrapped := if s.increment > 0 then s.minValue else s.maxValue
        .ok (wrapped, some wrapped)
      else .error (.sequenceExhausted s.name)
    else .ok (n, some n)

end LangSemantics.Sql.Sequence
