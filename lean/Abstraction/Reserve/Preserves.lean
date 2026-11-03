import Abstraction.Reserve.Witness
import Abstraction.Reserve.ReserveRun
import Abstraction.MasterData.SeedAlpha
import Spec.EnvPre
import Spec.Seed.FlightProps

/-!
# Abstraction.Reserve.Preserves

ABS-041（予約）の束 `Machine.Preserves`（`Abstraction.Reserve.reservePreserves`）の部品（ADR ab93 の 3d）。

- 環境の前提 `envR`（状態と入力の述語）と、初期状態での証人 `icSeed`・`iaSeed`（シードのマスタの DB で、シードの最初の
  フライトを選ぶ予約確認）。環境の前提を破る入力 `iaBad`。
- 自由な選択 N-004 の枠の射影 `eraseDetailR`（`InvalidRequest` の詳細を消す）と核、枠の定理 `reserveStep_frame`。
- 選択の像の材料 `chR`（環境の記述 `ceR` と、それが許す選択 `Spec.Nondet.admits`）。
-/

namespace Abstraction.Reserve.Preserves
open Abstraction.Reserve.Alpha Abstraction.Reserve.Witness Abstraction.World.Alpha Spec.UseCase.Reserve Machine
open Abstraction.FlightSearch.Witness

/-- 2026-11-01。 -/
def daySeed : Spec.Prim.Date := ⟨2026, 11, 1, by decide⟩

/-- シードの最初のフライト（2026-11-01・NTT001・N・OW）を選ぶ予約フォーム。 -/
def formSeed : SourceModel.App.B2.TicketReserveForm :=
  { formR with selectFlightFormList := [⟨some ⟨2026, 11, 1, by decide⟩, some "NTT001", some .OW, some .N⟩], passengerFormList := [paxR] }

/-- 初期状態での環境の前提の証人（予約確認。マスタはシードのマスタの DB）。 -/
def icSeed : SourceModel.ReserveQuery.MInput :=
  ⟨{ db := SourceModel.Db.MasterSeed.masterDb, config := SourceModel.AtrsProperties.upstreamConfig, form := formSeed,
     env := SourceModel.Db.Tx.Env.fixed ⟨2026, 11, 1, by decide⟩ }, .confirm⟩

def iaSeed : Spec.UseCase.Reserve.MInput :=
  ⟨Spec.Seed.config, Spec.Seed.masterData, daySeed, ⟨[⟨daySeed, ⟨"NTT001"⟩, .N, .OW⟩], inputR⟩, .confirm⟩

theorem aiR_icSeed : aiR icSeed = some iaSeed := by
  have h1 : Abstraction.MasterData.Alpha.configOf icSeed.input.config = some Spec.Seed.config := by decide
  have h2 : Abstraction.MasterData.Alpha.masterDataOf icSeed.input.db = some Spec.Seed.masterData :=
    Abstraction.MasterData.SeedAlpha.masterDataOf_seed
  have h3 : Abstraction.MasterData.AlphaLeaf.dateOfJ (icSeed.input.env.clock 0) = some daySeed := by decide
  have h4 : requestOf icSeed.input.form = some iaSeed.req := by decide
  simp only [aiR, h1, h2, h3, h4, Option.bind_some]
  rfl

theorem refMaster_seed : Spec.Seed.World.world.RefMaster Spec.Seed.masterData :=
  Spec.Seed.FlightProps.world_refMaster

theorem memberRefMaster_seed : Spec.Seed.World.world.MemberRefMaster Spec.Seed.masterData := by decide

theorem req_seed : iaSeed.req.Valid := by
  refine ⟨?_, by decide, by decide, by decide, by decide, by decide, by decide, by decide, inputR_passengers⟩
  intro s hs
  simp only [iaSeed, List.mem_cons, List.not_mem_nil, or_false] at hs
  subst hs
  rw [Spec.Prim.Text.hasText, LangSemantics.Core.List.string_any_toList]
  decide

set_option maxHeartbeats 4000000 in
theorem confirm_seed :
    (confirmOp iaSeed.cfg iaSeed.md Spec.Seed.World.world iaSeed.req).isSome = true := by
  simp only [hasText_fun, confirmOp, checkSelects, reserveConfirm, buildDraft, compactPassengers,
    PassengerInput.isEmpty, iaSeed, inputR]
  all_goals decide +kernel

theorem devs_seed : dev_D001R iaSeed ∧ dev_D002R iaSeed ∧ dev_D012R iaSeed := by
  refine ⟨?_, ?_, ?_⟩
  · unfold dev_D001R; decide
  · unfold dev_D002R; decide
  · unfold dev_D012R; decide


/-! ## 環境の前提 -/

/-- ABS-041 の環境の前提: マスタ・設定の妥当性、要求の長さと桁、状態とマスタの対応（外部キー。`World.RefMaster`・
`World.MemberRefMaster`）、操作の結果が定まること（選択フライトが 1〜2 件、搭乗者の欄、マスタの便・区間・運賃種別）、
差異の前提（D-009・D-031・D-001・D-002・D-012）。状態と入力の述語（スキル spec-pivot の ADR 61e6）。 -/
def envR (w : Spec.Port.World) (i : Spec.UseCase.Reserve.MInput) : Prop :=
  Spec.EnvPre.masterConfigOk (i.cfg, i.md) ∧ i.req.Valid ∧ w.RefMaster i.md ∧ w.MemberRefMaster i.md ∧
    (match i.op with
     | .confirm => (confirmOp i.cfg i.md w i.req).isSome = true
     | .reserve => (reserveOp i.cfg i.md i.today w i.req).isSome = true) ∧
    dev_D009 w i ∧ dev_D031 i ∧ dev_D001R i ∧ dev_D002R i ∧ dev_D012R i

