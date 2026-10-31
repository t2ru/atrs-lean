import Machine.Concrete

/-!
# Machine.Refines

具体機械が抽象機械をリファインすること（B メソッドの refinement）と、その証明義務（ADR 01d4）。

| ADR 01d4 の証明義務 | `Refines` の成分 |
| --- | --- |
| INIT | `init` |
| 入力の全域性 | `input_total` |
| 適用可能性 | `applicable` |
| 正しさ | `correct` |

- 抽象側の非決定性は、具体側で減らしてよい（`correct` は抽象側の結果を 1 つ示せばよい）。
- 具体側の非決定性は、そのすべての分岐が `correct` で模倣されなければならない。具体側が抽象側より
  大きな非決定性を持つと、`Refines` は成り立たない（`MachineTest.Nondet` の反例）。
- 差異は、前提型なら `Machine.restrict`・`Machine.restrictState`（抽象側の PRE を強める）と
  `Concrete.restrict`（具体側の入力を制限する）の述語として、観測型なら `Glue` の `J`・`αo` の
  名前付きの成分として現れる。述語・成分に `@[deviation]` を付けるのは利用側（`Abstraction`・`Refinement`）である。
-/

namespace Machine

/-- 貼り合わせ。抽象側の状態 σ・入力 ιa・出力 οa と、具体側の状態 τ・入力 ιc・出力 οc の関係。

- `J s t`: 貼り合わせ不変条件（抽象化関数 α/β を含む関係）
- `αi ic ia`: 入力の対応
- `αo oc oa`: 出力の対応 -/
structure Glue (σ τ ιa ιc οa οc : Type) where
  J : σ → τ → Prop
  αi : ιc → ιa → Prop
  αo : οc → οa → Prop

namespace Glue

/-- 恒等の貼り合わせ。 -/
def id (σ ι ο : Type) : Glue σ σ ι ι ο ο where
  J s t := s = t
  αi c a := c = a
  αo c a := c = a

/-- 状態を持たない機械どうしの貼り合わせ。 -/
def pure {ιa ιc οa οc : Type} (αi : ιc → ιa → Prop) (αo : οc → οa → Prop) :
    Glue Unit Unit ιa ιc οa οc where
  J _ _ := True
  αi := αi
  αo := αo

/-- 貼り合わせの合成。中間の状態には、中間の機械の不変条件 `invM` を課す。 -/
def comp {σ μ τ ιa ιb ιc οa οb οc : Type} (g₁ : Glue σ μ ιa ιb οa οb) (g₂ : Glue μ τ ιb ιc οb οc)
    (invM : μ → Prop) : Glue σ τ ιa ιc οa οc where
  J s t := ∃ m, g₁.J s m ∧ g₂.J m t ∧ invM m
  αi ic ia := ∃ ib, g₂.αi ic ib ∧ g₁.αi ib ia
  αo oc oa := ∃ ob, g₂.αo oc ob ∧ g₁.αo ob oa

end Glue

