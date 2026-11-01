import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.Passenger

原典の `jp.co.ntt.atrs.domain.model.Passenger`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Passenger.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Passenger`。会員（`member`）は、予約の backlog で足す。 -/
structure Passenger where
  passengerNo : JRef J32 := none
  reserveFlightNo : JRef J32 := none
  familyName : JRef String := none
  givenName : JRef String := none
  age : JRef J32 := none
  gender : JRef Spec.Model.Gender := none
  deriving Repr, DecidableEq

namespace Passenger

end Passenger

end SourceModel.Domain.Model
