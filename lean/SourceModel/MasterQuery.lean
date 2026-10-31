import LangSemantics.Java
import LangSemantics.Sql
import Machine
import SourceModel.Repository.MasterData
import SourceModel.MasterData
import SourceModel.CodeList
import SourceModel.Config
import SourceModel.Fare
import Spec.MasterQuery

/-!
# SourceModel.MasterQuery

マスタ・設定・コードリストの参照の具体機械（R 課題 ABS-026 の具体側）。

入力は、DB のマスタの表（`MasterDb`）・注入された設定（`AtrsConfig`）・問い合わせである。原典は起動時に、
各 Provider の `load()`（Mapper の文）とコードリストの読み込み（コードリストの SQL）を行い、以後はキャッシュを引く。
Mapper の文の結果は順序が未規定で、`ORDER BY` の文は許される順列のどれかになる。そこで 1 歩は、
各文の結果の許される順列（`Order.Allowed`）のどれかを選んで読み込み、問い合わせに答える関係とする。
読み込みが例外を投げると、原典は起動しない（このモデルでは、その例外を結果とする）。
-/

namespace SourceModel.MasterQuery
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Sql.Query

open LangSemantics.Java SourceModel.Model SourceModel.Repository.Schema
  SourceModel.Repository.MasterData SourceModel.MasterData SourceModel.Config

/-- 問い合わせ（原典の各参照の呼び出し）。 -/
inductive SrcQuery where
  /-- `RouteProvider.getRouteByAirportCd` -/
  | routeOf (dep arr : String)
  /-- `FlightMasterProvider.getFlightMaster` -/
  | flightMasterOf (name : String)
  /-- `FareTypeProvider.getFareType` -/
  | fareTypeOf (cd : Spec.Model.FareTypeCd)
  /-- `BoardingClassProvider.getBoardingClass` -/
  | boardingClassOf (cd : Spec.Model.BoardingClassCd)
  /-- `PeakTimeProvider.getPeakTime` -/
  | peakTimeOn (d : JLocalDate)
  /-- `TicketSharedServiceImpl.getMultiplicationRatio`（private。`calculateBasicFare` が使う） -/
  | multiplicationRatioOn (d : JLocalDate)
  /-- 注入された設定 -/
  | config
  /-- コードリストの `asMap()` -/
  | codeList (n : Spec.MasterQuery.CodeListName)
  deriving DecidableEq, Repr

/-- 結果。 -/
inductive SrcAnswer where
  | route (r : JRef Route)
  | flightMaster (f : JRef FlightMaster)
  | fareType (f : JRef FareType)
  | boardingClass (b : JRef BoardingClass)
  | peakTime (p : JRef PeakTime)
  | ratio (n : J32)
  | config (c : AtrsConfig)
  | codeList (l : SourceModel.CodeList.Entries)
  deriving DecidableEq, Repr

/-- 入力。 -/
@[gap "D-027"]
structure SrcInput where
  db : MasterDb
  config : AtrsConfig
  query : SrcQuery
  deriving DecidableEq, Repr

/-- 各文の結果の並び（1 つの実行で DB から返った順）。 -/
structure Order where
  route : List RouteResult
  flightMaster : List FlightMasterResult
  boardingClass : List BoardingClassResult
  fareType : List FareTypeResult
  peakTime : List PeakTimeRow
  airportCl : List AirportRow
  boardingClassCl : List BoardingClassRow
  fareTypeCl : List FareTypeRow
  creditTypeCl : List CreditTypeRow

/-- 並びが許される: 順序の無い文は結果のバッグの並べ替え、`ORDER BY display_order` の文は `isAllowedOrder`。 -/
def Order.Allowed (db : MasterDb) (o : Order) : Prop :=
  o.route.Perm (routeFindAll db) ∧ o.flightMaster.Perm (flightMasterFindAll db) ∧
  o.boardingClass.Perm (boardingClassFindAll db) ∧ o.fareType.Perm (fareTypeFindAll db) ∧
  o.peakTime.Perm (peakTimeFindAll db) ∧
  isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (airportCodeListRows db) o.airportCl = true ∧
  isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (boardingClassCodeListRows db) o.boardingClassCl = true ∧
  isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (fareTypeCodeListRows db) o.fareTypeCl = true ∧
  isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (creditTypeCodeListRows db) o.creditTypeCl = true

