import Abstraction.Fare.Preserves
import Abstraction.Fare.BasicFareRun
import Abstraction.Fare.FareRun
import Abstraction.Fare.TotalFareRun

/-!
# Abstraction.Fare

運賃計算の証明課題（R・W・C 課題と、R 課題の付帯の義務）。補題・α・差異の述語は下位のモジュールに置く
（spec-pivot の `lang/lean/rules.md#証明課題の配置`）。
-/

namespace Abstraction.Fare
open Abstraction.Fare.Preserves
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.Alpha Abstraction.Fare.Factors Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Lookup
  Abstraction.MasterData.QueryRun LangSemantics.Java.Int LangSemantics.Java.IntLemmas Machine
  Abstraction.Fare.BasicFareRun SourceModel.FareQuery Abstraction.Fare.FareRun Abstraction.Fare.TotalAlpha
  Abstraction.Fare.TotalFareRun Spec Spec.EnvPre Spec.Model

/-- R 課題 ABS-001。 -/
@[obligation "ABS-001"]
theorem basicFareRefines :
    Refines (Spec.Fare.basicFareMachine.restrict dev_D001) (basicFareConcrete.restrict dev_D027BF) glueBF where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    refine ⟨⟨_, mergeOrder ic.db, mergeOrder_allowed ic.db, rfl⟩, fun e ⟨o, ho, he⟩ => ?_⟩
    obtain ⟨v, -, -, hr, -⟩ := runBasicFare_spec hα hpre.1 ho
    rw [hr] at he
    cases he
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    obtain ⟨o, ho, he⟩ := hs
    obtain ⟨v, X, C, hr, hsp, hC, ⟨bc, hbc, hX⟩, hv⟩ := runBasicFare_spec hα hpre.1 ho
    rw [hr] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨-, rfl⟩ := he
    refine ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ?_⟩
    show natOfJ32 oc = some ((Spec.Fare.basicFare ia.md ia.routeBasicFare ia.boardingClassCd ia.depDate).getD 0)
    rw [hsp, Option.getD_some]
    apply natOfJ32_eq_some.mpr
    rcases hv with h | ⟨h1, -, h3, -⟩
    · exact h
    · have hd : dev_D001 ia := hpre.2
      unfold dev_D001 at hd
      rw [hbc] at hd
      simp only at hd
      rw [← hX, ← hC] at hd
      rcases hd with hd | hd
      · exact absurd h1 hd
      · exact absurd h3 hd

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem basicFareRefines_initSurj :
    Refines.InitSurj (Spec.Fare.basicFareMachine.restrict dev_D001) (basicFareConcrete.restrict dev_D027BF) glueBF :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- W 課題 ABS-101（D-001 の必要性。G9）: 前提を外すと、ABS-001 は成り立たない。区間の運賃 100 円・加算料金 0・
積算比率 29% で、[Source] は 28 円、[Spec] は 29 円。 -/
@[obligation "ABS-101", gap "D-001"]
theorem need_D001 : ¬ Refines Spec.Fare.basicFareMachine (basicFareConcrete.restrict dev_D027BF) glueBF := fun h => by
  obtain ⟨ia, he, hpre, -⟩ := aiBF_icBF29
  have hout : (Spec.Fare.basicFare ia.md ia.routeBasicFare ia.boardingClassCd ia.depDate).getD 0 = 29 := by
    have : (aiBF icBF29).map
        (fun ia => (Spec.Fare.basicFare ia.md ia.routeBasicFare ia.boardingClassCd ia.depDate).getD 0) = some 29 := by
      decide
    rw [he] at this
    simpa using this
  obtain ⟨s', oa, hst, -, ho⟩ := h.correct () () icBF29 ia () (J32.ofInt 28) trivial (Or.inl ⟨rfl, trivial⟩) he hpre
    ⟨trivial, by unfold dev_D027BF; rw [he]; rfl⟩
    ⟨mergeOrder db29, mergeOrder_allowed db29, by rw [runBasicFare_icBF29]; rfl⟩
  have : oa = 29 := hst.trans hout
  subst this
  rcases ho with ho | ho
  · exact absurd ho (by decide)
  · exact ho

