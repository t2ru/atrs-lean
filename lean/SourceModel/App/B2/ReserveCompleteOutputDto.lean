import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.App.B2.ReserveCompleteOutputDto

原典の `jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/ReserveCompleteOutputDto.java`）の写し。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int

/-- `ReserveCompleteOutputDto`（予約番号・支払期限・合計金額）。 -/
structure ReserveCompleteOutputDto where
  reserveNo : JRef String
  paymentDate : JRef JLocalDate
  totalFare : JRef J32
  deriving DecidableEq, Repr

end SourceModel.App.B2
