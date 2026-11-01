import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.Fare
import Spec.Error
import Spec.Port

/-!
# Spec.FlightSearch

空席照会（B1。`docs/spec/flight-search.md`）。照会可能期間・運賃種別の予約可能判定・`searchFlight` を、
設定・マスタ・今日の日付・照会条件・フライトの全件の関数として与える（ADR ce36）。
フライトは抽象状態 `World` の成分で、空席照会は状態を変えない。機械と SPEC 課題は backlog 0be7 の第 2 段で置く。
-/

namespace Spec.FlightSearch
open Spec.Config Spec.Model Spec.Prim.Time Spec.Prim.Format Spec.Error

open Spec.Prim Spec.MasterData

/-! ## 照会可能期間 -/

/-- 照会可能期間の末日 `addDays(today, limitDay)`。暦日（1〜9999 年）を超えれば無し。 -/
@[spec_doc "docs/spec/flight-search.md#照会可能期間"]
def searchLimitDate (cfg : Config) (today : Date) : Option Date := today.addDays cfg.limitDay

/-- 搭乗日が照会可能期間の外（`depDate < today ∨ depDate > searchLimitDate(today)`）。
末日は日数で比べる（末日が暦日を超えるときは、どの搭乗日も末日を超えない）。 -/
@[spec_doc "docs/spec/flight-search.md#照会可能期間"]
def outOfPeriod (cfg : Config) (today depDate : Date) : Bool :=
  decide (depDate < today) || decide (Date.daysBetween today depDate > cfg.limitDay)

/-- 搭乗日の検査。期間外なら `Business("e.ar.b1.2001")`。 -/
@[spec_doc "docs/spec/flight-search.md#照会可能期間"]
def validateDepartureDate (cfg : Config) (today depDate : Date) : Except AtrsError Unit :=
  if outOfPeriod cfg today depDate then .error (.business "e.ar.b1.2001") else .ok ()

/-! ## 運賃種別の予約可能判定 -/

/-- 運賃種別の予約可能判定（日数で表した形。`rsrvAvailableEndDayNum ≤ beforeDayNum ≤ rsrvAvailableStartDayNum`）。
日付の形（`addDays(depDate, −n) ≤ today`）との同値は L 課題 ABS-010（第 3 段）。 -/
@[spec_doc "docs/spec/flight-search.md#運賃種別の予約可能判定"]
def availableOnDayNum (ft : FareType) (beforeDayNum : Int) : Bool :=
  decide ((ft.rsrvAvailableEndDayNum : Int) ≤ beforeDayNum) && decide (beforeDayNum ≤ ft.rsrvAvailableStartDayNum)

/-- 運賃種別の予約可能判定 `isAvailableFareType(fareType, depDate, today)`。 -/
@[spec_doc "docs/spec/flight-search.md#運賃種別の予約可能判定"]
def isAvailableFareType (ft : FareType) (depDate today : Date) : Bool :=
  availableOnDayNum ft (Date.daysBetween today depDate)

/-! ## searchFlight -/

/-- 照会条件。 -/
@[spec_doc "docs/spec/flight-search.md#シグネチャ"]
structure Criteria where
  depDate : Date
  boardingClassCd : BoardingClassCd
  depAirportCd : AirportCd
  arrAirportCd : AirportCd
  flightType : FlightType
  deriving DecidableEq, Repr

/-- 運賃種別ごとの空席情報。 -/
@[spec_doc "docs/spec/flight-search.md#出力-flightvacantinfo"]
structure FareTypeVacantInfo where
  fareTypeName : String
  /-- `fmtYen(fare)` -/
  fare : String
  vacantNum : Nat
  deriving DecidableEq, Repr

/-- 便ごとの空席情報。`fareTypes` は挿入順の順序付き写像。 -/
@[spec_doc "docs/spec/flight-search.md#出力-flightvacantinfo"]
structure FlightVacantInfo where
  flightName : FlightName
  depAirportName : String
  arrAirportName : String
  depTime : String
  arrTime : String
  depDate : String
  boardingClassCd : BoardingClassCd
  fareTypes : List (FareTypeCd × FareTypeVacantInfo)
  deriving DecidableEq, Repr

/-- 候補（フライトと、その便マスタ・運賃種別）。 -/
structure Candidate where
  flight : Flight
  master : FlightMaster
  fareType : FareType

/-- 候補の条件（`docs/spec/flight-search.md#定義評価順` の 5）。条件を満たせば、便マスタと運賃種別を添える。 -/
@[spec_doc "docs/spec/flight-search.md#定義評価順"]
def candidateOf (md : MasterData) (c : Criteria) (route : Route) (beforeDayNum : Int) (f : Flight) :
    Option Candidate := do
  let fm ← md.flightMasterOf f.key.flightName
  let ft ← md.fareTypeOf f.key.fareTypeCd
  if f.key.departureDate = c.depDate ∧ fm.routeNo = route.routeNo ∧ f.key.boardingClassCd = c.boardingClassCd ∧
      f.key.fareTypeCd ∈ fareTypesFor c.flightType ∧ availableOnDayNum ft beforeDayNum = true then
    some ⟨f, fm, ft⟩
  else none

