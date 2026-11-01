import SourceModel.MasterQuery
import SourceModel.App.B0.SelectFlightForm
import SourceModel.App.B0.TicketHelper

/-!
# SourceModel.FareQuery

運賃計算の具体機械（R 課題 ABS-001・ABS-002 の具体側）。

- 基本運賃: 入力は DB のマスタ・注入された設定・`calculateBasicFare` の引数である。1 歩は、Mapper の文の結果の
  許される並びのどれかで起動時の読み込み（`SourceModel.MasterQuery.load`）を行い、読み込んだ Provider を注入した
  `TicketSharedServiceImpl` の `calculateBasicFare` を呼ぶ関係とする（ABS-026 の `queryConcrete` と同じ形）。
- 運賃: `calculateFare` はマスタを読まないので、入力は引数だけとする。
- 合計金額: 入力は DB のマスタ・設定・選択フライト情報・搭乗者である。1 歩は、許される並びのどれかで読み込み、
  `TicketHelper.toFlightList` でフライト情報を組み立て、`TicketReserveServiceImpl.calculateTotalFare` を呼ぶ関係とする。
-/

namespace SourceModel.FareQuery
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.AtrsProperties
  SourceModel.MasterQuery

/-- 基本運賃の入力。 -/
@[gap "D-027"]
structure BasicFareInput where
  db : MasterDb
  config : AtrsConfig
  basicFareOfRoute : J32
  boardingClassCd : JRef Spec.Model.BoardingClassCd
  depDate : JRef JLocalDate
  deriving DecidableEq, Repr

/-- 起動時の読み込みと `calculateBasicFare`（並び `o` を選んだとき）。 -/
def runBasicFare (ic : BasicFareInput) (o : Order) : JResult J32 := do
  let p ← load o
  SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare p.shared ic.basicFareOfRoute ic.boardingClassCd ic.depDate

/-- 基本運賃の具体機械（状態を持たない）。1 歩は、許される並びのどれかで読み込んで計算する。 -/
def basicFareConcrete : Machine.Concrete Unit BasicFareInput J32 JThrow where
  Init _ := True
  step _ ic r := ∃ o, o.Allowed ic.db ∧ r = (runBasicFare ic o).map fun a => ((), a)

/-- 運賃の入力（`calculateFare` の引数）。 -/
@[gap "D-027"]
structure FareInput where
  basicFare : J32
  discountRate : J32
  deriving DecidableEq, Repr

/-- 運賃の具体機械（状態を持たない）。 -/
def fareConcrete : Machine.Concrete Unit FareInput J32 JThrow :=
  Machine.Concrete.pure fun ic => SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare ic.basicFare ic.discountRate

/-- 合計金額の入力。 -/
@[gap "D-027"]
structure TotalFareInput where
  db : MasterDb
  config : AtrsConfig
  flights : List SourceModel.App.B0.SelectFlightForm
  passengers : List (JRef Passenger)
  deriving DecidableEq, Repr

/-- 読み込んだ Provider を注入した `TicketHelper`。 -/
def ticketHelper (p : Providers) : SourceModel.App.B0.TicketHelper :=
  { flightMasterProvider := p.flightMaster, fareTypeProvider := p.fareType, boardingClassProvider := p.boardingClass }

/-- 読み込んだ Provider と設定を注入した `TicketReserveServiceImpl`。 -/
def ticketReserveService (p : Providers) (c : AtrsConfig) : SourceModel.Domain.Service.B2.TicketReserveServiceImpl :=
  { ticketSharedService := p.shared, representativeMinAge := c.representativeMinAge,
    adultPassengerMinAge := c.adultPassengerMinAge, childFareRate := c.childFareRate }

/-- 起動時の読み込み、`toFlightList`、`calculateTotalFare`（並び `o` を選んだとき）。 -/
def runTotalFare (ic : TotalFareInput) (o : Order) : JResult J32 := do
  let p ← load o
  let flights ← SourceModel.App.B0.TicketHelper.toFlightList (ticketHelper p) ic.flights
  SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare (ticketReserveService p ic.config) (some flights) (some ic.passengers)

/-- 合計金額の具体機械（状態を持たない）。 -/
def totalFareConcrete : Machine.Concrete Unit TotalFareInput J32 JThrow where
  Init _ := True
  step _ ic r := ∃ o, o.Allowed ic.db ∧ r = (runTotalFare ic o).map fun a => ((), a)

end SourceModel.FareQuery
