import Machine.Adequacy

/-!
# Machine.Sum

機械の並置（references/docs/spec/architecture.md#リファインメントb-メソッド）。

各機能の機械を並べて、トップレベルの機械を作る。入力は和型で、どちらかの機能を 1 歩動かす。状態は積で、
動かさない側の状態は変わらない。抽象機械・具体機械・貼り合わせをそれぞれ並べると、リファインメントと
義務の束 `Machine.Adequate` は保たれる（`Refines.sum`・`Adequate.sum`）。

| 定義・定理 | 内容 |
| --- | --- |
| `Machine.sum`・`Concrete.sum`・`Glue.sum` | 抽象機械・具体機械・貼り合わせの並置 |
| `Machine.sumPred` | 入力の述語の並置（前提型の差異・環境の前提を並べる） |
| `Refines.sum`・`Adequate.sum` | 並置はリファインメントと義務の束を保つ |
| `Adequate.congrPre` | PRE と具体側の定義域を、各点で同値なものに替えても束は保たれる（並置した制限と、制限の並置を結ぶ） |

トップレベルの主定理は、次の形をとる。

```lean
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem adequate : Machine.Adequate (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue s₀ env
```
-/

namespace Machine

variable {σ₁ σ₂ τ₁ τ₂ ι₁ ι₂ ιc₁ ιc₂ ο₁ ο₂ οc₁ οc₂ ε : Type}

/-- 入力の述語の並置。 -/
def sumPred {α β : Type} (P : α → Prop) (Q : β → Prop) : α ⊕ β → Prop
  | .inl a => P a
  | .inr b => Q b

namespace Machine

/-- 抽象機械の並置: 入力 `inl` は左の機械を、`inr` は右の機械を 1 歩動かす。 -/
def sum (A₁ : Machine σ₁ ι₁ ο₁) (A₂ : Machine σ₂ ι₂ ο₂) : Machine (σ₁ × σ₂) (ι₁ ⊕ ι₂) (ο₁ ⊕ ο₂) where
  Inv s := A₁.Inv s.1 ∧ A₂.Inv s.2
  Init s := A₁.Init s.1 ∧ A₂.Init s.2
  Pre s i := match i with
    | .inl j => A₁.Pre s.1 j
    | .inr j => A₂.Pre s.2 j
  step s i s' o := match i, o with
    | .inl j, .inl o => A₁.step s.1 j s'.1 o ∧ s'.2 = s.2
    | .inr j, .inr o => A₂.step s.2 j s'.2 o ∧ s'.1 = s.1
    | _, _ => False
  run s i := match i with
    | .inl j => (((A₁.run s.1 j).1, s.2), .inl (A₁.run s.1 j).2)
    | .inr j => ((s.1, (A₂.run s.2 j).1), .inr (A₂.run s.2 j).2)
  run_step s i h := by
    cases i with
    | inl j => exact ⟨A₁.run_step s.1 j h, rfl⟩
    | inr j => exact ⟨A₂.run_step s.2 j h, rfl⟩

theorem Sound.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} (h₁ : A₁.Sound) (h₂ : A₂.Sound) :
    (A₁.sum A₂).Sound where
  init_inv s h := ⟨h₁.init_inv _ h.1, h₂.init_inv _ h.2⟩
  step_inv s i s' o hi hp hs := by
    match i, o, hs with
    | .inl j, .inl o, ⟨hs, he⟩ => exact ⟨h₁.step_inv _ j _ o hi.1 hp hs, he ▸ hi.2⟩
    | .inr j, .inr o, ⟨hs, he⟩ => exact ⟨he ▸ hi.1, h₂.step_inv _ j _ o hi.2 hp hs⟩

theorem InitIs.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} {s₁ : σ₁} {s₂ : σ₂} (h₁ : A₁.InitIs s₁)
    (h₂ : A₂.InitIs s₂) : (A₁.sum A₂).InitIs (s₁, s₂) := fun s => by
  show A₁.Init s.1 ∧ A₂.Init s.2 ↔ s = (s₁, s₂)
  rw [h₁ s.1, h₂ s.2]
  obtain ⟨a, b⟩ := s
  simp

theorem TotalUnder.sum {A₁ : Machine σ₁ ι₁ ο₁} {A₂ : Machine σ₂ ι₂ ο₂} {E₁ : ι₁ → Prop} {E₂ : ι₂ → Prop}
    (h₁ : A₁.TotalUnder E₁) (h₂ : A₂.TotalUnder E₂) : (A₁.sum A₂).TotalUnder (sumPred E₁ E₂) := fun s i hi he => by
  cases i with
  | inl j => exact h₁ s.1 j hi.1 he
  | inr j => exact h₂ s.2 j hi.2 he

end Machine

namespace Concrete

