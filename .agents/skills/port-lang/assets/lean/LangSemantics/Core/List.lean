/-!
# LangSemantics.Core.List

列・文字列の汎用の補題（言語に依存しない。core だけに依存する）。

- `find?_perm`: 述語を満たす要素が高々 1 つなら、`find?` は並べ替えで変わらない。
- `inj_of_nodup_map`・`nodup_map_of_imp`: キーが一意な列の性質。
- `filter_key_eq_singleton`: キーが一意な列でキーを探すと、その要素ただ 1 つが残る。
- `find?_congr`: 要素の上で等しい述語の検索は等しい。
- `append_sep_inj`: 区切り文字を含まない 2 つの列を区切りで連結したものは単射（キャッシュのキーなど）。
- `string_any_toList`: `String.any` は文字の列の `any`。
- `Forall₂`: 2 つの列の要素ごとの関係（core に無いので置く）。`sum_map_le`: 和の上限。
-/

namespace LangSemantics.Core.List

/-- 述語を満たす要素が高々 1 つなら、`find?` の結果は並べ替えで変わらない。 -/
theorem find?_perm {α : Type} {p : α → Bool} {l l' : List α} (hp : l.Perm l')
    (hu : ∀ a ∈ l, ∀ b ∈ l, p a = true → p b = true → a = b) : l.find? p = l'.find? p := by
  cases h : l.find? p with
  | none =>
    rw [List.find?_eq_none] at h
    exact (List.find?_eq_none.mpr fun x hx => h x (hp.mem_iff.mpr hx)).symm
  | some a =>
    have ha : a ∈ l := List.mem_of_find?_eq_some h
    have hpa : p a = true := List.find?_some h
    cases h' : l'.find? p with
    | none =>
      rw [List.find?_eq_none] at h'
      exact absurd hpa (h' a (hp.mem_iff.mp ha))
    | some b =>
      have hb : b ∈ l := hp.mem_iff.mpr (List.mem_of_find?_eq_some h')
      rw [hu a ha b hb hpa (List.find?_some h')]

/-- 対称な関係で整列した列の、異なる 2 要素は関係を満たす。 -/
theorem rel_of_pairwise_symm {α : Type} {R : α → α → Prop} (hs : ∀ a b, R a b → R b a) :
    ∀ {l : List α}, l.Pairwise R → ∀ {a b : α}, a ∈ l → b ∈ l → a ≠ b → R a b
  | [], _, _, _, ha, _, _ => by simp at ha
  | x :: l, hl, a, b, ha, hb, hne => by
    obtain ⟨hx, hl'⟩ := List.pairwise_cons.mp hl
    rcases List.mem_cons.mp ha with rfl | ha' <;> rcases List.mem_cons.mp hb with rfl | hb'
    · exact absurd rfl hne
    · exact hx b hb'
    · exact hs _ _ (hx a ha')
    · exact rel_of_pairwise_symm hs hl' ha' hb' hne

/-- キーが一意な列で、キーが等しい要素は同じ要素。 -/
theorem inj_of_nodup_map {α κ : Type} {f : α → κ} {l : List α} (hnd : (l.map f).Nodup) {a b : α}
    (ha : a ∈ l) (hb : b ∈ l) (e : f a = f b) : a = b := by
  induction l with
  | nil => simp at ha
  | cons x l ih =>
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at hnd
    rcases List.mem_cons.mp ha with ha | ha <;> rcases List.mem_cons.mp hb with hb | hb
    · rw [ha, hb]
    · exact absurd ⟨b, hb, ha ▸ e.symm⟩ hnd.1
    · exact absurd ⟨a, ha, hb ▸ e⟩ hnd.1
    · exact ih hnd.2 ha hb

/-- キーが一意な列で、要素 `x` のキーで選ぶと、`x` だけが残る。 -/
theorem filter_key_eq_singleton {α κ : Type} [DecidableEq κ] {f : α → κ} {l : List α} {x : α}
    (hnd : (l.map f).Nodup) (hx : x ∈ l) : l.filter (fun a => f a == f x) = [x] := by
  induction l with
  | nil => simp at hx
  | cons a l ih =>
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at hnd
    rcases List.mem_cons.mp hx with rfl | hx
    · rw [List.filter_cons_of_pos (by simp), List.filter_eq_nil_iff.mpr]
      intro b hb hfb
      exact hnd.1 ⟨b, hb, by simpa using hfb⟩
    · have hne : f a ≠ f x := fun e => hnd.1 ⟨x, hx, e.symm⟩
      rw [List.filter_cons_of_neg (by simpa using hne), ih hnd.2 hx]

/-- 要素の上で等しい述語の検索は等しい。 -/
theorem find?_congr {α : Type} {p q : α → Bool} : ∀ {l : List α}, (∀ a ∈ l, p a = q a) → l.find? p = l.find? q
  | [], _ => rfl
  | a :: l, h => by
    simp only [List.find?_cons, h a (List.mem_cons_self ..)]
    cases q a
    · exact find?_congr fun b hb => h b (List.mem_cons_of_mem _ hb)
    · rfl

/-- `f` の値が重複せず、`g` の値が等しければ `f` の値も等しいなら、`g` の値も重複しない。 -/
theorem nodup_map_of_imp {α β γ : Type} {l : List α} {f : α → β} {g : α → γ} (hf : (l.map f).Nodup)
    (h : ∀ a ∈ l, ∀ b ∈ l, g a = g b → f a = f b) : (l.map g).Nodup := by
  rw [List.Nodup, List.pairwise_map] at hf ⊢
  exact (List.Pairwise.and_mem.mp hf).imp fun {a b} ⟨ha, hb, hne⟩ e => hne (h a ha b hb e)

theorem append_sep_inj {c : Char} : ∀ {a a' b b' : List Char}, c ∉ a → c ∉ a' →
    a ++ c :: b = a' ++ c :: b' → a = a' ∧ b = b'
  | [], [], _, _, _, _, h => by simpa using h
  | [], x :: a', _, _, _, h', h => by
    simp only [List.nil_append, List.cons_append, List.cons.injEq] at h
    exact absurd (h.1 ▸ List.mem_cons_self ..) h'
  | x :: a, [], _, _, h, _, h' => by
    simp only [List.nil_append, List.cons_append, List.cons.injEq] at h'
    exact absurd (h'.1 ▸ List.mem_cons_self ..) h
  | x :: a, y :: a', _, _, h, h', e => by
    simp only [List.cons_append, List.cons.injEq] at e
    obtain ⟨rfl, e⟩ := e
    obtain ⟨rfl, rfl⟩ := append_sep_inj (fun m => h (List.mem_cons_of_mem _ m))
      (fun m => h' (List.mem_cons_of_mem _ m)) e
    exact ⟨rfl, rfl⟩

theorem string_any_toList (s : String) (p : Char → Bool) : s.any p = s.toList.any p := by simp [String.any]

/-- 2 つの列の要素ごとの関係（core に無いので置く）。 -/
inductive Forall₂ {α β : Type} (R : α → β → Prop) : List α → List β → Prop
  | nil : Forall₂ R [] []
  | cons {a : α} {b : β} {as : List α} {bs : List β} : R a b → Forall₂ R as bs → Forall₂ R (a :: as) (b :: bs)

theorem sum_map_le {α : Type} {V : α → Nat} {M : Nat} : ∀ (xs : List α), (∀ x ∈ xs, V x ≤ M) →
    (xs.map V).sum ≤ xs.length * M
  | [], _ => by simp
  | x :: xs, h => by
    have := sum_map_le xs fun y hy => h y (List.mem_cons_of_mem _ hy)
    have hx := h x (List.mem_cons_self ..)
    simp only [List.map_cons, List.sum_cons, List.length_cons, Nat.succ_mul]
    omega

end LangSemantics.Core.List
