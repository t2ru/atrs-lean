import Machine.Preserves
import Machine.Machine.Run
import Machine.Concrete.Run

/-!
# Machine.Abstracts

**A abstracts B = A preserves B ∧ B refines A**（references/docs/spec/architecture.md#空虚化を防ぐ義務）。

- `Refines A C g`（B refines A）: B メソッドのリファインメント（`Machine.Refines`。B の初期化・操作の証明義務を、入出力の対応 αi・αo で一般化したもの）
- `Preserves A C g s₀ Env ch outs outsC`（A preserves B）: R 課題の、空虚化を防ぐ意味的な義務のすべて（`Machine.Preserves`。Refines を含まない）

`Abstracts` は B のリファインメントより厳密に強い（`Abstracts` ⇒ B refines A。逆は成り立たない）。
系は、両方を使うもの（初期状態からの複数歩の模倣 `run_init`、具体側の正常終了が実在すること `exists_ok`、
1 歩の可換式 `complete`）である。

| 定義・定理 | 内容 |
| --- | --- |
| `Abstracts.Forall₂` | 各要素が関係で対応する 2 つの列 |
| `Abstracts` | 束 `preserves`・`refines` |
| `Abstracts.run_of`・`Abstracts.run` | 複数歩の模倣（`Sound`・`TotalUnder` と `Refines` から） |
| `Abstracts.init_glue`・`run_init`・`exists_ok` | 初期状態の対応、初期状態からの複数歩の模倣、具体側の正常終了の実在 |
| `Abstracts.complete_of`・`Abstracts.complete` | 1 歩の可換式（基底が `ofChoice`。`Refines` と `Pinned` から） |
| `Machine.Abstracts.Sum` | 並置 `Abstracts.sum`・付け替え `Abstracts.congrPre` |

出力が関数で決まる機械（`Machine.pure` とその制限）の 1 歩の可換式は、`Refines` だけから出る（`Refines.complete_fun`）。
-/

namespace Machine

variable {σ τ ιa ιc οa οc ε E F : Type}

namespace Abstracts

/-- 各要素が関係 `R` で対応する 2 つの列。 -/
inductive Forall₂ {α β : Type} (R : α → β → Prop) : List α → List β → Prop
  | nil : Forall₂ R [] []
  | cons {a b as bs} : R a b → Forall₂ R as bs → Forall₂ R (a :: as) (b :: bs)

end Abstracts

