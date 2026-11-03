import SourceModel

/-!
# Tests.TicketChecks

`SourceModel.App.B0.TicketHelper.toFlightList`（`TicketHelper.toFlightList`）と、合計金額の具体機械の実行（`runTotalFare`）の検査。
期待値は原典のコードを読んで手で書いた（原典実行との照合は backlog f18c）。
-/

open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model SourceModel.MasterQuery SourceModel.FareQuery
  SourceModel.App.B0 SourceModel.App.B0.TicketHelper

namespace Tests.TicketChecks

/-- 空港 2 つ・区間 1 つ（運賃 20,600 円）・便 NTT001・搭乗クラス N（加算料金 0）・運賃種別 OW（割引率 0）の DB。 -/
def db : SourceModel.Db.Schema.MasterDb :=
  { airport := [⟨⟨"HND", by decide⟩, ⟨"Haneda", by decide⟩, ⟨1, by decide⟩⟩,
      ⟨⟨"ITM", by decide⟩, ⟨"Itami", by decide⟩, ⟨2, by decide⟩⟩],
    route := [⟨⟨1, by decide⟩, ⟨"HND", by decide⟩, ⟨"ITM", by decide⟩, ⟨"0100", by decide⟩, ⟨20600, by decide⟩⟩],
    flightMaster := [⟨⟨"NTT001", by decide⟩, ⟨1, by decide⟩, ⟨"0800", by decide⟩, ⟨"0900", by decide⟩,
      ⟨"B777", by decide⟩⟩],
    boardingClass := [⟨⟨"N", by decide⟩, some ⟨"N", by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩⟩],
    fareType := [⟨⟨"OW", by decide⟩, ⟨"OW", by decide⟩, ⟨0, by decide⟩, ⟨355, by decide⟩, ⟨0, by decide⟩,
      ⟨1, by decide⟩, ⟨1, by decide⟩⟩] }

def form (name : JRef String) : SelectFlightForm :=
  ⟨some ⟨2026, 11, 1, by decide⟩, name, some .OW, some .N⟩

def providers : Option Providers := (load (standardOrder db)).toOption

-- toFlightList: 便マスタ（区間の運賃を含む）・運賃種別・搭乗クラスを Provider から引く
#guard (providers.map fun p => (toFlightList (SourceModel.FareQuery.ticketHelper p) [form (some "NTT001")]).toOption.map fun fl =>
  fl.map fun f => (f.bind (·.flightMaster)).bind (·.route) |>.bind (·.basicFare) |>.map (·.val)) ==
  some (some [some 20600])
-- マスタに無い便名は null のフライト情報の成分になる（例外ではない）
#guard (providers.map fun p => (toFlightList (SourceModel.FareQuery.ticketHelper p) [form (some "NTT999")]).toOption.map fun fl =>
  fl.map fun f => (f.bind (·.flightMaster)).isSome) == some (some [false])
-- 拒む例: 便名が null なら IllegalArgumentException
#guard (providers.map fun p => match toFlightList (SourceModel.FareQuery.ticketHelper p) [form none] with
  | .error (.illegalArgument _) => true | _ => false) == some true

-- 合計金額（fare-calculation.md の例: 大人 2 名・小児 1 名で 53,600 円）
def passengers : List (JRef Passenger) := [30, 28, 5].map fun a => some { age := some (J32.ofInt a) }
#guard ((runTotalFare ⟨db, SourceModel.AtrsProperties.upstreamConfig, [form (some "NTT001")], passengers⟩
  (standardOrder db)).toOption.map (·.val)) == some 53600

end Tests.TicketChecks
