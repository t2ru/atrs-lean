import LangSemantics.Java
import LangSemantics.Sql
import Spec
import Trace
import SourceModel.Model
import SourceModel.MasterData
import SourceModel.Fare
import SourceModel.Repository.Schema
import SourceModel.Repository.MasterData
import SourceModel.Repository.Mapping
import SourceModel.CodeList
import SourceModel.Config
import SourceModel.MasterQuery
import SourceModel.Ticket
import SourceModel.FareQuery
import SourceModel.Repository.Flight
import SourceModel.FlightSearch

/-!
# SourceModel

移植元モデル。移植元ソース（Java/SQL）の振る舞いを、意味論ごと写す。
依存してよいもの: `LangSemantics.Java`, `LangSemantics.Sql`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）に依存してはならない。

| モジュール | 内容 |
| --- | --- |
| `SourceModel.Model` | 原典の domain model |
| `SourceModel.Repository.*` | 表の行（`Schema`）、マスタの Mapper の文（`MasterData`）、MyBatis の対応（`Mapping`） |
| `SourceModel.MasterData` | マスタの Provider（`load()` とキャッシュの参照） |
| `SourceModel.CodeList` | コードリスト |
| `SourceModel.Config` | 注入される設定 |
| `SourceModel.MasterQuery` | マスタ・設定・コードリストの参照の具体機械（ABS-026 の具体側） |
| `SourceModel.Fare` | 運賃計算 |
| `SourceModel.Ticket` | 選択フライト情報からフライト情報を組み立てる部分（`TicketHelper.toFlightList`） |
| `SourceModel.FareQuery` | 運賃計算の具体機械（ABS-001・ABS-002・ABS-004 の具体側） |
| `SourceModel.Repository.Flight` | 空席照会の Mapper の文 `findByVacantSeatSearchCriteria`（SQL の写しと許される並び）。FLIGHT 表は状態 `FlightDb` |
| `SourceModel.FlightSearch` | 空席照会（`TicketSearchServiceImpl.searchFlight`・照会可能期間・`FareTypeUtil`・`DateTimeUtil`）。具体機械は backlog 0be7 の第 2 段 |

トップレベルの具体機械 `SourceModel.machine` は、`Spec.machine` と同じ並びで、各機能の具体機械を並置したもの
（`Machine.Concrete.sum`）である。`Abstraction` の主定理の具体側になる。
-/

namespace SourceModel
open LangSemantics.Java.Int LangSemantics.Java.Exception


/-- トップレベルの具体機械の入力（`Spec.Input` と同じ並び）。 -/
abbrev Input := MasterQuery.SrcInput ⊕ FareQuery.BasicFareInput ⊕ FareQuery.FareInput ⊕ FareQuery.TotalFareInput

/-- トップレベルの具体機械の出力。 -/
abbrev Output := MasterQuery.SrcAnswer ⊕ J32 ⊕ J32 ⊕ J32

/-- トップレベルの具体機械: 実装済みの範囲の機能の具体機械を並置したもの。 -/
def machine : Machine.Concrete (Unit × Unit × Unit × Unit) Input Output JThrow :=
  MasterQuery.queryConcrete.sum (FareQuery.basicFareConcrete.sum (FareQuery.fareConcrete.sum FareQuery.totalFareConcrete))

end SourceModel
