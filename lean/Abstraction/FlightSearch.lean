import Abstraction.FlightSearch.Run
import Abstraction.World.Init
import Abstraction.FlightSearch.Witness
import Abstraction.FlightSearch.Preserves

/-!
# Abstraction.FlightSearch

空席照会の証明課題（R 課題 ABS-011 と、その付帯の義務・W 課題）。補題・α・差異の述語は下位のモジュールに置く
（spec-pivot の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.FlightSearch
open Abstraction.World.Alpha Abstraction.World.Init
open Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Run Abstraction.FlightSearch.Order
  Abstraction.FlightSearch.Witness Abstraction.FlightSearch.Preserves Abstraction.MasterData.QueryRun Machine
open SourceModel.FlightSearchQuery

/-- R 課題 ABS-011: 空席照会。[Spec] の `searchMachine`（D-001・D-002 の前提で PRE を強める）は、具体機械
`searchConcrete`（D-027・D-014・D-032 の前提で入力を制限する）に、標準の貼り合わせ `glueFS`（状態は `worldOfDb`）で
リファインされる。 -/
@[obligation "ABS-011"]
theorem searchRefines :
    Refines ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      (((searchConcrete.restrict dev_D027S).restrict dev_D014S).restrict dev_D032) glueFS where
  init t ht := ⟨Spec.Seed.World.world, rfl, Or.inl ⟨by rw [ht]; exact worldOfDb_seed, by rw [ht]; exact icW_seed⟩⟩
  input_total := Glue.ofStd_input_total fun _ hd => hd.1.1.2
  applicable s t ic ia hinv hJ hα hpre hd := by
    obtain ⟨⟨hp, h1⟩, h2⟩ := hpre
    have hw : worldOfDb t = some s := by
      rcases hJ with ⟨h, -⟩ | h
      · exact h
      · exact h.elim
    obtain ⟨oc, hoc, -⟩ := run_spec hw hinv hα hp h1 h2 hd.1.2 hd.2 (mergeOrder_allowed ic.db)
      sortAllowed_mergeSortRows
    refine ⟨⟨_, mergeOrder ic.db, mergeSortRows, mergeOrder_allowed ic.db, sortAllowed_mergeSortRows, rfl⟩,
      fun e ⟨mo, sr, hmo, hsr, he⟩ => ?_⟩
    obtain ⟨oc', hoc', -⟩ := run_spec hw hinv hα hp h1 h2 hd.1.2 hd.2 hmo hsr
    rw [hoc'] at he
    cases he
  correct s t ic ia t' oc hinv hJ hα hpre hd hs := by
    obtain ⟨⟨hp, h1⟩, h2⟩ := hpre
    obtain ⟨hw, hic⟩ : worldOfDb t = some s ∧ IcW t := by
      rcases hJ with h | h
      · exact h
      · exact h.elim
    obtain ⟨mo, sr, hmo, hsr, he⟩ := hs
    obtain ⟨oc', hoc', hα'⟩ := run_spec hw hinv hα hp h1 h2 hd.1.2 hd.2 hmo hsr
    rw [hoc'] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact ⟨s, _, ⟨((), ()), rfl⟩, Or.inl ⟨hw, hic⟩, Or.inl hα'⟩

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem searchRefines_initSurj :
    Refines.InitSurj ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      (((searchConcrete.restrict dev_D027S).restrict dev_D014S).restrict dev_D032) glueFS :=
  fun s hs => ⟨SourceModel.Db.Seed.seedDb, rfl, Or.inl ⟨by rw [hs]; exact worldOfDb_seed, icW_seed⟩⟩

/-- W 課題 ABS-132（D-032 の必要性。G9）: 前提を外すと、ABS-011 は成り立たない。配備の環境の区切り文字が `.` のとき、
運賃 100,000 円の表示は、[Source] が `100.000`、[Spec] が `100,000` になる（`Witness`）。 -/
@[obligation "ABS-132", gap "D-032"]
theorem need_D032 :
    ¬ Refines ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      ((searchConcrete.restrict dev_D027S).restrict dev_D014S) glueFS := fun h => by
  obtain ⟨oc, hoc, hα⟩ := run_icFS_dot
  obtain ⟨hd1, hd2⟩ := iaFS_devs
  obtain ⟨s', oa, ⟨c, hc⟩, -, ho⟩ := h.correct wFS fdFS (icFS symDot) iaFS fdFS oc wFS_inv
    (Or.inl ⟨worldOfDb_fdFS, icW_of_nil rfl rfl⟩) aiS_icFS ⟨⟨iaFS_pre, hd1⟩, hd2⟩
    ⟨⟨trivial, by unfold dev_D027S; rw [aiS_icFS]; rfl⟩, rfl⟩
    ⟨mergeOrder dbFS, mergeSortRows, mergeOrder_allowed _, sortAllowed_mergeSortRows, by rw [hoc]; rfl⟩
  simp only [Spec.FlightSearch.searchStep, Prod.mk.injEq] at hc
  obtain ⟨-, rfl⟩ := hc
  rcases ho with ho | ho
  · rw [hα] at ho
    exact answer_ne_dot (Option.some.inj ho).symm
  · exact ho

/-- W 課題 ABS-114（D-014 の必要性。G9）: 前提を外すと、ABS-011 は成り立たない。照会の途中で日付をまたぐ
（共有サービスが 1970-01-01 を読んだ後、`searchFlight` が 1970-01-02 を読む）と、[Source] は照会可能期間の検査を通り、
予約可能期間に入らないので `e.ar.b1.2003` を返す。[Spec]（今日は 1970-01-02）は `e.ar.b1.2001` を返す（`Witness`）。 -/
@[obligation "ABS-114", gap "D-014"]
theorem need_D014 :
    ¬ Refines ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      ((searchConcrete.restrict dev_D027S).restrict dev_D032) glueFS := fun h => by
  obtain ⟨hd1, hd2⟩ := iaFS14_devs
  obtain ⟨s', oa, ⟨c, hc⟩, -, ho⟩ := h.correct wFS fdFS icFS14 iaFS14 fdFS (.error (.notFound "e.ar.b1.2003"))
    wFS_inv (Or.inl ⟨worldOfDb_fdFS, icW_of_nil rfl rfl⟩) aiS_icFS14 ⟨⟨iaFS14_pre, hd1⟩, hd2⟩
    ⟨⟨trivial, by unfold dev_D027S; rw [aiS_icFS14]; rfl⟩, rfl⟩
    ⟨mergeOrder dbFS, mergeSortRows, mergeOrder_allowed _, sortAllowed_mergeSortRows, by rw [run_icFS14]; rfl⟩
  simp only [Spec.FlightSearch.searchStep, Prod.mk.injEq] at hc
  obtain ⟨-, rfl⟩ := hc
  rcases ho with ho | ho
  · exact answer_ne14 (Option.some.inj ho).symm
  · exact ho

/-- ABS-011 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。基底が `ofChoice` なので `ch = some chFS`、
「出力のみ」の具体側の差異 D-032 の層を `outsC` に置く。 -/
@[obligation "ABS-011"]
theorem searchPreserves :
    Machine.Preserves ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      (((searchConcrete.restrict dev_D027S).restrict dev_D014S).restrict dev_D032) glueFS Spec.Seed.World.world envFS (some chFS) []
      [⟨(searchConcrete.restrict dev_D027S).restrict dev_D014S, dev_D032⟩] where
  sound := (Spec.FlightSearch.searchMachine_sound.restrictState _).restrictState _
  initIs := Spec.FlightSearch.searchMachine_initIs
  initSurj := searchRefines_initSurj
  total _ _ _ h := ⟨⟨⟨h.1.1, h.1.2, h.2.1, h.2.2.1, h.2.2.2.1, h.2.2.2.2.1⟩, h.2.2.2.2.2.1⟩, h.2.2.2.2.2.2⟩
  envWitness := ⟨icFS LangSemantics.Java.DecimalFormat.Symbols.ascii, iaFS, ⟨⟨⟨trivial, by unfold dev_D027S; rw [aiS_icFS_comma]; rfl⟩, rfl⟩, rfl⟩, aiS_icFS_comma,
    envFS_iaFS⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := wFS) (i := iaFSbad) wFS_inv
    fun h => Spec.EnvPre.badMasterData_not_env ⟨h.1.1.1, h.1.1.2.1⟩
  pinned c hc s t ic ia t' oc hi hJ ha hp hd hs := by
    cases hc
    obtain ⟨s', oa, ⟨x, hx⟩, hJ', ho⟩ := searchRefines.correct s t ic ia t' oc hi hJ ha hp hd hs
    refine ⟨(), ?_⟩
    change glueFS.J (Spec.FlightSearch.searchStep s ia ((), ())).1 t' ∧
      glueFS.αo oc (Spec.FlightSearch.searchStep s ia ((), ())).2
    obtain ⟨⟨⟩, ⟨⟩⟩ := x
    rw [hx]
    exact ⟨hJ', ho⟩
  noFault c hc ic ia hd ha := by
    cases hc
    exact ⟨ic, hd, ha, rfl⟩
  freeFrame c hc := by
    cases hc
    intro _ _ _ x y
    cases x; cases y; rfl
  stateSafeC l hl := by
    simp only [List.mem_singleton] at hl
    subst hl
    intro s t ic ia t' oc _ hJ _ _ _ _ hs
    have := step_state hs
    subst this
    exact ⟨s, _, ⟨((), ()), rfl⟩, hJ⟩

/-- ABS-011 の 1 歩の可換式: 前提を満たす入力では、[Source] のどの結果も正常終了で、状態を変えず、出力の像は
[Spec] の `answer`。 -/
theorem searchRefines_commutes {t : SourceModel.Db.Schema.FlightDb} {w : Spec.Port.World}
    (hw : worldOfDb t = some w) (hinv : w.Inv) {ic : SourceModel.FlightSearchQuery.SearchInput}
    {ia : Spec.FlightSearch.SearchInput} (hα : aiS ic = some ia) (hv : envFS ia) (h14 : dev_D014S ic)
    (h32 : dev_D032 ic) :
    ∀ r, searchConcrete.step t ic r → ∃ oc, r = .ok (t, oc) ∧ aoS oc = some (Spec.FlightSearch.answer w ia) := by
  intro r ⟨mo, sr, hmo, hsr, hr⟩
  obtain ⟨⟨hc, hm⟩, hb, hd, ha, hn, h1, h2⟩ := hv
  obtain ⟨oc, hoc, hα'⟩ := Run.run_spec hw hinv hα ⟨hc, hm, hb, hd, ha, hn⟩ h1 h2 h14 h32 hmo hsr
  exact ⟨oc, by rw [hr, hoc]; rfl, hα'⟩

end Abstraction.FlightSearch
