import Abstraction.Prim.List

/-!
# Abstraction.Prim.Order

`ORDER BY` の許される順列（`isAllowedOrder`）と、[Spec] の整列（`List.mergeSort`）の一致。
整列キーが行の上で一意なら、許される順列はただ 1 つで、[Spec] の安定整列の結果に一致する。
-/

namespace Abstraction.Prim

open LangSemantics.Sql

/-- 非 NULL の整数 1 列を昇順で整列した結果は、行の並べ替えで、キーについて整列している。 -/
theorem allowed_int_sorted {α : Type} [BEq α] [LawfulBEq α] {cfg : SortConfig} {f : α → Int} {rows o : List α}
    (h : isAllowedOrder cfg [.asc] (fun r => [.int (f r)]) rows o = true) :
    o.Perm rows ∧ o.Pairwise fun a b => f a ≤ f b := by
  simp only [isAllowedOrder, Bool.and_eq_true, Bag.bagEq_iff_perm, List.all_eq_true, bne_iff_ne, ne_eq,
    compareKeys_int_asc, Int.compare_ne_gt] at h
  exact ⟨h.1.symm, pairwise_of_adjacent (R := fun a b => f a ≤ f b) (fun _ _ _ => Int.le_trans) o h.2⟩

/-- キー `d` が一意な列 `l` の並べ替えで、`d` について整列しているものは、`l` の `mergeSort` に等しい。 -/
theorem eq_mergeSort_of_sorted {β : Type} {l l' : List β} (d : β → Nat) (hnd : (l.map d).Nodup)
    (hp : l'.Perm l) (hs : l'.Pairwise fun a b => d a ≤ d b) :
    l' = l.mergeSort fun a b => decide (d a ≤ d b) := by
  have hm := List.mergeSort_perm l (fun a b => decide (d a ≤ d b))
  have hsorted := List.pairwise_mergeSort (le := fun a b => decide (d a ≤ d b))
    (fun a b c hab hbc => by simp only [decide_eq_true_eq] at *; omega)
    (fun a b => by simp only [Bool.or_eq_true, decide_eq_true_eq]; omega) l
  refine eq_of_perm_of_pairwise (R := fun a b => d a ≤ d b) ?_ (hp.trans hm.symm) hs ?_
  · intro a ha b hb hab hba
    exact inj_of_nodup_map hnd (hp.mem_iff.mp ha) (hp.mem_iff.mp hb) (by omega)
  · simpa using hsorted

/-- 許される順列を `g` で写したものは、写した列の `mergeSort` に等しい（キーが一意で、非負の整数のとき）。 -/
theorem allowed_map_eq_mergeSort {α β : Type} [BEq α] [LawfulBEq α] {cfg : SortConfig} {f : α → Int}
    {rows o : List α} (g : α → β) (d : β → Nat) (hd : ∀ r ∈ rows, (d (g r) : Int) = f r)
    (hnd : ((rows.map g).map d).Nodup) (h : isAllowedOrder cfg [.asc] (fun r => [.int (f r)]) rows o = true) :
    o.map g = (rows.map g).mergeSort fun a b => decide (d a ≤ d b) := by
  obtain ⟨hp, hs⟩ := allowed_int_sorted h
  refine eq_mergeSort_of_sorted d hnd (hp.map g) ?_
  rw [List.pairwise_map]
  refine (List.Pairwise.and_mem.mp hs).imp fun {a b} ⟨ha, hb, hab⟩ => ?_
  have := hd a (hp.mem_iff.mp ha)
  have := hd b (hp.mem_iff.mp hb)
  omega

end Abstraction.Prim
