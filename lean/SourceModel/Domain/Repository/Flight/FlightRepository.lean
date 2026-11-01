import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import LangSemantics.Sql.QueryLemmas
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Domain.Model.Airport
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.BoardingClassCd
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.FareTypeCd
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Model.Plane
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto
import SourceModel.Domain.Repository.Route.RouteRepository
import Spec.Model

/-!
# SourceModel.Domain.Repository.Flight.FlightRepository

原典の `jp.co.ntt.atrs.domain.repository.flight.FlightRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/flight/FlightRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/flight/FlightRepository.xml`）の写し。

空席照会の Mapper の文 `FlightRepository.findByVacantSeatSearchCriteria`（`FlightRepository.xml`）を、
`LangSemantics.Sql` の演算で写す（backlog 0be7。ADR ce36）。

- 結合（FLIGHT・FARE_TYPE・FLIGHT_MASTER・ROUTE）は、`cross` と `select` で書く（マスタの文と同じ形。ADR c108）。
- 束縛変数 `#{…}` は、Java の値を SQL の値にしたもの（`Params`）として受ける。`null` の参照をたどる式は `NULL` になる。
  enum は `name()` の文字列（`EnumTypeHandler`）、`LocalDate` は `DATE`、`Long` は `bigint` で束縛される。
- `IN (<foreach>)` は `inList` で写す。原典の `FareTypeUtil.getFareTypeCdList` は空の列を返さないので、
  空の `IN ()`（PostgreSQL では構文の誤り）は起きない。
- `ORDER BY ft.display_order ASC, fm.departure_time ASC` は、整列前のバッグ（整列キーの列を持つ）と整列キーを与え、
  許される並びを `isAllowedOrder` で決める。キーの等しい行の相対順序は未規定である。
-/

namespace SourceModel.Domain.Repository.Flight
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Route SourceModel.Domain.Repository.Route.RouteRepository SourceModel.Domain.Repository.Flight
open LangSemantics.Java.Exception LangSemantics.Java.Int
open LangSemantics.Java

open LangSemantics.Java.IntLemmas
open SourceModel.Domain.Model
open SourceModel.Db.MyBatis

namespace FlightRepository

/-- `flightMaster-map` が読む列。 -/
structure FlightMasterResult where
  flightName : Varchar 6
  departureTime : Varchar 4
  arrivalTime : Varchar 4
  craftType : Varchar 16
  route : RouteResult
  deriving DecidableEq, Repr

/-- `SELECT fm.flight_name, fm.departure_time, fm.arrival_time, fm.craft_type, r.route_no, r.basic_fare,
a_dep.airport_cd AS dep_airport_cd, …, a_arr.airport_name AS aar_airport_name
FROM flight_master fm, route r, airport a_dep, airport a_arr
WHERE fm.route_no = r.route_no AND r.dep_airport_cd = a_dep.airport_cd AND r.arr_airport_cd = a_arr.airport_cd` -/
@[source "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster@ebfbc030ba80f150"]
def findAllFlightMaster (db : MasterDb) : Bag FlightMasterResult :=
  Bag.project (fun (((f, r), d), a) => ⟨f.flightName, f.departureTime, f.arrivalTime, f.craftType,
      ⟨r.routeNo, r.basicFare, d.airportCd, d.airportName, a.airportCd, a.airportName⟩⟩)
    (Bag.select (fun (((f, r), d), a) =>
        ((eqInt f.routeNo r.routeNo).and (eqText r.depAirportCd d.airportCd)).and (eqText r.arrAirportCd a.airportCd))
      (Bag.cross (Bag.cross (Bag.cross db.flightMaster db.route) db.airport) db.airport))

/-- 束縛変数の値（`#{criteria.…}` を SQL の値にしたもの）。 -/
structure Params where
  fareTypeList : List SqlValue
  depAirportCd : SqlValue
  arrAirportCd : SqlValue
  depDate : SqlValue
  boardingClass : SqlValue
  beforeDayNum : SqlValue
  deriving DecidableEq, Repr

/-- 参照の値を SQL の値に（`null` は `NULL`）。 -/
def sqlOf {α : Type} (f : α → SqlValue) : JRef α → SqlValue
  | some a => f a
  | none => .null

