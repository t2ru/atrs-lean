import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Service.B1.TicketSearchErrorCode
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.FlightNotFoundException

原典の `jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/FlightNotFoundException.java`）の写し。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Service.B1

namespace FlightNotFoundException

/-- 照会結果 0 件の業務例外のクラス名。 -/
def className : String := "jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException"

/-- `new FlightNotFoundException()`（`E_AR_B1_2003`）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException#<init>()@a759c61b6ed17dc4",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException.serialVersionUID@8c008f35f98c4bb6"]
def new : JThrow := .other FlightNotFoundException.className (TicketSearchErrorCode.code "e.ar.b1.2003")

end FlightNotFoundException

end SourceModel.Domain.Service.B1
