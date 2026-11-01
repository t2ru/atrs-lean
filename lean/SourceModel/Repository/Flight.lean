import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Model
import SourceModel.Repository.Schema
import SourceModel.Repository.MasterData
import LangSemantics.Sql.QueryLemmas

/-!
# SourceModel.Repository.Flight

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

namespace SourceModel.Repository.Flight
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Java.Exception LangSemantics.Java.Int

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Repository.Schema SourceModel.Repository.MasterData

/-- `VacantSeatSearchCriteriaDto`（空席照会の条件）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#<init>(LocalDate,Route,BoardingClassCd,Long,List)@da10cbbc34c14874",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBeforeDayNum()@87c12b12578b0d7e",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBoardingClass()@14872a96b272a9e5",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getDepDate()@9e5ad0157d1bece7",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getFareTypeList()@108313590608caad",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getRoute()@bb4d94a040ef721d",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto.serialVersionUID@652bd2782db8027a"]
structure VacantSeatSearchCriteriaDto where
  boardingClass : JRef Spec.Model.BoardingClassCd := none
  depDate : JRef JLocalDate := none
  route : JRef SourceModel.Model.Route := none
  beforeDayNum : JRef J64 := none
  fareTypeList : JRef (List Spec.Model.FareTypeCd) := none
  deriving DecidableEq, Repr

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
  fareTypeList := (c.fareTypeList.getD []).map fun t => .text (SourceModel.Model.fareTypeCdCode t)
  depAirportCd := sqlOf .text ((c.route.bind (·.departureAirport)).bind (·.code))
  arrAirportCd := sqlOf .text ((c.route.bind (·.arrivalAirport)).bind (·.code))
  depDate := sqlOf (fun d => .date d.toEpochDay) c.depDate
  boardingClass := sqlOf (fun b => .text (SourceModel.Model.boardingClassCdName b)) c.boardingClass
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

end SourceModel.Repository.Flight
