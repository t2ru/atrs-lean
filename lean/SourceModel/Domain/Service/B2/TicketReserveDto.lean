import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Domain.Service.B2.TicketReserveDto

原典の `jp.co.ntt.atrs.domain.service.b2.TicketReserveDto`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b2/TicketReserveDto.java`）の写し。
-/

namespace SourceModel.Domain.Service.B2
open LangSemantics.Java LangSemantics.Java.Exception

/-- `TicketReserveDto`（予約番号と支払期限）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#<init>(String,LocalDate)@9478f45856d7dcf7",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#getPaymentDate()@305a3cd2edbb1ef0",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#getReserveNo()@627ab75e41f993e2",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#setPaymentDate(LocalDate)@28072d31fdd042a0",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#setReserveNo(String)@2edb9dab1a771a71",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveDto.serialVersionUID@ab7b84f869e4a96c"]
structure TicketReserveDto where
  reserveNo : JRef String := none
  paymentDate : JRef JLocalDate := none
  deriving Repr, DecidableEq

end SourceModel.Domain.Service.B2
