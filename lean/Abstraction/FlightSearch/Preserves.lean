import Abstraction.FlightSearch.Witness
import Spec.EnvPre

/-!
# Abstraction.FlightSearch.Preserves

ABS-011（空席照会）の束 `Machine.Preserves`（`Abstraction.FlightSearch.searchPreserves`）の部品: 環境の前提 `envFS`、
その証人（前提を満たす [Source] の入力、前提を破る [Spec] の入力）、選択の像の材料 `chFS`。
環境の前提は、マスタ・設定の妥当性（`Spec.EnvPre.masterConfigOk`）と、照会の搭乗クラス・空港コード・便マスタの便名の
条件、差異の前提の述語を、[Spec] の入力の成分だけで書いたものである。入口の R 課題ではないので `@[env_pre]` は付けない。
-/

namespace Abstraction.FlightSearch.Preserves
open Machine Spec Spec.EnvPre Spec.FlightSearch Spec.Prim.Text Abstraction.FlightSearch.Alpha
  Abstraction.FlightSearch.Witness

/-- ABS-011 の環境の前提。 -/
def envFS (i : Spec.FlightSearch.SearchInput) : Prop :=
  masterConfigOk (i.cfg, i.md) ∧ (i.md.boardingClassOf i.criteria.boardingClassCd).isSome = true ∧
    hasText i.criteria.depAirportCd.val = true ∧ hasText i.criteria.arrAirportCd.val = true ∧
    FlightNamesHaveText i.md ∧ dev_D001S i ∧ dev_D002S i

theorem aiS_icFS_comma : aiS (icFS ',') = some iaFS := by decide

theorem envFS_iaFS : envFS iaFS := by
  obtain ⟨hc, hv, hb, hd, ha, hn⟩ := iaFS_pre
  obtain ⟨h1, h2⟩ := iaFS_devs
  exact ⟨⟨hc, hv⟩, hb, hd, ha, hn, h1, h2⟩

/-- 環境の前提を破る [Spec] の入力: MD-1 を破るマスタ。 -/
def iaFSbad : Spec.FlightSearch.SearchInput :=
  ⟨Seed.config, badMasterData, Abstraction.Fare.TotalAlpha.day0, iaFS.criteria⟩

/-- 選択の像の材料（基底の `searchStep`・標準の環境 `()`、`@[std_abs]` の `ceFS`）。自由な選択は `Unit`。 -/
def chFS : Machine.Preserves.Choice Spec.Port.World Spec.FlightSearch.SearchInput Spec.FlightSearch.SearchOutput
    SourceModel.FlightSearch.SearchInput :=
  ⟨Unit, Unit, Spec.Port.World × Spec.FlightSearch.SearchOutput, searchStep, ceFS, (), fun r => r⟩

end Abstraction.FlightSearch.Preserves
