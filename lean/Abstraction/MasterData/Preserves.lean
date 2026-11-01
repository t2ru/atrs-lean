import Abstraction.Fare.TotalAlpha
import Abstraction.MasterData.QueryRun

/-!
# Abstraction.MasterData.Preserves

ABS-026（マスタ・設定・コードリストの読み込み）の束 `Machine.Preserves`（`Abstraction.MasterData` の `*Preserves`）の部品: 環境の前提 `env*` と、その証人（前提を満たす [Source] の入力、前提を破る [Spec] の入力）。
環境の前提は、マスタ・設定の妥当性（`Spec.EnvPre.masterConfigOk`）と、入力の値域、差異の前提の述語を、[Spec] の入力の成分だけで書いたものである。
入口の R 課題ではないので `@[env_pre]` は付けない。
-/

namespace Abstraction.MasterData.Preserves

open Machine Spec Spec.EnvPre Abstraction.MasterData.Alpha
open SourceModel.MasterQuery

/-- ABS-026 の環境の前提: マスタ・設定の妥当性と、問い合わせの値域。 -/
def envMQ (i : Config × Spec.MasterData × Spec.MasterQuery.Query) : Prop :=
  masterConfigOk (i.1, i.2.1) ∧ i.2.2.Valid

/-- 前提を満たす [Source] の入力: `Abstraction.Fare.TotalAlpha.dbTF` の DB（空港 2・区間 1・便 1）、上流の設定、設定の参照。 -/
def icMQ : SrcInput :=
  { db := Abstraction.Fare.TotalAlpha.dbTF ⟨100, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩,
    config := SourceModel.AtrsProperties.upstreamConfig, query := .config }

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

end Abstraction.MasterData.Preserves
