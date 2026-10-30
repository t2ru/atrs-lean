import Machine.Refines

/-!
# Machine.Adequacy

リファインメントが空虚・自明に成り立つことを防ぐ義務（ADR 0039）。

`Refines` は「具体側の振る舞いが抽象側の許す範囲に収まる」ことしか述べない。そのため、抽象機械が緩い、
PRE が強すぎる、貼り合わせが粗い、といった場合にも成り立ってしまう。ここでは、それを塞ぐ定義を与える。

| 定義 | 内容 | 塞ぐもの |
| --- | --- | --- |
| `Machine.ofChoice` | 抽象機械の非決定性を、選択の型 `E × F` の像に限る（E は環境の選択、F は自由な選択） | 緩い `step` |
| `Refines.Pinned` | 具体側の正常終了を、E を具体側の入力の環境 `ce ic` に固定した選択で模倣する | 具体側の不具合が環境の非決定性（衝突・I/O 失敗）に紛れる |
| `Glue.ofStd` | 部分写像 β・ai・ao（標準の抽象化）と、名前付きの成分 OJ・OO だけからなる貼り合わせ | 粗い `J`・`αo`、α の部分性の消失 |
| `Refines.NoFaultReachable` | 抽象側の各入力は、障害の無い環境（`ce ic = e₀`）の具体側の入力でも実現される | `ce` の悪用（障害でない入力を障害の環境に写す） |
| `Machine.FreeFrame` | 自由な選択 F が変えうるのは、名前付きの射影 `m` が忘れる部分だけである | 自由な選択による結果の吸収 |
| `Machine.TotalUnder`・`Refines.EnvWitness` | 入口の機械の PRE は、INV と環境の前提（マスタ・設定の妥当性と入力の値域）だけで成り立つ。環境の前提を満たす具体側の入力がある | 強すぎる PRE、PRE・環境の前提の外への写し |
| `Machine.InitIs` | 抽象側の初期状態は fixture の 1 点（`Sound` と合わせて、INV が空でないことを保証する） | 空の INV・初期状態 |
| `Refines.InitSurj` | 抽象側の各初期状態に、対応する具体側の初期状態がある | 初期状態の偏り |
| `Refines.StateSafe`・`StateSafeConcrete` | 出力のみの差異の前提が破れても、状態は `J` を保つ | 差異の前提の外の 1 歩による状態の破壊 |
| `Nontrivial`・`Nontrivial₂` | 名前付きの述語・関係は、成り立つ値と成り立たない値を持つ | `True`・`False` の成分 |
| `KernelIs` | 標準の抽象化の葉が同一視するもの（核） | 標準の抽象化に隠れた同一視 |
| `Refines.complete`・`Refines.run` | 1 歩の可換式と、複数歩の模倣 | — |
| `Refines.congr` | 各点で同値な貼り合わせへの付け替え | — |
-/

namespace Machine

variable {σ τ ιa ιc οa οc ε E F : Type}

/-- 常に偽の関係。`Glue.ofStd` の OJ・OO の既定値（観測型の差異が無いこと）。 -/
def never {α β : Type} (_ : α) (_ : β) : Prop := False

/-- 述語が自明でない: 成り立つ値と、成り立たない値がある。名前付きの差異の述語に課す（W 課題）。 -/
def Nontrivial {α : Type} (P : α → Prop) : Prop := (∃ x, P x) ∧ ∃ x, ¬ P x

/-- 2 引数の述語・関係が自明でない。 -/
def Nontrivial₂ {α β : Type} (R : α → β → Prop) : Prop := Nontrivial fun p : α × β => R p.1 p.2

/-- 関数 `f` の核（同一視するもの）が `K` である。`K` が等号なら `f` は単射。標準の抽象化の葉に課す。 -/
def KernelIs {α β : Type} (f : α → β) (K : α → α → Prop) : Prop := ∀ x y, f x = f y ↔ K x y

/-- 各要素が関係 `R` で対応する 2 つの列。 -/
inductive Forall₂ {α β : Type} (R : α → β → Prop) : List α → List β → Prop
  | nil : Forall₂ R [] []
  | cons {a b as bs} : R a b → Forall₂ R as bs → Forall₂ R (a :: as) (b :: bs)

/-! ## 抽象機械 -/

namespace Machine

/-- 選択の像として与える抽象機械。`f s i (e, x)` は、環境の選択 `e : E`（排他の衝突、I/O の失敗、
配備の設定など）と自由な選択 `x : F`（ハッシュ値など）の下での結果である。標準の選択は `(e₀, f₀)`。
`E`・`F` の各成分の型には `@[nondet "N-NNN"]` を付ける（利用側）。 -/
def ofChoice (Inv Init : σ → Prop) (Pre : σ → ιa → Prop) (f : σ → ιa → E × F → σ × οa)
    (e₀ : E) (f₀ : F) : Machine σ ιa οa where
  Inv := Inv
  Init := Init
  Pre := Pre
  step s i s' o := ∃ c, f s i c = (s', o)
  run s i := f s i (e₀, f₀)
  run_step _ _ _ := ⟨(e₀, f₀), rfl⟩

