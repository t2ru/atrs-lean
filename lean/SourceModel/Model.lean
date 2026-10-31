import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Model

原典の domain model（`jp.co.ntt.atrs.domain.model`）の写し。Java の参照・boxed な値は `JRef`（`null` は `none`）、
`int`/`Integer` の値は `J32`、`LocalDate` は `JLocalDate` で表す。
enum（`BoardingClassCd`・`FareTypeCd`・`Gender`）は、構築子が原典と 1 対 1 なので `Spec.Model` の型を使う（ADR 0042）。
getter・setter は欄の参照として写す。
-/

namespace SourceModel.Model

open LangSemantics.Java

/-- `Airport`。 -/
structure Airport where
  code : JRef String := none
  name : JRef String := none
  displayOrder : JRef J32 := none
  deriving Repr, DecidableEq

/-- `Route`。Mapper の `findAll` は所要時間を読まない。 -/
structure Route where
  routeNo : JRef J32 := none
  basicFare : JRef J32 := none
  arrivalAirport : JRef Airport := none
  departureAirport : JRef Airport := none
  deriving Repr, DecidableEq

/-- `Plane`。 -/
structure Plane where
  craftType : JRef String := none
  nSeatNum : JRef J32 := none
  sSeatNum : JRef J32 := none
  deriving Repr, DecidableEq

/-- `FlightMaster`。時刻は `HHmm` の文字列。 -/
structure FlightMaster where
  flightName : JRef String := none
  departureTime : JRef String := none
  arrivalTime : JRef String := none
  route : JRef Route := none
  plane : JRef Plane := none
  deriving Repr, DecidableEq

/-- `BoardingClass`。 -/
structure BoardingClass where
  boardingClassCd : JRef Spec.BoardingClassCd := none
  boardingClassName : JRef String := none
  extraCharge : JRef J32 := none
  deriving Repr, DecidableEq

/-- `FareType`。 -/
structure FareType where
  fareTypeCd : JRef Spec.FareTypeCd := none
  fareTypeName : JRef String := none
  discountRate : JRef J32 := none
  rsrvAvailableStartDayNum : JRef J32 := none
  rsrvAvailableEndDayNum : JRef J32 := none
  passengerMinNum : JRef J32 := none
  deriving Repr, DecidableEq

/-- `PeakTime`。 -/
structure PeakTime where
  peakTimeCd : JRef String := none
  peakStartDate : JRef JLocalDate := none
  peakEndDate : JRef JLocalDate := none
  multiplicationRatio : JRef J32 := none
  deriving Repr, DecidableEq

/-- `Flight`。 -/
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
  gender : JRef Spec.Gender := none
  deriving Repr, DecidableEq

end SourceModel.Model
