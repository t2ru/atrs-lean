import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Domain.Service.B0.InvalidFlightException

原典の `jp.co.ntt.atrs.domain.service.b0.InvalidFlightException`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b0/InvalidFlightException.java`）の写し。
-/

namespace SourceModel.Domain.Service.B0
open LangSemantics.Java LangSemantics.Java.Exception

namespace InvalidFlightException

/-- フライト不正の例外のクラス名。 -/
def className : LangSemantics.Java.Exception.JClassName := cls!"jp.co.ntt.atrs.domain.service.b0.InvalidFlightException"

/-- `new InvalidFlightException(message)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.InvalidFlightException#<init>(String)@80edf1af3fd26cf2",
  "java:jp.co.ntt.atrs.domain.service.b0.InvalidFlightException.serialVersionUID@2d16bfba7652351b"]
def new (message : String) : JThrow := .other InvalidFlightException.className message

end InvalidFlightException

end SourceModel.Domain.Service.B0
