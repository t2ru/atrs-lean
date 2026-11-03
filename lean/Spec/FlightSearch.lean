import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.Fare
import Spec.Error
import Spec.Port
import Spec.Seed.Flight
import Spec.Seed.FlightProps
import Spec.Seed.World
import Machine

/-!
# Spec.FlightSearch

空席照会（B1。`docs/spec/flight-search.md`）。照会可能期間・運賃種別の予約可能判定・`searchFlight` を、
設定・マスタ・今日の日付・照会条件・フライトの全件の関数として与える（ADR ce36）。
フライトは抽象状態 `World` の成分で、空席照会は状態を変えない。抽象機械 `searchMachine` は、選択を持たない
`Machine.ofChoice`（選択の型は `Unit`）で、1 歩は状態を変えずに `searchFlight` の結果を出力する（backlog 0be7 の第 2 段）。
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
  if outOfPeriod cfg today depDate then .error (.business .outOfSearchPeriod) else .ok ()

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
@[spec_doc "docs/spec/flight-search.md#シグネチャ", raw_input "画面・REST の照会条件。空港コードは生の文字列で、区間はマスタで値で引く"]
structure Criteria where
  depDate : Date
  boardingClassCd : BoardingClassCd
  depAirportCd : String
  arrAirportCd : String
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
  let fm ← md.flightMasterOf f.key.flightName.val
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

/-- 運賃種別ごとの空席情報（基本運賃 `b` から）。運賃の表示は `fmtYen`（3 桁区切りは `,`。[Source] は配備の環境の
既定の書式ロケールによる。D-032）。 -/
@[gap "D-032"]
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

/-- 空席照会 `searchFlight`。`flights` はフライトの全件（`World.findAll`）。今日の日付 `today` は 1 回だけ読んだ値（D-014）。
結果が `none` なのは PRE の外（MD-3 か `World.RefMaster` が破れ、照会の区間の空港名か搭乗クラスがマスタに無い）
のときだけである。 -/
@[spec_doc "docs/spec/flight-search.md#searchflight", gap "D-001", "D-002", "D-014"]
def searchFlight (cfg : Config) (md : MasterData) (today : Date) (c : Criteria) (flights : List Flight) :
    Option (Except AtrsError (List FlightVacantInfo)) :=
  match validateDepartureDate cfg today c.depDate with
  | .error e => some (.error e)
  | .ok () =>
    match md.routeOf c.depAirportCd c.arrAirportCd with
    | none => some (.error (.business .routeNotFound))
    | some route =>
      let beforeDayNum := Date.daysBetween today c.depDate
      let cs := (flights.filterMap (candidateOf md c route beforeDayNum)).mergeSort candidateLe
      if cs.isEmpty then some (.error (.notFound .noFlight))
      else do
        let b ← Fare.basicFare md route.basicFare c.boardingClassCd c.depDate
        let depName ← airportName? md route.depAirportCd
        let arrName ← airportName? md route.arrAirportCd
        return .ok (group depName arrName b cs)

/-- 照会画面の照会可能期間の表示（`beginningPeriod`・`endingPeriod`）。 -/
@[spec_doc "docs/spec/flight-search.md#照会画面の初期値"]
def searchPeriod (cfg : Config) (today : Date) : Date × Option Date := (today, searchLimitDate cfg today)

/-! ## 抽象機械（SPEC 課題） -/

/-- 空席照会の入力（状態のフライト以外）: 設定・マスタ・今日の日付・照会条件。 -/
@[raw_input "機械の入力。妥当性 SearchInput.Pre は PRE"]
structure SearchInput where
  cfg : Config
  md : MasterData
  today : Date
  criteria : Criteria
  deriving DecidableEq

/-- 空席照会の出力。 -/
abbrev SearchOutput := Except AtrsError (List FlightVacantInfo)

/-- 照会の区間の便マスタの便名が空白でない（[Source] の `FlightMasterProvider.getFlightMaster` の `Assert.hasText` に
当たる）。空白の便名の便マスタが照会の結果に現れると、[Source] は `IllegalArgumentException` を投げる（D-033。PRE の外）。
結果に現れうるのは照会の区間の便マスタだけなので、その便マスタに限って課す。 -/
@[spec_doc "docs/spec/flight-search.md#事前条件", gap "D-033"]
def FlightNamesHaveText (md : MasterData) (c : Criteria) : Prop :=
  ∀ r, md.routeOf c.depAirportCd c.arrAirportCd = some r →
    ∀ fm ∈ md.flightMasters, fm.routeNo = r.routeNo → Text.hasText fm.flightName.val = true

