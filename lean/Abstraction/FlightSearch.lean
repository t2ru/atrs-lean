import Abstraction.FlightSearch.Run
import Abstraction.FlightSearch.Init
import Abstraction.FlightSearch.Witness

/-!
# Abstraction.FlightSearch

空席照会の証明課題（R 課題 ABS-011 と、その付帯の義務・W 課題）。補題・α・差異の述語は下位のモジュールに置く
（port-lang の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.FlightSearch
open Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Run Abstraction.FlightSearch.Order
  Abstraction.FlightSearch.Init Abstraction.FlightSearch.Witness Abstraction.MasterData.QueryRun Machine
open SourceModel.FlightSearchQuery

/-- R 課題 ABS-011: 空席照会。[Spec] の `searchMachine`（D-001・D-002 の前提で PRE を強める）は、具体機械
`searchConcrete`（D-027・D-032 の前提で入力を制限する）に、標準の貼り合わせ `glueFS`（状態は `worldOfDb`）で
リファインされる。 -/
@[obligation "ABS-011"]
theorem searchRefines :
    Refines ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      ((searchConcrete.restrict dev_D027S).restrict dev_D032) glueFS where
  init t ht := ⟨Spec.Seed.Flight.world, rfl, Or.inl ⟨by rw [ht]; exact worldOfDb_seed, trivial⟩⟩
  input_total := Glue.ofStd_input_total fun _ hd => hd.1.2
  applicable s t ic ia hinv hJ hα hpre hd := by
    obtain ⟨⟨hp, h1⟩, h2⟩ := hpre
    have hw : worldOfDb t = some s := by
      rcases hJ with ⟨h, -⟩ | h
      · exact h
      · exact h.elim
    obtain ⟨oc, hoc, -⟩ := run_spec hw hinv hα hp h1 h2 hd.2 (mergeOrder_allowed ic.db)
      sortAllowed_mergeSortRows
    refine ⟨⟨_, mergeOrder ic.db, mergeSortRows, mergeOrder_allowed ic.db, sortAllowed_mergeSortRows, rfl⟩,
      fun e ⟨mo, sr, hmo, hsr, he⟩ => ?_⟩
    obtain ⟨oc', hoc', -⟩ := run_spec hw hinv hα hp h1 h2 hd.2 hmo hsr
    rw [hoc'] at he
    cases he
  correct s t ic ia t' oc hinv hJ hα hpre hd hs := by
    obtain ⟨⟨hp, h1⟩, h2⟩ := hpre
    have hw : worldOfDb t = some s := by
      rcases hJ with ⟨h, -⟩ | h
      · exact h
      · exact h.elim
    obtain ⟨mo, sr, hmo, hsr, he⟩ := hs
    obtain ⟨oc', hoc', hα'⟩ := run_spec hw hinv hα hp h1 h2 hd.2 hmo hsr
    rw [hoc'] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact ⟨s, _, ⟨((), ()), rfl⟩, Or.inl ⟨hw, trivial⟩, Or.inl hα'⟩

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem searchRefines_initSurj :
    Refines.InitSurj ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      ((searchConcrete.restrict dev_D027S).restrict dev_D032) glueFS :=
  fun s hs => ⟨SourceModel.Repository.FlightSeed.seedFlightDb, rfl, Or.inl ⟨by rw [hs]; exact worldOfDb_seed, trivial⟩⟩

/-- W 課題 ABS-132（D-032 の必要性。G9）: 前提を外すと、ABS-011 は成り立たない。配備の環境の区切り文字が `.` のとき、
運賃 100,000 円の表示は、[Source] が `100.000`、[Spec] が `100,000` になる（`Witness`）。 -/
@[obligation "ABS-132", gap "D-032"]
theorem need_D032 :
    ¬ Refines ((Spec.FlightSearch.searchMachine.restrict dev_D001S).restrict dev_D002S)
      (searchConcrete.restrict dev_D027S) glueFS := fun h => by
  obtain ⟨oc, hoc, hα⟩ := run_icFS_dot
  obtain ⟨hd1, hd2⟩ := iaFS_devs
  obtain ⟨s', oa, ⟨c, hc⟩, -, ho⟩ := h.correct wFS fdFS (icFS '.') iaFS fdFS oc wFS_inv
    (Or.inl ⟨worldOfDb_fdFS, trivial⟩) aiS_icFS ⟨⟨iaFS_pre, hd1⟩, hd2⟩
    ⟨trivial, by unfold dev_D027S; rw [aiS_icFS]; rfl⟩
    ⟨mergeOrder dbFS, mergeSortRows, mergeOrder_allowed _, sortAllowed_mergeSortRows, by rw [hoc]; rfl⟩
  simp only [Prod.mk.injEq] at hc
  obtain ⟨-, rfl⟩ := hc
  rcases ho with ho | ho
  · rw [hα] at ho
    exact answer_ne_dot (Option.some.inj ho).symm
  · exact ho

end Abstraction.FlightSearch
