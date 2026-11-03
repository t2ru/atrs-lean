import Lean.Data.Json
import Spec
import SourceModel
import Tests.Conformance

/-!
# Tests.ConformanceFare

`fare.*` の操作の割当（`docs/spec/conformance.md`）。`Spec` 用と `SourceModel` 用の 2 つの表を、
ベクタの共有入力（`fixtures/master-data.json`・`config.json`）から作る。

- `Spec`: 共有入力を `Spec.MasterData`・`Spec.Config` に読む。`outsideSpec` を付けた行は除く。共有入力が無ければ、空のマスタと既定の設定。
- `SourceModel`: 共有入力の行の順に、Provider のキャッシュ（`HashMap.put`・`List.add`）を作る。
  `fare.totalFare` の `Flight` は、便マスタ・区間・空港・搭乗クラス・運賃種別を引いて組み立てる（Mapper の結果の形）。
-/

open Lean Spec ConformanceKit Tests.Conformance

open ConformanceKit.Runner ConformanceKit.SqlTable LangSemantics.Java.Exception LangSemantics.Java.HashMap
  LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open Spec.CodeList Spec.Config Spec.Model Spec.Prim.Time

namespace Tests.ConformanceFare
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)

def boardingClassCd (s : String) : Except String BoardingClassCd := need (BoardingClassCd.ofCode? s) s!"boarding class: {s}"
def fareTypeCd (s : String) : Except String FareTypeCd := need (FareTypeCd.ofCode? s) s!"fare type: {s}"
def airportCd (s : String) : Except String AirportCd := need (AirportCd.ofString? s) s!"airport code: {s}"
def creditTypeCd (s : String) : Except String CreditTypeCd := need (CreditTypeCd.ofString? s) s!"credit type code: {s}"
def decodeFlightName (s : String) : Except String FlightName := need (FlightName.ofString? s) s!"flight name: {s}"
def decodeMembershipNumber (s : String) : Except String MembershipNumber :=
  need (MembershipNumber.ofString? s) s!"membership number: {s}"

/-! ## Spec -/

def decodeMaster (j : Json) : Except String MasterData := do
  if j.isNull then return { airports := [], routes := [], flightMasters := [], boardingClasses := [], fareTypes := [],
                            peakTimes := [], planes := [], creditTypes := [] }
  let airports ← (← getArr j "airports").mapM fun a => do
    return ({ code := ← airportCd (← getStr a "code"), name := ← getStr a "name", displayOrder := ← getNat a "displayOrder" } : Spec.MasterData.Airport)
  let routes ← (← getArr j "routes").mapM fun r => do
    return ({ routeNo := ← getNat r "routeNo", depAirportCd := ← airportCd (← getStr r "depAirportCd"), arrAirportCd := ← airportCd (← getStr r "arrAirportCd"),
              basicFare := ← getNat r "basicFare" } : Spec.MasterData.Route)
  -- `outsideSpec` の行（Spec の値域の外の時刻。ADR 8f18・ADR ce36。上流のシードには無い）は除く
  let fms := (← getArr j "flightMasters").filter fun f => (f.getObjVal? "outsideSpec").toOption.isNone
  let flightMasters ← fms.mapM fun f => do
    let dep ← getStr f "departureTime"
    let arr ← getStr f "arrivalTime"
    return ({ flightName := ← decodeFlightName (← getStr f "flightName"), routeNo := ← getNat f "routeNo",
              departureTime := ← need (HourMinute.parseHHmm dep) s!"time: {dep}",
              arrivalTime := ← need (ArrivalTime.parseHHmm arr) s!"time: {arr}", craftType := ← getStr f "craftType" } : Spec.MasterData.FlightMaster)
  let boardingClasses ← (← getArr j "boardingClasses").mapM fun b => do
    return ({ boardingClassCd := ← boardingClassCd (← getStr b "boardingClassCd"), boardingClassName := ← getStr b "boardingClassName",
              extraCharge := ← getNat b "extraCharge", displayOrder := ← getNat b "displayOrder" } : Spec.MasterData.BoardingClass)
  let fareTypes ← (← getArr j "fareTypes").mapM fun f => do
    return ({ fareTypeCd := ← fareTypeCd (← getStr f "fareTypeCd"), fareTypeName := ← getStr f "fareTypeName",
              discountRate := ← getNat f "discountRate", rsrvAvailableStartDayNum := ← getNat f "rsrvAvailableStartDayNum",
              rsrvAvailableEndDayNum := ← getNat f "rsrvAvailableEndDayNum", passengerMinNum := ← getNat f "passengerMinNum",
              displayOrder := ← getNat f "displayOrder" } : Spec.MasterData.FareType)
  let peakTimes ← (← getArr j "peakTimes").mapM fun p => do
    return ({ peakTimeCd := ← getStr p "peakTimeCd", peakStartDate := ← decodeDate (← getStr p "peakStartDate"),
              peakEndDate := ← decodeDate (← getStr p "peakEndDate"), multiplicationRatio := ← getNat p "multiplicationRatio" } : Spec.MasterData.PeakTime)
  let planes ← (← getArr j "planes").mapM fun p => do
    return ({ craftType := ← getStr p "craftType", nSeatNum := ← getNat p "nSeatNum", sSeatNum := ← getNat p "sSeatNum" } : Spec.MasterData.Plane)
  let creditTypes ← (← getArr j "creditTypes").mapM fun c => do
    return ({ creditTypeCd := ← creditTypeCd (← getStr c "creditTypeCd"), creditFirm := ← getStr c "creditFirm", displayOrder := ← getNat c "displayOrder" } : Spec.MasterData.CreditType)
  return { airports, routes, flightMasters, boardingClasses, fareTypes, peakTimes, planes, creditTypes }

