import Spec.Seed

/-!
# Spec.EnvPre

入口の環境の前提（`@[env_pre]`。ADR 70eb の SPEC-006）。入口の機械（画面・REST・レポート要求の受信）の
`TotalUnder` の `Env` は、入力から設定とマスタを射影して `masterConfigOk` を課し、各機能の入力の値域の述語と組み合わせて作る
（入力の値域の述語は、入口の機械を作る各機能の backlog で置く）。

- `ValidEnv`・`validate`: 検証済みの設定とマスタと、境界の検証（`validate_sound`・`validate_complete`・`validate_isSome_iff`）。
- `masterConfigOk`: 検証が成功すること（設定の不変条件と、マスタの不変条件 MD-1〜MD-8）。
- `validB`: カーネルの評価で進む真偽値の検査（文字列は `toList` で見る。一意性は、鍵が真に増加していれば線形時間で
  確かめる）と、その正しさ `validB_sound`。
- `seed_env`: シードの設定とマスタ（`Spec.Seed`）は、環境の前提を満たす。
-/

namespace Spec.EnvPre
open Spec.Model


/-! ## 検証済みの設定とマスタ

設定とマスタは、機械の入力では生の型（`Config`・`MasterData`）のままにし、境界で検証する（ADR 6d36 の L3）。
環境の前提は「検証が成功すること」である。 -/

/-- 検証済みの設定とマスタ: 設定の不変条件と MD-1〜MD-8 の証明を持つ。 -/
structure ValidEnv where
  cfg : Config
  md : MasterData
  cfgOk : cfg.Valid
  mdOk : md.Valid cfg

/-- 境界の検証: 設定の不変条件と MD-1〜MD-8 を満たせば、証明を添えて返す。 -/
def validate (x : Config × MasterData) : Option ValidEnv :=
  if h : x.1.Valid ∧ x.2.Valid x.1 then some ⟨x.1, x.2, h.1, h.2⟩ else none

/-- 検証の健全性: 検証が返す値は、入力の設定とマスタそのものである（妥当性は値が持つ）。 -/
theorem validate_sound {x : Config × MasterData} {v : ValidEnv} (h : validate x = some v) :
    v.cfg = x.1 ∧ v.md = x.2 := by
  unfold validate at h
  split at h
  · cases h; exact ⟨rfl, rfl⟩
  · cases h

/-- 検証の完全性: 妥当な設定とマスタは、検証を通る。 -/
theorem validate_complete {x : Config × MasterData} (h : x.1.Valid ∧ x.2.Valid x.1) :
    validate x = some ⟨x.1, x.2, h.1, h.2⟩ := by
  unfold validate
  split
  · rfl
  · contradiction

/-- 検証が成功することと、設定とマスタが妥当であることは同値。 -/
theorem validate_isSome_iff {x : Config × MasterData} :
    (validate x).isSome = true ↔ x.1.Valid ∧ x.2.Valid x.1 := by
  unfold validate
  split
  · exact ⟨fun _ => by assumption, fun _ => rfl⟩
  · exact ⟨fun e => (nomatch e), fun _ => by contradiction⟩

/-- 入口の環境の前提: 設定とマスタの検証が成功する（設定の不変条件と、マスタの不変条件 MD-1〜MD-8）。 -/
@[env_pre "MD-1", "MD-2", "MD-3", "MD-4", "MD-5", "MD-6", "MD-7", "MD-8", "CFG",
  spec_doc "lean/Spec/MasterData.lean#不変条件spec"]
def masterConfigOk (x : Config × MasterData) : Prop := (validate x).isSome = true

instance (x : Config × MasterData) : Decidable (masterConfigOk x) := by unfold masterConfigOk; infer_instance

/-- 環境の前提から、設定とマスタの妥当性。 -/
theorem masterConfigOk.valid {x : Config × MasterData} (h : masterConfigOk x) : x.1.Valid ∧ x.2.Valid x.1 :=
  validate_isSome_iff.mp h

/-- 設定とマスタの妥当性から、環境の前提。 -/
theorem masterConfigOk.of_valid {x : Config × MasterData} (hc : x.1.Valid) (hm : x.2.Valid x.1) : masterConfigOk x :=
  validate_isSome_iff.mpr ⟨hc, hm⟩

/-- 環境の前提と、設定とマスタの妥当性は同値。 -/
theorem masterConfigOk_iff {x : Config × MasterData} : masterConfigOk x ↔ x.1.Valid ∧ x.2.Valid x.1 :=
  validate_isSome_iff


/-! ## 真偽値の検査 -/

/-- 列が真に増加する（隣どうしを比べる）。 -/
def increasing : List Nat → Bool
  | a :: b :: t => decide (a < b) && increasing (b :: t)
  | _ => true

/-- 文字列の鍵（文字の符号を 1 ずらした、底 1114112 の位取り）。長さが同じなら辞書順、短いほうが小さい。 -/
def strKey (s : String) : Nat := s.toList.foldl (fun acc c => acc * 1114112 + c.toNat + 1) 0

/-- 一意性の検査: 鍵が真に増加していれば線形時間で、そうでなければ定義どおりに確かめる。 -/
def nodupB {α : Type} [DecidableEq α] (key : α → Nat) (l : List α) : Bool :=
  increasing (l.map key) || decide l.Nodup

