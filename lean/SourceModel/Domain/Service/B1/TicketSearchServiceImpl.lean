import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.FareTypeProvider
import SourceModel.Domain.Common.Masterdata.FlightMasterProvider
import SourceModel.Domain.Common.Masterdata.RouteProvider
import SourceModel.Domain.Common.Util.DateTimeUtil
import SourceModel.Domain.Common.Util.FareTypeUtil
import SourceModel.Domain.Model.Airport
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Domain.Service.B1.FareTypeVacantInfoDto
import SourceModel.Domain.Service.B1.FlightNotFoundException
import SourceModel.Domain.Service.B1.FlightVacantInfoDto
import SourceModel.Domain.Service.B1.TicketSearchCriteriaDto
import SourceModel.Domain.Service.B1.TicketSearchErrorCode
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.TicketSearchServiceImpl

原典の `jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/TicketSearchServiceImpl.java`）の写し。

空席照会（B1）の原典（`TicketSearchServiceImpl.searchFlight`・`TicketSharedServiceImpl` の照会可能期間と
運賃種別の予約可能判定・`FareTypeUtil`・`DateTimeUtil` の書式）の写し（backlog 0be7。ADR ce36）。

- 今日の日付（`LocalDate.now(dateFactory.tick())`）は、Clock の読み出しごとに値として受ける。原典は 1 回の照会で
  Clock を 3 回読む（`validateDepatureDate` の今日・`getSearchLimitDate` の今日・`searchFlight` の今日）。
  3 つが同じ日付であることは D-014 の前提（`Abstraction.FlightSearch.Alpha.dev_D014S`）で、写しは仮定しない。
- リポジトリ `FlightRepository.findByVacantSeatSearchCriteria` はポートとして関数で受ける。SQL の写しと、
  その許される並べ方は `SourceModel.Domain.Repository.Flight.FlightRepository` にある。選んだ並べ方でポートを作るのは `SourceModel.FlightSearchQuery.repositoryOf`、
  起動時の読み込みと合わせて実行するのは `runSearchFlight` である。
- 業務例外（`AtrsBusinessException`・`FlightNotFoundException`）は、`JThrow.other` のクラス名とエラーコードで表す。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata SourceModel.Domain.Repository.Flight
  SourceModel.Domain.Repository.Flight.FlightRepository
open SourceModel.Domain.Common.Exception SourceModel.Domain.Service.B1 SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareTypeUtil
  SourceModel.Domain.Common.Util.DateTimeUtil SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl SourceModel.Domain.Service.B1.FlightVacantInfoDto

/-- `TicketSearchServiceImpl` が受けるもの（`@Inject`・`@Value`）と、今日の日付・リポジトリのポート。 -/
structure TicketSearchServiceImpl where
  routeProvider : RouteProvider := {}
  fareTypeProvider : FareTypeProvider := {}
  flightMasterProvider : FlightMasterProvider := {}
  boardingClassProvider : BoardingClassProvider := {}
  ticketSharedService : SourceModel.Domain.Service.B0.TicketSharedServiceImpl := {}
  /-- `atrs.limitDay`（`TicketSharedServiceImpl`） -/
  limitDay : J32
  /-- `searchFlight` の今日の日付（`LocalDate.now(dateFactory.tick())`） -/
  today : JLocalDate
  /-- `TicketSharedServiceImpl` が読む今日の日付（`validateDepatureDate` の今日、`getSearchLimitDate` の今日。D-014） -/
  sharedClock : JLocalDate × JLocalDate
  /-- 配備の環境: JVM の既定の書式ロケールの書式の記号（`DecimalFormat` が使う区切り文字・数字・負の記号。D-032） -/
  formatSymbols : DecimalFormat.Symbols
  /-- `FlightRepository.findByVacantSeatSearchCriteria` -/
  flightRepository : VacantSeatSearchCriteriaDto → JResult (List Flight)

namespace TicketSearchServiceImpl

/-- `createFlightVacantInfo(flight)`（private）: グループの見出し。 -/
def createFlightVacantInfo (flight : Flight) : JResult FlightVacantInfoDto := do
  let fm ← flight.flightMaster.deref "flightMaster"
  let route ← fm.route.deref "route"
  let dep ← route.departureAirport.deref "departureAirport"
  let arr ← route.arrivalAirport.deref "arrivalAirport"
  let bc ← flight.boardingClass.deref "boardingClass"
  return { flightName := fm.flightName, depAirportName := dep.name, arrAirportName := arr.name,
           depTime := ← toFormatTimeString fm.departureTime, arrTime := ← toFormatTimeString fm.arrivalTime,
           depDate := some (toFormatDateString flight.departureDate), boardingClassCd := bc.boardingClassCd }

