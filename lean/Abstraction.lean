import SourceModel
import Spec
import Trace
import Abstraction.Gap
import Abstraction.Prim.Date
import Abstraction.MasterData.Join
import Abstraction.MasterData.Key
import Abstraction.MasterData.Load
import Abstraction.MasterData.CodeList
import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import Abstraction.MasterData.Pre
import Abstraction.MasterData.Lookup
import Abstraction.MasterData.Query
import Abstraction.MasterData.QueryRun
import Abstraction.MasterData
import Abstraction.Fare.Factors
import Abstraction.Fare.Alpha
import Abstraction.Fare.FareRun
import Abstraction.Fare.BasicFareRun
import Abstraction.Fare.Load
import Abstraction.Fare.TotalAlpha
import Abstraction.Fare.Loop
import Abstraction.Fare.TotalFareRun
import Abstraction.Fare
import Abstraction.World.Alpha
import Abstraction.FlightSearch.Alpha
import Abstraction.FlightSearch.Format
import Abstraction.FlightSearch.Period
import Abstraction.World.Init
import Abstraction.FlightSearch.Join
import Abstraction.FlightSearch.Candidates
import Abstraction.FlightSearch.Order
import Abstraction.FlightSearch.Group
import Abstraction.FlightSearch.Providers
import Abstraction.FlightSearch.Run
import Abstraction.FlightSearch.Witness
import Abstraction.FlightSearch.Preserves
import Abstraction.FlightSearch
import Abstraction.Reserve.Alpha
import Abstraction.Reserve.Port
import Abstraction.Reserve.Member
import Abstraction.Reserve.Providers
import Abstraction.Reserve.Flights
import Abstraction.Reserve.Select
import Abstraction.Reserve.Tx
import Abstraction.Reserve.ValidateFlights
import Abstraction.Reserve.Validate
import Abstraction.Reserve.MemberCheck
import Abstraction.Reserve.ValidateReservation
import Abstraction.Reserve.TotalFare
import Abstraction.Reserve.Selects
import Abstraction.Reserve.Catch
import Abstraction.Reserve.Draft
import Abstraction.Reserve.SpecFacts
import Abstraction.Reserve.Confirm
import Abstraction.Reserve.Input
import Abstraction.Reserve.NoNL
import Abstraction.Reserve.ConfirmRun
import Abstraction.Reserve.Vacancy
import Abstraction.Reserve.Register
import Abstraction.Reserve.Insert
import Abstraction.Reserve.Rollback
import Abstraction.Reserve.RegSpec
import Abstraction.Reserve.RegisterRun
import Abstraction.Reserve.Keys
import Abstraction.Reserve.FlightFacts
import Abstraction.Reserve.Registration
import Abstraction.Reserve.Witness

/-!
# Abstraction

抽象化証明課題（ABS-NNN）。`SourceModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `SourceModel`, `Spec`, `LangSemantics.Core`, `LangSemantics.Java`, `LangSemantics.Sql`, `Machine`, `Trace`。
汎用の補題（列・`mapM`・整列・結合・double の比較・汎用の核 `Machine.Kernel.undefOrEq`・機械の並置 `Machine.Sum`）は、
スキルの assets にある。
機能の証明課題（R・W・C 課題と付帯の義務、束 `Machine.Preserves`）は機能のモジュール（`Abstraction.Fare`・`Abstraction.MasterData`・`Abstraction.FlightSearch`）に、
その補題は下位のモジュールに置く（spec-pivot の `lang/lean/rules.md#証明課題の配置`）。

## トップレベルの主定理（本ファイル）

| 定理 | 内容 |
| --- | --- |
| `Abstraction.refines` | B refines A: `Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue` |
| `Abstraction.preserves` | A preserves B: `Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env` |
| `Abstraction.abstracts` | A abstracts B = A preserves B ∧ B refines A: `Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env` |

- `Spec.machine`・`SourceModel.machine` は、実装済みの範囲の機能の機械を同じ並びで並置したもの（`Machine.sum`）。
- `dev`・`devC`・`glue`・`env` は、各機能の R 課題の前提型の差異・貼り合わせ・環境の前提を並置したもの。
- `refines` は R 課題の主定理（`*Refines`）を `Machine.Refines.sum` で、`preserves` は R 課題ごとの束（機能のモジュールの
  `*Preserves`）を `Machine.Preserves.sum` で並べて示す。互いを使わない。`abstracts` は両者の組である。
  機能を取り込んだら、その R 課題の主定理と束を並置に加える。主定理が `lake build` で通り続けることが、取り込みの条件である。

