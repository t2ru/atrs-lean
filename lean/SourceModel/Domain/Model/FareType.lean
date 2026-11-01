import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.FareType

原典の `jp.co.ntt.atrs.domain.model.FareType`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/FareType.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `FareType`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareType#getDiscountRate()@ed3dd8409edfd508",
  "java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeCd()@0ad0a31bd0da4f1d",
  "java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeName()@fe0943673fcac4f0",
  "java:jp.co.ntt.atrs.domain.model.FareType#getPassengerMinNum()@a825d94771937aa7",
  "java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableEndDayNum()@c72ad3c4851e2bbf",
  "java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableStartDayNum()@14927cc7d58ca59b",
  "java:jp.co.ntt.atrs.domain.model.FareType#setDiscountRate(Integer)@5d282bd1a68ca907",
  "java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeCd(FareTypeCd)@028d6508ed1eadd9",
  "java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeName(String)@a37098988b7af7bb",
  "java:jp.co.ntt.atrs.domain.model.FareType#setPassengerMinNum(Integer)@2f6371e03bcf7124",
  "java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableEndDayNum(Integer)@96031ccbe007803c",
  "java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableStartDayNum(Integer)@f740fe7fa648536d",
  "java:jp.co.ntt.atrs.domain.model.FareType#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.FareType.serialVersionUID@7ac4c51a2e13b2a2"]
structure FareType where
  fareTypeCd : JRef Spec.Model.FareTypeCd := none
  fareTypeName : JRef String := none
  discountRate : JRef J32 := none
  rsrvAvailableStartDayNum : JRef J32 := none
  rsrvAvailableEndDayNum : JRef J32 := none
  passengerMinNum : JRef J32 := none
  deriving Repr, DecidableEq

namespace FareType

end FareType

end SourceModel.Domain.Model
