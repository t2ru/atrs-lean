/-!
# LangSemantics.Core.MapM

`Option` の `List.mapM`（標準の抽象化 α で表を写すもの）の性質。写しが定義されれば、
要素は 1 対 1 に対応し、キーの列・`find?` の結果も対応する。
-/

namespace LangSemantics.Core

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

end LangSemantics.Core
