import LangSemantics.Java
import SourceModel.AtrsProperties
import SourceModel.Db.Schema
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Repository.Flight.FlightRepository
import SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto
import SourceModel.Domain.Service.B1.FlightVacantInfoDto
import SourceModel.Domain.Service.B1.TicketSearchCriteriaDto
import SourceModel.Domain.Service.B1.TicketSearchServiceImpl
import SourceModel.MasterQuery
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Service.B1.FlightNotFoundException
import SourceModel.Domain.Service.B1.TicketSearchErrorCode
import SourceModel.Domain.Common.Util.FareTypeUtil
import SourceModel.Domain.Common.Util.DateTimeUtil
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Domain.Service.B1.FareTypeVacantInfoDto
import SourceModel.Db.Seed

/-!
# SourceModel.FlightSearchQuery

空席照会の具体機械（R 課題 ABS-011 の具体側。backlog 0be7 の第 2 段）。

- 状態は状態の表とシーケンス `FlightDb`（照会が読むのは FLIGHT 表）。初期状態は、シードの投入後の表 `Seed.seedDb`。照会は状態を変えない。
- 入力は、DB のマスタ・注入された設定・今日の日付・照会条件（`SourceModel.FlightSearchQuery.SearchInput`）。
- 1 歩は、マスタの文の許される並び `mo`（`Order.Allowed`）と、空席照会の文の許される並べ方 `sortRows`
  （`SortAllowed`）のどれかで、起動時の読み込みと `searchFlight` を実行する関係とする。原典はマスタを起動時に 1 度だけ
  読み込むが、この機械はマスタの並びを 1 歩ごとに選び直す。許す振る舞いが原典より多い（上からの近似）ので、
  リファインメントの証明には安全である（マスタの参照・運賃計算の具体機械と同じ扱い）。
- 業務例外（`AtrsBusinessException`・`FlightNotFoundException`）は、原典の画面・API が捕まえてメッセージに変える
  観測可能な結果なので、出力の値 `BusinessError` として受ける（ADR a4fa「エラーは値」）。それ以外の例外
  （前提違反・NPE など）は、例外の経路 `JThrow` に残す。
-/

namespace SourceModel.FlightSearchQuery
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata SourceModel.Domain.Repository.Flight
  SourceModel.Domain.Repository.Flight.FlightRepository
open SourceModel.Domain.Common.Exception SourceModel.Domain.Service.B1 SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareTypeUtil
  SourceModel.Domain.Common.Util.DateTimeUtil SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl SourceModel.Domain.Service.B1.FlightVacantInfoDto
  SourceModel.Domain.Service.B1.TicketSearchServiceImpl

open SourceModel.Db.Schema

/-- リポジトリのポート: 束縛した条件で SQL を評価し、並べ方 `sortRows` で並べて、`flight-map` で写す。
`sortRows` が `SortAllowed` を満たすとき、原典の許される結果の 1 つになる（標準は `standardSort`）。 -/
def repositoryOf (db : SourceModel.Db.Schema.MasterDb) (fd : SourceModel.Db.Schema.FlightDb)
    (sortRows : List VacantSeatRow → List VacantSeatRow) (c : VacantSeatSearchCriteriaDto) : JResult (List Flight) :=
  (sortRows (vacantSeatRows db fd (bind c))).mapM fun r => SourceModel.Domain.Repository.Flight.FlightRepository.flightMap r.result

/-- 空席照会の入力（状態 FLIGHT 以外）: DB のマスタ・注入された設定・今日の日付・照会条件。 -/
@[gap "D-027"]
structure SearchInput where
  db : SourceModel.Db.Schema.MasterDb
  config : SourceModel.AtrsProperties.AtrsConfig
  today : JLocalDate
  /-- `TicketSharedServiceImpl` が読む今日の日付（D-014） -/
  sharedClock : JLocalDate × JLocalDate
  criteria : JRef TicketSearchCriteriaDto
  /-- 配備の環境: 既定の書式ロケールの書式の記号（D-032） -/
  formatSymbols : DecimalFormat.Symbols
  deriving DecidableEq, Repr

/-- 起動時の読み込みと `searchFlight`（マスタの文の並び `mo`、空席照会の文の並べ方 `sortRows` を選んだとき）。
状態の FLIGHT 表 `fd` は読むだけで変えない。backlog 0be7 の第 2 段の具体機械の 1 歩は、許される `mo`・`sortRows` の
どれかでこれを実行する関係とする（`mo.Allowed ic.db` と `SortAllowed sortRows` を課す）。 -/
def runSearchFlight (fd : SourceModel.Db.Schema.FlightDb) (ic : SearchInput) (mo : SourceModel.MasterQuery.Order)
    (sortRows : List VacantSeatRow → List VacantSeatRow) : JResult (List FlightVacantInfoDto) := do
  let p ← SourceModel.MasterQuery.load mo
  let svc : TicketSearchServiceImpl :=
    { routeProvider := p.route, fareTypeProvider := p.fareType, flightMasterProvider := p.flightMaster,
      boardingClassProvider := p.boardingClass, ticketSharedService := p.shared, limitDay := ic.config.limitDay,
      today := ic.today, sharedClock := ic.sharedClock, formatSymbols := ic.formatSymbols, flightRepository := repositoryOf ic.db fd sortRows }
  searchFlight svc ic.criteria

/-- 業務例外（原典の `AtrsBusinessException` と、その派生の `FlightNotFoundException`）。 -/
inductive BusinessError where
  /-- `AtrsBusinessException(code)` -/
  | business (code : String)
  /-- `FlightNotFoundException`（照会結果 0 件） -/
  | notFound (code : String)
  deriving DecidableEq, Repr

/-- 具体機械の出力: 業務例外か、便ごとの空席情報の列。 -/
abbrev SearchOutput := Except BusinessError (List FlightVacantInfoDto)

/-- 業務例外を出力の値に変える。それ以外の例外は、そのまま例外とする。 -/
def catchBusiness (r : JResult (List FlightVacantInfoDto)) : JResult SearchOutput :=
  match r with
  | .ok v => .ok (.ok v)
  | .error (.other cls code) =>
    if cls = AtrsBusinessException.className then .ok (.error (.business code))
    else if cls = FlightNotFoundException.className then .ok (.error (.notFound code))
    else .error (.other cls code)
  | .error e => .error e

/-- 空席照会の具体機械。1 歩は、許される並びのどれかで照会し、状態を変えない。 -/
def searchConcrete : Machine.Concrete FlightDb SearchInput SearchOutput JThrow where
  Init t := t = SourceModel.Db.Seed.seedDb
  step t ic r := ∃ mo sortRows, mo.Allowed ic.db ∧ SortAllowed sortRows ∧
    r = (catchBusiness (runSearchFlight t ic mo sortRows)).map fun o => (t, o)

end SourceModel.FlightSearchQuery
