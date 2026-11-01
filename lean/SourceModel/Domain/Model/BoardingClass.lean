import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.BoardingClass

原典の `jp.co.ntt.atrs.domain.model.BoardingClass`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/BoardingClass.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `BoardingClass`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassName()@a4962e4cdd7f7b0b",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#getExtraCharge()@c2ed357f647cbb3f",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassName(String)@11476b38898738b2",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#setExtraCharge(Integer)@a9a095c60eef4b98",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.BoardingClass.serialVersionUID@7a425c3cfaa07f43"]
structure BoardingClass where
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  boardingClassName : JRef String := none
  extraCharge : JRef J32 := none
  deriving Repr, DecidableEq

namespace BoardingClass

end BoardingClass

end SourceModel.Domain.Model
