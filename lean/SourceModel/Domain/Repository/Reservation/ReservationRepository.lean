import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Db.Tx
import SourceModel.Domain.Model.BoardingClassCd
import SourceModel.Domain.Model.FareTypeCd
import SourceModel.Domain.Model.Gender
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Model.Reservation
import SourceModel.Domain.Model.ReserveFlight
import Spec.Model

/-!
# SourceModel.Domain.Repository.Reservation.ReservationRepository

原典の `jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/reservation/ReservationRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/reservation/ReservationRepository.xml`）の写し。

予約の登録の 3 つの文（`insert`・`insertReserveFlight`・`insertPassenger`）を写す（backlog aedf）。予約履歴の文は
レポートの backlog（ac71）で足す。

- 各文は `<selectKey order="BEFORE">` で、挿入の前に別の文でシーケンスを進め、結果を引数のオブジェクトの
  `keyProperty` に書き込む。写しでは、書き込んだ後のオブジェクトを返す。シーケンスは取消で戻らない。
- 予約フライト番号・搭乗者番号の `selectKey` は `resultType="Integer"` で、列も `INT` である。シーケンスの値が
  int の範囲を超えると、JDBC の読み出しが失敗する（既知差異 D-009 の範囲）。
- 挿入の検査は PostgreSQL の順に行う（`conformance/sql/reservation.json` の差分実行で確かめた）。
  1. `VALUES` のすべての値を列の型に変換する（`INT`・`DATE` の範囲、`VARCHAR(n)` の長さ。`null` は `NULL`）。
  2. NOT NULL を列の順に検査する。
  3. 主キーの一意性（索引への挿入）。
  4. 外部キー（文の終わりの AFTER ROW トリガ。制約の作成順）。
-/

namespace SourceModel.Domain.Repository.Reservation
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.Postgresql LangSemantics.Sql.Sequence
open SourceModel.Db.Schema
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Domain.Model SourceModel.Db.MyBatis

namespace ReservationRepository

/-- MyBatis の `selectKey` の結果を `Integer` で読めないときの例外（JDBC の `getInt` の失敗を MyBatis が包む）。 -/
def keyReadFailureClass : String := "org.mybatis.spring.MyBatisSystemException"

/-- NOT NULL の `VARCHAR(n)` の列への格納。 -/
def storeText (column : String) (n : Nat) : JRef String → SqlResult (Varchar n)
  | some s => Varchar.ofString column n s
  | none => .error (.notNullViolation column)

/-- `VARCHAR(n)` への型変換（`NULL` はそのまま）。 -/
def convText (column : String) (n : Nat) : JRef String → SqlResult (Option (Varchar n))
  | some s => some <$> Varchar.ofString column n s
  | none => .ok none

/-- `INT` への型変換（`NULL` はそのまま）。 -/
def convInt : JRef J32 → SqlResult (Option Int4)
  | some v => some <$> Int4.ofInt v.val
  | none => .ok none

/-- `DATE` への型変換（`NULL` はそのまま）。 -/
def convDate : JRef JLocalDate → SqlResult (Option PgDate)
  | some d => some <$> date d.toEpochDay
  | none => .ok none

/-- NOT NULL の検査。 -/
def notNull {α : Type} (column : String) : Option α → SqlResult α
  | some a => .ok a
  | none => .error (.notNullViolation column)

/-- `NULLIF(#{…}, '')` を、NULL を許す `VARCHAR(n)` の列に格納する。 -/
def storeNullIf (column : String) (n : Nat) : JRef String → SqlResult (Option (Varchar n))
  | some "" | none => .ok none
  | some s => some <$> Varchar.ofString column n s

/-- NOT NULL の `INT` の列への格納。 -/
def storeInt (column : String) : JRef J32 → SqlResult Int4
  | some v => Int4.ofInt v.val
  | none => .error (.notNullViolation column)

/-- NOT NULL の `DATE` の列への格納。 -/
def storeDate (column : String) : JRef JLocalDate → SqlResult PgDate
  | some d => date d.toEpochDay
  | none => .error (.notNullViolation column)

/-- `SELECT TO_CHAR(NEXTVAL('sq_reservation_1'), 'FM0999999999')`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert@24efe7b0cbd4877c"]
def nextReserveNo (fd : FlightDb) : SqlResult (String × FlightDb) := do
  let (n, st) ← nextval sqReservation fd.sqReservation
  let s := (toChar n "FM0999999999").getD ""
  return (s, { fd with sqReservation := st })

