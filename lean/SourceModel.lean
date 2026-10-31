import LangSemantics.Java
import LangSemantics.Sql
import Spec
import Trace
import SourceModel.Model
import SourceModel.MasterData
import SourceModel.Fare

/-!
# SourceModel

移植元モデル。移植元ソース（Java/SQL）の振る舞いを、意味論ごと写す。
依存してよいもの: `LangSemantics.Java`, `LangSemantics.Sql`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）に依存してはならない。

| モジュール | 内容 |
| --- | --- |
| `SourceModel.Model` | 原典の domain model |
| `SourceModel.MasterData` | マスタの Provider のキャッシュと参照 |
| `SourceModel.Fare` | 運賃計算 |
-/

namespace SourceModel
end SourceModel
