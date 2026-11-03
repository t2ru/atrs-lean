import Machine.Preserves.Pred


/-!
# Machine.Sum

機械の並置（references/docs/spec/architecture.md#リファインメントb-メソッド）。

各機能の機械を並べて、トップレベルの機械を作る。入力は和型で、どちらかの機能を 1 歩動かす。状態は積で、
動かさない側の状態は変わらない。抽象機械・具体機械・貼り合わせをそれぞれ並べると、リファインメントと
束 `Machine.Preserves`・`Machine.Abstracts` は保たれる（`Refines.sum`・`Preserves.sum`・`Abstracts.sum`）。

| 定義・定理 | モジュール | 内容 |
| --- | --- | --- |
| `Machine.Sum.sumPred` | `Machine.Sum` | 入力の述語の並置（前提型の差異・環境の前提を並べる） |
| `Machine.sum`（`Machine.Machine.sum`）・`Sound.sum`・`InitIs.sum`・`TotalUnder.sum` | `Machine.Machine.Sum` | 抽象機械の並置と、その義務 |
| `Concrete.sum` | `Machine.Concrete.Sum` | 具体機械の並置 |
| `Glue.sum` | `Machine.Glue.Sum` | 貼り合わせの並置 |
| `Refines.sum`・`Refines.congrPre` | `Machine.Refines.Sum` | 並置はリファインメントを保つ。PRE と具体側の定義域を、各点で同値なものに替えても保たれる（並置した制限と、制限の並置を結ぶ） |
| `Preserves.sum`・`Preserves.congrPre` | `Machine.Preserves.Sum` | 同じことを束 `Preserves` について示す（`Refines` を使わない） |
| `Abstracts.sum`・`Abstracts.congrPre` | `Machine.Abstracts.Sum` | 同じことを `Abstracts` について示す |

ドット記法（`A₁.sum A₂`・`h₁.sum h₂`）のため、型ごとの定義はその型の名前空間に置き、型のモジュールの下位モジュールに分ける（spec-pivot の `lang/lean/rules.md#モジュールと名前空間` の E1）。

トップレベルの主定理は、次の形をとる。

```lean
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem preserves : Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue s₀ env
theorem abstracts : Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue s₀ env
```
-/


namespace Machine.Sum


/-- 入力の述語の並置。 -/
def sumPred {α β : Type} (P : α → Prop) (Q : β → Prop) : α ⊕ β → Prop
  | .inl a => P a
  | .inr b => Q b

/-- 状態と入力の述語（環境の前提）の並置（`Machine.sum`。状態は組）。 -/
def sumEnv {σ₁ σ₂ α β : Type} (P : σ₁ → α → Prop) (Q : σ₂ → β → Prop) : σ₁ × σ₂ → α ⊕ β → Prop
  | s, .inl a => P s.1 a
  | s, .inr b => Q s.2 b

/-- 状態と入力の述語（環境の前提）の並置（`Machine.alt`。同じ状態）。 -/
def altEnv {σ α β : Type} (P : σ → α → Prop) (Q : σ → β → Prop) : σ → α ⊕ β → Prop
  | s, .inl a => P s a
  | s, .inr b => Q s b

end Machine.Sum
