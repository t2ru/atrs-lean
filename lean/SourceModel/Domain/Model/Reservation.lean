import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Member
import SourceModel.Domain.Model.ReserveFlight
import Spec.Model

/-!
# SourceModel.Domain.Model.Reservation

原典の `jp.co.ntt.atrs.domain.model.Reservation`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Reservation.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Reservation`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Reservation#getRepAge()@846ec8352e5658be",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepFamilyName()@66abb894190a0227",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepGender()@015d7284f4686835",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepGivenName()@416cfd32c3fd3e09",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepMail()@1f11cdab9d1723af",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepMember()@a6545c8a50e40110",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getRepTel()@32a86102cf08218b",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getReserveDate()@2c8ef6f8d1698155",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getReserveFlightList()@f425d6344b4a2403",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getReserveNo()@627ab75e41f993e2",
  "java:jp.co.ntt.atrs.domain.model.Reservation#getTotalFare()@337b91f1b4b57ed5",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepAge(Integer)@6a4c35f99292ef27",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepFamilyName(String)@bcf989d8201a63e6",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepGender(Gender)@d6a97d15e5c042cf",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepGivenName(String)@51d9e064217ea526",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepMail(String)@2a33f1fef3a3ef8f",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepMember(Member)@3a750ea4386f8f84",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setRepTel(String)@c2e8b2936c18f73b",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setReserveDate(LocalDate)@0a1d34981e900f2e",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setReserveFlightList(List)@6b9a3b4787149f5d",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setReserveNo(String)@2edb9dab1a771a71",
  "java:jp.co.ntt.atrs.domain.model.Reservation#setTotalFare(Integer)@7f3959b617cdbb6d",
  "java:jp.co.ntt.atrs.domain.model.Reservation#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Reservation.serialVersionUID@fadf05834e294c32"]
structure Reservation where
  reserveNo : JRef String := none
  reserveDate : JRef JLocalDate := none
  totalFare : JRef J32 := none
  repFamilyName : JRef String := none
  repGivenName : JRef String := none
  repAge : JRef J32 := none
  repGender : JRef Spec.Model.Gender := none
  repTel : JRef String := none
  repMail : JRef String := none
  repMember : JRef Member := none
  reserveFlightList : JRef (List (JRef ReserveFlight)) := none
  deriving Repr, DecidableEq

namespace Reservation

end Reservation

end SourceModel.Domain.Model
