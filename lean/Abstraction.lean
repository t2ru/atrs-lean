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
import Abstraction.MasterData.Refines
import Abstraction.Fare.Factors
import Abstraction.Fare.Alpha
import Abstraction.Fare.FareRefines
import Abstraction.Fare.BasicFareRefines
import Abstraction.Fare.Load
import Abstraction.Fare.TotalAlpha
import Abstraction.Fare.Loop
import Abstraction.Fare.TotalFareRefines
import Abstraction.Adequacy

/-!
# Abstraction

抽象化証明課題（ABS-NNN）。`SourceModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `SourceModel`, `Spec`, `LangSemantics.Core`, `LangSemantics.Java`, `LangSemantics.Sql`, `Machine`, `Trace`。
汎用の補題（列・`mapM`・整列・結合・double の比較・汎用の核 `Machine.undefOrEq`・機械の並置 `Machine.Sum`）は、
スキルの assets にある。

## トップレベルの主定理（本ファイル）

| 定理 | 内容 |
| --- | --- |
| `Abstraction.refines` | `Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue` |
| `Abstraction.adequate` | `Machine.Adequate (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env` |

- `Spec.machine`・`SourceModel.machine` は、実装済みの範囲の機能の機械を同じ並びで並置したもの（`Machine.sum`）。
- `dev`・`devC`・`glue`・`env` は、各機能の R 課題の前提型の差異・貼り合わせ・環境の前提を並置したもの。
- 主定理は、R 課題ごとの義務の束（`Abstraction.Adequacy`）を `Machine.Adequate.sum` で並べて示す。
  機能を取り込んだら、その R 課題の束を並置に加える。主定理が `lake build` で通り続けることが、取り込みの条件である。

## R 課題（下の名前空間）

| ID | 機能 | 主定理（`Machine.Refines`） | 義務の束（`Machine.Adequate`） |
| --- | --- | --- | --- |
| ABS-026 | マスタ・設定・コードリストの読み込み | `Abstraction.MasterData.queryRefines` | `Abstraction.MasterData.queryAdequate` |
| ABS-001 | 基本運賃 | `Abstraction.Fare.basicFareRefines` | `Abstraction.Fare.basicFareAdequate` |
| ABS-002 | 運賃 | `Abstraction.Fare.fareRefines` | `Abstraction.Fare.fareAdequate` |
| ABS-004 | 合計金額 | `Abstraction.Fare.totalFareRefines` | `Abstraction.Fare.totalFareAdequate` |

## モジュール

| モジュール | 内容 |
| --- | --- |
| `Abstraction.Prim.Date` | `LocalDate` の通算日数と [Spec] の暦日の一致 |
| `Abstraction.MasterData.Join` | `routeFindAll`・`flightMasterFindAll` の形 |
| `Abstraction.MasterData.Key` | `RouteProvider` のキャッシュのキーの単射性 |
| `Abstraction.MasterData.Load` | Provider の `load()` の形（例外を投げない条件と、キャッシュの表） |
| `Abstraction.MasterData.AlphaLeaf` | ABS-026 の標準の抽象化 α の値の葉（数・暦日・時刻・コード）と核 |
| `Abstraction.MasterData.Alpha` | ABS-026 の α（DB の行・設定・問い合わせ・答え）、出力の核 `answerKer`、`dev_D027`（D-027） |
| `Abstraction.MasterData.Pre` | ABS-026 の前提の取り出し（α の分解、空白、値とコードの対応） |
| `Abstraction.MasterData.Lookup` | Provider のキャッシュの参照と、DB の行での検索の対応 |
| `Abstraction.MasterData.Query` | ABS-026 の問い合わせごとの一致（参照・ピーク時期・積算比率・コードリスト） |
| `Abstraction.MasterData.Refines` | R 課題 ABS-026 `queryRefines`、`InitSurj`、W 課題 ABS-127 `need_D027` |
| `Abstraction.MasterData.CodeList` | 空港コードリストと `insertNop` の一致、`JdbcCodeList` の値 |
| `Abstraction.Fare.Factors` | 運賃計算の因子の表、基本運賃（D-001）・運賃（D-002）の差異の条件と証拠、安全でない因子の一覧 |
| `Abstraction.Fare.Alpha` | 運賃計算の α（`aiBF`・`aiF`）と差異の述語 `dev_D001`・`dev_D002`・`dev_D027BF`・`dev_D027F` |
| `Abstraction.Fare.FareRefines` | R 課題 ABS-002 `fareRefines`、C 課題 ABS-003 `fare_diff`、W 課題 ABS-102 `need_D002` |
| `Abstraction.Fare.Load` | 合計金額の読み込みの補題（便マスタの区間の運賃、搭乗クラス・運賃種別の取り出し、`load_correct'`） |
| `Abstraction.Fare.TotalAlpha` | 合計金額の α（`aiTF`）と差異の述語 `dev_D001T`・`dev_D002T`・`dev_D012`・`dev_D027TF`、証人 |
| `Abstraction.Fare.Loop` | `for` 文（`forIn`）の和・計数、値域内の `int` の演算、`calculateBasicFare`・`calculateFare` の補題 |
| `Abstraction.Fare.TotalFareRefines` | R 課題 ABS-004 `totalFareRefines`、L 課題 ABS-005 `runTotalFare_eq`、W 課題 ABS-112 `need_D012` |
| `Abstraction.Fare.BasicFareRefines` | R 課題 ABS-001 `basicFareRefines`、L 課題 ABS-007 `runBasicFare_spec`、W 課題 ABS-101 `need_D001` |
| `Abstraction.Adequacy` | R 課題ごとの義務の束 `Machine.Adequate`（`queryAdequate`・`basicFareAdequate`・`fareAdequate`・`totalFareAdequate`。同じ課題 ID の `@[obligation]`）、環境の前提 `env*`、1 歩の可換式 `*Commutes` |
-/

namespace Abstraction

open Machine Abstraction.MasterData Abstraction.Fare

/-- 抽象側の前提型の差異（各 R 課題の `restrict` の述語を並置したもの）。 -/
def dev : Spec.Input → Prop :=
  sumPred (fun _ => True) (sumPred dev_D001 (sumPred dev_D002 fun i => dev_D001T i ∧ dev_D002T i ∧ dev_D012 i))

/-- 具体側の前提型の差異（D-027。各 R 課題の `Concrete.restrict` の述語を並置したもの）。 -/
def devC : SourceModel.Input → Prop :=
  sumPred dev_D027 (sumPred dev_D027BF (sumPred dev_D027F dev_D027TF))

/-- 貼り合わせ（各 R 課題の標準の貼り合わせを並置したもの）。 -/
def glue := glueMQ.sum (glueBF.sum (glueF.sum glueTF))

/-- 環境の前提（各 R 課題の環境の前提を並置したもの）。 -/
def env : Spec.Input → Prop := sumPred envMQ (sumPred envBF (sumPred envF envTF))

/-- トップレベルの義務の束: 実装済みの範囲の [Source] は、差異の前提の下で [Spec] をリファインし、
空虚化を防ぐ義務（`Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness`・環境の前提の必要性）を満たす。 -/
theorem adequate :
    Machine.Adequate (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env :=
  (queryAdequate.sum (basicFareAdequate.sum (fareAdequate.sum totalFareAdequate))).congrPre rfl rfl rfl
    (fun _ i => by
      rcases i with i | i | i | i
      · exact ⟨And.left, fun h => ⟨h, trivial⟩⟩
      · exact Iff.rfl
      · exact Iff.rfl
      · exact ⟨fun ⟨a, b, c, d⟩ => ⟨⟨⟨a, b⟩, c⟩, d⟩, fun ⟨⟨⟨a, b⟩, c⟩, d⟩ => ⟨a, b, c, d⟩⟩)
    rfl rfl (fun i => by rcases i with i | i | i | i <;> exact Iff.rfl)

/-- トップレベルの主定理: 実装済みの範囲の [Source] は、差異の前提の下で [Spec] をリファインする。 -/
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue :=
  adequate.refines

end Abstraction