/-- 自由な選択の枠: 自由な選択 `x` を変えても、射影 `m` で見た結果は変わらない。`m` の核（`KernelIs`）が、
自由な選択が変えうる部分を表す。 -/
def FreeFrame {P : Type} (f : σ → ιa → E × F → σ × οa) (m : σ × οa → P) : Prop :=
  ∀ s i e x y, m (f s i (e, x)) = m (f s i (e, y))

/-- 初期状態が `s₀` の 1 点である。 -/
def InitIs (A : Machine σ ιa οa) (s₀ : σ) : Prop := ∀ s, A.Init s ↔ s = s₀

/-- `Sound` で初期状態が 1 点なら、その点は INV を満たす（INV は空でない）。 -/
theorem InitIs.inv {A : Machine σ ιa οa} {s₀ : σ} (h : A.InitIs s₀) (hS : A.Sound) : A.Inv s₀ :=
  hS.init_inv s₀ ((h s₀).2 rfl)

theorem ofChoice_step {Inv Init : σ → Prop} {Pre : σ → ιa → Prop} {f : σ → ιa → E × F → σ × οa}
    {e₀ : E} {f₀ : F} {s : σ} {i : ιa} {s' : σ} {o : οa} :
    (ofChoice Inv Init Pre f e₀ f₀).step s i s' o ↔ ∃ c, f s i c = (s', o) := Iff.rfl

/-- 入口の全域性: INV と環境の前提 `Env`（マスタ・設定の妥当性。入力の射影だけで書く）の下で、PRE が成り立つ。 -/
def TotalUnder (A : Machine σ ιa οa) (Env : ιa → Prop) : Prop :=
  ∀ s i, A.Inv s → Env i → A.Pre s i

/-- PRE を強めた機械の全域性は、強めた述語を環境の前提に加えれば保たれる。 -/
theorem TotalUnder.restrictState {A : Machine σ ιa οa} {Env : ιa → Prop} (h : A.TotalUnder Env)
    (P : σ → ιa → Prop) : (A.restrictState P).TotalUnder fun i => Env i ∧ ∀ s, P s i :=
  fun s i hi he => ⟨h s i hi he.1, he.2 s⟩

theorem TotalUnder.restrict {A : Machine σ ιa οa} {Env : ιa → Prop} (h : A.TotalUnder Env)
    (P : ιa → Prop) : (A.restrict P).TotalUnder fun i => Env i ∧ P i :=
  fun s i hi he => ⟨h s i hi he.1, he.2⟩

/-- 抽象機械の、PRE を満たす歩みの列。 -/
inductive Run (A : Machine σ ιa οa) : σ → List ιa → σ → List οa → Prop
  | nil (s : σ) : Run A s [] s []
  | cons {s i s₁ o is s₂ os} : A.Pre s i → A.step s i s₁ o → Run A s₁ is s₂ os →
      Run A s (i :: is) s₂ (o :: os)

end Machine

/-! ## 具体機械 -/

namespace Concrete

/-- 具体機械の、正常終了の列。 -/
inductive Run (C : Concrete τ ιc οc ε) : τ → List ιc → τ → List οc → Prop
  | nil (t : τ) : Run C t [] t []
  | cons {t i t₁ o is t₂ os} : C.step t i (.ok (t₁, o)) → Run C t₁ is t₂ os →
      Run C t (i :: is) t₂ (o :: os)

end Concrete

/-! ## 貼り合わせ -/

namespace Glue

/-- 標準の貼り合わせ。

- `β`・`ai`・`ao`: 標準の抽象化（部分写像。`none` は α/β の未定義）。利用側で `@[std_abs]` を付ける
- `Ic`: 具体側の不変条件
- `OJ`・`OO`: 観測型の差異の名前付きの成分（既定は `never`）。利用側で `@[deviation]` を付ける -/
def ofStd (β : τ → Option σ) (Ic : τ → Prop) (ai : ιc → Option ιa) (ao : οc → Option οa)
    (OJ : σ → τ → Prop := never) (OO : οc → οa → Prop := never) : Glue σ τ ιa ιc οa οc where
  J s t := (β t = some s ∧ Ic t) ∨ OJ s t
  αi c a := ai c = some a
  αo c a := ao c = some a ∨ OO c a

/-- 各点で同値な貼り合わせ。 -/
structure Equiv (g g' : Glue σ τ ιa ιc οa οc) : Prop where
  J : ∀ s t, g.J s t ↔ g'.J s t
  αi : ∀ c a, g.αi c a ↔ g'.αi c a
  αo : ∀ c a, g.αo c a ↔ g'.αo c a

end Glue

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

/-- 標準の貼り合わせでは、具体側の入力の全域性は `ai` が定義域で `none` にならないことに帰着する。 -/
theorem Glue.ofStd_input_total {β : τ → Option σ} {Ic : τ → Prop} {ai : ιc → Option ιa}
    {ao : οc → Option οa} {OJ : σ → τ → Prop} {OO : οc → οa → Prop} {Dom : ιc → Prop}
    (h : ∀ ic, Dom ic → (ai ic).isSome) :
    ∀ ic, Dom ic → ∃ ia, (Glue.ofStd β Ic ai ao OJ OO).αi ic ia := by
  intro ic hd
  have hs := h ic hd
  match hai : ai ic, hs with
  | some ia, _ => exact ⟨ia, hai⟩
  | none, hs => simp at hs

end Machine
