import Machine.Refines.Preserves

/-!
# Machine.Preserves

**A preserves B**: R 課題の、リファインメントの空虚化を防ぐ意味的な義務のすべてを束ねた `Preserves`
（references/docs/spec/architecture.md#空虚化を防ぐ義務）。`Refines`（B refines A。B メソッドのリファインメント）を含まない。
両者を合わせたものが `Machine.Abstracts`（A abstracts B = A preserves B ∧ B refines A）である。

`Refines` は「∀ 具体側の振る舞い ∃ 抽象側の振る舞い」の主張なので、抽象側が緩い、PRE が強い、具体側が空、
具体側の不具合が抽象側の非決定性に紛れる、といった場合にも空虚に成り立つ。束の各成分がそれを塞ぐ。

| 成分 | 条件 | 向き | 意味 | 塞ぐもの |
| --- | --- | --- | --- | --- |
| `sound` | 常に | 抽象のみ | 抽象側の INV が初期化で成り立ち、PRE の下の歩みで保たれる | 不健全な INV |
| `initIs` | 常に | 抽象のみ | 初期状態は fixture の 1 点（`sound` と合わせて、INV が空でない） | 仮定 `A.Inv s` が空で、Refines が空虚に成り立つこと |
| `initSurj` | 常に | 抽象→具体 | 抽象側の各初期状態に、`J` で結ばれる具体側の初期状態がある（`Refines.init` の逆向き） | 具体側の初期状態が空であること |
| `total` | 常に | 抽象のみ | INV と環境の前提 `Env`（状態と入力の述語）の下で PRE が成り立つ | 強すぎる PRE |
| `envWitness` | 常に | 抽象→具体 | 初期状態 `s₀` で `Env` を満たす抽象側の入力が、具体側の定義域の入力の像として実現される | αi が PRE・`Env` の外へ写すこと、`Dom` が空であること |
| `envNeeded` | 常に | 抽象のみ | 環境の前提は、置かない（`Env = always`）か、無ければ PRE が成り立たない | 不要な前提で主張の範囲を狭めること |
| `pinned` | 基底が `ofChoice`（`ch = some c`） | 具体→抽象（模倣を絞る） | 具体側の正常終了は、具体側の入力の環境の記述 `c.ce ic` が許す（`c.adm`）環境の選択の `c.f` の結果で模倣される（`correct` より強い。B には無い） | 環境の非決定性が具体側の不具合を吸収すること |
| `noFault` | 基底が `ofChoice` | 抽象→具体 | 抽象側の入力の各像は、環境の記述が障害の指定の無い `c.d₀` の具体側の入力でも実現される | `ce` が全入力を障害の環境に写し、`pinned` を骨抜きにすること |
| `noFaultStd` | 基底が `ofChoice` | 抽象のみ | 障害の指定の無い環境の記述 `c.d₀` が許す環境の選択は、標準 `c.e₀` だけである | `adm` が障害の無い環境でも障害の選択を許し、具体側の不具合を吸収すること |
| `freeFrame` | 基底が `ofChoice` | 抽象のみ | 自由な選択が変えうるのは、射影 `c.m` が忘れる部分だけである | 自由な選択による結果の吸収 |
| `stateSafe`・`stateSafeC` | 「出力のみ」の差異ごと（`outs`・`outsC`） | 具体→抽象（模倣を広げる） | 差異の前提を破る入力でも、具体側の正常終了の後の状態は `J` を保つ | 差異の前提の外の 1 歩が状態を壊すこと |

条件付きの成分には既定の証明を付ける。`ch = none`・`outs = []`・`outsC = []`（既定値）なら自動で閉じるので、
基底が `pure` で「出力のみ」の差異が無い R 課題は、6 成分だけを書けばよい。

束の外に残る義務（差異の必要性 G9、定数ごとの `Nontrivial`・`KernelIs`、`ch`・`outs` が R 課題の構造に合うこと G6、
形 G0〜G5・G7）は、obligation-check が照合する（`Trace.Obligation`）。

定義の置き場所（spec-pivot の `lang/lean/rules.md#モジュールと名前空間` の E1）:

| モジュール | 内容 |
| --- | --- |
| `Machine.Preserves.Pred` | 型に属さない述語 `never`・`always`・`anyOf`・`Covers`・`Nontrivial`・`KernelIs` |
| `Machine.Machine.Preserves` | 抽象機械: `Machine.ofChoice`・`FreeFrame`・`InitIs`・`TotalUnder` |
| `Machine.Glue.Preserves` | 標準の貼り合わせ `Glue.ofStd` |
| `Machine.Refines.Preserves` | `Refines.InitSurj`・`EnvWitness`・`NoFaultReachable`・`Pinned`・`StateSafe`・`StateSafeConcrete` |
| `Machine.Preserves`（本モジュール） | 選択の像の材料 `Choice`、「出力のみ」の差異の層 `OutLayer`・`OutLayerC`、束 `Preserves`、忘却 `Preserves.core` |
| `Machine.Preserves.Sum` | 並置 `Preserves.sum`・付け替え `Preserves.congrPre` |
-/

namespace Machine

variable {σ τ ιa ιc οa οc ε : Type}

namespace Preserves

/-- 選択の像の材料（基底が `Machine.ofChoice` の R 課題）。

