import LangSemantics.Java
import SourceModel.Model
import SourceModel.MasterData

/-!
# SourceModel.Fare

運賃計算の原典（`TicketSharedServiceImpl`・`FareUtil`・`TicketReserveServiceImpl#calculateTotalFare`）の写し。
`int` は `J32`（折り返し）、`double` は `JDouble`、`BigDecimal` の切上げは `bdCeilHundredUp`、
Spring の `Assert` は `IllegalArgumentException`、参照の `null` と `Integer` の unboxing は `NullPointerException` で表す。
[Spec] との差異は D-001・D-002・D-012（`docs/spec/abstraction.md#既知差異`）。
-/

namespace SourceModel.Fare
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java SourceModel.Model SourceModel.MasterData

/-- `TicketSharedServiceImpl` が受ける Provider（`@Inject`）。 -/
structure TicketSharedService where
  boardingClassProvider : BoardingClassProvider := {}
  peakTimeProvider : PeakTimeProvider := {}

/-- `MULTIPLICATION_RATIO_IN_NORMAL_TIME`。 -/
def multiplicationRatioInNormalTime : J32 := J32.ofInt 100

/-- `getMultiplicationRatio`（private）: ピーク時期の積算比率。ピーク時期でなければ 100。 -/
def getMultiplicationRatio (svc : TicketSharedService) (departureDate : JRef JLocalDate) : JResult J32 := do
  match ← getPeakTime svc.peakTimeProvider departureDate with
  | some pt => pt.multiplicationRatio.deref "multiplicationRatio"
  | none => pure multiplicationRatioInNormalTime

/-- `calculateBasicFare`: `(int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl.MULTIPLICATION_RATIO_IN_NORMAL_TIME@48440c4bc2152d40",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@5b0822fe4c6991ac",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateBasicFare(int,BoardingClassCd,LocalDate)@9872678663e9a896",
  gap "D-001", "D-030"]
def calculateBasicFare (svc : TicketSharedService) (basicFareOfRoute : J32) (boardingClassCd : JRef Spec.Model.BoardingClassCd)
    (depDate : JRef JLocalDate) : JResult J32 := do
  jAssert (java! basicFareOfRoute >= 0) "basicFareOfRoute must be 0 or higher."
  jAssert boardingClassCd.isSome "boardingClassCd must not null."
  jAssert depDate.isSome "depDate must not null."
  let boardingClass ← (← getBoardingClass svc.boardingClassProvider boardingClassCd).deref "boardingClass"
  let boardingClassFare ← boardingClass.extraCharge.deref "extraCharge"
  let multiplicationRatio ← getMultiplicationRatio svc depDate
  let basicFare := java! (int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))
  return basicFare

/-- `FareUtil.ceilFare`: `new BigDecimal(fare).setScale(-2, RoundingMode.UP).intValue()`（0 から遠ざかる向きの切上げ）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareUtil.CEIL_FARE_SCALE@cd0475f0dda7e5e1",
  "java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)@345c1d9656b3930c"]
def ceilFare (fare : J32) : J32 := bdCeilHundredUp fare

/-- `calculateFare`: `FareUtil.ceilFare((int) (basicFare * (1 - (discountRate * 0.01))))`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)@1e12eb714e2bc395",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateFare(int,int)@8088a7f2c9efaf7e", gap "D-002"]
def calculateFare (basicFare discountRate : J32) : JResult J32 := do
  jAssert (java! basicFare >= 0) "basicFare must be 0 or higher."
  jAssert (java! discountRate >= 0) "discountRate must be 0 or higher."
  jAssert (java! discountRate <= 100) "discountRate must be 100 or less."
  let fare := java! (int) (basicFare * (1 - (discountRate * 0.01)))
  return ceilFare fare

/-- `TicketReserveServiceImpl` が受ける設定（`@Value`）と、使うサービス。 -/
structure TicketReserveService where
  ticketSharedService : TicketSharedService := {}
  /-- `atrs.adultPassengerMinAge` -/
  adultPassengerMinAge : J32
  /-- `atrs.childFareRate` -/
  childFareRate : J32

/-- `Assert.notEmpty(list)`: `null` か空なら `IllegalArgumentException`。 -/
def assertNotEmpty {α : Type} (xs : JRef (List α)) (message : String) : JResult (List α) :=
  match xs with
  | some (x :: rest) => pure (x :: rest)
  | _ => throw (.illegalArgument message)

/-- `calculateTotalFare`: 小児の人数を数え、フライトごとに `boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum`
を左から int で計算して合計し、最後に `FareUtil.ceilFare` で 100 円単位に切り上げる。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)@35bc5d27ed5f2ca9",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)@ca1a14757ce1cb33", gap "D-003", "D-012"]
def calculateTotalFare (svc : TicketReserveService) (flightList : JRef (List (JRef Flight)))
    (passengerList : JRef (List (JRef Passenger))) : JResult J32 := do
  let flights ← assertNotEmpty flightList "flightList must not empty."
  let passengers ← assertNotEmpty passengerList "passengerList must not empty."
  let mut childNum : J32 := J32.ofInt 0
  for passenger in passengers do
    let passenger ← match passenger with
      | some p => pure p
      | none => throw (.illegalArgument "passenger must not null.")
    let age ← passenger.age.deref "age"
    if java! age < svc.adultPassengerMinAge then childNum := java! childNum + 1
  let adultNum := java! ⟪J32.ofInt passengers.length⟫ - childNum
  let mut totalFare : J32 := J32.ofInt 0
  for flight in flights do
    let flight ← match flight with
      | some f => pure f
      | none => throw (.illegalArgument "flight must not null.")
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

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1000 円（[Spec] は 1100 円）。 -/
theorem calculateFare_1430_30 : ((calculateFare (J32.ofInt 1430) (J32.ofInt 30)).toOption.map (·.val)) = some 1000 := by decide

end SourceModel.Fare