/-- 束縛（MyBatis の `#{…}` の評価と型ハンドラ）。 -/
@[source "dep:org.mybatis:mybatis#EnumTypeHandler@mybatis-3.5.19"]
def bind (c : VacantSeatSearchCriteriaDto) : Params where
  fareTypeList := (c.fareTypeList.getD []).map fun t => .text (SourceModel.Domain.Model.FareTypeCd.name t)
  depAirportCd := sqlOf .text ((c.route.bind (·.departureAirport)).bind (·.code))
  arrAirportCd := sqlOf .text ((c.route.bind (·.arrivalAirport)).bind (·.code))
  depDate := sqlOf (fun d => .date d.toEpochDay) c.depDate
  boardingClass := sqlOf (fun b => .text (SourceModel.Domain.Model.BoardingClassCd.name b)) c.boardingClass
  beforeDayNum := sqlOf (fun n => .int n.val) c.beforeDayNum

/-- `SELECT f.departure_date, f.flight_name, f.fare_type_cd, f.vacant_num, f.boarding_class_cd` の列。 -/
structure FlightResult where
  departureDate : PgDate
  flightName : Varchar 6
  fareTypeCd : Varchar 4
  vacantNum : Int4
  boardingClassCd : Varchar 1
  deriving DecidableEq, Repr

/-- 整列前の行（結果の列と、整列キーの列 `ft.display_order`・`fm.departure_time`）。 -/
structure VacantSeatRow where
  result : FlightResult
  displayOrder : Int4
  departureTime : Varchar 4
  deriving DecidableEq, Repr

/-- `findByVacantSeatSearchCriteria` の `WHERE` の条件（直積の 1 組について）。
`f.fare_type_cd = ft.fare_type_cd AND f.fare_type_cd IN (…) AND f.flight_name = fm.flight_name AND fm.route_no = r.route_no
AND r.dep_airport_cd = #{…} AND r.arr_airport_cd = #{…} AND f.departure_date = #{…} AND f.boarding_class_cd = #{…}
AND #{beforeDayNum} BETWEEN ft.rsrv_available_end_day_num AND ft.rsrv_available_start_day_num` -/
def vacantSeatCond (p : Params) (t : ((FlightRow × FareTypeRow) × FlightMasterRow) × RouteRow) : Truth :=
  let (((f, ft), fm), r) := t
  (eqText f.fareTypeCd ft.fareTypeCd).and
  ((inList collationC f.fareTypeCd.toSql p.fareTypeList).and
  ((eqText f.flightName fm.flightName).and
  ((eqInt fm.routeNo r.routeNo).and
  ((SqlValue.eq collationC r.depAirportCd.toSql p.depAirportCd).and
  ((SqlValue.eq collationC r.arrAirportCd.toSql p.arrAirportCd).and
  ((SqlValue.eq collationC f.departureDate.toSql p.depDate).and
  ((SqlValue.eq collationC f.boardingClassCd.toSql p.boardingClass).and
  (between collationC p.beforeDayNum ft.rsrvAvailableEndDayNum.toSql ft.rsrvAvailableStartDayNum.toSql))))))))

/-- `SELECT f.departure_date, f.flight_name, f.fare_type_cd, f.vacant_num, f.boarding_class_cd` と、整列キーの列。 -/
def vacantSeatProj (t : ((FlightRow × FareTypeRow) × FlightMasterRow) × RouteRow) : VacantSeatRow :=
  let (((f, ft), fm), _) := t
  ⟨⟨f.departureDate, f.flightName, f.fareTypeCd, f.vacantNum, f.boardingClassCd⟩, ft.displayOrder, fm.departureTime⟩

/-- `findByVacantSeatSearchCriteria` の整列前の結果（`FROM flight f, fare_type ft, flight_master fm, route r WHERE …`）。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria@2fbe03024cd7d231"]
def vacantSeatRows (db : MasterDb) (fd : FlightDb) (p : Params) : Bag VacantSeatRow :=
  Bag.project vacantSeatProj
    (Bag.select (vacantSeatCond p) (Bag.cross (Bag.cross (Bag.cross fd.flight db.fareType) db.flightMaster) db.route))

/-- FLIGHT の行だけで決まる条件（運賃種別の `IN`・出発日・搭乗クラス）。 -/
def flightPre (p : Params) (f : FlightRow) : Bool :=
  (inList collationC f.fareTypeCd.toSql p.fareTypeList).holds &&
    (SqlValue.eq collationC f.departureDate.toSql p.depDate).holds &&
    (SqlValue.eq collationC f.boardingClassCd.toSql p.boardingClass).holds

