import LangSemantics.Java
import SourceModel.Model
import SourceModel.MasterData
import SourceModel.Fare
import SourceModel.MasterQuery
import SourceModel.Config
import SourceModel.Repository.Flight
import SourceModel.Repository.Mapping

/-!
# SourceModel.FlightSearch

空席照会（B1）の原典（`TicketSearchServiceImpl.searchFlight`・`TicketSharedServiceImpl` の照会可能期間と
運賃種別の予約可能判定・`FareTypeUtil`・`DateTimeUtil` の書式）の写し（backlog 0be7。ADR ce36）。

- 今日の日付（`LocalDate.now(dateFactory.tick())`）は、1 つの値 `today` として受ける。原典は 1 回の照会で
  Clock を 3 回読むので、この写しは D-014 の前提（各呼び出しが同じ日付を返す）の下のものである。
- リポジトリ `FlightRepository.findByVacantSeatSearchCriteria` はポートとして関数で受ける。SQL の写しと、
  その許される並べ方は `SourceModel.Repository.Flight` にある。選んだ並べ方でポートを作るのは `repositoryOf`、
  起動時の読み込みと合わせて実行するのは `runSearchFlight` である。
- 業務例外（`AtrsBusinessException`・`FlightNotFoundException`）は、`JThrow.other` のクラス名とエラーコードで表す。
-/

namespace SourceModel.FlightSearch
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap

open LangSemantics.Java SourceModel.Model SourceModel.MasterData SourceModel.Repository.Flight

/-! ## 業務例外 -/

/-- 業務例外のクラス名。 -/
def businessExceptionClass : String := "jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException"

/-- 照会結果 0 件の業務例外のクラス名。 -/
def flightNotFoundClass : String := "jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException"

/-- `new AtrsBusinessException(code)`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException#<init>(AtrsErrorCode,Object...)@70bc401f3ab46d0d",
  "java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException.serialVersionUID@3d4b63a6702d11d1"]
def businessException (code : String) : JThrow := .other businessExceptionClass code

/-- 空席照会のエラーコード（`TicketSearchErrorCode`）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode#code()@5fde806a365dc7a0",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2001@d4efdf3f2ea8e7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2002@c1a57c4052f9c12b",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2003@2ea2beee13c2ea3a",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5001@9bd02ea3ebb9a87f",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5002@c2b041fc47e7f619"]
def errorCode : String → String := id

/-- `new FlightNotFoundException()`（`E_AR_B1_2003`）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException#<init>()@a759c61b6ed17dc4",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException.serialVersionUID@8c008f35f98c4bb6"]
def flightNotFound : JThrow := .other flightNotFoundClass (errorCode "e.ar.b1.2003")

/-! ## `FareTypeUtil`・`DateTimeUtil` -/

/-- `ONE_WAY_FARETYPES`（`LinkedHashSet`。この順序）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ONE_WAY_FARETYPES@13a685de676dd6d0"]
def oneWayFareTypes : List Spec.Model.FareTypeCd := [.OW, .RD1, .RD7, .ED, .LD, .GD, .SOW, .SRD]

/-- `ROUND_TRIP_FARETYPES`（`LinkedHashSet`。この順序）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ROUND_TRIP_FARETYPES@93a93cb033a0d234"]
def roundTripFareTypes : List Spec.Model.FareTypeCd := [.RT, .SRT]

/-- `getFareTypeCdList(flightType)`: `FlightType.OW.equals(flightType)` なら片道の列、それ以外（`null` を含む）は往復の列。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil#getFareTypeCdList(FlightType)@23c5f6e900fea030",
  "java:jp.co.ntt.atrs.domain.model.FlightType#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.FlightType.OW@7e4b60f4d2ee743b",
  "java:jp.co.ntt.atrs.domain.model.FlightType.RT@3165be96f5833ae0"]
