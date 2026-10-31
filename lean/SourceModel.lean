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

/-!
# SourceModel

移植元モデル。移植元ソース（Java/SQL）の振る舞いを、意味論ごと写す。
依存してよいもの: `LangSemantics.Java`, `LangSemantics.Sql`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）に依存してはならない。

| モジュール | 内容 |
| --- | --- |
| `SourceModel.Model` | 原典の domain model |
| `SourceModel.Repository.*` | マスタの表の行（`Schema`）、Mapper の文（`MasterData`）、MyBatis の対応（`Mapping`） |
| `SourceModel.MasterData` | マスタの Provider（`load()` とキャッシュの参照） |
| `SourceModel.CodeList` | コードリスト |
| `SourceModel.Config` | 注入される設定 |
| `SourceModel.MasterQuery` | マスタ・設定・コードリストの参照の具体機械（ABS-026 の具体側） |
| `SourceModel.Fare` | 運賃計算 |
-/

namespace SourceModel
end SourceModel
