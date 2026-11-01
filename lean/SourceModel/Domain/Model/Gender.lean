import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.Gender

原典の `jp.co.ntt.atrs.domain.model.Gender`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Gender.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception
open LangSemantics.Java
open SourceModel.Domain.Model

namespace Gender

/-- `Gender.getCode()`（原典では `this.name()` を返す。`#{repGender.code}`・`#{gender.code}` が束縛する値）。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Gender#getCode()@a9f1cc11acd733ab", "java:jp.co.ntt.atrs.domain.model.Gender.F@f67ab10ad4e4c531",
  "java:jp.co.ntt.atrs.domain.model.Gender.M@08f271887ce94707"]
def getCode : Spec.Model.Gender → String
  | .F => "F" | .M => "M"

/-- `Enum.valueOf(Gender.class, s)`（MyBatis の `EnumTypeHandler` が列の値を読む）。 -/
@[source "dep:org.mybatis:mybatis#EnumTypeHandler@mybatis-3.5.19"]
def valueOf (s : String) : JResult Spec.Model.Gender :=
  match s with
  | "F" => pure .F
  | "M" => pure .M
  | _ => throw (.illegalArgument s!"No enum constant Gender.{s}")

end Gender

end SourceModel.Domain.Model
