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
structure TicketReserveDto where
  reserveNo : JRef String := none
  paymentDate : JRef JLocalDate := none
  deriving Repr, DecidableEq

end SourceModel.Domain.Service.B2
