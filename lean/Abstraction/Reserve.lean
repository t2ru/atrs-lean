import Abstraction.Reserve.ReserveRun
import Abstraction.Reserve.Preserves
import Abstraction.Reserve.Witness
import Abstraction.World.Init

/-!
# Abstraction.Reserve

予約の証明課題（R 課題 ABS-041 と、その束・付帯の義務、W 課題 ABS-109・ABS-131）。補題・α・差異の述語は下位のモジュールに
置く（spec-pivot の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.Reserve
open Abstraction.World.Alpha Abstraction.World.Init Abstraction.Reserve.Alpha Abstraction.Reserve.ReserveRun
  Abstraction.Reserve.Preserves Abstraction.Reserve.Witness Abstraction.MasterData.QueryRun Machine
open Abstraction.FlightSearch.Witness
open SourceModel.ReserveQuery Spec.UseCase.Reserve

/-- R 課題 ABS-041: 予約。[Spec] の `reserveMachine`（D-009 の前提で状態と入力の PRE を強め、D-031・D-001・D-002・
D-012 の前提で PRE を強める）は、具体機械 `reserveConcrete`（D-027・D-014 の前提で入力を制限する）に、標準の貼り合わせ
`glueR`（状態は `worldOfDb`、具体側の不変条件は `IcW`）でリファインされる。 -/
@[obligation "ABS-041"]
theorem reserveRefines :
    Refines (((((reserveMachine.restrictState dev_D009).restrict dev_D031).restrict dev_D001R).restrict dev_D002R).restrict
        dev_D012R) ((reserveConcrete.restrict dev_D027R).restrict dev_D014R) glueR where
  init t ht := ⟨Spec.Seed.World.world, rfl, Or.inl ⟨by rw [ht]; exact worldOfDb_seed, by rw [ht]; exact icW_seed⟩⟩
  input_total := Glue.ofStd_input_total fun _ hd => hd.1.2.1
  applicable s t ic ia hinv hJ hα hpre hd := by
    obtain ⟨⟨⟨⟨⟨hp, h9⟩, h31⟩, h1⟩, h2⟩, h12⟩ := hpre
    obtain ⟨⟨-, h27⟩, h14⟩ := hd
    obtain ⟨hw, hic⟩ : worldOfDb t = some s ∧ IcW t := by
      rcases hJ with h | h
      · exact h
      · exact h.elim
    obtain ⟨oc, -, -, -, hc, -⟩ := run_any hw hic hinv hα hp h9 h31 h1 h2 h12 h27 h14
      (mergeOrder_allowed ic.input.db)
    refine ⟨⟨_, mergeOrder ic.input.db, mergeOrder_allowed _, rfl⟩, fun e ⟨mo, hmo, he⟩ => ?_⟩
    obtain ⟨oc', -, -, -, hc', -⟩ := run_any hw hic hinv hα hp h9 h31 h1 h2 h12 h27 h14 hmo
    rw [hc'] at he
    cases he
  correct s t ic ia t' oc hinv hJ hα hpre hd hs := by
    obtain ⟨⟨⟨⟨⟨hp, h9⟩, h31⟩, h1⟩, h2⟩, h12⟩ := hpre
    obtain ⟨⟨-, h27⟩, h14⟩ := hd
    obtain ⟨hw, hic⟩ : worldOfDb t = some s ∧ IcW t := by
      rcases hJ with h | h
      · exact h
      · exact h.elim
    obtain ⟨mo, hmo, he⟩ := hs
    obtain ⟨oc', w', oa, c, hc, hdb, hic', hst, ho, -⟩ := run_any hw hic hinv hα hp h9 h31 h1 h2 h12 h27 h14 hmo
    rw [hc] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact ⟨w', oa, ⟨c, hst⟩, Or.inl ⟨hdb, hic'⟩, Or.inl ho⟩

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem reserveRefines_initSurj :
    Refines.InitSurj (((((reserveMachine.restrictState dev_D009).restrict dev_D031).restrict dev_D001R).restrict
        dev_D002R).restrict dev_D012R) ((reserveConcrete.restrict dev_D027R).restrict dev_D014R) glueR :=
  fun s hs => ⟨SourceModel.Db.Seed.seedDb, rfl, Or.inl ⟨by rw [hs]; exact worldOfDb_seed, icW_seed⟩⟩

/-- ABS-041 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。基底が `ofChoice` なので `ch = some chR`
（環境の記述 `ceR` が許す選択 `Spec.Nondet.admits`、自由な選択の枠の射影 `eraseDetailR`）。差異はすべて中断の差異なので、
「出力のみ」の層は無い。環境の前提 `envR` は状態と入力の述語で、証人は初期状態で示す。 -/
@[obligation "ABS-041"]
theorem reservePreserves :
    Machine.Preserves (((((reserveMachine.restrictState dev_D009).restrict dev_D031).restrict dev_D001R).restrict dev_D002R).restrict
        dev_D012R) ((reserveConcrete.restrict dev_D027R).restrict dev_D014R) glueR Spec.Seed.World.world envR (some chR)
      [] [] where
  sound := ((((reserveMachine_sound.restrictState _).restrict _).restrict _).restrict _).restrict _
  initIs := reserveMachine_initIs
  initSurj := reserveRefines_initSurj
  total _ _ _ h := ⟨⟨⟨⟨⟨⟨h.1.1, h.1.2, h.2.1, h.2.2.1, h.2.2.2.1, h.2.2.2.2.1⟩, h.2.2.2.2.2.1⟩, h.2.2.2.2.2.2.1⟩,
    h.2.2.2.2.2.2.2.1⟩, h.2.2.2.2.2.2.2.2.1⟩, h.2.2.2.2.2.2.2.2.2⟩
  envWitness := ⟨icSeed, iaSeed, ⟨⟨trivial, dev_D027R_icSeed⟩, fun _ => rfl⟩, aiR_icSeed, envR_seed⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := wFS) (i := iaBad) wFS_inv
    fun h => Spec.EnvPre.badMasterData_not_env ⟨h.1.1.1.1.1.1, h.1.1.1.1.1.2.1⟩
  pinned c hc s t ic ia t' oc hi hJ hα hpre hd hs := by
    cases hc
    obtain ⟨⟨⟨⟨⟨hp, h9⟩, h31⟩, h1⟩, h2⟩, h12⟩ := hpre
    obtain ⟨⟨-, h27⟩, h14⟩ := hd
    obtain ⟨hw, hic⟩ : worldOfDb t = some s ∧ IcW t := by
      rcases hJ with h | h
      · exact h
      · exact h.elim
    obtain ⟨mo, hmo, he⟩ := hs
    obtain ⟨oc', w', oa, c, hc, hdb, hic', hst, ho, had⟩ := run_any hw hic hi hα hp h9 h31 h1 h2 h12 h27 h14 hmo
    rw [hc] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    refine ⟨c.1, c.2, had, ?_⟩
    show glueR.J (reserveStep s ia (c.1, c.2)).1 _ ∧ glueR.αo _ (reserveStep s ia (c.1, c.2)).2
    rw [show ((c.1, c.2) : _ × _) = c from rfl, hst]
    exact ⟨Or.inl ⟨hdb, hic'⟩, Or.inl ho⟩
  noFault c hc ic ia hd hα := by
    cases hc
    exact ⟨noFaults ic, ⟨⟨trivial, by unfold dev_D027R; rw [aiR_noFaults]; exact hd.1.2⟩, hd.2⟩,
      by show aiR (noFaults ic) = some ia; rw [aiR_noFaults]; exact hα, rfl⟩
  noFaultStd c hc e he := by
    cases hc
    exact Spec.Nondet.admits_none he
  freeFrame c hc := by
    cases hc
    exact reserveStep_frame

