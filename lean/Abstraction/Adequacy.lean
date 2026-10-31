import Abstraction.MasterData.Refines
import Abstraction.Fare.BasicFareRefines
import Abstraction.Fare.FareRefines
import Abstraction.Fare.TotalFareRefines

/-!
# Abstraction.Adequacy

実装済みの範囲（マスタ・設定・コードリストの読み込みと、運賃計算）の R 課題について、リファインメント `Refines` と
空虚化を防ぐ義務（`Machine.Adequacy`）を束ねた `Machine.Adequate` を示す（ADR 70eb）。

各 R 課題について、次を示す。

| 定理 | 内容 |
| --- | --- |
| `*Adequate` | `Machine.Adequate`: R 課題の主定理、[Spec] の機械の `Sound`・`InitIs`、`InitSurj`、環境の前提 `env*` の下の `TotalUnder`、`EnvWitness`（前提を満たす像を持つ [Source] の入力）、前提の必要性（`¬ TotalUnder always`） |
| `*Commutes` | 1 歩の可換式（`Refines.complete_fun`）: [Spec] の PRE の下で、[Source] のどの結果も正常終了で、出力の像は [Spec] の出力 |

束には、R 課題と同じ課題 ID の `@[obligation]` を付ける（R 課題と同じ `A`・`C`・`g` を束ねることを obligation-check の GA が、
R 課題ごとに束があることを `check_obligations.py` の OB-A が確かめる）。系として、初期状態からの複数歩の模倣
（`Machine.Adequate.run_init`）と、[Source] の正常終了が実在すること（`Machine.Adequate.exists_ok`）が成り立つ。
トップレベルの主定理 `Abstraction.adequate`（`Abstraction.lean`）は、これらを並置して示す。

環境の前提 `env*` は、マスタ・設定の妥当性（`Spec.masterConfigOk`）と、入力の値域、差異の前提の述語を、
[Spec] の入力の成分だけで書いたものである。入口の R 課題ではないので `@[env_pre]` は付けない。
-/

namespace Abstraction

open Machine LangSemantics.Java Spec Spec.Prim LangSemantics.Core

/-! ## ABS-026: マスタ・設定・コードリストの読み込み -/

namespace MasterData

open SourceModel.MasterQuery

/-- ABS-026 の環境の前提: マスタ・設定の妥当性と、問い合わせの値域。 -/
def envMQ (i : Config × Spec.MasterData × Spec.MasterData.Query) : Prop :=
  masterConfigOk (i.1, i.2.1) ∧ i.2.2.Valid

/-- 前提を満たす [Source] の入力: `Abstraction.Fare.dbTF` の DB（空港 2・区間 1・便 1）、上流の設定、設定の参照。 -/
def icMQ : SrcInput :=
  { db := Abstraction.Fare.dbTF ⟨100, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩,
    config := SourceModel.Config.upstreamConfig, query := .config }

theorem envMQ_icMQ : ∃ ia, aiMQ icMQ = some ia ∧ envMQ ia := by
  cases he : aiMQ icMQ with
  | none => exact absurd he (by decide)
  | some ia =>
    have hc : ia.1.Valid := by
      have : (aiMQ icMQ).any (fun ia => decide ia.1.Valid) = true := by decide
      rw [he] at this; simpa using this
    have hq : ia.2.2.Valid := by
      have : (aiMQ icMQ).any (fun ia => decide ia.2.2.Valid) = true := by decide
      rw [he] at this; simpa using this
    have hm : EnvPre.validB ia.1 ia.2.1 = true := by
      have : (aiMQ icMQ).any (fun ia => EnvPre.validB ia.1 ia.2.1) = true := by decide +kernel
      rw [he] at this; simpa using this
    exact ⟨ia, rfl, ⟨hc, EnvPre.validB_sound hm⟩, hq⟩

/-- ABS-026 の義務の束。 -/
@[obligation "ABS-026"]
theorem queryAdequate :
    Machine.Adequate Spec.MasterData.queryMachine (queryConcrete.restrict dev_D027) glueMQ () envMQ where
  refines := queryRefines
  sound := Spec.MasterData.queryMachine_sound
  initIs := Spec.MasterData.queryMachine_initIs
  initSurj := queryRefines_initSurj
  total _ _ _ h := ⟨h.1.1, h.1.2, h.2⟩
  envWitness := by
    obtain ⟨ia, hα, he⟩ := envMQ_icMQ
    exact ⟨icMQ, ia, ⟨trivial, by unfold dev_D027; rw [hα]; rfl⟩, hα, he⟩
  envNeeded := .inr <| Machine.TotalUnder.not_always (s := ()) (i := (Seed.config, badMasterData, .config)) trivial
    fun h => badMasterData_not_env ⟨h.1, h.2.1⟩

