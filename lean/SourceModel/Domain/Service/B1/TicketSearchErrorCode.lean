import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.TicketSearchErrorCode

原典の `jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/TicketSearchErrorCode.java`）の写し。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Service.B1

namespace TicketSearchErrorCode

/-- 空席照会のエラーコード（`TicketSearchErrorCode`）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode#code()@5fde806a365dc7a0",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2001@d4efdf3f2ea8e7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2002@c1a57c4052f9c12b",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2003@2ea2beee13c2ea3a",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5001@9bd02ea3ebb9a87f",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5002@c2b041fc47e7f619"]
def code : String → String := id

end TicketSearchErrorCode

end SourceModel.Domain.Service.B1
