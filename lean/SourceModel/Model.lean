import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Model

原典の domain model（`jp.co.ntt.atrs.domain.model`）の写し。Java の参照・boxed な値は `JRef`（`null` は `none`）、
`int`/`Integer` の値は `J32`、`LocalDate` は `JLocalDate` で表す。
enum（`BoardingClassCd`・`FareTypeCd`・`Gender`）は、構築子が原典と 1 対 1 なので `Spec.Model` の型を使う（ADR 8f18）。
getter・setter は欄の参照として写す。
-/

namespace SourceModel.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java

/-- enum の名前（`Enum.name()`。MyBatis の `EnumTypeHandler` が束縛する値）。原典の `BoardingClassCd` は定数名と
`getCode()` が同じ。 -/
def boardingClassCdName : Spec.Model.BoardingClassCd → String
  | .N => "N" | .S => "S"

/-- `FareTypeCd.getCode()`（定数名 `Enum.name()` と同じ）。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()@3855e45998af62f8"]
def fareTypeCdCode : Spec.Model.FareTypeCd → String
  | .OW => "OW" | .RT => "RT" | .RD1 => "RD1" | .RD7 => "RD7" | .ED => "ED"
  | .LD => "LD" | .GD => "GD" | .SOW => "SOW" | .SRT => "SRT" | .SRD => "SRD"

/-- `Airport`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Airport#getCode()@da85740cb21790bb",
  "java:jp.co.ntt.atrs.domain.model.Airport#getDisplayOrder()@15b3aeb33df2350d",
  "java:jp.co.ntt.atrs.domain.model.Airport#getName()@36c200189d0d5290",
  "java:jp.co.ntt.atrs.domain.model.Airport#setCode(String)@fe06ceaece4b0839",
  "java:jp.co.ntt.atrs.domain.model.Airport#setDisplayOrder(Integer)@811041ac15b071c0",
  "java:jp.co.ntt.atrs.domain.model.Airport#setName(String)@d75eb48ec8bce02e",
  "java:jp.co.ntt.atrs.domain.model.Airport#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Airport.serialVersionUID@8bae105bbb3f3f93"]
structure Airport where
  code : JRef String := none
  name : JRef String := none
  displayOrder : JRef J32 := none
  deriving Repr, DecidableEq

/-- `Route`。Mapper の `findAll` は所要時間を読まない。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Route#getArrivalAirport()@e4e63cfd9aa52b7c",
  "java:jp.co.ntt.atrs.domain.model.Route#getBasicFare()@89a978cfeb517ad4",
  "java:jp.co.ntt.atrs.domain.model.Route#getDepartureAirport()@c52377ce8cec2f3c",
  "java:jp.co.ntt.atrs.domain.model.Route#getRouteNo()@4c60bbfe1a09e09b",
  "java:jp.co.ntt.atrs.domain.model.Route#setArrivalAirport(Airport)@8f997e7447e48706",
  "java:jp.co.ntt.atrs.domain.model.Route#setBasicFare(Integer)@dcef121f022ac443",
  "java:jp.co.ntt.atrs.domain.model.Route#setDepartureAirport(Airport)@ba74485411a2bc4f",
  "java:jp.co.ntt.atrs.domain.model.Route#setRouteNo(Integer)@a9c754e56f9d626c",
  "java:jp.co.ntt.atrs.domain.model.Route#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Route.serialVersionUID@e55e25f5719b321f"]
structure Route where
  routeNo : JRef J32 := none
  basicFare : JRef J32 := none
  arrivalAirport : JRef Airport := none
  departureAirport : JRef Airport := none
  deriving Repr, DecidableEq

/-- `Plane`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Plane#getCraftType()@01576ceec214b3c8",
  "java:jp.co.ntt.atrs.domain.model.Plane#getNSeatNum()@f5d712d167c0596e",
  "java:jp.co.ntt.atrs.domain.model.Plane#getSSeatNum()@99c381dae97878b5",
  "java:jp.co.ntt.atrs.domain.model.Plane#setCraftType(String)@91f4b11b9bd54c75",
  "java:jp.co.ntt.atrs.domain.model.Plane#setNSeatNum(Integer)@6e34b482ab4e2e96",
  "java:jp.co.ntt.atrs.domain.model.Plane#setSSeatNum(Integer)@a1d12f387b95199b",
  "java:jp.co.ntt.atrs.domain.model.Plane#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Plane.serialVersionUID@ee869d61bf2fce1b"]
structure Plane where
  craftType : JRef String := none
  nSeatNum : JRef J32 := none
  sSeatNum : JRef J32 := none
  deriving Repr, DecidableEq

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

