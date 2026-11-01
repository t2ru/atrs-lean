import Abstraction.Fare.Factors
import Abstraction.MasterData.QueryRun
import SourceModel.FareQuery

/-!
# Abstraction.Fare.Alpha

運賃計算の R 課題（ABS-001・ABS-002）の標準の抽象化 α と、前提型の差異の述語。

- 入力の α: 基本運賃は、ABS-026 の `configOf`・`masterDataOf` と、引数の `natOfJ32`・`dateOfJ`（`null` には定義しない）。
  運賃は、引数の `natOfJ32`。
- 状態の β は `betaMQ`（どちらも状態を持たない）、出力の α は `natOfJ32`。
- 差異: D-027（具体側の入力が [Spec] の型で表せる）、D-001・D-002（安全でない因子の一覧で書く。
  `Abstraction.Fare.Factors`。ADR e9bc）。
-/

namespace Abstraction.Fare.Alpha
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.Fare.Factors Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Lookup
  Spec.CodeList
open LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open Machine.Preserves (never always anyOf
  Covers Covers₂ Nontrivial Nontrivial₂
  KernelIs)

open Machine LangSemantics.Core SourceModel.FareQuery

/-! ## 入力（合成） -/

/-- 基本運賃の入力: 設定・マスタ・引数。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiBF (ic : BasicFareInput) : Option Spec.Fare.BasicFareInput :=
  (configOf ic.config).bind fun cfg => (masterDataOf ic.db).bind fun md =>
    (natOfJ32 ic.basicFareOfRoute).bind fun b => ic.boardingClassCd.bind fun cd =>
      (ic.depDate.bind dateOfJ).map fun d => ⟨cfg, md, b, cd, d⟩

/-- 運賃の入力: 引数。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiF (ic : FareInput) : Option Spec.Fare.FareInput :=
  (natOfJ32 ic.basicFare).bind fun b => (natOfJ32 ic.discountRate).map fun r => ⟨b, r⟩

/-- 基本運賃の標準の貼り合わせ。 -/
abbrev glueBF := Glue.ofStd betaMQ (fun _ => True) aiBF natOfJ32

/-- 運賃の標準の貼り合わせ。 -/
abbrev glueF := Glue.ofStd betaMQ (fun _ => True) aiF natOfJ32

/-! ## 前提型の差異 -/

/-- D-027（基本運賃）: 具体側の入力（DB のマスタ・設定・引数）が [Spec] の型で表せる。 -/
@[deviation "D-027"]
def dev_D027BF (ic : BasicFareInput) : Prop := (aiBF ic).isSome = true

/-- D-027（運賃）: 引数が [Spec] の型で表せる（負でない）。 -/
@[deviation "D-027"]
def dev_D027F (ic : FareInput) : Prop := (aiF ic).isSome = true

/-- D-001: `x = routeBasicFare + extraCharge`・`c` = 出発日の積算比率として、`x·c` が 100 で割り切れないか、
`c` が安全でない積算比率の一覧に無い。 -/
@[deviation "D-001"]
def dev_D001 (i : Spec.Fare.BasicFareInput) : Prop :=
  match i.md.boardingClassOf i.boardingClassCd with
  | some bc =>
    (i.routeBasicFare + bc.extraCharge) * i.md.multiplicationRatioOn i.depDate % 100 ≠ 0 ∨
      i.md.multiplicationRatioOn i.depDate ∉ unsafeBasicRatios
  | none => True

/-- D-002: `b·(100−r)` が 10000 で割って 100 余らないか、`r` が安全でない割引率の一覧に無い。 -/
@[deviation "D-002"]
def dev_D002 (i : Spec.Fare.FareInput) : Prop :=
  i.basicFare * (100 - i.discountRate) % 10000 ≠ 100 ∨ i.discountRate ∉ unsafeDiscountRates

/-! ## 例（差異の述語の非自明性と、W 課題の証人） -/

/-- 搭乗クラス N（加算料金 0）と、1970-01-01 の 1 日だけ積算比率 29% のピーク時期を持つ DB。 -/
def db29 : SourceModel.Db.Schema.MasterDb :=
  { boardingClass := [⟨⟨"N", by decide⟩, some ⟨"N", by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩⟩],
    peakTime := [⟨⟨"P", by decide⟩, ⟨0, by decide⟩, ⟨0, by decide⟩, ⟨29, by decide⟩⟩] }

/-- D-001 の差異が起きる入力: 区間の運賃 100 円・搭乗クラス N・1970-01-01（積算比率 29%）。 -/
def icBF29 : BasicFareInput :=
  { db := db29, config := SourceModel.AtrsProperties.upstreamConfig, basicFareOfRoute := J32.ofInt 100,
    boardingClassCd := some .N, depDate := some ⟨1970, 1, 1⟩ }

/-- 前提を満たさない入力: 搭乗クラスが `null`。 -/
def icBFnull : BasicFareInput := { icBF29 with boardingClassCd := none }

/-- D-002 の差異が起きる入力: 基本運賃 1430 円・割引率 30%。 -/
def icF1430 : FareInput := ⟨J32.ofInt 1430, J32.ofInt 30⟩

theorem dev_D027BF_nontrivial : Nontrivial dev_D027BF :=
  ⟨⟨icBF29, by unfold dev_D027BF; decide⟩, ⟨icBFnull, by unfold dev_D027BF; decide⟩⟩

theorem dev_D027F_nontrivial : Nontrivial dev_D027F :=
  ⟨⟨icF1430, by unfold dev_D027F; decide⟩, ⟨⟨J32.ofInt (-1), J32.ofInt 0⟩, by unfold dev_D027F; decide⟩⟩

instance : DecidablePred dev_D001 := fun i => by unfold dev_D001; split <;> infer_instance

instance : DecidablePred dev_D002 := fun i => by unfold dev_D002; infer_instance

/-- `icBF29` の像は [Spec] の PRE を満たし、D-001 の前提を破る。 -/
theorem aiBF_icBF29 : ∃ ia, aiBF icBF29 = some ia ∧ ia.Pre ∧ ¬ dev_D001 ia := by
  have h : (aiBF icBF29).any (fun ia => decide ia.Pre && !decide (dev_D001 ia)) = true := by decide
  cases he : aiBF icBF29 with
  | none => rw [he] at h; cases h
  | some ia =>
    rw [he] at h
    simp only [Option.any_some, Bool.and_eq_true, decide_eq_true_eq, Bool.not_eq_true',
      decide_eq_false_iff_not] at h
    exact ⟨ia, rfl, h.1, h.2⟩

theorem dev_D001_nontrivial : Nontrivial dev_D001 := by
  obtain ⟨ia, -, -, hn⟩ := aiBF_icBF29
  refine ⟨⟨{ ia with md := ⟨[], [], [], [], [], [], [], []⟩ }, ?_⟩, ⟨ia, hn⟩⟩
  unfold dev_D001
  simp only [Spec.MasterData.boardingClassOf, List.find?_nil]

theorem dev_D002_nontrivial : Nontrivial dev_D002 :=
  ⟨⟨⟨0, 0⟩, by unfold dev_D002; decide⟩, ⟨⟨1430, 30⟩, by unfold dev_D002; decide⟩⟩

end Abstraction.Fare.Alpha
