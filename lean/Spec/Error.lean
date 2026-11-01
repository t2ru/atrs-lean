import Trace

/-!
# Spec.Error

エラーの分類 `AtrsError`（`docs/spec/errors-and-messages.md#分類atrserror`、ADR a4fa）。
空席照会・予約が使う `Business`・`NotFound`・`InvalidRequest`・`System`・`Conflict` を置く。`Validation` は、
それを使う機能の backlog（4e0e）で足す。`PreconditionViolation` は [Source] だけの分類なので置かない。
-/

namespace Spec.Error

/-- エラーの分類。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive AtrsError where
  /-- 業務規則違反（コードと引数） -/
  | business (code : String) (args : List String := [])
  /-- 照会結果 0 件 -/
  | notFound (code : String)
  /-- 改竄検知（`detail` はログ用の詳細。変えうる部分は N-004） -/
  | invalidRequest (detail : String)
  /-- 整合性違反・I/O 失敗（コードと引数。I/O 失敗のコードは `e.ar.fw.9999` だけ。N-002） -/
  | system (code : String) (args : List String := [])
  /-- 排他制御の失敗（`reason` はログ用。N-001） -/
  | conflict (reason : String)
  deriving DecidableEq, Repr

end Spec.Error
