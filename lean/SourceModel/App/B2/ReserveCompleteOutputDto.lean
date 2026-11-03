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
@[source "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#getPaymentDate()@305a3cd2edbb1ef0",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#getReserveNo()@627ab75e41f993e2",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#getTotalFare()@337b91f1b4b57ed5",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#setPaymentDate(LocalDate)@28072d31fdd042a0",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#setReserveNo(String)@2edb9dab1a771a71",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#setTotalFare(Integer)@7f3959b617cdbb6d",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto.serialVersionUID@b254b2b7e2ccf898"]
structure ReserveCompleteOutputDto where
  reserveNo : JRef String
  paymentDate : JRef JLocalDate
  totalFare : JRef J32
  deriving DecidableEq, Repr

end SourceModel.App.B2
