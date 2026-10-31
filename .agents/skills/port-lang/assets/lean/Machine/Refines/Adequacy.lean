import Machine.Refines
import Machine.Machine.Adequacy
import Machine.Concrete.Adequacy
import Machine.Glue.Adequacy

/-!
# Machine.Refines.Adequacy

リファインメントの付帯の義務（references/docs/spec/architecture.md#空虚化を防ぐ義務）: `InitSurj`・`Pinned`・`NoFaultReachable`・`EnvWitness`・`StateSafe`、1 歩の可換式 `complete`、複数歩の模倣 `run`。
-/

namespace Machine

open Machine.Adequacy

variable {σ τ ιa ιc οa οc ε E F : Type}

/-! ## リファインメントの付帯の義務 -/

namespace Refines

variable {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc}

/-- 各点で同値な貼り合わせに付け替えても、リファインメントは保たれる。 -/
theorem congr {g' : Glue σ τ ιa ιc οa οc} (h : Refines A C g) (e : g.Equiv g') : Refines A C g' where
  init t ht := by
    obtain ⟨s, hs, hJ⟩ := h.init t ht
    exact ⟨s, hs, (e.J s t).1 hJ⟩
  input_total ic hd := by
    obtain ⟨ia, ha⟩ := h.input_total ic hd
    exact ⟨ia, (e.αi ic ia).1 ha⟩
  applicable s t ic ia hi hJ ha hp hd :=
    h.applicable s t ic ia hi ((e.J s t).2 hJ) ((e.αi ic ia).2 ha) hp hd
  correct s t ic ia t' oc hi hJ ha hp hd hs := by
    obtain ⟨s', oa, hst, hJ', ho⟩ :=
      h.correct s t ic ia t' oc hi ((e.J s t).2 hJ) ((e.αi ic ia).2 ha) hp hd hs
    exact ⟨s', oa, hst, (e.J s' t').1 hJ', (e.αo oc oa).1 ho⟩

/-- 初期化の全射性: 抽象側の各初期状態に、`J` で結ばれる具体側の初期状態がある。 -/
def InitSurj (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) : Prop :=
  ∀ s, A.Init s → ∃ t, C.Init t ∧ g.J s t

