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
# 空席照会（B1）（`Spec.FlightSearch`）

空席照会（B1）。照会可能期間・運賃種別の予約可能判定・`searchFlight` を、
設定・マスタ・今日の日付・照会条件・フライトの全件の関数として与える（ADR ce36）。
フライトは抽象状態 `World` の成分で、空席照会は状態を変えない。抽象機械 `searchMachine` は、選択を持たない
`Machine.ofChoice`（選択の型は `Unit`）で、1 歩は状態を変えずに `searchFlight` の結果を出力する（backlog 0be7 の第 2 段）。

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。
>
> 照会可能期間・運賃種別の予約可能判定・`searchFlight` は Lean [`Spec.FlightSearch`](FlightSearch.lean) に形式化した（正。[ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。以下のそれらの定義は、Lean の非規範の要約である。[Source] の写しは [`SourceModel.Domain.Service.B1.TicketSearchServiceImpl`](../SourceModel/Domain/Service/B1/TicketSearchServiceImpl.lean)・[`SourceModel.Domain.Service.B0.TicketSharedServiceImpl`](../SourceModel/Domain/Service/B0/TicketSharedServiceImpl.lean)・[`SourceModel.Domain.Repository.Flight.FlightRepository`](../SourceModel/Domain/Repository/Flight/FlightRepository.lean) など（原典のクラスと 1 対 1。[ADR e41c](../../docs/decision/e41c-source-model-mirrors-java-tree.md)）。適合テストベクタは `conformance/shared/flight-search/`。抽象機械 `searchMachine`・具体機械 `SourceModel.FlightSearchQuery.searchConcrete` と、シードの初期状態は第 2 段で置いた（[ADR cdb6](../../docs/decision/cdb6-flight-search-stage2-machines-seed-sql.md)）。リファインメント（ABS-010・ABS-011）は [backlog 0be7](../../docs/backlog/0be7-flight-search-usecase.md) の第 3 段で置く。
-/

namespace Spec.FlightSearch
open Spec.Config Spec.Model Spec.Prim.Time Spec.Prim.Format Spec.Error

open Spec.Prim Spec.MasterData

/-!
## 照会可能期間

**[Spec=Source]**

- `searchLimitDate(today) = addDays(today, limitDay)`
- `validateDepartureDate(depDate, today)`: `depDate < today ∨ depDate > searchLimitDate(today)` なら `Business("e.ar.b1.2001")`。両端を含む。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getSearchLimitDate()`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateDepatureDate(LocalDate)`
-/


/-- 照会可能期間の末日 `addDays(today, limitDay)`。暦日（1〜9999 年）を超えれば無し。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#照会可能期間"]
def searchLimitDate (cfg : Config) (today : Date) : Option Date := today.addDays cfg.limitDay

/-- 搭乗日が照会可能期間の外（`depDate < today ∨ depDate > searchLimitDate(today)`）。
末日は日数で比べる（末日が暦日を超えるときは、どの搭乗日も末日を超えない）。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#照会可能期間"]
def outOfPeriod (cfg : Config) (today depDate : Date) : Bool :=
  decide (depDate < today) || decide (Date.daysBetween today depDate > cfg.limitDay)

/-- 搭乗日の検査。期間外なら `Business("e.ar.b1.2001")`。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#照会可能期間"]
def validateDepartureDate (cfg : Config) (today depDate : Date) : Except AtrsError Unit :=
  if outOfPeriod cfg today depDate then .error (.business "e.ar.b1.2001") else .ok ()

/-!
## 運賃種別の予約可能判定

**[Spec=Source]**

`isAvailableFareType(fareType, depDate, today)`:

```
start = addDays(depDate, −fareType.rsrvAvailableStartDayNum)
end   = addDays(depDate, −fareType.rsrvAvailableEndDayNum)
result = start ≤ today ≤ end
```

Lean の `Spec.FlightSearch.isAvailableFareType` は、次の日数の形で定義する（下の日付の形との同値は L 課題 ABS-010。backlog 0be7 の第 3 段）。これは `beforeDayNum = daysBetween(today, depDate)` について `rsrvAvailableEndDayNum ≤ beforeDayNum ≤ rsrvAvailableStartDayNum` と同値である（課題 [ABS-010](../../docs/spec/abstraction.md#証明課題)）。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#isAvailableFareType(FareType,LocalDate)`
-/


/-- 運賃種別の予約可能判定（日数で表した形。`rsrvAvailableEndDayNum ≤ beforeDayNum ≤ rsrvAvailableStartDayNum`）。
日付の形（`addDays(depDate, −n) ≤ today`）との同値は L 課題 ABS-010（第 3 段）。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#運賃種別の予約可能判定"]
def availableOnDayNum (ft : FareType) (beforeDayNum : Int) : Bool :=
  decide ((ft.rsrvAvailableEndDayNum : Int) ≤ beforeDayNum) && decide (beforeDayNum ≤ ft.rsrvAvailableStartDayNum)

/-- 運賃種別の予約可能判定 `isAvailableFareType(fareType, depDate, today)`。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#運賃種別の予約可能判定"]
def isAvailableFareType (ft : FareType) (depDate today : Date) : Bool :=
  availableOnDayNum ft (Date.daysBetween today depDate)

/-!
## searchFlight

### シグネチャ

```
searchFlight(criteria: { depDate, boardingClassCd, depAirportCd, arrAirportCd, flightType },
             flights: [Flight]; master, config, today) : Except AtrsError [FlightVacantInfo]
```

`flights` はフライトの全件（[`Spec.Port`](Port.lean) の `FlightRepository.findAll` 相当。抽象状態 `World.flights`。実装は絞り込みを永続化層に押し下げてよい）。
Lean では、MD-3 かフライトの参照整合性（`World.RefMaster`。FK_FLIGHT_1〜3）が破れて区間の空港名か搭乗クラスがマスタに無いとき（PRE の外）、結果を `none` とする。

### 事前条件

- [Source]: 各フィールドが null でない・空文字でない（`Assert`）。入力検証（[`Spec.InputValidation`](InputValidation.lean)）を通過していれば満たされる。
- [Spec]（Lean `Spec.FlightSearch.SearchInput.Pre`）: 次の連言。どれも入力だけの条件である（[ADR 0b0c](../../docs/decision/0b0c-flight-search-stage3-abs011.md)）。
  - 設定とマスタの不変条件（MD-1〜MD-8）
  - 照会の搭乗クラスがマスタにあること（入力検証の `ExistInCodeList` に当たる。無ければ [Source] は `calculateBasicFare` で `NullPointerException`。D-033。PRE の外）
  - 照会の空港コードが空白でないこと（空白なら [Source] は `Assert.hasText` で例外。D-033。PRE の外）。空港コードの形（英大文字 3 文字）は課さない（形の違うコードは区間が無いので `e.ar.b1.2002`。[Source] も同じ）
  - 照会の区間の便マスタの便名が空白でないこと（`FlightNamesHaveText`）。空白の便名の便マスタが結果に現れると、[Source] は `getFlightMaster` の `Assert.hasText` で例外を投げる（D-033。PRE の外）
- フライトの参照整合性（`World.RefMaster`）は PRE に課さない。マスタに無い便名・運賃種別を指すフライトは、[Spec] の候補の条件でも [Source] の結合でも除かれる。

### 定義（評価順）

1. `validateDepartureDate(depDate, today)`。失敗時 `e.ar.b1.2001`。
2. `route = routeOf(depAirportCd, arrAirportCd)`。無ければ `Business("e.ar.b1.2002")`。
3. `beforeDayNum = daysBetween(today, depDate)`。
4. `fareTypeCds = fareTypesFor(flightType)`（[`Spec.Model`](Model.lean#列挙)）。
5. 候補 `cs` = 次をすべて満たすフライト `f`:
   - `f.departureDate = depDate`
   - `flightMasterOf(f.flightName).routeNo = route.routeNo`
   - `f.boardingClassCd = boardingClassCd`
   - `f.fareTypeCd ∈ fareTypeCds`
   - `ft = fareTypeOf(f.fareTypeCd)` について `ft.rsrvAvailableEndDayNum ≤ beforeDayNum ≤ ft.rsrvAvailableStartDayNum`
   - **空席数 0 のフライトも含む**（除外しない）
6. `cs` を整列キー `(fareTypeOf(f.fareTypeCd).displayOrder, flightMasterOf(f.flightName).departureTime)` の昇順に並べる。
   - **[Spec]**: 同順位は `flightName` の昇順（MD-1・MD-2・MD-5 と `World` の主キーの一意性の下では同順位は生じない）。
   - **[Source]**: 同順位の順序は未規定（SQL の `ORDER BY` に含まれない）。
7. `cs` が空なら `NotFound("e.ar.b1.2003")`。
8. `b = basicFare(route.basicFare, boardingClassCd, depDate)`（全候補で共通）。
9. グループ化: `cs` を先頭から走査し、**便マスタの出発時刻**（`departureTime`）をキーとして、キーの初出順にグループ `FlightVacantInfo` を作る。
   - グループの見出し項目は、そのキーで最初に現れたフライトから作る（下表）。
   - 各フライト `f` について `fareTypes` に `f.fareTypeCd ↦ { fareTypeName, fare: fmtYen(fare(b, discountRate)), vacantNum: f.vacantNum }` を **挿入** する。同じキーが既にあれば値を置き換え、順序は最初の挿入位置のまま（[Source] の `LinkedHashMap.put`）。MD-1・MD-2・MD-5 と `World` の主キーの一意性の下ではグループ内の便は 1 つであり、置き換えは生じない。
10. グループの列を返す。

### 出力 FlightVacantInfo

| フィールド | 値 |
| --- | --- |
| `flightName` | `flightName` |
| `depAirportName` | 区間の出発空港の `name` |
| `arrAirportName` | 区間の到着空港の `name` |
| `depTime` | `fmtTime(departureTime)`（`HH:mm`） |
| `arrTime` | `fmtArrTime(arrivalTime)`（翌日着は `24:15` のように 24 時以降で表す。[Source] の `toFormatTimeString` と同じ） |
| `depDate` | `fmtDate(departureDate)`（`yyyy/MM/dd`） |
| `boardingClassCd` | `boardingClassCd` |
| `fareTypes`（`fare` は `fmtYen`。[Source] の区切り文字は既定の書式ロケールによる。既知差異 [D-032](../../docs/spec/abstraction.md#既知差異)） | 順序付き写像 `FareTypeCd ↦ { fareTypeName: String, fare: String, vacantNum: Nat }` |

出力の順序の性質: 第 1 グループの並びは「最も表示順の小さい運賃種別を持つ便の出発時刻順」であり、単純な出発時刻順ではない。
例えば片道照会で搭乗日が 10 日後なら、`OW`（表示順 1）は全便にあるので全グループが出発時刻順になる。一方、ある便に `OW` の行が無ければ、その便のグループは後ろに回る。

### エラー

| 条件 | エラー |
| --- | --- |
| 搭乗日が照会可能期間外 | `Business("e.ar.b1.2001")` |
| 区間が存在しない | `Business("e.ar.b1.2002")` |
| 候補が 0 件 | `NotFound("e.ar.b1.2003")` |

### 例

`today = 2026-04-01`、区間 HND→ITM（路線基本運賃 20600）、便 NTT001（09:00–10:00）・NTT031（09:45–10:45）、
`depDate = 2026-04-11`（ピーク時期外）、`N`、`OW` のとき `beforeDayNum = 10`。
候補となる運賃種別は `OW`(0–90), `RD1`(1–60), `RD7`(7–60), `LD`(1–60), `GD`(1–60), `SRD` は `S` 専用のため無し、`ED`(30–60) は対象外。
結果は 2 グループ（09:00, 09:45）、各グループの `fareTypes` は `OW: "20,600"`, `RD1: "18,600"`, `RD7: "16,500"`, `LD: "14,500"`, `GD: "14,500"` の順。

（`fare(20600, 10) = ceilTo(18540, 100) = 18600`、`fare(20600, 20) = ceilTo(16480, 100) = 16500`、`fare(20600, 30) = ceilTo(14420, 100) = 14500`）

出典: `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)`（private の `createFlightVacantInfoList` を含む）, `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria`
-/


/-- 照会条件。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#シグネチャ"]
structure Criteria where
  depDate : Date
  boardingClassCd : BoardingClassCd
  depAirportCd : AirportCd
  arrAirportCd : AirportCd
  flightType : FlightType
  deriving DecidableEq, Repr

/-- 運賃種別ごとの空席情報。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#出力-flightvacantinfo"]
structure FareTypeVacantInfo where
  fareTypeName : String
  /-- `fmtYen(fare)` -/
  fare : String
  vacantNum : Nat
  deriving DecidableEq, Repr

/-- 便ごとの空席情報。`fareTypes` は挿入順の順序付き写像。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#出力-flightvacantinfo"]
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

/-- 候補の条件（`lean/Spec/FlightSearch.lean#定義評価順` の 5）。条件を満たせば、便マスタと運賃種別を添える。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#定義評価順"]
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
@[spec_doc "lean/Spec/FlightSearch.lean#定義評価順"]
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
@[spec_doc "lean/Spec/FlightSearch.lean#出力-flightvacantinfo"]
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

/-- グループ化（`lean/Spec/FlightSearch.lean#定義評価順` の 9）: 便マスタの出発時刻をキーに、キーの初出順に
グループを作り、各フライトの運賃種別を挿入する。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#定義評価順"]
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
@[spec_doc "lean/Spec/FlightSearch.lean#searchflight", gap "D-001", "D-002", "D-014"]
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

/-!
## 照会画面の初期値

**[Spec=Source]**

- 照会条件の初期値: `flightType = defaultFlightType`, `depAirportCd = defaultDepAirportCd`, `arrAirportCd = defaultArrAirportCd`, `outwardDate = today`, `homewardDate = today`, `boardingClassCd = defaultBoardingClassCd`。
- 照会可能期間の表示: `beginningPeriod = today`, `endingPeriod = searchLimitDate(today)`, `reserveIntervalTime = config.reserveIntervalTime`。

出典: `java:jp.co.ntt.atrs.app.b1.TicketSearchHelper#createDefaultTicketSearchForm()`, `java:jp.co.ntt.atrs.app.b1.TicketSearchHelper#createFlightSearchOutputDto()`
-/

/-- 照会画面の照会可能期間の表示（`beginningPeriod`・`endingPeriod`）。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#照会画面の初期値"]
def searchPeriod (cfg : Config) (today : Date) : Date × Option Date := (today, searchLimitDate cfg today)

/-! ## 抽象機械（SPEC 課題） -/

/-- 空席照会の入力（状態のフライト以外）: 設定・マスタ・今日の日付・照会条件。 -/
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
@[spec_doc "lean/Spec/FlightSearch.lean#事前条件", gap "D-033"]
def FlightNamesHaveText (md : MasterData) (c : Criteria) : Prop :=
  ∀ r, md.routeOf c.depAirportCd c.arrAirportCd = some r →
    ∀ fm ∈ md.flightMasters, fm.routeNo = r.routeNo → Text.hasText fm.flightName.val = true

/-- PRE: 設定とマスタの不変条件（MD-1〜MD-8）、照会の搭乗クラスがマスタにあること（入力検証の `ExistInCodeList`）、
照会の空港コードが空白でないこと（[Source] の `Assert.hasText` に当たる）。どれも入力だけの条件である（照会条件の条件は、
入力検証を通過していれば満たされる）。空港コードの形（英大文字 3 文字）は課さない。形の違うコードは、区間が無いので `e.ar.b1.2002` になる
（[Source] も同じ）。フライトがマスタに無い便名・運賃種別を指しても、[Spec] の `candidateOf` も [Source] の結合も、その行を除く
（搭乗クラスは照会と同じものだけが残る）。フライトの参照整合性 `World.RefMaster` は PRE に入れない（ADR 0b0c）。
便マスタの便名が空白でないこと（`FlightNamesHaveText`。D-033）も課す。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#事前条件", gap "D-033"]
def SearchInput.Pre (_w : Port.World) (i : SearchInput) : Prop :=
  i.cfg.Valid ∧ i.md.Valid i.cfg ∧ (i.md.boardingClassOf i.criteria.boardingClassCd).isSome = true ∧
    Text.hasText i.criteria.depAirportCd.val = true ∧ Text.hasText i.criteria.arrAirportCd.val = true ∧
    FlightNamesHaveText i.md i.criteria

/-- 1 歩の出力: `searchFlight` の結果（PRE の下では `none` にならない。`searchFlight_isSome`）。 -/
def answer (w : Port.World) (i : SearchInput) : SearchOutput :=
  (searchFlight i.cfg i.md i.today i.criteria w.findAll).getD (.ok [])

/-- 1 歩の関数（選択は環境・自由とも `Unit`）: 状態を変えず、`answer` を出力する。 -/
def searchStep (w : Port.World) (i : SearchInput) (_ : Unit × Unit) : Port.World × SearchOutput := (w, answer w i)

/-- 空席照会の抽象機械。状態は `World`、INV は主キーの一意性、初期状態はシードを投入した後の `World`
（予約と共有する。backlog aedf の第 3 段）。1 歩は状態を変えない。 -/
@[spec_doc "lean/Spec/FlightSearch.lean#searchflight"]
def searchMachine : Machine.Machine Port.World SearchInput SearchOutput :=
  Machine.Machine.ofChoice Port.World.Inv (· = Seed.World.world) SearchInput.Pre searchStep () ()

/-- PRE の下で、`searchFlight` は `none` にならない（`answer` の既定値は観測されない）。 -/
theorem searchFlight_isSome {w : Port.World} {i : SearchInput} (h : SearchInput.Pre w i) :
    (searchFlight i.cfg i.md i.today i.criteria w.findAll).isSome := by
  obtain ⟨_, hmd, hbsome, _, _, _⟩ := h
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
