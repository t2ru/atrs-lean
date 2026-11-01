import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.MemberLogin

原典の `jp.co.ntt.atrs.domain.model.MemberLogin`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/MemberLogin.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `MemberLogin`。 -/
structure MemberLogin where
  password : JRef String := none
  lastPassword : JRef String := none
  loginDateTime : JRef JLocalDate := none
  loginFlg : JRef Bool := none
  deriving Repr, DecidableEq

namespace MemberLogin

end MemberLogin

end SourceModel.Domain.Model