/-- 障害の無い環境での実現: 具体側の入力 `ic` の抽象側の像 `ia` は、環境が標準 `e₀` の具体側の入力 `ic'` でも
実現される。`ce` が障害でない入力を障害の環境へ写すこと（`Pinned` の悪用）を防ぐ。 -/
def NoFaultReachable (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (ce : ιc → E) (e₀ : E) : Prop :=
  ∀ ic ia, C.Dom ic → g.αi ic ia → ∃ ic', C.Dom ic' ∧ g.αi ic' ia ∧ ce ic' = e₀

/-- 環境の前提の非空虚性: 環境の前提 `Env` を満たす像を持つ、具体側の入力がある。 -/
def EnvWitness (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (Env : ιa → Prop) : Prop :=
  ∃ ic ia, C.Dom ic ∧ g.αi ic ia ∧ Env ia

/-- 環境の固定: 具体側の任意の正常終了は、環境の選択を具体側の入力の環境 `ce ic` に固定した `f` の結果の
どれかで模倣される。`f` は抽象側の基底の機械（`Machine.ofChoice`）の `f` である。 -/
def Pinned (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc)
    (f : σ → ιa → E × F → σ × οa) (ce : ιc → E) : Prop :=
  ∀ s t ic ia t' oc, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → C.Dom ic →
    C.step t ic (.ok (t', oc)) → ∃ x, g.J (f s ia (ce ic, x)).1 t' ∧ g.αo oc (f s ia (ce ic, x)).2

/-! ### 成分の必要性の証人（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- PRE の下で具体側が正常終了しない証人があれば、リファインメントは成り立たない（適用可能性が破れる）。 -/
theorem not_of_error {s : σ} {t : τ} {ic : ιc} {ia : ιa} {e : ε} (hi : A.Inv s) (hJ : g.J s t)
    (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic) (he : C.step t ic (.error e)) :
    ¬ Refines A C g :=
  fun h => (h.applicable s t ic ia hi hJ ha hpre hd).2 e he

/-- PRE の下で具体側が結果を持たない（行き詰まる・停止しない）証人があれば、リファインメントは成り立たない。 -/
theorem not_of_stuck {s : σ} {t : τ} {ic : ιc} {ia : ιa} (hi : A.Inv s) (hJ : g.J s t)
    (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic) (hn : ∀ r, ¬ C.step t ic r) :
    ¬ Refines A C g := fun h => by
  obtain ⟨r, hr⟩ := (h.applicable s t ic ia hi hJ ha hpre hd).1
  exact hn r hr

/-- 具体側の正常終了を、抽象側のどの歩みも `J`・`αo` で模倣できない証人があれば、リファインメントは
成り立たない（正しさが破れる）。 -/
theorem not_of_mismatch {s : σ} {t : τ} {ic : ιc} {ia : ιa} {t' : τ} {oc : οc} (hi : A.Inv s)
    (hJ : g.J s t) (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic)
    (hs : C.step t ic (.ok (t', oc))) (hm : ∀ s' oa, A.step s ia s' oa → g.J s' t' → ¬ g.αo oc oa) :
    ¬ Refines A C g := fun h => by
  obtain ⟨s', oa, hst, hJ', ho⟩ := h.correct s t ic ia t' oc hi hJ ha hpre hd hs
  exact hm s' oa hst hJ' ho

/-- 具体側の正常終了を、環境を `ce ic` に固定したどの `f` の結果とも対応づけられない証人があれば、
環境の固定は成り立たない。 -/
theorem Pinned.not_of_mismatch {f : σ → ιa → E × F → σ × οa} {ce : ιc → E} {s : σ} {t : τ} {ic : ιc}
    {ia : ιa} {t' : τ} {oc : οc} (hi : A.Inv s) (hJ : g.J s t) (ha : g.αi ic ia) (hpre : A.Pre s ia)
    (hd : C.Dom ic) (hs : C.step t ic (.ok (t', oc)))
    (hm : ∀ x, g.J (f s ia (ce ic, x)).1 t' → ¬ g.αo oc (f s ia (ce ic, x)).2) :
    ¬ Pinned A C g f ce := fun h => by
  obtain ⟨x, hJ', ho⟩ := h s t ic ia t' oc hi hJ ha hpre hd hs
  exact hm x hJ' ho

/-- `f` の結果が抽象側の `step` に含まれるなら、環境の固定は正しさの義務を含意する。 -/
theorem Pinned.correct {f : σ → ιa → E × F → σ × οa} {ce : ιc → E} (hp : Pinned A C g f ce)
    (hf : ∀ s i c, A.Pre s i → A.step s i (f s i c).1 (f s i c).2) :
    ∀ s t ic ia t' oc, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → C.Dom ic →
      C.step t ic (.ok (t', oc)) → ∃ s' oa, A.step s ia s' oa ∧ g.J s' t' ∧ g.αo oc oa :=
  fun s t ic ia t' oc hi hJ ha hpre hd hs => by
    obtain ⟨x, hJ', ho⟩ := hp s t ic ia t' oc hi hJ ha hpre hd hs
    exact ⟨_, _, hf s ia (ce ic, x) hpre, hJ', ho⟩

/-- `Machine.ofChoice` の `f` の結果は、その機械の `step` に含まれる。 -/
theorem ofChoice_f_step {Inv Init : σ → Prop} {Pre : σ → ιa → Prop} {f : σ → ιa → E × F → σ × οa}
    {e₀ : E} {f₀ : F} (s : σ) (i : ιa) (c : E × F) :
    (Machine.ofChoice Inv Init Pre f e₀ f₀).step s i (f s i c).1 (f s i c).2 := ⟨c, rfl⟩

/-- 1 歩の可換式（完全性）: PRE の下で、具体側は必ず結果を持ち、どの結果も正常終了で、環境を固定した
`f` の結果のどれかと `J`・`αo` で対応する。障害の無い環境（`ce ic = e₀`）では、自由な選択を除いて
標準の選択と一致する。 -/
theorem complete {f : σ → ιa → E × F → σ × οa} {ce : ιc → E} (h : Refines A C g)
    (hp : Pinned A C g f ce) {s : σ} {t : τ} {ic : ιc} {ia : ιa} (hi : A.Inv s) (hJ : g.J s t)
    (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic) :
    (∃ r, C.step t ic r) ∧ ∀ r, C.step t ic r → ∃ t' oc, r = .ok (t', oc) ∧
      ∃ x, g.J (f s ia (ce ic, x)).1 t' ∧ g.αo oc (f s ia (ce ic, x)).2 := by
  obtain ⟨hex, hne⟩ := h.applicable s t ic ia hi hJ ha hpre hd
  refine ⟨hex, fun r hr => ?_⟩
  match r, hr with
  | .error e, hr => exact absurd hr (hne e)
  | .ok (t', oc), hr => exact ⟨t', oc, rfl, hp s t ic ia t' oc hi hJ ha hpre hd hr⟩

/-- 状態の安全性（抽象側の述語の差異）: 基底の機械 `A` の PRE を満たし、差異の前提 `P` を破る入力でも、
具体側の正常終了の後の状態は、抽象側のある歩みと `J` で結ばれる（出力は問わない）。
出力のみの前提型の差異に課す。 -/
def StateSafe (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc)
    (P : σ → ιa → Prop) : Prop :=
  ∀ s t ic ia t' oc, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → ¬ P s ia → C.Dom ic →
    C.step t ic (.ok (t', oc)) → ∃ s' o, A.step s ia s' o ∧ g.J s' t'

/-- 状態の安全性（具体側だけにある入力の述語の差異）。`C` は制限する前の具体機械である。 -/
def StateSafeConcrete (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc)
    (P : ιc → Prop) : Prop :=
  ∀ s t ic ia t' oc, A.Inv s → g.J s t → g.αi ic ia → A.Pre s ia → ¬ P ic → C.Dom ic →
    C.step t ic (.ok (t', oc)) → ∃ s' o, A.step s ia s' o ∧ g.J s' t'

/-- 複数歩の模倣: 抽象機械が `Sound` で、入口の全域性 `TotalUnder Env` が成り立つとき、各入力が定義域と
環境の前提を満たす具体側の正常終了の列は、PRE を満たす抽象側の歩みの列で模倣される。 -/
theorem run (hS : A.Sound) (h : Refines A C g) {Env : ιa → Prop} (hT : A.TotalUnder Env)
    {s : σ} {t : τ} {ics : List ιc} {t' : τ} {ocs : List οc} (hi : A.Inv s) (hJ : g.J s t)
    (hr : C.Run t ics t' ocs) (hin : ∀ ic, ic ∈ ics → C.Dom ic ∧ ∀ ia, g.αi ic ia → Env ia) :
    ∃ ias s' oas, Forall₂ g.αi ics ias ∧ A.Run s ias s' oas ∧ g.J s' t' ∧ A.Inv s' ∧
      Forall₂ g.αo ocs oas := by
  induction hr generalizing s with
  | nil t => exact ⟨[], s, [], .nil, .nil s, hJ, hi, .nil⟩
  | @cons t ic t₁ oc ics t₂ ocs hs _ ih =>
    obtain ⟨hd, he⟩ := hin ic (List.Mem.head _)
    obtain ⟨ia, ha⟩ := h.input_total ic hd
    have hpre := hT s ia hi (he ia ha)
    obtain ⟨s₁, oa, hst, hJ₁, ho⟩ := h.correct s t ic ia t₁ oc hi hJ ha hpre hd hs
    have hi₁ := hS.step_inv s ia s₁ oa hi hpre hst
    obtain ⟨ias, s', oas, hai, hrun, hJ', hi', hao⟩ :=
      ih hi₁ hJ₁ fun ic' hm => hin ic' (List.Mem.tail _ hm)
    exact ⟨ia :: ias, s', oa :: oas, .cons ha hai, .cons hpre hst hrun, hJ', hi', .cons ho hao⟩

end Refines

end Machine
