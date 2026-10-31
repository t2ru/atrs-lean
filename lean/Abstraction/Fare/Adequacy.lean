import Abstraction.Fare.BasicFareRun
import Abstraction.Fare.FareRun
import Abstraction.Fare.TotalFareRun

/-!
# Abstraction.Fare.Adequacy

ABS-001・ABS-002・ABS-004（運賃計算）の義務の束（`Abstraction.Fare` の `*Adequate`）の部品: 環境の前提 `env*` と、その証人（前提を満たす [Source] の入力、前提を破る [Spec] の入力）。
環境の前提は、マスタ・設定の妥当性（`Spec.EnvPre.masterConfigOk`）と、入力の値域、差異の前提の述語を、[Spec] の入力の成分だけで書いたものである。
入口の R 課題ではないので `@[env_pre]` は付けない。
-/

namespace Abstraction.Fare.Adequacy

open Machine Spec LangSemantics.Core Spec.EnvPre Spec.Model Spec.Prim.Text LangSemantics.Core.List LangSemantics.Java.IntLemmas LangSemantics.Java.Int Abstraction.Fare.Alpha Abstraction.Fare.TotalAlpha
open SourceModel.FareQuery

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

end Abstraction.Fare.Adequacy
