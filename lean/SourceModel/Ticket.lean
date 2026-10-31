import SourceModel.MasterData

/-!
# SourceModel.Ticket

画面の選択フライト情報から、フライト情報を組み立てる部分（`TicketHelper.toFlightList`）。予約・合計金額の具体機械が使う。
-/

namespace SourceModel.Ticket
open LangSemantics.Java.Exception

open LangSemantics.Java SourceModel.Model SourceModel.MasterData

/-- `SelectFlightForm`（選択フライト情報フォーム）。 -/
structure SelectFlightForm where
  depDate : JRef JLocalDate := none
  flightName : JRef String := none
  fareTypeCd : JRef Spec.Model.FareTypeCd := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  deriving DecidableEq, Repr

/-- `TicketHelper` が受ける Provider（`@Inject`）。 -/
structure TicketHelper where
  flightMasterProvider : FlightMasterProvider := {}
  fareTypeProvider : FareTypeProvider := {}
  boardingClassProvider : BoardingClassProvider := {}

/-- `toFlightList` の 1 件分: 出発日を写し、便マスタ・運賃種別・搭乗クラスを Provider から引いてフライト情報を作る。
便名が `null` なら `getFlightMaster` の `Assert.hasText` で `IllegalArgumentException`。 -/
def toFlight (h : TicketHelper) (form : SelectFlightForm) : JResult (JRef Flight) := do
  let name ← match form.flightName with
    | some n => pure n
    | none => throw (.illegalArgument "flightName must have some text.")
  let fm ← getFlightMaster h.flightMasterProvider name
  let ft ← getFareType h.fareTypeProvider form.fareTypeCd
  let bc ← getBoardingClass h.boardingClassProvider form.boardingClassCd
  return some { departureDate := form.depDate, flightMaster := fm, fareType := ft, boardingClass := bc }

/-- `toFlightList`: 選択フライト情報ごとにフライト情報を作る（`toFlight`）。 -/
@[source "java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)@3fef600108b03c6e"]
def toFlightList (h : TicketHelper) (forms : List SelectFlightForm) : JResult (List (JRef Flight)) :=
  forms.mapM (toFlight h)

end SourceModel.Ticket
