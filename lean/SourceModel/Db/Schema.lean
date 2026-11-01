import Trace
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql

/-!
# SourceModel.Db.Schema

マスタの表と FLIGHT の表の行（`atrs-initdb/src/sqls/integration-test-postgres/00100_create_all_tables.sql`）。
列の型は、処理系が許す範囲を持つ型で写す（ADR c108）: `INT` は `Int4`、`DATE` は `PgDate`、
`VARCHAR(n)` は `Varchar n`、NOT NULL の無い列は `Option`。
主キー・一意制約・外部キーは、行の型には現れない（[Spec] の MD-1〜MD-3、`World.Inv`（主キー）・`World.RefMaster`（FK_FLIGHT）が対応する）。
-/

namespace SourceModel.Db.Schema
open LangSemantics.Sql.Core LangSemantics.Sql.Query
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

/-- `FLIGHT`（フライト。予約で空席数が変わる。マスタでなく状態の表。ADR ce36）。 -/
@[source "ddl:00100_create_all_tables.sql#PK_FLIGHT@75e469d15a6da12e",
  "ddl:00100_create_all_tables.sql#FK_FLIGHT_1@2d0e26c837cc8f79",
  "ddl:00100_create_all_tables.sql#FK_FLIGHT_2@d395df3615466997",
  "ddl:00100_create_all_tables.sql#FK_FLIGHT_3@d4327a6873ccf4c0",
  "ddl:00100_create_all_tables.sql#FLIGHT@97fb492b5adfbec4"]
structure FlightRow where
  departureDate : PgDate
  flightName : Varchar 6
  boardingClassCd : Varchar 1
  fareTypeCd : Varchar 4
  vacantNum : Int4
  deriving DecidableEq, Repr

/-- `MEMBER`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_MEMBER@0ef1b6d6f5d103cb", "ddl:00100_create_all_tables.sql#FK_MEMBER_1@f973f6fb19c6579a",
  "ddl:00100_create_all_tables.sql#MEMBER@27ed37725641693d"]
structure MemberRow where
  customerNo : Varchar 10
  kanjiFamilyName : Varchar 10
  kanjiGivenName : Varchar 10
  kanaFamilyName : Varchar 10
  kanaGivenName : Varchar 10
  birthday : PgDate
  gender : Varchar 1
  tel : Varchar 13
  zipCode : Varchar 7
  address : Varchar 60
  mail : Varchar 256
  creditNo : Varchar 16
  creditTypeCd : Varchar 3
  creditTerm : Varchar 5
  deriving DecidableEq, Repr

/-- `MEMBER_LOGIN`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_MEMBER_LOGIN@946bc5e00f703c39", "ddl:00100_create_all_tables.sql#FK_MEMBER_LOGIN_1@1759f86c859d73ff",
  "ddl:00100_create_all_tables.sql#MEMBER_LOGIN@c876b54c793bc20b"]
structure MemberLoginRow where
  customerNo : Varchar 10
  password : Varchar 124
  lastPassword : Option (Varchar 124)
  loginDateTime : Option PgTimestamp
  loginFlg : Bool
  deriving DecidableEq, Repr

/-- `RESERVATION`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_RESERVATION@bd7d930ed9b812f9", "ddl:00100_create_all_tables.sql#FK_RESERVATION_1@dc02d22353059eb2",
  "ddl:00100_create_all_tables.sql#RESERVATION@b760349f34b7abf9"]
structure ReservationRow where
  reserveNo : Varchar 10
  reserveDate : PgDate
  totalFare : Int4
  repFamilyName : Varchar 10
  repGivenName : Varchar 10
  repAge : Int4
  repGender : Varchar 1
  repTel : Varchar 13
  repMail : Varchar 256
  repCustomerNo : Option (Varchar 10)
  deriving DecidableEq, Repr

/-- `RESERVE_FLIGHT`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_RESERVE_FLIGHT@61fc69db73a3d3f9", "ddl:00100_create_all_tables.sql#FK_RESERVE_FLIGHT_1@3326d08660a32a50",
  "ddl:00100_create_all_tables.sql#FK_RESERVE_FLIGHT_2@0fa426c3b4f30b61", "ddl:00100_create_all_tables.sql#RESERVE_FLIGHT@bbf4d320c62e6860"]
structure ReserveFlightRow where
  reserveFlightNo : Int4
  reserveNo : Varchar 10
  departureDate : PgDate
  flightName : Varchar 6
  boardingClassCd : Varchar 1
  fareTypeCd : Varchar 4
  deriving DecidableEq, Repr

/-- `PASSENGER`。 -/
@[source "ddl:00100_create_all_tables.sql#PK_PASSENGER@a65be50c47900082", "ddl:00100_create_all_tables.sql#FK_PASSENGER_1@73e9ec7955ed6537",
  "ddl:00100_create_all_tables.sql#FK_PASSENGER_2@38e248347f807a22", "ddl:00100_create_all_tables.sql#PASSENGER@798b3b804ed44e20"]
