import Machine

/-!
# Test.Machine.Adequacy

`Machine.Adequacy` の義務の例と反例（references/docs/spec/architecture.md#空虚化を防ぐ義務）。抜け道ごとに、`Refines` は成り立つが、新しい義務が
成り立たないことを証明する。あわせて、すべての義務を満たす正例を示す。

| 抜け道 | 反例 |
| --- | --- |
| 具体側の不具合が、環境の非決定性（衝突）に紛れる | `buggy_refines`・`buggy_not_pinned` |
| 観測型の成分が `True` | `garbage_refines_top`・`top_not_nontrivial` |
| 全域の出力の抽象化が NaN を 0 に写す | `halfNaN_refines_total`・`halfNaN_not_refines_partial`・`aoTotal_not_injective` |
| 初期状態の偏り | `fullC_refines_specAny`・`fullC_not_initSurj` |
| 強すぎる PRE と、PRE の外への入力の写し | `garbage_refines_strong_bad`・`specStrong_not_total` |
| 差異の前提の外の 1 歩が状態を壊す | `langC_refines`・`langC_not_stateSafe` |
| 抽象側の INV が `False` | `junk_refines_invFalse`・`specInvF_not_sound` |
| `ce` が障害でない入力を障害の環境に写す | `buggy_pinned_ceCheat`・`ceCheat_not_noFaultReachable` |
| 自由な選択が結果をすべて吸収する | `junk_refines_specFree`・`fFree_frame_forgets_all` |
| 差異の前提の述語が `False` | `false_not_nontrivial` |
| 環境の前提の外への入力の写し | `specStrong_total_lt10`・`glueBad_not_envWitness` |
| 不要な差異（外しても成り立つ。references/docs/spec/architecture.md#空虚化を防ぐ義務） | `good_restrict_refines`・`devLang_unneeded_for_good` |
| 環境の選択が不具合を吸収する（`Refines` だけでは必要性が示せない。references/docs/spec/architecture.md#空虚化を防ぐ義務） | `buggy_restrict_refines`・`buggy_refines`・`devNot3_needed_for_buggy` |

成分の必要性（references/docs/spec/architecture.md#空虚化を防ぐ義務）の正例は、`devLang_needed_for_langErr`（前提型・`not_of_error`）、
`devNot3_needed_for_buggy`（前提型・`Pinned.not_of_mismatch`）、`obsNaN_needed`（観測型・`not_of_mismatch`）、
`specStrong_not_always`（環境の前提・`TotalUnder.not_always`）である。
-/

namespace Test.Machine.Adequacy

open _root_.Machine

/-! ## 正例: 衝突を環境の選択とする予約 -/

/-- 出力。 -/
inductive Out where
  | ok
  | full
  | conflict
  deriving DecidableEq, Repr

/-- 具体側の要求。`env` は環境（衝突が起きるか）、`lang` は具体側だけにある入力。 -/
structure Req where
  n : Nat
  env : Bool
  lang : Bool
  deriving DecidableEq, Repr

/-- 結果。選択の第 1 成分が環境（衝突）、第 2 成分が自由な選択（ここでは無い）。 -/
def fRes (s n : Nat) (c : Bool × Unit) : Nat × Out :=
  if c.1 then (s, .conflict) else if n ≤ s then (s - n, .ok) else (s, .full)

/-- 空席 5 から始まる予約。 -/
def spec : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fRes false ()

/-- 環境に従って衝突する、正しい具体機械。 -/
def good : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r => .ok (fRes t r.n (r.env, ()))

/-- 標準の貼り合わせ（観測型の差異なし）。 -/
def glue : Glue Nat Nat Nat Req Out Out :=
  Glue.ofStd some (fun _ => True) (fun r => some r.n) some

/-- 具体側の入力の環境。 -/
def ce (r : Req) : Bool := r.env

theorem glue_J {s t : Nat} : glue.J s t ↔ s = t := by
  simp [glue, Glue.ofStd, never, eq_comm]

theorem glue_αi {r : Req} {n : Nat} : glue.αi r n ↔ n = r.n := by
  simp [glue, Glue.ofStd, eq_comm]

