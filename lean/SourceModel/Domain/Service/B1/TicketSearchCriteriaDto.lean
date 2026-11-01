import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.TicketSearchCriteriaDto

原典の `jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/TicketSearchCriteriaDto.java`）の写し。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Service.B1

/-- `TicketSearchCriteriaDto`（照会条件）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getArrivalAirportCd()@1c111d784bf8d220",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepDate()@9e5ad0157d1bece7",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepartureAirportCd()@08763144c723fca5",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getFlightType()@a815d39b257bbd2b",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setArrivalAirportCd(String)@922656e0efb53e00",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepDate(LocalDate)@e4d262f79ebcb7ac",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepartureAirportCd(String)@48b1037e44becf59",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setFlightType(FlightType)@7f178ac43c6090bd",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto.serialVersionUID@c846f41752a6a6bf"]
structure TicketSearchCriteriaDto where
  flightType : JRef Spec.Model.FlightType := none
  departureAirportCd : JRef String := none
  arrivalAirportCd : JRef String := none
  depDate : JRef JLocalDate := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  deriving DecidableEq, Repr

namespace TicketSearchCriteriaDto

end TicketSearchCriteriaDto

end SourceModel.Domain.Service.B1
