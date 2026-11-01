/-!
# Machine.Preserves.Pred

`Machine.Preserves`（A preserves B: リファインメントの空虚化を防ぐ義務。references/docs/spec/architecture.md#空虚化を防ぐ義務）が使う、
型に属さない述語: `never`・`always`・`anyOf`・`Covers`・`Covers₂`・`Nontrivial`・`Nontrivial₂`・`KernelIs`。

型 `Machine.Preserves`（`Machine.Preserves` のモジュール）の名前空間に置く（spec-pivot の `lang/lean/rules.md#モジュールと名前空間` の E1）。
束 `Machine.Preserves` がこれらに依存するので、下位のモジュールに分ける。利用側は
`open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)` のように、名前を選んで開く。

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
-/

namespace Machine.Preserves


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

end Machine.Preserves