/-- 具体機械の並置。正常終了でない結果（`ε`）は、動かした側の結果をそのまま返す。 -/
def sum (C₁ : Concrete τ₁ ιc₁ οc₁ ε) (C₂ : Concrete τ₂ ιc₂ οc₂ ε) : Concrete (τ₁ × τ₂) (ιc₁ ⊕ ιc₂) (οc₁ ⊕ οc₂) ε where
  Init t := C₁.Init t.1 ∧ C₂.Init t.2
  Dom := sumPred C₁.Dom C₂.Dom
  step t i r := match i, r with
    | .inl j, .ok (t', .inl o) => C₁.step t.1 j (.ok (t'.1, o)) ∧ t'.2 = t.2
    | .inr j, .ok (t', .inr o) => C₂.step t.2 j (.ok (t'.2, o)) ∧ t'.1 = t.1
    | .inl j, .error e => C₁.step t.1 j (.error e)
    | .inr j, .error e => C₂.step t.2 j (.error e)
    | _, _ => False

end Concrete

namespace Glue

/-- 貼り合わせの並置。和の左右が食い違う入力・出力は対応しない。 -/
def sum {σ₁ σ₂ τ₁ τ₂ ιa₁ ιa₂ ιc₁ ιc₂ οa₁ οa₂ οc₁ οc₂ : Type} (g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁)
    (g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂) : Glue (σ₁ × σ₂) (τ₁ × τ₂) (ιa₁ ⊕ ιa₂) (ιc₁ ⊕ ιc₂) (οa₁ ⊕ οa₂) (οc₁ ⊕ οc₂) where
  J s t := g₁.J s.1 t.1 ∧ g₂.J s.2 t.2
  αi c a := match c, a with
    | .inl c, .inl a => g₁.αi c a
    | .inr c, .inr a => g₂.αi c a
    | _, _ => False
  αo c a := match c, a with
    | .inl c, .inl a => g₁.αo c a
    | .inr c, .inr a => g₂.αo c a
    | _, _ => False

end Glue

namespace Refines

variable {ιa₁ ιa₂ οa₁ οa₂ : Type} {A₁ : Machine σ₁ ιa₁ οa₁} {A₂ : Machine σ₂ ιa₂ οa₂}
  {C₁ : Concrete τ₁ ιc₁ οc₁ ε} {C₂ : Concrete τ₂ ιc₂ οc₂ ε}
  {g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂}

