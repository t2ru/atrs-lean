import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.App.B0.SelectFlightForm
import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.FareTypeProvider
import SourceModel.Domain.Common.Masterdata.FlightMasterProvider
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.FlightMaster
import Spec.Model

/-!
# SourceModel.App.B0.TicketHelper

原典の `jp.co.ntt.atrs.app.b0.TicketHelper`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b0/TicketHelper.java`）の写し。

画面の選択フライト情報から、フライト情報を組み立てる部分（`TicketHelper.toFlightList`）。予約・合計金額の具体機械が使う。
-/

namespace SourceModel.App.B0
open LangSemantics.Java.Exception
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata
open SourceModel.App.B0

/-- `TicketHelper` が受ける Provider（`@Inject`）。 -/
structure TicketHelper where
  flightMasterProvider : FlightMasterProvider := {}
  fareTypeProvider : FareTypeProvider := {}
  boardingClassProvider : BoardingClassProvider := {}

namespace TicketHelper

/-- `toFlightList` の 1 件分: 出発日を写し、便マスタ・運賃種別・搭乗クラスを Provider から引いてフライト情報を作る。
便名が `null` なら `FlightMasterProvider.getFlightMaster` の `Assert.hasText` で `IllegalArgumentException`。 -/
def toFlight (h : TicketHelper) (form : SelectFlightForm) : JResult (JRef Flight) := do
  let name ← match form.flightName with
    | some n => pure n
    | none => throw (.illegalArgument "flightName must have some text.")
  let fm ← FlightMasterProvider.getFlightMaster h.flightMasterProvider name
  let ft ← FareTypeProvider.getFareType h.fareTypeProvider form.fareTypeCd
  let bc ← BoardingClassProvider.getBoardingClass h.boardingClassProvider form.boardingClassCd
  return some { departureDate := form.depDate, flightMaster := fm, fareType := ft, boardingClass := bc }

/-- `toFlightList`: 選択フライト情報ごとにフライト情報を作る（`toFlight`）。 -/
@[source "java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)@3fef600108b03c6e"]
def toFlightList (h : TicketHelper) (forms : List SelectFlightForm) : JResult (List (JRef Flight)) :=
  forms.mapM (toFlight h)

end TicketHelper

end SourceModel.App.B0
