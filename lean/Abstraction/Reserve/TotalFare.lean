import Abstraction.Fare.TotalFareRun
import Abstraction.Reserve.Alpha

/-!
# Abstraction.Reserve.TotalFare

ABS-041 の補題: 予約の合計金額（`TicketReserveServiceImpl.calculateTotalFare`）は、合計金額の L 課題 ABS-005
（`Abstraction.Fare.TotalFareRun.runTotalFare_eq`）から、[Spec] の `totalFareOfKeys` の値になる（backlog aedf の第 3 段）。
-/

namespace Abstraction.Reserve.TotalFare
open Abstraction.Fare.TotalAlpha Abstraction.Fare.TotalFareRun
open LangSemantics.Java LangSemantics.Java.Int
open SourceModel.MasterQuery SourceModel.FareQuery SourceModel.Domain.Service.B2

/-- 合計金額の計算: 読み込んだ Provider `p`、作ったフライト情報 `flights` のもとで、合計金額の入力 `ic` の前提を満たせば、
[Spec] の合計金額。会員の表（`memberRepository`）は使わない。 -/
theorem calc_eq {ic : TotalFareInput} {ia : Spec.Fare.TotalFareInput} (hα : aiTF ic = some ia) (hp : ia.Pre)
    (h1 : dev_D001T ia) (h2 : dev_D002T ia) (h12 : dev_D012 ia) {o : Order} (ho : o.Allowed ic.db) {p : Providers}
    (hl : load o = .ok p) {flights : List (Exception.JRef SourceModel.Domain.Model.Flight)}
    (htf : SourceModel.App.B0.TicketHelper.toFlightList (ticketHelper p) ic.flights = .ok flights)
    (mdb : SourceModel.Db.Schema.MasterDb) :
    TicketReserveServiceImpl.calculateTotalFare { ticketReserveService p ic.config with memberRepository := mdb }
        (some flights) (some ic.passengers) =
      .ok (J32.ofInt ((Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0)) := by
  have h := runTotalFare_eq hα hp h1 h2 h12 ho
  simp only [runTotalFare, hl, htf, bind, Except.bind] at h
  exact h

end Abstraction.Reserve.TotalFare