/-- R 課題 ABS-002。 -/
@[obligation "ABS-002"]
theorem fareRefines : Refines (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    have e := calculateFare_eq hα hpre.1
    refine ⟨⟨_, rfl⟩, fun err he => ?_⟩
    have he' : Except.error err =
        (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare ic.basicFare ic.discountRate).map fun o => ((), o) := he
    rw [e] at he'
    cases he'
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    have e := calculateFare_eq hα hpre.1
    have hs' : Except.ok (t', oc) =
        (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare ic.basicFare ic.discountRate).map fun o => ((), o) := hs
    rw [e] at hs'
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at hs'
    obtain ⟨-, rfl⟩ := hs'
    refine ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ?_⟩
    obtain ⟨hr, hb, hbr⟩ := fare_range hpre.1
    exact natOfJ32_eq_some.mpr (fare_src_eq' hr hb hbr hpre.2)

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem fareRefines_initSurj :
    Refines.InitSurj (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- C 課題 ABS-003: 値域内では、[Source] の運賃は [Spec] の運賃に等しいか 100 円少ない（D-002 の前提によらない）。 -/
@[obligation "ABS-003"]
theorem fare_diff {ic : FareInput} {i : Spec.Fare.FareInput} (h : aiF ic = some i) (hp : i.Pre) :
    ∃ v, SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare ic.basicFare ic.discountRate = .ok v ∧
      (v.val = Spec.Fare.fare i.basicFare i.discountRate ∨
        v.val + 100 = Spec.Fare.fare i.basicFare i.discountRate) := by
  refine ⟨_, calculateFare_eq h hp, ?_⟩
  obtain ⟨hr, hb, hbr⟩ := fare_range hp
  rcases fare_src hr hb hbr with e | ⟨-, -, e⟩
  · exact Or.inl e
  · exact Or.inr e

/-- W 課題 ABS-102（D-002 の必要性。G9）: 前提を外すと、ABS-002 は成り立たない。基本運賃 1430 円・割引率 30% で、
[Source] は 1000 円、[Spec] は 1100 円。 -/
@[obligation "ABS-102", gap "D-002"]
theorem need_D002 : ¬ Refines Spec.Fare.fareMachine (fareConcrete.restrict dev_D027F) glueF := fun h => by
  have hα : aiF icF1430 = some ⟨1430, 30⟩ := rfl
  have hpre : Spec.Fare.FareInput.Pre ⟨1430, 30⟩ := by decide
  obtain ⟨s', oa, hst, -, ho⟩ := h.correct () () icF1430 ⟨1430, 30⟩ () (J32.ofInt 1000) trivial
    (Or.inl ⟨rfl, trivial⟩) hα hpre ⟨trivial, by unfold dev_D027F; decide⟩ (by
      show Except.ok ((), J32.ofInt 1000) = _
      rfl)
  have : oa = 1100 := hst
  subst this
  rcases ho with ho | ho
  · exact absurd ho (by decide)
  · exact ho

/-- R 課題 ABS-004。 -/
@[obligation "ABS-004"]
theorem totalFareRefines :
    Refines (((Spec.Fare.totalFareMachine.restrict dev_D001T).restrict dev_D002T).restrict dev_D012)
      (totalFareConcrete.restrict dev_D027TF) glueTF where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    obtain ⟨⟨⟨hp, h1⟩, h2⟩, h12⟩ := hpre
    refine ⟨⟨_, mergeOrder ic.db, mergeOrder_allowed ic.db, rfl⟩, fun e ⟨o, ho, he⟩ => ?_⟩
    rw [runTotalFare_eq hα hp h1 h2 h12 ho] at he
    cases he
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    obtain ⟨⟨⟨hp, h1⟩, h2⟩, h12⟩ := hpre
    obtain ⟨o, ho, he⟩ := hs
    rw [runTotalFare_eq hα hp h1 h2 h12 ho] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨-, rfl⟩ := he
    refine ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ?_⟩
    exact natOfJ32_eq_some.mpr (ofInt_nat (Nat.le_trans (totalFareOfKeys_le hp) (by decide)))

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem totalFareRefines_initSurj :
    Refines.InitSurj (((Spec.Fare.totalFareMachine.restrict dev_D001T).restrict dev_D002T).restrict dev_D012)
      (totalFareConcrete.restrict dev_D027TF) glueTF :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- W 課題 ABS-112（D-012 の必要性。G9）: 前提を外すと、ABS-004 は成り立たない。基本運賃 1 億円・割引率 0・小児 1 名で、
[Source] は 17,050,400 円、[Spec] は 60,000,000 円。 -/
@[obligation "ABS-112", gap "D-012"]
theorem need_D012 :
    ¬ Refines ((Spec.Fare.totalFareMachine.restrict dev_D001T).restrict dev_D002T)
      (totalFareConcrete.restrict dev_D027TF) glueTF := fun h => by
  obtain ⟨hd1, hd2, -⟩ := iaTF012_devs
  have hout : (Spec.Fare.totalFareOfKeys iaTF012.cfg iaTF012.md iaTF012.flights iaTF012.ages).getD 0 = 60000000 := by
    decide
  obtain ⟨s', oa, hst, -, ho⟩ := h.correct () () icTF012 iaTF012 () (J32.ofInt 17050400) trivial
    (Or.inl ⟨rfl, trivial⟩) aiTF_icTF012 ⟨⟨iaTF012_pre, hd1⟩, hd2⟩
    ⟨trivial, by unfold dev_D027TF; rw [aiTF_icTF012]; rfl⟩
    ⟨mergeOrder icTF012.db, mergeOrder_allowed _, by rw [runTotalFare_icTF012]; rfl⟩
  have : oa = 60000000 := hst.trans hout
  subst this
  rcases ho with ho | ho
  · exact absurd ho (by decide)
  · exact ho

/-- ABS-001 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。 -/
@[obligation "ABS-001"]
theorem basicFarePreserves :
    Machine.Preserves (Spec.Fare.basicFareMachine.restrict dev_D001) (basicFareConcrete.restrict dev_D027BF) glueBF ()
      envBF where
  sound := Spec.Fare.basicFareMachine_sound.restrictState _
  initIs := Spec.Fare.basicFareMachine_initIs
  initSurj := basicFareRefines_initSurj
  total _ _ _ h := ⟨⟨h.1.1, h.1.2, h.2.1⟩, h.2.2⟩
  envWitness := by
    obtain ⟨ia, hα, he⟩ := envBF_icBF101
    exact ⟨icBF101, ia, ⟨trivial, by unfold dev_D027BF; rw [hα]; rfl⟩, hα, he⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := ()) (i := iaBFbad) trivial
    fun h => badMasterData_not_env ⟨h.1.1, h.1.2.1⟩

/-- ABS-001 の 1 歩の可換式: 前提を満たす入力では、[Source] のどの結果も正常終了で、出力の像は [Spec] の基本運賃。 -/
theorem basicFareRefines_commutes {ic : BasicFareInput} {ia : Spec.Fare.BasicFareInput} (hα : aiBF ic = some ia)
    (hv : envBF ia) :
    ∀ r, basicFareConcrete.step () ic r → ∃ oc, r = .ok ((), oc) ∧
      natOfJ32 oc = some ((Spec.Fare.basicFare ia.md ia.routeBasicFare ia.boardingClassCd ia.depDate).getD 0) := by
  intro r hr
  obtain ⟨-, h⟩ := basicFareRefines.complete_fun
    (f := fun i => (Spec.Fare.basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).getD 0)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα
    ⟨⟨hv.1.1, hv.1.2, hv.2.1⟩, hv.2.2⟩ ⟨trivial, by unfold dev_D027BF; rw [hα]; rfl⟩
  obtain ⟨_, oc, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨oc, rfl, ho⟩
  · exact ho.elim

/-! ### ABS-002: 運賃 -/

/-- ABS-002 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。 -/
@[obligation "ABS-002"]
theorem farePreserves :
    Machine.Preserves (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF () envF where
  sound := Spec.Fare.fareMachine_sound.restrictState _
  initIs := Spec.Fare.fareMachine_initIs
  initSurj := fareRefines_initSurj
  total _ _ _ h := h
  envWitness := by
    obtain ⟨ia, hα, he⟩ := envF_icF1000
    exact ⟨icF1000, ia, ⟨trivial, by unfold dev_D027F; rw [hα]; rfl⟩, hα, he⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := ()) (i := ⟨Range.maxBasicFare + 1, 0⟩) trivial
    fun h => absurd h.1.1 (by decide)

/-- ABS-002 の 1 歩の可換式。 -/
theorem fareRefines_commutes {ic : FareInput} {ia : Spec.Fare.FareInput} (hα : aiF ic = some ia) (hv : envF ia) :
    ∀ r, fareConcrete.step () ic r → ∃ oc, r = .ok ((), oc) ∧
      natOfJ32 oc = some (Spec.Fare.fare ia.basicFare ia.discountRate) := by
  intro r hr
  obtain ⟨-, h⟩ := fareRefines.complete_fun (f := fun i => Spec.Fare.fare i.basicFare i.discountRate)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα hv
    ⟨trivial, by unfold dev_D027F; rw [hα]; rfl⟩
  obtain ⟨_, oc, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨oc, rfl, ho⟩
  · exact ho.elim

/-! ### ABS-004: 合計金額 -/

/-- ABS-004 の束 `Machine.Preserves`（A preserves B。`Refines` を使わない）。 -/
@[obligation "ABS-004"]
theorem totalFarePreserves :
    Machine.Preserves (((Spec.Fare.totalFareMachine.restrict dev_D001T).restrict dev_D002T).restrict dev_D012)
      (totalFareConcrete.restrict dev_D027TF) glueTF () envTF where
  sound := ((Spec.Fare.totalFareMachine_sound.restrictState _).restrictState _).restrictState _
  initIs := Spec.Fare.totalFareMachine_initIs
  initSurj := totalFareRefines_initSurj
  total _ _ _ h :=
    ⟨⟨⟨⟨h.1.1, h.1.2, h.2.1.1, h.2.1.2.1, h.2.1.2.2.1, h.2.1.2.2.2.1, h.2.1.2.2.2.2.1, h.2.1.2.2.2.2.2.1,
      h.2.1.2.2.2.2.2.2⟩, h.2.2.1⟩, h.2.2.2.1⟩, h.2.2.2.2⟩
  envWitness :=
    ⟨icTF100, iaTF100, ⟨trivial, by unfold dev_D027TF; rw [aiTF_icTF100]; rfl⟩, aiTF_icTF100, envTF_iaTF100⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := ()) (i := iaTFbad) trivial
    fun h => badMasterData_not_env ⟨h.1.1.1.1, h.1.1.1.2.1⟩

/-- ABS-004 の 1 歩の可換式。 -/
theorem totalFareRefines_commutes {ic : TotalFareInput} {ia : Spec.Fare.TotalFareInput} (hα : aiTF ic = some ia)
    (hv : envTF ia) :
    ∀ r, totalFareConcrete.step () ic r → ∃ oc, r = .ok ((), oc) ∧
      natOfJ32 oc = some ((Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0) := by
  intro r hr
  obtain ⟨-, h⟩ := totalFareRefines.complete_fun
    (f := fun i => (Spec.Fare.totalFareOfKeys i.cfg i.md i.flights i.ages).getD 0)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα
    (totalFarePreserves.total () ia trivial hv) ⟨trivial, by unfold dev_D027TF; rw [hα]; rfl⟩
  obtain ⟨_, oc, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨oc, rfl, ho⟩
  · exact ho.elim

end Abstraction.Fare
