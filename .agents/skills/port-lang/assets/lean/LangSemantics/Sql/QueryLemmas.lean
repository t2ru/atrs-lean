import LangSemantics.Sql.Query
import LangSemantics.Core.List

/-!
# LangSemantics.Sql.QueryLemmas

照会の結果の補題。

- `mem_cross`・`filter_cross`: 直積の選択で、右の各行がただ 1 つに決まるなら、左の行ごとの 1 行になる（結合の補題）。
- `allowed_int_sorted`・`eq_mergeSort_of_sorted`・`allowed_map_eq_mergeSort`・`allowed_mergeSort_self`:
  `ORDER BY` の許される順列（`isAllowedOrder`）と安定整列（`List.mergeSort`）の一致。整列キーが行の上で一意なら、
  許される順列はただ 1 つで、安定整列の結果に一致する。
- `adjacent_of_pairwise`: `pairwise_of_adjacent` の逆。
- `allowed_perm`: 許される順列は元の行の並べ替え。
-/

namespace LangSemantics.Sql.QueryLemmas
open LangSemantics.Core.List LangSemantics.Sql.Core LangSemantics.Sql.Query

open LangSemantics.Core

theorem mem_cross {α β : Type} {xs : List α} {bs : List β} {x : α × β} :
    x ∈ Bag.cross xs bs ↔ x.1 ∈ xs ∧ x.2 ∈ bs := by
  obtain ⟨a, b⟩ := x
  simp [Bag.cross]

/-- 結合の補題: 左の行 `x` が `c x` を満たすとき、右の行のうち `q x` を満たすものがただ 1 つ `g x` なら、
直積を `c x ∧ q x b` で選んだ結果は、`c` を満たす左の行ごとに `(x, g x)` を並べたもの。 -/
theorem filter_cross {α β : Type} {xs : List α} {bs : List β} {c : α → Bool} {q : α → β → Bool} {g : α → β}
    (h : ∀ x ∈ xs, c x = true → bs.filter (q x) = [g x]) :
    (Bag.cross xs bs).filter (fun p => c p.1 && q p.1 p.2) = (xs.filter c).map fun x => (x, g x) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have ih := ih fun y hy => h y (List.mem_cons_of_mem _ hy)
    simp only [Bag.cross, List.flatMap_cons, List.filter_append] at ih ⊢
    rw [ih]
    by_cases hc : c x = true
    · have hx := h x (List.mem_cons_self ..) hc
      rw [List.filter_cons_of_pos hc, List.map_cons, List.singleton_append.symm.trans (by rfl)]
      congr 1
      rw [List.filter_map]
      simp only [Function.comp_def, hc, Bool.true_and]
      have : (fun b => q x b) = q x := rfl
      rw [this, hx]; rfl
    · have hc' : c x = false := by simpa using hc
      rw [List.filter_cons_of_neg hc]
      rw [List.filter_map]
      simp [Function.comp_def, hc']

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

/-- 整列した列では、隣り合う要素も関係を満たす。 -/
theorem adjacent_of_pairwise {α : Type} {R : α → α → Prop} : ∀ {l : List α}, l.Pairwise R →
    ∀ p ∈ l.zip l.tail, R p.1 p.2
  | [], _, _, h => by simp at h
  | [_], _, _, h => by simp at h
  | a :: b :: l, hl, p, hp => by
    simp only [List.tail_cons, List.zip_cons_cons, List.mem_cons] at hp
    rcases hp with rfl | hp
    · exact List.rel_of_pairwise_cons hl (List.mem_cons_self ..)
    · exact adjacent_of_pairwise (List.pairwise_cons.mp hl).2 p hp

/-- 許される並びは存在する: 整数のキーで `mergeSort` した並び。 -/
theorem allowed_mergeSort_self {α : Type} [BEq α] [LawfulBEq α] (cfg : SortConfig) (rows : List α) (f : α → Int) :
    isAllowedOrder cfg [.asc] (fun r => [.int (f r)]) rows (rows.mergeSort fun a b => decide (f a ≤ f b)) = true := by
  simp only [isAllowedOrder, Bool.and_eq_true, Bag.bagEq_iff_perm, List.all_eq_true, bne_iff_ne, ne_eq,
    compareKeys_int_asc, Int.compare_ne_gt]
  refine ⟨(List.mergeSort_perm _ _).symm, adjacent_of_pairwise (R := fun a b => f a ≤ f b) ?_⟩
  have := List.pairwise_mergeSort (le := fun a b => decide (f a ≤ f b))
    (fun a b c hab hbc => by simp only [decide_eq_true_eq] at *; omega)
    (fun a b => by simp only [Bool.or_eq_true, decide_eq_true_eq]; omega) rows
  simpa using this

theorem allowed_perm {ρ : Type} [DecidableEq ρ] {cfg : SortConfig} {dirs : List SortDir} {rows o : List ρ}
    {key : ρ → List SqlValue} (h : isAllowedOrder cfg dirs key rows o = true) : o.Perm rows := by
  simp only [isAllowedOrder, Bool.and_eq_true, Bag.bagEq_iff_perm] at h
  exact h.1.symm

end LangSemantics.Sql.QueryLemmas
