import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Domain.Model.Airport
import SourceModel.Domain.Model.Route
import Spec.Model

/-!
# SourceModel.Domain.Repository.Route.RouteRepository

原典の `jp.co.ntt.atrs.domain.repository.route.RouteRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/route/RouteRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/route/RouteRepository.xml`）の写し。
-/

namespace SourceModel.Domain.Repository.Route
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Route
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model
open SourceModel.Db.MyBatis

namespace RouteRepository

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
def findAll (db : MasterDb) : Bag RouteResult :=
  Bag.project (fun ((r, d), a) => ⟨r.routeNo, r.basicFare, d.airportCd, d.airportName, a.airportCd, a.airportName⟩)
    (Bag.select (fun ((r, d), a) => (eqText r.depAirportCd d.airportCd).and (eqText r.arrAirportCd a.airportCd))
      (Bag.cross (Bag.cross db.route db.airport) db.airport))

/-- `route-map`。`departureAirport.code` などの点つきの属性は、空港を作って値を入れる。 -/
@[source "java:jp.co.ntt.atrs.config.app.mybatis.MybatisConfig#configuration()@81014029228aac4a",
  "java:jp.co.ntt.atrs.config.app.AtrsInfraConfig#sqlSessionFactory(DataSource)@b1ab3854afd9d9e6"]
def routeMap (r : RouteResult) : Route :=
  { routeNo := int r.routeNo, basicFare := int r.basicFare,
    departureAirport := some { code := str r.depAirportCd, name := str r.depAirportName },
    arrivalAirport := some { code := str r.aarAirportCd, name := str r.aarAirportName } }

end RouteRepository

end SourceModel.Domain.Repository.Route
