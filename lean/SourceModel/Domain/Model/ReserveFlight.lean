import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.Passenger
import Spec.Model

/-!
# SourceModel.Domain.Model.ReserveFlight

原典の `jp.co.ntt.atrs.domain.model.ReserveFlight`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/ReserveFlight.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `ReserveFlight`。搭乗者の列（`passengerList`）は、往路・復路の予約フライトで同じ `List` を共有する（`TicketReserveHelper.createReservation`）。`registerReservation` は搭乗者の `reserveFlightNo`・`passengerNo` を書き換えながら 1 行ずつ挿入するので、共有は挿入される行に現れない（写しでは値として扱う）。 -/
@[source "java:jp.co.ntt.atrs.domain.model.ReserveFlight#getFlight()@f32789ed3a8ab89a",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#getPassengerList()@14ef9a6a124c29ed",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#getReserveFlightNo()@2769dce77ca87a1a",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#getReserveNo()@627ab75e41f993e2",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#setFlight(Flight)@7e222d6a5c787480",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#setPassengerList(List)@3c0f73ab04c18ff1",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#setReserveFlightNo(Integer)@0970fb4639317f1c",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#setReserveNo(String)@2edb9dab1a771a71",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.ReserveFlight.serialVersionUID@fd7ac2ae97b49599"]
structure ReserveFlight where
  reserveFlightNo : JRef J32 := none
  reserveNo : JRef String := none
  flight : JRef Flight := none
  passengerList : JRef (List (JRef Passenger)) := none
  deriving Repr, DecidableEq

namespace ReserveFlight

end ReserveFlight

end SourceModel.Domain.Model
