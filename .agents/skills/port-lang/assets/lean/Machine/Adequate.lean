import Machine.Refines.Adequacy

/-!
# Machine.Adequate

リファインメントと、空虚化を防ぐ付帯の義務の束 `Adequate`（references/docs/spec/architecture.md#空虚化を防ぐ義務）と、
その系（初期状態からの複数歩の模倣 `run_init`、具体側の正常終了が実在すること `exists_ok`）。
-/

namespace Machine

open Machine.Adequacy

variable {σ τ ιa ιc οa οc ε : Type}

/-- リファインメントと、空虚化を防ぐ付帯の義務の束（references/docs/spec/architecture.md#空虚化を防ぐ義務）。
入口でない R 課題にも課せる形で、環境の固定（`Pinned`・`NoFaultReachable`）は含めない（基底が `ofChoice` の機械は
別に示す）。

- `refines`: R 課題の主定理
- `sound`・`initIs`: 抽象側の INV が空でなく、初期状態は fixture の 1 点 `s₀`
- `initSurj`: 抽象側の初期状態に、対応する具体側の初期状態がある
- `total`: INV と環境の前提 `Env` の下で PRE が成り立つ
- `envWitness`: 環境の前提を満たす像を持つ、具体側の入力がある
- `envNeeded`: 環境の前提を置かない（`Env = always`。PRE が INV の下で全域）か、環境の前提が無ければ PRE が
  成り立たない入力がある（前提は不要でない） -/
structure Adequate (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (s₀ : σ)
    (Env : ιa → Prop) : Prop where
  refines : Refines A C g
  sound : A.Sound
  initIs : A.InitIs s₀
  initSurj : Refines.InitSurj A C g
  total : A.TotalUnder Env
  envWitness : Refines.EnvWitness C g Env
  envNeeded : Env = always ∨ ¬ A.TotalUnder always

namespace Adequate

variable {A : Machine σ ιa οa} {C : Concrete τ ιc οc ε} {g : Glue σ τ ιa ιc οa οc} {s₀ : σ} {Env : ιa → Prop}

/-- 具体側の初期状態は、抽象側の初期状態 `s₀` と `J` で結ばれ、`s₀` は INV を満たす。 -/
theorem init_glue (h : Adequate A C g s₀ Env) {t : τ} (ht : C.Init t) : g.J s₀ t ∧ A.Inv s₀ := by
  obtain ⟨s, hs, hJ⟩ := h.refines.init t ht
  rw [(h.initIs s).1 hs] at hJ
  exact ⟨hJ, h.initIs.inv h.sound⟩

/-- 初期状態からの複数歩の模倣: 具体側の初期状態からの正常終了の列は、各入力が定義域と環境の前提を満たせば、
`s₀` からの PRE を満たす抽象側の歩みの列で、`J`・`αi`・`αo` を保って模倣される。 -/
theorem run_init (h : Adequate A C g s₀ Env) {t : τ} {ics : List ιc} {t' : τ} {ocs : List οc} (ht : C.Init t)
    (hr : C.Run t ics t' ocs) (hin : ∀ ic, ic ∈ ics → C.Dom ic ∧ ∀ ia, g.αi ic ia → Env ia) :
    ∃ ias s' oas, Forall₂ g.αi ics ias ∧ A.Run s₀ ias s' oas ∧ g.J s' t' ∧ A.Inv s' ∧ Forall₂ g.αo ocs oas :=
  let ⟨hJ, hi⟩ := h.init_glue ht
  h.refines.run h.sound h.total hi hJ hr hin

/-- 非空虚性: 環境の前提を満たす具体側の入力が、`s₀` に対応する具体側の初期状態から正常終了し、その結果は
抽象側の歩みで模倣される。リファインメントが、空でない具体側の振る舞いについて述べていることを示す。 -/
theorem exists_ok (h : Adequate A C g s₀ Env) :
    ∃ t ic ia t' oc s' oa, C.Init t ∧ C.Dom ic ∧ g.αi ic ia ∧ Env ia ∧ C.step t ic (.ok (t', oc)) ∧
      A.step s₀ ia s' oa ∧ g.J s' t' ∧ g.αo oc oa := by
  obtain ⟨ic, ia, hd, ha, he⟩ := h.envWitness
  have hi := h.initIs.inv h.sound
  obtain ⟨t, ht, hJ⟩ := h.initSurj s₀ ((h.initIs s₀).2 rfl)
  have hpre := h.total s₀ ia hi he
  obtain ⟨⟨r, hr⟩, hne⟩ := h.refines.applicable s₀ t ic ia hi hJ ha hpre hd
  match r, hr with
  | .error e, hr => exact absurd hr (hne e)
  | .ok (t', oc), hr =>
    obtain ⟨s', oa, hst, hJ', ho⟩ := h.refines.correct s₀ t ic ia t' oc hi hJ ha hpre hd hr
    exact ⟨t, ic, ia, t', oc, s', oa, ht, hd, ha, he, hr, hst, hJ', ho⟩

end Adequate

end Machine