## R 課題（下の名前空間）

| ID | 機能 | 主定理（`Machine.Refines`） | 束（`Machine.Preserves`） |
| --- | --- | --- | --- |
| ABS-026 | マスタ・設定・コードリストの読み込み | `Abstraction.MasterData.queryRefines` | `Abstraction.MasterData.queryPreserves` |
| ABS-001 | 基本運賃 | `Abstraction.Fare.basicFareRefines` | `Abstraction.Fare.basicFarePreserves` |
| ABS-002 | 運賃 | `Abstraction.Fare.fareRefines` | `Abstraction.Fare.farePreserves` |
| ABS-004 | 合計金額 | `Abstraction.Fare.totalFareRefines` | `Abstraction.Fare.totalFarePreserves` |
| ABS-011 | 空席照会 | `Abstraction.FlightSearch.searchRefines` | `Abstraction.FlightSearch.searchPreserves` |

## モジュール

| モジュール | 内容 |
| --- | --- |
| `Abstraction.Prim.Date` | `LocalDate` の通算日数と [Spec] の暦日の一致 |
| `Abstraction.MasterData.Join` | `RouteRepository.findAll`・`FlightRepository.findAllFlightMaster` の形 |
| `Abstraction.MasterData.Key` | `RouteProvider` のキャッシュのキーの単射性 |
| `Abstraction.MasterData.Load` | Provider の `load()` の形（例外を投げない条件と、キャッシュの表） |
| `Abstraction.MasterData.AlphaLeaf` | ABS-026 の標準の抽象化 α の値の葉（数・暦日・時刻・コード）と核 |
| `Abstraction.MasterData.Alpha` | ABS-026 の α（DB の行・設定・問い合わせ・答え）、出力の核 `answerKer`、`dev_D027`（D-027） |
| `Abstraction.MasterData.Pre` | ABS-026 の前提の取り出し（α の分解、空白、値とコードの対応） |
| `Abstraction.MasterData.Lookup` | Provider のキャッシュの参照と、DB の行での検索の対応 |
| `Abstraction.MasterData.Query` | ABS-026 の問い合わせごとの一致（参照・ピーク時期・積算比率・コードリスト） |
| `Abstraction.MasterData.QueryRun` | ABS-026・ABS-127 の補題: 貼り合わせ `glueMQ`、読み込みと実行の正しさ、Mapper の結果の並び |
| `Abstraction.MasterData.Preserves` | ABS-026 の束 `Machine.Preserves` の部品: 環境の前提 `envMQ` と証人 |
| `Abstraction.MasterData` | 機能の証明課題: 束 `queryPreserves` と 1 歩の可換式 `queryRefines_commutes`、R 課題 ABS-026 `queryRefines` と `InitSurj`、W 課題 ABS-127 `need_D027` |
| `Abstraction.MasterData.CodeList` | 空港コードリストと `insertNop` の一致、`JdbcCodeList` の値 |
| `Abstraction.Fare.Factors` | 運賃計算の因子の表、基本運賃（D-001）・運賃（D-002）の差異の条件と証拠、安全でない因子の一覧 |
| `Abstraction.Fare.Alpha` | 運賃計算の α（`aiBF`・`aiF`）と差異の述語 `dev_D001`・`dev_D002`・`dev_D027BF`・`dev_D027F` |
| `Abstraction.Fare.FareRun` | ABS-002・ABS-003・ABS-102 の補題: `calculateFare` の値、[Spec] の運賃の値域 |
| `Abstraction.Fare.Load` | 合計金額の読み込みの補題（便マスタの区間の運賃、搭乗クラス・運賃種別の取り出し、`load_correct'`） |
| `Abstraction.Fare.TotalAlpha` | 合計金額の α（`aiTF`）と差異の述語 `dev_D001T`・`dev_D002T`・`dev_D012`・`dev_D027TF`、証人 |
| `Abstraction.Fare.Loop` | `for` 文（`forIn`）の和・計数、値域内の `int` の演算、`calculateBasicFare`・`calculateFare` の補題 |
| `Abstraction.Fare.TotalFareRun` | ABS-004・ABS-112 の補題、L 課題 ABS-005 `runTotalFare_eq` |
| `Abstraction.Fare.BasicFareRun` | ABS-001・ABS-101 の補題、L 課題 ABS-007 `runBasicFare_spec` |
| `Abstraction.Fare.Preserves` | ABS-001・ABS-002・ABS-004 の束 `Machine.Preserves` の部品: 環境の前提 `envBF`・`envF`・`envTF` と証人 |
| `Abstraction.Fare` | 機能の証明課題: 束 `basicFarePreserves`・`farePreserves`・`totalFarePreserves` と 1 歩の可換式 `*Refines_commutes`、R 課題 ABS-001 `basicFareRefines`・ABS-002 `fareRefines`・ABS-004 `totalFareRefines` と `InitSurj`、C 課題 ABS-003 `fare_diff`、W 課題 ABS-101 `need_D001`・ABS-102 `need_D002`・ABS-112 `need_D012` |
| `Abstraction.World.Alpha` | 状態の表とシーケンスの α `worldOfDb`（FLIGHT・MEMBER・MEMBER_LOGIN・RESERVATION・RESERVE_FLIGHT・PASSENGER・シーケンス）と核、具体側の不変条件 `IcW`（空席照会と予約が共有する） |
| `Abstraction.World.Init` | 初期状態の対応 `worldOfDb_seed`・`icW_seed` |
| `Abstraction.FlightSearch.Alpha` | 空席照会の α（入力 `aiS`、出力 `aoS`、環境 `ceFS`）と核、貼り合わせ `glueFS`、差異の述語 `dev_D001S`・`dev_D002S`・`dev_D014S`・`dev_D027S`・`dev_D032` |
| `Abstraction.FlightSearch.Format` | 書式の一致（3 桁区切り・時刻・日付） |
| `Abstraction.FlightSearch.Period` | 照会可能期間の検査の一致、L 課題 ABS-010 `isAvailableFareType_between` |
| `Abstraction.FlightSearch.Join` | 空席照会の文の結合と、FLIGHT の行ごとの評価 `rowAt` |
| `Abstraction.FlightSearch.Candidates` | 行ごとの対応 `rowAt_rel`、結果の行の α `candOfRow`、列の対応 `rows_cands` |
| `Abstraction.FlightSearch.Order` | `ORDER BY` と `mergeSort candidateLe`（`sorted_cands`）、同順位の無さ `noTie_cands`、許される並びの証人 `mergeSortRows` |
| `Abstraction.FlightSearch.Group` | `createFlightVacantInfoList` の畳み込みと `group`（`group_spec`） |
| `Abstraction.FlightSearch.Providers` | キャッシュの答え（`flightMaster_full`・`load_fs`） |
| `Abstraction.FlightSearch.Run` | ABS-011 の 1 歩 `run_spec` |
| `Abstraction.FlightSearch.Witness` | W 課題 ABS-114・ABS-132 の証人、差異の述語の非自明性 |
| `Abstraction.FlightSearch.Preserves` | ABS-011 の束の部品: 環境の前提 `envFS`、選択の像の材料 `chFS` |
| `Abstraction.FlightSearch` | 機能の証明課題: R 課題 ABS-011 `searchRefines` と `InitSurj`、束 `searchPreserves`、W 課題 ABS-114 `need_D014`・ABS-132 `need_D032` |
-/

