import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Db.MyBatis

MyBatis の型の対応（`INT`・`DATE`・`VARCHAR` の値を Java の値にする `TypeHandler`）。原典のクラスではないので、原典のソースツリーの外に置く。

MyBatis の結果の対応（`resultMap`）。列の値を Java の型へ写す。

- `INT` → `Integer`（`JRef J32`。`Int4` の範囲は int に収まる）
- `DATE` → `LocalDate`（`JLocalDate`）
- `VARCHAR` → `String`
- enum の列 → `Enum.valueOf`（MyBatis の `EnumTypeHandler`）。未知のコードは `IllegalArgumentException`
- 入れ子の `resultMap`（`flightMaster-map` の `association`）は、`<id>` の列が同じ行を 1 つにまとめ、最初の行を残す。

lang/dep: `dep:org.mybatis:mybatis#EnumTypeHandler`、`dep:org.mybatis:mybatis#DefaultResultSetHandler`
-/

namespace SourceModel.Db
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java LangSemantics.Sql.Postgresql

namespace MyBatis

/-- `INT` の値を `Integer` に。 -/
def int (v : Int4) : JRef J32 := some (J32.ofInt v.val)

/-- `DATE` の値を `LocalDate` に。 -/
def date (d : PgDate) : JRef JLocalDate := some (JLocalDate.ofEpochDay d.val)

/-- `VARCHAR` の値を `String` に。 -/
def str {n : Nat} (s : Varchar n) : JRef String := some s.val

end MyBatis

end SourceModel.Db
