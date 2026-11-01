import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Airport
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Repository.Route.RouteRepository
import Spec.Model

/-!
# SourceModel.Domain.Common.Masterdata.RouteProvider

原典の `jp.co.ntt.atrs.domain.common.masterdata.RouteProvider`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/masterdata/RouteProvider.java`）の写し。
-/

namespace SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.Domain.Repository.Route
  SourceModel.Domain.Repository.Route.RouteRepository
open SourceModel.Domain.Common.Masterdata

/-- `RouteProvider` のキャッシュ（`Map<String, Route>`。キーは `RouteProvider.makeCacheKey`）。 -/
structure RouteProvider where
  routeMap : JHashMap String Route := {}

namespace RouteProvider

/-- `RouteProvider.makeCacheKey`（private）: `"[出発空港コード]-[到着空港コード]"`。`-` を含む空港コードでは、別の組とキーが重なる（D-034・D-036）。 -/
@[gap "D-034", "D-036"]
def makeCacheKey (departureAirportCd arrivalAirportCd : String) : String :=
  departureAirportCd ++ "-" ++ arrivalAirportCd

/-- `RouteProvider.load()`: 出発・到着の空港コードのキーで `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#load()@ce13818ba91368aa",
  "java:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll()@3cd8d3e7f6409637", gap "D-015", "D-036"]
def load (rows : List RouteResult) : JResult RouteProvider := do
  let mut m : JHashMap String Route := {}
  for r in rows.map SourceModel.Domain.Repository.Route.RouteRepository.routeMap do
    let dep ← (← r.departureAirport.deref "departureAirport").code.deref "code"
    let arr ← (← r.arrivalAirport.deref "arrivalAirport").code.deref "code"
    m := m.put (RouteProvider.makeCacheKey dep arr) r
  return { routeMap := m }

/-- `RouteProvider.getRouteByAirportCd`: 両方の空港コードが `hasText` でなければ `IllegalArgumentException`。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)@4266ccb1fdc24df9",
  "dep:org.springframework:spring-core#Assert.hasText@spring-core-7.0.3", gap "D-034"]
def getRouteByAirportCd (p : RouteProvider) (departureAirportCd arrivalAirportCd : String) : JResult (JRef Route) := do
  Assert.hasText departureAirportCd "departureAirportCd must have some text."
  Assert.hasText arrivalAirportCd "arrivalAirportCd must have some text."
  return p.routeMap.get (RouteProvider.makeCacheKey departureAirportCd arrivalAirportCd)

end RouteProvider

end SourceModel.Domain.Common.Masterdata
