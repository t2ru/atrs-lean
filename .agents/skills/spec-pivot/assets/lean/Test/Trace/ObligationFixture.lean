import Trace
import Machine
import Test.Machine.Preserves

/-!
# Test.Trace.ObligationFixture

`obligation-check`（`Trace.Obligation`）のフィクスチャ。`Test.Trace.ObligationFixture.<層>` の下に、規則をすべて満たす R 課題と、
規則ごとの違反例を置く（テストは接頭辞 `Test.Trace.ObligationFixture` を除いた名前で層を決める）。違反例には、実装後の敵対的レビューで
作られた迂回（references/docs/spec/architecture.md#空虚化を防ぐ義務 の「実装後の敵対的レビュー」）を含める。証明は `Test.Machine.Preserves` の定理を定義の展開で使い回す。

期待する判定は `Test/Trace/Main.lean` の `obligationTests` に書く。
-/

open Machine
open Test.Machine.Preserves (Out Req Num)

open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)

namespace Test.Trace.ObligationFixture.Spec

/-- 衝突の選択（環境）。 -/
@[nondet "N-901"] abbrev Conflict : Type := Bool

/-- 結果の全体（自由な選択として吸収に使う。誤り）。 -/
@[nondet "N-902"] abbrev AnyResult : Type := Nat × Out

/-- 結果（`Test.Machine.Preserves.fRes` と同じ）。 -/
def fRes (s n : Nat) (c : Conflict × Unit) : Nat × Out := Test.Machine.Preserves.fRes s n c

/-- 抽象機械。 -/
def spec : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fRes false ()

theorem spec_sound : spec.Sound := Test.Machine.Preserves.spec_sound
theorem spec_initIs : spec.InitIs 5 := fun _ => Iff.rfl

/-- 環境の前提。 -/
@[env_pre "MD-901"] def envOk (n : Nat) : Prop := n < 1000

theorem envOk_nontrivial : Nontrivial envOk :=
  ⟨⟨0, show 0 < 1000 by decide⟩, ⟨1000, show ¬ 1000 < 1000 by decide⟩⟩
/-- `spec` の PRE は全域なので、環境の前提を置かずに全域性を示す（G9）。 -/
theorem spec_total : spec.TotalUnder always := fun _ _ _ _ => trivial

/-- 選択の型に `@[nondet]` の無い抽象機械。 -/
def specBool : Machine.Machine Nat Nat Out := Test.Machine.Preserves.spec

/-- 選択の像でない（関係で与えた）抽象機械。 -/
def specRel : Machine.Machine Nat Nat Out where
  Inv _ := True
  Init s := s = 5
  Pre _ _ := True
  step _ _ _ _ := True
  run s _ := (s, .full)
  run_step _ _ _ := trivial

/-- INV が `False` の抽象機械。 -/
def specInvF : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => False) (· = 5) (fun _ _ => True) fRes false ()

theorem specInvF_initIs : specInvF.InitIs 5 := fun _ => Iff.rfl

/-- 自由な選択が結果そのものである抽象機械。 -/
def fFree (s n : Nat) (c : Conflict × AnyResult) : Nat × Out := Test.Machine.Preserves.fFree s n c

def specFree : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fFree false (5, .ok)

theorem specFree_sound : specFree.Sound := ⟨fun _ _ => trivial, fun _ _ _ _ _ _ _ => trivial⟩
theorem specFree_initIs : specFree.InitIs 5 := fun _ => Iff.rfl

/-- PRE を入力の値域で制限した抽象機械（環境の前提の必要性の正例。references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
def specPre : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ n => n < 1000) fRes false ()

theorem specPre_total : specPre.TotalUnder envOk := fun _ _ _ h => h
theorem specPre_needs_env : ¬ specPre.TotalUnder always :=
  Machine.TotalUnder.not_always (A := specPre) (s := 5) (i := 1000) trivial (show ¬ (1000 < 1000) by decide)

/-- 必要性の定理の無い環境の前提（違反例。`specFree` の PRE は常に成り立つ）。 -/
@[env_pre "MD-902"] def envNoNeed (n : Nat) : Prop := n < 2000

theorem envNoNeed_nontrivial : Nontrivial envNoNeed :=
  ⟨⟨0, show 0 < 2000 by decide⟩, ⟨2000, show ¬ 2000 < 2000 by decide⟩⟩
theorem specFree_total : specFree.TotalUnder envNoNeed := fun _ _ _ _ => trivial

/-- 純粋な計算の抽象機械（観測型の差異の必要性の正例）。 -/
def half : Machine.Machine Unit Nat Nat := Test.Machine.Preserves.half

theorem half_sound : half.Sound := Machine.sound_pure (fun _ => True) (· / 2)
theorem half_initIs : half.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

end Test.Trace.ObligationFixture.Spec

open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)
open Test.Trace.ObligationFixture.Spec

namespace Test.Trace.ObligationFixture.SourceModel

