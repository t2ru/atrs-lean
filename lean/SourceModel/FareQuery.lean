import SourceModel.MasterQuery

/-!
# SourceModel.FareQuery

運賃計算の具体機械（R 課題 ABS-001・ABS-002 の具体側）。

- 基本運賃: 入力は DB のマスタ・注入された設定・`calculateBasicFare` の引数である。1 歩は、Mapper の文の結果の
  許される並びのどれかで起動時の読み込み（`SourceModel.MasterQuery.load`）を行い、読み込んだ Provider を注入した
  `TicketSharedServiceImpl` の `calculateBasicFare` を呼ぶ関係とする（ABS-026 の `queryConcrete` と同じ形）。
- 運賃: `calculateFare` はマスタを読まないので、入力は引数だけとする。
-/

namespace SourceModel.FareQuery

open LangSemantics.Java SourceModel.Model SourceModel.Repository.Schema SourceModel.Config SourceModel.MasterQuery

/-- 基本運賃の入力。 -/
structure BasicFareInput where
  db : MasterDb
  config : AtrsConfig
  basicFareOfRoute : J32
  boardingClassCd : JRef Spec.BoardingClassCd
  depDate : JRef JLocalDate
  deriving DecidableEq, Repr

/-- 起動時の読み込みと `calculateBasicFare`（並び `o` を選んだとき）。 -/
def runBasicFare (ic : BasicFareInput) (o : Order) : JResult J32 := do
  let p ← load o
  SourceModel.Fare.calculateBasicFare p.shared ic.basicFareOfRoute ic.boardingClassCd ic.depDate

/-- 基本運賃の具体機械（状態を持たない）。1 歩は、許される並びのどれかで読み込んで計算する。 -/
def basicFareConcrete : Machine.Concrete Unit BasicFareInput J32 JThrow where
  Init _ := True
  step _ ic r := ∃ o, o.Allowed ic.db ∧ r = (runBasicFare ic o).map fun a => ((), a)

/-- 運賃の入力（`calculateFare` の引数）。 -/
structure FareInput where
  basicFare : J32
  discountRate : J32
  deriving DecidableEq, Repr

/-- 運賃の具体機械（状態を持たない）。 -/
def fareConcrete : Machine.Concrete Unit FareInput J32 JThrow :=
  Machine.Concrete.pure fun ic => SourceModel.Fare.calculateFare ic.basicFare ic.discountRate

end SourceModel.FareQuery
