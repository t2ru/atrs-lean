/-!
# LangSemantics.Java.HashMap

`java.util.HashMap` の、業務ロジックが使う範囲（`put`・`get`・`containsKey`・`size`）。
反復の順序は未規定なので、モデルは反復を与えない（反復に依存する原典は、順序を非決定性として別に写す）。
キーの等しさは `DecidableEq` とする。enum（同一性）と `String`（値の `equals`）の `equals` に一致する。
`hashCode` と `equals` が整合しないキーは、対象外である。

lang: `lang:java#java.util.HashMap`, `lang:java#java.util.LinkedHashMap`
-/

namespace LangSemantics.Java.HashMap

/-- `HashMap<K, V>`。項目は挿入順に並べるが、順序に意味は無い。キーが重複しないことの証明（`nodup`）を持ち、
同じキーを 2 度持つ表は表せない。 -/
structure JHashMap (κ υ : Type) where
  entries : List (κ × υ) := []
  /-- キーは重複しない -/
  nodup : (entries.map Prod.fst).Nodup := by simp
  deriving Repr

namespace JHashMap

variable {κ υ : Type} [DecidableEq κ]

/-- 項目の列でキーを引く（`get` の本体。写しとの可換性 `get_alpha` は列の上で述べる）。 -/
def getE (es : List (κ × υ)) (k : κ) : Option υ :=
  (es.find? fun e => e.1 == k).map (·.2)

/-- 項目の列への `put`（`put` の本体）。同じキーがあれば値を置き換え、無ければ末尾に足す。 -/
def putE (es : List (κ × υ)) (k : κ) (v : υ) : List (κ × υ) :=
  if es.any (fun e => e.1 == k) then es.map fun e => if e.1 == k then (k, v) else e
  else es ++ [(k, v)]

/-- `putE` はキーの重複の無さを保つ（置き換えはキーを変えず、足すのは無いキーに限る）。 -/
theorem putE_nodup {es : List (κ × υ)} (h : (es.map Prod.fst).Nodup) (k : κ) (v : υ) :
    ((putE es k v).map Prod.fst).Nodup := by
  unfold putE
  split
  · have e : (es.map fun e => if e.1 == k then (k, v) else e).map Prod.fst = es.map Prod.fst := by
      rw [List.map_map]
      apply List.map_congr_left
      intro e _
      by_cases he : e.1 = k <;> simp [he]
    rwa [e]
  · rename_i hc
    simp only [List.any_eq_true, beq_iff_eq, not_exists, not_and] at hc
    rw [List.map_append, List.nodup_append]
    refine ⟨h, by simp, ?_⟩
    intro a ha b hb
    simp only [List.map_cons, List.map_nil, List.mem_singleton] at hb
    subst hb
    rintro rfl
    obtain ⟨e, he, hek⟩ := List.mem_map.mp ha
    exact hc e he hek

omit [DecidableEq κ] in
/-- 表は項目の列で決まる。 -/
theorem ext {m m' : JHashMap κ υ} (h : m.entries = m'.entries) : m = m' := by
  cases m; cases m'; cases h; rfl

/-- 空の `new HashMap<>()`。 -/
def empty : JHashMap κ υ := {}

/-- `get(k)`。キーが無ければ `null`。 -/
def get (m : JHashMap κ υ) (k : κ) : Option υ := getE m.entries k

/-- `containsKey(k)`。 -/
def containsKey (m : JHashMap κ υ) (k : κ) : Bool :=
  m.entries.any fun e => e.1 == k

/-- `put(k, v)`。同じキーがあれば値を置き換える（後勝ち）。 -/
def put (m : JHashMap κ υ) (k : κ) (v : υ) : JHashMap κ υ :=
  ⟨putE m.entries k v, putE_nodup m.nodup k v⟩

/-- `put` の項目の列は `putE`。 -/
@[simp] theorem put_entries (m : JHashMap κ υ) (k : κ) (v : υ) : (m.put k v).entries = putE m.entries k v := rfl

/-- `size()`。 -/
def size (m : JHashMap κ υ) : Nat := m.entries.length

/-- 項目を順に `put` した結果（`for (x : xs) map.put(key(x), x)`）。 -/
def ofList (xs : List (κ × υ)) : JHashMap κ υ :=
  xs.foldl (fun m e => m.put e.1 e.2) empty

end JHashMap

/-! ## 写しとの可換性

項目ごとの部分写像 `pairAlpha ka va`（キーを `ka`、値を `va` で写す）で項目の列を写すとき、キーの写しが単射なら、
`get`・`put` の本体（列の上の `getE`・`putE`）は写しと可換である。写した側は列のまま（[Spec] の連想リスト）でよい。 -/

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
      Option.Rel (fun v g => va v = some g) (JHashMap.getE es k) (JHashMap.getE gs k')
  | [], gs, h, _, _, _ => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .none
  | e :: es, gs, h, k, k', hk => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨e', he, gs', hgs, rfl⟩ := h
    obtain ⟨h1, h2⟩ := pairAlpha_some he
    have hb := beq_alpha hinj h1 hk
    simp only [JHashMap.getE, List.find?_cons, hb]
    cases (e'.1 == k')
    · exact get_alpha hinj hgs hk
    · exact .some h2

/-- `put` と写し: 写した表に写したキーと値を `put` した結果は、元の `put` の結果の写し。 -/
theorem put_alpha (hinj : ∀ a b x, ka a = some x → ka b = some x → a = b) {es : List (κ × υ)}
    {gs : List (κ' × υ')} (h : es.mapM (pairAlpha ka va) = some gs) {k : κ} {k' : κ'} (hk : ka k = some k')
    {v : υ} {g : υ'} (hv : va v = some g) :
    (JHashMap.putE es k v).mapM (pairAlpha ka va) = some (JHashMap.putE gs k' g) := by
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
  simp only [JHashMap.putE, hany h]
  by_cases hc : (gs.any fun e => e.1 == k') = true
  · simp only [hc, ↓reduceIte]; exact hmap h
  · simp only [hc, ↓reduceIte, Bool.false_eq_true]; exact happ

end Alpha

/-- `java.util.LinkedHashMap`（挿入順）。`JHashMap` と同じ表し方で、反復の順序は `entries` の順と定める
（同じキーの `put` は位置を保って値を置き換える。`LinkedHashMap` の既定の挿入順の動作に一致する）。 -/
abbrev JLinkedHashMap (κ υ : Type) := JHashMap κ υ

end LangSemantics.Java.HashMap
