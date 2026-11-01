import Trace

/-!
# Spec.Error

エラーの分類 `AtrsError`（`docs/spec/errors-and-messages.md#分類atrserror`、ADR a4fa）。
いまは空席照会が使う `Business`・`NotFound` だけを置く。ほかの分類（`Validation`・`InvalidRequest`・`System`・
`Conflict`）は、それを使う機能の backlog で足す。
-/

namespace Spec.Error

/-- エラーの分類。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive AtrsError where
  /-- 業務規則違反（コードと引数） -/
  | business (code : String) (args : List String := [])
  /-- 照会結果 0 件 -/
  | notFound (code : String)
  deriving DecidableEq, Repr

end Spec.Error
