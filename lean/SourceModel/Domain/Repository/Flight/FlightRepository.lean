import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import LangSemantics.Sql.QueryLemmas
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Db.Tx
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

/-- 評価用: `findAllFlightMaster` の条件を直積の各段に押し下げた形（入れ子ループの結合）。行の並びも含めて等しく
（`findAllFlightMaster_eq_join`）、`@[csimp]` でコンパイル後のコードだけをこれに差し替える。意味論の定義は `findAllFlightMaster`。 -/
def findAllFlightMasterJoin (db : MasterDb) : Bag FlightMasterResult :=
  Bag.project (fun (((f, r), d), a) => ⟨f.flightName, f.departureTime, f.arrivalTime, f.craftType,
      ⟨r.routeNo, r.basicFare, d.airportCd, d.airportName, a.airportCd, a.airportName⟩⟩)
    (Bag.crossWhere (fun t a => (eqText t.1.2.arrAirportCd a.airportCd).holds)
      (Bag.crossWhere (fun t d => (eqText t.2.depAirportCd d.airportCd).holds)
        (Bag.crossWhere (fun f r => (eqInt f.routeNo r.routeNo).holds) db.flightMaster db.route) db.airport) db.airport)

/-- `findAllFlightMaster` の評価用の実装（条件の押し下げ）。 -/
@[csimp] theorem findAllFlightMaster_eq_join : @findAllFlightMaster = @findAllFlightMasterJoin := by
  funext db
  unfold findAllFlightMaster findAllFlightMasterJoin
  rw [LangSemantics.Sql.QueryLemmas.select_cross_split _ _ _ (fun t => (eqInt t.1.1.routeNo t.1.2.routeNo).holds && (eqText t.1.2.depAirportCd t.2.airportCd).holds)
        (fun t a => (eqText t.1.2.arrAirportCd a.airportCd).holds) (fun ⟨⟨_, _⟩, _⟩ _ => by simp [Truth.holds_and]),
      LangSemantics.Sql.QueryLemmas.filter_cross_split _ _ _ (fun t => (eqInt t.1.routeNo t.2.routeNo).holds) (fun t d => (eqText t.2.depAirportCd d.airportCd).holds)
        (fun ⟨_, _⟩ _ => rfl),
      LangSemantics.Sql.QueryLemmas.filter_cross_split _ _ _ (fun _ => true) (fun f r => (eqInt f.routeNo r.routeNo).holds) (fun _ _ => by simp),
      show db.flightMaster.filter (fun _ => true) = db.flightMaster from List.filter_eq_self.mpr fun _ _ => rfl]

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

/-- 評価用: `vacantSeatRows` の条件を直積の各段に押し下げた形（入れ子ループの結合）。FLIGHT の行だけの条件（`flightPre`）、
運賃種別との条件、便マスタとの条件、区間との条件の順に評価する。行の並びも含めて等しく（`vacantSeatRows_eq_join`）、
`@[csimp]` でコンパイル後のコードだけをこれに差し替える。意味論の定義は `vacantSeatRows`。 -/
def vacantSeatRowsJoin (db : MasterDb) (fd : FlightDb) (p : Params) : Bag VacantSeatRow :=
  Bag.project vacantSeatProj
    (Bag.crossWhere (fun t r => ((eqInt t.2.routeNo r.routeNo).and
          ((SqlValue.eq collationC r.depAirportCd.toSql p.depAirportCd).and
          (SqlValue.eq collationC r.arrAirportCd.toSql p.arrAirportCd))).holds)
      (Bag.crossWhere (fun t fm => (eqText t.1.flightName fm.flightName).holds)
        (Bag.crossWhere (fun f ft => ((eqText f.fareTypeCd ft.fareTypeCd).and
              (between collationC p.beforeDayNum ft.rsrvAvailableEndDayNum.toSql ft.rsrvAvailableStartDayNum.toSql)).holds)
          (fd.flight.filter (flightPre p)) db.fareType) db.flightMaster) db.route)

