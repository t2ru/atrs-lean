import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.CreditType
import SourceModel.Domain.Model.MemberLogin
import Spec.Model

/-!
# SourceModel.Domain.Model.Member

原典の `jp.co.ntt.atrs.domain.model.Member`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Member.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Member`。 -/
structure Member where
  membershipNumber : JRef String := none
  kanjiFamilyName : JRef String := none
  kanjiGivenName : JRef String := none
  kanaFamilyName : JRef String := none
  kanaGivenName : JRef String := none
  birthday : JRef JLocalDate := none
  gender : JRef Spec.Model.Gender := none
  tel : JRef String := none
  zipCode : JRef String := none
  address : JRef String := none
  mail : JRef String := none
  creditNo : JRef String := none
  creditTerm : JRef String := none
  creditType : JRef CreditType := none
  memberLogin : JRef MemberLogin := none
  deriving Repr, DecidableEq

namespace Member

end Member

end SourceModel.Domain.Model
