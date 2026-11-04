import Abstraction.Reserve.Alpha
import Abstraction.FlightSearch.Witness
import Abstraction.MasterData.QueryRun

/-!
# Abstraction.Reserve.Witness

予約（ABS-041）の差異の述語の両向きの例（非自明性。G8）と、W 課題 ABS-109（D-009）・ABS-131（D-031）の証人と否定の
定理の材料（backlog aedf の第 3 段）。否定の定理（W 課題）は、機能のモジュール `Abstraction.Reserve` に置く。

[Source] の計算のカーネルでの評価は、`String.any`（整礎再帰）で止まるので、`hasText` を文字の列の形に書き換えてから
`decide +kernel` で評価する（空席照会の証人と同じ）。
-/

namespace Abstraction.Reserve.Witness
open Abstraction.Reserve.Alpha Abstraction.Fare.TotalAlpha Abstraction.FlightSearch.Witness Spec.Model
  Spec.Reserve
open Machine Abstraction.World.Alpha Abstraction.MasterData.QueryRun
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
     env := SourceModel.Db.Tx.Env.fixed ⟨1970, 1, 1, by decide⟩ }, .confirm⟩

theorem dev_D027R_nontrivial : Nontrivial dev_D027R :=
  ⟨⟨icR, by unfold dev_D027R; decide⟩,
    ⟨{ icR with input := { icR.input with form := { formR with repAge := none } } }, by unfold dev_D027R; decide⟩⟩

/-- 2 回目の読み出しで日付をまたぐ実行環境。 -/
def icR14 : SourceModel.ReserveQuery.MInput :=
  { icR with input := { icR.input with
      env := { clock := fun n => if n = 0 then ⟨1970, 1, 1, by decide⟩ else ⟨1970, 1, 2, by decide⟩ } } }

theorem dev_D014R_nontrivial : Nontrivial dev_D014R :=
  ⟨⟨icR, fun _ => rfl⟩, ⟨icR14, fun h => by have := h 1; simp [icR14] at this⟩⟩

/-! ## 抽象側の入力 -/

/-- 選択フライトの無い予約入力。 -/
def inputR : ReserveInput :=
  ⟨"デンデン", "タロウ", 30, .M, "03", "1234", "5678", "a@example.com", none, [⟨some "デンデン", some "タロウ", some 5, some .M, none⟩]⟩

/-- 抽象側の入力（予約確定。マスタ `md`、選択フライト `ss`）。 -/
def iaR (md : Spec.Env.MasterData) (ss : List Spec.Reserve.FlightSelection.SelectFlight) : MInput :=
  ⟨Spec.Env.Config.default, md, day0, ⟨ss, inputR⟩, .reserve⟩

/-- NTT001・N・OW の選択フライト。 -/
def selR : Spec.Reserve.FlightSelection.SelectFlight := ⟨day0, "NTT001", .N, .OW⟩

theorem dev_D009_nontrivial : Nontrivial₂ dev_D009 :=
  ⟨⟨(wFS, iaR mdFS []), fun _ => by decide⟩,
    ⟨({ wFS with sequences := { passenger := 2147483647 } }, iaR mdFS []), fun h => by
      have := (h rfl).2.2; simp at this⟩⟩

/-- 往路便の到着時刻が 24:15（翌日着）の便マスタ。 -/
def md2415 : Spec.Env.MasterData :=
  { mdFS with flightMasters := [⟨{ val := "NTT001" }, 1, ⟨22, 0, by decide⟩, ⟨24, 15, by decide⟩, "B777"⟩] }

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

/-- 搭乗者欄（デンデン タロウ・5 歳・男性）。 -/
def paxR : SourceModel.App.B2.PassengerForm :=
  { familyName := some "デンデン", givenName := some "タロウ", age := some (J32.ofInt 5), gender := some .M }

/-- NTT523 を往路、NTT528 を復路とする予約フォーム（搭乗者 1 人）。 -/
def form2415 : SourceModel.App.B2.TicketReserveForm :=
  { formR with selectFlightFormList := [⟨some ⟨1970, 1, 1, by decide⟩, some "NTT523", some .RT, some .N⟩,
    ⟨some ⟨1970, 1, 2, by decide⟩, some "NTT528", some .RT, some .N⟩], passengerFormList := [paxR] }