/-- マスタの不変条件 MD-1〜MD-8 の検査。 -/
def validB (cfg : Config) (md : MasterData) : Bool :=
  nodupB (fun c : AirportCd => strKey c.val) (md.airports.map (·.code)) &&
  decide (md.routes.map (·.routeNo)).Nodup &&
  nodupB (fun n : FlightName => strKey n.val) (md.flightMasters.map (·.flightName)) &&
  decide (md.boardingClasses.map (·.boardingClassCd)).Nodup &&
  decide (md.fareTypes.map (·.fareTypeCd)).Nodup &&
  decide (md.peakTimes.map fun p => (p.peakTimeCd, p.peakStartDate, p.peakEndDate)).Nodup &&
  nodupB strKey (md.planes.map (·.craftType)) &&
  decide (md.creditTypes.map (·.creditTypeCd)).Nodup &&
  decide (md.airports.map (·.displayOrder)).Nodup && decide (md.boardingClasses.map (·.displayOrder)).Nodup &&
  decide (md.fareTypes.map (·.displayOrder)).Nodup && decide (md.creditTypes.map (·.displayOrder)).Nodup &&
  decide md.MD2 && decide md.MD3 && decide md.MD4 && decide md.MD5 && decide md.MD6 && decide (md.MD7 cfg) &&
  md.airports.all (fun a => a.code.val != MasterData.airportNopCode) &&
  decide ((∀ r ∈ md.routes, ∀ b ∈ md.boardingClasses, r.basicFare + b.extraCharge ≤ Range.maxBasicFareWithCharge) ∧
    (∀ p ∈ md.peakTimes, p.multiplicationRatio ≤ Range.maxMultiplicationRatio) ∧
    (∀ ft ∈ md.fareTypes, ft.discountRate ≤ Range.maxDiscountRate))

/-! ## 正しさ -/

theorem increasing_cons {a : Nat} {l : List Nat} (h : increasing (a :: l) = true) :
    increasing l = true ∧ ∀ x ∈ l, a < x := by
  induction l generalizing a with
  | nil => exact ⟨rfl, by simp⟩
  | cons b t ih =>
    simp only [increasing, Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨hab, hbt⟩ := h
    obtain ⟨-, hb⟩ := ih hbt
    refine ⟨hbt, fun x hx => ?_⟩
    rcases List.mem_cons.mp hx with rfl | hx
    · exact hab
    · exact Nat.lt_trans hab (hb x hx)

theorem increasing_pairwise : ∀ {l : List Nat}, increasing l = true → l.Pairwise (· < ·)
  | [], _ => .nil
  | a :: l, h => by
    obtain ⟨hl, ha⟩ := increasing_cons h
    exact .cons ha (increasing_pairwise hl)

theorem nodup_of_map {α β : Type} {f : α → β} {l : List α} (h : (l.map f).Nodup) : l.Nodup := by
  unfold List.Nodup at *
  rw [List.pairwise_map] at h
  exact h.imp fun hne e => hne (congrArg f e)

theorem nodupB_sound {α : Type} [DecidableEq α] {key : α → Nat} {l : List α} (h : nodupB key l = true) : l.Nodup := by
  simp only [nodupB, Bool.or_eq_true, decide_eq_true_eq] at h
  rcases h with h | h
  · exact nodup_of_map ((increasing_pairwise h).imp fun hlt => Nat.ne_of_lt hlt)
  · exact h

/-- 検査の正しさ。 -/
theorem validB_sound {cfg : Config} {md : MasterData} (h : validB cfg md = true) : md.Valid cfg := by
  simp only [validB, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true, and_assoc] at h
  obtain ⟨a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, m2, m3, m4, m5, m6, m7, m8a, m8b⟩ := h
  refine ⟨⟨nodupB_sound a1, a2, nodupB_sound a3, a4, a5, a6, nodupB_sound a7, a8, a9, a10, a11, a12⟩,
    m2, m3, m4, m5, m6, m7, ⟨fun a ha => ?_, m8b⟩⟩
  have := m8a a ha
  simp only [bne_iff_ne, ne_eq] at this
  exact this


/-! ## シードと非自明性 -/

set_option maxRecDepth 100000 in
/-- シードの設定とマスタは、入口の環境の前提を満たす。 -/
theorem seed_env : masterConfigOk (Seed.config, Seed.masterData) :=
  masterConfigOk.of_valid (by decide) (EnvPre.validB_sound (by decide +kernel))

/-- 環境の前提を破る例: 空港コードの重複（MD-1）。 -/
def badMasterData : MasterData :=
  { Seed.masterData with airports := ⟨{ val := "HND" }, "x", 1000⟩ :: Seed.masterData.airports }

theorem badMasterData_not_env : ¬ masterConfigOk (Seed.config, badMasterData) := by
  intro h
  obtain ⟨-, hv⟩ := h.valid
  have h := hv.md1.1
  simp only [badMasterData, List.map_cons, List.nodup_cons] at h
  exact h.1 (by decide)

/-- G8: 環境の前提は自明でない。 -/
theorem masterConfigOk_nontrivial : Machine.Preserves.Nontrivial masterConfigOk :=
  ⟨⟨_, seed_env⟩, ⟨_, badMasterData_not_env⟩⟩

end Spec.EnvPre
