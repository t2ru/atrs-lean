import Trace
import LangSemantics.Java
import SourceModel.AtrsProperties
import SourceModel.Db.Schema
import SourceModel.Db.Tx
import SourceModel.MasterQuery
import SourceModel.FareQuery
import SourceModel.App.B0.TicketHelper
import SourceModel.App.B2.TicketReserveForm
import SourceModel.App.B2.TicketReserveHelper

/-!
# SourceModel.ReserveQuery

予約（B2）の入口の計算（backlog aedf）。Controller（`TicketReserveController`）の `reserveConfirm`・`reserve` の、入力検証の
後の流れを写す。

1. 起動時の読み込み（`SourceModel.MasterQuery.load`。Mapper の文の結果の並び `mo`）
2. `TicketHelper.toFlightList`（選択フライト情報からフライト情報を作る）
3. `TicketReserveHelper.validateFlightList`（失敗は `BadRequestException`）
4. `TicketReserveHelper.reserveConfirm` または `TicketReserveHelper.reserve`

状態は状態の表とシーケンス（`FlightDb`）、実行環境（Clock・障害の位置）は入力の成分である。具体機械は第 2 段で置く。
-/

namespace SourceModel.ReserveQuery
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.AtrsProperties SourceModel.MasterQuery
open SourceModel.App.B0 SourceModel.App.B2

/-- 予約の入力: DB のマスタ・注入された設定・予約フォーム（選択フライト情報を含む）・実行環境。 -/
@[gap "D-027"]
structure ReserveInput where
  db : MasterDb
  config : AtrsConfig
  form : TicketReserveForm
  env : Env

/-- 読み込んだ Provider・設定・マスタの表を注入した `TicketReserveHelper`。 -/
def helperOf (p : Providers) (ic : ReserveInput) : TicketReserveHelper :=
  { ticketReserveService := { SourceModel.FareQuery.ticketReserveService p ic.config with memberRepository := ic.db },
    reserveIntervalTime := ic.config.reserveIntervalTime }

/-- 予約確認の流れ（Provider `p` を読み込んだ後）。 -/
def confirmBody (p : Providers) (ic : ReserveInput) : DbM ReserveConfirmOutputDto := do
  let h := helperOf p ic
  let flightList ← lift (TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p) ic.form.selectFlightFormList)
  TicketReserveHelper.validateFlightList h flightList
  let (_, out) ← TicketReserveHelper.reserveConfirm h ic.form flightList
  pure out

/-- 予約確定の流れ（Provider `p` を読み込んだ後）。 -/
def reserveBody (p : Providers) (ic : ReserveInput) : DbM ReserveCompleteOutputDto := do
  let h := helperOf p ic
  let flightList ← lift (TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p) ic.form.selectFlightFormList)
  TicketReserveHelper.validateFlightList h flightList
  TicketReserveHelper.reserve h ic.form flightList

/-- 予約確認（並び `mo` を選んだとき）。結果と、実行後の状態。 -/
def runConfirm (fd : FlightDb) (ic : ReserveInput) (mo : Order) : JResult ReserveConfirmOutputDto × FlightDb :=
  match load mo with
  | .error e => (.error e, fd)
  | .ok p => runOn (confirmBody p ic) fd ic.env

/-- 予約確定（並び `mo` を選んだとき）。結果と、実行後の状態。 -/
def runReserve (fd : FlightDb) (ic : ReserveInput) (mo : Order) : JResult ReserveCompleteOutputDto × FlightDb :=
  match load mo with
  | .error e => (.error e, fd)
  | .ok p => runOn (reserveBody p ic) fd ic.env

end SourceModel.ReserveQuery
