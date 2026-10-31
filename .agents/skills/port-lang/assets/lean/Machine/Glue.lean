/-!
# Machine.Glue

貼り合わせ `Glue`（抽象側と具体側の状態の関係 `J`、入力の対応 `αi`、出力の対応 `αo`）と、恒等・純粋・合成の貼り合わせ
（references/docs/spec/architecture.md#リファインメントb-メソッド）。リファインメント `Machine.Refines` が使う。
-/

namespace Machine

/-- 貼り合わせ。抽象側の状態 σ・入力 ιa・出力 οa と、具体側の状態 τ・入力 ιc・出力 οc の関係。

- `J s t`: 貼り合わせ不変条件（抽象化関数 α/β を含む関係）
- `αi ic ia`: 入力の対応
- `αo oc oa`: 出力の対応 -/
structure Glue (σ τ ιa ιc οa οc : Type) where
  J : σ → τ → Prop
  αi : ιc → ιa → Prop
  αo : οc → οa → Prop

namespace Glue

/-- 恒等の貼り合わせ。 -/
def id (σ ι ο : Type) : Glue σ σ ι ι ο ο where
  J s t := s = t
  αi c a := c = a
  αo c a := c = a

/-- 状態を持たない機械どうしの貼り合わせ。 -/
def pure {ιa ιc οa οc : Type} (αi : ιc → ιa → Prop) (αo : οc → οa → Prop) :
    Glue Unit Unit ιa ιc οa οc where
  J _ _ := True
  αi := αi
  αo := αo

/-- 貼り合わせの合成。中間の状態には、中間の機械の不変条件 `invM` を課す。 -/
def comp {σ μ τ ιa ιb ιc οa οb οc : Type} (g₁ : Glue σ μ ιa ιb οa οb) (g₂ : Glue μ τ ιb ιc οb οc)
    (invM : μ → Prop) : Glue σ τ ιa ιc οa οc where
  J s t := ∃ m, g₁.J s m ∧ g₂.J m t ∧ invM m
  αi ic ia := ∃ ib, g₂.αi ic ib ∧ g₁.αi ib ia
  αo oc oa := ∃ ob, g₂.αo oc ob ∧ g₁.αo ob oa

end Glue

end Machine
