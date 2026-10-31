import Abstraction.MasterData.Pre

/-!
# Abstraction.MasterData.Lookup

Provider のキャッシュ（`JHashMap`）の参照と、[Spec] の検索の対応。Mapper の結果の並び `o` は、
DB の行を写した列の並べ替えである。キーが重複しなければ、`get` はどの並びでも、DB の行での検索の写しになる。
-/

namespace Abstraction.MasterData
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String

open LangSemantics.Java LangSemantics.Core


end Abstraction.MasterData
