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

/-!
# Abstraction

抽象化証明課題（ABS-NNN）。`SourceModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `SourceModel`, `Spec`, `LangSemantics.Core`, `LangSemantics.Java`, `LangSemantics.Sql`, `Machine`, `Trace`。
汎用の補題（列・`mapM`・整列・結合・double の比較・汎用の核 `Machine.Kernel.undefOrEq`）は、スキルの assets にある。
機能の証明課題（R・W・C 課題と付帯の義務）は機能のモジュール（`Abstraction.Fare`・`Abstraction.MasterData`）に、
その補題は下位のモジュールに置く（port-lang の `lang/lean/rules.md#証明課題の配置`）。

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
| `Abstraction.MasterData.QueryRun` | ABS-026・ABS-127 の補題: 貼り合わせ `glueMQ`、読み込みと実行の正しさ、Mapper の結果の並び |
| `Abstraction.MasterData` | 機能の証明課題: R 課題 ABS-026 `queryRefines` と `InitSurj`、W 課題 ABS-127 `need_D027` |
| `Abstraction.MasterData.CodeList` | 空港コードリストと `insertNop` の一致、`JdbcCodeList` の値 |
| `Abstraction.Fare.Factors` | 運賃計算の因子の表、基本運賃（D-001）・運賃（D-002）の差異の条件と証拠、安全でない因子の一覧 |
| `Abstraction.Fare.Alpha` | 運賃計算の α（`aiBF`・`aiF`）と差異の述語 `dev_D001`・`dev_D002`・`dev_D027BF`・`dev_D027F` |
| `Abstraction.Fare.FareRun` | ABS-002・ABS-003・ABS-102 の補題: `calculateFare` の値、[Spec] の運賃の値域 |
| `Abstraction.Fare.Load` | 合計金額の読み込みの補題（便マスタの区間の運賃、搭乗クラス・運賃種別の取り出し、`load_correct'`） |
| `Abstraction.Fare.TotalAlpha` | 合計金額の α（`aiTF`）と差異の述語 `dev_D001T`・`dev_D002T`・`dev_D012`・`dev_D027TF`、証人 |
| `Abstraction.Fare.Loop` | `for` 文（`forIn`）の和・計数、値域内の `int` の演算、`calculateBasicFare`・`calculateFare` の補題 |
| `Abstraction.Fare.TotalFareRun` | ABS-004・ABS-112 の補題、L 課題 ABS-005 `runTotalFare_eq` |
| `Abstraction.Fare.BasicFareRun` | ABS-001・ABS-101 の補題、L 課題 ABS-007 `runBasicFare_spec` |
| `Abstraction.Fare` | 機能の証明課題: R 課題 ABS-001 `basicFareRefines`・ABS-002 `fareRefines`・ABS-004 `totalFareRefines` と `InitSurj`、C 課題 ABS-003 `fare_diff`、W 課題 ABS-101 `need_D001`・ABS-102 `need_D002`・ABS-112 `need_D012` |
-/

namespace Abstraction
end Abstraction
