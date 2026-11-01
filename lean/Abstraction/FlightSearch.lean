import Abstraction.FlightSearch.Run
import Abstraction.FlightSearch.Init

/-!
# Abstraction.FlightSearch

空席照会の証明課題（R 課題 ABS-011 と、その付帯の義務・W 課題）。補題・α・差異の述語は下位のモジュールに置く
（port-lang の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.FlightSearch
open Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Run Abstraction.FlightSearch.Order
  Abstraction.FlightSearch.Init Abstraction.MasterData.QueryRun Machine
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

end Abstraction.FlightSearch
