import LangSemantics.Sql.Core

/-!
# LangSemantics.Sql.Query

照会と更新の意味論。行の集まりは **バッグ（多重集合）** であり、リストで表すが順序には意味が無い。
`ORDER BY` の結果は「許される順列の集合」として、判定関数 `isAllowedOrder` で与える。

lang: `lang:sql#ISO-9075-2-7.12`（query specification）, `lang:sql#ISO-9075-2-10.10`（sort specification）
-/

namespace LangSemantics.Sql

/-- 行の集まり（バッグ）。リストの順序に意味は無い。 -/
abbrev Bag (α : Type) := List α

namespace Bag

/-- 2 つのバッグが等しい（要素ごとの個数が一致する）か。 -/
def bagEq {α : Type} [BEq α] (a b : Bag α) : Bool :=
  a.all (fun x => a.count x == b.count x) && b.all (fun x => a.count x == b.count x)

/-- `bagEq` は、順列であること（`List.Perm`）と同値である。 -/
theorem bagEq_iff_perm {α : Type} [BEq α] [LawfulBEq α] (a b : Bag α) : bagEq a b = true ↔ a.Perm b := by
  rw [List.perm_iff_count]
  simp only [bagEq, Bool.and_eq_true, List.all_eq_true, beq_iff_eq]
  constructor
  · intro ⟨ha, hb⟩ x
    by_cases hxa : x ∈ a
    · exact ha x hxa
    · by_cases hxb : x ∈ b
      · exact hb x hxb
      · rw [List.count_eq_zero_of_not_mem hxa, List.count_eq_zero_of_not_mem hxb]
  · intro h
    exact ⟨fun x _ => h x, fun x _ => h x⟩

/-- `WHERE p`。 -/
def select {α : Type} (p : α → Truth) (rows : Bag α) : Bag α := rows.filter (fun r => (p r).holds)

/-- `SELECT f(row)`（射影）。 -/
def project {α β : Type} (f : α → β) (rows : Bag α) : Bag β := rows.map f

/-- 直積（`FROM a, b`）。 -/
def cross {α β : Type} (a : Bag α) (b : Bag β) : Bag (α × β) := a.flatMap (fun x => b.map (x, ·))

/-- 内部結合。 -/
def innerJoin {α β : Type} (on : α → β → Truth) (a : Bag α) (b : Bag β) : Bag (α × β) :=
  (cross a b).filter (fun p => (on p.1 p.2).holds)

/-- `SELECT EXISTS (…)`。 -/
def exists' {α : Type} (rows : Bag α) : Bool := !rows.isEmpty

/-- `COUNT(*)`。 -/
def countAll {α : Type} (rows : Bag α) : Nat := rows.length

end Bag

/-- 整列キーの 1 項目の向き。 -/
inductive SortDir where
  | asc
  | desc
  deriving Repr, BEq, DecidableEq

/-- 整列の設定（方言が与える）。 -/
structure SortConfig where
  collation : Collation
  /-- 昇順で NULL を先にするか（PostgreSQL は昇順で NULL が後）。 -/
  nullsFirstAsc : Bool

/-- 1 項目の比較（NULL の位置を含む）。 -/
def compareKey (cfg : SortConfig) (dir : SortDir) (a b : SqlValue) : Ordering :=
  let base : Ordering :=
    match a, b with
    | .null, .null => .eq
    | .null, _ => if cfg.nullsFirstAsc then .lt else .gt
    | _, .null => if cfg.nullsFirstAsc then .gt else .lt
    | _, _ => (a.cmp cfg.collation b).getD .eq
  match dir with
  | .asc => base
  | .desc => base.swap

/-- 複数項目の辞書式比較。 -/
def compareKeys (cfg : SortConfig) (dirs : List SortDir) : List SqlValue → List SqlValue → Ordering
  | a :: as, b :: bs =>
    match dirs with
    | d :: ds => match compareKey cfg d a b with
      | .eq => compareKeys cfg ds as bs
      | o => o
    | [] => .eq
  | _, _ => .eq

/-- `ORDER BY` の結果として `out` が許されるか: `rows` の並べ替えであり、整列キーについて非減少である。
キーが等しい行の相対順序は問わない（未規定）。 -/
def isAllowedOrder {α : Type} [BEq α] (cfg : SortConfig) (dirs : List SortDir)
    (key : α → List SqlValue) (rows out : List α) : Bool :=
  let sorted := (out.zip out.tail).all (fun p => compareKeys cfg dirs (key p.1) (key p.2) != .gt)
  Bag.bagEq rows out && sorted

