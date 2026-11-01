import Trace
import LangSemantics.Java
import SourceModel.Db.Tx
import SourceModel.App.B2.B2Mapper
import SourceModel.App.B2.PassengerForm
import SourceModel.App.B2.ReserveCompleteOutputDto
import SourceModel.App.B2.ReserveConfirmOutputDto
import SourceModel.App.B2.TicketReserveForm
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Model.Reservation
import SourceModel.Domain.Model.ReserveFlight
import SourceModel.Domain.Service.B0.InvalidFlightException
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Domain.Service.B2.TicketReserveServiceImpl
import Spec.Model

/-!
# SourceModel.App.B2.TicketReserveHelper

原典の `jp.co.ntt.atrs.app.b2.TicketReserveHelper`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/TicketReserveHelper.java`）の写し。

予約確認（`reserveConfirm`）・予約確定（`reserve`）・選択フライトの検証（`validateFlightList`）と、それらが呼ぶ private の
`createReservation`・`calculateTotalFare` を写す（backlog aedf）。画面の表示用の `createSelectFlightDtoList`・
`createTicketReserveForm`・`createParameterMapForFlightSearch` は HTTP の backlog（a89e）で写す。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.Spring
open SourceModel.Db.Tx SourceModel.Domain.Model SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B2

/-- `TicketReserveHelper` が使うサービス（`@Inject`）。`reserveIntervalTime` は、共有サービス（`TicketSharedServiceImpl`）が
受ける設定 `atrs.reserveIntervalTime`。 -/
structure TicketReserveHelper where
  ticketReserveService : TicketReserveServiceImpl
  reserveIntervalTime : J32

namespace TicketReserveHelper

/-- `BadRequestException` のクラス名。 -/
def badRequestClass : String := "jp.co.ntt.atrs.app.common.exception.BadRequestException"

/-- 予約情報を組み立てる（private `createReservation`）。空でない搭乗者情報フォームを搭乗者にし、すべての予約フライトに
同じ搭乗者の列を持たせる。代表者の電話番号は `String.format("%s-%s-%s", repTel1, repTel2, repTel3)`（`null` は
`"null"`）。 -/
@[source "lang:java#java.lang.String.format@java-17"]
def createReservation (ticketReserveForm : TicketReserveForm) (flightList : List (JRef Flight)) : Reservation :=
  let passengerList : List (JRef Passenger) :=
    (ticketReserveForm.passengerFormList.filter (!·.isEmpty)).map fun p => some (B2Mapper.mapPassenger p)
  let reserveFlightList : List (JRef ReserveFlight) :=
    flightList.map fun flight => some { flight, passengerList := some passengerList }
  let reservation := B2Mapper.mapReservation ticketReserveForm {}
  let fmt (s : JRef String) : String := s.getD "null"
  let repTel := fmt ticketReserveForm.repTel1 ++ "-" ++ fmt ticketReserveForm.repTel2 ++ "-" ++ fmt ticketReserveForm.repTel3
  { reservation with repTel := some repTel, reserveFlightList := some reserveFlightList }

/-- 合計金額（private `calculateTotalFare`）: 最初の予約フライトの搭乗者で `calculateTotalFare` を呼ぶ。 -/
def calculateTotalFare (h : TicketReserveHelper) (flightList : List (JRef Flight)) (reservation : Reservation) :
    JResult J32 := do
  let reserveFlightList ← reservation.reserveFlightList.deref "reserveFlightList"
  let first ← JList.get reserveFlightList 0
  let reserveFlight ← first.deref "reserveFlight"
  TicketReserveServiceImpl.calculateTotalFare h.ticketReserveService (some flightList) reserveFlight.passengerList

/-- `reserveConfirm(ticketReserveForm, flightList)`: 搭乗者情報フォームを詰め、予約情報を組み立てて検証し、合計金額を返す。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserveConfirm(TicketReserveForm,List)@7b28499828937c4a"]
def reserveConfirm (h : TicketReserveHelper) (ticketReserveForm : TicketReserveForm) (flightList : List (JRef Flight)) :
    DbM (TicketReserveForm × ReserveConfirmOutputDto) := do
  let ticketReserveForm := ticketReserveForm.resetPassengersIndex
  let reservation := createReservation ticketReserveForm flightList
  TicketReserveServiceImpl.validateReservation h.ticketReserveService (some reservation)
  let totalFare ← lift (calculateTotalFare h flightList reservation)
  pure (ticketReserveForm, { totalFare })

/-- `reserve(ticketReserveForm, flightList)`: 予約情報を組み立てて検証し、予約日（Clock を読む。既知差異 D-014）と合計金額を
設定して登録する。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserve(TicketReserveForm,List)@adcae9fef7b9df35", gap "D-014"]
def reserve (h : TicketReserveHelper) (ticketReserveForm : TicketReserveForm) (flightList : List (JRef Flight)) :
    DbM ReserveCompleteOutputDto := do
  let reservation := createReservation ticketReserveForm flightList
  TicketReserveServiceImpl.validateReservation h.ticketReserveService (some reservation)
  let reserveDate ← now
  let reservation := { reservation with reserveDate := some reserveDate }
  let totalFare ← lift (calculateTotalFare h flightList reservation)
  let reservation := { reservation with totalFare := some totalFare }
  let ticketReserveDto ← TicketReserveServiceImpl.registerReservation h.ticketReserveService (some reservation)
  pure { reserveNo := ticketReserveDto.reserveNo, paymentDate := ticketReserveDto.paymentDate,
         totalFare := reservation.totalFare }

/-- `validateFlightList(flightList)`: 共有サービスの `validateFlightList` を呼び、`InvalidFlightException` と業務例外
（`e.ar.b2.2001` を含む）を `BadRequestException` に包む。 -/
@[source "java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#validateFlightList(List)@d6700fbbefbc4997",
  "java:jp.co.ntt.atrs.app.common.exception.BadRequestException#<init>(Exception)@e6ed9d4d70fd7b28"]
def validateFlightList (h : TicketReserveHelper) (flightList : List (JRef Flight)) : DbM Unit :=
  tryCatch (TicketSharedServiceImpl.validateFlightList h.reserveIntervalTime (some flightList)) fun e =>
    match e with
    | .other cls msg =>
      if cls = InvalidFlightException.className ∨ cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className then
        throw (.other badRequestClass msg)
      else throw e
    | _ => throw e

end TicketReserveHelper

end SourceModel.App.B2
