import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.BoardingClassCd

原典の `jp.co.ntt.atrs.domain.model.BoardingClassCd`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/BoardingClassCd.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model
open LangSemantics.Sql.Postgresql

namespace BoardingClassCd

/-- enum の定数名（`Enum.name()`。MyBatis の `EnumTypeHandler` が束縛する値。出典は `bind` の `EnumTypeHandler`）。 -/
def name : Spec.Model.BoardingClassCd → String
  | .N => "N" | .S => "S"

/-- `Enum.valueOf(BoardingClassCd.class, s)`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.BoardingClassCd#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.BoardingClassCd.N@8ce86a6ae65d3692",
  "java:jp.co.ntt.atrs.domain.model.BoardingClassCd.S@8de0b3c47f112c59"]
def valueOf (s : String) : JResult Spec.Model.BoardingClassCd :=
  match s with
  | "N" => pure .N
  | "S" => pure .S
  | _ => throw (.illegalArgument s!"No enum constant BoardingClassCd.{s}")

end BoardingClassCd

end SourceModel.Domain.Model
