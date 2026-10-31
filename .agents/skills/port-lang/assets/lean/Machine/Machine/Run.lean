import Machine.Machine

/-!
# Machine.Machine.Run

抽象機械の、PRE を満たす歩みの列 `Machine.Run`（複数歩の模倣 `Machine.Abstracts.run` が使う）。
ドット記法（`A.Run`）のため、型 `Machine.Machine` の名前空間に置く（port-lang の `lang/lean/rules.md#モジュールと名前空間` の E1）。
-/

namespace Machine

variable {σ ιa οa : Type}

namespace Machine

/-- 抽象機械の、PRE を満たす歩みの列。 -/
inductive Run (A : Machine σ ιa οa) : σ → List ιa → σ → List οa → Prop
  | nil (s : σ) : Run A s [] s []
  | cons {s i s₁ o is s₂ os} : A.Pre s i → A.step s i s₁ o → Run A s₁ is s₂ os →
      Run A s (i :: is) s₂ (o :: os)

end Machine

end Machine