/-- 整列の順序: `(運賃種別の表示順, 便マスタの出発時刻, 便名)` の辞書式。
便名は [Spec] の同順位の決め方で、MD-1（運賃種別の表示順の一意性）・MD-2・MD-5 と `World.Inv` の下では
同順位は生じない（[Source] は未規定）。 -/
@[spec_doc "docs/spec/flight-search.md#定義評価順"]
def candidateLe (a b : Candidate) : Bool :=
  a.fareType.displayOrder < b.fareType.displayOrder ||
    (a.fareType.displayOrder == b.fareType.displayOrder &&
      (a.master.departureTime.toMinutes < b.master.departureTime.toMinutes ||
        (a.master.departureTime.toMinutes == b.master.departureTime.toMinutes &&
          decide (a.flight.key.flightName.val ≤ b.flight.key.flightName.val))))

/-- 順序付き写像への挿入: 同じキーがあれば値を置き換え、位置は最初の挿入のまま（`LinkedHashMap.put`）。 -/
def insertOrdered {κ ν : Type} [DecidableEq κ] (m : List (κ × ν)) (k : κ) (v : ν) : List (κ × ν) :=
  if m.any (·.1 == k) then m.map fun p => if p.1 = k then (k, v) else p else m ++ [(k, v)]

/-- 空港名。 -/
def airportName? (md : MasterData) (cd : AirportCd) : Option String :=
  (md.airports.find? fun a => a.code == cd).map (·.name)

/-- グループの見出し（そのキーで最初に現れたフライトから作る）。 -/
@[spec_doc "docs/spec/flight-search.md#出力-flightvacantinfo"]
def headerOf (depName arrName : String) (x : Candidate) : FlightVacantInfo where
  flightName := x.flight.key.flightName
  depAirportName := depName
  arrAirportName := arrName
  depTime := fmtTime x.master.departureTime
  arrTime := fmtArrTime x.master.arrivalTime
  depDate := fmtDate x.flight.key.departureDate
  boardingClassCd := x.flight.key.boardingClassCd
  fareTypes := []

/-- 運賃種別ごとの空席情報（基本運賃 `b` から）。 -/
def fareTypeInfoOf (b : Nat) (x : Candidate) : FareTypeVacantInfo :=
  ⟨x.fareType.fareTypeName, fmtYen (Fare.fare b x.fareType.discountRate), x.flight.vacantNum⟩

/-- グループ化（`docs/spec/flight-search.md#定義評価順` の 9）: 便マスタの出発時刻をキーに、キーの初出順に
グループを作り、各フライトの運賃種別を挿入する。 -/
@[spec_doc "docs/spec/flight-search.md#定義評価順"]
def group (depName arrName : String) (b : Nat) (cs : List Candidate) : List FlightVacantInfo :=
  let step (gs : List (HourMinute × FlightVacantInfo)) (x : Candidate) :=
    let key := x.master.departureTime
    let g := match gs.find? (·.1 == key) with
      | some (_, g) => g
      | none => headerOf depName arrName x
    let g := { g with fareTypes := insertOrdered g.fareTypes x.flight.key.fareTypeCd (fareTypeInfoOf b x) }
    insertOrdered gs key g
  (cs.foldl step []).map (·.2)

/-- 空席照会 `searchFlight`。`flights` はフライトの全件（`World.findAll`）。
結果が `none` なのは PRE の外（MD-3 か `World.RefMaster` が破れ、照会の区間の空港名か搭乗クラスがマスタに無い）
のときだけである。 -/
@[spec_doc "docs/spec/flight-search.md#searchflight", gap "D-001", "D-002"]
def searchFlight (cfg : Config) (md : MasterData) (today : Date) (c : Criteria) (flights : List Flight) :
    Option (Except AtrsError (List FlightVacantInfo)) :=
  match validateDepartureDate cfg today c.depDate with
  | .error e => some (.error e)
  | .ok () =>
    match md.routeOf c.depAirportCd c.arrAirportCd with
    | none => some (.error (.business "e.ar.b1.2002"))
    | some route =>
      let beforeDayNum := Date.daysBetween today c.depDate
      let cs := (flights.filterMap (candidateOf md c route beforeDayNum)).mergeSort candidateLe
      if cs.isEmpty then some (.error (.notFound "e.ar.b1.2003"))
      else do
        let b ← Fare.basicFare md route.basicFare c.boardingClassCd c.depDate
        let depName ← airportName? md route.depAirportCd
        let arrName ← airportName? md route.arrAirportCd
        return .ok (group depName arrName b cs)

/-- 照会画面の照会可能期間の表示（`beginningPeriod`・`endingPeriod`）。 -/
@[spec_doc "docs/spec/flight-search.md#照会画面の初期値"]
def searchPeriod (cfg : Config) (today : Date) : Date × Option Date := (today, searchLimitDate cfg today)

end Spec.FlightSearch
