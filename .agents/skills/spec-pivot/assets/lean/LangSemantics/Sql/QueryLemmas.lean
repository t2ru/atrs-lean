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
- `cross_filter_left`・`select_filter_of_imp`: 選択の条件が左の表の行だけで決まる条件を含むなら、その条件で
  左の表を先に絞ってよい（条件の押し下げ）。
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

/-- 結合の補題（高々 1 行の形）: 左の各行 `x` で、右の行のうち `P x` を満たすものが `g x` の 0 行か 1 行なら、
直積を `P` で選んだ結果は、`g x` が定義される左の行ごとに `(x, g x)` を並べたもの。 -/
theorem filter_cross_opt {α β : Type} (xs : List α) (bs : List β) (P : α → β → Bool) (g : α → Option β)
    (h : ∀ x ∈ xs, bs.filter (P x) = (g x).toList) :
    (Bag.cross xs bs).filter (fun t => P t.1 t.2) = xs.filterMap fun x => (g x).map (x, ·) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have ih := ih fun y hy => h y (List.mem_cons_of_mem _ hy)
    simp only [Bag.cross] at ih ⊢
    rw [List.flatMap_cons, List.filter_append, ih, List.filter_map]
    have hx := h x (List.mem_cons_self ..)
    have e : (bs.filter ((fun t => P t.1 t.2) ∘ fun b => (x, b))) = bs.filter (P x) := rfl
    rw [e, hx]
    cases hg : g x <;> simp [hg]

/-- 結合の補題（`filterMap` の形）: 左の各行 `x` で、右の行のうち `h x` が値を持つものが `g x` の高々 1 行なら、
直積の `filterMap` は、左の行ごとに `g x` で `h x` を評価したもの。 -/
theorem filterMap_cross {α β γ : Type} (xs : List α) (bs : List β) (h : α → β → Option γ) (g : α → Option β)
    (H : ∀ x ∈ xs, bs.filterMap (h x) = ((g x).bind (h x)).toList) :
    (Bag.cross xs bs).filterMap (fun t => h t.1 t.2) = xs.filterMap fun x => (g x).bind (h x) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have ih := ih fun y hy => H y (List.mem_cons_of_mem _ hy)
    simp only [Bag.cross] at ih ⊢
    rw [List.flatMap_cons, List.filterMap_append, ih, List.filterMap_map]
    have hx := H x (List.mem_cons_self ..)
    have e : bs.filterMap ((fun t => h t.1 t.2) ∘ fun b => (x, b)) = bs.filterMap (h x) := rfl
    rw [e, hx]
    cases hg : (g x).bind (h x) <;> simp [hg]

/-- キーが重複しない表で、キーが `v` の行のほかは `h` が値を持たないなら、表の `filterMap` は、キーが `v` の行
（`find?`）を `h` で評価したもの（高々 1 行）。 -/
theorem filterMap_unique {β σ γ : Type} [DecidableEq σ] (bs : List β) (k : β → σ) (v : σ) (h : β → Option γ)
    (hnd : (bs.map k).Nodup) (hh : ∀ b ∈ bs, k b ≠ v → h b = none) :
    bs.filterMap h = ((bs.find? fun b => k b == v).bind h).toList := by
  induction bs with
  | nil => rfl
  | cons b bs ih =>
    rw [List.map_cons, List.nodup_cons] at hnd
    have ih := ih hnd.2 fun c hc => hh c (List.mem_cons_of_mem _ hc)
    by_cases hb : k b = v
    · have hrest : bs.filterMap h = [] := by
        rw [List.filterMap_eq_nil_iff]
        intro c hc
        apply hh c (List.mem_cons_of_mem _ hc)
        intro e; apply hnd.1; rw [hb, ← e]; exact List.mem_map_of_mem hc
      simp only [List.filterMap_cons, List.find?_cons, hb, beq_self_eq_true, hrest, Option.bind_some]
      cases h b <;> rfl
    · have hn : h b = none := hh b (List.mem_cons_self ..) hb
      have hb' : (k b == v) = false := by simp [hb]
      simp only [List.filterMap_cons, hn, List.find?_cons, hb', ih]

/-- 左の表を絞ってから直積を取るのは、直積を左の成分の条件で絞るのと同じ。 -/
theorem cross_filter_left {α β : Type} (xs : List α) (bs : List β) (q : α → Bool) :
    Bag.cross (xs.filter q) bs = (Bag.cross xs bs).filter (fun t => q t.1) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    simp only [Bag.cross] at ih ⊢
    have hmap : (List.map (fun b => (x, b)) bs).filter (fun t => q t.1) =
        if q x then List.map (fun b => (x, b)) bs else [] := by
      by_cases hq : q x = true
      · simp only [hq, List.filter_map, Function.comp_def, ite_true]
        congr 1
        exact List.filter_eq_self.mpr fun _ _ => rfl
      · have hq' : q x = false := by simpa using hq
        simp [hq', List.filter_map, Function.comp_def]
    rw [List.flatMap_cons, List.filter_append, hmap, ← ih]
    by_cases hq : q x = true
    · simp [List.filter_cons_of_pos hq, hq]
    · have hq' : q x = false := by simpa using hq
      simp [List.filter_cons_of_neg hq, hq']

/-- 選択の条件 `P` が `q` を含意するなら、先に `q` で絞ってから `P` で選んでも同じ。 -/
theorem select_filter_of_imp {α : Type} (P : α → Truth) (q : α → Bool) (rows : Bag α)
    (h : ∀ t, (P t).holds = true → q t = true) :
    Bag.select P rows = Bag.select P (rows.filter q) := by
  unfold Bag.select
  rw [List.filter_filter]
  congr 1
  funext t
  by_cases hp : (P t).holds = true
  · simp [hp, h t hp]
  · simp [hp]

end LangSemantics.Sql.QueryLemmas
