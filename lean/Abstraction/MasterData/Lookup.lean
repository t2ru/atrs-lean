import Abstraction.MasterData.Pre

/-!
# Abstraction.MasterData.Lookup

Provider のキャッシュ（`JHashMap`）の参照と、[Spec] の検索の対応。Mapper の結果の並び `o` は、
DB の行を写した列の並べ替えである。キーが重複しなければ、`get` はどの並びでも、DB の行での検索の写しになる。
-/

namespace Abstraction.MasterData

open LangSemantics.Java Abstraction.Prim

/-- キャッシュの参照: 並べ替えの `ofList` の `get` は、元の行での検索の写し。 -/
theorem get_ofList_perm {ρ σ κ υ : Type} [DecidableEq κ] {rows : List ρ} {o : List σ} {proj : ρ → σ}
    (hp : o.Perm (rows.map proj)) {key : σ → κ} {val : σ → υ} (hnd : (rows.map (key ∘ proj)).Nodup) (k : κ) :
    (JHashMap.ofList (o.map fun b => (key b, val b))).get k =
      (rows.find? fun r => key (proj r) == k).map (val ∘ proj) := by
  have hnd' : ((o.map fun b => (key b, val b)).map Prod.fst).Nodup := by
    rw [List.map_map]
    have : (o.map (Prod.fst ∘ fun b => (key b, val b))) = o.map key := rfl
    rw [this]
    exact (hp.map key).nodup_iff.mpr (by rw [List.map_map]; exact hnd)
  rw [JHashMap.get_ofList hnd', List.find?_map]
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

end Abstraction.MasterData