/-- ABS-026 の 1 歩の可換式: 前提を満たす入力では、[Source] のどの結果も正常終了で、答えの像は [Spec] の答え。 -/
theorem queryCommutes {ic : SrcInput} {cfg : Config} {md : Spec.MasterData} {q : Spec.MasterData.Query}
    (hα : aiMQ ic = some (cfg, md, q)) (hv : envMQ (cfg, md, q)) :
    ∀ r, queryConcrete.step () ic r → ∃ a, r = .ok ((), a) ∧ answerOf? a = some (Spec.MasterData.answer cfg md q) := by
  intro r hr
  obtain ⟨-, h⟩ := queryRefines.complete_fun (f := fun i => Spec.MasterData.answer i.1 i.2.1 i.2.2)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα ⟨hv.1.1, hv.1.2, hv.2⟩
    ⟨trivial, by unfold dev_D027; rw [hα]; rfl⟩
  obtain ⟨_, a, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨a, rfl, ho⟩
  · exact ho.elim

end MasterData

/-! ## ABS-001・ABS-002・ABS-004: 運賃計算 -/

namespace Fare

open SourceModel.FareQuery Abstraction.MasterData

/-! ### ABS-001: 基本運賃 -/

/-- ABS-001 の環境の前提: マスタ・設定の妥当性、`routeBasicFare + extraCharge` の値域、D-001 の前提。 -/
def envBF (i : Spec.Fare.BasicFareInput) : Prop :=
  masterConfigOk (i.cfg, i.md) ∧
    (i.md.boardingClassOf i.boardingClassCd).any
      (fun bc => decide (i.routeBasicFare + bc.extraCharge ≤ Range.maxBasicFareWithCharge)) = true ∧
    dev_D001 i

/-- 前提を満たす [Source] の入力: `icBF29` の区間の運賃を 101 円にしたもの（`101·29` は 100 で割り切れない）。 -/
def icBF101 : BasicFareInput := { icBF29 with basicFareOfRoute := J32.ofInt 101 }

theorem envBF_icBF101 : ∃ ia, aiBF icBF101 = some ia ∧ envBF ia := by
  cases he : aiBF icBF101 with
  | none => exact absurd he (by decide)
  | some ia =>
    have h : decide ia.cfg.Valid && EnvPre.validB ia.cfg ia.md &&
        (ia.md.boardingClassOf ia.boardingClassCd).any
          (fun bc => decide (ia.routeBasicFare + bc.extraCharge ≤ Range.maxBasicFareWithCharge)) &&
        decide (dev_D001 ia) = true := by
      have : (aiBF icBF101).any (fun ia => decide ia.cfg.Valid && EnvPre.validB ia.cfg ia.md &&
          (ia.md.boardingClassOf ia.boardingClassCd).any
            (fun bc => decide (ia.routeBasicFare + bc.extraCharge ≤ Range.maxBasicFareWithCharge)) &&
          decide (dev_D001 ia)) = true := by decide +kernel
      rw [he] at this; simpa using this
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    exact ⟨ia, rfl, ⟨h.1.1.1, EnvPre.validB_sound h.1.1.2⟩, h.1.2, h.2⟩

/-- 環境の前提を破る [Spec] の入力: MD-1 を破るマスタ。 -/
def iaBFbad : Spec.Fare.BasicFareInput := ⟨Seed.config, badMasterData, 0, .N, day0⟩

/-- ABS-001 の義務の束。 -/
@[obligation "ABS-001"]
theorem basicFareAdequate :
    Machine.Adequate (Spec.Fare.basicFareMachine.restrict dev_D001) (basicFareConcrete.restrict dev_D027BF) glueBF ()
      envBF where
  refines := basicFareRefines
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
theorem basicFareCommutes {ic : BasicFareInput} {ia : Spec.Fare.BasicFareInput} (hα : aiBF ic = some ia)
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

/-- ABS-002 の環境の前提: 基本運賃と割引率の値域、D-002 の前提（マスタ・設定を含まない）。 -/
def envF (i : Spec.Fare.FareInput) : Prop := i.Pre ∧ dev_D002 i

/-- 前提を満たす [Source] の入力: 基本運賃 1000 円・割引率 10%。 -/
def icF1000 : FareInput := ⟨J32.ofInt 1000, J32.ofInt 10⟩

instance : DecidablePred envF := fun i => by unfold envF; infer_instance

theorem envF_icF1000 : ∃ ia, aiF icF1000 = some ia ∧ envF ia := by
  cases he : aiF icF1000 with
  | none => exact absurd he (by decide)
  | some ia =>
    have : (aiF icF1000).any (fun ia => decide (envF ia)) = true := by decide
    rw [he] at this
    exact ⟨ia, rfl, by simpa using this⟩

