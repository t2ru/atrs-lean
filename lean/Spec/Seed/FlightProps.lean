import Spec.Seed
import Spec.Seed.Flight

/-!
# Spec.Seed.FlightProps

シードのフライト `Spec.Seed.Flight.flights` の性質（backlog 0be7 の第 2 段）。全件（15 万行）には展開せず、
生成の形（日付の列 × 便名の列 × 枠の列）から示す。

- `flights_nodup`: 主キーで一意（`World` の証明フィールド `flights_nodup`。ADR 6d36 の L3）。日付・便名・枠の列が
  それぞれ重複しないことから従う。`Spec.Seed.World.world` が、これで `World` を組み立てる。
- `flights_refMaster`: 参照整合性（`World.RefMaster` の中身。シードのマスタに対して）。便名・枠の列がマスタにあることから
  従う。`World` についての主張は `Spec.Seed.World.world_refMaster`。
-/

namespace Spec.Seed.FlightProps
open Spec.Model Spec.Prim Spec.Seed.Flight

/-- `zip` は、左の列の上の関係 `R` の `Pairwise` を、組の左の成分について保つ。 -/
theorem pairwise_zip_fst {α β : Type} {R : α → α → Prop} :
    ∀ {l : List α} {m : List β}, l.Pairwise R → (l.zip m).Pairwise (fun a b => R a.1 b.1)
  | [], _, _ => by simp
  | _ :: _, [], _ => by simp
  | a :: l, b :: m, h => by
    rw [List.pairwise_cons] at h
    simp only [List.zip_cons_cons, List.pairwise_cons]
    exact ⟨fun p hp => h.1 _ (List.of_mem_zip hp).1, pairwise_zip_fst h.2⟩

theorem days_nodup : days.Nodup := by decide +kernel
theorem names_nodup : names.Nodup := by decide +kernel
theorem slots_nodup : slots.Nodup := by decide +kernel

/-- 1 日分のフライトの各行は、その日の、便名の列・枠の列にある便名・枠の行である。 -/
theorem mem_dayFlights {d : Date} {vs : List (List Nat)} {x : Flight} (h : x ∈ dayFlights d vs) :
    x.key.departureDate = d ∧ x.key.flightName ∈ names ∧ (x.key.boardingClassCd, x.key.fareTypeCd) ∈ slots := by
  unfold dayFlights at h
  simp only [List.mem_flatMap, List.mem_map] at h
  obtain ⟨⟨n, row⟩, hz, ⟨⟨b, f⟩, v⟩, hz2, rfl⟩ := h
  exact ⟨rfl, (List.of_mem_zip hz).1, (List.of_mem_zip hz2).1⟩

/-- シードの各フライトは、日付の列・便名の列・枠の列にある日付・便名・枠の行である。 -/
theorem mem_flights {x : Flight} (h : x ∈ flights) :
    x.key.departureDate ∈ days ∧ x.key.flightName ∈ names ∧ (x.key.boardingClassCd, x.key.fareTypeCd) ∈ slots := by
  simp only [flights, List.mem_flatMap] at h
  obtain ⟨⟨d, i⟩, hd, hx⟩ := h
  obtain ⟨e1, e2, e3⟩ := mem_dayFlights hx
  refine ⟨?_, e2, e3⟩
  rw [e1, ← List.zipIdx_map_fst 0 days]
  exact List.mem_map_of_mem (f := Prod.fst) hd

/-- 1 日分のフライトのキーは互いに異なる。 -/
theorem dayKeys_pairwise (d : Date) (vs : List (List Nat)) :
    ((dayFlights d vs).map (·.key)).Pairwise (· ≠ ·) := by
  unfold dayFlights
  rw [List.map_flatMap, List.pairwise_flatMap]
  constructor
  · intro ⟨n, row⟩ _
    rw [List.map_map, List.pairwise_map]
    refine (pairwise_zip_fst (m := row) (List.nodup_iff_pairwise_ne.mp slots_nodup)).imp ?_
    intro ⟨⟨b, f⟩, v⟩ ⟨⟨b', f'⟩, v'⟩ hne heq
    simp only [Function.comp, FlightKey.mk.injEq] at heq
    exact hne (by rw [heq.2.2.1, heq.2.2.2])
  · refine (pairwise_zip_fst (m := vs) (List.nodup_iff_pairwise_ne.mp names_nodup)).imp ?_
    intro ⟨n, row⟩ ⟨n', row'⟩ hne x hx y hy hxy
    simp only [List.mem_map] at hx hy
    obtain ⟨_, ⟨⟨⟨b, f⟩, v⟩, _, rfl⟩, rfl⟩ := hx
    obtain ⟨_, ⟨⟨⟨b', f'⟩, v'⟩, _, rfl⟩, rfl⟩ := hy
    simp only [FlightKey.mk.injEq] at hxy
    exact hne hxy.2.1

/-- シードのフライトは主キーで一意である（`World` の証明フィールド `flights_nodup`）。 -/
theorem flights_nodup : (flights.map (·.key)).Nodup := by
  rw [List.nodup_iff_pairwise_ne]
  simp only [flights, List.map_flatMap, List.pairwise_flatMap]
  refine ⟨fun ⟨d, i⟩ _ => dayKeys_pairwise d (pattern i), ?_⟩
  have hdays : (days.zipIdx).Pairwise (fun a b => a.1 ≠ b.1) := by
    have := List.nodup_iff_pairwise_ne.mp days_nodup
    rw [← List.zipIdx_map_fst 0 days, List.pairwise_map] at this
    exact this
  refine hdays.imp ?_
  intro ⟨d, i⟩ ⟨d', i'⟩ hne x hx y hy hxy
  simp only [List.mem_map] at hx hy
  obtain ⟨fx, hfx, rfl⟩ := hx
  obtain ⟨fy, hfy, rfl⟩ := hy
  exact hne ((mem_dayFlights hfx).1.symm.trans (hxy ▸ (mem_dayFlights hfy).1))

theorem names_in_master : ∀ n ∈ names, ∃ m ∈ Spec.Seed.masterData.flightMasters, m.flightName = n := by
  decide +kernel

theorem slots_in_master : ∀ s ∈ slots, (∃ b ∈ Spec.Seed.masterData.boardingClasses, b.boardingClassCd = s.1) ∧
    (∃ t ∈ Spec.Seed.masterData.fareTypes, t.fareTypeCd = s.2) := by
  decide +kernel

/-- シードのフライトは、シードのマスタを参照する（`World.RefMaster` の中身。FK_FLIGHT_1〜3）。 -/
theorem flights_refMaster : ∀ x ∈ flights,
    (∃ m ∈ Spec.Seed.masterData.flightMasters, m.flightName = x.key.flightName) ∧
    (∃ b ∈ Spec.Seed.masterData.boardingClasses, b.boardingClassCd = x.key.boardingClassCd) ∧
    (∃ t ∈ Spec.Seed.masterData.fareTypes, t.fareTypeCd = x.key.fareTypeCd) := by
  intro x hx
  obtain ⟨_, hn, hs⟩ := mem_flights hx
  exact ⟨names_in_master _ hn, (slots_in_master _ hs).1, (slots_in_master _ hs).2⟩

end Spec.Seed.FlightProps
