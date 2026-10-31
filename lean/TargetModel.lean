import LangSemantics.Rust
import Spec
import Trace

/-!
# TargetModel

移植先モデル。移植先ソース（Rust）の振る舞いを `LangSemantics.Rust` で写す。
Verus の写しの生成器が扱える部分集合で書く（port-lang の `lang/lean/rules.md`）。
依存してよいもの: `LangSemantics.Rust`, `Spec`（型の再利用）, `Machine`, `Trace`。
移植元側（`SourceModel`, `Abstraction`, `LangSemantics.Java`, `LangSemantics.Sql`）に依存してはならない。
-/

namespace TargetModel
end TargetModel