/-- 具体機械。 -/
def good : Concrete Nat Req Out Unit := Test.Machine.Preserves.good

/-- 付帯の定理の無い具体機械。 -/
def good2 : Concrete Nat Req Out Unit := Test.Machine.Preserves.good

/-- 不具合を持つ具体機械。 -/
def buggy : Concrete Nat Req Out Unit := Test.Machine.Preserves.buggy

/-- 状態を壊す具体機械。 -/
def junk : Concrete Nat Req Out Unit := Test.Machine.Preserves.junk

/-- `Dom` を設定した具体機械。 -/
def domSet : Concrete Nat Req Out Unit where
  Init := good.Init
  Dom r := True ∧ r.n < 100
  step := good.step

/-- 抽象機械そのものを具体機械とする（同語反復）。 -/
def taut : Concrete Nat Nat Out Unit := Concrete.ofMachine spec

/-- `lang` が真のとき正常終了しない具体機械（必要な差異の正例。references/docs/spec/architecture.md#空虚化を防ぐ義務）。 -/
def langErr : Concrete Nat Req Out Unit := Test.Machine.Preserves.langErr

/-- `langErr` と同じ具体機械（別の基底の違反例のため）。 -/
def langErr2 : Concrete Nat Req Out Unit := Test.Machine.Preserves.langErr

/-- 0 で NaN を返す具体機械（必要な観測型の差異の正例）。 -/
def halfNaN : Concrete Unit Nat Num Unit := Test.Machine.Preserves.halfNaN

/-- `Spec` の関数を使う具体機械。 -/
def usesSpec : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r => .ok (Spec.fRes t r.n (r.env, ()))

end Test.Trace.ObligationFixture.SourceModel

open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)
open Test.Trace.ObligationFixture.Spec Test.Trace.ObligationFixture.SourceModel

namespace Test.Trace.ObligationFixture.Abstraction

/-- 標準の抽象化（葉）: 状態。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def betaS (t : Nat) : Option Nat := some t

/-- 標準の抽象化（合成）: 入力。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aiS (r : Req) : Option Nat := Option.some r.n

/-- 標準の抽象化（葉）: 出力。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoS (o : Out) : Option Out := some o

/-- 標準の抽象化（合成）: 環境。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def ceS (r : Req) : Bool := r.env

theorem betaS_kernel : KernelIs betaS Eq := fun x y => by simp [betaS]
theorem aoS_kernel : KernelIs aoS Eq := fun x y => by simp [aoS]

/-- 前提型の差異の述語。 -/
@[deviation "D-901"] def devLang (r : Req) : Prop := r.lang = false

theorem devLang_nontrivial : Nontrivial devLang := Test.Machine.Preserves.devLang_nontrivial

/-- 標準の貼り合わせ。 -/
abbrev glue : Glue Nat Nat Nat Req Out Out := Glue.ofStd betaS (fun _ => True) aiS aoS

/-! ## 正例 -/

@[obligation "ABS-901"]
theorem good_refines : Refines spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines _

theorem good_initSurj : Refines.InitSurj spec (good.restrict devLang) glue :=
  Test.Machine.Preserves.good_initSurj

theorem good_pinned : Refines.Pinned spec (good.restrict devLang) glue fRes ceS :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    Test.Machine.Preserves.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

theorem good_noFault : Refines.NoFaultReachable (good.restrict devLang) glue ceS false :=
  fun r _ hd ha => ⟨{ r with env := false }, ⟨trivial, hd.2⟩, ha, rfl⟩

theorem good_envWitness : Refines.EnvWitness (good.restrict devLang) glue always :=
  ⟨⟨0, false, false⟩, 0, ⟨trivial, rfl⟩, rfl, trivial⟩

theorem good_stateSafe : Refines.StateSafeConcrete spec good glue devLang :=
  fun s t ic ia t' oc hi hJ ha hp _ hd hs => by
    obtain ⟨s', o, hst, hJ', _⟩ :=
      Test.Machine.Preserves.good_refines.correct s t ic ia t' oc hi hJ ha hp hd hs
    exact ⟨s', o, hst, hJ'⟩

/-- 選択の像の材料（`spec` の `f`・`e₀`、`@[std_abs]` の `ceS`）。自由な選択は無いので、枠の射影は恒等でよい。 -/
def choiceS : Machine.Preserves.Choice Nat Nat Out Req := ⟨Conflict, Unit, Nat × Out, fRes, ceS, false, fun r => r⟩

theorem fRes_frame : Machine.FreeFrame fRes (fun r : Nat × Out => r) :=
  fun _ _ _ x y => by cases x; cases y; rfl

