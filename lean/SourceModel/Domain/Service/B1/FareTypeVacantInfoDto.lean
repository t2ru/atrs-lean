import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.FareTypeVacantInfoDto

原典の `jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/FareTypeVacantInfoDto.java`）の写し。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Service.B1

/-- `FareTypeVacantInfoDto`（運賃種別ごとの空席情報）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#<init>(String,String,Integer)@b5ab6bf246edfbbf",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFare()@3aecf0e9bebb654a",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFareTypeName()@fe0943673fcac4f0",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getVacantNum()@1727d00958d6c3a3",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto.serialVersionUID@dd46f950a2716a7f"]
structure FareTypeVacantInfoDto where
  fareTypeName : JRef String
  fare : JRef String
  vacantNum : JRef J32
  deriving DecidableEq, Repr

namespace FareTypeVacantInfoDto

end FareTypeVacantInfoDto

end SourceModel.Domain.Service.B1
