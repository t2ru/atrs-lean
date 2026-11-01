import SourceModel.Gfw.CodeList
import SourceModel.Config.App.AtrsCodeListConfig
import SourceModel.Domain.Common.Codelist.AirportCodeList
import Spec.CodeList

/-!
# Abstraction.MasterData.CodeList

空港コードリスト（`AirportCodeList.retrieveMap`）と [Spec] の `CodeList.insertNop` の一致。
空港コードが一意で、区切り行のコード `NOP` を使わなければ、`LinkedHashMap` の `put` は行を末尾に足すだけなので、
原典の値は、`displayOrder ≥ 100` の最初の行の前に区切り行を入れた列になる。行の並びは問わない
（並びを [Spec] の整列に合わせるのは、スキルの `LangSemantics.Sql.QueryLemmas`）。
-/

namespace Abstraction.MasterData.CodeList
open LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java SourceModel.Db.Schema SourceModel.Gfw.CodeList SourceModel.Config.App
  SourceModel.Config.App.AtrsCodeListConfig SourceModel.Domain.Common.Codelist

/-- 空港の行の、[Spec] の空港（コード・名前・表示順）。 -/
def airportOf (r : AirportRow) : Spec.MasterData.Airport := ⟨⟨r.airportCd.val⟩, r.airportName.val, r.displayOrder.val.toNat⟩

/-- コードリストの要素を、原典の（コード, 表示）の組に。 -/
def CodeEntry.toPair (e : Spec.CodeList.CodeEntry) : String × String := (e.code, e.label)

/-- `AirportCodeList.retrieveMap` の 1 行の処理（既定の設定）。 -/
def airportStep (acc : JLinkedHashMap String String × Bool) (r : AirportRow) : JLinkedHashMap String String × Bool :=
  let (m, nopInserted) := acc
  let (m, nopInserted) :=
    if !nopInserted && decide (100 ≤ r.displayOrder.val) then (m.put Spec.MasterData.airportNopCode "-----------", true)
    else (m, nopInserted)
  (m.put r.airportCd.val r.airportName.val, nopInserted)

theorem airport_eq_foldl (rows : List AirportRow) :
    CL_AIRPORT rows = (rows.foldl airportStep ({}, false)).1.entries := by
  unfold CL_AIRPORT AirportCodeList.afterPropertiesSet
  simp only [List.foldl_map]
  congr 3
  funext acc r
  obtain ⟨m, b⟩ := acc
  have h := J32.val_ofInt_of_inRange r.displayOrder.val ⟨by
    have := r.displayOrder.property.1; simp only [J32.minValue]; omega, by
    have := r.displayOrder.property.2; simp only [J32.maxValue]; omega⟩
  have h100 : (J32.ofInt 100).val = 100 := by decide
  simp only [airportStep, h, h100]
  rfl

/-- 区切り行を入れた後は、各行を末尾に足すだけ。 -/
theorem foldl_airportStep_true (rows : List AirportRow) (m : JLinkedHashMap String String)
    (h : (m.entries.map Prod.fst ++ rows.map (·.airportCd.val)).Nodup) :
    (rows.foldl airportStep (m, true)).1.entries = m.entries ++ rows.map fun r => (r.airportCd.val, r.airportName.val) := by
  induction rows generalizing m with
  | nil => simp
  | cons r rows ih =>
    have hr : r.airportCd.val ∉ m.entries.map Prod.fst := fun hm =>
      (List.nodup_append.mp h).2.2 _ hm _ (by simp) rfl
    have hs : airportStep (m, true) r = (m.put r.airportCd.val r.airportName.val, true) := by
      simp [airportStep]
    rw [List.foldl_cons, hs, ih, JHashMap.put_entries_of_not_mem _ hr]
    · simp
    · rw [JHashMap.put_entries_of_not_mem _ hr]
      simpa using h