/-- 並置はリファインメントを保つ。 -/
theorem sum (h₁ : Refines A₁ C₁ g₁) (h₂ : Refines A₂ C₂ g₂) : Refines (A₁.sum A₂) (C₁.sum C₂) (g₁.sum g₂) where
  init t ht := by
    obtain ⟨s₁, hs₁, hJ₁⟩ := h₁.init t.1 ht.1
    obtain ⟨s₂, hs₂, hJ₂⟩ := h₂.init t.2 ht.2
    exact ⟨(s₁, s₂), ⟨hs₁, hs₂⟩, hJ₁, hJ₂⟩
  input_total ic hd := by
    cases ic with
    | inl c => obtain ⟨a, ha⟩ := h₁.input_total c hd; exact ⟨.inl a, ha⟩
    | inr c => obtain ⟨a, ha⟩ := h₂.input_total c hd; exact ⟨.inr a, ha⟩
  applicable s t ic ia hi hJ ha hp hd := by
    match ic, ia, ha with
    | .inl c, .inl a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₁.applicable s.1 t.1 c a hi.1 hJ.1 ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok ((t', t.2), .inl o), hr, rfl⟩
      | .error e, hr => exact ⟨.error e, hr⟩
    | .inr c, .inr a, ha =>
      obtain ⟨⟨r, hr⟩, hne⟩ := h₂.applicable s.2 t.2 c a hi.2 hJ.2 ha hp hd
      refine ⟨?_, fun e he => hne e he⟩
      match r, hr with
      | .ok (t', o), hr => exact ⟨.ok ((t.1, t'), .inr o), hr, rfl⟩
      | .error e, hr => exact ⟨.error e, hr⟩
  correct s t ic ia t' oc hi hJ ha hp hd hs := by
    match ic, ia, oc, ha, hs with
    | .inl c, .inl a, .inl o, ha, ⟨hs, he⟩ =>
      obtain ⟨s₁', oa, hst, hJ', ho⟩ := h₁.correct s.1 t.1 c a t'.1 o hi.1 hJ.1 ha hp hd hs
      exact ⟨(s₁', s.2), .inl oa, ⟨hst, rfl⟩, ⟨hJ', he ▸ hJ.2⟩, ho⟩
    | .inr c, .inr a, .inr o, ha, ⟨hs, he⟩ =>
      obtain ⟨s₂', oa, hst, hJ', ho⟩ := h₂.correct s.2 t.2 c a t'.2 o hi.2 hJ.2 ha hp hd hs
      exact ⟨(s.1, s₂'), .inr oa, ⟨hst, rfl⟩, ⟨he ▸ hJ.1, hJ'⟩, ho⟩

end Refines

namespace Adequate

variable {ιa₁ ιa₂ οa₁ οa₂ : Type} {A₁ : Machine σ₁ ιa₁ οa₁} {A₂ : Machine σ₂ ιa₂ οa₂}
  {C₁ : Concrete τ₁ ιc₁ οc₁ ε} {C₂ : Concrete τ₂ ιc₂ οc₂ ε}
  {g₁ : Glue σ₁ τ₁ ιa₁ ιc₁ οa₁ οc₁} {g₂ : Glue σ₂ τ₂ ιa₂ ιc₂ οa₂ οc₂}
  {s₁ : σ₁} {s₂ : σ₂} {E₁ : ιa₁ → Prop} {E₂ : ιa₂ → Prop}

/-- 並置は義務の束を保つ。 -/
theorem sum (h₁ : Adequate A₁ C₁ g₁ s₁ E₁) (h₂ : Adequate A₂ C₂ g₂ s₂ E₂) :
    Adequate (A₁.sum A₂) (C₁.sum C₂) (g₁.sum g₂) (s₁, s₂) (sumPred E₁ E₂) where
  refines := h₁.refines.sum h₂.refines
  sound := h₁.sound.sum h₂.sound
  initIs := h₁.initIs.sum h₂.initIs
  initSurj s hs := by
    obtain ⟨t₁, ht₁, hJ₁⟩ := h₁.initSurj s.1 hs.1
    obtain ⟨t₂, ht₂, hJ₂⟩ := h₂.initSurj s.2 hs.2
    exact ⟨(t₁, t₂), ⟨ht₁, ht₂⟩, hJ₁, hJ₂⟩
  total := h₁.total.sum h₂.total
  envWitness := by
    obtain ⟨c, a, hd, ha, he⟩ := h₁.envWitness
    exact ⟨.inl c, .inl a, hd, ha, he⟩
  envNeeded := by
    have hi₁ := h₁.initIs.inv h₁.sound
    have hi₂ := h₂.initIs.inv h₂.sound
    rcases h₁.envNeeded with e₁ | n₁
    · rcases h₂.envNeeded with e₂ | n₂
      · left
        funext i
        cases i <;> simp [sumPred, e₁, e₂, always]
      · right
        intro h
        exact n₂ fun s i hi _ => h (s₁, s) (.inr i) ⟨hi₁, hi⟩ trivial
    · right
      intro h
      exact n₁ fun s i hi _ => h (s, s₂) (.inl i) ⟨hi, hi₂⟩ trivial

/-- PRE と具体側の定義域を、各点で同値なものに替えても、義務の束は保たれる。INV・初期状態・歩みは同じものとする。
並置した機械の制限（`(A₁.sum A₂).restrict (sumPred P₁ P₂)`）と、制限した機械の並置を結ぶのに使う。 -/
theorem congrPre {σ τ ιa ιc οa οc : Type} {A A' : Machine σ ιa οa} {C C' : Concrete τ ιc οc ε}
    {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : ιa → Prop} (h : Adequate A C g s₀ Env)
    (hInv : A'.Inv = A.Inv) (hInit : A'.Init = A.Init) (hstep : A'.step = A.step)
    (hPre : ∀ s i, A'.Pre s i ↔ A.Pre s i) (hCInit : C'.Init = C.Init) (hCstep : C'.step = C.step)
    (hDom : ∀ i, C'.Dom i ↔ C.Dom i) : Adequate A' C' g s₀ Env where
  refines :=
    { init := fun t ht => by
        obtain ⟨s, hs, hJ⟩ := h.refines.init t (hCInit ▸ ht)
        exact ⟨s, hInit ▸ hs, hJ⟩
      input_total := fun ic hd => h.refines.input_total ic ((hDom ic).1 hd)
      applicable := fun s t ic ia hi hJ ha hp hd => by
        rw [hCstep]
        exact h.refines.applicable s t ic ia (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd)
      correct := fun s t ic ia t' oc hi hJ ha hp hd hs => by
        rw [hstep]
        exact h.refines.correct s t ic ia t' oc (hInv ▸ hi) hJ ha ((hPre s ia).1 hp) ((hDom ic).1 hd) (hCstep ▸ hs) }
  sound :=
    { init_inv := fun s hs => hInv ▸ h.sound.init_inv s (hInit ▸ hs)
      step_inv := fun s i s' o hi hp hs =>
        hInv ▸ h.sound.step_inv s i s' o (hInv ▸ hi) ((hPre s i).1 hp) (hstep ▸ hs) }
  initIs s := hInit ▸ h.initIs s
  initSurj s hs := by
    obtain ⟨t, ht, hJ⟩ := h.initSurj s (hInit ▸ hs)
    exact ⟨t, hCInit ▸ ht, hJ⟩
  total s i hi he := (hPre s i).2 (h.total s i (hInv ▸ hi) he)
  envWitness := by
    obtain ⟨c, a, hd, ha, he⟩ := h.envWitness
    exact ⟨c, a, (hDom c).2 hd, ha, he⟩
  envNeeded := by
    rcases h.envNeeded with e | n
    · exact .inl e
    · exact .inr fun hT => n fun s i hi he => (hPre s i).1 (hT s i (hInv ▸ hi) he)

end Adequate

end Machine
