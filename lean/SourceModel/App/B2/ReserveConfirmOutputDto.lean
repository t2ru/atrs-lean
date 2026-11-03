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
@[source "java:jp.co.ntt.atrs.app.b2.ReserveConfirmOutputDto#getTotalFare()@337b91f1b4b57ed5",
  "java:jp.co.ntt.atrs.app.b2.ReserveConfirmOutputDto#setTotalFare(Integer)@7f3959b617cdbb6d",
  "java:jp.co.ntt.atrs.app.b2.ReserveConfirmOutputDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.app.b2.ReserveConfirmOutputDto.serialVersionUID@a5320337ac4d508c"]
structure ReserveConfirmOutputDto where
  totalFare : J32
  deriving DecidableEq, Repr

end SourceModel.App.B2
