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
structure SelectFlightForm where
  depDate : JRef JLocalDate := none
  flightName : JRef String := none
  fareTypeCd : JRef Spec.Model.FareTypeCd := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  deriving DecidableEq, Repr

namespace SelectFlightForm

end SelectFlightForm

end SourceModel.App.B0
