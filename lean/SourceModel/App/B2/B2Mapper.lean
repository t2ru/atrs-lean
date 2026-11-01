import Trace
import LangSemantics.Java
import SourceModel.App.B2.PassengerForm
import SourceModel.App.B2.TicketReserveForm
import SourceModel.Domain.Model.Member
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Model.Reservation
import Spec.Model

/-!
# SourceModel.App.B2.B2Mapper

原典の `jp.co.ntt.atrs.app.b2.B2Mapper`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/B2Mapper.java`。MapStruct が実装を生成する）の写し。
予約の組み立てが使う 2 つの対応だけを写す。入れ子の対象（`repMember.membershipNumber`・`member.membershipNumber`）は、
元が `null` でなければ、値が `null` でも入れ子のオブジェクトを作る（MapStruct の生成コード）。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Domain.Model

namespace B2Mapper

/-- `void map(TicketReserveForm ticketReserveForm, @MappingTarget Reservation reservation)`。`reserveNo`・`reserveDate`・
`totalFare`・`repTel`・`reserveFlightList` は写さない（`ignore = true`）。 -/
@[source "java:jp.co.ntt.atrs.app.b2.B2Mapper#map(TicketReserveForm,Reservation)@b1198d19edff71a3", "dep:org.mapstruct:mapstruct#Mapper@mapstruct-1.6.3"]
def mapReservation (f : TicketReserveForm) (r : Reservation) : Reservation :=
  { r with repFamilyName := f.repFamilyName, repGivenName := f.repGivenName, repAge := f.repAge,
           repGender := f.repGender, repMail := f.repMail, repMember := some { membershipNumber := f.repMembershipNumber } }

/-- `Passenger map(PassengerForm passengerForm)`。`passengerNo`・`reserveFlightNo` は写さない。 -/
@[source "java:jp.co.ntt.atrs.app.b2.B2Mapper#map(PassengerForm)@0685ad6f1c953274", "dep:org.mapstruct:mapstruct#Mapper@mapstruct-1.6.3"]
def mapPassenger (p : PassengerForm) : Passenger :=
  { familyName := p.familyName, givenName := p.givenName, age := p.age, gender := p.gender,
    member := some { membershipNumber := p.membershipNumber } }

end B2Mapper

end SourceModel.App.B2
