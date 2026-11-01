import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Gfw.CodeList

TERASOLUNA Server Framework の `org.terasoluna.gfw.common.codelist` のコードリスト（`CodeList.asMap()` の値と `NumberRangeCodeList`）。原典のクラスではないので、原典のソースツリーの外に置く。
-/

namespace SourceModel.Gfw
open LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java

namespace CodeList

/-- コードリストの値（`asMap()` の反復の順）。 -/
abbrev Entries := List (String × String)

/-- `NumberRangeCodeList`（`from ≤ to`、間隔 1）: 各値を `String.format("%02d", i)` で書く。 -/
@[source "dep:org.terasoluna.gfw:terasoluna-gfw-common#NumberRangeCodeList.afterPropertiesSet@terasoluna-gfw-common-5.11.0.RELEASE"]
def numberRange (lo hi : Nat) : Entries :=
  (List.range (hi + 1 - lo)).map fun i =>
    let n := lo + i
    let s := if n < 10 then "0" ++ toString n else toString n
    (s, s)

end CodeList

end SourceModel.Gfw
