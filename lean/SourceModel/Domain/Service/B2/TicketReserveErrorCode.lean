import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Domain.Service.B2.TicketReserveErrorCode

原典の `jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b2/TicketReserveErrorCode.java`）の写し。
-/

namespace SourceModel.Domain.Service.B2
open LangSemantics.Java

namespace TicketReserveErrorCode

/-- 予約のエラーコード（`TicketReserveErrorCode`）。定数の値はコードの文字列そのもの。`E_AR_B2_5001`〜`5003` は Web 層の入力検証
（`ReservationFlightValidator`・`TicketReserveValidator`。backlog 4e0e・a89e）が使う。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode#code()@5fde806a365dc7a0",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2001@48c863106106d000",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2002@cd7ca684671ce46f",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2003@e38fa5a882084768",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2004@4e63e291bfee3d2a",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2005@ddb39f02b8f2ef71",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2006@7f2e00f344361b5e",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2007@1ad572ad2b5e701d",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2008@25e29d5a5f6f2214",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2009@9810cb0c99b4d473",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2010@d64487b413becec0",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_5001@5acd18b769673fe4",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_5002@f4427cb5117641dc",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_5003@a96dc797ba2e65b6"]
def code : String → String := id

end TicketReserveErrorCode

end SourceModel.Domain.Service.B2