/-- 正例（G6・GP）: R 課題 `good_refines`（ABS-901）の束。基底が `ofChoice` なので `ch = some choiceS`、
「出力のみ」の差異 `devLang` の層を `outsC` に置く。 -/
@[obligation "ABS-901"]
theorem good_preserves :
    Machine.Preserves spec (good.restrict devLang) glue 5 always (some choiceS) [] [⟨good, devLang⟩] where
  sound := spec_sound
  initIs := spec_initIs
  initSurj := good_initSurj
  total := spec_total
  envWitness := good_envWitness
  envNeeded := .inl rfl
  pinned _ h := by cases h; exact good_pinned
  noFault _ h := by cases h; exact good_noFault
  freeFrame _ h := by cases h; exact fRes_frame
  stateSafeC _ h := by simp only [List.mem_singleton] at h; subst h; exact good_stateSafe

/-- 貼り合わせを `abbrev` で書いた正例（付帯の定理は展開形で照合される）。 -/
@[obligation "ABS-902"]
theorem good_abbrev : Refines spec (good.restrict devLang) glue := good_refines

@[obligation "ABS-902"]
theorem good_abbrev_preserves :
    Machine.Preserves spec (good.restrict devLang) glue 5 always (some choiceS) [] [⟨good, devLang⟩] :=
  good_preserves

/-! ## 違反例 -/

@[obligation "ABS-911"]
theorem v1_forall (_ : True) : Refines spec (good.restrict devLang) glue := good_refines

@[obligation "ABS-911"]
theorem v1_preserves :
    Machine.Preserves spec (good.restrict devLang) glue 5 always (some choiceS) [] [⟨good, devLang⟩] :=
  good_preserves

/-- `@[deviation]` の無い述語。 -/
def plainLang (r : Req) : Prop := r.lang = false

@[obligation "ABS-912"]
theorem v2_plainRestrict : Refines spec (good.restrict plainLang) glue :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines _

theorem v2_initSurj : Refines.InitSurj spec (good.restrict plainLang) glue :=
  Test.Machine.Preserves.good_initSurj

theorem v2_pinned : Refines.Pinned spec (good.restrict plainLang) glue fRes ceS :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    Test.Machine.Preserves.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

theorem v2_noFault : Refines.NoFaultReachable (good.restrict plainLang) glue ceS false :=
  fun r _ hd ha => ⟨{ r with env := false }, ⟨trivial, hd.2⟩, ha, rfl⟩

@[obligation "ABS-912"]
theorem v2_preserves : Machine.Preserves spec (good.restrict plainLang) glue 5 always (some choiceS) where
  sound := spec_sound
  initIs := spec_initIs
  initSurj := v2_initSurj
  total := spec_total
  envWitness := ⟨⟨0, false, false⟩, 0, ⟨trivial, rfl⟩, rfl, trivial⟩
  envNeeded := .inl rfl
  pinned _ h := by cases h; exact v2_pinned
  noFault _ h := by cases h; exact v2_noFault
  freeFrame _ h := by cases h; exact fRes_frame

/-- 引数を取る差異の述語（引数で `False` にできる）。 -/
@[deviation "D-903"] def devK (k : Nat) (r : Req) : Prop := r.n < k

@[obligation "ABS-913"]
theorem v2_paramDev : Refines spec (good.restrict (devK 0)) glue :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines _

@[obligation "ABS-914"]
theorem v3_choiceNoNondet : Refines specBool good glue := Test.Machine.Preserves.good_refines

@[obligation "ABS-915"]
theorem v3_relSpec : Refines specRel good glue where
  init t ht := ⟨t, ht, Or.inl ⟨rfl, trivial⟩⟩
  input_total r _ := ⟨r.n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ _ _ t' oc _ _ _ _ _ _ := ⟨t', oc, trivial, Or.inl ⟨rfl, trivial⟩, Or.inl rfl⟩

@[obligation "ABS-916"]
theorem v3_free : Refines specFree junk glue := Test.Machine.Preserves.junk_refines_specFree

@[obligation "ABS-917"]
theorem v4_domSet : Refines spec domSet glue :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines fun r => r.n < 100

/-- `Nat` の入力をそのまま写す標準の抽象化（同語反復の例のため）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aiNat (n : Nat) : Option Nat := some n

