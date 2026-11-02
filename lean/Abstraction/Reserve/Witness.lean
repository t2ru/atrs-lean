import Abstraction.Reserve.Alpha
import Abstraction.FlightSearch.Witness

/-!
# Abstraction.Reserve.Witness

予約（ABS-041）の差異の述語の両向きの例（非自明性。G8）と、W 課題の証人の材料（backlog aedf の第 3 段）。
-/

namespace Abstraction.Reserve.Witness
open Abstraction.Reserve.Alpha Abstraction.Fare.TotalAlpha Abstraction.FlightSearch.Witness Spec.Model
  Spec.UseCase.Reserve
open Machine.Preserves (Nontrivial Nontrivial₂)
open LangSemantics.Java LangSemantics.Java.Int SourceModel.Db.Schema

/-! ## 具体側の入力 -/

/-- 代表者だけを入れた予約フォーム（選択フライトは無い）。 -/
def formR : SourceModel.App.B2.TicketReserveForm :=
  { repFamilyName := some "デンデン", repGivenName := some "タロウ", repAge := some (J32.ofInt 30),
    repGender := some .M, repTel1 := some "03", repTel2 := some "1234", repTel3 := some "5678",
    repMail := some "a@example.com" }

/-- 1970-01-01 に予約確認を行う具体側の入力（マスタは空席照会の証人と同じ）。 -/
def icR : SourceModel.ReserveQuery.MInput :=
  ⟨{ db := dbFS, config := SourceModel.AtrsProperties.upstreamConfig, form := formR,
     env := SourceModel.Db.Tx.Env.fixed ⟨1970, 1, 1⟩ }, .confirm⟩

theorem dev_D027R_nontrivial : Nontrivial dev_D027R :=
  ⟨⟨icR, by unfold dev_D027R; decide⟩,
    ⟨{ icR with input := { icR.input with form := { formR with repAge := none } } }, by unfold dev_D027R; decide⟩⟩

/-- 2 回目の読み出しで日付をまたぐ実行環境。 -/
def icR14 : SourceModel.ReserveQuery.MInput :=
  { icR with input := { icR.input with
      env := { clock := fun n => if n = 0 then ⟨1970, 1, 1⟩ else ⟨1970, 1, 2⟩ } } }

theorem dev_D014R_nontrivial : Nontrivial dev_D014R :=
  ⟨⟨icR, fun _ => rfl⟩, ⟨icR14, fun h => by have := h 1; simp [icR14] at this⟩⟩

/-! ## 抽象側の入力 -/

/-- 選択フライトの無い予約入力。 -/
def inputR : ReserveInput :=
  ⟨"デンデン", "タロウ", 30, .M, "03", "1234", "5678", "a@example.com", none, [⟨some "デンデン", some "タロウ", some 5, some .M, none⟩]⟩

/-- 抽象側の入力（予約確定。マスタ `md`、選択フライト `ss`）。 -/
def iaR (md : Spec.MasterData) (ss : List Spec.Ticket.SelectFlight) : MInput :=
  ⟨Spec.Config.default, md, day0, ⟨ss, inputR⟩, .reserve⟩

/-- NTT001・N・OW の選択フライト。 -/
def selR : Spec.Ticket.SelectFlight := ⟨day0, ⟨"NTT001"⟩, .N, .OW⟩

theorem dev_D009_nontrivial : Nontrivial₂ dev_D009 :=
  ⟨⟨(wFS, iaR mdFS []), fun _ => by decide⟩,
    ⟨({ wFS with sequences := { passenger := 2147483647 } }, iaR mdFS []), fun h => by
      have := (h rfl).2.2; simp at this⟩⟩

/-- 往路便の到着時刻が 24:15（翌日着）の便マスタ。 -/
def md2415 : Spec.MasterData :=
  { mdFS with flightMasters := [⟨⟨"NTT001"⟩, 1, ⟨22, 0, by decide⟩, ⟨24, 15, by decide⟩, "B777"⟩] }

theorem dev_D031_nontrivial : Nontrivial dev_D031 :=
  ⟨⟨iaR mdFS [], fun o h e => by simp [iaR] at e⟩,
    ⟨iaR md2415 [selR, selR], fun h => by
      have := h selR selR rfl _ rfl; exact absurd this (by decide)⟩⟩