/-- W 課題 ABS-131（D-031 の必要性。G9）: 前提を外すと、ABS-041 は成り立たない。往路便の到着時刻が 24:15 の往復の
予約確認で、[Source] は `DateTimeParseException` で終わる（適用可能性が破れる）。[Spec] の PRE は成り立つ。 -/
@[obligation "ABS-131", gap "D-031"]
theorem need_D031 :
    ¬ Refines ((((reserveMachine.restrictState dev_D009).restrict dev_D001R).restrict dev_D002R).restrict dev_D012R)
      ((SourceModel.ReserveQuery.reserveConcrete.restrict dev_D027R).restrict dev_D014R) glueR := fun h => by
  obtain ⟨d9, d1, d2, d12⟩ := ia2415_devs
  obtain ⟨-, hne⟩ := h.applicable w2415 fd2415 ic2415 ia2415 w2415_inv (Or.inl ⟨worldOfDb_fd2415, icW_of_nil rfl rfl⟩)
    aiR_ic2415 ⟨⟨⟨⟨ia2415_pre, d9⟩, d1⟩, d2⟩, d12⟩ ⟨⟨trivial, ic2415_dev⟩, fun _ => rfl⟩
  have hr := run2415
  split at hr
  · rename_i e he
    exact hne e ⟨mergeOrder db2415, mergeOrder_allowed _, by rw [he]; rfl⟩
  · cases hr

/-- W 課題 ABS-109（D-009 の必要性。G9）: 前提を外すと、ABS-041 は成り立たない。搭乗者の採番の次の値が `int` の
最大値を超える状態で予約確定すると、[Source] は `MyBatisSystemException` で終わる（適用可能性が破れる）。[Spec] の
PRE は成り立つ。 -/
@[obligation "ABS-109", gap "D-009"]
theorem need_D009 :
    ¬ Refines ((((reserveMachine.restrict dev_D031).restrict dev_D001R).restrict dev_D002R).restrict dev_D012R)
      ((SourceModel.ReserveQuery.reserveConcrete.restrict dev_D027R).restrict dev_D014R) glueR := fun h => by
  obtain ⟨d31, d1, d2, d12⟩ := ia109_devs
  obtain ⟨-, hne⟩ := h.applicable w109 fd109 ic109 (iaR mdFS [selR]) w109_inv
    (Or.inl ⟨worldOfDb_fd109, icW_of_nil rfl rfl⟩) aiR_ic109 ⟨⟨⟨⟨ia109_pre, d31⟩, d1⟩, d2⟩, d12⟩
    ⟨⟨trivial, ic109_dev⟩, fun _ => rfl⟩
  have hr := run109
  split at hr
  · rename_i e he
    exact hne e ⟨mergeOrder dbFS, mergeOrder_allowed _, by rw [he]; rfl⟩
  · cases hr

end Abstraction.Reserve