@[obligation "ABS-918"]
theorem v4_taut : Refines spec taut (Glue.ofStd betaS (fun _ => True) aiNat aoS) where
  init t ht := ⟨t, ht, Or.inl ⟨rfl, trivial⟩⟩
  input_total n _ := ⟨n, rfl⟩
  applicable s t _ ia _ hJ ha hp _ := by
    simp only [Glue.ofStd, betaS, aiNat, never, Option.some.injEq, and_true, or_false] at hJ ha
    subst hJ; subst ha
    exact (Refines.refl spec).applicable _ _ _ _ trivial rfl rfl hp trivial
  correct s t _ ia t' oc _ hJ ha hp _ hs := by
    simp only [Glue.ofStd, betaS, aiNat, never, Option.some.injEq, and_true, or_false] at hJ ha
    subst hJ; subst ha
    obtain ⟨s', oa, hst, hJ', ho⟩ := (Refines.refl spec).correct _ _ _ _ _ _ trivial rfl rfl hp trivial hs
    refine ⟨s', oa, hst, Or.inl ⟨?_, trivial⟩, Or.inl ?_⟩
    · show some t' = some s'; rw [show s' = t' from hJ']
    · show some oc = some oa; rw [show oc = oa from ho]

@[obligation "ABS-919"]
theorem v4_usesSpec : Refines spec usesSpec glue := Test.Machine.Preserves.good_refines

/-- 補助定義（`@[reducible]` でない）で包んだ貼り合わせ。 -/
def myGlue : Glue Nat Nat Nat Req Out Out := Glue.ofStd betaS (fun _ => True) aiS aoS

@[obligation "ABS-920"]
theorem v5_helperGlue : Refines spec good myGlue := Test.Machine.Preserves.good_refines

/-- `@[deviation]` の無い観測の成分。 -/
def obsPlain (_ _ : Out) : Prop := False

@[obligation "ABS-921"]
theorem v5_plainObs : Refines spec good (Glue.ofStd betaS (fun _ => True) aiS aoS never obsPlain) :=
  Test.Machine.Preserves.good_refines

/-- `@[std_abs]` の無い入力の写像。 -/
def aiPlain (r : Req) : Option Nat := some r.n

@[obligation "ABS-922"]
theorem v5_plainAi : Refines spec good (Glue.ofStd betaS (fun _ => True) aiPlain aoS) :=
  Test.Machine.Preserves.good_refines

/-- 核の定理の無い出力の写像（合成）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoComp (o : Out) : Option Out := Option.some o

@[obligation "ABS-923"]
theorem v5_aoNoKernel : Refines spec good (Glue.ofStd betaS (fun _ => True) aiS aoComp) :=
  Test.Machine.Preserves.good_refines

@[obligation "ABS-924"]
theorem v6_noCompanions : Refines spec good2 glue := Test.Machine.Preserves.good_refines

@[obligation "ABS-925"]
theorem v6_invFalse : Refines specInvF junk glue := Test.Machine.Preserves.junk_refines_invFalse

theorem v6_invFalse_initSurj : Refines.InitSurj specInvF junk glue := fun s hs => ⟨s, hs, Or.inl ⟨hs ▸ rfl, trivial⟩⟩

theorem v6_invFalse_pinned : Refines.Pinned specInvF junk glue fRes ceS := fun _ _ _ _ _ _ hi => absurd hi id

theorem v6_invFalse_noFault : Refines.NoFaultReachable junk glue ceS false :=
  fun r _ _ ha => ⟨{ r with env := false }, trivial, ha, rfl⟩

/-- `n = 3` を衝突の環境とみなす `ce`（誤り）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def ceCheat (r : Req) : Bool := Test.Machine.Preserves.ceCheat r

@[obligation "ABS-926"]
theorem v6_ceCheat : Refines spec buggy glue := Test.Machine.Preserves.buggy_refines

theorem v6_ceCheat_initSurj : Refines.InitSurj spec buggy glue := fun s hs => ⟨s, hs, Or.inl ⟨rfl, trivial⟩⟩

theorem v6_ceCheat_pinned : Refines.Pinned spec buggy glue fRes ceCheat := Test.Machine.Preserves.buggy_pinned_ceCheat

/-- 分岐を含む合成の標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoIf (o : Out) : Option Out := if o = .full then some .ok else some o

/-- 部分写像の汎用の核: どちらも定義されないか、等しい。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def undefOrEqF {α β : Type} (f : α → Option β) (x y : α) : Prop := (f x = none ∧ f y = none) ∨ x = y

/-- 部分単射の葉（分岐を含むが、核の定理で受ける。核は汎用の核をこの葉に適用したもの）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoPart (o : Out) : Option Out := if o = .full then none else some o

theorem aoPart_kernel : KernelIs aoPart (undefOrEqF aoPart) := by
  intro x y; cases x <;> cases y <;> simp [aoPart, undefOrEqF]

/-- 同じ形の葉だが、核の定理は汎用の核を別の葉に適用している（受けない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoPart2 (o : Out) : Option Out := if o = .full then none else some o

theorem aoPart2_kernel : KernelIs aoPart2 (undefOrEqF aoPart) := by
  intro x y; cases x <;> cases y <;> simp [aoPart2, aoPart, undefOrEqF]

/-- 部分単射の葉。核はスキルの汎用の核 `Machine.Kernel.undefOrEq` をこの葉に適用したもの（受ける）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoPart3 (o : Out) : Option Out := if o = .full then none else some o

theorem aoPart3_kernel : KernelIs aoPart3 (Machine.Kernel.undefOrEq aoPart3) := by
  intro x y; cases x <;> cases y <;> simp [aoPart3, Machine.Kernel.undefOrEq]

/-- 同じ形の葉だが、`Machine.Kernel.undefOrEq` を別の葉に適用している（受けない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoPart4 (o : Out) : Option Out := if o = .full then none else some o

theorem aoPart4_kernel : KernelIs aoPart4 (Machine.Kernel.undefOrEq aoPart) := by
  intro x y; cases x <;> cases y <;> simp [aoPart4, aoPart, Machine.Kernel.undefOrEq]

/-- 関数を引数に取る標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def via (h : Out → Option Out) (o : Out) : Option Out := h o

/-- `Nontrivial` の無い差異の述語。 -/
@[deviation "D-902"] def devNoW (r : Req) : Prop := r.n < 3

/-- `Refines` を結論に持たない R 課題。 -/
@[obligation "ABS-927"]
theorem v0_notRefines : Refines spec (good.restrict devLang) glue ∧ True := ⟨good_refines, trivial⟩

/-! ## 成分の必要性（G9。references/docs/spec/architecture.md#空虚化を防ぐ義務） -/

/-- 正例: 前提型の差異 `devLang` が必要な R 課題。 -/
@[obligation "ABS-950"]
theorem need_refines : Refines spec (langErr.restrict devLang) glue := Test.Machine.Preserves.langErr_refines

theorem need_initSurj : Refines.InitSurj spec (langErr.restrict devLang) glue :=
  Test.Machine.Preserves.langErr_initSurj

theorem need_pinned : Refines.Pinned spec (langErr.restrict devLang) glue fRes ceS :=
  Test.Machine.Preserves.langErr_pinned

theorem need_noFault : Refines.NoFaultReachable (langErr.restrict devLang) glue ceS false :=
  Test.Machine.Preserves.langErr_noFaultReachable

@[obligation "ABS-950"]
theorem need_preserves : Machine.Preserves spec (langErr.restrict devLang) glue 5 always (some choiceS) where
  sound := spec_sound
  initIs := spec_initIs
  initSurj := need_initSurj
  total := spec_total
  envWitness := ⟨⟨0, false, false⟩, 0, ⟨trivial, rfl⟩, rfl, trivial⟩
  envNeeded := .inl rfl
  pinned _ h := by cases h; exact need_pinned
  noFault _ h := by cases h; exact need_noFault
  freeFrame _ h := by cases h; exact fRes_frame

/-- `devLang` の必要性。W 課題の形で `@[obligation]` を付けても、G0 の誤りにならない。 -/
@[obligation "ABS-951", gap "D-901"]
theorem need_devLang : ¬ (Refines spec langErr glue ∧ Refines.Pinned spec langErr glue fRes ceS) :=
  Test.Machine.Preserves.devLang_needed_for_langErr

/-- 正例（観測型・基底が `pure`）の標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def betaU (t : Unit) : Option Unit := some t

@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoNum (o : Num) : Option Nat :=
  Test.Machine.Preserves.aoPartial o

theorem aoNum_kernel : KernelIs aoNum Eq := Test.Machine.Preserves.aoPartial_injective

/-- 観測型の差異の成分。 -/
@[deviation "D-907"] def obsNaN (c : Num) (a : Nat) : Prop := Test.Machine.Preserves.obsNaN c a

theorem obsNaN_nontrivial : Nontrivial₂ obsNaN := Test.Machine.Preserves.obsNaN_nontrivial

/-- 正例: 観測型の差異 `obsNaN` が必要な R 課題。 -/
@[obligation "ABS-954"]
theorem obs_refines : Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) :=
  Test.Machine.Preserves.halfNaN_refines_obs

