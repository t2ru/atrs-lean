import Trace
import Machine
import MachineTest.Adequacy

/-!
# Tests.ObligationFixture

`obligation-check`（`Trace.Obligation`）のフィクスチャ。`Tests.ObFix.<層>` の下に、規則をすべて満たす R 課題と、
規則ごとの違反例を置く（テストは接頭辞 `Tests.ObFix` を除いた名前で層を決める）。違反例には、実装後の敵対的レビューで
作られた迂回（ADR 0039 の「実装後の敵対的レビュー」）を含める。証明は `MachineTest.Adequacy` の定理を定義の展開で使い回す。

期待する判定は `Tests/Main.lean` の `obligationTests` に書く。
-/

open Machine
open MachineTest.Adequacy (Out Req Num)

namespace Tests.ObFix.Spec

/-- 衝突の選択（環境）。 -/
@[nondet "N-901"] abbrev Conflict : Type := Bool

/-- 結果の全体（自由な選択として吸収に使う。誤り）。 -/
@[nondet "N-902"] abbrev AnyResult : Type := Nat × Out

/-- 結果（`MachineTest.Adequacy.fRes` と同じ）。 -/
def fRes (s n : Nat) (c : Conflict × Unit) : Nat × Out := MachineTest.Adequacy.fRes s n c

/-- 抽象機械。 -/
def spec : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fRes false ()

theorem spec_sound : spec.Sound := MachineTest.Adequacy.spec_sound
theorem spec_initIs : spec.InitIs 5 := fun _ => Iff.rfl

/-- 環境の前提。 -/
@[env_pre "MD-901"] def envOk (n : Nat) : Prop := n < 1000

theorem envOk_nontrivial : Nontrivial envOk :=
  ⟨⟨0, show 0 < 1000 by decide⟩, ⟨1000, show ¬ 1000 < 1000 by decide⟩⟩
theorem spec_total : spec.TotalUnder envOk := fun _ _ _ _ => trivial

/-- 選択の型に `@[nondet]` の無い抽象機械。 -/
def specBool : Machine.Machine Nat Nat Out := MachineTest.Adequacy.spec

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
def fFree (s n : Nat) (c : Conflict × AnyResult) : Nat × Out := MachineTest.Adequacy.fFree s n c

def specFree : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fFree false (5, .ok)

theorem specFree_sound : specFree.Sound := ⟨fun _ _ => trivial, fun _ _ _ _ _ _ _ => trivial⟩
theorem specFree_initIs : specFree.InitIs 5 := fun _ => Iff.rfl

/-- PRE を入力の値域で制限した抽象機械（環境の前提の必要性の正例。ADR 0042）。 -/
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
def half : Machine.Machine Unit Nat Nat := MachineTest.Adequacy.half

theorem half_sound : half.Sound := Machine.sound_pure (fun _ => True) (· / 2)
theorem half_initIs : half.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

end Tests.ObFix.Spec

namespace Tests.ObFix.SourceModel

open Tests.ObFix.Spec

/-- 具体機械。 -/
def good : Concrete Nat Req Out Unit := MachineTest.Adequacy.good

/-- 付帯の定理の無い具体機械。 -/
def good2 : Concrete Nat Req Out Unit := MachineTest.Adequacy.good

/-- 不具合を持つ具体機械。 -/
def buggy : Concrete Nat Req Out Unit := MachineTest.Adequacy.buggy

/-- 状態を壊す具体機械。 -/
def junk : Concrete Nat Req Out Unit := MachineTest.Adequacy.junk

/-- `Dom` を設定した具体機械。 -/
def domSet : Concrete Nat Req Out Unit where
  Init := good.Init
  Dom r := True ∧ r.n < 100
  step := good.step

/-- 抽象機械そのものを具体機械とする（同語反復）。 -/
def taut : Concrete Nat Nat Out Unit := spec.toConcrete

/-- `lang` が真のとき正常終了しない具体機械（必要な差異の正例。ADR 0042）。 -/
def langErr : Concrete Nat Req Out Unit := MachineTest.Adequacy.langErr

