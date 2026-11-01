import Lean.Data.Json
import Spec
import SourceModel
import Tests.Conformance
import Tests.ConformanceFare
import Tests.ConformanceMaster

/-!
# Tests.ConformanceFlightSearch

`flightSearch.*` の操作の割当（`docs/spec/conformance.md`）。`Spec` 用と `SourceModel` 用の 2 つの表を、
ベクタの共有入力（`fixtures/master-data.json`・`config.json`）から作る（backlog 0be7。ADR ce36）。

- 入力のフライト（`flights`）は、[Spec] では `World.flights` の全件、[Source] では FLIGHT 表の行とする。
- [Source] のマスタは、DB の表から起動時の読み込み（`SourceModel.MasterQuery.load`）で作り、Mapper の文の結果は
  標準の並び（安定整列）で返す。
- 結果の JSON: 成功は便ごとの空席情報の列。エラーは `{"error": {"kind": "business" | "notFound", "code": …}}`。
  [Source] の `AtrsBusinessException` は `business`、`FlightNotFoundException` は `notFound` に対応させる。
-/

open Lean Spec ConformanceKit Tests.Conformance

open ConformanceKit.Runner LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int

open Spec.Config Spec.Model Spec.Prim.Time Spec.Prim.Format

namespace Tests.ConformanceFlightSearch
open Tests.ConformanceFare (boardingClassCd fareTypeCd decodeMaster decodeConfig)

def getObjVal (j : Json) (k : String) : Except String Json := j.getObjVal? k

def flightType (s : String) : Except String FlightType := need (FlightType.ofCode? s) s!"flight type: {s}"

def errorJson (kind code : String) : Json :=
  Json.mkObj [("error", Json.mkObj [("kind", .str kind), ("code", .str code)])]

/-! ## Spec -/

def specFlight (f : Json) : Except String Flight := do
  return { key := { departureDate := ← decodeDate (← getStr f "departureDate"), flightName := ⟨← getStr f "flightName"⟩,
                    boardingClassCd := ← boardingClassCd (← getStr f "boardingClassCd"),
                    fareTypeCd := ← fareTypeCd (← getStr f "fareTypeCd") },
           vacantNum := ← getNat f "vacantNum" }

def specCriteria (c : Json) : Except String Spec.FlightSearch.Criteria := do
  return { depDate := ← decodeDate (← getStr c "depDate"), boardingClassCd := ← boardingClassCd (← getStr c "boardingClassCd"),
           depAirportCd := ⟨← getStr c "depAirportCd"⟩, arrAirportCd := ⟨← getStr c "arrAirportCd"⟩,
           flightType := ← flightType (← getStr c "flightType") }

def specErrorJson : Spec.Error.AtrsError → Json
  | .business code _ => errorJson "business" code
  | .notFound code => errorJson "notFound" code

def specInfoJson (v : Spec.FlightSearch.FlightVacantInfo) : Json :=
  Json.mkObj [("flightName", .str v.flightName.val), ("depAirportName", .str v.depAirportName),
    ("arrAirportName", .str v.arrAirportName), ("depTime", .str v.depTime), ("arrTime", .str v.arrTime),
    ("depDate", .str v.depDate), ("boardingClassCd", .str v.boardingClassCd.toCode),
    ("fareTypes", .arr (v.fareTypes.map fun (cd, i) => Json.mkObj [("fareTypeCd", .str cd.toCode),
      ("fareTypeName", .str i.fareTypeName), ("fare", .str i.fare), ("vacantNum", toJson i.vacantNum)]).toArray)]

/-- `Spec` の `flightSearch.*`。 -/
def specOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let md ← decodeMaster fx.master
  let cfg ← decodeConfig fx.config
  return [
    ("flightSearch.validateDepartureDate", fun i => do
      match Spec.FlightSearch.validateDepartureDate cfg (← decodeDate (← getStr i "today")) (← decodeDate (← getStr i "depDate")) with
      | .ok () => return .null
      | .error e => return specErrorJson e),
    ("flightSearch.isAvailableFareType", fun i => do
      let ft ← need (md.fareTypeOf (← fareTypeCd (← getStr i "fareTypeCd"))) "fare type not in master"
      return toJson (Spec.FlightSearch.isAvailableFareType ft (← decodeDate (← getStr i "depDate"))
        (← decodeDate (← getStr i "today")))),
    ("flightSearch.searchFlight", fun i => do
      let flights ← (← getArr i "flights").mapM specFlight
      let w : Spec.Port.World := ⟨flights⟩
      if !decide w.Inv then throw "outside INV (duplicate flight key)"
      let r ← need (Spec.FlightSearch.searchFlight cfg md (← decodeDate (← getStr i "today")) (← specCriteria (← getObjVal i "criteria"))
        w.findAll) "outside PRE"
      match r with
      | .ok vs => return .arr (vs.map specInfoJson).toArray
      | .error e => return specErrorJson e)
  ]

