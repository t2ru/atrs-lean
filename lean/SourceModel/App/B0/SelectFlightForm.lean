import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.App.B0.SelectFlightForm

原典の `jp.co.ntt.atrs.app.b0.SelectFlightForm`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b0/SelectFlightForm.java`）の写し。
-/

namespace SourceModel.App.B0
open LangSemantics.Java.Exception
open LangSemantics.Java
open SourceModel.App.B0

/-- `SelectFlightForm`（選択フライト情報フォーム）。 -/
@[source "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#getDepDate()@9e5ad0157d1bece7",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#getFareTypeCd()@0ad0a31bd0da4f1d",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#getFlightName()@56b669a044a195ca",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#setDepDate(LocalDate)@e4d262f79ebcb7ac",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#setFareTypeCd(FareTypeCd)@028d6508ed1eadd9",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#setFlightName(String)@c8ed541ae69f3cad",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.app.b0.SelectFlightForm.serialVersionUID@7be1d1be2d9c3506"]
structure SelectFlightForm where
  depDate : JRef JLocalDate := none
  flightName : JRef String := none
  fareTypeCd : JRef Spec.Model.FareTypeCd := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  deriving DecidableEq, Repr

namespace SelectFlightForm

end SelectFlightForm

end SourceModel.App.B0
