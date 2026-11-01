import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Common.Util.FareTypeUtil

原典の `jp.co.ntt.atrs.domain.common.util.FareTypeUtil`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/util/FareTypeUtil.java`）の写し。
-/

namespace SourceModel.Domain.Common.Util
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java
open SourceModel.Domain.Common.Util

namespace FareTypeUtil

/-- `ONE_WAY_FARETYPES`（`LinkedHashSet`。この順序）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ONE_WAY_FARETYPES@13a685de676dd6d0"]
def ONE_WAY_FARETYPES : List Spec.Model.FareTypeCd := [.OW, .RD1, .RD7, .ED, .LD, .GD, .SOW, .SRD]

/-- `ROUND_TRIP_FARETYPES`（`LinkedHashSet`。この順序）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ROUND_TRIP_FARETYPES@93a93cb033a0d234"]
def ROUND_TRIP_FARETYPES : List Spec.Model.FareTypeCd := [.RT, .SRT]

/-- `getFareTypeCdList(flightType)`: `FlightType.OW.equals(flightType)` なら片道の列、それ以外（`null` を含む）は往復の列。 -/
@[source "java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil#getFareTypeCdList(FlightType)@23c5f6e900fea030",
  "java:jp.co.ntt.atrs.domain.model.FlightType#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.FlightType.OW@7e4b60f4d2ee743b",
  "java:jp.co.ntt.atrs.domain.model.FlightType.RT@3165be96f5833ae0"]
def getFareTypeCdList (flightType : JRef Spec.Model.FlightType) : List Spec.Model.FareTypeCd :=
  if flightType = some .OW then ONE_WAY_FARETYPES else ROUND_TRIP_FARETYPES

end FareTypeUtil

end SourceModel.Domain.Common.Util
