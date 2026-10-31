import Machine.Machine
import Machine.Adequacy

/-!
# Machine.Machine.Adequacy

抽象機械の空虚化を防ぐ定義（references/docs/spec/architecture.md#空虚化を防ぐ義務）: 選択の像としての抽象機械 `ofChoice`、自由な選択の枠 `FreeFrame`、初期状態 `InitIs`、入口の全域性 `TotalUnder`。
ドット記法のため、型 `Machine.Machine` の名前空間に置く（`Machine.Adequacy` の表）。
-/

namespace Machine

open Machine.Adequacy

variable {σ τ ιa ιc οa οc ε E F : Type}

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

/-- 環境の前提の必要性（references/docs/spec/architecture.md#空虚化を防ぐ義務）: INV を満たし PRE を破る証人があれば、前提なしの全域性は成り立たない。 -/
theorem TotalUnder.not_always {A : Machine σ ιa οa} {s : σ} {i : ιa} (hi : A.Inv s) (hp : ¬ A.Pre s i) :
    ¬ A.TotalUnder always :=
  fun h => hp (h s i hi trivial)

/-- 抽象機械の、PRE を満たす歩みの列。 -/
inductive Run (A : Machine σ ιa οa) : σ → List ιa → σ → List οa → Prop
  | nil (s : σ) : Run A s [] s []
  | cons {s i s₁ o is s₂ os} : A.Pre s i → A.step s i s₁ o → Run A s₁ is s₂ os →
      Run A s (i :: is) s₂ (o :: os)

end Machine

end Machine