namespace Abstraction

open Machine Abstraction.MasterData Abstraction.Fare Abstraction.MasterData.Preserves
  Abstraction.Fare.Preserves
open Abstraction.FlightSearch Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Preserves
open Abstraction.MasterData.Alpha Abstraction.Fare.Alpha Abstraction.Fare.TotalAlpha Abstraction.MasterData.QueryRun
  Machine.Sum

/-- 抽象側の前提型の差異（各 R 課題の `restrict` の述語を並置したもの）。 -/
def dev : Spec.Input → Prop :=
  sumPred (fun _ => True) (sumPred dev_D001 (sumPred dev_D002 (sumPred (fun i => dev_D001T i ∧ dev_D002T i ∧ dev_D012 i)
    fun i => dev_D001S i ∧ dev_D002S i)))

/-- 具体側の前提型の差異（D-027。各 R 課題の `Concrete.restrict` の述語を並置したもの）。 -/
def devC : SourceModel.Input → Prop :=
  sumPred dev_D027 (sumPred dev_D027BF (sumPred dev_D027F (sumPred dev_D027TF fun ic => dev_D027S ic ∧ dev_D014S ic ∧ dev_D032 ic)))

/-- 貼り合わせ（各 R 課題の標準の貼り合わせを並置したもの）。 -/
def glue := glueMQ.sum (glueBF.sum (glueF.sum (glueTF.sum glueFS)))