/-- `BoardingClass`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassName()@a4962e4cdd7f7b0b",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#getExtraCharge()@c2ed357f647cbb3f",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassName(String)@11476b38898738b2",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setExtraCharge(Integer)@a9a095c60eef4b98",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass.serialVersionUID@7a425c3cfaa07f43"]
structure BoardingClass where
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  boardingClassName : JRef String := none
  extraCharge : JRef J32 := none
  deriving Repr, DecidableEq

/-- `FareType`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareType#getDiscountRate()@ed3dd8409edfd508",
  "java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeCd()@0ad0a31bd0da4f1d",
  "java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeName()@fe0943673fcac4f0",
  "java:jp.co.ntt.atrs.domain.model.FareType#getPassengerMinNum()@a825d94771937aa7",
  "java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableEndDayNum()@c72ad3c4851e2bbf",
  "java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableStartDayNum()@14927cc7d58ca59b",
  "java:jp.co.ntt.atrs.domain.model.FareType#setDiscountRate(Integer)@5d282bd1a68ca907",
  "java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeCd(FareTypeCd)@028d6508ed1eadd9",
  "java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeName(String)@a37098988b7af7bb",
  "java:jp.co.ntt.atrs.domain.model.FareType#setPassengerMinNum(Integer)@2f6371e03bcf7124",
  "java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableEndDayNum(Integer)@96031ccbe007803c",
  "java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableStartDayNum(Integer)@f740fe7fa648536d",
  "java:jp.co.ntt.atrs.domain.model.FareType#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.FareType.serialVersionUID@7ac4c51a2e13b2a2"]
structure FareType where
  fareTypeCd : JRef Spec.Model.FareTypeCd := none
  fareTypeName : JRef String := none
  discountRate : JRef J32 := none
  rsrvAvailableStartDayNum : JRef J32 := none
  rsrvAvailableEndDayNum : JRef J32 := none
  passengerMinNum : JRef J32 := none
  deriving Repr, DecidableEq

/-- `PeakTime`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.PeakTime#getMultiplicationRatio()@0b4e159bab8a2bad",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakEndDate()@3320372937ffb1c6",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakStartDate()@8c5afe3863a52476",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakTimeCd()@bf567cee012c32c7",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setMultiplicationRatio(Integer)@2a4c3f761ef3b3ac",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakEndDate(LocalDate)@7d72acc8b47d2285",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakStartDate(LocalDate)@a620abe6a1283db9",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakTimeCd(String)@df6461ab2c7d6c5e",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.PeakTime.serialVersionUID@2f2b16014969a5f5"]
structure PeakTime where
  peakTimeCd : JRef String := none
  peakStartDate : JRef JLocalDate := none
  peakEndDate : JRef JLocalDate := none
  multiplicationRatio : JRef J32 := none
  deriving Repr, DecidableEq

/-- `Flight`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Flight#getBoardingClass()@590aaacf8b6bb288",
  "java:jp.co.ntt.atrs.domain.model.Flight#getDepartureDate()@5fac0b39eeb51c0a",
  "java:jp.co.ntt.atrs.domain.model.Flight#getFareType()@70c7e2748ef109e1",
  "java:jp.co.ntt.atrs.domain.model.Flight#getFlightMaster()@9870269e2c0916c0",
  "java:jp.co.ntt.atrs.domain.model.Flight#getVacantNum()@1727d00958d6c3a3",
  "java:jp.co.ntt.atrs.domain.model.Flight#setBoardingClass(BoardingClass)@4881f219e0e20946",
  "java:jp.co.ntt.atrs.domain.model.Flight#setDepartureDate(LocalDate)@596fcb7473f9f84f",
  "java:jp.co.ntt.atrs.domain.model.Flight#setFareType(FareType)@1ced11692bc11e36",
  "java:jp.co.ntt.atrs.domain.model.Flight#setFlightMaster(FlightMaster)@8563a05050c6b001",
  "java:jp.co.ntt.atrs.domain.model.Flight#setVacantNum(Integer)@29bf39575d8c8abb",
  "java:jp.co.ntt.atrs.domain.model.Flight#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Flight.serialVersionUID@943c963ca9c1a2b3"]
structure Flight where
  fareType : JRef FareType := none
  departureDate : JRef JLocalDate := none
  vacantNum : JRef J32 := none
  flightMaster : JRef FlightMaster := none
  boardingClass : JRef BoardingClass := none
  deriving Repr, DecidableEq

/-- `Passenger`。会員（`member`）は、予約の backlog で足す。 -/
structure Passenger where
  passengerNo : JRef J32 := none
  reserveFlightNo : JRef J32 := none
  familyName : JRef String := none
  givenName : JRef String := none
  age : JRef J32 := none
  gender : JRef Spec.Model.Gender := none
  deriving Repr, DecidableEq

end SourceModel.Model