def getFareTypeCdList (flightType : JRef Spec.Model.FlightType) : List Spec.Model.FareTypeCd :=
  if flightType = some .OW then oneWayFareTypes else roundTripFareTypes

/-- `toFormatTimeString(timeString)`: 長さが 2 より大きければ `String.format("%s:%s", s.substring(0, 2), s.substring(2))`。
`%s` に非 `null` の文字列を渡す `String.format` は、連結と同じである。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatTimeString(String)@45ff7b872987b979",
  "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.TIME_FORMATTER@b3ea6e972e16ec6a",
  "lang:java#java.lang.String.format@java-17"]
def toFormatTimeString (timeString : JRef String) : JResult (JRef String) := do
  match timeString with
  | some s =>
    if 2 < utf16Len s then
      let a ← jSubstring s 0 2
      let b ← jSubstringFrom s 2
      return some (a ++ ":" ++ b)
    else return some s
  | none => return none

/-- `toFormatDateString(localDate)`: `null` なら空文字列、それ以外は `yyyy/MM/dd`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatDateString(LocalDate)@a9c17cb275f550f1",
  "java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.DATE_FORMATTER@6231e4eebda71cf4"]
def toFormatDateString (localDate : JRef JLocalDate) : String :=
  match localDate with
  | some d => d.formatYMD "/"
  | none => ""

/-! ## 照会可能期間・運賃種別の予約可能判定（`TicketSharedServiceImpl`） -/

/-- `getSearchLimitDate()`: `today.plusDays(limitDay)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#getSearchLimitDate()@9196be73040e6f0f",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getSearchLimitDate()@07352a31cf61634a", gap "D-014"]
def getSearchLimitDate (limitDay : J32) (today : JLocalDate) : JLocalDate := today.plusDays limitDay.val

/-- `validateDepatureDate(departureDate)`: `null` なら `IllegalArgumentException`。今日より前か、照会可能期間の
末日より後なら `AtrsBusinessException(E_AR_B1_2001)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#validateDepatureDate(LocalDate)@9b898d66ce284b6a",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateDepatureDate(LocalDate)@ab7abd9ac674d349",
  gap "D-014"]
def validateDepatureDate (limitDay : J32) (today : JLocalDate) (departureDate : JRef JLocalDate) : JResult Unit := do
  let d ← match departureDate with
    | some d => pure d
    | none => throw (.illegalArgument "departureDate must not null.")
  let limitDate := getSearchLimitDate limitDay today
  if d.isBefore today || d.isAfter limitDate then throw (businessException (errorCode "e.ar.b1.2001"))

/-- `isAvailableFareType(fareType, depDate)`: 予約可能期間の始まり `depDate − start`・終わり `depDate − end` の
両端を含む範囲に今日があるか。`searchFlight` は呼ばない（同じ条件を SQL の `BETWEEN` で書く。ABS-010）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#isAvailableFareType(FareType,LocalDate)@920d960054ac73a8",
  "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#isAvailableFareType(FareType,LocalDate)@c724cf20ebe62f82",
  gap "D-014"]
def isAvailableFareType (fareType : JRef FareType) (depDate : JRef JLocalDate) (today : JLocalDate) : JResult Bool := do
  let ft ← match fareType with
    | some f => pure f
    | none => throw (.illegalArgument "fareType must not null.")
  let d ← match depDate with
    | some d => pure d
    | none => throw (.illegalArgument "depDate must not null.")
  let s ← ft.rsrvAvailableStartDayNum.deref "rsrvAvailableStartDayNum"
  let e ← ft.rsrvAvailableEndDayNum.deref "rsrvAvailableEndDayNum"
  let startDate := d.minusDays s.val
  let endDate := d.minusDays e.val
  return !(today.isBefore startDate || today.isAfter endDate)

/-! ## DTO -/

