import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Repository.Flight.FlightRepository
import Spec.Model

/-!
# SourceModel.Domain.Common.Masterdata.FlightMasterProvider

原典の `jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/masterdata/FlightMasterProvider.java`）の写し。
-/

namespace SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.Domain.Repository.Route
  SourceModel.Domain.Repository.Route.RouteRepository SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository
open SourceModel.Domain.Common.Masterdata

/-- `FlightMasterProvider` のキャッシュ（`Map<String, FlightMaster>`。キーは便名）。 -/
structure FlightMasterProvider where
  flightMasterMap : JHashMap String FlightMaster := {}

namespace FlightMasterProvider

/-- `FlightMasterProvider.load()`: 便名をキーに `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#load()@42b24c5f9549b118",
  "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster()@0563c719a0a21f51", gap "D-015"]
def load (rows : List FlightMasterResult) : JResult FlightMasterProvider := do
  let mut m : JHashMap String FlightMaster := {}
  for f in SourceModel.Domain.Repository.Flight.FlightRepository.flightMasters rows do
    m := m.put (← f.flightName.deref "flightName") f
  return { flightMasterMap := m }

/-- `FlightMasterProvider.getFlightMaster`: 便名が `hasText` でなければ `IllegalArgumentException`。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#getFlightMaster(String)@73525e4cbaf2e787",
  "dep:org.springframework:spring-core#Assert.hasText@spring-core-7.0.3"]
def getFlightMaster (p : FlightMasterProvider) (flightName : String) : JResult (JRef FlightMaster) := do
  Assert.hasText flightName "flightName must have some text."
  return p.flightMasterMap.get flightName

end FlightMasterProvider

end SourceModel.Domain.Common.Masterdata
