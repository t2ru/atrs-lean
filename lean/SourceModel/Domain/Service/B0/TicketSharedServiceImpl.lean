import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.PeakTimeProvider
import SourceModel.Domain.Common.Util.FareUtil
import SourceModel.Domain.Common.Util.DateTimeUtil
import SourceModel.Domain.Common.Util.FareTypeUtil
import SourceModel.Db.Tx
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Repository.Flight.FlightRepository
import SourceModel.Domain.Service.B0.InvalidFlightException
import SourceModel.Domain.Service.B2.TicketReserveErrorCode
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.PeakTime
import SourceModel.Domain.Service.B1.TicketSearchErrorCode
import Spec.Model

/-!
# SourceModel.Domain.Service.B0.TicketSharedServiceImpl

原典の `jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b0/TicketSharedServiceImpl.java`）の写し。

運賃計算の原典（`TicketSharedServiceImpl`・`FareUtil`・`TicketReserveServiceImpl#calculateTotalFare`）の写し。
`int` は `J32`（折り返し）、`double` は `JDouble`、`BigDecimal` の切上げは `bdCeilHundredUp`、
Spring の `Assert` は `IllegalArgumentException`、参照の `null` と `Integer` の unboxing は `NullPointerException` で表す。
[Spec] との差異は D-001・D-002・D-012（`docs/spec/abstraction.md#既知差異`）。
-/

namespace SourceModel.Domain.Service.B0
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.Spring LangSemantics.Java.Int
  LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata
open SourceModel.Domain.Service.B0 SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareUtil
open LangSemantics.Java.String LangSemantics.Java.HashMap

open SourceModel.Domain.Common.Exception SourceModel.Domain.Service.B1

/-- `TicketSharedServiceImpl` が受ける Provider（`@Inject`）。 -/
structure TicketSharedServiceImpl where
  boardingClassProvider : BoardingClassProvider := {}
  peakTimeProvider : PeakTimeProvider := {}

namespace TicketSharedServiceImpl

/-- `MULTIPLICATION_RATIO_IN_NORMAL_TIME`。 -/
def MULTIPLICATION_RATIO_IN_NORMAL_TIME : J32 := J32.ofInt 100

/-- `getMultiplicationRatio`（private）: ピーク時期の積算比率。ピーク時期でなければ 100。 -/
def getMultiplicationRatio (svc : TicketSharedServiceImpl) (departureDate : JRef JLocalDate) : JResult J32 := do
  match ← PeakTimeProvider.getPeakTime svc.peakTimeProvider departureDate with
  | some pt => pt.multiplicationRatio.deref "multiplicationRatio"
  | none => pure MULTIPLICATION_RATIO_IN_NORMAL_TIME

/-- `calculateBasicFare`: `(int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl.MULTIPLICATION_RATIO_IN_NORMAL_TIME@48440c4bc2152d40",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@5b0822fe4c6991ac",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateBasicFare(int,BoardingClassCd,LocalDate)@9872678663e9a896",
  gap "D-001", "D-030"]
def calculateBasicFare (svc : TicketSharedServiceImpl) (basicFareOfRoute : J32) (boardingClassCd : JRef Spec.Model.BoardingClassCd)
    (depDate : JRef JLocalDate) : JResult J32 := do
  Assert.isTrue (java! basicFareOfRoute >= 0) "basicFareOfRoute must be 0 or higher."
  Assert.notNull boardingClassCd "boardingClassCd must not null."
  Assert.notNull depDate "depDate must not null."
  let boardingClass ← (← BoardingClassProvider.getBoardingClass svc.boardingClassProvider boardingClassCd).deref "boardingClass"
  let boardingClassFare ← boardingClass.extraCharge.deref "extraCharge"
  let multiplicationRatio ← getMultiplicationRatio svc depDate
  let basicFare := java! (int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))
  return basicFare

/-- `calculateFare`: `FareUtil.ceilFare((int) (basicFare * (1 - (discountRate * 0.01))))`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)@1e12eb714e2bc395",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateFare(int,int)@8088a7f2c9efaf7e", gap "D-002"]
def calculateFare (basicFare discountRate : J32) : JResult J32 := do
  Assert.isTrue (java! basicFare >= 0) "basicFare must be 0 or higher."
  Assert.isTrue (java! discountRate >= 0) "discountRate must be 0 or higher."
  Assert.isTrue (java! discountRate <= 100) "discountRate must be 100 or less."
  let fare := java! (int) (basicFare * (1 - (discountRate * 0.01)))
  return ceilFare fare

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1000 円（[Spec] は 1100 円）。 -/
theorem calculateFare_1430_30 : ((calculateFare (J32.ofInt 1430) (J32.ofInt 30)).toOption.map (·.val)) = some 1000 := by decide

/-- `getSearchLimitDate()`: `today.plusDays(limitDay)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#getSearchLimitDate()@9196be73040e6f0f",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getSearchLimitDate()@07352a31cf61634a", gap "D-014"]
def getSearchLimitDate (limitDay : J32) (today : JLocalDate) : JLocalDate := today.plusDays limitDay.val