/-- 具体機械 `C` が、貼り合わせ `g` の下で抽象機械 `A` をリファインする。 -/
structure Refines {σ τ ιa ιc οa οc ε : Type} (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε)
    (g : Glue σ τ ιa ιc οa οc) : Prop where
  /-- INIT: 具体側の任意の初期状態に、`J` で結ばれる抽象側の初期状態がある。 -/
  init : ∀ t, C.Init t → ∃ s, A.Init s ∧ g.J s t
  /-- 入力の全域性: 具体側の定義域の任意の入力に、`αi` の像がある。 -/
  input_total : ∀ ic, C.Dom ic → ∃ ia, g.αi ic ia
  /-- 適用可能性: 具体側の操作は結果を持ち、どの結果も正常終了である。 -/
  applicable : ∀ s t ic ia, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → C.Dom ic →
    (∃ r, C.step t ic r) ∧ ∀ e, ¬ C.step t ic (.error e)
  /-- 正しさ: 具体側の任意の正常終了が、抽象側のある結果で模倣される。 -/
  correct : ∀ s t ic ia t' oc, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → C.Dom ic →
    C.step t ic (.ok (t', oc)) → ∃ s' oa, A.step s ia s' oa ∧ g.J s' t' ∧ g.αo oc oa

namespace Refines

variable {σ μ τ ιa ιb ιc οa οb οc ε : Type}

/-- 抽象側の PRE を強めても、リファインメントは保たれる。 -/
theorem restrictState {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc}
    (h : Refines A C g) (P : σ → ιa → Prop) : Refines (A.restrictState P) C g where
  init := h.init
  input_total := h.input_total
  applicable s t ic ia hi hJ ha hp hd := h.applicable s t ic ia hi hJ ha hp.1 hd
  correct s t ic ia t' oc hi hJ ha hp hd hs := h.correct s t ic ia t' oc hi hJ ha hp.1 hd hs

theorem restrict {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc}
    (h : Refines A C g) (P : ιa → Prop) : Refines (A.restrict P) C g :=
  h.restrictState _

/-- 具体側の入力を制限しても、リファインメントは保たれる。 -/
theorem restrictConcrete {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc}
    (h : Refines A C g) (P : ιc → Prop) : Refines A (C.restrict P) g where
  init := h.init
  input_total ic hd := h.input_total ic hd.1
  applicable s t ic ia hi hJ ha hp hd := h.applicable s t ic ia hi hJ ha hp hd.1
  correct s t ic ia t' oc hi hJ ha hp hd hs := h.correct s t ic ia t' oc hi hJ ha hp hd.1 hs

/-- 抽象機械は、具体機械とみなした自分自身をリファインする。 -/
theorem refl (A : Machine σ ιa οa) : Refines A A.toConcrete (Glue.id σ ιa οa) where
  init t ht := ⟨t, ht, rfl⟩
  input_total ic _ := ⟨ic, rfl⟩
  applicable s t ic ia _ hJ ha hp _ := by
    subst hJ; subst ha
    refine ⟨⟨_, Or.inl ⟨hp, _, _, rfl, A.run_step s ic hp⟩⟩, fun e h => ?_⟩
    rcases h with ⟨_, _, _, he, _⟩ | ⟨hn, _⟩
    · cases he
    · exact hn hp
  correct s t ic ia t' oc _ hJ ha _ _ hs := by
    subst hJ; subst ha
    rcases hs with ⟨_, s', o, he, hst⟩ | ⟨_, he⟩
    · cases he
      exact ⟨t', oc, hst, rfl, rfl⟩
    · cases he

/-- 具体機械とみなした中間の機械が PRE の外で前提違反になることから、PRE を取り出す。 -/
theorem pre_of_applicable {A : Machine σ ιa οa} {B : Machine μ ιb οb} {g : Glue σ μ ιa ιb οa οb}
    (h : Refines A B.toConcrete g) {s : σ} {m : μ} {ib : ιb} {ia : ιa}
    (hi : A.Inv s) (hJ : g.J s m) (ha : g.αi ib ia) (hp : A.Pre s ia) : B.Pre m ib :=
  Classical.byContradiction fun hn =>
    (h.applicable s m ib ia hi hJ ha hp trivial).2 () (Or.inr ⟨hn, rfl⟩)

/-- 推移性。中間の機械 `B` は `Spec` 自身の証明義務（`Sound`）を満たさなければならない。 -/
theorem trans {A : Machine σ ιa οa} {B : Machine μ ιb οb} {C : Concrete τ ιc οc ε}
    {g₁ : Glue σ μ ιa ιb οa οb} {g₂ : Glue μ τ ιb ιc οb οc}
    (hB : B.Sound) (h₁ : Refines A B.toConcrete g₁) (h₂ : Refines B C g₂) :
    Refines A C (g₁.comp g₂ B.Inv) where
  init t ht := by
    obtain ⟨m, hm, hJ₂⟩ := h₂.init t ht
    obtain ⟨s, hs, hJ₁⟩ := h₁.init m hm
    exact ⟨s, hs, m, hJ₁, hJ₂, hB.init_inv m hm⟩
  input_total ic hd := by
    obtain ⟨ib, hb⟩ := h₂.input_total ic hd
    obtain ⟨ia, ha⟩ := h₁.input_total ib trivial
    exact ⟨ia, ib, hb, ha⟩
  applicable s t ic ia hi hJ ha hp hd := by
    obtain ⟨m, hJ₁, hJ₂, hm⟩ := hJ
    obtain ⟨ib, hb₂, hb₁⟩ := ha
    exact h₂.applicable m t ic ib hm hJ₂ hb₂ (h₁.pre_of_applicable hi hJ₁ hb₁ hp) hd
  correct s t ic ia t' oc hi hJ ha hp hd hs := by
    obtain ⟨m, hJ₁, hJ₂, hm⟩ := hJ
    obtain ⟨ib, hb₂, hb₁⟩ := ha
    have hpb := h₁.pre_of_applicable hi hJ₁ hb₁ hp
    obtain ⟨m', ob, hsB, hJ₂', ho₂⟩ := h₂.correct m t ic ib t' oc hm hJ₂ hb₂ hpb hd hs
    obtain ⟨s', oa, hsA, hJ₁', ho₁⟩ :=
      h₁.correct s m ib ia m' ob hi hJ₁ hb₁ hp trivial (Or.inl ⟨hpb, m', ob, rfl, hsB⟩)
    exact ⟨s', oa, hsA, ⟨m', hJ₁', hJ₂', hB.step_inv m ib m' ob hm hpb hsB⟩, ob, ho₂, ho₁⟩

/-- 状態を持たない機械どうしのリファインメントは、入力の全域性と、PRE の下で具体側が正常終了して
抽象側の結果と対応することに帰着する。 -/
theorem of_pure {ιa ιc οa οc ε : Type} {Pre : ιa → Prop} {f : ιa → οa} {fc : ιc → Except ε οc}
    {αi : ιc → ιa → Prop} {αo : οc → οa → Prop}
    (htot : ∀ ic, ∃ ia, αi ic ia)
    (hok : ∀ ic ia, αi ic ia → Pre ia → ∃ oc, fc ic = .ok oc ∧ αo oc (f ia)) :
    Refines (Machine.pure Pre f) (Concrete.pure fc) (Glue.pure αi αo) where
  init _ _ := ⟨(), trivial, trivial⟩
  input_total ic _ := htot ic
  applicable _ _ ic ia _ _ ha hp _ := by
    obtain ⟨oc, he, _⟩ := hok ic ia ha hp
    refine ⟨⟨_, rfl⟩, fun e h => ?_⟩
    simp only [Concrete.pure, Concrete.ofFun, he] at h
    cases h
  correct _ _ ic ia t' oc' _ _ ha hp _ hs := by
    obtain ⟨oc, he, ho⟩ := hok ic ia ha hp
    simp only [Concrete.pure, Concrete.ofFun, he] at hs
    cases hs
    exact ⟨(), f ia, rfl, trivial, ho⟩

end Refines

end Machine
