import LangSemantics.Java.HashMap
import LangSemantics.Core.List

/-!
# LangSemantics.Java.HashMap.Lemmas

`JHashMap` の性質。キーが重複しない列を順に `put` した表は、その列そのものであり（`ofList_entries`）、
`get` は列の `find?` に一致する（`get_ofList`）。`LinkedHashMap` の反復の順は、`put` した順である。
-/

namespace LangSemantics.Java.HashMap
open LangSemantics.Core.List

namespace JHashMap

open LangSemantics.Core

variable {κ υ : Type} [DecidableEq κ]

theorem containsKey_eq_false {m : JHashMap κ υ} {k : κ} (h : k ∉ m.entries.map Prod.fst) :
    m.containsKey k = false := by
  simp only [containsKey, List.any_eq_false, beq_iff_eq]
  intro e he hk
  exact h (List.mem_map.mpr ⟨e, he, hk⟩)

/-- 無いキーの `put` は、末尾に足す。 -/
theorem put_entries_of_not_mem {m : JHashMap κ υ} {k : κ} (v : υ) (h : k ∉ m.entries.map Prod.fst) :
    (m.put k v).entries = m.entries ++ [(k, v)] := by
  simp [put, containsKey_eq_false h]

/-- 表 `m` にキーが無い列を順に `put` すると、末尾に順に足される。 -/
theorem foldl_put_entries (xs : List (κ × υ)) (m : JHashMap κ υ)
    (h : (m.entries.map Prod.fst ++ xs.map Prod.fst).Nodup) :
    (xs.foldl (fun m e => m.put e.1 e.2) m).entries = m.entries ++ xs := by
  induction xs generalizing m with
  | nil => simp
  | cons x xs ih =>
    have hx : x.1 ∉ m.entries.map Prod.fst := by
      intro hm
      exact (List.nodup_append.mp h).2.2 _ hm _ (by simp) rfl
    simp only [List.foldl_cons]
    rw [ih, put_entries_of_not_mem _ hx]
    · simp
    · rw [put_entries_of_not_mem _ hx]
      simpa using h

/-- キーが重複しない列の `ofList` は、その列そのもの（`LinkedHashMap` の反復の順は `put` の順）。 -/
theorem ofList_entries {xs : List (κ × υ)} (h : (xs.map Prod.fst).Nodup) : (ofList xs).entries = xs := by
  have := foldl_put_entries xs empty (by simpa [empty] using h)
  simpa [ofList, empty] using this

/-- キーが重複しない列の `ofList` の `get` は、列でキーを探した結果。 -/
theorem get_ofList {xs : List (κ × υ)} (h : (xs.map Prod.fst).Nodup) (k : κ) :
    (ofList xs).get k = (xs.find? fun e => e.1 == k).map (·.2) := by
  simp [get, ofList_entries h]

/-- 並べ替えの `ofList` の `get` は、元の行での検索の写し（キーが重複しないとき）。 -/
theorem get_ofList_perm {ρ σ κ υ : Type} [DecidableEq κ] {rows : List ρ} {o : List σ} {proj : ρ → σ}
    (hp : o.Perm (rows.map proj)) {key : σ → κ} {val : σ → υ} (hnd : (rows.map (key ∘ proj)).Nodup) (k : κ) :
    (ofList (o.map fun b => (key b, val b))).get k =
      (rows.find? fun r => key (proj r) == k).map (val ∘ proj) := by
  have hnd' : ((o.map fun b => (key b, val b)).map Prod.fst).Nodup := by
    rw [List.map_map]
    have : (o.map (Prod.fst ∘ fun b => (key b, val b))) = o.map key := rfl
    rw [this]
    exact (hp.map key).nodup_iff.mpr (by rw [List.map_map]; exact hnd)
  rw [get_ofList hnd', List.find?_map]
  have e : (o.find? ((fun e : κ × υ => e.1 == k) ∘ fun b => (key b, val b))) = o.find? (fun b => key b == k) := rfl
  rw [e, find?_perm hp]
  · rw [List.find?_map, Option.map_map, Option.map_map]
    rfl
  · intro a ha b hb ea eb
    simp only [beq_iff_eq] at ea eb
    have ha' := (hp.mem_iff).mp ha
    have hb' := (hp.mem_iff).mp hb
    obtain ⟨ra, hra, rfl⟩ := List.mem_map.mp ha'
    obtain ⟨rb, hrb, rfl⟩ := List.mem_map.mp hb'
    rw [inj_of_nodup_map (f := key ∘ proj) hnd hra hrb (by simp only [Function.comp, ea, eb])]

end JHashMap

end LangSemantics.Java.HashMap