/-- 評価用: FLIGHT の行を `flightPre` で先に絞ってから同じ文を評価する（全件の直積を避ける。テストの差分実行に使う）。 -/
def vacantSeatRowsOn (db : MasterDb) (fd : FlightDb) (p : Params) : Bag VacantSeatRow :=
  vacantSeatRows db ⟨fd.flight.filter (flightPre p)⟩ p

/-- 条件の押し下げ: 先に絞っても、文の結果は変わらない。 -/
theorem vacantSeatRows_eq_on (db : MasterDb) (fd : FlightDb) (p : Params) :
    vacantSeatRows db fd p = vacantSeatRowsOn db fd p := by
  unfold vacantSeatRowsOn vacantSeatRows
  congr 1
  rw [LangSemantics.Sql.QueryLemmas.cross_filter_left fd.flight db.fareType,
    LangSemantics.Sql.QueryLemmas.cross_filter_left _ db.flightMaster,
    LangSemantics.Sql.QueryLemmas.cross_filter_left _ db.route]
  apply LangSemantics.Sql.QueryLemmas.select_filter_of_imp
  intro ⟨⟨⟨f, ft⟩, fm⟩, r⟩ ht
  simp only [vacantSeatCond, Truth.holds_and, Bool.and_eq_true] at ht
  simp only [flightPre, Bool.and_eq_true]
  exact ⟨⟨ht.2.1, ht.2.2.2.2.2.2.1⟩, ht.2.2.2.2.2.2.2.1⟩

/-- `ORDER BY ft.display_order ASC, fm.departure_time ASC` の整列キー。 -/
def vacantSeatKey (r : VacantSeatRow) : List SqlValue := [r.displayOrder.toSql, r.departureTime.toSql]

/-- 整列の向き。 -/
def vacantSeatDirs : List SortDir := [.asc, .asc]

/-- 並べ方 `sortRows`（整列前の行の列から、並べた列を返す）が、どの結果についても `ORDER BY` の許される並びを返す。 -/
def SortAllowed (sortRows : List VacantSeatRow → List VacantSeatRow) : Prop :=
  ∀ rows, isAllowedOrder sortCfg vacantSeatDirs vacantSeatKey rows (sortRows rows) = true

/-- 標準の並べ方（安定整列。テストと参照に使う）。 -/
def standardSort (rows : List VacantSeatRow) : List VacantSeatRow :=
  orderByStable sortCfg vacantSeatDirs vacantSeatKey rows

/-- `flightMaster-map`（1 行分）。 -/
def flightMasterMap (f : FlightMasterResult) : FlightMaster :=
  { flightName := str f.flightName, departureTime := str f.departureTime, arrivalTime := str f.arrivalTime,
    plane := some { craftType := str f.craftType }, route := some (RouteRepository.routeMap f.route) }

/-- `flightMaster-map`: 入れ子の対応なので、`<id>`（`flight_name`）が同じ行は最初の 1 つにまとめる。 -/
def flightMasters (rows : List FlightMasterResult) : List FlightMaster :=
  (rows.foldl (fun (acc : List FlightMasterResult) r =>
    if acc.any (fun a => a.flightName.val == r.flightName.val) then acc else acc ++ [r]) []).map FlightRepository.flightMasterMap

/-- `flight-map`（`FlightRepository.findByVacantSeatSearchCriteria` の結果）。入れ子の対応が無いので、行をまとめない。
便マスタ・運賃種別・搭乗クラスは、コードだけを入れた値になる（`searchFlight` が Provider で詰め直す）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria(VacantSeatSearchCriteriaDto)@642c24ce08bfe364"]
def flightMap (r : SourceModel.Domain.Repository.Flight.FlightRepository.FlightResult) : JResult Flight := do
  let bc ← BoardingClassCd.valueOf r.boardingClassCd.val
  let ft ← FareTypeCd.valueOf r.fareTypeCd.val
  return { departureDate := date r.departureDate, flightMaster := some { flightName := str r.flightName },
           boardingClass := some { boardingClassCd := some bc }, fareType := some { fareTypeCd := some ft },
           vacantNum := int r.vacantNum }

end FlightRepository

end SourceModel.Domain.Repository.Flight