/-- `validateDepatureDate(departureDate)`: `null` なら `IllegalArgumentException`。今日 `sysDate` より前か、照会可能期間の
末日（`getSearchLimitDate()`。その中で Clock を読み直した今日 `limitToday` から数える）より後なら
`AtrsBusinessException(E_AR_B1_2001)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#validateDepatureDate(LocalDate)@9b898d66ce284b6a",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateDepatureDate(LocalDate)@ab7abd9ac674d349",
  gap "D-014"]
def validateDepatureDate (limitDay : J32) (sysDate limitToday : JLocalDate) (departureDate : JRef JLocalDate) :
    JResult Unit := do
  let d ← Assert.notNullValue departureDate "departureDate must not null."
  let limitDate := getSearchLimitDate limitDay limitToday
  if java! d.isBefore(sysDate) || d.isAfter(limitDate) then throw (AtrsBusinessException.new (TicketSearchErrorCode.code "e.ar.b1.2001"))

/-- `isAvailableFareType(fareType, depDate)`: 予約可能期間の始まり `depDate − start`・終わり `depDate − end` の
両端を含む範囲に今日があるか。`searchFlight` は呼ばない（同じ条件を SQL の `BETWEEN` で書く。ABS-010）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#isAvailableFareType(FareType,LocalDate)@920d960054ac73a8",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#isAvailableFareType(FareType,LocalDate)@c724cf20ebe62f82",
  gap "D-014"]
def isAvailableFareType (fareType : JRef FareType) (depDate : JRef JLocalDate) (today : JLocalDate) : JResult Bool := do
  let ft ← Assert.notNullValue fareType "fareType must not null."
  let d ← Assert.notNullValue depDate "depDate must not null."
  let s ← ft.rsrvAvailableStartDayNum.deref "rsrvAvailableStartDayNum"
  let e ← ft.rsrvAvailableEndDayNum.deref "rsrvAvailableEndDayNum"
  let startDate := d.minusDays s.val
  let endDate := d.minusDays e.val
  return java! !(today.isBefore(startDate) || today.isAfter(endDate))

/-! ## 選択フライトの検証（予約が使う。backlog aedf）

`validateFlightList` と、それが呼ぶ `existsFlight`・private の検査。フライトの存在の確認は Mapper の文 `exists` を実行する
ので、状態の表に対する計算（`SourceModel.Db.Tx.DbM`）で書く。`InvalidFlightException` のメッセージは、原典ではフライトの
`toString()` を連結するが、写しでは連結しない（メッセージの詳細は [Spec] の自由な選択 N-004 で、α が捨てる）。 -/

open SourceModel.Db.Tx SourceModel.Domain.Repository.Flight SourceModel.Domain.Service.B2

/-- `existsFlight(flight)`: 主キーのフライトがあるか（`flightRepository.exists`）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#existsFlight(Flight)@a4e50b127ec510cf",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#existsFlight(Flight)@3a7ea0432fb7d108"]
def existsFlight (flight : JRef Flight) : DbM Bool := do
  let f ← lift (Assert.notNullValue flight "flight must not null.")
  let fm ← lift (Assert.notNullValue f.flightMaster "flightMaster must not null.")
  FlightRepository.exists f.departureDate fm.flightName f.boardingClass f.fareType

/-- `validateFlightDepartureDateForRoundTripFlight`（private）: 往路便の到着日時に `reserveIntervalTime` 分を足した日時より、
復路便の出発日時が前なら `AtrsBusinessException(E_AR_B2_2001)`。到着時刻は `DateTimeUtil.toLocalDateTime` で読む
（24:00 より後なら `DateTimeParseException`。既知差異 D-031）。 -/
@[gap "D-031"]
def validateFlightDepartureDateForRoundTripFlight (reserveIntervalTime : J32) (outwardFlight homewardFlight : Flight) :
    JResult Unit := do
  let ofm ← outwardFlight.flightMaster.deref "flightMaster"
  let outwardArriveDateTime ← DateTimeUtil.toLocalDateTime outwardFlight.departureDate ofm.arrivalTime
  let reserveAvailableDateTime := outwardArriveDateTime.plusMinutes reserveIntervalTime.val
  let hfm ← homewardFlight.flightMaster.deref "flightMaster"
  let homewardDepartureDateTime ← DateTimeUtil.toLocalDateTime homewardFlight.departureDate hfm.departureTime
  if java! homewardDepartureDateTime.isBefore(reserveAvailableDateTime) then
    throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2001"))

/-- `validateFlightRouteForRoundTripFlight`（private）: 復路が往路の逆区間でなければ `InvalidFlightException`。 -/
def validateFlightRouteForRoundTripFlight (outwardFlight homewardFlight : Flight) : JResult Unit := do
  let ofm ← outwardFlight.flightMaster.deref "flightMaster"
  let hfm ← homewardFlight.flightMaster.deref "flightMaster"
  let outwardRoute ← ofm.route.deref "route"
  let homewardRoute ← hfm.route.deref "route"
  -- `!a.equals(b) || !c.equals(d)`: 受け手の `null` は `NullPointerException`、引数の `null` は `equals` が偽。`||` は短絡する
  let oDep ← (← outwardRoute.departureAirport.deref "departureAirport").code.deref "code"
  let hArr := (← homewardRoute.arrivalAirport.deref "arrivalAirport").code
  if !(some oDep == hArr) then throw (InvalidFlightException.new "homeward route is not outward route reverse")
  let oArr ← (← outwardRoute.arrivalAirport.deref "arrivalAirport").code.deref "code"
  let hDep := (← homewardRoute.departureAirport.deref "departureAirport").code
  if !(some oArr == hDep) then throw (InvalidFlightException.new "homeward route is not outward route reverse")

/-- `validateFlightFareType`（private）: 片道なら往路が片道運賃、往復なら往路・復路が往復運賃。 -/
def validateFlightFareType (flightList : List (JRef Flight)) : JResult Unit := do
  let fareTypeCdOf (f : JRef Flight) : JResult (JRef Spec.Model.FareTypeCd) := do
    let f ← f.deref "flight"
    return (← f.fareType.deref "fareType").fareTypeCd
  match flightList with
  | [o] =>
    let owFareTypeCd ← fareTypeCdOf o
    if !FareTypeUtil.isOneWay owFareTypeCd then throw (InvalidFlightException.new "outward flight fareType is invalid")
  | [o, h] =>
    let owFareTypeCd ← fareTypeCdOf o
    if !FareTypeUtil.isRoundTrip owFareTypeCd then throw (InvalidFlightException.new "outward flight fareType is invalid")
    let hwFareTypeCd ← fareTypeCdOf h
    if !FareTypeUtil.isRoundTrip hwFareTypeCd then throw (InvalidFlightException.new "homeward flight fareType is invalid")
  | _ => throw (InvalidFlightException.new "flightList size must be between 1 and 2")

/-- `validateFlightList(flightList)`: 往路の便マスタと存在、往復なら復路の便マスタと存在・搭乗間隔・逆区間、最後に運賃種別。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateFlightList(List)@31235b0af5e54df0",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#validateFlightList(List)@cab75bbff4478e82", gap "D-031"]
def validateFlightList (reserveIntervalTime : J32) (flightList : JRef (List (JRef Flight))) : DbM Unit := do
  let flights ← lift (Assert.notEmptyValue flightList "flightList must not empty.")
  lift (Assert.isTrue (java! ⟪J32.ofInt flights.length⟫ <= 2) "flightList size must be 2 or less.")
  let outwardFlight ← lift (Assert.notNullValue (← lift (JList.get flights 0)) "outwardFlight must not null.")
  if outwardFlight.flightMaster.isNone then throw (InvalidFlightException.new "flightMaster is null :")
  if !(← existsFlight (some outwardFlight)) then throw (InvalidFlightException.new "flight not found :")
  if flights.length = 2 then
    let homewardFlight ← lift (Assert.notNullValue (← lift (JList.get flights 1)) "homewardFlight must not null.")
    if homewardFlight.flightMaster.isNone then throw (InvalidFlightException.new "flightMaster is null :")
    if !(← existsFlight (some homewardFlight)) then throw (InvalidFlightException.new "flight not found :")
    lift (validateFlightDepartureDateForRoundTripFlight reserveIntervalTime outwardFlight homewardFlight)
    lift (validateFlightRouteForRoundTripFlight outwardFlight homewardFlight)
  lift (validateFlightFareType flights)

end TicketSharedServiceImpl

end SourceModel.Domain.Service.B0