/-- `TicketSearchCriteriaDto`（照会条件）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getArrivalAirportCd()@1c111d784bf8d220",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepDate()@9e5ad0157d1bece7",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepartureAirportCd()@08763144c723fca5",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getFlightType()@a815d39b257bbd2b",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setArrivalAirportCd(String)@922656e0efb53e00",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepDate(LocalDate)@e4d262f79ebcb7ac",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepartureAirportCd(String)@48b1037e44becf59",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setFlightType(FlightType)@7f178ac43c6090bd",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto.serialVersionUID@c846f41752a6a6bf"]
structure TicketSearchCriteriaDto where
  flightType : JRef Spec.Model.FlightType := none
  departureAirportCd : JRef String := none
  arrivalAirportCd : JRef String := none
  depDate : JRef JLocalDate := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  deriving DecidableEq, Repr

/-- `FareTypeVacantInfoDto`（運賃種別ごとの空席情報）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#<init>(String,String,Integer)@b5ab6bf246edfbbf",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFare()@3aecf0e9bebb654a",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFareTypeName()@fe0943673fcac4f0",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getVacantNum()@1727d00958d6c3a3",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto.serialVersionUID@dd46f950a2716a7f"]
structure FareTypeVacantInfoDto where
  fareTypeName : JRef String
  fare : JRef String
  vacantNum : JRef J32
  deriving DecidableEq, Repr

/-- `FlightVacantInfoDto`（便ごとの空席情報）。`fareTypes` は `LinkedHashMap<String, FareTypeVacantInfoDto>`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrAirportName()@168f6313b91f7efc",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrTime()@eba19a6e8cfe7373",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepAirportName()@613fd9acef107682",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepDate()@369d89134caefd5a",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepTime()@e8756384892001a1",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFareTypes()@b4cb9d39c4e1670d",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFlightName()@56b669a044a195ca",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrAirportName(String)@6ed33d2eb1ba891b",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrTime(String)@a72394c9d4069159",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepAirportName(String)@fccb4abecff6d001",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepDate(String)@962bd97bc530d3db",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepTime(String)@a032ee060e4c3da2",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFareTypes(Map)@28c6e4b5185f43b9",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFlightName(String)@c8ed541ae69f3cad",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto.serialVersionUID@c450724693049058"]
structure FlightVacantInfoDto where
  flightName : JRef String := none
  depAirportName : JRef String := none
  arrAirportName : JRef String := none
  depTime : JRef String := none
  arrTime : JRef String := none
  depDate : JRef String := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  fareTypes : JLinkedHashMap String FareTypeVacantInfoDto := {}
  deriving Repr

/-- `addFareTypeVacantInfo(fareTypeCd, info)`: `fareTypes.put(fareTypeCd.getCode(), info)`（`null` なら NPE）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#addFareTypeVacantInfo(FareTypeCd,FareTypeVacantInfoDto)@1c016d6655a35b9a"]
def FlightVacantInfoDto.addFareTypeVacantInfo (v : FlightVacantInfoDto) (fareTypeCd : JRef Spec.Model.FareTypeCd)
    (info : FareTypeVacantInfoDto) : JResult FlightVacantInfoDto := do
  let cd ← fareTypeCd.deref "fareTypeCd"
  return { v with fareTypes := v.fareTypes.put cd.toCode info }

/-! ## searchFlight（`TicketSearchServiceImpl`） -/

/-- `TicketSearchServiceImpl` が受けるもの（`@Inject`・`@Value`）と、今日の日付・リポジトリのポート。 -/
structure TicketSearchService where
  routeProvider : RouteProvider := {}
  fareTypeProvider : FareTypeProvider := {}
  flightMasterProvider : FlightMasterProvider := {}
  boardingClassProvider : BoardingClassProvider := {}
  ticketSharedService : SourceModel.Fare.TicketSharedService := {}
  /-- `atrs.limitDay`（`TicketSharedServiceImpl`） -/
  limitDay : J32
  /-- 今日の日付（`LocalDate.now(dateFactory.tick())`。D-014 の前提の下で 1 つの値） -/
  today : JLocalDate
  /-- `FlightRepository.findByVacantSeatSearchCriteria` -/
  flightRepository : VacantSeatSearchCriteriaDto → JResult (List Flight)

