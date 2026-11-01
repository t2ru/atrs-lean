import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.Airport

原典の `jp.co.ntt.atrs.domain.model.Airport`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Airport.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Airport`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Airport#getCode()@da85740cb21790bb",
  "java:jp.co.ntt.atrs.domain.model.Airport#getDisplayOrder()@15b3aeb33df2350d",
  "java:jp.co.ntt.atrs.domain.model.Airport#getName()@36c200189d0d5290",
  "java:jp.co.ntt.atrs.domain.model.Airport#setCode(String)@fe06ceaece4b0839",
  "java:jp.co.ntt.atrs.domain.model.Airport#setDisplayOrder(Integer)@811041ac15b071c0",
  "java:jp.co.ntt.atrs.domain.model.Airport#setName(String)@d75eb48ec8bce02e",
  "java:jp.co.ntt.atrs.domain.model.Airport#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Airport.serialVersionUID@8bae105bbb3f3f93"]
structure Airport where
  code : JRef String := none
  name : JRef String := none
  displayOrder : JRef J32 := none
  deriving Repr, DecidableEq

namespace Airport

end Airport

end SourceModel.Domain.Model
