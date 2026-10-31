import SourceModel
import Spec
import Trace
import Abstraction.Prim.Date
import Abstraction.Prim.List
import Abstraction.Prim.Order
import Abstraction.MasterData.Join
import Abstraction.MasterData.Key
import Abstraction.MasterData.Load
import Abstraction.MasterData.CodeList

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
| `Abstraction.MasterData.CodeList` | 空港コードリストと `insertNop` の一致、`JdbcCodeList` の値 |
-/

namespace Abstraction
end Abstraction
