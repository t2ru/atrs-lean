import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Common.Exception.AtrsBusinessException

原典の `jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/exception/AtrsBusinessException.java`）の写し。
-/

namespace SourceModel.Domain.Common.Exception
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Common.Exception

namespace AtrsBusinessException

/-- 業務例外のクラス名。 -/
def className : LangSemantics.Java.Exception.JClassName := cls!"jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException"

/-- `new AtrsBusinessException(code)`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException#<init>(AtrsErrorCode,Object...)@70bc401f3ab46d0d",
  "java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException.serialVersionUID@3d4b63a6702d11d1"]
def new (errorCode : String) : JThrow := .other AtrsBusinessException.className errorCode

/-- `new AtrsBusinessException(code, args...)`。例外のメッセージは、コードと引数（`toString` の値）を改行でつないだもの
とする（`new code` は引数が無い場合と同じ値）。コードと引数は改行を含まない（コードは `e.ar.…`、引数は整数と
マスタの運賃種別名）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException#<init>(AtrsErrorCode,Object...)@70bc401f3ab46d0d"]
def newArgs (errorCode : String) (args : List String) : JThrow :=
  .other AtrsBusinessException.className (String.intercalate "\n" (errorCode :: args))

theorem newArgs_nil (errorCode : String) : newArgs errorCode [] = new errorCode := by
  rfl

end AtrsBusinessException

end SourceModel.Domain.Common.Exception
