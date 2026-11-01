import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.App.B2.ReserveConfirmOutputDto

原典の `jp.co.ntt.atrs.app.b2.ReserveConfirmOutputDto`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/ReserveConfirmOutputDto.java`）の写し。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int

/-- `ReserveConfirmOutputDto`（合計金額）。 -/
structure ReserveConfirmOutputDto where
  totalFare : J32
  deriving DecidableEq, Repr

end SourceModel.App.B2
