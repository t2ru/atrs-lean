import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Member
import Spec.Model

/-!
# SourceModel.Domain.Model.Passenger

原典の `jp.co.ntt.atrs.domain.model.Passenger`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Passenger.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Passenger`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Passenger#getAge()@a104b8de82dcc9aa",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getFamilyName()@42b1265bbc5dfce0",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getGender()@40162857f388bc4a",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getGivenName()@d2416f58f72730cb",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getMember()@1e62d600fca019f6",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getPassengerNo()@dd1555b61a86c0fa",
  "java:jp.co.ntt.atrs.domain.model.Passenger#getReserveFlightNo()@2769dce77ca87a1a",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setAge(Integer)@0f30aa30583622a4",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setFamilyName(String)@f5e85e96b8121f23",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setGender(Gender)@4a852d53b0d2198a",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setGivenName(String)@b701004f7a9287e1",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setMember(Member)@e55af386080fd1eb",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setPassengerNo(Integer)@55aa102035d21774",
  "java:jp.co.ntt.atrs.domain.model.Passenger#setReserveFlightNo(Integer)@0970fb4639317f1c",
  "java:jp.co.ntt.atrs.domain.model.Passenger#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Passenger.serialVersionUID@a4400e5f56da5cba"]
structure Passenger where
  passengerNo : JRef J32 := none
  reserveFlightNo : JRef J32 := none
  familyName : JRef String := none
  givenName : JRef String := none
  age : JRef J32 := none
  gender : JRef Spec.Model.Gender := none
  member : JRef Member := none
  deriving Repr, DecidableEq

namespace Passenger

end Passenger

end SourceModel.Domain.Model
