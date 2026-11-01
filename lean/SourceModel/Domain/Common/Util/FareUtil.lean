import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Common.Util.FareUtil

原典の `jp.co.ntt.atrs.domain.common.util.FareUtil`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/util/FareUtil.java`）の写し。
-/

namespace SourceModel.Domain.Common.Util
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.Spring LangSemantics.Java.Int
  LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Common.Util

namespace FareUtil

/-- `FareUtil.ceilFare`: `new BigDecimal(fare).setScale(-2, RoundingMode.UP).intValue()`（0 から遠ざかる向きの切上げ）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareUtil.CEIL_FARE_SCALE@cd0475f0dda7e5e1",
  "java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)@345c1d9656b3930c"]
def ceilFare (fare : J32) : J32 := bdCeilHundredUp fare

end FareUtil

end SourceModel.Domain.Common.Util