/-- 許される順列のうちの 1 つ（挿入ソートによる安定整列）。テストや参照実装に使う。 -/
def orderByStable {α : Type} (cfg : SortConfig) (dirs : List SortDir) (key : α → List SqlValue)
    (rows : List α) : List α :=
  let insert (x : α) : List α → List α :=
    let rec go : List α → List α
      | [] => [x]
      | y :: ys => if compareKeys cfg dirs (key x) (key y) == .lt then x :: y :: ys else y :: go ys
    go
  rows.foldl (fun acc x => insert x acc) []

/-! ## 許される順列の一意性 -/

/-- 隣り合う要素が `R` を満たし、`R` が推移的なら、どの 2 要素も `R` を満たす。 -/
theorem pairwise_of_adjacent {α : Type} {R : α → α → Prop} (htrans : ∀ a b c, R a b → R b c → R a c) :
    ∀ (l : List α), (∀ p ∈ l.zip l.tail, R p.1 p.2) → l.Pairwise R
  | [] , _ => List.Pairwise.nil
  | [_], _ => List.pairwise_singleton _ _
  | a :: b :: l, h => by
    have hab : R a b := h (a, b) (by simp)
    have hrest : (b :: l).Pairwise R :=
      pairwise_of_adjacent htrans (b :: l) fun p hp => h p (by simp [List.zip] at hp ⊢; exact Or.inr hp)
    refine List.Pairwise.cons ?_ hrest
    intro c hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact hab
    · exact htrans a b c hab (List.rel_of_pairwise_cons hrest hc)

/-- 互いに順列で、どちらも `R` で整列していて、`R` が要素の上で反対称なら、2 つの列は等しい。 -/
theorem eq_of_perm_of_pairwise {α : Type} {R : α → α → Prop} :
    ∀ {l₁ l₂ : List α}, (∀ a ∈ l₁, ∀ b ∈ l₁, R a b → R b a → a = b) →
      l₁.Perm l₂ → l₁.Pairwise R → l₂.Pairwise R → l₁ = l₂
  | [], _, _, hp, _, _ => (List.Perm.nil_eq hp)
  | _ :: _, [], _, hp, _, _ => absurd hp.length_eq (by simp)
  | a :: t₁, b :: t₂, hanti, hp, h₁, h₂ => by
    by_cases e : a = b
    · subst e
      have ht := hp.cons_inv
      rw [eq_of_perm_of_pairwise (fun x hx y hy => hanti x (List.mem_cons_of_mem _ hx) y
        (List.mem_cons_of_mem _ hy)) ht (List.pairwise_cons.mp h₁).2 (List.pairwise_cons.mp h₂).2]
    · have hb : b ∈ t₁ := by
        rcases List.mem_cons.mp (hp.mem_iff.mpr (List.mem_cons_self ..)) with h | h
        · exact absurd h.symm e
        · exact h
      have ha : a ∈ t₂ := by
        rcases List.mem_cons.mp (hp.mem_iff.mp (List.mem_cons_self ..)) with h | h
        · exact absurd h e
        · exact h
      exact absurd (hanti a (List.mem_cons_self ..) b (List.mem_cons_of_mem _ hb)
        (List.rel_of_pairwise_cons h₁ hb) (List.rel_of_pairwise_cons h₂ ha)) e