- `E`・`F`: 環境の選択・自由な選択の型。`f`: 基底の `ofChoice` の `f`
- `D`・`ce`: 具体側の入力の環境の記述の型と、その標準の抽象化（`@[std_abs]`）
- `adm`: 環境の記述が許す環境の選択（`Spec` の層の定数。記述が選択そのものなら `Machine.Preserves.sameEnv`）
- `d₀`: 障害の指定の無い環境の記述。`e₀`: 標準の環境の選択（`d₀` が許すのは `e₀` だけ。束の `noFaultStd`）
- `m`: 自由な選択の枠 `FreeFrame` の射影（核の定理 `KernelIs` を持つ） -/
structure Choice (σ ιa οa ιc : Type) : Type 1 where
  E : Type
  F : Type
  D : Type
  P : Type
  f : σ → ιa → E × F → σ × οa
  ce : ιc → D
  adm : D → E → Prop
  d₀ : D
  e₀ : E
  m : σ × οa → P

/-- 「出力のみ」の前提型の差異の層（抽象側の述語）。`base` は、その層 `P` を外した抽象機械。 -/
structure OutLayer (σ ιa οa : Type) where
  base : Machine σ ιa οa
  P : σ → ιa → Prop

/-- 「出力のみ」の前提型の差異の層（具体側だけにある入力の述語）。`base` は、その層 `P` を外した具体機械。 -/
structure OutLayerC (τ ιc οc ε : Type) where
  base : Concrete τ ιc οc ε
  P : ιc → Prop

end Preserves

open Machine.Preserves (always Choice OutLayer OutLayerC) in
/-- A preserves B: R 課題の、空虚化を防ぐ意味的な義務のすべて（`Refines` を含まない）。

- `ch`: 基底が `ofChoice` なら `some c`（選択の像の材料）、`pure` なら `none`
- `outs`・`outsC`: 「出力のみ」の前提型の差異の層（抽象側・具体側） -/
structure Preserves (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (s₀ : σ)
    (Env : σ → ιa → Prop) (ch : Option (Choice σ ιa οa ιc) := none) (outs : List (OutLayer σ ιa οa) := [])
    (outsC : List (OutLayerC τ ιc οc ε) := []) : Prop where
  /-- 抽象側の INV が初期化で成り立ち、PRE の下の歩みで保たれる。 -/
  sound : A.Sound
  /-- 抽象側の初期状態は fixture の 1 点 `s₀`。 -/
  initIs : A.InitIs s₀
  /-- 抽象側の初期状態に、対応する具体側の初期状態がある。 -/
  initSurj : Refines.InitSurj A C g
  /-- INV と環境の前提 `Env` の下で PRE が成り立つ。 -/
  total : A.TotalUnder Env
  /-- 環境の前提を満たす像を持つ、具体側の入力がある。 -/
  envWitness : Refines.EnvWitness C g s₀ Env
  /-- 環境の前提を置かない（PRE が INV の下で全域）か、環境の前提が無ければ PRE が成り立たない入力がある。 -/
  envNeeded : Env = always ∨ ¬ A.TotalUnder always
  /-- 環境の固定（基底が `ofChoice`）。 -/
  pinned : ∀ c, ch = some c → Refines.Pinned A C g c.f c.ce c.adm := by intro _ h; simp at h
  /-- 障害の無い環境での実現（基底が `ofChoice`）。 -/
  noFault : ∀ c, ch = some c → Refines.NoFaultReachable C g c.ce c.d₀ := by intro _ h; simp at h
  /-- 障害の指定の無い環境の記述が許すのは、標準の環境の選択だけ（基底が `ofChoice`）。 -/
  noFaultStd : ∀ c, ch = some c → ∀ e, c.adm c.d₀ e → e = c.e₀ := by intro _ h; simp at h
  /-- 自由な選択の枠（基底が `ofChoice`）。 -/
  freeFrame : ∀ c, ch = some c → Machine.FreeFrame c.f c.m := by intro _ h; simp at h
  /-- 状態の安全性（「出力のみ」の抽象側の差異ごと）。 -/
  stateSafe : ∀ l ∈ outs, Refines.StateSafe l.base C g l.P := by intro _ h; simp at h
  /-- 状態の安全性（「出力のみ」の具体側の差異ごと）。 -/
  stateSafeC : ∀ l ∈ outsC, Refines.StateSafeConcrete A l.base g l.P := by intro _ h; simp at h

namespace Preserves

variable {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : σ → ιa → Prop}
  {ch : Option (Choice σ ιa οa ιc)} {outs : List (OutLayer σ ιa οa)} {outsC : List (OutLayerC τ ιc οc ε)}

/-- 条件付きの成分を忘れて、全 R 課題に共通の 6 成分だけの束にする（並置 `Preserves.sum` の前に使う）。 -/
theorem core (h : Preserves A C g s₀ Env ch outs outsC) : Preserves A C g s₀ Env where
  sound := h.sound
  initIs := h.initIs
  initSurj := h.initSurj
  total := h.total
  envWitness := h.envWitness
  envNeeded := h.envNeeded

/-- `Sound` で初期状態が 1 点なら、その点は INV を満たす（INV は空でない）。 -/
theorem init_inv (h : Preserves A C g s₀ Env ch outs outsC) : A.Inv s₀ := h.initIs.inv h.sound

end Preserves

end Machine
