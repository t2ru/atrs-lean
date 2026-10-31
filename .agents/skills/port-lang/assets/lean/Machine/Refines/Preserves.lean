import Machine.Refines
import Machine.Machine.Preserves
import Machine.Glue.Preserves

/-!
# Machine.Refines.Preserves

束 `Machine.Preserves`（A preserves B）の成分のうち、リファインメントの 3 者（A・C・g）に関わる述語（references/docs/spec/architecture.md#空虚化を防ぐ義務）: `InitSurj`・`EnvWitness`・`NoFaultReachable`・`Pinned`・`StateSafe`・`StateSafeConcrete`。
どれも `Refines` を含まない。ドット記法のため、型 `Machine.Refines` の名前空間に置く（E1）。
-/

namespace Machine

variable {σ τ ιa ιc οa οc ε E F : Type}

/-! ## 束 `Preserves` の成分 -/

namespace Refines

variable {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc}

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

end Refines

end Machine