/-- `langErr` と同じ具体機械（別の基底の違反例のため）。 -/
def langErr2 : Concrete Nat Req Out Unit := MachineTest.Adequacy.langErr

/-- 0 で NaN を返す具体機械（必要な観測型の差異の正例）。 -/
def halfNaN : Concrete Unit Nat Num Unit := MachineTest.Adequacy.halfNaN

/-- `Spec` の関数を使う具体機械。 -/
def usesSpec : Concrete Nat Req Out Unit :=
  Concrete.ofFun (· = 5) fun t r => .ok (Spec.fRes t r.n (r.env, ()))

end Tests.ObFix.SourceModel

namespace Tests.ObFix.Abstraction

open Tests.ObFix.Spec Tests.ObFix.SourceModel

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

theorem devLang_nontrivial : Nontrivial devLang := MachineTest.Adequacy.devLang_nontrivial

/-- 標準の貼り合わせ。 -/
abbrev glue : Glue Nat Nat Nat Req Out Out := Glue.ofStd betaS (fun _ => True) aiS aoS

/-! ## 正例 -/

@[obligation "ABS-901"]
theorem good_refines : Refines spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

theorem good_initSurj : Refines.InitSurj spec (good.restrict devLang) glue :=
  MachineTest.Adequacy.good_initSurj

theorem good_pinned : Refines.Pinned spec (good.restrict devLang) glue fRes ceS :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    MachineTest.Adequacy.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

theorem good_noFault : Refines.NoFaultReachable (good.restrict devLang) glue ceS false :=
  fun r _ hd ha => ⟨{ r with env := false }, ⟨trivial, hd.2⟩, ha, rfl⟩

theorem good_envWitness : Refines.EnvWitness (good.restrict devLang) glue envOk :=
  ⟨⟨0, false, false⟩, 0, ⟨trivial, rfl⟩, rfl, show 0 < 1000 by decide⟩

theorem good_stateSafe : Refines.StateSafeConcrete spec good glue devLang :=
  fun s t ic ia t' oc hi hJ ha hp _ hd hs => by
    obtain ⟨s', o, hst, hJ', _⟩ :=
      MachineTest.Adequacy.good_refines.correct s t ic ia t' oc hi hJ ha hp hd hs
    exact ⟨s', o, hst, hJ'⟩

/-- 貼り合わせを `abbrev` で書いた正例（付帯の定理は展開形で照合される）。 -/
@[obligation "ABS-902"]
theorem good_abbrev : Refines spec (good.restrict devLang) glue := good_refines

/-! ## 違反例 -/

@[obligation "ABS-911"]
theorem v1_forall (_ : True) : Refines spec (good.restrict devLang) glue := good_refines

/-- `@[deviation]` の無い述語。 -/
def plainLang (r : Req) : Prop := r.lang = false

@[obligation "ABS-912"]
theorem v2_plainRestrict : Refines spec (good.restrict plainLang) glue :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

theorem v2_initSurj : Refines.InitSurj spec (good.restrict plainLang) glue :=
  MachineTest.Adequacy.good_initSurj

theorem v2_pinned : Refines.Pinned spec (good.restrict plainLang) glue fRes ceS :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    MachineTest.Adequacy.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

theorem v2_noFault : Refines.NoFaultReachable (good.restrict plainLang) glue ceS false :=
  fun r _ hd ha => ⟨{ r with env := false }, ⟨trivial, hd.2⟩, ha, rfl⟩

/-- 引数を取る差異の述語（引数で `False` にできる）。 -/
@[deviation "D-903"] def devK (k : Nat) (r : Req) : Prop := r.n < k

@[obligation "ABS-913"]
theorem v2_paramDev : Refines spec (good.restrict (devK 0)) glue :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

@[obligation "ABS-914"]
theorem v3_choiceNoNondet : Refines specBool good glue := MachineTest.Adequacy.good_refines

@[obligation "ABS-915"]
theorem v3_relSpec : Refines specRel good glue where
  init t ht := ⟨t, ht, Or.inl ⟨rfl, trivial⟩⟩
  input_total r _ := ⟨r.n, rfl⟩
  applicable _ _ _ _ _ _ _ _ _ := ⟨⟨_, rfl⟩, fun _ h => by cases h⟩
  correct _ _ _ _ t' oc _ _ _ _ _ _ := ⟨t', oc, trivial, Or.inl ⟨rfl, trivial⟩, Or.inl rfl⟩