theorem glue_αo {a b : Out} : glue.αo a b ↔ b = a := by
  simp [glue, Glue.ofStd, never, eq_comm]

theorem spec_sound : spec.Sound where
  init_inv _ _ := trivial
  step_inv _ _ _ _ _ _ _ := trivial

theorem spec_total : spec.TotalUnder fun _ => True := fun _ _ _ _ => trivial

theorem good_refines : Refines spec good glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct s t r ia t' oc _ hJ ha _ _ hs := by
    rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
    simp only [good, Concrete.ofFun_step, Except.ok.injEq] at hs
    exact ⟨t', oc, ⟨(r.env, ()), hs.symm⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

theorem good_pinned : Refines.Pinned spec good glue fRes ce := by
  intro s t r ia t' oc _ hJ ha _ _ hs
  rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
  simp only [good, Concrete.ofFun_step, Except.ok.injEq] at hs
  simp only [ce]
  exact ⟨(), by rw [← hs]; exact glue_J.2 rfl, by rw [← hs]; exact glue_αo.2 rfl⟩

theorem good_initSurj : Refines.InitSurj spec good glue :=
  fun s hs => ⟨s, hs, glue_J.2 rfl⟩

/-- 複数歩の模倣の使用例。 -/
theorem good_run {ics : List Req} {t' : Nat} {ocs : List Out} (hr : good.Run 5 ics t' ocs) :
    ∃ ias s' oas, Forall₂ glue.αi ics ias ∧ spec.Run 5 ias s' oas ∧ glue.J s' t' ∧ spec.Inv s' ∧
      Forall₂ glue.αo ocs oas :=
  good_refines.run spec_sound spec_total trivial (glue_J.2 rfl) hr fun _ _ => ⟨trivial, fun _ _ => trivial⟩

theorem good_noFaultReachable : Refines.NoFaultReachable good glue ce false :=
  fun r ia _ ha => ⟨{ r with env := false }, trivial, by rw [glue_αi] at ha ⊢; exact ha, rfl⟩

theorem fRes_frame : Machine.FreeFrame fRes fun r : Nat × Out => r :=
  fun _ _ _ x y => by cases x; cases y; rfl

theorem spec_initIs : spec.InitIs 5 := fun _ => Iff.rfl

theorem good_envWitness : Refines.EnvWitness good glue fun _ => True :=
  ⟨⟨0, false, false⟩, 0, trivial, glue_αi.2 rfl, trivial⟩

#guard spec.run 5 2 == (3, .ok)

/-! ## 反例 1: 具体側の不具合が衝突に紛れる -/

/-- `n = 3` のとき、環境と無関係に衝突を返す不具合を持つ具体機械。 -/
def buggy : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r =>
    if r.n = 3 then .ok (t, .conflict) else .ok (fRes t r.n (r.env, ()))

/-- 衝突は抽象側が許す結果なので、`Refines` は成り立ってしまう。 -/
theorem buggy_refines : Refines spec buggy glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ t r _ _ _ _ _ _ := by
    refine ⟨⟨_, rfl⟩, fun _ h => ?_⟩
    simp only [buggy, Concrete.ofFun_step] at h
    split at h <;> cases h
  correct s t r ia t' oc _ hJ ha _ _ hs := by
    rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
    simp only [buggy, Concrete.ofFun_step] at hs
    split at hs
    · simp only [Except.ok.injEq, Prod.mk.injEq] at hs
      obtain ⟨rfl, rfl⟩ := hs
      exact ⟨_, _, ⟨(true, ()), rfl⟩, glue_J.2 rfl, glue_αo.2 rfl⟩
    · simp only [Except.ok.injEq] at hs
      exact ⟨t', oc, ⟨(r.env, ()), hs.symm⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

/-- 環境の固定は成り立たない（衝突の無い環境で衝突を返す）。 -/
theorem buggy_not_pinned : ¬ Refines.Pinned spec buggy glue fRes ce := fun h => by
  obtain ⟨x, _, ho⟩ := h 5 5 ⟨3, false, false⟩ 3 5 .conflict trivial (glue_J.2 rfl) (glue_αi.2 rfl)
    trivial trivial rfl
  cases x
  simp [glue_αo, fRes, ce] at ho