theorem obs_initSurj :
    Refines.InitSurj half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- 正例（GP）: R 課題 `obs_refines`（ABS-954）の束。基底が `pure` なので `ch = none`（既定値）。PRE が全域なので、
環境の前提を置かない。 -/
@[obligation "ABS-954"]
theorem obs_preserves :
    Machine.Preserves half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) () always where
  sound := half_sound
  initIs := half_initIs
  initSurj := obs_initSurj
  total _ _ _ _ := trivial
  envWitness := ⟨0, 0, trivial, rfl, trivial⟩
  envNeeded := .inl rfl

/-- 違反（GP）: 同じ ID の R 課題（`obs_refines`）と、束ねる機械・貼り合わせが違う。 -/
@[obligation "ABS-954"]
theorem gp_mismatch :
    Machine.Preserves Test.Machine.Preserves.halfSmall Test.Machine.Preserves.halfC
      (Test.Machine.Preserves.glueNum Test.Machine.Preserves.aoPartial) () (· < 100) :=
  Test.Machine.Preserves.halfC_preserves

/-- 違反（GP）: 同じ ID の R 課題が無い束。 -/
@[obligation "ABS-998"]
theorem gp_noR :
    Machine.Preserves half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) () always :=
  obs_preserves

@[gap "D-907"] theorem obs_needed : ¬ Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never never) :=
  Test.Machine.Preserves.obsNaN_needed

/-- 違反例: 外しても成り立つ差異（必要性の定理が無い）。 -/
@[deviation "D-905"] def devUnneeded (r : Req) : Prop := r.lang = false

theorem devUnneeded_nontrivial : Nontrivial devUnneeded := Test.Machine.Preserves.devLang_nontrivial

