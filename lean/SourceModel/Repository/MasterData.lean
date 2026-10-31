import Trace
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Repository.Schema

/-!
# SourceModel.Repository.MasterData

マスタの Mapper の文（`jp.co.ntt.atrs.domain.repository.*`）と、コードリストの SQL（`AtrsCodeListConfig`）を、
`LangSemantics.Sql` の演算で写す。結果はバッグ（行の順序は未規定）である。`ORDER BY` の文は、
並べる前のバッグと整列キーを与え、許される順列は `orderKey` について `isAllowedOrder` で決まる。
結合の条件は PostgreSQL の比較（照合順序 C）で評価する。
-/

namespace SourceModel.Repository.MasterData
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas LangSemantics.Sql.Sequence

open LangSemantics.Sql LangSemantics.Sql.Postgresql SourceModel.Repository.Schema

/-- 文字列の列の等号（`a = b`。照合順序 C）。 -/
def eqText {m n : Nat} (a : Varchar m) (b : Varchar n) : Truth := SqlValue.eq collationC a.toSql b.toSql

/-- 整数の列の等号。 -/
def eqInt (a b : Int4) : Truth := SqlValue.eq collationC a.toSql b.toSql

/-! ## 区間（`RouteRepository.findAll`） -/

/-- `route-map` が読む列。 -/
structure RouteResult where
  routeNo : Int4
  basicFare : Int4
  depAirportCd : Varchar 3
  depAirportName : Varchar 15
  aarAirportCd : Varchar 3
  aarAirportName : Varchar 15
  deriving DecidableEq, Repr

/-- `SELECT r.route_no, r.basic_fare, a_dep.airport_cd AS dep_airport_cd, a_dep.airport_name AS dep_airport_name,
a_arr.airport_cd AS aar_airport_cd, a_arr.airport_name AS aar_airport_name FROM route r, airport a_dep, airport a_arr
WHERE r.dep_airport_cd = a_dep.airport_cd AND r.arr_airport_cd = a_arr.airport_cd` -/
@[source "sql:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll@0a9a6b28094e3e9a"]
def routeFindAll (db : MasterDb) : Bag RouteResult :=
  Bag.project (fun ((r, d), a) => ⟨r.routeNo, r.basicFare, d.airportCd, d.airportName, a.airportCd, a.airportName⟩)
    (Bag.select (fun ((r, d), a) => (eqText r.depAirportCd d.airportCd).and (eqText r.arrAirportCd a.airportCd))
      (Bag.cross (Bag.cross db.route db.airport) db.airport))

/-! ## 便マスタ（`FlightRepository.findAllFlightMaster`） -/

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
def flightMasterFindAll (db : MasterDb) : Bag FlightMasterResult :=
  Bag.project (fun (((f, r), d), a) => ⟨f.flightName, f.departureTime, f.arrivalTime, f.craftType,
      ⟨r.routeNo, r.basicFare, d.airportCd, d.airportName, a.airportCd, a.airportName⟩⟩)
    (Bag.select (fun (((f, r), d), a) =>
        ((eqInt f.routeNo r.routeNo).and (eqText r.depAirportCd d.airportCd)).and (eqText r.arrAirportCd a.airportCd))
      (Bag.cross (Bag.cross (Bag.cross db.flightMaster db.route) db.airport) db.airport))

/-! ## 搭乗クラス・運賃種別・ピーク時期（`findAll`） -/

/-- `SELECT boarding_class_cd, boarding_class_name, extra_charge FROM boarding_class` -/
structure BoardingClassResult where
  boardingClassCd : Varchar 1
  boardingClassName : Option (Varchar 10)
  extraCharge : Int4
  deriving DecidableEq, Repr

@[source "sql:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll@9b228eec7b3acd6a"]
def boardingClassFindAll (db : MasterDb) : Bag BoardingClassResult :=
  Bag.project (fun b => ⟨b.boardingClassCd, b.boardingClassName, b.extraCharge⟩) db.boardingClass

/-- `SELECT fare_type_cd, fare_type_name, discount_rate, rsrv_available_start_day_num, rsrv_available_end_day_num,
passenger_min_num FROM fare_type` -/
structure FareTypeResult where
  fareTypeCd : Varchar 4
  fareTypeName : Varchar 10
  discountRate : Int4
  rsrvAvailableStartDayNum : Int4
  rsrvAvailableEndDayNum : Int4
  passengerMinNum : Int4
  deriving DecidableEq, Repr

@[source "sql:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll@7ff78a19a79f16de"]
def fareTypeFindAll (db : MasterDb) : Bag FareTypeResult :=
  Bag.project (fun f => ⟨f.fareTypeCd, f.fareTypeName, f.discountRate, f.rsrvAvailableStartDayNum,
    f.rsrvAvailableEndDayNum, f.passengerMinNum⟩) db.fareType

/-- `SELECT peak_time_cd, peak_start_date, peak_end_date, multiplication_ratio FROM peak_time` -/
@[source "sql:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll@52311345757d8bde"]
def peakTimeFindAll (db : MasterDb) : Bag PeakTimeRow := db.peakTime

/-! ## コードリストの SQL（`ORDER BY display_order ASC`） -/

/-- 整列の設定（PostgreSQL の既定。照合順序 C）。 -/
def sortCfg : SortConfig := sortConfig

/-- `ORDER BY display_order ASC` の整列キー。 -/
def orderKey {α : Type} (displayOrder : α → Int4) (r : α) : List SqlValue := [(displayOrder r).toSql]

/-- `CL_AIRPORT`: `SELECT airport_cd,airport_name,display_order FROM airport order by display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()@6236d6ba59dfd39c"]
def airportCodeListRows (db : MasterDb) : Bag AirportRow := db.airport

/-- `CL_BOARDINGCLASS`: `SELECT boarding_class_cd,boarding_class_name FROM boarding_class ORDER BY display_order ASC`
（整列前。整列キーのために `display_order` も持つ）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_BOARDINGCLASS()@c0ccb970d9355072"]
def boardingClassCodeListRows (db : MasterDb) : Bag BoardingClassRow := db.boardingClass

/-- `CL_FARETYPE`: `SELECT fare_type_cd, fare_type_name FROM fare_type ORDER BY display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FARETYPE()@49649a5d73522449"]
def fareTypeCodeListRows (db : MasterDb) : Bag FareTypeRow := db.fareType

/-- `CL_CREDITTYPE`: `SELECT credit_type_cd, credit_firm FROM credit_type ORDER BY display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITTYPE()@14fc9ae274494f99"]
def creditTypeCodeListRows (db : MasterDb) : Bag CreditTypeRow := db.creditType

end SourceModel.Repository.MasterData