/-! ## 反例 2: 観測型の成分が `True` -/

/-- 常に満席を返す具体機械。 -/
def garbage : Concrete Nat Req Out Unit := Concrete.ofFun (· = 5) fun t _ => .ok (t, .full)

/-- 出力の成分に `True` を置いた貼り合わせ。 -/
def glueTop : Glue Nat Nat Nat Req Out Out :=
  Glue.ofStd some (fun _ => True) (fun r => some r.n) some never fun _ _ => True

theorem garbage_refines_top : Refines spec garbage glueTop where
  init t ht := ⟨t, ht, Or.inl ⟨rfl, trivial⟩⟩
  input_total r _ := ⟨r.n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct s t r ia t' oc _ hJ _ _ _ hs := by
    simp only [garbage, Concrete.ofFun_step, Except.ok.injEq, Prod.mk.injEq] at hs
    obtain ⟨rfl, rfl⟩ := hs
    exact ⟨s, .conflict, ⟨(true, ()), rfl⟩, hJ, Or.inr trivial⟩

/-- 標準の貼り合わせでは成り立たない。 -/
theorem garbage_not_refines : ¬ Refines spec garbage glue := fun h => by
  obtain ⟨_, oa, ⟨c, hc⟩, _, ho⟩ :=
    h.correct 5 5 ⟨0, false, false⟩ 0 5 .full trivial (glue_J.2 rfl) (glue_αi.2 rfl) trivial trivial rfl
  rw [glue_αo] at ho; subst ho
  obtain ⟨b, _⟩ := c
  cases b <;> simp [fRes] at hc

/-- `True` の成分は自明である（W 課題の両向きの例が作れない）。 -/
theorem top_not_nontrivial : ¬ Nontrivial₂ fun (_ _ : Out) => True :=
  fun ⟨_, ⟨_, h⟩⟩ => h trivial

/-! ## 反例 3: 全域の出力の抽象化が NaN を 0 に写す -/

/-- 浮動小数点数の模擬。 -/
inductive Num where
  | num (n : Nat)
  | nan
  deriving DecidableEq, Repr

/-- 半分にする。 -/
def half : Machine.Machine Unit Nat Nat := Machine.pure (fun _ => True) (· / 2)

/-- 0 のとき NaN を返す具体機械。 -/
def halfNaN : Concrete Unit Nat Num Unit :=
  Concrete.pure fun n => .ok (if n = 0 then .nan else .num (n / 2))

/-- NaN を 0 に写す全域の抽象化（誤り）。 -/
def aoTotal : Num → Option Nat
  | .num n => some n
  | .nan => some 0

/-- NaN に α を定義しない部分写像（正しい）。 -/
def aoPartial : Num → Option Nat
  | .num n => some n
  | .nan => none

def glueNum (ao : Num → Option Nat) : Glue Unit Unit Nat Nat Nat Num :=
  Glue.ofStd (fun _ => some ()) (fun _ => True) some ao

theorem halfNaN_refines_total : Refines half halfNaN (glueNum aoTotal) where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total n _ := ⟨n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ n ia _ oc _ _ ha _ _ hs := by
    simp only [glueNum, Glue.ofStd, Option.some.injEq] at ha; subst ha
    simp only [halfNaN, Concrete.pure, Concrete.ofFun_step, Except.map, Except.ok.injEq,
      Prod.mk.injEq] at hs
    obtain ⟨-, rfl⟩ := hs
    refine ⟨(), n / 2, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ?_⟩
    by_cases h0 : n = 0
    · subst h0; rfl
    · simp [h0, aoTotal]

theorem halfNaN_not_refines_partial : ¬ Refines half halfNaN (glueNum aoPartial) := fun h => by
  obtain ⟨_, _, _, _, ho⟩ :=
    h.correct () () 0 0 () .nan trivial (Or.inl ⟨rfl, trivial⟩) rfl trivial trivial rfl
  simp [glueNum, Glue.ofStd, aoPartial, never] at ho

/-- 全域の抽象化は NaN と 0 を同一視する（核が等号でない）。 -/
theorem aoTotal_not_injective : ¬ KernelIs aoTotal Eq := fun h => by
  have := (h .nan (.num 0)).1 rfl
  cases this

