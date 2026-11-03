import Abstraction.MasterData.Preserves
import Abstraction.MasterData.QueryRun

/-!
# Abstraction.MasterData

マスタ・設定・コードリストの参照の証明課題（R・W・C 課題と、R 課題の付帯の義務）。補題・α・差異の述語は下位のモジュールに置く
（spec-pivot の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.MasterData
open Abstraction.MasterData.Preserves
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.MasterData.Alpha Abstraction.MasterData.Lookup Machine Abstraction.MasterData.QueryRun
  SourceModel.MasterQuery Spec Spec.EnvPre

/-- R 課題 ABS-026。 -/
@[obligation "ABS-026"]
theorem queryRefines : Refines Spec.MasterQuery.queryMachine ((queryConcrete.restrict dev_D027).restrict dev_D036) glueMQ where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.1.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    obtain ⟨cfg, md, q⟩ := ia
    have hα' : aiMQ ic = some (cfg, md, q) := hα
    refine ⟨⟨_, mergeOrder ic.db, mergeOrder_allowed ic.db, rfl⟩, fun e ⟨o, ho, he⟩ => ?_⟩
    obtain ⟨a, hr, -⟩ := run_correct hα' hpre.2.1 hpre.2.2 ho
    rw [hr] at he
    cases he
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    obtain ⟨cfg, md, q⟩ := ia
    have hα' : aiMQ ic = some (cfg, md, q) := hα
    obtain ⟨o, ho, he⟩ := hs
    obtain ⟨a, hr, ha⟩ := run_correct hα' hpre.2.1 hpre.2.2 ho
    rw [hr] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨-, rfl⟩ := he
    exact ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ha⟩

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem queryRefines_initSurj : Refines.InitSurj Spec.MasterQuery.queryMachine ((queryConcrete.restrict dev_D027).restrict dev_D036) glueMQ :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- W 課題 ABS-142（D-036 の被覆。G9）: D-027 の前提（α が定義される）の下では、DB の空港の行のコードは空港コードの
形式に合う（空港の行の α `airportOfRow` が、コードを `AirportCd` として読む）。 -/
@[obligation "ABS-142", gap "D-036"]
theorem covers_D036 : Machine.Preserves.Covers dev_D027 dev_D036 := by
  intro ic h r hr
  unfold dev_D027 at h
  obtain ⟨⟨cfg, md, q⟩, hq⟩ := Option.isSome_iff_exists.mp h
  simp only [aiMQ, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hq
  obtain ⟨_, -, md', hmd, -⟩ := hq
  obtain ⟨a, -, ha⟩ := LangSemantics.Core.MapM.mapM_some_mem
    (Abstraction.MasterData.Pre.masterDataOf_eq_some.mp hmd).1 hr
  simp only [airportOfRow, Option.bind_eq_some_iff] at ha
  obtain ⟨c, hc, -⟩ := ha
  have := Abstraction.MasterData.AlphaLeaf.airportCdOf_eq_some hc
  rw [← this]; exact c.wf

/-- W 課題 ABS-127（D-027 の必要性。G9）: 前提を外すと、ABS-026 は成り立たない。未知の搭乗クラスコード `X` の行を
持つ DB では α が定義されず、入力の全域性が破れる。 -/
@[obligation "ABS-127", gap "D-027"]
theorem need_D027 : ¬ Refines Spec.MasterQuery.queryMachine (queryConcrete.restrict dev_D036) glueMQ := fun h => by
  obtain ⟨ia, hia⟩ := h.input_total ic_unknownBoardingClass ⟨trivial, by unfold dev_D036; decide⟩
  have : aiMQ ic_unknownBoardingClass = none := by decide
  rw [show glueMQ.αi ic_unknownBoardingClass ia = (aiMQ ic_unknownBoardingClass = some ia) from rfl, this] at hia
  cases hia

/-- ABS-026 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。 -/
@[obligation "ABS-026"]
theorem queryPreserves :
    Machine.Preserves Spec.MasterQuery.queryMachine ((queryConcrete.restrict dev_D027).restrict dev_D036) glueMQ () (fun _ => envMQ) where
  sound := Spec.MasterQuery.queryMachine_sound
  initIs := Spec.MasterQuery.queryMachine_initIs
  initSurj := queryRefines_initSurj
  total _ _ _ h := ⟨h.1.1, h.1.2, h.2⟩
  envWitness := by
    obtain ⟨ia, hα, he⟩ := envMQ_icMQ
    have h27 : dev_D027 icMQ := by unfold dev_D027; rw [hα]; rfl
    exact ⟨icMQ, ia, ⟨⟨trivial, h27⟩, covers_D036 _ h27⟩, hα, he⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := ()) (i := (Seed.config, badMasterData, .config)) trivial
    fun h => badMasterData_not_env ⟨h.1, h.2.1⟩

/-- ABS-026 の 1 歩の可換式: 前提を満たす入力では、[Source] のどの結果も正常終了で、答えの像は [Spec] の答え。 -/
theorem queryRefines_commutes {ic : SrcInput} {cfg : Config} {md : Spec.MasterData} {q : Spec.MasterQuery.Query}
    (hα : aiMQ ic = some (cfg, md, q)) (hv : envMQ (cfg, md, q)) :
    ∀ r, queryConcrete.step () ic r → ∃ a, r = .ok ((), a) ∧ answerOf? a = some (Spec.MasterQuery.answer cfg md q) := by
  intro r hr
  have h27 : dev_D027 ic := by unfold dev_D027; rw [hα]; rfl
  obtain ⟨-, h⟩ := queryRefines.complete_fun (f := fun i => Spec.MasterQuery.answer i.1 i.2.1 i.2.2)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα ⟨hv.1.1, hv.1.2, hv.2⟩
    ⟨⟨trivial, h27⟩, covers_D036 _ h27⟩
  obtain ⟨_, a, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨a, rfl, ho⟩
  · exact ho.elim

end Abstraction.MasterData