open Machine.Preserves (Choice OutLayer OutLayerC) in
/-- A abstracts B = A preserves B ∧ B refines A。 -/
structure Abstracts (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (s₀ : σ)
    (Env : ιa → Prop) (ch : Option (Choice σ ιa οa ιc) := none) (outs : List (OutLayer σ ιa οa) := [])
    (outsC : List (OutLayerC τ ιc οc ε) := []) : Prop where
  /-- A preserves B: 空虚化を防ぐ意味的な義務のすべて。 -/
  preserves : Preserves A C g s₀ Env ch outs outsC
  /-- B refines A: B メソッドのリファインメント。 -/
  refines : Refines A C g

namespace Abstracts

open Machine.Preserves (Choice OutLayer OutLayerC)

variable {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : ιa → Prop}
  {ch : Option (Choice σ ιa οa ιc)} {outs : List (OutLayer σ ιa οa)} {outsC : List (OutLayerC τ ιc οc ε)}

/-- 複数歩の模倣: 抽象機械が `Sound` で、入口の全域性 `TotalUnder Env` が成り立つとき、各入力が定義域と
環境の前提を満たす具体側の正常終了の列は、PRE を満たす抽象側の歩みの列で模倣される。 -/
theorem run_of (hS : A.Sound) (h : Refines A C g) {Env : ιa → Prop} (hT : A.TotalUnder Env)
    {s : σ} {t : τ} {ics : List ιc} {t' : τ} {ocs : List οc} (hi : A.Inv s) (hJ : g.J s t)
    (hr : C.Run t ics t' ocs) (hin : ∀ ic, ic ∈ ics → C.Dom ic ∧ ∀ ia, g.αi ic ia → Env ia) :
    ∃ ias s' oas, Forall₂ g.αi ics ias ∧ A.Run s ias s' oas ∧ g.J s' t' ∧ A.Inv s' ∧
      Forall₂ g.αo ocs oas := by
  induction hr generalizing s with
  | nil t => exact ⟨[], s, [], .nil, .nil s, hJ, hi, .nil⟩
  | @cons t ic t₁ oc ics t₂ ocs hs _ ih =>
    obtain ⟨hd, he⟩ := hin ic (List.Mem.head _)
    obtain ⟨ia, ha⟩ := h.input_total ic hd
    have hpre := hT s ia hi (he ia ha)
    obtain ⟨s₁, oa, hst, hJ₁, ho⟩ := h.correct s t ic ia t₁ oc hi hJ ha hpre hd hs
    have hi₁ := hS.step_inv s ia s₁ oa hi hpre hst
    obtain ⟨ias, s', oas, hai, hrun, hJ', hi', hao⟩ :=
      ih hi₁ hJ₁ fun ic' hm => hin ic' (List.Mem.tail _ hm)
    exact ⟨ia :: ias, s', oa :: oas, .cons ha hai, .cons hpre hst hrun, hJ', hi', .cons ho hao⟩

/-- 複数歩の模倣（束から）: 任意の INV を満たし `J` で結ばれた状態からの、具体側の正常終了の列は、
各入力が定義域と環境の前提を満たせば、PRE を満たす抽象側の歩みの列で模倣される。 -/
theorem run (h : Abstracts A C g s₀ Env ch outs outsC) {s : σ} {t : τ} {ics : List ιc} {t' : τ} {ocs : List οc}
    (hi : A.Inv s) (hJ : g.J s t) (hr : C.Run t ics t' ocs)
    (hin : ∀ ic, ic ∈ ics → C.Dom ic ∧ ∀ ia, g.αi ic ia → Env ia) :
    ∃ ias s' oas, Forall₂ g.αi ics ias ∧ A.Run s ias s' oas ∧ g.J s' t' ∧ A.Inv s' ∧ Forall₂ g.αo ocs oas :=
  run_of h.preserves.sound h.refines h.preserves.total hi hJ hr hin

/-- 具体側の初期状態は、抽象側の初期状態 `s₀` と `J` で結ばれ、`s₀` は INV を満たす。 -/
theorem init_glue (h : Abstracts A C g s₀ Env ch outs outsC) {t : τ} (ht : C.Init t) : g.J s₀ t ∧ A.Inv s₀ := by
  obtain ⟨s, hs, hJ⟩ := h.refines.init t ht
  rw [(h.preserves.initIs s).1 hs] at hJ
  exact ⟨hJ, h.preserves.init_inv⟩

/-- 初期状態からの複数歩の模倣: 具体側の初期状態からの正常終了の列は、各入力が定義域と環境の前提を満たせば、
`s₀` からの PRE を満たす抽象側の歩みの列で、`J`・`αi`・`αo` を保って模倣される。 -/
theorem run_init (h : Abstracts A C g s₀ Env ch outs outsC) {t : τ} {ics : List ιc} {t' : τ} {ocs : List οc}
    (ht : C.Init t) (hr : C.Run t ics t' ocs) (hin : ∀ ic, ic ∈ ics → C.Dom ic ∧ ∀ ia, g.αi ic ia → Env ia) :
    ∃ ias s' oas, Forall₂ g.αi ics ias ∧ A.Run s₀ ias s' oas ∧ g.J s' t' ∧ A.Inv s' ∧ Forall₂ g.αo ocs oas :=
  let ⟨hJ, hi⟩ := h.init_glue ht
  h.run hi hJ hr hin

/-- 非空虚性: 環境の前提を満たす具体側の入力が、`s₀` に対応する具体側の初期状態から正常終了し、その結果は
抽象側の歩みで模倣される。リファインメントが、空でない具体側の振る舞いについて述べていることを示す。 -/
theorem exists_ok (h : Abstracts A C g s₀ Env ch outs outsC) :
    ∃ t ic ia t' oc s' oa, C.Init t ∧ C.Dom ic ∧ g.αi ic ia ∧ Env ia ∧ C.step t ic (.ok (t', oc)) ∧
      A.step s₀ ia s' oa ∧ g.J s' t' ∧ g.αo oc oa := by
  obtain ⟨ic, ia, hd, ha, he⟩ := h.preserves.envWitness
  have hi := h.preserves.init_inv
  obtain ⟨t, ht, hJ⟩ := h.preserves.initSurj s₀ ((h.preserves.initIs s₀).2 rfl)
  have hpre := h.preserves.total s₀ ia hi he
  obtain ⟨⟨r, hr⟩, hne⟩ := h.refines.applicable s₀ t ic ia hi hJ ha hpre hd
  match r, hr with
  | .error e, hr => exact absurd hr (hne e)
  | .ok (t', oc), hr =>
    obtain ⟨s', oa, hst, hJ', ho⟩ := h.refines.correct s₀ t ic ia t' oc hi hJ ha hpre hd hr
    exact ⟨t, ic, ia, t', oc, s', oa, ht, hd, ha, he, hr, hst, hJ', ho⟩

/-- 1 歩の可換式（完全性）: PRE の下で、具体側は必ず結果を持ち、どの結果も正常終了で、環境を固定した
`f` の結果のどれかと `J`・`αo` で対応する。障害の無い環境（`ce ic = e₀`）では、自由な選択を除いて
標準の選択と一致する。 -/
theorem complete_of {f : σ → ιa → E × F → σ × οa} {ce : ιc → E} (h : Refines A C g)
    (hp : Refines.Pinned A C g f ce) {s : σ} {t : τ} {ic : ιc} {ia : ιa} (hi : A.Inv s) (hJ : g.J s t)
    (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic) :
    (∃ r, C.step t ic r) ∧ ∀ r, C.step t ic r → ∃ t' oc, r = .ok (t', oc) ∧
      ∃ x, g.J (f s ia (ce ic, x)).1 t' ∧ g.αo oc (f s ia (ce ic, x)).2 := by
  obtain ⟨hex, hne⟩ := h.applicable s t ic ia hi hJ ha hpre hd
  refine ⟨hex, fun r hr => ?_⟩
  match r, hr with
  | .error e, hr => exact absurd hr (hne e)
  | .ok (t', oc), hr => exact ⟨t', oc, rfl, hp s t ic ia t' oc hi hJ ha hpre hd hr⟩

/-- 1 歩の可換式（束から。基底が `ofChoice` で `ch = some c`）。 -/
theorem complete {c : Choice σ ιa οa ιc} (h : Abstracts A C g s₀ Env (some c) outs outsC) {s : σ} {t : τ} {ic : ιc}
    {ia : ιa} (hi : A.Inv s) (hJ : g.J s t) (ha : g.αi ic ia) (hpre : A.Pre s ia) (hd : C.Dom ic) :
    (∃ r, C.step t ic r) ∧ ∀ r, C.step t ic r → ∃ t' oc, r = .ok (t', oc) ∧
      ∃ x, g.J (c.f s ia (c.ce ic, x)).1 t' ∧ g.αo oc (c.f s ia (c.ce ic, x)).2 :=
  complete_of h.refines (h.preserves.pinned c rfl) hi hJ ha hpre hd

end Abstracts

end Machine