/-- `ORDER BY` の許される順列の一意性: 整列キーの比較が `rows` の上で反対称（`swap`）・推移的で、
比較が等しい行は同じ行である（キーが単射）なら、許される順列はただ 1 つである。 -/
theorem isAllowedOrder_unique {α : Type} [BEq α] [LawfulBEq α] {cfg : SortConfig} {dirs : List SortDir}
    {key : α → List SqlValue} {rows o₁ o₂ : List α}
    (hswap : ∀ x ∈ rows, ∀ y ∈ rows, compareKeys cfg dirs (key y) (key x) = (compareKeys cfg dirs (key x) (key y)).swap)
    (htrans : ∀ x ∈ rows, ∀ y ∈ rows, ∀ z ∈ rows, compareKeys cfg dirs (key x) (key y) ≠ .gt →
      compareKeys cfg dirs (key y) (key z) ≠ .gt → compareKeys cfg dirs (key x) (key z) ≠ .gt)
    (hinj : ∀ x ∈ rows, ∀ y ∈ rows, compareKeys cfg dirs (key x) (key y) = .eq → x = y)
    (h₁ : isAllowedOrder cfg dirs key rows o₁ = true) (h₂ : isAllowedOrder cfg dirs key rows o₂ = true) :
    o₁ = o₂ := by
  simp only [isAllowedOrder, Bool.and_eq_true, Bag.bagEq_iff_perm, List.all_eq_true, bne_iff_ne, ne_eq] at h₁ h₂
  obtain ⟨hp₁, hs₁⟩ := h₁
  obtain ⟨hp₂, hs₂⟩ := h₂
  -- 要素を rows の要素に限った関係で考える
  let R : α → α → Prop := fun x y => x ∈ rows ∧ y ∈ rows ∧ compareKeys cfg dirs (key x) (key y) ≠ .gt
  have trans : ∀ a b c, R a b → R b c → R a c := fun a b c ⟨ha, hb, hab⟩ ⟨_, hc, hbc⟩ =>
    ⟨ha, hc, htrans a ha b hb c hc hab hbc⟩
  have sorted : ∀ (o : List α), rows.Perm o → (∀ p ∈ o.zip o.tail, ¬ compareKeys cfg dirs (key p.1) (key p.2) = .gt) →
      o.Pairwise R := by
    intro o hp hs
    apply pairwise_of_adjacent trans
    intro p hpm
    have h1 : p.1 ∈ o := (List.of_mem_zip hpm).1
    have h2 : p.2 ∈ o := List.mem_of_mem_tail (List.of_mem_zip hpm).2
    exact ⟨hp.mem_iff.mpr h1, hp.mem_iff.mpr h2, hs p hpm⟩
  apply eq_of_perm_of_pairwise (R := R) _ (hp₁.symm.trans hp₂) (sorted o₁ hp₁ hs₁) (sorted o₂ hp₂ hs₂)
  intro x _ y _ ⟨hx, hy, hxy⟩ ⟨_, _, hyx⟩
  apply hinj x hx y hy
  rw [hswap x hx y hy] at hyx
  revert hxy hyx
  generalize compareKeys cfg dirs (key x) (key y) = c
  cases c <;> decide

/-- 非 NULL の整数 1 列を昇順で整列するときの比較は、整数の比較である。 -/
theorem compareKeys_int_asc (cfg : SortConfig) (a b : Int) :
    compareKeys cfg [.asc] [.int a] [.int b] = compare a b := by
  simp only [compareKeys, compareKey, SqlValue.cmp, Option.getD_some]
  cases compare a b <;> rfl

/-- 例: 非 NULL の整数 1 列のキーが行の上で単射なら、`ORDER BY` の許される順列はただ 1 つである。 -/
theorem isAllowedOrder_unique_int {α : Type} [BEq α] [LawfulBEq α] {cfg : SortConfig} {f : α → Int}
    {rows o₁ o₂ : List α} (hinj : ∀ x ∈ rows, ∀ y ∈ rows, f x = f y → x = y)
    (h₁ : isAllowedOrder cfg [.asc] (fun r => [.int (f r)]) rows o₁ = true)
    (h₂ : isAllowedOrder cfg [.asc] (fun r => [.int (f r)]) rows o₂ = true) : o₁ = o₂ := by
  refine isAllowedOrder_unique ?_ ?_ ?_ h₁ h₂
  · intro x _ y _; simp only [compareKeys_int_asc]; exact (Int.compare_swap _ _).symm
  · intro x _ y _ z _; simp only [compareKeys_int_asc, Int.compare_ne_gt]; exact Int.le_trans
  · intro x hx y hy h; simp only [compareKeys_int_asc, Int.compare_eq_eq] at h; exact hinj x hx y hy h

/-- `UPDATE … SET … WHERE p`。右辺 `set` は更新前の行で評価する。更新件数を返す。 -/
def updateWhere {α : Type} (p : α → Truth) (set : α → α) (rows : List α) : List α × Nat :=
  rows.foldr (fun r (acc, n) => if (p r).holds then (set r :: acc, n + 1) else (r :: acc, n)) ([], 0)

/-- `DELETE … WHERE p`。削除件数を返す。 -/
def deleteWhere {α : Type} (p : α → Truth) (rows : List α) : List α × Nat :=
  let kept := rows.filter (fun r => !(p r).holds)
  (kept, rows.length - kept.length)

/-- 主キー `pk` の一意性を保って挿入する。 -/
def insertUnique {α κ : Type} [BEq κ] (pk : α → κ) (constraintName : String) (row : α) (rows : List α) :
    SqlResult (List α) :=
  if rows.any (fun r => pk r == pk row) then .error (.uniqueViolation constraintName) else .ok (rows ++ [row])

end LangSemantics.Sql
