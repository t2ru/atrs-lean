import Machine.Basic

/-!
# Machine.Concrete

具体機械。`SourceModel`・`TargetModel` の各機能をこの形で与える（references/docs/architecture.md#リファインメントb-メソッド の「リファインメント」）。

- 結果は `Except ε (τ × ο)` とする。`.ok (t', o)` が正常終了、`.error e` が正常終了でない結果である。
  `ε` は言語ごとに選ぶ（パニック、`PreconditionViolation`・`Assert` の失敗、溢れを誤りとする言語の
  算術の溢れ、NaN、不対サロゲートなど）。
- 業務エラー（例外として投げられ、α/β でエラー値に写るもの）は、出力 `ο` の値として正常な結果に含める。
- α/β の未定義は、貼り合わせ不変条件 `J`・出力の対応 `αₒ` に像が無いことである。これは
  `Machine.Refines` の正しさの義務が排除する（references/docs/architecture.md#リファインメントb-メソッド の適用可能性の「α/β の未定義」は、
  適用可能性と正しさの組で満たされる）。
- 非決定性（例: SQL の未規定の並び順）は、`step` が複数の結果を許すことで表す。
- `Dom` は、具体側の入力の定義域である。既定は全体で、前提型の差異（`restrict`）でだけ狭める。
  具体側だけにある環境（要求ヘッダ、ロケールなど）は、入力の成分として表す。
-/

namespace Machine

/-- 具体機械。`step t i r`: 状態 `t` で入力 `i` を受けると、結果 `r` になりうる。 -/
structure Concrete (τ ι ο ε : Type) where
  Init : τ → Prop
  Dom : ι → Prop := fun _ => True
  step : τ → ι → Except ε (τ × ο) → Prop

namespace Concrete

variable {τ ι ο ε : Type}

/-- 決定的な具体機械。 -/
def ofFun (Init : τ → Prop) (f : τ → ι → Except ε (τ × ο)) : Concrete τ ι ο ε where
  Init := Init
  step t i r := r = f t i

/-- 状態を持たない決定的な具体機械。 -/
def pure (f : ι → Except ε ο) : Concrete Unit ι ο ε :=
  ofFun (fun _ => True) fun _ i => (f i).map fun o => ((), o)

/-- 前提型の差異（具体側だけにある入力・環境の述語）で具体機械の入力を制限する。
`C.restrict dev_DNNN` と書く。 -/
def restrict (C : Concrete τ ι ο ε) (P : ι → Prop) : Concrete τ ι ο ε where
  Init := C.Init
  Dom i := C.Dom i ∧ P i
  step := C.step

@[simp] theorem ofFun_step (Init : τ → Prop) (f : τ → ι → Except ε (τ × ο)) (t : τ) (i : ι)
    (r : Except ε (τ × ο)) : (ofFun Init f).step t i r ↔ r = f t i := Iff.rfl

end Concrete

/-- 抽象機械を具体機械とみなす。PRE の外は前提違反（`.error ()`）の結果とする。
`Refines.trans` で、中間の抽象機械を具体側に置くために使う。 -/
def Machine.toConcrete {σ ι ο : Type} (A : Machine σ ι ο) : Concrete σ ι ο Unit where
  Init := A.Init
  step s i r :=
    (A.Pre s i ∧ ∃ s' o, r = .ok (s', o) ∧ A.step s i s' o) ∨ (¬ A.Pre s i ∧ r = .error ())

end Machine
