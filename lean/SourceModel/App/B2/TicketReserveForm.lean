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