/-- `INSERT INTO reservation (…) VALUES (#{reserveNo}, #{reserveDate}, #{totalFare}, #{repFamilyName}, #{repGivenName},
#{repAge}, #{repGender.code}, #{repTel}, #{repMail}, NULLIF(#{repMember.membershipNumber}, ''))`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert@24efe7b0cbd4877c"]
def insertRow (fd : FlightDb) (r : Reservation) : SqlResult (Nat × FlightDb) := do
  -- 1. 型変換
  let reserveNo ← convText "reserve_no" 10 r.reserveNo
  let reserveDate ← convDate r.reserveDate
  let totalFare ← convInt r.totalFare
  let repFamilyName ← convText "rep_family_name" 10 r.repFamilyName
  let repGivenName ← convText "rep_given_name" 10 r.repGivenName
  let repAge ← convInt r.repAge
  let repGender ← convText "rep_gender" 1 (r.repGender.map Gender.getCode)
  let repTel ← convText "rep_tel" 13 r.repTel
  let repMail ← convText "rep_mail" 256 r.repMail
  let repCustomerNo ← storeNullIf "rep_customer_no" 10 (r.repMember.bind (·.membershipNumber))
  -- 2. NOT NULL
  let row : ReservationRow :=
    { reserveNo := ← notNull "reserve_no" reserveNo, reserveDate := ← notNull "reserve_date" reserveDate,
      totalFare := ← notNull "total_fare" totalFare, repFamilyName := ← notNull "rep_family_name" repFamilyName,
      repGivenName := ← notNull "rep_given_name" repGivenName, repAge := ← notNull "rep_age" repAge,
      repGender := ← notNull "rep_gender" repGender, repTel := ← notNull "rep_tel" repTel,
      repMail := ← notNull "rep_mail" repMail, repCustomerNo }
  -- 3. 主キー
  let rows ← insertUnique (·.reserveNo.val) "PK_RESERVATION" row fd.reservation
  -- 4. 外部キー
  if let some c := row.repCustomerNo then
    if !(fd.member.any fun m => m.customerNo.val == c.val) then throw (.foreignKeyViolation "FK_RESERVATION_1")
  return (1, { fd with reservation := rows })

/-- `int insert(Reservation reservation)`: 予約番号を採番して `reservation.reserveNo` に書き込み、予約を挿入する。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert(Reservation)@3d5880d4f5b24ab0",
  "dep:org.mybatis:mybatis#SelectKeyGenerator@mybatis-3.5.19"]
def insert (reservation : Reservation) : SourceModel.Db.Tx.DbM (J32 × Reservation) := do
  let no ← SourceModel.Db.Tx.sql nextReserveNo
  let r := { reservation with reserveNo := some no }
  let n ← SourceModel.Db.Tx.sql fun fd => insertRow fd r
  pure (J32.ofInt n, r)

/-- `SELECT NEXTVAL('sq_reserve_flight_1')` を `Integer` で読む。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight@c6374f352f5e8516", gap "D-009"]
def nextReserveFlightNo (fd : FlightDb) : SqlResult (Int × FlightDb) := do
  let (n, st) ← nextval sqReserveFlight fd.sqReserveFlight
  return (n, { fd with sqReserveFlight := st })

/-- `INSERT INTO reserve_flight (…) VALUES (#{reserveFlightNo}, #{reserveNo}, #{flight.departureDate},
#{flight.flightMaster.flightName}, #{flight.boardingClass.boardingClassCd}, #{flight.fareType.fareTypeCd})`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight@c6374f352f5e8516",
  "dep:org.mybatis:mybatis#EnumTypeHandler@mybatis-3.5.19"]
def insertReserveFlightRow (fd : FlightDb) (rf : ReserveFlight) : SqlResult (Nat × FlightDb) := do
  let f := rf.flight
  -- 1. 型変換
  let reserveFlightNo ← convInt rf.reserveFlightNo
  let reserveNo ← convText "reserve_no" 10 rf.reserveNo
  let departureDate ← convDate (f.bind (·.departureDate))
  let flightName ← convText "flight_name" 6 ((f.bind (·.flightMaster)).bind (·.flightName))
  let boardingClassCd ← convText "boarding_class_cd" 1
    (((f.bind (·.boardingClass)).bind (·.boardingClassCd)).map BoardingClassCd.name)
  let fareTypeCd ← convText "fare_type_cd" 4 (((f.bind (·.fareType)).bind (·.fareTypeCd)).map FareTypeCd.name)
  -- 2. NOT NULL
  let row : ReserveFlightRow :=
    { reserveFlightNo := ← notNull "reserve_flight_no" reserveFlightNo, reserveNo := ← notNull "reserve_no" reserveNo,
      departureDate := ← notNull "departure_date" departureDate, flightName := ← notNull "flight_name" flightName,
      boardingClassCd := ← notNull "boarding_class_cd" boardingClassCd, fareTypeCd := ← notNull "fare_type_cd" fareTypeCd }
  -- 3. 主キー
  let rows ← insertUnique (·.reserveFlightNo.val) "PK_RESERVE_FLIGHT" row fd.reserveFlight
  -- 4. 外部キー
  if !(fd.reservation.any fun r => r.reserveNo.val == row.reserveNo.val) then
    throw (.foreignKeyViolation "FK_RESERVE_FLIGHT_1")
  if !(fd.flight.any fun x => x.departureDate.val == row.departureDate.val && x.flightName.val == row.flightName.val &&
      x.boardingClassCd.val == row.boardingClassCd.val && x.fareTypeCd.val == row.fareTypeCd.val) then
    throw (.foreignKeyViolation "FK_RESERVE_FLIGHT_2")
  return (1, { fd with reserveFlight := rows })