theorem aoPartial_injective : KernelIs aoPartial Eq := by
  intro x y
  cases x <;> cases y <;> simp [aoPartial]

/-! ## 反例 4: 初期状態の偏り -/

/-- 初期状態を限らない予約（誤り）。 -/
def specAny : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (fun _ => True) (fun _ _ => True) fRes false ()

/-- 満席から始まる具体機械。成功する予約の経路を一度も通らない。 -/
def fullC : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 0) fun t r => .ok (fRes t r.n (r.env, ()))

theorem fullC_refines_specAny : Refines specAny fullC glue where
  init t _ := ⟨t, trivial, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct s t r ia t' oc _ hJ ha _ _ hs := by
    rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
    simp only [fullC, Concrete.ofFun_step, Except.ok.injEq] at hs
    exact ⟨t', oc, ⟨(r.env, ()), hs.symm⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

theorem fullC_not_initSurj : ¬ Refines.InitSurj specAny fullC glue := fun h => by
  obtain ⟨t, ht, hJ⟩ := h 5 trivial
  rw [glue_J] at hJ
  simp only [fullC, Concrete.ofFun] at ht
  omega

/-- 初期状態を fixture の 1 点にすると、`Refines` 自体が成り立たない。 -/
theorem fullC_not_refines : ¬ Refines spec fullC glue := fun h => by
  obtain ⟨s, hs, hJ⟩ := h.init 0 rfl
  rw [glue_J] at hJ
  simp only [spec, Machine.ofChoice] at hs
  omega

/-! ## 反例 5: 強すぎる PRE と、PRE の外への入力の写し -/

/-- 10 未満の要求だけを PRE とする予約。 -/
def specStrong : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ n => n < 10) fRes false ()

/-- 具体側のすべての入力を、PRE の外の入力 100 に写す貼り合わせ。 -/
def glueBad : Glue Nat Nat Nat Req Out Out :=
  Glue.ofStd some (fun _ => True) (fun _ => some 100) some

theorem garbage_refines_strong_bad : Refines specStrong garbage glueBad where
  init t ht := ⟨t, ht, Or.inl ⟨rfl, trivial⟩⟩
  input_total _ _ := ⟨100, rfl⟩
  applicable _ _ _ ia _ _ ha hp _ := by
    simp only [glueBad, Glue.ofStd, Option.some.injEq] at ha
    subst ha
    exact absurd (show 100 < 10 from hp) (by decide)
  correct _ _ _ ia _ _ _ _ ha hp _ _ := by
    simp only [glueBad, Glue.ofStd, Option.some.injEq] at ha
    subst ha
    exact absurd (show 100 < 10 from hp) (by decide)

/-- 入口の全域性は成り立たない。 -/
theorem specStrong_not_total : ¬ specStrong.TotalUnder fun _ => True := fun h =>
  absurd (show 100 < 10 from h 5 100 trivial trivial) (by decide)

/-! ## 反例 6: 差異の前提の外の 1 歩が状態を壊す -/

/-- `lang` が真のとき、出力は正しいが状態を 0 に壊す具体機械。 -/
def langC : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r =>
    if r.lang then .ok (0, (fRes t r.n (r.env, ())).2) else .ok (fRes t r.n (r.env, ()))

/-- 前提型の差異の述語の模擬（具体側だけにある入力）。 -/
def devLang (r : Req) : Prop := r.lang = false

theorem devLang_nontrivial : Nontrivial devLang :=
  ⟨⟨⟨0, false, false⟩, rfl⟩, ⟨⟨0, false, true⟩, by simp [devLang]⟩⟩

theorem langC_refines : Refines spec (langC.restrict devLang) glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ r _ _ _ _ _ hd := by
    have hl : r.lang = false := hd.2
    refine ⟨⟨_, rfl⟩, fun _ h => ?_⟩
    simp only [Concrete.restrict, langC, Concrete.ofFun_step, hl] at h
    cases h
  correct s t r ia t' oc _ hJ ha _ hd hs := by
    have hl : r.lang = false := hd.2
    rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
    simp only [Concrete.restrict, langC, Concrete.ofFun_step, hl] at hs
    exact ⟨t', oc, ⟨(r.env, ()), by simpa using hs.symm⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