def decodeConfig (j : Json) : Except String Config := do
  if j.isNull then return Config.default
  let ft ← getStr j "defaultFlightType"
  return {
    limitDay := ← getNat j "limitDay", reserveIntervalTime := ← getNat j "reserveIntervalTime",
    representativeMinAge := ← getNat j "representativeMinAge", adultPassengerMinAge := ← getNat j "adultPassengerMinAge",
    childFareRate := ← getNat j "childFareRate", dateOfBirthMinDate := ← decodeDate (← getStr j "dateOfBirthMinDate"),
    defaultFlightType := ← need (FlightType.ofCode? ft) s!"flight type: {ft}",
    defaultDepAirportCd := ← airportCd (← getStr j "defaultDepAirportCd"),
    defaultArrAirportCd := ← airportCd (← getStr j "defaultArrAirportCd"),
    defaultBoardingClassCd := ← boardingClassCd (← getStr j "defaultBoardingClassCd") }

def specFlight (f : Json) : Except String Flight := do
  return { key := { departureDate := ← decodeDate (← getStr f "departureDate"), flightName := ← decodeFlightName (← getStr f "flightName"),
                    boardingClassCd := ← boardingClassCd (← getStr f "boardingClassCd"),
                    fareTypeCd := ← fareTypeCd (← getStr f "fareTypeCd") }, vacantNum := 0 }

def specPassenger (p : Json) : Except String Passenger := do
  return { familyName := "", givenName := "", age := ← getNat p "age", gender := .M, membershipNumber := none }

/-- `Spec` の `fare.*`。 -/
def specOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let md ← decodeMaster fx.master
  let cfg ← decodeConfig fx.config
  return [
    ("fare.basicFare", fun i => do
      return optJson toJson (Fare.basicFare md (← getNat i "routeBasicFare") (← boardingClassCd (← getStr i "boardingClassCd"))
        (← decodeDate (← getStr i "depDate")))),
    ("fare.fare", fun i => do return toJson (Fare.fare (← getNat i "basicFare") (← getNat i "discountRate"))),
    ("fare.totalFare", fun i => do
      return optJson toJson (Fare.totalFare cfg md (← (← getArr i "flights").mapM specFlight) (← (← getArr i "passengers").mapM specPassenger)))
  ]

/-! ## SourceModel -/

open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl
  SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareUtil SourceModel.Domain.Service.B2 SourceModel.Domain.Service.B2.TicketReserveServiceImpl

def j32 (j : Json) (k : String) : Except String J32 := do return J32.ofInt (← getInt j k)

def jdate (s : String) : Except String JLocalDate := do
  let d ← decodeDate s
  need (JLocalDate.ofYMD? d.year d.month d.day) s!"date: {s}"

def srcBoardingClass (b : Json) : Except String SourceModel.Domain.Model.BoardingClass := do
  return { boardingClassCd := some (← boardingClassCd (← getStr b "boardingClassCd")),
           boardingClassName := some (← getStr b "boardingClassName"), extraCharge := some (← j32 b "extraCharge") }

def srcFareType (f : Json) : Except String SourceModel.Domain.Model.FareType := do
  return { fareTypeCd := some (← fareTypeCd (← getStr f "fareTypeCd")), fareTypeName := some (← getStr f "fareTypeName"),
           discountRate := some (← j32 f "discountRate"), rsrvAvailableStartDayNum := some (← j32 f "rsrvAvailableStartDayNum"),
           rsrvAvailableEndDayNum := some (← j32 f "rsrvAvailableEndDayNum"), passengerMinNum := some (← j32 f "passengerMinNum") }