/-- `createFlightVacantInfoList(flightList, basicFare)`（private）: 便マスタの出発時刻をキーに `LinkedHashMap` へまとめ、
各フライトの運賃種別の空席情報を足す。値の列（挿入順）を返す。運賃の書式は `new DecimalFormat("###,###")`
（書式の記号は既定の書式ロケールによる。配備の環境 `sym` として受ける。D-032）。 -/
@[source "lang:java#java.text.DecimalFormat@java-17", "lang:java#java.util.LinkedHashMap@java-17", gap "D-005", "D-032"]
def createFlightVacantInfoList (sym : DecimalFormat.Symbols) (flightList : List Flight) (basicFare : J32) : JResult (List FlightVacantInfoDto) := do
  let mut m : JLinkedHashMap (JRef String) FlightVacantInfoDto := {}
  for flight in flightList do
    let fm ← flight.flightMaster.deref "flightMaster"
    let departureTime := fm.departureTime
    let vacantInfo ← match m.get departureTime with
      | some v => pure v
      | none => createFlightVacantInfo flight
    let ft ← flight.fareType.deref "fareType"
    let fare ← SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare basicFare (← ft.discountRate.deref "discountRate")
    let info : FareTypeVacantInfoDto :=
      ⟨ft.fareTypeName, some (DecimalFormat.formatJ32S sym fare), flight.vacantNum⟩
    -- 原典は、取り出した（または作って入れた）同じオブジェクトを更新する。ここでは更新した値を同じキーで置き直す
    m := m.put departureTime (← vacantInfo.addFareTypeVacantInfo ft.fareTypeCd info)
  return m.entries.map (·.2)

/-- `searchFlight(searchCriteria)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchService#searchFlight(TicketSearchCriteriaDto)@aebd2fb115cd02fc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)@75061ffc6ae02ecb",
  "dep:org.springframework:spring-core#Assert.notNull@spring-core-7.0.3",
  "dep:org.springframework:spring-core#Assert.hasText@spring-core-7.0.3", gap "D-001", "D-002", "D-014", "D-033"]
def searchFlight (svc : TicketSearchServiceImpl) (searchCriteria : JRef TicketSearchCriteriaDto) :
    JResult (List FlightVacantInfoDto) := do
  let c ← Assert.notNullValue searchCriteria "searchCriteria must not null."
  let depDate ← Assert.notNullValue c.depDate "depDate must not null."
  let boardingClassCd ← Assert.notNullValue c.boardingClassCd "boardingClassCd must not null."
  let depAirportCd := c.departureAirportCd.getD ""
  Assert.hasText depAirportCd "depAirportCd must have some text."
  let arrAirportCd := c.arrivalAirportCd.getD ""
  Assert.hasText arrAirportCd "arrAirportCd must have some text."
  let flightType ← Assert.notNullValue c.flightType "flightType must not null."
  validateDepatureDate svc.limitDay svc.sharedClock.1 svc.sharedClock.2 (some depDate)
  let route ← match ← RouteProvider.getRouteByAirportCd svc.routeProvider depAirportCd arrAirportCd with
    | some r => pure r
    | none => throw (AtrsBusinessException.new (TicketSearchErrorCode.code "e.ar.b1.2002"))
  let beforeDayNum := J64.ofInt (JLocalDate.daysBetween svc.today depDate)
  let fareTypeList := getFareTypeCdList (some flightType)
  let criteria : VacantSeatSearchCriteriaDto :=
    { depDate := some depDate, route := some route, boardingClass := some boardingClassCd,
      beforeDayNum := some beforeDayNum, fareTypeList := some fareTypeList }
  let flightList ← svc.flightRepository criteria
  if flightList.isEmpty then throw FlightNotFoundException.new
  let flightList ← flightList.mapM fun flight => do
    let ftCd := (← flight.fareType.deref "fareType").fareTypeCd
    let fareType ← FareTypeProvider.getFareType svc.fareTypeProvider ftCd
    let name ← match (← flight.flightMaster.deref "flightMaster").flightName with
      | some n => pure n
      | none => throw (.illegalArgument "flightName must have some text.")
    let flightMaster ← FlightMasterProvider.getFlightMaster svc.flightMasterProvider name
    let bcCd := (← flight.boardingClass.deref "boardingClass").boardingClassCd
    let boardingClass ← BoardingClassProvider.getBoardingClass svc.boardingClassProvider bcCd
    return { flight with fareType := fareType, flightMaster := flightMaster, boardingClass := boardingClass }
  let basicFareOfRoute ← route.basicFare.deref "basicFare"
  let basicFare ← SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare svc.ticketSharedService basicFareOfRoute (some boardingClassCd)
    (some depDate)
  createFlightVacantInfoList svc.formatSymbols flightList basicFare

end TicketSearchServiceImpl

end SourceModel.Domain.Service.B1