/-- `createFlightVacantInfo(flight)`（private）: グループの見出し。 -/
def createFlightVacantInfo (flight : Flight) : JResult FlightVacantInfoDto := do
  let fm ← flight.flightMaster.deref "flightMaster"
  let route ← fm.route.deref "route"
  let dep ← route.departureAirport.deref "departureAirport"
  let arr ← route.arrivalAirport.deref "arrivalAirport"
  let bc ← flight.boardingClass.deref "boardingClass"
  return { flightName := fm.flightName, depAirportName := dep.name, arrAirportName := arr.name,
           depTime := ← toFormatTimeString fm.departureTime, arrTime := ← toFormatTimeString fm.arrivalTime,
           depDate := some (toFormatDateString flight.departureDate), boardingClassCd := bc.boardingClassCd }

/-- `createFlightVacantInfoList(flightList, basicFare)`（private）: 便マスタの出発時刻をキーに `LinkedHashMap` へまとめ、
各フライトの運賃種別の空席情報を足す。値の列（挿入順）を返す。運賃の書式は `new DecimalFormat("###,###")`
（既定の書式ロケールの区切り文字。D-032 の前提の下で `,`）。 -/
@[source "lang:java#java.text.DecimalFormat@java-17", "lang:java#java.util.LinkedHashMap@java-17", gap "D-032"]
def createFlightVacantInfoList (flightList : List Flight) (basicFare : J32) : JResult (List FlightVacantInfoDto) := do
  let mut m : JLinkedHashMap (JRef String) FlightVacantInfoDto := {}
  for flight in flightList do
    let fm ← flight.flightMaster.deref "flightMaster"
    let departureTime := fm.departureTime
    let vacantInfo ← match m.get departureTime with
      | some v => pure v
      | none => createFlightVacantInfo flight
    let ft ← flight.fareType.deref "fareType"
    let fare ← SourceModel.Fare.calculateFare basicFare (← ft.discountRate.deref "discountRate")
    let info : FareTypeVacantInfoDto :=
      ⟨ft.fareTypeName, some (DecimalFormat.formatJ32 ',' fare), flight.vacantNum⟩
    -- 原典は、取り出した（または作って入れた）同じオブジェクトを更新する。ここでは更新した値を同じキーで置き直す
    m := m.put departureTime (← vacantInfo.addFareTypeVacantInfo ft.fareTypeCd info)
  return m.entries.map (·.2)

/-- `searchFlight(searchCriteria)`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchService#searchFlight(TicketSearchCriteriaDto)@aebd2fb115cd02fc",
  "java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)@75061ffc6ae02ecb",
  "dep:org.springframework:spring-core#Assert.notNull@spring-core-7.0.3", gap "D-001", "D-002", "D-014"]