/-- `vacantSeatRows` の評価用の実装（条件の押し下げ）。 -/
@[csimp] theorem vacantSeatRows_eq_join : @vacantSeatRows = @vacantSeatRowsJoin := by
  funext db fd p
  unfold vacantSeatRows vacantSeatRowsJoin
  rw [LangSemantics.Sql.QueryLemmas.select_cross_split _ _ (vacantSeatCond p)
      (fun t => (flightPre p t.1.1 && ((eqText t.1.1.fareTypeCd t.1.2.fareTypeCd).and
          (between collationC p.beforeDayNum t.1.2.rsrvAvailableEndDayNum.toSql t.1.2.rsrvAvailableStartDayNum.toSql)).holds) &&
        (eqText t.1.1.flightName t.2.flightName).holds)
      (fun t r => ((eqInt t.2.routeNo r.routeNo).and
          ((SqlValue.eq collationC r.depAirportCd.toSql p.depAirportCd).and
          (SqlValue.eq collationC r.arrAirportCd.toSql p.arrAirportCd))).holds) ?h3,
    LangSemantics.Sql.QueryLemmas.filter_cross_split _ _ _
      (fun t => flightPre p t.1 && ((eqText t.1.fareTypeCd t.2.fareTypeCd).and
          (between collationC p.beforeDayNum t.2.rsrvAvailableEndDayNum.toSql t.2.rsrvAvailableStartDayNum.toSql)).holds)
      (fun t fm => (eqText t.1.flightName fm.flightName).holds) (fun _ _ => rfl),
    LangSemantics.Sql.QueryLemmas.filter_cross_split _ _ _ (flightPre p)
      (fun f ft => ((eqText f.fareTypeCd ft.fareTypeCd).and
          (between collationC p.beforeDayNum ft.rsrvAvailableEndDayNum.toSql ft.rsrvAvailableStartDayNum.toSql)).holds)
      (fun _ _ => rfl)]
  case h3 =>
    intro ⟨⟨f, ft⟩, fm⟩ r
    simp only [vacantSeatCond, flightPre, Truth.holds_and, Bool.and_assoc, Bool.and_comm, Bool.and_left_comm]

/-- 評価用: FLIGHT の行を `flightPre` で先に絞ってから同じ文を評価する（全件の直積を避ける。テストの差分実行に使う）。 -/
def vacantSeatRowsOn (db : MasterDb) (fd : FlightDb) (p : Params) : Bag VacantSeatRow :=
  vacantSeatRows db { fd with flight := fd.flight.filter (flightPre p) } p

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

/-- `ORDER BY ft.display_order ASC, fm.departure_time ASC` の整列の指定。 -/
def vacantSeatOrder : OrderBy VacantSeatRow :=
  ⟨[(.asc, fun r => r.displayOrder.toSql), (.asc, fun r => r.departureTime.toSql)]⟩

/-- 並べ方 `sortRows`（整列前の行の列から、並べた列を返す）が、どの結果についても `ORDER BY` の許される並びを返す。 -/
def SortAllowed (sortRows : List VacantSeatRow → List VacantSeatRow) : Prop :=
  ∀ rows, isAllowedOrder sortCfg vacantSeatOrder rows (sortRows rows) = true

/-- 標準の並べ方（安定整列。テストと参照に使う）。 -/
def standardSort (rows : List VacantSeatRow) : List VacantSeatRow :=
  orderByStable sortCfg vacantSeatOrder rows

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

/-! ## 予約が使う文（`exists`・`findOneForUpdate`・`update`。backlog aedf） -/

/-- 主キーの束縛変数（`#{departureDate}`・`#{flightName}`・`#{boardingClass.boardingClassCd}`・`#{fareType.fareTypeCd}`）。
`null` の参照をたどる式は `NULL`（MyBatis の `MetaObject`）。 -/
structure KeyParams where
  departureDate : SqlValue
  flightName : SqlValue
  boardingClass : SqlValue
  fareType : SqlValue
  deriving DecidableEq, Repr

/-- 主キーの束縛（`exists`・`findOneForUpdate` の引数）。 -/
@[source "dep:org.mybatis:mybatis#EnumTypeHandler@mybatis-3.5.19"]
def bindKey (departureDate : JRef JLocalDate) (flightName : JRef String) (boardingClass : JRef BoardingClass)
    (fareType : JRef FareType) : KeyParams where
  departureDate := sqlOf (fun d => .date d.toEpochDay) departureDate
  flightName := sqlOf .text flightName
  boardingClass := sqlOf (fun b => .text (BoardingClassCd.name b)) (boardingClass.bind (·.boardingClassCd))
  fareType := sqlOf (fun t => .text (FareTypeCd.name t)) (fareType.bind (·.fareTypeCd))