@[obligation "ABS-952"]
theorem v9_unneeded : Refines spec (good.restrict devUnneeded) glue :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines _

/-- 正例: 基底が `ofChoice` でも、必要性を（より強い）`¬ Refines` で示してよい。 -/
@[deviation "D-906"] def devLang2 (r : Req) : Prop := r.lang = false

theorem devLang2_nontrivial : Nontrivial devLang2 := Test.Machine.Preserves.devLang_nontrivial

@[obligation "ABS-953"]
theorem v9_noPinned : Refines spec (langErr2.restrict devLang2) glue := Test.Machine.Preserves.langErr_refines

theorem v9_noPinned_initSurj : Refines.InitSurj spec (langErr2.restrict devLang2) glue :=
  Test.Machine.Preserves.langErr_initSurj

theorem v9_noPinned_pinned : Refines.Pinned spec (langErr2.restrict devLang2) glue fRes ceS :=
  Test.Machine.Preserves.langErr_pinned

theorem v9_noPinned_noFault : Refines.NoFaultReachable (langErr2.restrict devLang2) glue ceS false :=
  Test.Machine.Preserves.langErr_noFaultReachable

@[obligation "ABS-953"]
theorem v9_noPinned_preserves : Machine.Preserves spec (langErr2.restrict devLang2) glue 5 always (some choiceS) where
  sound := spec_sound
  initIs := spec_initIs
  initSurj := v9_noPinned_initSurj
  total := spec_total
  envWitness := ⟨⟨0, false, false⟩, 0, ⟨trivial, rfl⟩, rfl, trivial⟩
  envNeeded := .inl rfl
  pinned _ h := by cases h; exact v9_noPinned_pinned
  noFault _ h := by cases h; exact v9_noPinned_noFault
  freeFrame _ h := by cases h; exact fRes_frame

@[gap "D-906"] theorem v9_noPinned_nec : ¬ Refines spec langErr2 glue :=
  Refines.not_of_error (A := spec) (C := langErr2) (g := glue) (s := 5) (t := 5)
    (ic := ⟨0, false, true⟩) (ia := 0) (e := ()) trivial (Or.inl ⟨rfl, trivial⟩) rfl trivial trivial rfl

/-- 正例: 必要性を `→ False` の形で書いた W 課題（G0 の誤りにならない）。 -/
@[obligation "ABS-955", gap "D-905"]
theorem need_arrow : Refines spec langErr2 glue → False := v9_noPinned_nec

/-- 同じ差異 ID の別の定数（差異 ID ごとに必要性を数えるので、G9 の誤りにならない）。 -/
@[deviation "D-901"] def devLangB (r : Req) : Prop := r.lang = false

theorem devLangB_nontrivial : Nontrivial devLangB := Test.Machine.Preserves.devLang_nontrivial

@[obligation "ABS-956"]
theorem v9_sameId : Refines spec (good.restrict devLangB) glue :=
  Refines.restrictConcrete Test.Machine.Preserves.good_refines _

/-- 違反例: 2 つの差異 ID を 1 つの定数に束ねる。 -/
@[deviation "D-908", "D-909"] def devTwo (r : Req) : Prop := r.lang = false

theorem devTwo_nontrivial : Nontrivial devTwo := Test.Machine.Preserves.devLang_nontrivial

/-- 正例: 必要な `devLang` に覆われる差異（被覆）。 -/
@[deviation "D-910"] def devWeak (r : Req) : Prop := r.lang = false ∨ 50 < r.n

theorem devWeak_nontrivial : Nontrivial devWeak :=
  ⟨⟨⟨0, false, false⟩, Or.inl rfl⟩, ⟨⟨0, false, true⟩, by simp [devWeak]⟩⟩

@[gap "D-910"] theorem devWeak_covered : Covers devLang devWeak := fun _ h => Or.inl h

@[obligation "ABS-957"]
theorem cover_refines : Refines spec ((langErr.restrict devLang).restrict devWeak) glue :=
  Refines.restrictConcrete Test.Machine.Preserves.langErr_refines _

/-- 違反例: 互いに覆い合うだけで、どちらも必要でない差異（被覆の循環）。 -/
@[deviation "D-911"] def devC1 (r : Req) : Prop := r.lang = false
@[deviation "D-912"] def devC2 (r : Req) : Prop := r.lang = false

theorem devC1_nontrivial : Nontrivial devC1 := Test.Machine.Preserves.devLang_nontrivial
theorem devC2_nontrivial : Nontrivial devC2 := Test.Machine.Preserves.devLang_nontrivial
@[gap "D-912"] theorem devC1_covers : Covers devC1 devC2 := fun _ h => h
@[gap "D-911"] theorem devC2_covers : Covers devC2 devC1 := fun _ h => h

@[obligation "ABS-958"]
theorem v9_circular : Refines spec ((good.restrict devC1).restrict devC2) glue :=
  Refines.restrictConcrete (Refines.restrictConcrete Test.Machine.Preserves.good_refines _) _

