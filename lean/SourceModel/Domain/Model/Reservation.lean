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