/-- NTT523 を往路、NTT528 を復路とする往復の予約確認（搭乗者 1 人）。 -/
def ic2415 : SourceModel.ReserveQuery.MInput :=
  ⟨{ db := db2415, config := SourceModel.AtrsProperties.upstreamConfig,
     form := form2415,
     env := SourceModel.Db.Tx.Env.fixed ⟨1970, 1, 1, by decide⟩ }, .confirm⟩

/-! ## 評価の補題 -/

theorem hasText_fun : Spec.Prim.Text.hasText = fun s => s.toList.any fun c => !Spec.Prim.Text.isBlank c := by
  funext s
  simp only [Spec.Prim.Text.hasText, LangSemantics.Core.List.string_any_toList]

theorem suHasText_fun : LangSemantics.Java.Spring.StringUtils.hasText =
    fun str => match str with
      | some s => s.toList.any fun c => !LangSemantics.Java.String.isJavaWhitespace c
      | none => false := by
  funext str
  cases str <;> simp [LangSemantics.Java.Spring.StringUtils.hasText, LangSemantics.Core.List.string_any_toList]

/-! ## W 課題 ABS-131（D-031） -/

/-- ABS-131 の証人の [Spec] のマスタ（`db2415` の写し）。 -/
def mdW2415 : Spec.Env.MasterData :=
  { airports := [⟨{ val := "HND" }, "Haneda", 1⟩, ⟨{ val := "ITM" }, "Itami", 2⟩],
    routes := [⟨1, { val := "HND" }, { val := "ITM" }, 10000⟩, ⟨2, { val := "ITM" }, { val := "HND" }, 10000⟩],
    flightMasters := [⟨{ val := "NTT523" }, 1, ⟨22, 0, by decide⟩, ⟨24, 15, by decide⟩, "B777"⟩,
      ⟨{ val := "NTT528" }, 2, ⟨8, 0, by decide⟩, ⟨9, 0, by decide⟩, "B777"⟩],
    boardingClasses := [⟨.N, "N", 0, 1⟩],
    fareTypes := [⟨.RT, "RT", 10, 355, 0, 1, 1⟩],
    peakTimes := [], planes := [], creditTypes := [] }

/-- 1970-01-02。 -/
def day1R : Spec.Prim.Date := ⟨1970, 1, 2, by decide⟩

/-- ABS-131 の証人の [Spec] の入力（`ic2415` の像）。 -/
def ia2415 : Spec.Reserve.MInput :=
  ⟨Spec.Env.Config.default, mdW2415, day0, ⟨[⟨day0, "NTT523", .N, .RT⟩, ⟨day1R, "NTT528", .N, .RT⟩], inputR⟩, .confirm⟩

/-- ABS-131 の証人の [Spec] の状態（`fd2415` の像）。 -/
def w2415 : Spec.World := { flights := [⟨⟨day0, { val := "NTT523" }, .N, .RT⟩, 10⟩, ⟨⟨day1R, { val := "NTT528" }, .N, .RT⟩, 10⟩] }

theorem worldOfDb_fd2415 : worldOfDb fd2415 = some w2415 := by decide

theorem w2415_inv : w2415.Inv := w2415.inv

theorem aiR_ic2415 : aiR ic2415 = some ia2415 := by
  have h1 : Abstraction.MasterData.Alpha.configOf ic2415.input.config = some Spec.Env.Config.default := by decide
  have h2 : Abstraction.MasterData.Alpha.masterDataOf ic2415.input.db = some mdW2415 := by decide
  have h3 : Abstraction.MasterData.AlphaLeaf.dateOfJ (ic2415.input.env.clock 0) = some day0 := by decide
  have h4 : requestOf ic2415.input.form = some ia2415.req := by decide
  simp only [aiR, h1, h2, h3, h4, Option.bind_some]
  rfl