/-- 同じ出力に重なる 2 つ目の観測型の差異（`anyOf` で並べる。必要性が無いので違反例）。 -/
@[deviation "D-913"] def obsZero (c : Num) (a : Nat) : Prop := c = .num 0 ∧ a = 1

theorem obsZero_nontrivial : Nontrivial₂ obsZero :=
  ⟨⟨(.num 0, 1), by simp [obsZero]⟩, ⟨(.nan, 0), by simp [obsZero]⟩⟩

@[obligation "ABS-959"]
theorem obs2_refines :
    Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never (anyOf obsNaN obsZero)) where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total n _ := ⟨n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct s t n ia t' oc hi hJ ha hp hd hs := by
    obtain ⟨s', oa, hst, hJ', ho⟩ := obs_refines.correct s t n ia t' oc hi hJ ha hp hd hs
    refine ⟨s', oa, hst, hJ', ?_⟩
    rcases ho with ho | ho
    · exact Or.inl ho
    · exact Or.inr (Or.inl ho)

theorem obs2_initSurj :
    Refines.InitSurj half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never (anyOf obsNaN obsZero)) :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

@[obligation "ABS-959"]
theorem obs2_preserves :
    Machine.Preserves half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never (anyOf obsNaN obsZero)) () always where
  sound := half_sound
  initIs := half_initIs
  initSurj := obs2_initSurj
  total _ _ _ _ := trivial
  envWitness := ⟨0, 0, trivial, rfl, trivial⟩
  envNeeded := .inl rfl

/-- `anyOf` の葉 `obsNaN` だけを `never` に替えた必要性。 -/
theorem obs2_needed :
    ¬ Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never (anyOf never obsZero)) :=
  Refines.not_of_mismatch (s := ()) (t := ()) (ic := 0) (ia := 0) (t' := ()) (oc := .nan) trivial
    (Or.inl ⟨rfl, trivial⟩) rfl trivial trivial rfl
    (fun _ _ _ _ ho => by
      simp [Glue.ofStd, aoNum, Test.Machine.Preserves.aoPartial, never, anyOf, obsZero] at ho)

/-- 正例: PRE が全域でない基底での環境の前提（`specPre_needs_env` があるので G9 の誤りにならない）。 -/
@[obligation "ABS-960"]
theorem pre_refines : Refines specPre good glue where
  init := Test.Machine.Preserves.good_refines.init
  input_total := Test.Machine.Preserves.good_refines.input_total
  applicable s t ic ia hi hJ ha _ hd := Test.Machine.Preserves.good_refines.applicable s t ic ia hi hJ ha trivial hd
  correct s t ic ia t' oc hi hJ ha _ hd hs :=
    Test.Machine.Preserves.good_refines.correct s t ic ia t' oc hi hJ ha trivial hd hs

end Test.Trace.ObligationFixture.Abstraction

/-- モデルの層の外に置いた差異の述語。 -/
@[deviation "D-904"] def Test.Trace.ObligationFixture.Helpers.devFalse (_ : Req) : Prop := False

open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)

namespace Test.Trace.ObligationFixture.Spec

/-- 箇所の印（正例）。 -/
@[gap "D-922"] def markedSpec (n : Nat) : Nat := n

/-- 違反: モデル外の差異の印（GK）。 -/
@[gap "D-920"] def markedOutOfModel (n : Nat) : Nat := n

/-- 違反: 宣言の無い ID の印（GK）。 -/
@[gap "D-999"] def markedUnknown (n : Nat) : Nat := n

end Test.Trace.ObligationFixture.Spec

/-! ## ギャップの登録簿（GK）

`@[deviation]` の各 ID の宣言と、GK の違反例。宣言の値は、補助の定義（`preGap`）の展開でも読めることを確かめる。 -/

open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)
open _root_.Trace

namespace Test.Trace.ObligationFixture.Abstraction

/-- 前提型の宣言を作る補助（値は展開して読まれる）。 -/
def preGap (id : String) (devs : List Lean.Name) (ev : Evidence) : Gap :=
  { id, kind := .pre, sites := [⟨"例", "docs/spec/example.md#base", ""⟩], premise := "前提", rTasks := ["ABS-900"],
    deviations := devs, evidence := ev, impact := some (.abort, "理由"), backlog := ["backlog-x"] }

/-- 観測型の宣言を作る補助。 -/
def obsGap (id : String) (devs : List Lean.Name) (ev : Evidence) : Gap :=
  { id, kind := .observational, sites := [⟨"例", "docs/spec/example.md#base", ""⟩], premise := "成分",
    rTasks := ["ABS-900"], deviations := devs, evidence := ev }

/-- 未証明（必要性の定理がまだ無い）の状態。 -/
def noW : Evidence := .pending "必要性の定理がまだ無い" (some "ABS-990")

