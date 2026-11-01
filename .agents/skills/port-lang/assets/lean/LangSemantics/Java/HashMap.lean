/-!
# LangSemantics.Java.HashMap

`java.util.HashMap` の、業務ロジックが使う範囲（`put`・`get`・`containsKey`・`size`）。
反復の順序は未規定なので、モデルは反復を与えない（反復に依存する原典は、順序を非決定性として別に写す）。
キーの等しさは `DecidableEq` とする。enum（同一性）と `String`（値の `equals`）の `equals` に一致する。
`hashCode` と `equals` が整合しないキーは、対象外である。

lang: `lang:java#java.util.HashMap`, `lang:java#java.util.LinkedHashMap`
-/

namespace LangSemantics.Java.HashMap

/-- `HashMap<K, V>`。項目は挿入順に並べるが、順序に意味は無い（キーは重複しない）。 -/
structure JHashMap (κ υ : Type) where
  entries : List (κ × υ) := []
  deriving Repr

namespace JHashMap

variable {κ υ : Type} [DecidableEq κ]

/-- 空の `new HashMap<>()`。 -/
def empty : JHashMap κ υ := {}

/-- `get(k)`。キーが無ければ `null`。 -/
def get (m : JHashMap κ υ) (k : κ) : Option υ :=
  (m.entries.find? fun e => e.1 == k).map (·.2)

/-- `containsKey(k)`。 -/
def containsKey (m : JHashMap κ υ) (k : κ) : Bool :=
  m.entries.any fun e => e.1 == k

/-- `put(k, v)`。同じキーがあれば値を置き換える（後勝ち）。 -/
def put (m : JHashMap κ υ) (k : κ) (v : υ) : JHashMap κ υ :=
  if m.containsKey k then ⟨m.entries.map fun e => if e.1 == k then (k, v) else e⟩
  else ⟨m.entries ++ [(k, v)]⟩

/-- `size()`。 -/
def size (m : JHashMap κ υ) : Nat := m.entries.length

/-- 項目を順に `put` した結果（`for (x : xs) map.put(key(x), x)`）。 -/
def ofList (xs : List (κ × υ)) : JHashMap κ υ :=
  xs.foldl (fun m e => m.put e.1 e.2) empty

end JHashMap

/-! ## 写しとの可換性

項目ごとの部分写像 `pairAlpha ka va`（キーを `ka`、値を `va` で写す）で項目の列を写すとき、キーの写しが単射なら、
`get`・`put` は写しと可換である。 -/

section Alpha
variable {κ υ κ' υ' : Type} (ka : κ → Option κ') (va : υ → Option υ')

/-- 項目の写し。 -/
def pairAlpha (e : κ × υ) : Option (κ' × υ') := (ka e.1).bind fun k => (va e.2).map (k, ·)

variable {ka va}

theorem pairAlpha_some {e : κ × υ} {e' : κ' × υ'} (h : pairAlpha ka va e = some e') :
    ka e.1 = some e'.1 ∧ va e.2 = some e'.2 := by
  simp only [pairAlpha, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨k, hk, v, hv, rfl⟩ := h
  exact ⟨hk, hv⟩

variable [DecidableEq κ] [DecidableEq κ']

theorem beq_alpha (hinj : ∀ a b x, ka a = some x → ka b = some x → a = b) {a k : κ} {a' k' : κ'}
    (ha : ka a = some a') (hk : ka k = some k') : (a == k) = (a' == k') := by
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]
  constructor
  · rintro rfl; rw [ha] at hk; exact Option.some.inj hk
  · rintro rfl; exact hinj _ _ _ ha hk

/-- `get` と写し: 写した表で写したキーを引いた結果は、元の結果の写し（無ければ無し）。 -/
theorem get_alpha (hinj : ∀ a b x, ka a = some x → ka b = some x → a = b) :
    ∀ {es : List (κ × υ)} {gs : List (κ' × υ')}, es.mapM (pairAlpha ka va) = some gs →
    ∀ {k : κ} {k' : κ'}, ka k = some k' →
      Option.Rel (fun v g => va v = some g) ((⟨es⟩ : JHashMap κ υ).get k) ((⟨gs⟩ : JHashMap κ' υ').get k')
  | [], gs, h, _, _, _ => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .none
  | e :: es, gs, h, k, k', hk => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨e', he, gs', hgs, rfl⟩ := h
    obtain ⟨h1, h2⟩ := pairAlpha_some he
    have hb := beq_alpha hinj h1 hk
    simp only [JHashMap.get, List.find?_cons, hb]
    cases (e'.1 == k')
    · exact get_alpha hinj hgs hk
    · exact .some h2

/-- `put` と写し: 写した表に写したキーと値を `put` した結果は、元の `put` の結果の写し。 -/
theorem put_alpha (hinj : ∀ a b x, ka a = some x → ka b = some x → a = b) {es : List (κ × υ)}
    {gs : List (κ' × υ')} (h : es.mapM (pairAlpha ka va) = some gs) {k : κ} {k' : κ'} (hk : ka k = some k')
    {v : υ} {g : υ'} (hv : va v = some g) :
    ((⟨es⟩ : JHashMap κ υ).put k v).entries.mapM (pairAlpha ka va) = some ((⟨gs⟩ : JHashMap κ' υ').put k' g).entries := by
  have hpk : pairAlpha ka va (k, v) = some (k', g) := by simp [pairAlpha, hk, hv]
  -- 同じキーの有無は写しで変わらない
  have hany : ∀ {es : List (κ × υ)} {gs : List (κ' × υ')}, es.mapM (pairAlpha ka va) = some gs →
      (es.any fun e => e.1 == k) = (gs.any fun e => e.1 == k') := by
    intro es
    induction es with
    | nil => intro gs h; simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
    | cons e es ih =>
      intro gs h
      simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
        Option.some.injEq] at h
      obtain ⟨e', he, gs', hgs, rfl⟩ := h
      simp only [List.any_cons, beq_alpha hinj (pairAlpha_some he).1 hk, ih hgs]
  have hmap : ∀ {es : List (κ × υ)} {gs : List (κ' × υ')}, es.mapM (pairAlpha ka va) = some gs →
      (es.map fun e => if e.1 == k then (k, v) else e).mapM (pairAlpha ka va) =
        some (gs.map fun e => if e.1 == k' then (k', g) else e) := by
    intro es
    induction es with
    | nil => intro gs h; simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
    | cons e es ih =>
      intro gs h
      simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
        Option.some.injEq] at h
      obtain ⟨e', he, gs', hgs, rfl⟩ := h
      simp only [List.map_cons, List.mapM_cons, beq_alpha hinj (pairAlpha_some he).1 hk, ih hgs]
      cases (e'.1 == k') <;> simp [he, hpk]
  have happ : (es ++ [(k, v)]).mapM (pairAlpha ka va) = some (gs ++ [(k', g)]) := by
    rw [List.mapM_append, h]; simp [hpk]
  simp only [JHashMap.put, JHashMap.containsKey, hany h]
  by_cases hc : (gs.any fun e => e.1 == k') = true
  · simp only [hc, ↓reduceIte]; exact hmap h
  · simp only [hc, ↓reduceIte, Bool.false_eq_true]; exact happ

end Alpha

/-- `java.util.LinkedHashMap`（挿入順）。`JHashMap` と同じ表し方で、反復の順序は `entries` の順と定める
（同じキーの `put` は位置を保って値を置き換える。`LinkedHashMap` の既定の挿入順の動作に一致する）。 -/
abbrev JLinkedHashMap (κ υ : Type) := JHashMap κ υ

end LangSemantics.Java.HashMap