/-- 区切り行を入れる前: 原典の値は、[Spec] の `insertNop` の列を末尾に足したもの。 -/
theorem foldl_airportStep_false (rows : List AirportRow) (m : JLinkedHashMap String String)
    (h : (m.entries.map Prod.fst ++ Spec.MasterData.airportNopCode :: rows.map (·.airportCd.val)).Nodup) :
    (rows.foldl airportStep (m, false)).1.entries =
      m.entries ++ (Spec.CodeList.insertNop (rows.map airportOf)).map CodeEntry.toPair := by
  induction rows generalizing m with
  | nil => simp [Spec.CodeList.insertNop]
  | cons r rows ih =>
    have hr : r.airportCd.val ∉ m.entries.map Prod.fst := fun hm =>
      (List.nodup_append.mp h).2.2 _ hm _ (by simp) rfl
    have hn : Spec.MasterData.airportNopCode ∉ m.entries.map Prod.fst := fun hm =>
      (List.nodup_append.mp h).2.2 _ hm _ (by simp) rfl
    have hrn : r.airportCd.val ≠ Spec.MasterData.airportNopCode := by
      intro e
      have := (List.nodup_append.mp h).2.1
      simp only [List.map_cons, List.nodup_cons, List.mem_cons, List.mem_map, not_or] at this
      exact this.1.1 e.symm
    by_cases h100 : 100 ≤ r.displayOrder.val
    · have hs : airportStep (m, false) r =
          ((m.put Spec.MasterData.airportNopCode "-----------").put r.airportCd.val r.airportName.val, true) := by
        simp [airportStep, h100]
      have hn' : r.airportCd.val ∉ (m.put Spec.MasterData.airportNopCode "-----------").entries.map Prod.fst := by
        rw [JHashMap.put_entries_of_not_mem _ hn]
        simpa [hrn] using hr
      rw [List.foldl_cons, hs, foldl_airportStep_true, JHashMap.put_entries_of_not_mem _ hn',
        JHashMap.put_entries_of_not_mem _ hn]
      · have : Spec.CodeList.airportNopInsertOrder ≤ r.displayOrder.val.toNat := by
          simp only [Spec.CodeList.airportNopInsertOrder]; omega
        simp [Spec.CodeList.insertNop, this, CodeEntry.toPair, Spec.CodeList.airportNop, airportOf, Function.comp_def]
      · rw [JHashMap.put_entries_of_not_mem _ hn', JHashMap.put_entries_of_not_mem _ hn]
        simp [List.nodup_append, List.nodup_cons] at h ⊢
        exact h
    · have hs : airportStep (m, false) r = (m.put r.airportCd.val r.airportName.val, false) := by
        simp [airportStep, h100]
      rw [List.foldl_cons, hs, ih, JHashMap.put_entries_of_not_mem _ hr]
      · have : ¬ Spec.CodeList.airportNopInsertOrder ≤ r.displayOrder.val.toNat := by
          simp only [Spec.CodeList.airportNopInsertOrder]; omega
        simp [Spec.CodeList.insertNop, this, CodeEntry.toPair, airportOf]
      · rw [JHashMap.put_entries_of_not_mem _ hr]
        simp [List.nodup_append, List.nodup_cons] at h ⊢
        obtain ⟨h1, ⟨⟨-, hB⟩, hC, hD⟩, hE⟩ := h
        exact ⟨h1, ⟨⟨hrn, hC⟩, hB, hD⟩, fun a x hx => ⟨(hE a x hx).2.1, (hE a x hx).1, (hE a x hx).2.2⟩⟩

/-- `CL_AIRPORT`: 空港コードが一意で、`NOP` を使わなければ、原典の値は [Spec] の `insertNop` に一致する。 -/
theorem airport_eq_insertNop (rows : List AirportRow) (hnd : (rows.map (·.airportCd.val)).Nodup)
    (hnop : ∀ r ∈ rows, r.airportCd.val ≠ Spec.MasterData.airportNopCode) :
    CL_AIRPORT rows = (Spec.CodeList.insertNop (rows.map airportOf)).map CodeEntry.toPair := by
  rw [airport_eq_foldl, foldl_airportStep_false]
  · rfl
  · refine List.nodup_cons.mpr ⟨?_, hnd⟩
    simp only [List.mem_map, not_exists, not_and]
    exact fun r hr e => hnop r hr e

/-- `JdbcCodeList.retrieveMap`: キーと表示が `null` でなく、キーが一意なら、値は行の（キー, 表示）の列そのもの。 -/
theorem jdbcCodeList_eq (xs : List (String × String)) (hnd : (xs.map Prod.fst).Nodup) :
    jdbcCodeList (xs.map fun e => (some e.1, some e.2)) = xs := by
  unfold jdbcCodeList
  rw [List.foldl_map]
  exact JHashMap.ofList_entries hnd

end Abstraction.MasterData.CodeList