/-- ABS-002 の義務の束。 -/
@[obligation "ABS-002"]
theorem fareAdequate :
    Machine.Adequate (Spec.Fare.fareMachine.restrict dev_D002) (fareConcrete.restrict dev_D027F) glueF () envF where
  refines := fareRefines
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
theorem fareCommutes {ic : FareInput} {ia : Spec.Fare.FareInput} (hα : aiF ic = some ia) (hv : envF ia) :
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

/-- 合計金額の入力の値域（PRE のうち、マスタ・設定の妥当性を除く部分）。 -/
def rangeTF (i : Spec.Fare.TotalFareInput) : Prop :=
  Range.minReserveFlights ≤ i.flights.length ∧ i.flights.length ≤ Range.maxReserveFlights ∧
    Range.minPassengers ≤ i.ages.length ∧ i.ages.length ≤ Range.maxPassengers ∧
    (∀ a ∈ i.ages, a ≤ Range.maxAge) ∧
    (∀ k ∈ i.flights, hasText k.flightName.val = true) ∧
    (Spec.Fare.totalFareOfKeys i.cfg i.md i.flights i.ages).isSome = true

/-- ABS-004 の環境の前提: マスタ・設定の妥当性、入力の値域、D-001・D-002・D-012 の前提。 -/
def envTF (i : Spec.Fare.TotalFareInput) : Prop :=
  masterConfigOk (i.cfg, i.md) ∧ rangeTF i ∧ dev_D001T i ∧ dev_D002T i ∧ dev_D012 i

/-- 前提を満たす [Source] の入力: 区間の運賃 100 円・積算比率 100%・割引率 0・大人 1 名。 -/
def icTF100 : TotalFareInput := icTF ⟨100, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩ [20]

/-- `icTF100` の DB の [Spec] の写し。 -/
def mdTF100 : Spec.MasterData :=
  ⟨mdTF012.airports, [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100⟩], mdTF012.flightMasters, mdTF012.boardingClasses, mdTF012.fareTypes,
    [⟨"P", day0, day0, 100⟩], [], []⟩

/-- `icTF100` の [Spec] の入力。 -/
def iaTF100 : Spec.Fare.TotalFareInput := ⟨Config.default, mdTF100, iaTF012.flights, [20]⟩

theorem aiTF_icTF100 : aiTF icTF100 = some iaTF100 := by
  rfl

theorem envTF_iaTF100 : envTF iaTF100 := by
  refine ⟨⟨by decide, EnvPre.validB_sound (by decide +kernel)⟩,
    ⟨by decide, by decide, by decide, by decide, by decide, ?_, by decide⟩, by decide, by decide, by decide⟩
  intro k hk
  simp only [iaTF100, iaTF012, List.mem_cons, List.not_mem_nil, or_false] at hk
  subst hk
  rw [hasText, string_any_toList]
  decide

/-- 環境の前提を破る [Spec] の入力: MD-1 を破るマスタ。 -/
def iaTFbad : Spec.Fare.TotalFareInput := ⟨Seed.config, badMasterData, [], []⟩

/-- ABS-004 の義務の束。 -/
@[obligation "ABS-004"]
theorem totalFareAdequate :
    Machine.Adequate (((Spec.Fare.totalFareMachine.restrict dev_D001T).restrict dev_D002T).restrict dev_D012)
      (totalFareConcrete.restrict dev_D027TF) glueTF () envTF where
  refines := totalFareRefines
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
theorem totalFareCommutes {ic : TotalFareInput} {ia : Spec.Fare.TotalFareInput} (hα : aiTF ic = some ia)
    (hv : envTF ia) :
    ∀ r, totalFareConcrete.step () ic r → ∃ oc, r = .ok ((), oc) ∧
      natOfJ32 oc = some ((Spec.Fare.totalFareOfKeys ia.cfg ia.md ia.flights ia.ages).getD 0) := by
  intro r hr
  obtain ⟨-, h⟩ := totalFareRefines.complete_fun
    (f := fun i => (Spec.Fare.totalFareOfKeys i.cfg i.md i.flights i.ages).getD 0)
    (by intro _ _ _ _ h; exact h) (s := ()) (t := ()) trivial (Or.inl ⟨rfl, trivial⟩) hα
    (totalFareAdequate.total () ia trivial hv) ⟨trivial, by unfold dev_D027TF; rw [hα]; rfl⟩
  obtain ⟨_, oc, rfl, -, ho⟩ := h r hr
  rcases ho with ho | ho
  · exact ⟨oc, rfl, ho⟩
  · exact ho.elim

end Fare

end Abstraction
