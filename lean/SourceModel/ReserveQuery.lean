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
import SourceModel.Db.Seed
import Machine

/-!
# SourceModel.ReserveQuery

予約（B2）の入口の計算（backlog aedf）。Controller（`TicketReserveController`）の `reserveConfirm`・`reserve` の、入力検証の
後の流れを写す。

1. 起動時の読み込み（`SourceModel.MasterQuery.load`。Mapper の文の結果の並び `mo`）
2. `TicketHelper.toFlightList`（選択フライト情報からフライト情報を作る）
3. `TicketReserveHelper.validateFlightList`（失敗は `BadRequestException`）
4. `TicketReserveHelper.reserveConfirm` または `TicketReserveHelper.reserve`

状態は状態の表とシーケンス（`FlightDb`）、実行環境（Clock・障害の位置）は入力の成分である。具体機械 `reserveConcrete`
（backlog aedf の第 2 段）は、業務例外・不正要求（`BadRequestException`）・I/O の失敗・排他の失敗を出力の値とし、
それ以外の例外（前提違反・制約違反・更新件数の不一致など）を正常でない結果とする。
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

/-! ## 具体機械（backlog aedf の第 2 段） -/

/-- 操作の種類: 予約確認（`POST ?confirm`）・予約確定（`POST`）。 -/
inductive Kind where
  | confirm
  | reserve
  deriving DecidableEq, Repr

/-- 具体機械の入力。 -/
structure MInput where
  input : ReserveInput
  kind : Kind

/-- 具体機械の出力の値。 -/
inductive MOutputValue where
  | confirmed (o : ReserveConfirmOutputDto)
  | reserved (o : ReserveCompleteOutputDto)
  deriving DecidableEq, Repr

/-- 出力の値とする例外: 業務例外（コードと引数）、不正要求、I/O の失敗、排他の失敗。 -/
inductive ReserveError where
  | business (code : String) (args : List String)
  | badRequest
  | ioFailure
  | conflict
  deriving DecidableEq, Repr

/-- 具体機械の出力。 -/
abbrev MOutput := Except ReserveError MOutputValue

/-- 出力の値とする例外を、出力の値に変える。それ以外の例外は、そのまま例外とする。業務例外のメッセージは、
コードと引数を改行でつないだもの（`AtrsBusinessException.newArgs`）。 -/
def catchReserve (r : JResult MOutputValue) : JResult MOutput :=
  match r with
  | .ok v => .ok (.ok v)
  | .error (.other cls msg) =>
    if cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className then
      match msg.splitOn "\n" with
      | code :: args => .ok (.error (.business code args))
      | [] => .ok (.error (.business msg []))
    else if cls = TicketReserveHelper.badRequestClass then .ok (.error .badRequest)
    else if cls = ioFailureClass then .ok (.error .ioFailure)
    else if cls = conflictClass then .ok (.error .conflict)
    else .error (.other cls msg)
  | .error e => .error e

/-- 1 歩の計算（並び `mo` を選んだとき）。 -/
def runOp (fd : FlightDb) (ic : MInput) (mo : Order) : JResult MOutputValue × FlightDb :=
  match ic.kind with
  | .confirm => let (r, fd') := runConfirm fd ic.input mo; (r.map .confirmed, fd')
  | .reserve => let (r, fd') := runReserve fd ic.input mo; (r.map .reserved, fd')

/-- 予約の具体機械。状態は状態の表とシーケンス、初期状態はシードを投入した後の状態。1 歩は、Mapper の文の結果の
許される並びのどれかで読み込み、操作を実行する。定義域: 予約確認では排他の失敗を起こさない（予約確認の文は行ロックを
取らないので、排他の失敗は起きない）。 -/
def reserveConcrete : Machine.Concrete FlightDb MInput MOutput JThrow where
  Init t := t = SourceModel.Db.Seed.seedDb
  Dom ic := ic.kind = .confirm → ic.input.env.conflictAt = none
  step t ic r := ∃ mo, mo.Allowed ic.input.db ∧ r = (catchReserve (runOp t ic mo).1).map fun o => ((runOp t ic mo).2, o)

end SourceModel.ReserveQuery
