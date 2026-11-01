/-!
# LangSemantics.Sql.Transaction

トランザクションの取消（ロールバック）。本体が例外で終わったら、取消の対象の状態を開始時の値に戻す。
シーケンスの前進は取り消さない（`LangSemantics.Sql.Sequence`）。どの成分を戻すかは、呼び出し側が `restore` で
与える（例: 表は開始時の値、シーケンスは終了時の値）。

状態と例外を持つ計算は `EStateM ε σ`（例外で終わっても、その時点の状態を返す）で書く。排他（行ロック・
`SELECT … FOR UPDATE`）と分離レベルは、逐次の実行では観測されないので写さない（並行実行の性質はモデルの外）。

lang: `lang:sql#ISO-9075-2-17.7`（`ROLLBACK`）
-/

namespace LangSemantics.Sql.Transaction

/-- トランザクションの中で `body` を実行する。例外で終わったら、状態を `restore 開始時 終了時` にして例外を伝える。
正常に終わったら確定する（状態はそのまま）。 -/
def run {ε σ α : Type} (restore : σ → σ → σ) (body : EStateM ε σ α) : EStateM ε σ α := fun s =>
  match body s with
  | .ok a s' => .ok a s'
  | .error e s' => .error e (restore s s')

theorem run_ok {ε σ α : Type} {restore : σ → σ → σ} {body : EStateM ε σ α} {s s' : σ} {a : α}
    (h : body s = .ok a s') : run restore body s = .ok a s' := by
  simp [run, h]

theorem run_error {ε σ α : Type} {restore : σ → σ → σ} {body : EStateM ε σ α} {s s' : σ} {e : ε}
    (h : body s = .error e s') : run restore body s = .error e (restore s s') := by
  simp [run, h]

end LangSemantics.Sql.Transaction