/-- `Integer` の範囲の値か（JDBC の `getInt`）。 -/
@[source "dep:org.postgresql:postgresql#PgResultSet.getInt@postgresql-42.7.9", gap "D-009"]
def readInteger (n : Int) : JResult J32 :=
  if -2147483648 ≤ n ∧ n ≤ 2147483647 then .ok (J32.ofInt n)
  else .error (.other keyReadFailureClass s!"Bad value for type int : {n}")

/-- `int insertReserveFlight(ReserveFlight reserveFlight)`: 予約フライト番号を採番して書き込み、予約フライトを挿入する。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight(ReserveFlight)@88ff643e818d213a",
  "dep:org.mybatis:mybatis#SelectKeyGenerator@mybatis-3.5.19", gap "D-009"]
def insertReserveFlight (reserveFlight : ReserveFlight) : SourceModel.Db.Tx.DbM (J32 × ReserveFlight) := do
  let no ← SourceModel.Db.Tx.sql nextReserveFlightNo
  let no ← SourceModel.Db.Tx.lift (readInteger no)
  let rf := { reserveFlight with reserveFlightNo := some no }
  let n ← SourceModel.Db.Tx.sql fun fd => insertReserveFlightRow fd rf
  pure (J32.ofInt n, rf)

/-- `SELECT NEXTVAL('sq_passenger_1')` を `Integer` で読む。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger@143c319a42242366", gap "D-009"]
def nextPassengerNo (fd : FlightDb) : SqlResult (Int × FlightDb) := do
  let (n, st) ← nextval sqPassenger fd.sqPassenger
  return (n, { fd with sqPassenger := st })

/-- `INSERT INTO passenger (…) VALUES (#{passengerNo}, #{reserveFlightNo}, #{familyName}, #{givenName}, #{age},
#{gender.code}, NULLIF(#{member.membershipNumber}, ''))`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger@143c319a42242366"]
def insertPassengerRow (fd : FlightDb) (p : Passenger) : SqlResult (Nat × FlightDb) := do
  -- 1. 型変換
  let passengerNo ← convInt p.passengerNo
  let reserveFlightNo ← convInt p.reserveFlightNo
  let familyName ← convText "family_name" 10 p.familyName
  let givenName ← convText "given_name" 10 p.givenName
  let age ← convInt p.age
  let gender ← convText "gender" 1 (p.gender.map Gender.getCode)
  let customerNo ← storeNullIf "customer_no" 10 (p.member.bind (·.membershipNumber))
  -- 2. NOT NULL
  let row : PassengerRow :=
    { passengerNo := ← notNull "passenger_no" passengerNo, reserveFlightNo := ← notNull "reserve_flight_no" reserveFlightNo,
      familyName := ← notNull "family_name" familyName, givenName := ← notNull "given_name" givenName,
      age := ← notNull "age" age, gender := ← notNull "gender" gender, customerNo }
  -- 3. 主キー
  let rows ← insertUnique (·.passengerNo.val) "PK_PASSENGER" row fd.passenger
  -- 4. 外部キー
  if !(fd.reserveFlight.any fun r => r.reserveFlightNo.val == row.reserveFlightNo.val) then
    throw (.foreignKeyViolation "FK_PASSENGER_1")
  if let some c := row.customerNo then
    if !(fd.member.any fun m => m.customerNo.val == c.val) then throw (.foreignKeyViolation "FK_PASSENGER_2")
  return (1, { fd with passenger := rows })

/-- `int insertPassenger(Passenger passenger)`: 搭乗者番号を採番して書き込み、搭乗者を挿入する。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger(Passenger)@1ba685e68ed407bf",
  "dep:org.mybatis:mybatis#SelectKeyGenerator@mybatis-3.5.19", gap "D-009"]
def insertPassenger (passenger : Passenger) : SourceModel.Db.Tx.DbM (J32 × Passenger) := do
  let no ← SourceModel.Db.Tx.sql nextPassengerNo
  let no ← SourceModel.Db.Tx.lift (readInteger no)
  let p := { passenger with passengerNo := some no }
  let n ← SourceModel.Db.Tx.sql fun fd => insertPassengerRow fd p
  pure (J32.ofInt n, p)

end ReservationRepository

end SourceModel.Domain.Repository.Reservation
