import Spec.Env.Config
import Spec.Env.MasterData

/-!
# 環境（設定とマスタ）（`Spec.Env`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

ATRS の各機能は、抽象状態 [`World`](World.lean)（フライト・会員・予約・採番）のほかに、**環境** を読む。
環境は次の 2 つの組 `Config × MasterData` で、どのユースケースも変更しない不変の入力である（`World` には含めない）。

- 設定 [`Config`](Env/Config.lean): 照会可能日数・小児運賃の割合・年齢の下限など、配備で決まる値。
- マスタ [`MasterData`](Env/MasterData.lean): 空港・区間・便・搭乗クラス・運賃種別・ピーク時期・機材・カード種別。
  画面用のコードリストは [`Spec.Env.CodeList`](Env/CodeList.lean) がマスタから作る。

各機能の機械の入力は、環境を生の型（`Config`・`MasterData`）のまま受け取り、境界で検証する。

- `validate`: 設定の不変条件とマスタの不変条件 MD-1〜MD-8 を満たせば、その証明を添えた検証済みの値 `ValidEnv` を返し、
  満たさなければ無し（`none`）を返す。
- `masterConfigOk`: 入口の環境の前提。環境の検証が成功することである。各機能の事前条件（PRE）はこれを含み、
  前提を満たさない環境での振る舞いは仕様の外になる（[Source] の振る舞いは参考として記録する。
  [`Spec.Env.MasterData`](Env/MasterData.lean#不変条件spec)）。
- `validB`: 同じ検査を真偽値で計算する関数と、その正しさ `validB_sound`（大きなマスタでも、カーネルの評価で前提を
  確かめられるようにするための道具）。

シードの設定とマスタが前提を満たすこと（`seed_env`）と、前提を破る例は [`Spec.Seed`](Seed.lean) にある。
-/

namespace Spec.Env
open Spec.Model


/-!
## 検証済みの設定とマスタ

設定とマスタは、機械の入力では生の型（`Config`・`MasterData`）のままにし、境界で検証する。
環境の前提は「検証が成功すること」である。
-/

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
  spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec"]
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


/-!
## 真偽値の検査

`validB` は、`MasterData.Valid` と同じ条件を真偽値で計算する。一意性は、鍵（空港コード・便名・機材の型式は文字列の鍵
`strKey`）が真に増加していれば隣どうしの比較だけで確かめ（線形時間）、そうでなければ定義どおりに確かめる。
-/

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

/-! ## 性質（検査の正しさ） -/

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

end Spec.Env

/-!
## 根拠と対応

- 根拠: [ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)（境界で検証する型 `ValidEnv`）、
  [ADR cd33](../../docs/decision/cd33-spec-nondet-types-and-env-pre.md)（入口の環境の前提）、
  [ADR 70eb](../../docs/decision/70eb-refinement-non-vacuity-obligations.md)（環境の前提の付帯の義務。SPEC-006）
- 既知差異: 前提を満たさない環境での [Source] の振る舞いは
  [abstraction.md](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)
- シードが前提を満たすこと: [`Spec.Seed`](Seed.lean)
-/