/-- 環境の前提（各 R 課題の環境の前提を並置したもの）。 -/
def env : Spec.Input → Prop := sumPred envMQ (sumPred envBF (sumPred envF (sumPred envTF envFS)))

/-- トップレベルの主定理（A preserves B）: 実装済みの範囲で、[Spec] は [Source] の振る舞いを空虚にせず保つ
（`Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness`・環境の前提の必要性）。R 課題ごとの束 `*Preserves` を並置して示し、
`Refines` を使わない。並置 `Preserves.sum` は全 R 課題に共通の 6 成分の束を並べるので、基底が `ofChoice` の R 課題（ABS-011）は、
条件付きの成分（`pinned`・`noFault`・`freeFrame`・`stateSafeC`）を忘れた束 `searchPreserves.core` を並置する。条件付きの成分は、
機能の束 `Abstraction.FlightSearch.searchPreserves` で示す。 -/
theorem preserves :
    Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env :=
  (queryPreserves.sum (basicFarePreserves.sum (farePreserves.sum
    (totalFarePreserves.sum searchPreserves.core)))).congrPre rfl rfl rfl
    (fun _ i => by
      rcases i with i | i | i | i | i
      · exact ⟨And.left, fun h => ⟨h, trivial⟩⟩
      · exact Iff.rfl
      · exact Iff.rfl
      · exact ⟨fun ⟨a, b, c, d⟩ => ⟨⟨⟨a, b⟩, c⟩, d⟩, fun ⟨⟨⟨a, b⟩, c⟩, d⟩ => ⟨a, b, c, d⟩⟩
      · exact ⟨fun ⟨a, b, c⟩ => ⟨⟨a, b⟩, c⟩, fun ⟨⟨a, b⟩, c⟩ => ⟨a, b, c⟩⟩)
    rfl (fun i => by
      rcases i with i | i | i | i | i
      any_goals exact Iff.rfl
      exact ⟨fun ⟨a, b, c, d⟩ => ⟨⟨⟨a, b⟩, c⟩, d⟩, fun ⟨⟨⟨a, b⟩, c⟩, d⟩ => ⟨a, b, c, d⟩⟩)

/-- トップレベルの主定理（B refines A）: 実装済みの範囲の [Source] は、差異の前提の下で [Spec] を B メソッドの意味で
リファインする。R 課題ごとの主定理 `*Refines` を並置して示す（束 `preserves` を使わない）。 -/
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue :=
  (queryRefines.sum (basicFareRefines.sum (fareRefines.sum (totalFareRefines.sum searchRefines)))).congrPre rfl rfl rfl
    (fun _ i => by
      rcases i with i | i | i | i | i
      · exact ⟨And.left, fun h => ⟨h, trivial⟩⟩
      · exact Iff.rfl
      · exact Iff.rfl
      · exact ⟨fun ⟨a, b, c, d⟩ => ⟨⟨⟨a, b⟩, c⟩, d⟩, fun ⟨⟨⟨a, b⟩, c⟩, d⟩ => ⟨a, b, c, d⟩⟩
      · exact ⟨fun ⟨a, b, c⟩ => ⟨⟨a, b⟩, c⟩, fun ⟨⟨a, b⟩, c⟩ => ⟨a, b, c⟩⟩)
    rfl rfl (fun i => by
      rcases i with i | i | i | i | i
      any_goals exact Iff.rfl
      exact ⟨fun ⟨a, b, c, d⟩ => ⟨⟨⟨a, b⟩, c⟩, d⟩, fun ⟨⟨⟨a, b⟩, c⟩, d⟩ => ⟨a, b, c, d⟩⟩)

/-- トップレベルの主定理（A abstracts B = A preserves B ∧ B refines A）。系として、初期状態からの複数歩の模倣
（`Machine.Abstracts.run_init`）と、[Source] の正常終了が実在すること（`Machine.Abstracts.exists_ok`）が成り立つ。 -/
theorem abstracts :
    Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env :=
  ⟨preserves, refines⟩

end Abstraction
