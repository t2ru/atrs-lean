import Trace
import LangSemantics.Java
import SourceModel.App.B0.SelectFlightForm
import SourceModel.App.B2.PassengerForm
import Spec.Model

/-!
# SourceModel.App.B2.TicketReserveForm

原典の `jp.co.ntt.atrs.app.b2.TicketReserveForm`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/TicketReserveForm.java`）の写し。
入力の前処理（`StringTrimmerEditor`）と単項目検証の後の値を持つ（検証は backlog 4e0e）。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.App.B0

/-- `TicketReserveForm`（予約フォーム）。搭乗者情報フォームの列は、生成時に 6 欄を持つ。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getFlightType()@9b6142b3fa1d0242",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getPassengerFormList()@6f58be9f86183e69",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepAge()@846ec8352e5658be",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepFamilyName()@66abb894190a0227",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepGender()@015d7284f4686835",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepGivenName()@416cfd32c3fd3e09",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepMail()@1f11cdab9d1723af",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepMembershipNumber()@0a19ce49bcf3b2f0",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepTel1()@f63099e3bf370f7d",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepTel2()@76a960a8570763d7",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getRepTel3()@f3aa4bc2e10c0517",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#getSelectFlightFormList()@88b7fb3a97cf3933",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setFlightType(FlightType)@7f178ac43c6090bd",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setPassenger(int,PassengerForm)@6be9b84152dfe022",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setPassengerFormList(List)@ea101707e186ad95",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepAge(Integer)@6a4c35f99292ef27",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepFamilyName(String)@bcf989d8201a63e6",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepGender(Gender)@d6a97d15e5c042cf",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepGivenName(String)@51d9e064217ea526",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepMail(String)@2a33f1fef3a3ef8f",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepMembershipNumber(String)@a17d24ad21760b13",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepTel1(String)@8c65985fbae35f9c",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepTel2(String)@b9219bb92a129742",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setRepTel3(String)@5b2191984494152c",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#setSelectFlightFormList(List)@4043576d5d6872c9",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm.serialVersionUID@5a3bc741ecae5432"]
structure TicketReserveForm where
  repFamilyName : JRef String := none
  repGivenName : JRef String := none
  repAge : JRef J32 := none
  repGender : JRef Spec.Model.Gender := none
  repMembershipNumber : JRef String := none
  repTel1 : JRef String := none
  repTel2 : JRef String := none
  repTel3 : JRef String := none
  repMail : JRef String := none
  passengerFormList : List PassengerForm := List.replicate 6 {}
  flightType : JRef Spec.Model.FlightType := none
  selectFlightFormList : List SelectFlightForm := []
  deriving DecidableEq, Repr

namespace TicketReserveForm

/-- `MAX_PASSENGERS_NUMBER`。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveForm.MAX_PASSENGERS_NUMBER@ce743698ff3529b4",
  "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#<init>()@e8da8828068e2108"]
def MAX_PASSENGERS_NUMBER : Nat := 6

/-- `resetPassengersIndex()`: 空の搭乗者情報フォームを除き、6 欄に満たない分を末尾に空の欄で補う。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveForm#resetPassengersIndex()@402fa38c7797fc36"]
def resetPassengersIndex (f : TicketReserveForm) : TicketReserveForm :=
  let kept := f.passengerFormList.filter (!·.isEmpty)
  { f with passengerFormList := kept ++ List.replicate (MAX_PASSENGERS_NUMBER - kept.length) {} }

end TicketReserveForm

end SourceModel.App.B2
