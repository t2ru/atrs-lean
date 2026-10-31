import SourceModel
import Spec
import Trace
import Abstraction.Gap
import Abstraction.Prim.Date
import Abstraction.Prim.List
import Abstraction.Prim.Order
import Abstraction.MasterData.Join
import Abstraction.MasterData.Key
import Abstraction.MasterData.Load
import Abstraction.MasterData.CodeList
import Abstraction.Prim.Kernel
import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import Abstraction.Prim.MapM
import Abstraction.MasterData.Pre
import Abstraction.MasterData.Lookup
import Abstraction.MasterData.Query
import Abstraction.MasterData.Refines
import Abstraction.Fare.Double
import Abstraction.Fare.Factors
import Abstraction.Fare.Alpha
import Abstraction.Fare.FareRefines
import Abstraction.Fare.BasicFareRefines

/-!
# Abstraction

抽象化証明課題（ABS-NNN）。`SourceModel` が `Spec` を B メソッドの意味でリファインすることを証明する。
依存してよいもの: `SourceModel`, `Spec`, `LangSemantics.Java`, `LangSemantics.Sql`, `Machine`, `Trace`。

| モジュール | 内容 |
| --- | --- |
| `Abstraction.Prim.Date` | `LocalDate` の通算日数と [Spec] の暦日の一致 |
| `Abstraction.Prim.List` | 一意な検索の並べ替えへの不変性、キーでの選択、結合の補題 |
| `Abstraction.Prim.Order` | `ORDER BY` の許される順列と [Spec] の `mergeSort` の一致 |
| `Abstraction.MasterData.Join` | `routeFindAll`・`flightMasterFindAll` の形 |
| `Abstraction.MasterData.Key` | `RouteProvider` のキャッシュのキーの単射性 |
| `Abstraction.MasterData.Load` | Provider の `load()` の形（例外を投げない条件と、キャッシュの表） |
| `Abstraction.Prim.Kernel` | 部分写像の汎用の核 `undefOrEq` |
| `Abstraction.MasterData.AlphaLeaf` | ABS-026 の標準の抽象化 α の値の葉（数・暦日・時刻・コード）と核 |
| `Abstraction.MasterData.Alpha` | ABS-026 の α（DB の行・設定・問い合わせ・答え）、出力の核 `answerKer`、`dev_D027`（D-027） |
| `Abstraction.Prim.MapM` | `Option` の `List.mapM`（表の写し）の要素・キー・検索の対応 |
| `Abstraction.MasterData.Pre` | ABS-026 の前提の取り出し（α の分解、空白、値とコードの対応） |
| `Abstraction.MasterData.Lookup` | Provider のキャッシュの参照と、DB の行での検索の対応 |
| `Abstraction.MasterData.Query` | ABS-026 の問い合わせごとの一致（参照・ピーク時期・積算比率・コードリスト） |
| `Abstraction.MasterData.Refines` | R 課題 ABS-026 `queryRefines`、`InitSurj`、W 課題 ABS-127 `need_D027` |
| `Abstraction.MasterData.CodeList` | 空港コードリストと `insertNop` の一致、`JdbcCodeList` の値 |
| `Abstraction.Fare.Double` | `(int)(X * F)` の閉じた形 `rneTrunc` と `⌊X·c/100⌋` の比較（因子の近さ `Close`・安全 `Safe`） |
| `Abstraction.Fare.Factors` | 運賃計算の因子の表、基本運賃（D-001）・運賃（D-002）の差異の条件と証拠、安全でない因子の一覧 |
| `Abstraction.Fare.Alpha` | 運賃計算の α（`aiBF`・`aiF`）と差異の述語 `dev_D001`・`dev_D002`・`dev_D027BF`・`dev_D027F` |
| `Abstraction.Fare.FareRefines` | R 課題 ABS-002 `fareRefines`、C 課題 ABS-003 `fare_diff`、W 課題 ABS-102 `need_D002` |
| `Abstraction.Fare.BasicFareRefines` | R 課題 ABS-001 `basicFareRefines`、L 課題 ABS-007 `runBasicFare_spec`、W 課題 ABS-101 `need_D001` |
-/

namespace Abstraction
end Abstraction