theorem dev_D001R_nontrivial : Nontrivial dev_D001R :=
  ⟨⟨iaR mdTF012 [], by unfold dev_D001R; decide⟩, ⟨iaR mdTF29 [selR], by unfold dev_D001R; decide⟩⟩

theorem dev_D002R_nontrivial : Nontrivial dev_D002R :=
  ⟨⟨iaR mdTF012 [], by unfold dev_D002R; decide⟩, ⟨iaR mdTF1430 [selR], by unfold dev_D002R; decide⟩⟩

theorem dev_D012R_nontrivial : Nontrivial dev_D012R :=
  ⟨⟨iaR mdTF012 [], by unfold dev_D012R; decide⟩, ⟨iaR mdTF012 [selR], by unfold dev_D012R; decide⟩⟩

/-! ## W 課題 ABS-131（D-031）の証人の材料 -/

/-- 往路便 NTT523（HND→ITM、22:00 発・24:15 着）と復路便 NTT528（ITM→HND、08:00 発）、搭乗クラス N、運賃種別 RT のマスタ。 -/
def db2415 : MasterDb :=
  { airport := [⟨⟨"HND", by decide⟩, ⟨"Haneda", by decide⟩, ⟨1, by decide⟩⟩,
      ⟨⟨"ITM", by decide⟩, ⟨"Itami", by decide⟩, ⟨2, by decide⟩⟩],
    route := [⟨⟨1, by decide⟩, ⟨"HND", by decide⟩, ⟨"ITM", by decide⟩, ⟨"0100", by decide⟩, ⟨10000, by decide⟩⟩,
      ⟨⟨2, by decide⟩, ⟨"ITM", by decide⟩, ⟨"HND", by decide⟩, ⟨"0100", by decide⟩, ⟨10000, by decide⟩⟩],
    flightMaster := [⟨⟨"NTT523", by decide⟩, ⟨1, by decide⟩, ⟨"2200", by decide⟩, ⟨"2415", by decide⟩, ⟨"B777", by decide⟩⟩,
      ⟨⟨"NTT528", by decide⟩, ⟨2, by decide⟩, ⟨"0800", by decide⟩, ⟨"0900", by decide⟩, ⟨"B777", by decide⟩⟩],
    boardingClass := [⟨⟨"N", by decide⟩, some ⟨"N", by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩⟩],
    fareType := [⟨⟨"RT", by decide⟩, ⟨"RT", by decide⟩, ⟨10, by decide⟩, ⟨355, by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩,
      ⟨1, by decide⟩⟩] }

/-- 1970-01-01 の NTT523・N・RT と、1970-01-02 の NTT528・N・RT の FLIGHT 表。 -/
def fd2415 : FlightDb :=
  { flight := [⟨⟨0, by decide⟩, ⟨"NTT523", by decide⟩, ⟨"N", by decide⟩, ⟨"RT", by decide⟩, ⟨10, by decide⟩⟩,
      ⟨⟨1, by decide⟩, ⟨"NTT528", by decide⟩, ⟨"N", by decide⟩, ⟨"RT", by decide⟩, ⟨10, by decide⟩⟩] }

/-- NTT523 を往路、NTT528 を復路とする往復の予約確認。[Source] の計算（`runOp fd2415 ic2415 (mergeOrder db2415)`）は
`DateTimeParseException`（`Text '2415' could not be parsed`）で終わる（`#eval` で確かめた）。カーネルでの評価の定理と
ABS-131 の否定の定理は、ABS-041 と同時に置く（backlog aedf の 3c）。 -/
def ic2415 : SourceModel.ReserveQuery.MInput :=
  ⟨{ db := db2415, config := SourceModel.AtrsProperties.upstreamConfig,
     form := { formR with selectFlightFormList :=
       [⟨some ⟨1970, 1, 1⟩, some "NTT523", some .RT, some .N⟩, ⟨some ⟨1970, 1, 2⟩, some "NTT528", some .RT, some .N⟩] },
     env := SourceModel.Db.Tx.Env.fixed ⟨1970, 1, 1⟩ }, .confirm⟩

end Abstraction.Reserve.Witness