theorem md2415_valid : mdW2415.Valid Spec.Env.Config.default := by
  refine ⟨by decide, by decide, by decide, by decide, by decide, by decide, by decide, ?_⟩
  refine ⟨?_, by decide, by decide, by decide⟩
  intro a ha
  simp only [mdW2415, List.mem_cons, List.not_mem_nil, or_false] at ha
  rcases ha with rfl | rfl <;> decide

theorem inputR_passengers : ∀ p ∈ inputR.passengers, (∀ s ∈ p.familyName, s.length ≤ 10) ∧
    (∀ s ∈ p.givenName, s.length ≤ 10) ∧ (∀ a ∈ p.age, a ≤ 999) := by
  intro p hp
  simp only [inputR, List.mem_cons, List.not_mem_nil, or_false] at hp
  subst hp
  exact ⟨by decide, by decide, by decide⟩

theorem req2415_valid : ia2415.req.Valid := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide, by decide, by decide, inputR_passengers⟩
  intro s hs
  simp only [ia2415, List.mem_cons, List.not_mem_nil, or_false] at hs
  rcases hs with rfl | rfl <;> (rw [Spec.Prim.Text.hasText, LangSemantics.Core.List.string_any_toList]; decide)

theorem confirm2415_some : (confirmOp ia2415.cfg ia2415.md w2415 ia2415.req).isSome = true := by
  simp only [hasText_fun, confirmOp, checkSelects, reserveConfirm, buildDraft, compactPassengers,
    PassengerInput.isEmpty, ia2415, inputR]
  all_goals decide +kernel

theorem ia2415_pre : ia2415.Pre w2415 :=
  ⟨Spec.Env.masterConfigOk.of_valid (by decide) md2415_valid, req2415_valid, by decide, by decide, confirm2415_some⟩

theorem ia2415_devs : dev_D009 w2415 ia2415 ∧ dev_D001R ia2415 ∧ dev_D002R ia2415 ∧ dev_D012R ia2415 := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro h; simp [ia2415] at h
  · unfold dev_D001R; decide
  · unfold dev_D002R; decide
  · unfold dev_D012R; decide

theorem ic2415_dev : dev_D027R ic2415 := ⟨by rw [aiR_ic2415]; rfl, by decide⟩

set_option maxHeartbeats 4000000 in
/-- [Source] の計算（許される並びの 1 つ）は、出力の値としない例外（`DateTimeParseException`。`Text '2415' could not
be parsed`）で終わる。 -/
theorem run2415 : (match SourceModel.ReserveQuery.catchReserve (SourceModel.ReserveQuery.runOp fd2415 ic2415 (mergeOrder db2415)).1 with
    | .error _ => true
    | .ok _ => false) = true := by
  simp only [SourceModel.ReserveQuery.runOp, SourceModel.ReserveQuery.runConfirm, SourceModel.ReserveQuery.confirmBody, ic2415,
    form2415, List.mapM_cons, List.mapM_nil,
    SourceModel.App.B0.TicketHelper.toFlightList, SourceModel.App.B0.TicketHelper.toFlight,
    SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster, assertHasText_eq]
  decide +kernel

/-! ## W 課題 ABS-109（D-009） -/

/-- 搭乗者の採番の次の値が 2,147,483,648（`int` の最大値の次）の状態の表（フライトは空席照会の証人と同じ）。 -/
def fd109 : FlightDb := { fdFS with sqPassenger := some 2147483647 }

/-- NTT001・N・OW を選んだ予約フォーム（搭乗者 1 人）。 -/
def form109 : SourceModel.App.B2.TicketReserveForm :=
  { formR with selectFlightFormList := [⟨some ⟨1970, 1, 1, by decide⟩, some "NTT001", some .OW, some .N⟩], passengerFormList := [paxR] }

/-- NTT001・N・OW を選んだ予約確定（搭乗者 1 人）。 -/
def ic109 : SourceModel.ReserveQuery.MInput :=
  ⟨{ db := dbFS, config := SourceModel.AtrsProperties.upstreamConfig,
     form := form109,
     env := SourceModel.Db.Tx.Env.fixed ⟨1970, 1, 1, by decide⟩ }, .reserve⟩