/-- PRE: 設定とマスタの検証が通ること（`EnvPre.masterConfigOk`。設定の不変条件と MD-1〜MD-8）、照会の搭乗クラスがマスタにあること（入力検証の `ExistInCodeList`）、
照会の空港コードが空白でないこと（[Source] の `Assert.hasText` に当たる）。どれも入力だけの条件である（照会条件の条件は、
入力検証を通過していれば満たされる）。空港コードの形（英大文字 3 文字）は課さない。形の違うコードは、区間が無いので `e.ar.b1.2002` になる
（[Source] も同じ）。フライトがマスタに無い便名・運賃種別を指しても、[Spec] の `candidateOf` も [Source] の結合も、その行を除く
（搭乗クラスは照会と同じものだけが残る）。フライトの参照整合性 `World.RefMaster` は PRE に入れない（ADR 0b0c）。
便マスタの便名が空白でないこと（`FlightNamesHaveText`。D-033）も課す。 -/
@[spec_doc "docs/spec/flight-search.md#事前条件", gap "D-033"]
def SearchInput.Pre (_w : Port.World) (i : SearchInput) : Prop :=
  EnvPre.masterConfigOk (i.cfg, i.md) ∧ (i.md.boardingClassOf i.criteria.boardingClassCd).isSome = true ∧
    Text.hasText i.criteria.depAirportCd = true ∧ Text.hasText i.criteria.arrAirportCd = true ∧
    FlightNamesHaveText i.md i.criteria

/-- 1 歩の出力: `searchFlight` の結果（PRE の下では `none` にならない。`searchFlight_isSome`）。 -/
def answer (w : Port.World) (i : SearchInput) : SearchOutput :=
  (searchFlight i.cfg i.md i.today i.criteria w.findAll).getD (.ok [])

/-- 1 歩の関数（選択は環境・自由とも `Unit`）: 状態を変えず、`answer` を出力する。 -/
def searchStep (w : Port.World) (i : SearchInput) (_ : Unit × Unit) : Port.World × SearchOutput := (w, answer w i)

/-- 空席照会の抽象機械。状態は `World`、INV は主キーの一意性、初期状態はシードを投入した後の `World`
（予約と共有する。backlog aedf の第 3 段）。1 歩は状態を変えない。 -/
@[spec_doc "docs/spec/flight-search.md#searchflight"]
def searchMachine : Machine.Machine Port.World SearchInput SearchOutput :=
  Machine.Machine.ofChoice Port.World.Inv (· = Seed.World.world) SearchInput.Pre searchStep () ()

/-- PRE の下で、`searchFlight` は `none` にならない（`answer` の既定値は観測されない）。 -/
theorem searchFlight_isSome {w : Port.World} {i : SearchInput} (h : SearchInput.Pre w i) :
    (searchFlight i.cfg i.md i.today i.criteria w.findAll).isSome := by
  obtain ⟨hok, hbsome, _, _, _⟩ := h
  obtain ⟨_, hmd⟩ := hok.valid
  unfold searchFlight
  split
  · rfl
  · split
    · rfl
    · rename_i route hroute
      simp only
      split
      · rfl
      · have hroute' := List.mem_of_find?_eq_some hroute
        obtain ⟨⟨a1, ha1, hc1⟩, ⟨a2, ha2, hc2⟩⟩ := hmd.md3.1 route hroute'
        have hdep : (airportName? i.md route.depAirportCd).isSome := by
          unfold airportName?; rw [Option.isSome_map, List.find?_isSome]; exact ⟨a1, ha1, by simp [hc1]⟩
        have harr : (airportName? i.md route.arrAirportCd).isSome := by
          unfold airportName?; rw [Option.isSome_map, List.find?_isSome]; exact ⟨a2, ha2, by simp [hc2]⟩
        obtain ⟨bc, hbc'⟩ := Option.isSome_iff_exists.mp hbsome
        obtain ⟨dn, hdn⟩ := Option.isSome_iff_exists.mp hdep
        obtain ⟨an, han⟩ := Option.isSome_iff_exists.mp harr
        simp [Fare.basicFare, hbc', hdn, han]

/-- SPEC-001: PRE の下で、標準の選択は関係に含まれる。 -/
@[obligation "SPEC-001"]
theorem searchMachine_run_step :
    ∀ s i, searchMachine.Pre s i → searchMachine.step s i (searchMachine.run s i).1 (searchMachine.run s i).2 :=
  searchMachine.run_step

/-- SPEC-002・SPEC-003: 初期状態（シードを投入した後の `World`）は INV を満たし、1 歩は状態を変えないので INV を保つ。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem searchMachine_sound : searchMachine.Sound where
  init_inv s h := h ▸ Seed.FlightProps.world_inv
  step_inv s i s' o hi _ hs := by
    obtain ⟨_, hc⟩ := hs
    cases hc
    exact hi

/-- SPEC-007: 初期状態は、シードを投入した後の `World` の 1 点。 -/
@[obligation "SPEC-007"]
theorem searchMachine_initIs : searchMachine.InitIs Seed.World.world := fun _ => Iff.rfl

end Spec.FlightSearch