@[obligation "ABS-916"]
theorem v3_free : Refines specFree junk glue := MachineTest.Adequacy.junk_refines_specFree

@[obligation "ABS-917"]
theorem v4_domSet : Refines spec domSet glue :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines fun r => r.n < 100

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
theorem v4_usesSpec : Refines spec usesSpec glue := MachineTest.Adequacy.good_refines

/-- 補助定義（`@[reducible]` でない）で包んだ貼り合わせ。 -/
def myGlue : Glue Nat Nat Nat Req Out Out := Glue.ofStd betaS (fun _ => True) aiS aoS

@[obligation "ABS-920"]
theorem v5_helperGlue : Refines spec good myGlue := MachineTest.Adequacy.good_refines

/-- `@[deviation]` の無い観測の成分。 -/
def obsPlain (_ _ : Out) : Prop := False

@[obligation "ABS-921"]
theorem v5_plainObs : Refines spec good (Glue.ofStd betaS (fun _ => True) aiS aoS never obsPlain) :=
  MachineTest.Adequacy.good_refines

/-- `@[std_abs]` の無い入力の写像。 -/
def aiPlain (r : Req) : Option Nat := some r.n

@[obligation "ABS-922"]
theorem v5_plainAi : Refines spec good (Glue.ofStd betaS (fun _ => True) aiPlain aoS) :=
  MachineTest.Adequacy.good_refines

/-- 核の定理の無い出力の写像（合成）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoComp (o : Out) : Option Out := Option.some o

@[obligation "ABS-923"]
theorem v5_aoNoKernel : Refines spec good (Glue.ofStd betaS (fun _ => True) aiS aoComp) :=
  MachineTest.Adequacy.good_refines

@[obligation "ABS-924"]
theorem v6_noCompanions : Refines spec good2 glue := MachineTest.Adequacy.good_refines

@[obligation "ABS-925"]
theorem v6_invFalse : Refines specInvF junk glue := MachineTest.Adequacy.junk_refines_invFalse

theorem v6_invFalse_initSurj : Refines.InitSurj specInvF junk glue := fun s hs => ⟨s, hs, Or.inl ⟨hs ▸ rfl, trivial⟩⟩

theorem v6_invFalse_pinned : Refines.Pinned specInvF junk glue fRes ceS := fun _ _ _ _ _ _ hi => absurd hi id

theorem v6_invFalse_noFault : Refines.NoFaultReachable junk glue ceS false :=
  fun r _ _ ha => ⟨{ r with env := false }, trivial, ha, rfl⟩

/-- `n = 3` を衝突の環境とみなす `ce`（誤り）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def ceCheat (r : Req) : Bool := MachineTest.Adequacy.ceCheat r

@[obligation "ABS-926"]
theorem v6_ceCheat : Refines spec buggy glue := MachineTest.Adequacy.buggy_refines

theorem v6_ceCheat_initSurj : Refines.InitSurj spec buggy glue := fun s hs => ⟨s, hs, Or.inl ⟨rfl, trivial⟩⟩

theorem v6_ceCheat_pinned : Refines.Pinned spec buggy glue fRes ceCheat := MachineTest.Adequacy.buggy_pinned_ceCheat

/-- 分岐を含む合成の標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoIf (o : Out) : Option Out := if o = .full then some .ok else some o

/-- 関数を引数に取る標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def via (h : Out → Option Out) (o : Out) : Option Out := h o

/-- `Nontrivial` の無い差異の述語。 -/
@[deviation "D-902"] def devNoW (r : Req) : Prop := r.n < 3

/-- `Refines` を結論に持たない R 課題。 -/
@[obligation "ABS-927"]
theorem v0_notRefines : Refines spec (good.restrict devLang) glue ∧ True := ⟨good_refines, trivial⟩

/-! ## 成分の必要性（G9。ADR 0042） -/