/-- 偽を証明済み。違反: 同じ ID の `devLangB` を `deviations` に挙げていない（GK）。 -/
@[gap_entry] def gD901 : Gap := preGap "D-901" [``devLang] (.refuted [``need_devLang])
/-- D-902 -/ @[gap_entry] def gD902 : Gap := preGap "D-902" [``devNoW] noW
/-- D-903 -/ @[gap_entry] def gD903 : Gap := preGap "D-903" [``devK] noW
/-- D-904 -/ @[gap_entry] def gD904 : Gap := preGap "D-904" [``Test.Trace.ObligationFixture.Helpers.devFalse] noW
/-- 違反: 別の差異の必要性の定理を、偽の証明に挙げる（GK）。 -/
@[gap_entry] def gD905 : Gap := preGap "D-905" [``devUnneeded] (.refuted [``need_arrow])
/-- 偽を証明済み（`¬ Refines`）。 -/
@[gap_entry] def gD906 : Gap := preGap "D-906" [``devLang2] (.refuted [``v9_noPinned_nec])
/-- 違反: 偽の証明の定理 `obs2_needed` に `@[gap]` が無い（GK）。 -/
@[gap_entry] def gD907 : Gap := obsGap "D-907" [``obsNaN] (.refuted [``obs_needed, ``obs2_needed])
/-- D-908 -/ @[gap_entry] def gD908 : Gap := preGap "D-908" [``devTwo] noW
/-- D-909 -/ @[gap_entry] def gD909 : Gap := preGap "D-909" [``devTwo] noW
/-- 被覆（`devLang` は偽を証明済みの D-901）。 -/
@[gap_entry] def gD910 : Gap := preGap "D-910" [``devWeak] (.covered ``devLang [``devWeak_covered])
/-- 違反: 被覆が循環する（GK）。 -/
@[gap_entry] def gD911 : Gap := preGap "D-911" [``devC1] (.covered ``devC2 [``devC2_covers])
/-- 違反: 被覆が循環する（GK）。 -/
@[gap_entry] def gD912 : Gap := preGap "D-912" [``devC2] (.covered ``devC1 [``devC1_covers])
/-- 未証明なので、G9 は警告になる。 -/
@[gap_entry] def gD913 : Gap := obsGap "D-913" [``obsZero] noW

/-- D-920（モデル外）の主張。命題として書けないので `opaque` にする。 -/
@[gap "D-920"] opaque claim920 : Prop

/-- 違反: 形式化していない主張を仮定に使う（GK）。 -/
theorem usesClaim (h : claim920) : claim920 := h

/-- モデル外の宣言（リテラルで書く）。 -/
@[gap_entry] def gD920 : Gap :=
  { id := "D-920", kind := .outOfModel, sites := [⟨"例", "docs/spec/example.md#base", "（規範節）"⟩],
    premise := "— モデル外", evidence := .unformalized ``claim920 "" }

/-- 違反: 主張が `opaque` でない（GK）。 -/
@[gap "D-921"] def claim921 : Prop := True

/-- 未確定の宣言。 -/
@[gap_entry] def gD921 : Gap :=
  { id := "D-921", kind := .undetermined, sites := [⟨"例", "docs/spec/example.md#base", ""⟩],
    evidence := .unformalized ``claim921 "原典実行で確かめる" }

/-- PRE の外の振る舞いの宣言（前提の述語には印がある）。 -/
@[gap_entry] def gD922 : Gap :=
  { id := "D-922", kind := .outsidePre, sites := [⟨"例", "docs/spec/example.md#base", ""⟩], premise := "PRE MD-1",
    evidence := .excludedBy [``Test.Trace.ObligationFixture.Spec.markedSpec] }

-- 違反: docstring が無い（GK）
@[gap_entry] def gD923 : Gap :=
  { id := "D-923", kind := .outsidePre, sites := [⟨"例", "docs/spec/example.md#base", ""⟩], premise := "PRE MD-1",
    evidence := .excludedBy [] }

/-- 違反: 同じ ID の宣言が 2 つ（GK）。 -/
@[gap_entry] def gD922dup : Gap := gD922

/-- 違反: `D-NNN` の宣言が `Refinement` の層にある（下の名前空間。GK）。 -/
@[gap_entry] def _root_.Test.Trace.ObligationFixture.Refinement.gD924 : Gap :=
  { id := "D-924", kind := .outsidePre, sites := [⟨"例", "docs/spec/example.md#base", ""⟩], premise := "PRE MD-1",
    evidence := .excludedBy [] }

/-- 違反: 未確定の差異に `@[deviation]` がある（GK）。 -/
@[deviation "D-921"] def devUndetermined (r : Req) : Prop := r.lang = false

end Test.Trace.ObligationFixture.Abstraction


open Trace.Gap
open Machine.Preserves (never always anyOf Covers Covers₂ Nontrivial Nontrivial₂ KernelIs)

namespace Test.Trace.ObligationFixture.Abstraction

/-- 違反: 印を `Abstraction` の層に付ける（GK）。 -/
@[gap "D-922"] def markedAbstraction (n : Nat) : Nat := n

end Test.Trace.ObligationFixture.Abstraction
