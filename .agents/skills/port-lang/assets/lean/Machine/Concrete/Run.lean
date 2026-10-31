import Machine.Concrete

/-!
# Machine.Concrete.Run

具体機械の正常終了の列 `Concrete.Run`（複数歩の模倣 `Machine.Abstracts.run` が使う。references/docs/spec/architecture.md#空虚化を防ぐ義務）。
-/

namespace Machine


variable {σ τ ιa ιc οa οc ε E F : Type}

/-! ## 具体機械 -/

namespace Concrete

/-- 具体機械の、正常終了の列。 -/
inductive Run (C : Concrete τ ιc οc ε) : τ → List ιc → τ → List οc → Prop
  | nil (t : τ) : Run C t [] t []
  | cons {t i t₁ o is t₂ os} : C.step t i (.ok (t₁, o)) → Run C t₁ is t₂ os →
      Run C t (i :: is) t₂ (o :: os)

end Concrete


end Machine
