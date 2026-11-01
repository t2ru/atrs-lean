import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.PeakTimeProvider
import SourceModel.Domain.Common.Util.FareUtil
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

end TicketSharedServiceImpl

end SourceModel.Domain.Service.B0