structure PassengerRow where
  passengerNo : Int4
  reserveFlightNo : Int4
  familyName : Varchar 10
  givenName : Varchar 10
  age : Int4
  gender : Varchar 1
  customerNo : Option (Varchar 10)
  deriving DecidableEq, Repr

/-- シーケンス（`CREATE SEQUENCE … CYCLE`）。 -/
@[source "ddl:00100_create_all_tables.sql#SQ_MEMBER_1@fca537c311ef1688", "ddl:00100_create_all_tables.sql#SQ_RESERVATION_1@280c70c2218d134c",
  "ddl:00100_create_all_tables.sql#SQ_RESERVE_FLIGHT_1@c7bb105cb9521b63", "ddl:00100_create_all_tables.sql#SQ_PASSENGER_1@331c9fe98f49d0a3"]
def sqMember : LangSemantics.Sql.Sequence.SequenceDef := { name := "sq_member_1", maxValue := 9999999999, cycle := true }
@[inherit_doc sqMember]
def sqReservation : LangSemantics.Sql.Sequence.SequenceDef :=
  { name := "sq_reservation_1", maxValue := 9999999999, cycle := true }
@[inherit_doc sqMember]
def sqReserveFlight : LangSemantics.Sql.Sequence.SequenceDef :=
  { name := "sq_reserve_flight_1", maxValue := 999999999999, cycle := true }
@[inherit_doc sqMember]
def sqPassenger : LangSemantics.Sql.Sequence.SequenceDef :=
  { name := "sq_passenger_1", maxValue := 9999999999999, cycle := true }

/-- 状態の表とシーケンスの内容（FLIGHT・MEMBER・MEMBER_LOGIN・RESERVATION・RESERVE_FLIGHT・PASSENGER と、4 つの
シーケンスの状態）。[Spec] の `World` に対応する（ADR ce36、backlog aedf）。列の型の範囲は [Spec] の型より広く
（負の空席数など）、[Spec] の型で表せる状態に限ることは既知差異 D-027 の前提である（ADR cdb6）。
シーケンスの状態は、トランザクションの取消で巻き戻らない。 -/
@[gap "D-027"]
structure FlightDb where
  flight : LangSemantics.Sql.Query.Bag FlightRow := []
  member : LangSemantics.Sql.Query.Bag MemberRow := []
  memberLogin : LangSemantics.Sql.Query.Bag MemberLoginRow := []
  reservation : LangSemantics.Sql.Query.Bag ReservationRow := []
  reserveFlight : LangSemantics.Sql.Query.Bag ReserveFlightRow := []
  passenger : LangSemantics.Sql.Query.Bag PassengerRow := []
  sqMember : LangSemantics.Sql.Sequence.SequenceState := none
  sqReservation : LangSemantics.Sql.Sequence.SequenceState := none
  sqReserveFlight : LangSemantics.Sql.Sequence.SequenceState := none
  sqPassenger : LangSemantics.Sql.Sequence.SequenceState := none
  deriving DecidableEq, Repr

namespace FlightDb

/-- トランザクションの取消: 表は開始時の値に戻し、シーケンスは終了時の値のままにする。 -/
@[source "dep:org.springframework:spring-tx#Transactional@spring-tx-7.0.3"]
def rollback (start stop : FlightDb) : FlightDb :=
  { start with sqMember := stop.sqMember, sqReservation := stop.sqReservation,
               sqReserveFlight := stop.sqReserveFlight, sqPassenger := stop.sqPassenger }

end FlightDb

/-- マスタの表の内容（各表は行のバッグ）。 -/
structure MasterDb where
  airport : LangSemantics.Sql.Query.Bag AirportRow := []
  route : LangSemantics.Sql.Query.Bag RouteRow := []
  flightMaster : LangSemantics.Sql.Query.Bag FlightMasterRow := []
  boardingClass : LangSemantics.Sql.Query.Bag BoardingClassRow := []
  fareType : LangSemantics.Sql.Query.Bag FareTypeRow := []
  peakTime : LangSemantics.Sql.Query.Bag PeakTimeRow := []
  plane : LangSemantics.Sql.Query.Bag PlaneRow := []
  creditType : LangSemantics.Sql.Query.Bag CreditTypeRow := []
  deriving DecidableEq, Repr

/-- 文字列の列の等号（`a = b`。照合順序 C）。 -/
def eqText {m n : Nat} (a : Varchar m) (b : Varchar n) : Truth := SqlValue.eq collationC a.toSql b.toSql

/-- 整数の列の等号。 -/
def eqInt (a b : Int4) : Truth := SqlValue.eq collationC a.toSql b.toSql

/-- 整列の設定（PostgreSQL の既定。照合順序 C）。 -/
def sortCfg : SortConfig := sortConfig

/-- `ORDER BY display_order ASC` の整列キー。 -/
def orderKey {α : Type} (displayOrder : α → Int4) (r : α) : List SqlValue := [(displayOrder r).toSql]

end SourceModel.Db.Schema