theorem langC_not_stateSafe : ¬ Refines.StateSafeConcrete spec langC glue devLang := fun h => by
  obtain ⟨s', o, ⟨c, hc⟩, hJ⟩ :=
    h 5 5 ⟨0, false, true⟩ 0 0 .ok trivial (glue_J.2 rfl) (glue_αi.2 rfl) trivial
      (by simp [devLang]) trivial (by simp [langC, fRes])
  rw [glue_J] at hJ; subst hJ
  obtain ⟨b, _⟩ := c
  cases b <;> simp [fRes] at hc

/-! ## 反例 7: 抽象側の INV が `False` -/

/-- INV が `False` の予約（誤り）。 -/
def specInvF : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => False) (· = 5) (fun _ _ => True) fRes false ()

/-- 状態を壊し、常に満席を返す具体機械。 -/
def junk : Concrete Nat Req Out Unit := Concrete.ofFun (· = 5) fun t _ => .ok (t + 1, .full)

/-- 適用可能性・正しさは INV を仮定するので、空虚に成り立つ。 -/
theorem junk_refines_invFalse : Refines specInvF junk glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ _ _ hi := absurd hi id
  correct _ _ _ _ _ _ hi := absurd hi id

/-- 初期状態が INV を満たさないので、`Sound` は成り立たない（`InitIs` と合わせて INV は空でない）。 -/
theorem specInvF_not_sound : ¬ specInvF.Sound := fun h => h.init_inv 5 rfl

/-! ## 反例 8: `ce` が障害でない入力を障害の環境に写す -/

/-- `n = 3` の入力を、衝突の環境とみなす `ce`（誤り）。 -/
def ceCheat (r : Req) : Bool := r.env || decide (r.n = 3)

/-- 不具合を持つ `buggy` でも、`ceCheat` なら環境の固定が成り立ってしまう。 -/
theorem buggy_pinned_ceCheat : Refines.Pinned spec buggy glue fRes ceCheat := by
  intro s t r ia t' oc _ hJ ha _ _ hs
  rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
  simp only [buggy, Concrete.ofFun_step] at hs
  refine ⟨(), ?_⟩
  split at hs
  · rename_i h3
    simp only [Except.ok.injEq, Prod.mk.injEq] at hs
    obtain ⟨rfl, rfl⟩ := hs
    simp [ceCheat, h3, fRes, glue_J, glue_αo]
  · rename_i h3
    simp only [Except.ok.injEq] at hs
    rw [show ceCheat r = r.env by simp [ceCheat, h3], ← hs]
    exact ⟨glue_J.2 rfl, glue_αo.2 rfl⟩

/-- `n = 3` の入力は、障害の無い環境では実現できない。 -/
theorem ceCheat_not_noFaultReachable : ¬ Refines.NoFaultReachable buggy glue ceCheat false := fun h => by
  obtain ⟨r', _, ha, hce⟩ := h ⟨3, false, false⟩ 3 trivial (glue_αi.2 rfl)
  rw [glue_αi] at ha
  simp [ceCheat, ← ha] at hce

/-! ## 反例 9: 自由な選択が結果をすべて吸収する -/

/-- 自由な選択が結果そのものである予約（誤り）。 -/
def fFree (_ _ : Nat) (c : Bool × (Nat × Out)) : Nat × Out := c.2

def specFree : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fFree false (5, .ok)