/-- 主キーの条件 `departure_date = … AND flight_name = … AND boarding_class_cd = … AND fare_type_cd = …`。 -/
def keyCond (p : KeyParams) (f : FlightRow) : Truth :=
  (SqlValue.eq collationC f.departureDate.toSql p.departureDate).and
  ((SqlValue.eq collationC f.flightName.toSql p.flightName).and
  ((SqlValue.eq collationC f.boardingClassCd.toSql p.boardingClass).and
  (SqlValue.eq collationC f.fareTypeCd.toSql p.fareType)))

/-- `SELECT EXISTS (SELECT * FROM flight WHERE <主キーの条件>)`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#exists@fe988ee9710d5e94"]
def existsRows (fd : FlightDb) (p : KeyParams) : Bool := Bag.exists' (Bag.select (keyCond p) fd.flight)

/-- `SELECT f.departure_date, f.flight_name, f.fare_type_cd, f.vacant_num, f.boarding_class_cd FROM flight f
WHERE <主キーの条件> FOR UPDATE`。行ロックは逐次の実行では観測されない（`SourceModel.Db.Tx`）。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findOneForUpdate@a0b73cb5abc18dbc"]
def findOneForUpdateRows (fd : FlightDb) (p : KeyParams) : Bag FlightResult :=
  Bag.project (fun f => ⟨f.departureDate, f.flightName, f.fareTypeCd, f.vacantNum, f.boardingClassCd⟩)
    (Bag.select (keyCond p) fd.flight)

/-- `UPDATE flight SET vacant_num = #{vacantNum} WHERE departure_date = #{departureDate} AND flight_name = #{flightMaster.flightName}
AND boarding_class_cd = #{boardingClass.boardingClassCd} AND fare_type_cd = #{fareType.fareTypeCd}`。更新件数を返す。
`vacant_num` は NOT NULL の `INT`。 -/
@[source "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#update@de19197b9e62d467"]
def updateRows (fd : FlightDb) (p : KeyParams) (vacantNum : JRef J32) : SqlResult (Nat × FlightDb) := do
  if (Bag.select (keyCond p) fd.flight).isEmpty then return (0, fd)
  let v ← match vacantNum with
    | some v => Int4.ofInt v.val
    | none => throw (.notNullViolation "vacant_num")
  let (rows, n) := updateWhere (keyCond p) (fun f => { f with vacantNum := v }) fd.flight
  return (n, { fd with flight := rows })

/-- `boolean exists(LocalDate departureDate, String flightName, BoardingClass boardingClass, FareType fareType)`。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#exists(LocalDate,String,BoardingClass,FareType)@963eff23e19232bd"]
def «exists» (departureDate : JRef JLocalDate) (flightName : JRef String) (boardingClass : JRef BoardingClass)
    (fareType : JRef FareType) : SourceModel.Db.Tx.DbM Bool :=
  SourceModel.Db.Tx.query fun fd => .ok (existsRows fd (bindKey departureDate flightName boardingClass fareType))

/-- `Flight findOneForUpdate(LocalDate departureDate, String flightName, BoardingClass boardingClass, FareType fareType)`。
`selectOne` なので、0 行なら `null`（主キーの条件なので 2 行以上にはならない）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findOneForUpdate(LocalDate,String,BoardingClass,FareType)@852c2d72ff703d07"]
def findOneForUpdate (departureDate : JRef JLocalDate) (flightName : JRef String) (boardingClass : JRef BoardingClass)
    (fareType : JRef FareType) : SourceModel.Db.Tx.DbM (JRef Flight) := do
  let rows ← SourceModel.Db.Tx.lockQuery fun fd =>
    .ok (findOneForUpdateRows fd (bindKey departureDate flightName boardingClass fareType))
  match rows with
  | [] => pure none
  | r :: _ => some <$> SourceModel.Db.Tx.lift (flightMap r)

/-- `int update(Flight flight)`。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#update(Flight)@3a289afa23fe78a3"]
def update (flight : JRef Flight) : SourceModel.Db.Tx.DbM J32 := do
  let f ← SourceModel.Db.Tx.lift (flight.deref "flight")
  let p := bindKey f.departureDate (f.flightMaster.bind (·.flightName)) f.boardingClass f.fareType
  let n ← SourceModel.Db.Tx.sql fun fd => updateRows fd p f.vacantNum
  pure (J32.ofInt n)

end FlightRepository

end SourceModel.Domain.Repository.Flight
