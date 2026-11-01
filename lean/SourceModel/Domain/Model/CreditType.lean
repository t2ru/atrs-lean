import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.CreditType

原典の `jp.co.ntt.atrs.domain.model.CreditType`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/CreditType.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `CreditType`。 -/
structure CreditType where
  creditTypeCd : JRef String := none
  creditFirm : JRef String := none
  deriving Repr, DecidableEq

namespace CreditType

end CreditType

end SourceModel.Domain.Model
