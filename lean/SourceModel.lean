import LangSemantics.Java
import LangSemantics.Sql
import Spec
import Trace

/-!
# SourceModel

移植元モデル。移植元ソース（Java/SQL）の振る舞いを、意味論ごと写す。
依存してよいもの: `LangSemantics.Java`, `LangSemantics.Sql`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）に依存してはならない。
-/

namespace SourceModel
end SourceModel
