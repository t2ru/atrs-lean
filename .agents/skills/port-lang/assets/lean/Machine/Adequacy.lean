/-!
# Machine.Adequacy

リファインメントが空虚・自明に成り立つことを防ぐ義務（references/docs/spec/architecture.md#空虚化を防ぐ義務）。

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
| `always`、`Refines.not_of_error`・`not_of_stuck`・`not_of_mismatch`・`Pinned.not_of_mismatch`・`Machine.TotalUnder.not_always` | 成分の必要性（references/docs/spec/architecture.md#空虚化を防ぐ義務）: 名前付きの成分を外した R 課題の命題が偽であることを、証人から示す | 不要な成分（外しても成り立つ差異・環境の前提） |
| `Covers`・`Covers₂` | 被覆: 必要な差異 M の下では差異 d が常に成り立つ（d は M に覆われ、必要性の代わりにこれを示す） | 他の差異に覆われた実在の差異が、必要性を示せないこと |
| `anyOf` | 観測型の差異の成分の和。同じ出力に重なる差異を、差異ごとの定数に分けたまま OJ・OO に置く | 複数の差異を 1 つの定数に束ねること |

成分の必要性は、vacuity detection（Beer ら 2001、Kupferman–Vardi 2003）の「部分式を自明な値に替えると
真理値が変わる」ことの証拠（interesting witness）に当たる。形は次のとおり（照合は `obligation-check` の G9）。

- 前提型の差異 `d`（`restrict d`）: `restrict d` の層を外した機械について、R 課題の命題が偽
- 観測型の差異 `d`（OJ・OO）: `d` を `never` にした貼り合わせについて、R 課題の命題が偽
- R 課題の命題は、基底が `ofChoice` なら `Refines ∧ Pinned`（同じ `f`・`ce`）、`pure` なら `Refines`。
  `Refines` だけでは、環境の選択（衝突・I/O 失敗）が具体側の不具合を模倣するため、差異が無くても成り立ちうる
- 否定する命題は `¬ P` か `P → False` の形で書く。基底が `ofChoice` でも、`¬ Refines` はより強い証明として認める
- 被覆: 他の必要な差異 M の下で常に成り立つ差異 d（例: 前提が M の前提に含まれる差異）は、外しても R 課題が
  成り立つので必要性を示せない。そのときは、M と d を同じ R 課題で使い、`Covers M d` を示す
- 環境の前提: `¬ A.TotalUnder always`（前提が無ければ PRE が成り立たない入力がある）。PRE が INV の下で
  全域な機械は、環境の前提を置かず `A.TotalUnder always` を示す

定義は、型ごとの下位モジュールに置く（ドット記法 `A.InitIs` などのため、型の名前空間に置く。port-lang の `lang/lean/rules.md#モジュールと名前空間` の E1）。
このモジュールは、型に属さない述語（`never`・`always`・`anyOf`・`Covers`・`Nontrivial`・`KernelIs`・`Forall₂`）を持つ。

| モジュール | 内容 |
| --- | --- |
| `Machine.Machine.Adequacy` | 抽象機械: `Machine.ofChoice`・`FreeFrame`・`InitIs`・`TotalUnder` |
| `Machine.Concrete.Adequacy` | 具体機械の正常終了の列 `Concrete.Run` |
| `Machine.Glue.Adequacy` | 標準の貼り合わせ `Glue.ofStd`・`Glue.Equiv` |
| `Machine.Refines.Adequacy` | リファインメントの付帯の義務: `Refines.InitSurj`・`Pinned`・`NoFaultReachable`・`EnvWitness`・`StateSafe`、`Refines.complete`・`Refines.run` |
-/

namespace Machine.Adequacy


/-- 常に偽の関係。`Glue.ofStd` の OJ・OO の既定値（観測型の差異が無いこと）。 -/
def never {α β : Type} (_ : α) (_ : β) : Prop := False

/-- 常に真の述語。環境の前提の必要性（`¬ A.TotalUnder always`）に使う（references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
def always {α : Type} (_ : α) : Prop := True

/-- 関係の和。観測型の差異の成分を、差異ごとの定数に分けたまま OJ・OO に置く（references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
def anyOf {α β : Type} (R S : α → β → Prop) (a : α) (b : β) : Prop := R a b ∨ S a b

/-- 被覆: 差異の述語 `M` の下では、差異の述語 `d` が常に成り立つ（`d` は `M` に覆われる。references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
def Covers {α : Type} (M d : α → Prop) : Prop := ∀ x, M x → d x

/-- 2 引数の述語（`restrictState` の述語）の被覆。 -/
def Covers₂ {α β : Type} (M d : α → β → Prop) : Prop := ∀ x y, M x y → d x y

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

end Machine.Adequacy
