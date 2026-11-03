import LangSemantics.Java
import LangSemantics.Sql
import Spec
import Trace
import SourceModel.Domain.Model.BoardingClassCd
import SourceModel.Domain.Model.FareTypeCd
import SourceModel.Domain.Model.Airport
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Model.Plane
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.PeakTime
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.PeakTimeProvider
import SourceModel.Domain.Common.Masterdata.FareTypeProvider
import SourceModel.Domain.Common.Masterdata.RouteProvider
import SourceModel.Domain.Common.Masterdata.FlightMasterProvider
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Domain.Common.Util.FareUtil
import SourceModel.Domain.Service.B2.TicketReserveServiceImpl
import SourceModel.Db.Schema
import SourceModel.Domain.Repository.Route.RouteRepository
import SourceModel.Domain.Repository.Flight.FlightRepository
import SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository
import SourceModel.Domain.Repository.Faretype.FareTypeRepository
import SourceModel.Domain.Repository.Peaktime.PeakTimeRepository
import SourceModel.Config.App.AtrsCodeListConfig
import SourceModel.Db.MyBatis
import SourceModel.Gfw.CodeList
import SourceModel.Domain.Common.Codelist.AirportCodeList
import SourceModel.AtrsProperties
import SourceModel.MasterQuery
import SourceModel.App.B0.SelectFlightForm
import SourceModel.App.B0.TicketHelper
import SourceModel.FareQuery
import SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Service.B1.FlightNotFoundException
import SourceModel.Domain.Service.B1.TicketSearchErrorCode
import SourceModel.Domain.Common.Util.FareTypeUtil
import SourceModel.Domain.Common.Util.DateTimeUtil
import SourceModel.Domain.Service.B1.TicketSearchCriteriaDto
import SourceModel.Domain.Service.B1.FareTypeVacantInfoDto
import SourceModel.Domain.Service.B1.FlightVacantInfoDto
import SourceModel.Domain.Service.B1.TicketSearchServiceImpl
import SourceModel.FlightSearchQuery
import SourceModel.ReserveQuery
import SourceModel.Db.FlightSeed
import SourceModel.Db.MemberSeed
import SourceModel.Db.MasterSeed
import SourceModel.Db.Seed

/-!
# SourceModel

移植元モデル。移植元ソース（Java/SQL）の振る舞いを、意味論ごと写す。
依存してよいもの: `LangSemantics.Java`, `LangSemantics.Sql`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）に依存してはならない。

モジュールは、原典の Java のソースツリーと同じ形に並べる（ADR e41c、スキルの `lang/java/layout.md`）。
原典のクラス `jp.co.ntt.atrs.<pkg>.<Class>` は、モジュール `SourceModel.<Pkg>.<Class>`（パッケージの各成分の先頭を大文字に
したもの）に写し、クラスの型はモジュールと同じ名前、メソッドは `<Class>.<method>` とする。Mapper の XML の文は、同じ
パッケージのリポジトリのモジュール（`…Repository`）に写す。対応は `trace check` の TR-M が確かめる。

| モジュール | 内容 |
| --- | --- |
| `SourceModel.Domain.*`・`SourceModel.App.*`・`SourceModel.Config.*` | 原典のクラスの写し（`jp.co.ntt.atrs.domain.*`・`app.*`・`config.*`）。例: `Domain.Service.B0.TicketSharedServiceImpl`（運賃計算・照会可能期間）、`Domain.Common.Masterdata.*Provider`（マスタの Provider）、`Domain.Repository.*.*Repository`（Mapper の文と resultMap）、`App.B0.TicketHelper` |
| `SourceModel.Db.Schema`・`SourceModel.Db.FlightSeed` | 表の行と DB の状態、シードの FLIGHT 表（`tools/conformance/flight_seed.py` が生成） |
| `SourceModel.Db.MyBatis` | MyBatis の型の対応（`INT`・`DATE`・`VARCHAR` の値を Java の値に） |
| `SourceModel.Gfw.CodeList` | TERASOLUNA のコードリスト（`CodeList.asMap()` の値・`NumberRangeCodeList`） |
| `SourceModel.AtrsProperties` | `@Value` で注入される設定（`atrs.properties`） |
| `SourceModel.MasterQuery` | マスタ・設定・コードリストの参照の具体機械（ABS-026 の具体側） |
| `SourceModel.FareQuery` | 運賃計算の具体機械（ABS-001・ABS-002・ABS-004 の具体側） |
| `SourceModel.FlightSearchQuery` | 空席照会の具体機械（ABS-011 の具体側。リポジトリのポートの組み立てと実行。状態は FLIGHT 表、業務例外は出力の値） |

原典のクラスに当たらないもの（具体機械、DB の状態、フレームワークの値、設定）は、原典のソースツリーの外
（`Domain`・`App`・`Config`・`Api` の外）に置く。

トップレベルの具体機械 `SourceModel.machine` は、`Spec.machine` と同じ並びで、各機能の具体機械を並置したもの
（`Machine.Concrete.sum`。状態を共有する空席照会と予約は `Machine.Concrete.alt`）である。`Abstraction` の主定理の
具体側になる。
-/

namespace SourceModel
open LangSemantics.Java.Int LangSemantics.Java.Exception

/-- トップレベルの具体機械の入力（`Spec.Input` と同じ並び）。 -/
abbrev Input := MasterQuery.SrcInput ⊕ FareQuery.BasicFareInput ⊕ FareQuery.FareInput ⊕ FareQuery.TotalFareInput ⊕
  (SourceModel.FlightSearchQuery.SearchInput ⊕ ReserveQuery.MInput)

/-- トップレベルの具体機械の出力。 -/
abbrev Output := MasterQuery.SrcAnswer ⊕ J32 ⊕ J32 ⊕ J32 ⊕ (FlightSearchQuery.SearchOutput ⊕ ReserveQuery.MOutput)

/-- トップレベルの具体機械: 実装済みの範囲の機能の具体機械を並置したもの。 -/
def machine : Machine.Concrete (Unit × Unit × Unit × Unit × SourceModel.Db.Schema.FlightDb) Input Output JThrow :=
  MasterQuery.queryConcrete.sum (FareQuery.basicFareConcrete.sum (FareQuery.fareConcrete.sum
    (FareQuery.totalFareConcrete.sum (FlightSearchQuery.searchConcrete.alt ReserveQuery.reserveConcrete))))

end SourceModel