/-- 正例: 前提型の差異 `devLang` が必要な R 課題。 -/
@[obligation "ABS-950"]
theorem need_refines : Refines spec (langErr.restrict devLang) glue := MachineTest.Adequacy.langErr_refines

theorem need_initSurj : Refines.InitSurj spec (langErr.restrict devLang) glue :=
  MachineTest.Adequacy.langErr_initSurj

theorem need_pinned : Refines.Pinned spec (langErr.restrict devLang) glue fRes ceS :=
  MachineTest.Adequacy.langErr_pinned

theorem need_noFault : Refines.NoFaultReachable (langErr.restrict devLang) glue ceS false :=
  MachineTest.Adequacy.langErr_noFaultReachable

/-- `devLang` の必要性。W 課題の形で `@[obligation]` を付けても、G0 の誤りにならない。 -/
@[obligation "ABS-951"]
theorem need_devLang : ¬ (Refines spec langErr glue ∧ Refines.Pinned spec langErr glue fRes ceS) :=
  MachineTest.Adequacy.devLang_needed_for_langErr

/-- 正例（観測型・基底が `pure`）の標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def betaU (t : Unit) : Option Unit := some t

@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoNum (o : Num) : Option Nat :=
  MachineTest.Adequacy.aoPartial o

theorem aoNum_kernel : KernelIs aoNum Eq := MachineTest.Adequacy.aoPartial_injective

/-- 観測型の差異の成分。 -/
@[deviation "D-907"] def obsNaN (c : Num) (a : Nat) : Prop := MachineTest.Adequacy.obsNaN c a

theorem obsNaN_nontrivial : Nontrivial₂ obsNaN := MachineTest.Adequacy.obsNaN_nontrivial

/-- 正例: 観測型の差異 `obsNaN` が必要な R 課題。 -/
@[obligation "ABS-954"]
theorem obs_refines : Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) :=
  MachineTest.Adequacy.halfNaN_refines_obs

theorem obs_initSurj :
    Refines.InitSurj half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never obsNaN) :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

theorem obs_needed : ¬ Refines half halfNaN (Glue.ofStd betaU (fun _ => True) aiNat aoNum never never) :=
  MachineTest.Adequacy.obsNaN_needed

/-- 違反例: 外しても成り立つ差異（必要性の定理が無い）。 -/
@[deviation "D-905"] def devUnneeded (r : Req) : Prop := r.lang = false

theorem devUnneeded_nontrivial : Nontrivial devUnneeded := MachineTest.Adequacy.devLang_nontrivial

@[obligation "ABS-952"]
theorem v9_unneeded : Refines spec (good.restrict devUnneeded) glue :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

/-- 違反例: 基底が `ofChoice` なのに、必要性を `Pinned` を伴わない `¬ Refines` で示す。 -/
@[deviation "D-906"] def devLang2 (r : Req) : Prop := r.lang = false

theorem devLang2_nontrivial : Nontrivial devLang2 := MachineTest.Adequacy.devLang_nontrivial

@[obligation "ABS-953"]
theorem v9_noPinned : Refines spec (langErr2.restrict devLang2) glue := MachineTest.Adequacy.langErr_refines

theorem v9_noPinned_initSurj : Refines.InitSurj spec (langErr2.restrict devLang2) glue :=
  MachineTest.Adequacy.langErr_initSurj

theorem v9_noPinned_pinned : Refines.Pinned spec (langErr2.restrict devLang2) glue fRes ceS :=
  MachineTest.Adequacy.langErr_pinned

theorem v9_noPinned_noFault : Refines.NoFaultReachable (langErr2.restrict devLang2) glue ceS false :=
  MachineTest.Adequacy.langErr_noFaultReachable

theorem v9_noPinned_nec : ¬ Refines spec langErr2 glue :=
  Refines.not_of_error (A := spec) (C := langErr2) (g := glue) (s := 5) (t := 5)
    (ic := ⟨0, false, true⟩) (ia := 0) (e := ()) trivial (Or.inl ⟨rfl, trivial⟩) rfl trivial trivial rfl

end Tests.ObFix.Abstraction

/-- モデルの層の外に置いた差異の述語。 -/
@[deviation "D-904"] def Tests.ObFixHelpers.devFalse (_ : Req) : Prop := False