/-- 起動時に読み込んだ Provider のキャッシュ。 -/
structure Providers where
  boardingClass : BoardingClassProvider
  fareType : FareTypeProvider
  peakTime : PeakTimeProvider
  route : RouteProvider
  flightMaster : FlightMasterProvider

/-- 起動時の読み込み（並び `o` を選んだとき）。各 Provider の `load()` を、原典の Bean の初期化の順に呼ぶ。 -/
def load (o : Order) : JResult Providers := do
  let bcp ← BoardingClassProvider.load o.boardingClass
  let ftp ← FareTypeProvider.load o.fareType
  let ptp := PeakTimeProvider.load o.peakTime
  let rtp ← RouteProvider.load o.route
  let fmp ← FlightMasterProvider.load o.flightMaster
  return ⟨bcp, ftp, ptp, rtp, fmp⟩

/-- `TicketSharedServiceImpl`（読み込んだ Provider を注入したもの）。 -/
def Providers.shared (p : Providers) : SourceModel.Fare.TicketSharedService :=
  { boardingClassProvider := p.boardingClass, peakTimeProvider := p.peakTime }

/-- 起動時の読み込みと、問い合わせへの答え（並び `o` を選んだとき）。 -/
def run (ic : SrcInput) (o : Order) : JResult SrcAnswer := do
  let p ← load o
  match ic.query with
  | .routeOf dep arr => return .route (← getRouteByAirportCd p.route dep arr)
  | .flightMasterOf name => return .flightMaster (← getFlightMaster p.flightMaster name)
  | .fareTypeOf cd => return .fareType (← getFareType p.fareType (some cd))
  | .boardingClassOf cd => return .boardingClass (← getBoardingClass p.boardingClass (some cd))
  | .peakTimeOn d => return .peakTime (← getPeakTime p.peakTime (some d))
  | .multiplicationRatioOn d => return .ratio (← SourceModel.Fare.getMultiplicationRatio p.shared (some d))
  | .config => return .config ic.config
  | .codeList n => return .codeList (match n with
    | .airport => SourceModel.CodeList.airport o.airportCl
    | .boardingClass => SourceModel.CodeList.boardingClass o.boardingClassCl
    | .fareType => SourceModel.CodeList.fareType o.fareTypeCl
    | .creditType => SourceModel.CodeList.creditType o.creditTypeCl
    | .creditMonth => SourceModel.CodeList.creditMonth
    | .creditYear => SourceModel.CodeList.creditYear
    | .gender => SourceModel.CodeList.gender
    | .flightType => SourceModel.CodeList.flightType)

/-- 標準の並び: 順序の無い文は評価の結果のまま、`ORDER BY` の文は安定整列（テストと参照に使う）。 -/
def standardOrder (db : MasterDb) : Order where
  route := routeFindAll db
  flightMaster := flightMasterFindAll db
  boardingClass := boardingClassFindAll db
  fareType := fareTypeFindAll db
  peakTime := peakTimeFindAll db
  airportCl := orderByStable sortCfg [.asc] (orderKey (·.displayOrder)) (airportCodeListRows db)
  boardingClassCl := orderByStable sortCfg [.asc] (orderKey (·.displayOrder)) (boardingClassCodeListRows db)
  fareTypeCl := orderByStable sortCfg [.asc] (orderKey (·.displayOrder)) (fareTypeCodeListRows db)
  creditTypeCl := orderByStable sortCfg [.asc] (orderKey (·.displayOrder)) (creditTypeCodeListRows db)

/-- 参照の具体機械（状態を持たない）。1 歩は、許される並びのどれかで読み込んで答える。 -/
def queryConcrete : Machine.Concrete Unit SrcInput SrcAnswer JThrow where
  Init _ := True
  step _ ic r := ∃ o, o.Allowed ic.db ∧ r = (run ic o).map fun a => ((), a)

end SourceModel.MasterQuery
