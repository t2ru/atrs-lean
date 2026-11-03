import Lean.Data.Json
import Spec
import SourceModel
import Tests.Conformance
import Tests.ConformanceFare

/-!
# Tests.ConformanceMaster

`master.*` の操作（マスタ・設定・コードリストの参照。R 課題 ABS-026 の両側）の割当。

- `Spec`: 共有入力を `Spec.MasterData`・`Spec.Config` に読み、`Spec.MasterQuery.answer` で答える。
- `SourceModel`: 共有入力の行を DB の表（`MasterDb`。列の型の範囲を検査する）とみなし、
  `SourceModel.MasterQuery.run` を標準の並び（`standardOrder`）で実行する。

結果は、両モデルに共通の JSON に写して比べる（区間の空港名など [Spec] が持たない値は写さない）。
-/

open Lean ConformanceKit Tests.Conformance Tests.ConformanceFare

open ConformanceKit.Runner ConformanceKit.SqlTable LangSemantics.Java.Exception LangSemantics.Java.Int
  LangSemantics.Java.IntLemmas

open Spec.CodeList Spec.Config Spec.MasterQuery Spec.Model
  Spec.Prim.Format Spec.Prim.Time

namespace Tests.ConformanceMaster
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)

/-! ## 共通の JSON -/

def hhmm (t : HourMinute) : String := padNat 2 t.hour ++ padNat 2 t.minute
def arrHhmm (t : ArrivalTime) : String := padNat 2 t.hour ++ padNat 2 t.minute

def codeListName (s : String) : Except String CodeListName :=
  match s with
  | "airport" => .ok .airport | "boardingClass" => .ok .boardingClass | "fareType" => .ok .fareType
  | "creditType" => .ok .creditType | "creditMonth" => .ok .creditMonth | "creditYear" => .ok .creditYear
  | "gender" => .ok .gender | "flightType" => .ok .flightType
  | _ => .error s!"code list: {s}"

