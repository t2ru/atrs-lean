/-!
# Machine.Machine

抽象機械（B メソッドの abstract machine）。`Spec` の各機能をこの形で与える（references/docs/spec/architecture.md#リファインメントb-メソッド の「抽象機械」）。

- 状態 σ・入力 ι・出力 ο を持つ 1 つの操作として表す。複数の操作を持つ機能は、入力を直和
  （操作ごとの構成子を持つ `inductive`）にして 1 つの機械にまとめる。
- 事後は関係 `step` で与え、非決定性を許す。あわせて実行可能な標準の選択 `run` と、
  `run` が PRE の下で `step` に含まれること（`run_step`）を持たせる。
- `Spec` 自身の証明義務（SPEC 課題）のうち、INIT ⇒ INV と INV の保存は `Machine.Sound` で表す。
-/

namespace Machine

/-- 抽象機械。

- `Inv`: 不変条件 INV
- `Init`: 初期状態の集合 INIT
- `Pre`: 操作の事前条件 PRE（値域、マスタ・設定の制約を含む）
- `step s i s' o`: 状態 `s` で入力 `i` を受けると、状態 `s'` に移り `o` を出力しうる
- `run`: 実行可能な標準の選択（ベクタの期待値の生成に使う）
- `run_step`: PRE の下で、標準の選択は関係 `step` に含まれる -/
structure Machine (σ ι ο : Type) where
  Inv : σ → Prop
  Init : σ → Prop
  Pre : σ → ι → Prop
  step : σ → ι → σ → ο → Prop
  run : σ → ι → σ × ο
  run_step : ∀ s i, Pre s i → step s i (run s i).1 (run s i).2

namespace Machine

variable {σ ι ο : Type}

/-- `Spec` 自身の証明義務: 初期化が INV を満たし、PRE の下の操作が INV を保つ。 -/
structure Sound (A : Machine σ ι ο) : Prop where
  init_inv : ∀ s, A.Init s → A.Inv s
  step_inv : ∀ s i s' o, A.Inv s → A.Pre s i → A.step s i s' o → A.Inv s'

/-- 前提型の差異（抽象側の入力・状態の述語）で PRE を強める。 -/
def restrictState (A : Machine σ ι ο) (P : σ → ι → Prop) : Machine σ ι ο where
  Inv := A.Inv
  Init := A.Init
  Pre s i := A.Pre s i ∧ P s i
  step := A.step
  run := A.run
  run_step s i h := A.run_step s i h.1

/-- 前提型の差異（抽象側の入力の述語）で PRE を強める。`A.restrict dev_DNNN` と書く。 -/
def restrict (A : Machine σ ι ο) (P : ι → Prop) : Machine σ ι ο :=
  A.restrictState fun _ i => P i

/-- 状態を変えない純粋な計算 `f` を、状態 `Unit` の抽象機械とする。 -/
def pure (Pre : ι → Prop) (f : ι → ο) : Machine Unit ι ο where
  Inv _ := True
  Init _ := True
  Pre _ i := Pre i
  step _ i _ o := o = f i
  run _ i := ((), f i)
  run_step _ _ _ := rfl

theorem Sound.restrictState {A : Machine σ ι ο} (h : A.Sound) (P : σ → ι → Prop) :
    (A.restrictState P).Sound where
  init_inv := h.init_inv
  step_inv s i s' o hi hp hs := h.step_inv s i s' o hi hp.1 hs

theorem Sound.restrict {A : Machine σ ι ο} (h : A.Sound) (P : ι → Prop) : (A.restrict P).Sound :=
  h.restrictState _

theorem sound_pure (Pre : ι → Prop) (f : ι → ο) : (pure Pre f).Sound where
  init_inv _ _ := trivial
  step_inv _ _ _ _ _ _ _ := trivial

end Machine

end Machine