/-- 初期状態（シードを投入した後の `World`）で、証人 `iaSeed` は環境の前提を満たす。 -/
theorem envR_seed : envR Spec.Seed.World.world iaSeed := by
  obtain ⟨d1, d2, d12⟩ := devs_seed
  refine ⟨Spec.EnvPre.seed_env, req_seed, refMaster_seed, memberRefMaster_seed, confirm_seed, fun h => ?_,
    fun o h e => ?_, d1, d2, d12⟩
  · simp [iaSeed] at h
  · simp [iaSeed] at e

theorem dev_D027R_icSeed : dev_D027R icSeed := ⟨by rw [aiR_icSeed]; rfl, by decide⟩

/-- 環境の前提を破る入力: MD-1 を破るマスタ（PRE が成り立たない）。 -/
def iaBad : Spec.UseCase.Reserve.MInput :=
  ⟨Spec.Seed.config, Spec.EnvPre.badMasterData, Abstraction.Fare.TotalAlpha.day0, ⟨[], inputR⟩, .confirm⟩

/-! ## 自由な選択の枠 -/

/-- 出力の `InvalidRequest` の詳細を消す（自由な選択 N-004 が変えうるのは、この詳細だけ）。 -/
def eraseDetailO : MOutput → MOutput
  | .error (.invalidRequest _) => .error (.invalidRequest "")
  | o => o

/-- 自由な選択の枠の射影: 状態はそのまま、出力の `InvalidRequest` の詳細を消す。 -/
def eraseDetailR (r : Spec.Port.World × MOutput) : Spec.Port.World × MOutput := (r.1, eraseDetailO r.2)

/-- `eraseDetailR` の核: 状態が同じで、出力が同じか、どちらも `InvalidRequest`（詳細だけが違う）。 -/
@[kernel "docs/spec/abstraction.md#spec-の非決定性"]
def sameUpToDetail (a b : Spec.Port.World × MOutput) : Prop :=
  a.1 = b.1 ∧ (a.2 = b.2 ∨ ∃ s t, a.2 = .error (.invalidRequest s) ∧ b.2 = .error (.invalidRequest t))

theorem eraseDetailO_eq (o₁ o₂ : MOutput) : eraseDetailO o₁ = eraseDetailO o₂ ↔
    (o₁ = o₂ ∨ ∃ s t, o₁ = .error (.invalidRequest s) ∧ o₂ = .error (.invalidRequest t)) := by
  constructor
  · intro h
    rcases o₁ with e₁ | v₁ <;> rcases o₂ with e₂ | v₂
    · rcases e₁ with _ | _ | s | _ | _ <;> rcases e₂ with _ | _ | t | _ | _ <;>
        simp_all [eraseDetailO]
    · rcases e₁ with _ | _ | s | _ | _ <;> simp_all [eraseDetailO]
    · rcases e₂ with _ | _ | t | _ | _ <;> simp_all [eraseDetailO]
    · simp_all [eraseDetailO]
  · rintro (rfl | ⟨s, t, rfl, rfl⟩) <;> rfl

@[obligation "ABS-048"]
theorem eraseDetailR_kernel : Machine.Preserves.KernelIs eraseDetailR sameUpToDetail := by
  intro a b
  simp only [eraseDetailR, sameUpToDetail, Prod.mk.injEq, eraseDetailO_eq]

theorem eraseDetailO_withDetail (x y : Spec.Nondet.InvalidRequestDetail) (o : MOutput) :
    eraseDetailO (withDetail x o) = eraseDetailO (withDetail y o) := by
  rcases o with e | v
  · rcases e with _ | _ | s | _ | _ <;> rfl
  · rfl

/-- 自由な選択の枠: 自由な選択 N-004 を変えても、`eraseDetailR` で見た 1 歩の結果は変わらない。 -/
theorem reserveStep_frame : Machine.Machine.FreeFrame reserveStep eraseDetailR := by
  intro s i e x y
  obtain ⟨c, io⟩ := e
  have hw : ∀ o, eraseDetailO (withDetail x o) = eraseDetailO (withDetail y o) := eraseDetailO_withDetail x y
  rcases io with _ | a <;> rcases c with _ | a' <;> cases hop : i.op <;>
    simp [reserveStep, hop, eraseDetailR, hw]

/-- 選択の像の材料: 基底の `reserveStep`・標準の選択、環境の記述 `ceR`（`@[std_abs]`）と許す選択 `admits`、
自由な選択の枠の射影 `eraseDetailR`。 -/
def chR : Machine.Preserves.Choice Spec.Port.World Spec.UseCase.Reserve.MInput Spec.UseCase.Reserve.MOutput
    SourceModel.ReserveQuery.MInput :=
  ⟨Spec.Nondet.ConflictChoice × Spec.Nondet.IoFailureChoice, Spec.Nondet.InvalidRequestDetail, Spec.Nondet.FaultSpec,
    Spec.Port.World × Spec.UseCase.Reserve.MOutput, reserveStep, ceR, Spec.Nondet.admits, ⟨none, none⟩,
    (Spec.Nondet.ConflictChoice.std, Spec.Nondet.IoFailureChoice.std), eraseDetailR⟩

/-- 障害の位置を消した具体側の入力（障害の無い環境での実現）。 -/
def noFaults (ic : SourceModel.ReserveQuery.MInput) : SourceModel.ReserveQuery.MInput :=
  ⟨{ ic.input with env := { ic.input.env with ioFailAt := none, conflictAt := none } }, ic.kind⟩

theorem aiR_noFaults (ic : SourceModel.ReserveQuery.MInput) : aiR (noFaults ic) = aiR ic := rfl

end Abstraction.Reserve.Preserves