def entriesJson (l : List (String × String)) : Json := .arr (l.map fun (c, v) => .arr #[.str c, .str v]).toArray

/-! ## Spec -/

def specAnswerJson : Spec.MasterQuery.Answer → Json
  | .route r => optJson (fun r => Json.mkObj [("routeNo", toJson r.routeNo), ("depAirportCd", .str r.depAirportCd.val),
      ("arrAirportCd", .str r.arrAirportCd.val), ("basicFare", toJson r.basicFare)]) r
  | .flightMaster f => optJson (fun f => Json.mkObj [("flightName", .str f.flightName.val), ("routeNo", toJson f.routeNo),
      ("departureTime", .str (hhmm f.departureTime)), ("arrivalTime", .str (arrHhmm f.arrivalTime)),
      ("craftType", .str f.craftType)]) f
  | .fareType f => optJson (fun f => Json.mkObj [("fareTypeCd", .str f.fareTypeCd.toCode), ("fareTypeName", .str f.fareTypeName),
      ("discountRate", toJson f.discountRate), ("rsrvAvailableStartDayNum", toJson f.rsrvAvailableStartDayNum),
      ("rsrvAvailableEndDayNum", toJson f.rsrvAvailableEndDayNum), ("passengerMinNum", toJson f.passengerMinNum)]) f
  | .boardingClass b => optJson (fun b => Json.mkObj [("boardingClassCd", .str b.boardingClassCd.toCode),
      ("boardingClassName", .str b.boardingClassName), ("extraCharge", toJson b.extraCharge)]) b
  | .peakTime p => optJson (fun p => Json.mkObj [("peakTimeCd", .str p.peakTimeCd), ("peakStartDate", .str (fmtIsoDate p.peakStartDate)),
      ("peakEndDate", .str (fmtIsoDate p.peakEndDate)), ("multiplicationRatio", toJson p.multiplicationRatio)]) p
  | .ratio n => toJson n
  | .config c => Json.mkObj [("limitDay", toJson c.limitDay), ("reserveIntervalTime", toJson c.reserveIntervalTime),
      ("representativeMinAge", toJson c.representativeMinAge), ("adultPassengerMinAge", toJson c.adultPassengerMinAge),
      ("childFareRate", toJson c.childFareRate), ("dateOfBirthMinDate", .str (fmtIsoDate c.dateOfBirthMinDate)),
      ("defaultFlightType", .str c.defaultFlightType.toCode), ("defaultDepAirportCd", .str c.defaultDepAirportCd.val),
      ("defaultArrAirportCd", .str c.defaultArrAirportCd.val), ("defaultBoardingClassCd", .str c.defaultBoardingClassCd.toCode)]
  | .codeList l => entriesJson (l.map fun e => (e.code, e.label))

def specQuery (i : Json) (op : String) : Except String Spec.MasterQuery.Query := do
  match op with
  | "master.routeOf" => return .routeOf (← getStr i "dep") (← getStr i "arr")
  | "master.flightMasterOf" => return .flightMasterOf (← getStr i "name")
  | "master.fareTypeOf" => return .fareTypeOf (← fareTypeCd (← getStr i "cd"))
  | "master.boardingClassOf" => return .boardingClassOf (← boardingClassCd (← getStr i "cd"))
  | "master.peakTimeOn" => return .peakTimeOn (← decodeDate (← getStr i "date"))
  | "master.multiplicationRatioOn" => return .multiplicationRatioOn (← decodeDate (← getStr i "date"))
  | "master.config" => return .config
  | "master.codeList" => return .codeList (← codeListName (← getStr i "name"))
  | _ => throw s!"unknown operation {op}"

def opNames : List String :=
  ["master.routeOf", "master.flightMasterOf", "master.fareTypeOf", "master.boardingClassOf", "master.peakTimeOn",
   "master.multiplicationRatioOn", "master.config", "master.codeList"]

/-- `Spec` の `master.*`。PRE（設定とマスタの不変条件、問い合わせの値域）を満たさない入力は失敗とする。 -/
def specOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let md ← decodeMaster fx.master
  let cfg ← decodeConfig fx.config
  return opNames.map fun op => (op, fun i => do
    let q ← specQuery i op
    if !(decide cfg.Valid && decide (md.Valid cfg) && decide q.Valid) then throw "outside PRE"
    return specAnswerJson (Spec.MasterQuery.answer cfg md q))

/-! ## SourceModel -/

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Db.Schema SourceModel.MasterQuery

def vc (n : Nat) (j : Json) (k : String) : Except String (Varchar n) := do liftSql (Varchar.ofString k n (← getStr j k)) k
def i4 (j : Json) (k : String) : Except String Int4 := do liftSql (Int4.ofInt (← getInt j k)) k
def pd (j : Json) (k : String) : Except String PgDate := do liftSql (date (← decodeDate (← getStr j k)).epochDay) k

/-- 共有入力の行を、DB の表とみなす。 -/
def decodeDb (m : Json) : Except String MasterDb := do
  if m.isNull then return {}
  return {
    airport := ← (← getArr m "airports").mapM fun a => do
      return { airportCd := ← vc 3 a "code", airportName := ← vc 15 a "name", displayOrder := ← i4 a "displayOrder" }
    route := ← (← getArr m "routes").mapM fun r => do
      return { routeNo := ← i4 r "routeNo", depAirportCd := ← vc 3 r "depAirportCd", arrAirportCd := ← vc 3 r "arrAirportCd",
               flightTime := ← vc 4 r "flightTime", basicFare := ← i4 r "basicFare" }
    flightMaster := ← (← getArr m "flightMasters").mapM fun f => do
      return { flightName := ← vc 6 f "flightName", routeNo := ← i4 f "routeNo", departureTime := ← vc 4 f "departureTime",
               arrivalTime := ← vc 4 f "arrivalTime", craftType := ← vc 16 f "craftType" }
    boardingClass := ← (← getArr m "boardingClasses").mapM fun b => do
      return { boardingClassCd := ← vc 1 b "boardingClassCd", boardingClassName := some (← vc 10 b "boardingClassName"),
               extraCharge := ← i4 b "extraCharge", displayOrder := ← i4 b "displayOrder" }
    fareType := ← (← getArr m "fareTypes").mapM fun f => do
      return { fareTypeCd := ← vc 4 f "fareTypeCd", fareTypeName := ← vc 10 f "fareTypeName", discountRate := ← i4 f "discountRate",
               rsrvAvailableStartDayNum := ← i4 f "rsrvAvailableStartDayNum",
               rsrvAvailableEndDayNum := ← i4 f "rsrvAvailableEndDayNum", passengerMinNum := ← i4 f "passengerMinNum",
               displayOrder := ← i4 f "displayOrder" }
    peakTime := ← (← getArr m "peakTimes").mapM fun p => do
      return { peakTimeCd := ← vc 10 p "peakTimeCd", peakStartDate := ← pd p "peakStartDate", peakEndDate := ← pd p "peakEndDate",
               multiplicationRatio := ← i4 p "multiplicationRatio" }
    plane := ← (← getArr m "planes").mapM fun p => do
      return { craftType := ← vc 16 p "craftType", nSeatNum := ← i4 p "nSeatNum", sSeatNum := ← i4 p "sSeatNum" }
    creditType := ← (← getArr m "creditTypes").mapM fun c => do
      return { creditTypeCd := ← vc 3 c "creditTypeCd", creditFirm := ← vc 80 c "creditFirm", displayOrder := ← i4 c "displayOrder" } }

def srcConfig (c : Json) : Except String SourceModel.AtrsProperties.AtrsConfig := do
  if c.isNull then return SourceModel.AtrsProperties.upstreamConfig
  let ft ← getStr c "defaultFlightType"
  let dob ← decodeDate (← getStr c "dateOfBirthMinDate")
  return { limitDay := ← j32 c "limitDay", reserveIntervalTime := ← j32 c "reserveIntervalTime",
           representativeMinAge := ← j32 c "representativeMinAge", adultPassengerMinAge := ← j32 c "adultPassengerMinAge",
           childFareRate := ← j32 c "childFareRate",
           dateOfBirthMinDate := s!"{padNat 4 dob.year}/{padNat 2 dob.month}/{padNat 2 dob.day}",
           defaultFlightType := ← need (FlightType.ofCode? ft) s!"flight type: {ft}",
           defaultDepAirportCd := ← getStr c "defaultDepAirportCd", defaultArrAirportCd := ← getStr c "defaultArrAirportCd",
           defaultBoardingClassCd := ← boardingClassCd (← getStr c "defaultBoardingClassCd") }

def jstr (r : JRef String) : Json := optJson Json.str r
def jint (r : JRef J32) : Json := optJson (fun v => toJson v.val) r
def jdate (r : JRef JLocalDate) : Json :=
  optJson (fun d => .str s!"{padNat 4 d.year.toNat}-{padNat 2 d.month}-{padNat 2 d.day}") r

def srcAnswerJson : SrcAnswer → Json
  | .route r => optJson (fun (r : SourceModel.Domain.Model.Route) => Json.mkObj [("routeNo", jint r.routeNo),
      ("depAirportCd", jstr (r.departureAirport.bind (·.code))), ("arrAirportCd", jstr (r.arrivalAirport.bind (·.code))),
      ("basicFare", jint r.basicFare)]) r
  | .flightMaster f => optJson (fun (f : SourceModel.Domain.Model.FlightMaster) => Json.mkObj [("flightName", jstr f.flightName),
      ("routeNo", jint (f.route.bind (·.routeNo))), ("departureTime", jstr f.departureTime), ("arrivalTime", jstr f.arrivalTime),
      ("craftType", jstr (f.plane.bind (·.craftType)))]) f
  | .fareType f => optJson (fun (f : SourceModel.Domain.Model.FareType) => Json.mkObj [
      ("fareTypeCd", optJson (fun c => .str (FareTypeCd.toCode c)) f.fareTypeCd), ("fareTypeName", jstr f.fareTypeName),
      ("discountRate", jint f.discountRate), ("rsrvAvailableStartDayNum", jint f.rsrvAvailableStartDayNum),
      ("rsrvAvailableEndDayNum", jint f.rsrvAvailableEndDayNum), ("passengerMinNum", jint f.passengerMinNum)]) f
  | .boardingClass b => optJson (fun (b : SourceModel.Domain.Model.BoardingClass) => Json.mkObj [
      ("boardingClassCd", optJson (fun c => .str (BoardingClassCd.toCode c)) b.boardingClassCd),
      ("boardingClassName", jstr b.boardingClassName), ("extraCharge", jint b.extraCharge)]) b
  | .peakTime p => optJson (fun (p : SourceModel.Domain.Model.PeakTime) => Json.mkObj [("peakTimeCd", jstr p.peakTimeCd),
      ("peakStartDate", jdate p.peakStartDate), ("peakEndDate", jdate p.peakEndDate),
      ("multiplicationRatio", jint p.multiplicationRatio)]) p
  | .ratio n => toJson n.val
  | .config c => Json.mkObj [("limitDay", toJson c.limitDay.val), ("reserveIntervalTime", toJson c.reserveIntervalTime.val),
      ("representativeMinAge", toJson c.representativeMinAge.val), ("adultPassengerMinAge", toJson c.adultPassengerMinAge.val),
      ("childFareRate", toJson c.childFareRate.val),
      ("dateOfBirthMinDate", .str (c.dateOfBirthMinDate.replace "/" "-")),
      ("defaultFlightType", .str c.defaultFlightType.toCode), ("defaultDepAirportCd", .str c.defaultDepAirportCd),
      ("defaultArrAirportCd", .str c.defaultArrAirportCd), ("defaultBoardingClassCd", .str c.defaultBoardingClassCd.toCode)]
  | .codeList l => entriesJson l

def srcQuery (i : Json) (op : String) : Except String SrcQuery := do
  let ld (s : String) : Except String JLocalDate := do
    let d ← decodeDate s
    need (JLocalDate.ofYMD? d.year d.month d.day) s!"date: {s}"
  match op with
  | "master.routeOf" => return .routeOf (← getStr i "dep") (← getStr i "arr")
  | "master.flightMasterOf" => return .flightMasterOf (← getStr i "name")
  | "master.fareTypeOf" => return .fareTypeOf (← fareTypeCd (← getStr i "cd"))
  | "master.boardingClassOf" => return .boardingClassOf (← boardingClassCd (← getStr i "cd"))
  | "master.peakTimeOn" => return .peakTimeOn (← ld (← getStr i "date"))
  | "master.multiplicationRatioOn" => return .multiplicationRatioOn (← ld (← getStr i "date"))
  | "master.config" => return .config
  | "master.codeList" => return .codeList (← codeListName (← getStr i "name"))
  | _ => throw s!"unknown operation {op}"

/-- `SourceModel` の `master.*`（標準の並び）。 -/
def sourceOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let db ← decodeDb fx.master
  let cfg ← srcConfig fx.config
  return opNames.map fun op => (op, fun i => do
    let q ← srcQuery i op
    match run { db, config := cfg, query := q } (standardOrder db) with
    | .ok a => return srcAnswerJson a
    | .error e => throw s!"java exception: {repr e}")

end Tests.ConformanceMaster
