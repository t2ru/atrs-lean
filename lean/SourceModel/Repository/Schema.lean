import Trace
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql

/-!
# SourceModel.Repository.Schema

マスタの表の行（`atrs-initdb/src/sqls/integration-test-postgres/00100_create_all_tables.sql`）。
列の型は、処理系が許す範囲を持つ型で写す（ADR c108）: `INT` は `Int4`、`DATE` は `PgDate`、
`VARCHAR(n)` は `Varchar n`、NOT NULL の無い列は `Option`。
主キー・一意制約・外部キーは、行の型には現れない（[Spec] の MD-1〜MD-3 が対応する）。
-/

namespace SourceModel.Repository.Schema

open LangSemantics.Sql.Postgresql

/-- `AIRPORT`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_AIRPORT@33090112cf970113",
  "ddl:00100_create_all_tables.sql#AIRPORT@bf8ca7804ba932ce"]
structure AirportRow where
  airportCd : Varchar 3
  airportName : Varchar 15
  displayOrder : Int4
  deriving DecidableEq, Repr

/-- `ROUTE`。`FLIGHT_TIME` は原典のどの文も読まない。 -/
@[source "ddl:00100_create_all_tables.sql#PK_ROUTE@9b19f26a2b262fa1",
  "ddl:00100_create_all_tables.sql#FK_ROUTE_1@f2f8da7a7846c31e",
  "ddl:00100_create_all_tables.sql#FK_ROUTE_2@2903eca0fa0ebcd3",
  "ddl:00100_create_all_tables.sql#UK_ROUTE_1@32f01bacba919d17",
  "ddl:00100_create_all_tables.sql#IX_ROUTE_1@4b7b42e33ff4788b",
  "ddl:00100_create_all_tables.sql#ROUTE@b26d30be10a7908d"]
structure RouteRow where
  routeNo : Int4
  depAirportCd : Varchar 3
  arrAirportCd : Varchar 3
  flightTime : Varchar 4
  basicFare : Int4
  deriving DecidableEq, Repr

/-- `FLIGHT_MASTER`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_FLIGHT_MASTER@88b87dbbb2237387",
  "ddl:00100_create_all_tables.sql#FK_FLIGHT_MASTER_1@4daa481a0c253ad9",
  "ddl:00100_create_all_tables.sql#FK_FLIGHT_MASTER_2@32419bcbe5e7e96d",
  "ddl:00100_create_all_tables.sql#FLIGHT_MASTER@d92b2c0f805256a1"]
structure FlightMasterRow where
  flightName : Varchar 6
  routeNo : Int4
  departureTime : Varchar 4
  arrivalTime : Varchar 4
  craftType : Varchar 16
  deriving DecidableEq, Repr

/-- `BOARDING_CLASS`。`BOARDING_CLASS_NAME` は NOT NULL でない。 -/
@[source "ddl:00100_create_all_tables.sql#PK_BOARDING_CLASS@ac50cd0d76cd2c66",
  "ddl:00100_create_all_tables.sql#BOARDING_CLASS@74a735596ef8e4ee"]
structure BoardingClassRow where
  boardingClassCd : Varchar 1
  boardingClassName : Option (Varchar 10)
  extraCharge : Int4
  displayOrder : Int4
  deriving DecidableEq, Repr

/-- `FARE_TYPE`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_FARE_TYPE@149b5d905d80158c",
  "ddl:00100_create_all_tables.sql#FARE_TYPE@25297f0a00f0d6fc"]
structure FareTypeRow where
  fareTypeCd : Varchar 4
  fareTypeName : Varchar 10
  discountRate : Int4
  rsrvAvailableStartDayNum : Int4
  rsrvAvailableEndDayNum : Int4
  passengerMinNum : Int4
  displayOrder : Int4
  deriving DecidableEq, Repr

/-- `PEAK_TIME`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_PEAK_TIME@bbba432826561bb6",
  "ddl:00100_create_all_tables.sql#PEAK_TIME@2639ea660139925b"]
structure PeakTimeRow where
  peakTimeCd : Varchar 10
  peakStartDate : PgDate
  peakEndDate : PgDate
  multiplicationRatio : Int4
  deriving DecidableEq, Repr

/-- `PLANE`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_PLANE@1ddda697876bfc78",
  "ddl:00100_create_all_tables.sql#PLANE@31641da45eeb4327"]
structure PlaneRow where
  craftType : Varchar 16
  nSeatNum : Int4
  sSeatNum : Int4
  deriving DecidableEq, Repr

/-- `CREDIT_TYPE`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_CREDIT_TYPE@f4279a12f9998bef",
  "ddl:00100_create_all_tables.sql#CREDIT_TYPE@22a8264dca01d374"]
structure CreditTypeRow where
  creditTypeCd : Varchar 3
  creditFirm : Varchar 80
  displayOrder : Int4
  deriving DecidableEq, Repr

/-- マスタの表の内容（各表は行のバッグ）。 -/
structure MasterDb where
  airport : LangSemantics.Sql.Bag AirportRow := []
  route : LangSemantics.Sql.Bag RouteRow := []
  flightMaster : LangSemantics.Sql.Bag FlightMasterRow := []
  boardingClass : LangSemantics.Sql.Bag BoardingClassRow := []
  fareType : LangSemantics.Sql.Bag FareTypeRow := []
  peakTime : LangSemantics.Sql.Bag PeakTimeRow := []
  plane : LangSemantics.Sql.Bag PlaneRow := []
  creditType : LangSemantics.Sql.Bag CreditTypeRow := []
  deriving DecidableEq, Repr

end SourceModel.Repository.Schema