/-! ## SourceModel -/

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Repository.Schema

def jdate (s : String) : Except String JLocalDate := do
  let d ← decodeDate s
  need (JLocalDate.ofYMD? d.year d.month d.day) s!"date: {s}"

def flightRow (f : Json) : Except String FlightRow := do
  return { departureDate := ← Tests.ConformanceMaster.pd f "departureDate", flightName := ← Tests.ConformanceMaster.vc 6 f "flightName",
           boardingClassCd := ← Tests.ConformanceMaster.vc 1 f "boardingClassCd",
           fareTypeCd := ← Tests.ConformanceMaster.vc 4 f "fareTypeCd", vacantNum := ← Tests.ConformanceMaster.i4 f "vacantNum" }

def srcCriteria (c : Json) : Except String SourceModel.FlightSearch.TicketSearchCriteriaDto := do
  return { flightType := some (← flightType (← getStr c "flightType")), departureAirportCd := some (← getStr c "depAirportCd"),
           arrivalAirportCd := some (← getStr c "arrAirportCd"), depDate := some (← jdate (← getStr c "depDate")),
           boardingClassCd := some (← boardingClassCd (← getStr c "boardingClassCd")) }

/-- 業務例外を `business`・`notFound` の JSON に。ほかの例外はテストの失敗。 -/
def srcErrorJson (e : JThrow) : Except String Json :=
  match e with
  | .other "jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException" code => .ok (errorJson "business" code)
  | .other "jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException" code => .ok (errorJson "notFound" code)
  | e => .error s!"java exception: {repr e}"

def jstr (r : JRef String) : Json := optJson Json.str r

def srcInfoJson (v : SourceModel.FlightSearch.FlightVacantInfoDto) : Json :=
  Json.mkObj [("flightName", jstr v.flightName), ("depAirportName", jstr v.depAirportName),
    ("arrAirportName", jstr v.arrAirportName), ("depTime", jstr v.depTime), ("arrTime", jstr v.arrTime),
    ("depDate", jstr v.depDate), ("boardingClassCd", optJson (fun c => .str (BoardingClassCd.toCode c)) v.boardingClassCd),
    ("fareTypes", .arr (v.fareTypes.entries.map fun (cd, i) => Json.mkObj [("fareTypeCd", .str cd),
      ("fareTypeName", jstr i.fareTypeName), ("fare", jstr i.fare),
      ("vacantNum", optJson (fun (n : J32) => toJson n.val) i.vacantNum)]).toArray)]

/-- `SourceModel` の `flightSearch.*`（標準の並び）。 -/
def sourceOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let db ← Tests.ConformanceMaster.decodeDb fx.master
  let cfg ← Tests.ConformanceMaster.srcConfig fx.config
  let p ← match SourceModel.MasterQuery.load (SourceModel.MasterQuery.standardOrder db) with
    | .ok p => pure p
    | .error e => throw s!"load: {repr e}"
  return [
    ("flightSearch.validateDepartureDate", fun i => do
      match SourceModel.FlightSearch.validateDepatureDate cfg.limitDay (← jdate (← getStr i "today"))
          (some (← jdate (← getStr i "depDate"))) with
      | .ok () => return .null
      | .error e => srcErrorJson e),
    ("flightSearch.isAvailableFareType", fun i => do
      let ft ← match SourceModel.MasterData.getFareType p.fareType (some (← fareTypeCd (← getStr i "fareTypeCd"))) with
        | .ok ft => pure ft
        | .error e => throw s!"java exception: {repr e}"
      match SourceModel.FlightSearch.isAvailableFareType ft (some (← jdate (← getStr i "depDate"))) (← jdate (← getStr i "today")) with
      | .ok b => return toJson b
      | .error e => throw s!"java exception: {repr e}"),
    ("flightSearch.searchFlight", fun i => do
      let fd : FlightDb := { flight := ← (← getArr i "flights").mapM flightRow }
      let ic : SourceModel.FlightSearch.SearchInput :=
        { db, config := cfg, today := ← jdate (← getStr i "today"), criteria := some (← srcCriteria (← getObjVal i "criteria")) }
      match SourceModel.FlightSearch.runSearchFlight fd ic (SourceModel.MasterQuery.standardOrder db)
          SourceModel.Repository.Flight.standardSort with
      | .ok vs => return .arr (vs.map srcInfoJson).toArray
      | .error e => srcErrorJson e)
  ]

end Tests.ConformanceFlightSearch
