
/-!
# LangSemantics.Core.EStateHoare

状態と例外を持つ計算（`EStateM`）の事前・事後条件（Hoare 三つ組）と、その合成の規則。移植元・移植先の命令型の計算
（例: 状態の表に対する計算、トランザクション）の性質を、メソッドごとに積み上げるのに使う
（`references/docs/lang/lean/rules.md#命令型の計算の検証`）。

`Hoare P m Q E`: 事前条件 `P` を満たす状態から `m` を実行すると、正常に終われば `Q 値 状態`、例外で終われば
`E 例外 状態` が成り立つ。
-/

namespace LangSemantics.Core.EStateHoare

/-- Hoare 三つ組（例外の事後条件を持つ）。 -/
def Hoare {ε σ α : Type} (P : σ → Prop) (m : EStateM ε σ α) (Q : α → σ → Prop) (E : ε → σ → Prop) : Prop :=
  ∀ s, P s → match m s with
    | .ok a s' => Q a s'
    | .error e s' => E e s'

namespace Hoare
variable {ε σ α β : Type}

theorem conseq {P P' : σ → Prop} {m : EStateM ε σ α} {Q Q' : α → σ → Prop} {E E' : ε → σ → Prop}
    (h : Hoare P m Q E) (hp : ∀ s, P' s → P s) (hq : ∀ a s, Q a s → Q' a s) (he : ∀ e s, E e s → E' e s) :
    Hoare P' m Q' E' := fun s hs => by
  have := h s (hp s hs)
  revert this
  cases m s with
  | ok a s' => exact hq a s'
  | error e s' => exact he e s'

theorem pure' {P : σ → Prop} {a : α} {Q : α → σ → Prop} {E : ε → σ → Prop} (h : ∀ s, P s → Q a s) :
    Hoare P (pure a : EStateM ε σ α) Q E := fun s hs => h s hs

theorem throw' {P : σ → Prop} {e : ε} {Q : α → σ → Prop} {E : ε → σ → Prop} (h : ∀ s, P s → E e s) :
    Hoare P (throw e : EStateM ε σ α) Q E := fun s hs => h s hs

theorem bind' {P : σ → Prop} {m : EStateM ε σ α} {f : α → EStateM ε σ β} {R : α → σ → Prop} {Q : β → σ → Prop}
    {E : ε → σ → Prop} (hm : Hoare P m R E) (hf : ∀ a, Hoare (R a) (f a) Q E) : Hoare P (m >>= f) Q E := fun s hs => by
  have := hm s hs
  show match (m >>= f) s with | .ok a s' => Q a s' | .error e s' => E e s'
  simp only [bind, EStateM.bind]
  split at this <;> rename_i heq <;> simp only [heq]
  · exact hf _ _ this
  · exact this

theorem ite' {P : σ → Prop} {c : Prop} [Decidable c] {t e : EStateM ε σ α} {Q : α → σ → Prop} {E : ε → σ → Prop}
    (ht : c → Hoare P t Q E) (he : ¬ c → Hoare P e Q E) : Hoare P (if c then t else e) Q E := by
  by_cases h : c
  · simp only [h, ite_true]; exact ht h
  · simp only [h, ite_false]; exact he h

theorem of_eq {P : σ → Prop} {m m' : EStateM ε σ α} {Q : α → σ → Prop} {E : ε → σ → Prop} (h : m = m')
    (hm : Hoare P m' Q E) : Hoare P m Q E := h ▸ hm

/-- `for x in xs do`（`forIn` のリスト）。不変条件 `I 処理済み 累積値 状態`。本体は `done`（`break`）を返さないとする。 -/
theorem forIn' {γ : Type} (xs : List β) (b : γ) (f : β → γ → EStateM ε σ (ForInStep γ))
    (I : List β → γ → σ → Prop) {E : ε → σ → Prop}
    (step : ∀ pre x suf acc, pre ++ x :: suf = xs →
      Hoare (I pre acc) (f x acc) (fun r s => ∃ acc', r = .yield acc' ∧ I (pre ++ [x]) acc' s) E) :
    Hoare (I [] b) (forIn xs b f) (fun r s => I xs r s) E := by
  suffices h : ∀ pre suf acc, pre ++ suf = xs →
      Hoare (I pre acc) (forIn suf acc f) (fun r s => I xs r s) E by
    simpa using h [] xs b rfl
  intro pre suf
  induction suf generalizing pre with
  | nil =>
    intro acc h s hs
    simp only [List.append_nil] at h
    subst h
    exact hs
  | cons x suf ih =>
    intro acc h
    rw [List.forIn_cons]
    refine bind' (step pre x suf acc h) fun r => ?_
    intro s ⟨acc', hr, hs⟩
    subst hr
    exact ih (pre ++ [x]) acc' (by simpa using h) s hs

/-- 累積値の無い `for x in xs do`（`forIn` のリスト）。不変条件 `I 処理済みの件数 状態`。`j` 番目の要素 `x` の本体は、
`I j` から `I (j + 1)` に進めて次へ進む。 -/
theorem forIn_idx (xs : List β) (f : β → PUnit → EStateM ε σ (ForInStep PUnit)) (I : Nat → σ → Prop)
    {E : ε → σ → Prop}
    (step : ∀ j x, xs[j]? = some x → Hoare (I j) (f x ()) (fun r s => r = .yield () ∧ I (j + 1) s) E) :
    Hoare (I 0) (forIn xs () f) (fun _ s => I xs.length s) E := by
  have h := forIn' xs () f (fun pre _ s => I pre.length s) (E := E) fun pre x suf acc hxs => by
    have hx : xs[pre.length]? = some x := by rw [← hxs]; simp
    refine conseq (step pre.length x hx) (fun _ h => h) (fun r s ⟨hr, hs⟩ => ⟨(), ?_, ?_⟩) (fun _ _ h => h)
    · cases acc; exact hr
    · simpa using hs
  exact h

theorem get' {P : σ → Prop} {Q : σ → σ → Prop} {E : ε → σ → Prop} (h : ∀ s, P s → Q s s) :
    Hoare P (get : EStateM ε σ σ) Q E := fun s hs => h s hs

theorem set' {P : σ → Prop} {s' : σ} {Q : Unit → σ → Prop} {E : ε → σ → Prop} (h : ∀ s, P s → Q () s') :
    Hoare P (set s' : EStateM ε σ Unit) Q E := fun s hs => h s hs

theorem modifyGet' {P : σ → Prop} {f : σ → α × σ} {Q : α → σ → Prop} {E : ε → σ → Prop}
    (h : ∀ s, P s → Q (f s).1 (f s).2) : Hoare P (modifyGet f : EStateM ε σ α) Q E := fun s hs => h s hs

/-- 純粋な結果の持ち上げ（`match r with | .ok a => pure a | .error e => throw e`）。 -/
theorem liftExcept' {P : σ → Prop} {r : Except ε α} {Q : α → σ → Prop} {E : ε → σ → Prop}
    (hok : ∀ a, r = .ok a → ∀ s, P s → Q a s) (herr : ∀ e, r = .error e → ∀ s, P s → E e s) :
    Hoare P (match r with | .ok a => pure a | .error e => throw e : EStateM ε σ α) Q E := by
  cases r with
  | ok a => exact pure' (hok a rfl)
  | error e => exact throw' (herr e rfl)

/-- 例外の捕捉（`tryCatch`）。本体の例外の事後条件 `R` から、捕捉した処理の三つ組で続ける。 -/
theorem tryCatch' {P : σ → Prop} {m : EStateM ε σ α} {h : ε → EStateM ε σ α} {R : ε → σ → Prop}
    {Q : α → σ → Prop} {E : ε → σ → Prop} (hm : Hoare P m Q R) (hh : ∀ e, Hoare (R e) (h e) Q E) :
    Hoare P (tryCatch m h) Q E := fun s hs => by
  have := hm s hs
  show match EStateM.tryCatch m h s with | .ok a s' => Q a s' | .error e s' => E e s'
  unfold EStateM.tryCatch
  revert this
  cases m s with
  | ok a s' => exact id
  | error e s' => exact fun hr => by simpa [EStateM.Backtrackable.restore, EStateM.Backtrackable.save, EStateM.dummyRestore, EStateM.dummySave] using hh e s' hr

/-- 三つ組から、実行の結果の性質を取り出す。 -/
theorem run {P : σ → Prop} {m : EStateM ε σ α} {Q : α → σ → Prop} {E : ε → σ → Prop} (h : Hoare P m Q E)
    {s : σ} (hs : P s) : match m.run s with | .ok a s' => Q a s' | .error e s' => E e s' := h s hs

end Hoare

end LangSemantics.Core.EStateHoare