def srcPeakTime (p : Json) : Except String SourceModel.Domain.Model.PeakTime := do
  return { peakTimeCd := some (← getStr p "peakTimeCd"), peakStartDate := some (← jdate (← getStr p "peakStartDate")),
           peakEndDate := some (← jdate (← getStr p "peakEndDate")), multiplicationRatio := some (← j32 p "multiplicationRatio") }

/-- 共有入力の行の順に作った `TicketSharedServiceImpl`（Provider の `load()` の結果）。 -/
def srcSharedService (master : Json) : Except String TicketSharedServiceImpl := do
  if master.isNull then return {}
  let bcs ← (← getArr master "boardingClasses").mapM fun b => do
    let bc ← srcBoardingClass b
    return (← boardingClassCd (← getStr b "boardingClassCd"), bc)
  let pts ← (← getArr master "peakTimes").mapM srcPeakTime
  return { boardingClassProvider := { boardingClassCodeMap := JHashMap.ofList bcs }, peakTimeProvider := { peakTimeList := pts } }

def findRow (rows : List Json) (k v : String) : Except String Json :=
  need (rows.find? fun r => (getStr r k).toOption == some v) s!"{k} = {v} not found"

/-- 入力のフライト（便名・搭乗日・搭乗クラス・運賃種別）から、Mapper が返す形の `Flight` を組み立てる。 -/
def srcFlight (master : Json) (f : Json) : Except String SourceModel.Domain.Model.Flight := do
  let fm ← findRow (← getArr master "flightMasters") "flightName" (← getStr f "flightName")
  let routeNo ← getNat fm "routeNo"
  let route ← need ((← getArr master "routes").find? fun r => (getNat r "routeNo").toOption == some routeNo) s!"route {routeNo}"
  let airport (cd : String) : Except String SourceModel.Domain.Model.Airport := do
    let a ← findRow (← getArr master "airports") "code" cd
    return { code := some cd, name := some (← getStr a "name") }
  let dep ← airport (← getStr route "depAirportCd")
  let arr ← airport (← getStr route "arrAirportCd")
  let bc ← srcBoardingClass (← findRow (← getArr master "boardingClasses") "boardingClassCd" (← getStr f "boardingClassCd"))
  let ft ← srcFareType (← findRow (← getArr master "fareTypes") "fareTypeCd" (← getStr f "fareTypeCd"))
  return {
    fareType := some ft, departureDate := some (← jdate (← getStr f "departureDate")), boardingClass := some bc,
    flightMaster := some { flightName := some (← getStr fm "flightName"), departureTime := some (← getStr fm "departureTime"),
                           arrivalTime := some (← getStr fm "arrivalTime"), plane := some { craftType := some (← getStr fm "craftType") },
                           route := some { routeNo := some (J32.ofInt routeNo), basicFare := some (← j32 route "basicFare"),
                                           departureAirport := some dep, arrivalAirport := some arr } } }

def javaResult (r : JResult J32) : Except String Json :=
  match r with
  | .ok v => .ok (toJson v.val)
  | .error e => .error s!"java exception: {repr e}"

/-- `SourceModel` の `fare.*`。 -/
def sourceOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let svc ← srcSharedService fx.master
  let cfg ← decodeConfig fx.config
  let reserve : TicketReserveServiceImpl :=
    { ticketSharedService := svc, representativeMinAge := J32.ofInt cfg.representativeMinAge,
      adultPassengerMinAge := J32.ofInt cfg.adultPassengerMinAge,
      childFareRate := J32.ofInt cfg.childFareRate }
  return [
    ("fare.basicFare", fun i => do
      javaResult (calculateBasicFare svc (← j32 i "routeBasicFare") (some (← boardingClassCd (← getStr i "boardingClassCd")))
        (some (← jdate (← getStr i "depDate"))))),
    ("fare.fare", fun i => do javaResult (calculateFare (← j32 i "basicFare") (← j32 i "discountRate"))),
    ("fare.totalFare", fun i => do
      let flights ← (← getArr i "flights").mapM (srcFlight fx.master)
      let passengers ← (← getArr i "passengers").mapM fun p => do return ({ age := some (← j32 p "age") } : SourceModel.Domain.Model.Passenger)
      javaResult (calculateTotalFare reserve (some (flights.map some)) (some (passengers.map some))))
  ]

end Tests.ConformanceFare