theorem junk_refines_specFree : Refines specFree junk glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ _ _ t' oc _ _ _ _ _ _ := ⟨t', oc, ⟨(false, (t', oc)), rfl⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

/-- 自由な選択の枠を満たす射影は、すべての結果を同一視する（核が全体になる）。 -/
theorem fFree_frame_forgets_all {P : Type} (m : Nat × Out → P) (h : Machine.FreeFrame fFree m) :
    ∀ a b, m a = m b := fun a b => h 0 0 false a b

/-! ## 反例 10: 差異の前提の述語が `False` -/

theorem false_not_nontrivial : ¬ Nontrivial fun (_ : Req) => False := fun ⟨⟨_, h⟩, _⟩ => h

/-! ## 反例 11: 環境の前提の外への入力の写し -/

/-- 環境の前提を PRE と同じ強さにすれば、入口の全域性は成り立ってしまう。 -/
theorem specStrong_total_lt10 : specStrong.TotalUnder fun n => n < 10 := fun _ _ _ h => h

/-- しかし、どの具体側の入力の像も環境の前提を満たさない。 -/
theorem glueBad_not_envWitness : ¬ Refines.EnvWitness garbage glueBad fun n => n < 10 := fun h => by
  obtain ⟨_, ia, _, ha, he⟩ := h
  simp only [glueBad, Glue.ofStd, Option.some.injEq] at ha
  subst ha
  exact absurd he (by decide)

/-! ## 反例 12: 不要な差異（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- `good` に `devLang` の制限を付けた R 課題は成り立つ。`devLang` は両向きの例を持つ（`devLang_nontrivial`）。 -/
theorem good_restrict_refines : Refines spec (good.restrict devLang) glue :=
  Refines.restrictConcrete good_refines _

/-- しかし、制限を外しても `Refines` と `Pinned` が成り立つ。`devLang` の必要性は示せない（`good` は `lang` に
依存しない）。 -/
theorem devLang_unneeded_for_good : Refines spec good glue ∧ Refines.Pinned spec good glue fRes ce :=
  ⟨good_refines, good_pinned⟩

/-! ## 正例: 必要な前提型の差異（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- `lang` が真のとき正常終了しない具体機械（移植元の不具合による 500 の模擬）。 -/
def langErr : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r => if r.lang then .error () else .ok (fRes t r.n (r.env, ()))

theorem langErr_refines : Refines spec (langErr.restrict devLang) glue where
  init t ht := ⟨t, ht, glue_J.2 rfl⟩
  input_total r _ := ⟨r.n, glue_αi.2 rfl⟩
  applicable _ _ r _ _ _ _ _ hd := by
    have hl : r.lang = false := hd.2
    refine ⟨⟨_, rfl⟩, fun _ h => ?_⟩
    simp only [Concrete.restrict, langErr, Concrete.ofFun_step, hl] at h
    cases h
  correct s t r ia t' oc _ hJ ha _ hd hs := by
    have hl : r.lang = false := hd.2
    rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
    simp only [Concrete.restrict, langErr, Concrete.ofFun_step, hl] at hs
    exact ⟨t', oc, ⟨(r.env, ()), by simpa using hs.symm⟩, glue_J.2 rfl, glue_αo.2 rfl⟩

theorem langErr_pinned : Refines.Pinned spec (langErr.restrict devLang) glue fRes ce := by
  intro s t r ia t' oc _ hJ ha _ hd hs
  have hl : r.lang = false := hd.2
  rw [glue_J] at hJ; rw [glue_αi] at ha; subst hJ; subst ha
  simp only [Concrete.restrict, langErr, Concrete.ofFun_step, hl] at hs
  have hs' : fRes s r.n (r.env, ()) = (t', oc) := by simpa using hs.symm
  simp only [ce]
  exact ⟨(), by rw [hs']; exact glue_J.2 rfl, by rw [hs']; exact glue_αo.2 rfl⟩

theorem langErr_initSurj : Refines.InitSurj spec (langErr.restrict devLang) glue :=
  fun s hs => ⟨s, hs, glue_J.2 rfl⟩

theorem langErr_noFaultReachable : Refines.NoFaultReachable (langErr.restrict devLang) glue ce false :=
  fun r ia hd ha => ⟨{ r with env := false }, ⟨trivial, hd.2⟩, by rw [glue_αi] at ha ⊢; exact ha, rfl⟩

/-- `devLang` の必要性: 制限を外すと、`lang` が真の入力で具体側が正常終了しない。 -/
theorem devLang_needed_for_langErr :
    ¬ (Refines spec langErr glue ∧ Refines.Pinned spec langErr glue fRes ce) := fun h =>
  Refines.not_of_error (A := spec) (C := langErr) (g := glue) (s := 5) (t := 5)
    (ic := ⟨0, false, true⟩) (ia := 0) (e := ()) trivial (glue_J.2 rfl) (glue_αi.2 rfl) trivial trivial
    rfl h.1

/-! ## 反例 13: 環境の選択が不具合を吸収する（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- 前提型の差異の述語の模擬: `buggy` の不具合の入力（`n = 3`）を除く。 -/
def devNot3 (r : Req) : Prop := r.n ≠ 3

theorem devNot3_nontrivial : Nontrivial devNot3 :=
  ⟨⟨⟨0, false, false⟩, by simp [devNot3]⟩, ⟨⟨3, false, false⟩, by simp [devNot3]⟩⟩

theorem buggy_restrict_refines : Refines spec (buggy.restrict devNot3) glue :=
  Refines.restrictConcrete buggy_refines _

/-- 制限を外しても `Refines` は成り立つ（`buggy_refines`）。必要性は、`Pinned` を含めた命題でだけ示せる。 -/
theorem devNot3_needed_for_buggy :
    ¬ (Refines spec buggy glue ∧ Refines.Pinned spec buggy glue fRes ce) := fun h =>
  Refines.Pinned.not_of_mismatch (A := spec) (C := buggy) (g := glue) (f := fRes) (ce := ce) (s := 5)
    (t := 5) (ic := ⟨3, false, false⟩) (ia := 3) (t' := 5) (oc := .conflict) trivial (glue_J.2 rfl)
    (glue_αi.2 rfl) trivial trivial rfl
    (fun x _ ho => by cases x; simp [glue_αo, fRes, ce] at ho) h.2

/-! ## 正例: 必要な観測型の差異（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- 観測型の差異の成分の模擬: 具体側の NaN を抽象側の 0 に対応させる。 -/
def obsNaN (c : Num) (a : Nat) : Prop := c = .nan ∧ a = 0

theorem obsNaN_nontrivial : Nontrivial₂ obsNaN :=
  ⟨⟨(.nan, 0), by simp [obsNaN]⟩, ⟨(.num 0, 0), by simp [obsNaN]⟩⟩

/-- 部分写像の出力の抽象化に、観測型の成分 `obsNaN` を加えた貼り合わせ。 -/
def glueObs : Glue Unit Unit Nat Nat Nat Num :=
  Glue.ofStd (fun _ => some ()) (fun _ => True) some aoPartial never obsNaN

theorem halfNaN_refines_obs : Refines half halfNaN glueObs where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total n _ := ⟨n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ n ia _ oc _ _ ha _ _ hs := by
    simp only [glueObs, Glue.ofStd, Option.some.injEq] at ha; subst ha
    simp only [halfNaN, Concrete.pure, Concrete.ofFun_step, Except.map, Except.ok.injEq,
      Prod.mk.injEq] at hs
    obtain ⟨-, rfl⟩ := hs
    refine ⟨(), n / 2, rfl, Or.inl ⟨rfl, trivial⟩, ?_⟩
    by_cases h0 : n = 0
    · subst h0; exact Or.inr (And.intro rfl rfl)
    · exact Or.inl (by simp [h0, aoPartial])

/-- `obsNaN` の必要性: `never` に替えると、NaN の出力を模倣できない。 -/
theorem obsNaN_needed : ¬ Refines half halfNaN (glueNum aoPartial) :=
  Refines.not_of_mismatch (A := half) (C := halfNaN) (g := glueNum aoPartial) (s := ()) (t := ())
    (ic := 0) (ia := 0) (t' := ()) (oc := .nan) trivial (Or.inl ⟨rfl, trivial⟩) rfl trivial trivial rfl
    (fun _ _ _ _ ho => by simp [glueNum, Glue.ofStd, aoPartial, never] at ho)

/-! ## 正例: 必要な環境の前提（references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- `specStrong` の PRE（`n < 10`）は、環境の前提なしには成り立たない。 -/
theorem specStrong_not_always : ¬ specStrong.TotalUnder always :=
  Machine.TotalUnder.not_always (A := specStrong) (s := 5) (i := 100) trivial (show ¬ (100 < 10) by decide)

end Test.Machine.Adequacy
