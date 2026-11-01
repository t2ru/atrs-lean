import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Plane
import SourceModel.Domain.Model.Route
import Spec.Model

/-!
# SourceModel.Domain.Model.FlightMaster

原典の `jp.co.ntt.atrs.domain.model.FlightMaster`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/FlightMaster.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `FlightMaster`。時刻は `HHmm` の文字列。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FlightMaster#getArrivalTime()@2be7080f706c1c52",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#getDepartureTime()@c36b7283ab99fa22",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#getFlightName()@56b669a044a195ca",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#getPlane()@cb4c505335b9f144",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#getRoute()@bb4d94a040ef721d",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#setArrivalTime(String)@64637d5d4f7ee1aa",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#setDepartureTime(String)@581010abbef112c0",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#setFlightName(String)@c8ed541ae69f3cad",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#setPlane(Plane)@b6b44d1417f9fdef",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#setRoute(Route)@876e919b14d523f8",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.FlightMaster.serialVersionUID@8eded4361c5b9f70"]
structure FlightMaster where
  flightName : JRef String := none
  departureTime : JRef String := none
  arrivalTime : JRef String := none
  route : JRef Route := none
  plane : JRef Plane := none
  deriving Repr, DecidableEq

namespace FlightMaster

end FlightMaster

end SourceModel.Domain.Model
