import LangSemantics.Core.List

/-!
# LangSemantics.Core.MapM

`Option` の `List.mapM`（標準の抽象化 α で表を写すもの）の性質。写しが定義されれば、
要素は 1 対 1 に対応し、キーの列・`find?` の結果も対応する。
-/

namespace LangSemantics.Core.MapM
open LangSemantics.Core.List

variable {α β : Type}

theorem mapM_some_cons {f : α → Option β} {a : α} {l : List α} {l' : List β}
    (h : (a :: l).mapM f = some l') : ∃ b t, f a = some b ∧ l.mapM f = some t ∧ l' = b :: t := by
  simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h
  obtain ⟨b, hb, t, ht, rfl⟩ := h
  exact ⟨b, t, hb, ht, rfl⟩

/-- 写しが定義されれば、各要素の写しも定義される。 -/
theorem mapM_some_mem {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l') {a : α}
    (ha : a ∈ l) : ∃ b ∈ l', f a = some b := by
  induction l generalizing l' with
  | nil => simp at ha
  | cons x l ih =>
    obtain ⟨b, t, hb, ht, rfl⟩ := mapM_some_cons h
    rcases List.mem_cons.mp ha with rfl | ha
    · exact ⟨b, List.mem_cons_self .., hb⟩
    · obtain ⟨c, hc, e⟩ := ih ht ha
      exact ⟨c, List.mem_cons_of_mem _ hc, e⟩

/-- 写しの各要素は、元のどれかの要素の写し。 -/
theorem mapM_some_mem' {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l') {b : β}
    (hb : b ∈ l') : ∃ a ∈ l, f a = some b := by
  induction l generalizing l' with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; simp at hb
  | cons x l ih =>
    obtain ⟨c, t, hc, ht, rfl⟩ := mapM_some_cons h
    rcases List.mem_cons.mp hb with rfl | hb
    · exact ⟨x, List.mem_cons_self .., hc⟩
    · obtain ⟨a, ha, e⟩ := ih ht hb
      exact ⟨a, List.mem_cons_of_mem _ ha, e⟩

/-- 写しが要素ごとに `g` と `h` を対応させるなら、`h` の列は `g` の列。 -/
theorem mapM_some_map {γ : Type} {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l')
    {g : α → γ} {k : β → γ} (hk : ∀ a b, f a = some b → k b = g a) : l'.map k = l.map g := by
  induction l generalizing l' with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | cons x l ih =>
    obtain ⟨b, t, hb, ht, rfl⟩ := mapM_some_cons h
    simp only [List.map_cons, hk _ _ hb, ih ht]

/-- 写しの上の検索は、元の検索の写し（述語が写しで保たれるとき）。 -/
theorem find?_mapM {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l')
    {p : α → Bool} {q : β → Bool} (hpq : ∀ a b, f a = some b → q b = p a) :
    l'.find? q = (l.find? p).bind f := by
  induction l generalizing l' with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | cons x l ih =>
    obtain ⟨b, t, hb, ht, rfl⟩ := mapM_some_cons h
    simp only [List.find?_cons, hpq _ _ hb]
    cases p x
    · exact ih ht
    · simp [hb]

/-- 写しが定義されれば、長さは等しい。 -/
theorem mapM_some_length {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l') :
    l'.length = l.length := by
  simpa using mapM_some_map (g := fun _ => ()) (k := fun _ => ()) h (fun _ _ _ => rfl) |> congrArg List.length

theorem mapM_some_getD {α β : Type} {f : α → Option β} {l : List α} {l' : List β} (h : l.mapM f = some l')
    (d : β) : l.map (fun a => (f a).getD d) = l' := by
  have := mapM_some_map h (g := fun a => (f a).getD d) (k := id) fun _ _ e => by simp [e]
  simpa using this.symm

/-- `mapM` で写した列と、各要素の関係。 -/
theorem forall₂_of_mapM {α β γ : Type} {g : α → Option β} {R : γ → β → Prop} (mk : α → γ) :
    ∀ (xs : List α) (ys : List β), xs.mapM g = some ys → (∀ x ∈ xs, ∀ y ∈ ys, g x = some y → R (mk x) y) →
      Forall₂ R (xs.map mk) ys
  | [], ys, h, _ => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .nil
  | x :: xs, ys, h, hR => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, hy, ys', hys, hyy⟩ := h
    subst hyy
    exact .cons (hR x (List.mem_cons_self ..) y (List.mem_cons_self ..) hy)
      (forall₂_of_mapM mk xs ys' hys fun x' hx' y' hy' => hR x' (List.mem_cons_of_mem _ hx') y'
        (List.mem_cons_of_mem _ hy'))

theorem forall₂_of_mapM_id {α β : Type} {g : α → Option β} {R : α → β → Prop} (xs : List α) (ys : List β)
    (h : xs.mapM g = some ys) (hR : ∀ x ∈ xs, ∀ y ∈ ys, g x = some y → R x y) : Forall₂ R xs ys := by
  have := forall₂_of_mapM (R := R) id xs ys h hR
  rwa [List.map_id] at this

/-- `mapM` の結果は、各要素の値の列。 -/
theorem mapM_eq_map_getD {α β : Type} {g : α → Option β} (d : β) :
    ∀ {xs : List α} {ys : List β}, xs.mapM g = some ys → ys = xs.map fun x => (g x).getD d
  | [], ys, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | x :: xs, ys, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, hy, ys', hys, rfl⟩ := h
    simp only [List.map_cons, hy, Option.getD_some, mapM_eq_map_getD d hys]

theorem mapM_length {α β : Type} {g : α → Option β} : ∀ {xs : List α} {ys : List β}, xs.mapM g = some ys →
    xs.length = ys.length
  | [], ys, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | x :: xs, ys, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, -, ys', hys, rfl⟩ := h
    simp only [List.length_cons, mapM_length hys]

end LangSemantics.Core.MapM