def searchFlight (svc : TicketSearchService) (searchCriteria : JRef TicketSearchCriteriaDto) :
    JResult (List FlightVacantInfoDto) := do
  let c ← match searchCriteria with
    | some c => pure c
    | none => throw (.illegalArgument "searchCriteria must not null.")
  let depDate ← match c.depDate with
    | some d => pure d
    | none => throw (.illegalArgument "depDate must not null.")
  let boardingClassCd ← match c.boardingClassCd with
    | some b => pure b
    | none => throw (.illegalArgument "boardingClassCd must not null.")
  let depAirportCd := c.departureAirportCd.getD ""
  assertHasText depAirportCd "depAirportCd must have some text."
  let arrAirportCd := c.arrivalAirportCd.getD ""
  assertHasText arrAirportCd "arrAirportCd must have some text."
  let flightType ← match c.flightType with
    | some t => pure t
    | none => throw (.illegalArgument "flightType must not null.")
  validateDepatureDate svc.limitDay svc.today (some depDate)
  let route ← match ← getRouteByAirportCd svc.routeProvider depAirportCd arrAirportCd with
    | some r => pure r
    | none => throw (businessException (errorCode "e.ar.b1.2002"))
  let beforeDayNum := J64.ofInt (JLocalDate.daysBetween svc.today depDate)
  let fareTypeList := getFareTypeCdList (some flightType)
  let criteria : VacantSeatSearchCriteriaDto :=
    { depDate := some depDate, route := some route, boardingClass := some boardingClassCd,
      beforeDayNum := some beforeDayNum, fareTypeList := some fareTypeList }
  let flightList ← svc.flightRepository criteria
  if flightList.isEmpty then throw flightNotFound
  let flightList ← flightList.mapM fun flight => do
    let ftCd := (← flight.fareType.deref "fareType").fareTypeCd
    let fareType ← getFareType svc.fareTypeProvider ftCd
    let name ← match (← flight.flightMaster.deref "flightMaster").flightName with
      | some n => pure n
      | none => throw (.illegalArgument "flightName must have some text.")
    let flightMaster ← getFlightMaster svc.flightMasterProvider name
    let bcCd := (← flight.boardingClass.deref "boardingClass").boardingClassCd
    let boardingClass ← getBoardingClass svc.boardingClassProvider bcCd
    return { flight with fareType := fareType, flightMaster := flightMaster, boardingClass := boardingClass }
  let basicFareOfRoute ← route.basicFare.deref "basicFare"
  let basicFare ← SourceModel.Fare.calculateBasicFare svc.ticketSharedService basicFareOfRoute (some boardingClassCd)
    (some depDate)
  createFlightVacantInfoList flightList basicFare

/-! ## リポジトリのポートと実行 -/

/-- リポジトリのポート: 束縛した条件で SQL を評価し、並べ方 `sortRows` で並べて、`flight-map` で写す。
`sortRows` が `SortAllowed` を満たすとき、原典の許される結果の 1 つになる（標準は `standardSort`）。 -/
def repositoryOf (db : SourceModel.Repository.Schema.MasterDb) (fd : SourceModel.Repository.Schema.FlightDb)
    (sortRows : List VacantSeatRow → List VacantSeatRow) (c : VacantSeatSearchCriteriaDto) : JResult (List Flight) :=
  (sortRows (vacantSeatRows db fd (bind c))).mapM fun r => SourceModel.Repository.Mapping.flight r.result

/-- 空席照会の入力（状態 FLIGHT 以外）: DB のマスタ・注入された設定・今日の日付・照会条件。 -/
@[gap "D-027"]
structure SearchInput where
  db : SourceModel.Repository.Schema.MasterDb
  config : SourceModel.Config.AtrsConfig
  today : JLocalDate
  criteria : JRef TicketSearchCriteriaDto
  deriving DecidableEq, Repr

/-- 起動時の読み込みと `searchFlight`（マスタの文の並び `mo`、空席照会の文の並べ方 `sortRows` を選んだとき）。
状態の FLIGHT 表 `fd` は読むだけで変えない。backlog 0be7 の第 2 段の具体機械の 1 歩は、許される `mo`・`sortRows` の
どれかでこれを実行する関係とする（`mo.Allowed ic.db` と `SortAllowed sortRows` を課す）。 -/
def runSearchFlight (fd : SourceModel.Repository.Schema.FlightDb) (ic : SearchInput) (mo : SourceModel.MasterQuery.Order)
    (sortRows : List VacantSeatRow → List VacantSeatRow) : JResult (List FlightVacantInfoDto) := do
  let p ← SourceModel.MasterQuery.load mo
  let svc : TicketSearchService :=
    { routeProvider := p.route, fareTypeProvider := p.fareType, flightMasterProvider := p.flightMaster,
      boardingClassProvider := p.boardingClass, ticketSharedService := p.shared, limitDay := ic.config.limitDay,
      today := ic.today, flightRepository := repositoryOf ic.db fd sortRows }
  searchFlight svc ic.criteria

end SourceModel.FlightSearch
