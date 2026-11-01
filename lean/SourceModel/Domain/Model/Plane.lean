import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.Plane

原典の `jp.co.ntt.atrs.domain.model.Plane`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Plane.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Plane`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Plane#getCraftType()@01576ceec214b3c8",
  "java:jp.co.ntt.atrs.domain.model.Plane#getNSeatNum()@f5d712d167c0596e",
  "java:jp.co.ntt.atrs.domain.model.Plane#getSSeatNum()@99c381dae97878b5",
  "java:jp.co.ntt.atrs.domain.model.Plane#setCraftType(String)@91f4b11b9bd54c75",
  "java:jp.co.ntt.atrs.domain.model.Plane#setNSeatNum(Integer)@6e34b482ab4e2e96",
  "java:jp.co.ntt.atrs.domain.model.Plane#setSSeatNum(Integer)@a1d12f387b95199b",
  "java:jp.co.ntt.atrs.domain.model.Plane#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Plane.serialVersionUID@ee869d61bf2fce1b"]
structure Plane where
  craftType : JRef String := none
  nSeatNum : JRef J32 := none
  sSeatNum : JRef J32 := none
  deriving Repr, DecidableEq

namespace Plane

end Plane

end SourceModel.Domain.Model