/-- ABS-109 の証人の [Spec] の状態（`fd109` の像）。 -/
def w109 : Spec.World := { wFS with sequences := { wFS.sequences with passenger := 2147483648 } }

theorem worldOfDb_fd109 : worldOfDb fd109 = some w109 := by decide

theorem w109_inv : w109.Inv := w109.inv

theorem aiR_ic109 : aiR ic109 = some (iaR mdFS [selR]) := by
  have h1 : Abstraction.MasterData.Alpha.configOf ic109.input.config = some Spec.Env.Config.default := by decide
  have h2 : Abstraction.MasterData.Alpha.masterDataOf ic109.input.db = some mdFS := by decide
  have h3 : Abstraction.MasterData.AlphaLeaf.dateOfJ (ic109.input.env.clock 0) = some day0 := by decide
  have h4 : requestOf ic109.input.form = some (iaR mdFS [selR]).req := by decide
  simp only [aiR, h1, h2, h3, h4, Option.bind_some]
  rfl

theorem mdFS_valid : mdFS.Valid Spec.Env.Config.default := by
  refine ⟨by decide, by decide, by decide, by decide, by decide, by decide, by decide, ?_⟩
  refine ⟨?_, by decide, by decide, by decide⟩
  intro a ha
  simp only [mdFS, List.mem_cons, List.not_mem_nil, or_false] at ha
  rcases ha with rfl | rfl <;> decide

theorem req109_valid : (iaR mdFS [selR]).req.Valid := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide, by decide, by decide, inputR_passengers⟩
  intro s hs
  simp only [iaR, selR, List.mem_cons, List.not_mem_nil, or_false] at hs
  subst hs
  rw [Spec.Prim.Text.hasText, LangSemantics.Core.List.string_any_toList]
  decide

theorem reserve109_some : (reserveOp (iaR mdFS [selR]).cfg (iaR mdFS [selR]).md (iaR mdFS [selR]).today w109
    (iaR mdFS [selR]).req).isSome = true := by
  simp only [hasText_fun, reserveOp, checkSelects, reserve, buildDraft, PassengerInput.isEmpty, iaR, inputR]
  all_goals decide +kernel

theorem ia109_pre : (iaR mdFS [selR]).Pre w109 :=
  ⟨Spec.Env.masterConfigOk.of_valid (by decide) mdFS_valid, req109_valid, by decide, by decide, reserve109_some⟩

theorem ia109_devs : dev_D031 (iaR mdFS [selR]) ∧ dev_D001R (iaR mdFS [selR]) ∧ dev_D002R (iaR mdFS [selR]) ∧
    dev_D012R (iaR mdFS [selR]) := by
  refine ⟨fun o h e => by simp [iaR] at e, ?_, ?_, ?_⟩
  · unfold dev_D001R; decide
  · unfold dev_D002R; decide
  · unfold dev_D012R; decide

theorem ic109_dev : dev_D027R ic109 := ⟨by rw [aiR_ic109]; rfl, by decide⟩

set_option maxHeartbeats 8000000 in
/-- [Source] の計算（許される並びの 1 つ）は、搭乗者番号の `selectKey` の読み出しの失敗（`MyBatisSystemException`。
`Bad value for type int : 2147483648`）で終わる。 -/
theorem run109 : (match SourceModel.ReserveQuery.catchReserve (SourceModel.ReserveQuery.runOp fd109 ic109 (mergeOrder dbFS)).1 with
    | .error _ => true
    | .ok _ => false) = true := by
  simp only [SourceModel.ReserveQuery.runOp, SourceModel.ReserveQuery.runReserve, SourceModel.ReserveQuery.reserveBody, ic109, form109, SourceModel.App.B2.TicketReserveHelper.reserve,
    SourceModel.App.B2.TicketReserveHelper.createReservation, List.mapM_cons, List.mapM_nil,
    SourceModel.App.B0.TicketHelper.toFlightList, SourceModel.App.B0.TicketHelper.toFlight,
    SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster, assertHasText_eq,
    SourceModel.App.B2.PassengerForm.isEmpty, suHasText_fun]
  decide +kernel

end Abstraction.Reserve.Witness
