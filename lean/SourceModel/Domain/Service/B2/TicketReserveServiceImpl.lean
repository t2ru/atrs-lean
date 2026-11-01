import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Common.Util.FareUtil
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import Spec.Model

/-!
# SourceModel.Domain.Service.B2.TicketReserveServiceImpl

原典の `jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b2/TicketReserveServiceImpl.java`）の写し。
-/

namespace SourceModel.Domain.Service.B2
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.Spring LangSemantics.Java.Int
  LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata
open SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareUtil
  SourceModel.Domain.Service.B2

/-- `TicketReserveServiceImpl` が受ける設定（`@Value`）と、使うサービス。 -/
structure TicketReserveServiceImpl where
  ticketSharedService : TicketSharedServiceImpl := {}
  /-- `atrs.adultPassengerMinAge` -/
  adultPassengerMinAge : J32
  /-- `atrs.childFareRate` -/
  childFareRate : J32

namespace TicketReserveServiceImpl

/-- `calculateTotalFare`: 小児の人数を数え、フライトごとに `boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum`
を左から int で計算して合計し、最後に `FareUtil.ceilFare` で 100 円単位に切り上げる。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)@35bc5d27ed5f2ca9",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)@ca1a14757ce1cb33", gap "D-003", "D-012", "D-030", "D-035"]
def calculateTotalFare (svc : TicketReserveServiceImpl) (flightList : JRef (List (JRef Flight)))
    (passengerList : JRef (List (JRef Passenger))) : JResult J32 := do
  let flights ← Assert.notEmptyValue flightList "flightList must not empty."
  let passengers ← Assert.notEmptyValue passengerList "passengerList must not empty."
  let mut childNum : J32 := J32.ofInt 0
  for passenger in passengers do
    let passenger ← Assert.notNullValue passenger "passenger must not null."
    let age ← passenger.age.deref "age"
    if java! age < svc.adultPassengerMinAge then childNum := java! childNum + 1
  let adultNum := java! ⟪J32.ofInt passengers.length⟫ - childNum
  let mut totalFare : J32 := J32.ofInt 0
  for flight in flights do
    let flight ← Assert.notNullValue flight "flight must not null."
    let flightMaster ← flight.flightMaster.deref "flightMaster"
    let route ← flightMaster.route.deref "route"
    let routeBasicFare ← route.basicFare.deref "basicFare"
    let boardingClass ← flight.boardingClass.deref "boardingClass"
    let baseFare ← calculateBasicFare svc.ticketSharedService routeBasicFare boardingClass.boardingClassCd flight.departureDate
    let fareType ← flight.fareType.deref "fareType"
    let discountRate ← fareType.discountRate.deref "discountRate"
    let boardingFare ← calculateFare baseFare discountRate
    let fare ← java! boardingFare * adultNum + baseFare * (svc.childFareRate - discountRate) / 100 * childNum
    totalFare := java! totalFare + fare
  return ceilFare totalFare

end TicketReserveServiceImpl

end SourceModel.Domain.Service.B2
