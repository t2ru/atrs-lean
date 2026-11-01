import LangSemantics.Java
import SourceModel.Model
import SourceModel.Repository.Mapping

/-!
# SourceModel.MasterData

マスタの Provider（`jp.co.ntt.atrs.domain.common.masterdata`）。Provider は起動時（`@PostConstruct load()`）に
マスタを読んでキャッシュし、以後は変えない。マスタは不変なので、キャッシュを操作の入力の成分として受ける
（`docs/spec/abstraction.md`）。`load` は、Mapper の文の結果の 1 つの順列（`List`）を受けてキャッシュを作る
（順列の選び方は具体機械 `SourceModel.MasterQuery.queryConcrete` が与える）。
-/

namespace SourceModel.MasterData
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring

open LangSemantics.Java SourceModel.Model SourceModel.Repository.MasterData

/-- `BoardingClassProvider` のキャッシュ（`Map<BoardingClassCd, BoardingClass>`）。 -/
structure BoardingClassProvider where
  boardingClassCodeMap : JHashMap Spec.Model.BoardingClassCd BoardingClass := {}

/-- `PeakTimeProvider` のキャッシュ（`List<PeakTime>`。取得順）。 -/
structure PeakTimeProvider where
  peakTimeList : List PeakTime := []

/-- `FareTypeProvider` のキャッシュ（`Map<FareTypeCd, FareType>`）。 -/
structure FareTypeProvider where
  fareTypeCodeMap : JHashMap Spec.Model.FareTypeCd FareType := {}

/-- `RouteProvider` のキャッシュ（`Map<String, Route>`。キーは `makeCacheKey`）。 -/
structure RouteProvider where
  routeMap : JHashMap String Route := {}

/-- `FlightMasterProvider` のキャッシュ（`Map<String, FlightMaster>`。キーは便名）。 -/
structure FlightMasterProvider where
  flightMasterMap : JHashMap String FlightMaster := {}

/-! ## `load()` -/

/-- `BoardingClassProvider.load()`: `findAll` の各行を、搭乗クラスコードをキーに `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#load()@ea4f74c6c99e9b67",
  "java:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll()@a75e2344e7b09314", gap "D-015"]
def BoardingClassProvider.load (rows : List BoardingClassResult) : JResult BoardingClassProvider := do
  let list ← rows.mapM Repository.Mapping.boardingClass
  let mut m : JHashMap Spec.Model.BoardingClassCd BoardingClass := {}
  for bc in list do
    m := m.put (← bc.boardingClassCd.deref "boardingClassCd") bc
  return { boardingClassCodeMap := m }

/-- `FareTypeProvider.load()`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#load()@accd51e500f0cb16",
  "java:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll()@c01904394de5db65", gap "D-015"]
def FareTypeProvider.load (rows : List FareTypeResult) : JResult FareTypeProvider := do
  let list ← rows.mapM Repository.Mapping.fareType
  let mut m : JHashMap Spec.Model.FareTypeCd FareType := {}
  for ft in list do
    m := m.put (← ft.fareTypeCd.deref "fareTypeCd") ft
  return { fareTypeCodeMap := m }

/-- `PeakTimeProvider.load()`: `findAll` の結果を取得順のまま `addAll` する。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#load()@604b187a665e10c5",
  "java:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll()@4020414e93f77c78"]
def PeakTimeProvider.load (rows : List SourceModel.Repository.Schema.PeakTimeRow) : PeakTimeProvider :=
  { peakTimeList := rows.map Repository.Mapping.peakTime }

/-- `RouteProvider.makeCacheKey`（private）: `"[出発空港コード]-[到着空港コード]"`。 -/
def makeCacheKey (departureAirportCd arrivalAirportCd : String) : String :=
  departureAirportCd ++ "-" ++ arrivalAirportCd

/-- `RouteProvider.load()`: 出発・到着の空港コードのキーで `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#load()@ce13818ba91368aa",
  "java:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll()@3cd8d3e7f6409637", gap "D-015"]
def RouteProvider.load (rows : List RouteResult) : JResult RouteProvider := do
  let mut m : JHashMap String Route := {}
  for r in rows.map Repository.Mapping.route do
    let dep ← (← r.departureAirport.deref "departureAirport").code.deref "code"
    let arr ← (← r.arrivalAirport.deref "arrivalAirport").code.deref "code"
    m := m.put (makeCacheKey dep arr) r
  return { routeMap := m }

/-- `FlightMasterProvider.load()`: 便名をキーに `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#load()@42b24c5f9549b118",
  "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster()@0563c719a0a21f51", gap "D-015"]
def FlightMasterProvider.load (rows : List FlightMasterResult) : JResult FlightMasterProvider := do
  let mut m : JHashMap String FlightMaster := {}
  for f in Repository.Mapping.flightMasters rows do
    m := m.put (← f.flightName.deref "flightName") f
  return { flightMasterMap := m }

/-! ## 参照 -/

/-- `getBoardingClass`: 無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)@363af6d3dd2e282d"]
def getBoardingClass (p : BoardingClassProvider) (cd : JRef Spec.Model.BoardingClassCd) : JResult (JRef BoardingClass) := do
  let cd ← Assert.notNullValue cd "boardingClassCd must not null."
  return p.boardingClassCodeMap.get cd

/-- `getPeakTime`: 取得順に走査し、`depLocalDate` を両端を含めて含む最初のピーク時期。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)@1b19d6cad612b687", gap "D-004"]
def getPeakTime (p : PeakTimeProvider) (depLocalDate : JRef JLocalDate) : JResult (JRef PeakTime) := do
  let d ← Assert.notNullValue depLocalDate "depLocalDate must not null."
  let rec go : List PeakTime → JResult (JRef PeakTime)
    | [] => pure none
    | pt :: rest => do
      let s ← pt.peakStartDate.deref "peakStartDate"
      let e ← pt.peakEndDate.deref "peakEndDate"
      if java! !(d.isBefore(s) || d.isAfter(e)) then pure (some pt) else go rest
  go p.peakTimeList

/-- `getFareType`: 無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#getFareType(FareTypeCd)@8cca1518f179d5a0"]
def getFareType (p : FareTypeProvider) (cd : JRef Spec.Model.FareTypeCd) : JResult (JRef FareType) := do
  let cd ← Assert.notNullValue cd "fareTypeCd must not null."
  return p.fareTypeCodeMap.get cd

/-- `getRouteByAirportCd`: 両方の空港コードが `hasText` でなければ `IllegalArgumentException`。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)@4266ccb1fdc24df9",
  "dep:org.springframework:spring-core#Assert.hasText@spring-core-7.0.3"]
def getRouteByAirportCd (p : RouteProvider) (departureAirportCd arrivalAirportCd : String) : JResult (JRef Route) := do
  Assert.hasText departureAirportCd "departureAirportCd must have some text."
  Assert.hasText arrivalAirportCd "arrivalAirportCd must have some text."
  return p.routeMap.get (makeCacheKey departureAirportCd arrivalAirportCd)

/-- `getFlightMaster`: 便名が `hasText` でなければ `IllegalArgumentException`。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#getFlightMaster(String)@73525e4cbaf2e787",
  "dep:org.springframework:spring-core#Assert.hasText@spring-core-7.0.3"]
def getFlightMaster (p : FlightMasterProvider) (flightName : String) : JResult (JRef FlightMaster) := do
  Assert.hasText flightName "flightName must have some text."
  return p.flightMasterMap.get flightName

end SourceModel.MasterData
