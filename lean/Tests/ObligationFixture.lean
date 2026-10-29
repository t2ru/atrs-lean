import Trace
import Machine
import MachineTest.Adequacy

/-!
# Tests.ObligationFixture

`obligation-check`（`Trace.Obligation`）のフィクスチャ。`Tests.ObFix` の下に、規則をすべて満たす R 課題 1 つと、
規則ごとの違反例を置く。証明は `MachineTest.Adequacy` の定理を定義の展開で使い回す。

| 定理・定義 | 期待する判定 |
| --- | --- |
| `good_refines` | 誤りなし |
| `v1_forall` | G1（仮定がある） |
| `v2_plainRestrict` | G2（制限の述語に `@[deviation]` が無い） |
| `v3_choiceNoNondet` | G3（選択の型に `@[nondet]` が無い）、G6（付帯の定理が無い） |
| `v4_domSet` | G4（具体機械が `Dom` を設定する）、G6 |
| `v5_helperGlue` | G5（貼り合わせを補助定義で包む）、G6 |
| `v5_plainObs` | G5（OO が `never` でも `@[deviation]` でもない）、G6 |
| `v5_plainAi` | G5（ai に `@[std_abs]` が無い）、G6 |
| `v6_noCompanions` | G6（`InitSurj`・`Pinned` が無い） |
| `aoIf` | G7（分岐を含む合成の標準の抽象化） |
| `devNoW` | G8（`Nontrivial` が無い差異の述語） |
-/

namespace Tests.ObFix

open Machine MachineTest.Adequacy

/-- 衝突の選択（環境）。 -/
@[nondet "N-901"] abbrev Conflict : Type := Bool

/-- 結果（`MachineTest.Adequacy.fRes` と同じ）。 -/
def fRes (s n : Nat) (c : Conflict × Unit) : Nat × Out := MachineTest.Adequacy.fRes s n c

/-- 抽象機械。 -/
def spec : Machine.Machine Nat Nat Out :=
  Machine.ofChoice (fun _ => True) (· = 5) (fun _ _ => True) fRes false ()

/-- 具体機械。 -/
def good : Concrete Nat Req Out Unit := MachineTest.Adequacy.good

/-- 標準の抽象化（葉）: 状態。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def betaS (t : Nat) : Option Nat := some t

/-- 標準の抽象化（合成）: 入力。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aiS (r : Req) : Option Nat := Option.some r.n

/-- 標準の抽象化（葉）: 出力。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"] def aoS (o : Out) : Option Out := some o

theorem betaS_kernel : KernelIs betaS Eq := fun x y => by simp [betaS]
theorem aoS_kernel : KernelIs aoS Eq := fun x y => by simp [aoS]

/-- 前提型の差異の述語。 -/
@[deviation "D-901"] def devLang (r : Req) : Prop := r.lang = false

theorem devLang_nontrivial : Nontrivial devLang := MachineTest.Adequacy.devLang_nontrivial

/-! ## 正例 -/

@[obligation "ABS-901"]
theorem good_refines :
    Refines spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

theorem good_initSurj :
    Refines.InitSurj spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  MachineTest.Adequacy.good_initSurj

theorem good_pinned :
    Refines.Pinned spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) fRes ce :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    MachineTest.Adequacy.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

theorem spec_total : spec.TotalUnder fun _ => True := fun _ _ _ _ => trivial

theorem good_stateSafe :
    Refines.StateSafeConcrete spec good (Glue.ofStd betaS (fun _ => True) aiS aoS) devLang :=
  fun s t ic ia t' oc hi hJ ha hp _ hd hs => by
    obtain ⟨s', o, hst, hJ', _⟩ := MachineTest.Adequacy.good_refines.correct s t ic ia t' oc hi hJ ha hp hd hs
    exact ⟨s', o, hst, hJ'⟩

/-! ## 違反例 -/

@[obligation "ABS-911"]
theorem v1_forall (_ : True) :
    Refines spec (good.restrict devLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  good_refines

/-- `@[deviation]` の無い述語。 -/
def plainLang (r : Req) : Prop := r.lang = false

@[obligation "ABS-912"]
theorem v2_plainRestrict :
    Refines spec (good.restrict plainLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines _

theorem v2_initSurj :
    Refines.InitSurj spec (good.restrict plainLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  MachineTest.Adequacy.good_initSurj

theorem v2_pinned :
    Refines.Pinned spec (good.restrict plainLang) (Glue.ofStd betaS (fun _ => True) aiS aoS) fRes ce :=
  fun s t ic ia t' oc hi hJ ha hp hd hs =>
    MachineTest.Adequacy.good_pinned s t ic ia t' oc hi hJ ha hp hd.1 hs

/-- 選択の型に `@[nondet]` の無い抽象機械。 -/
def specBool : Machine.Machine Nat Nat Out := MachineTest.Adequacy.spec

@[obligation "ABS-913"]
theorem v3_choiceNoNondet : Refines specBool good (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  MachineTest.Adequacy.good_refines

/-- `Dom` を設定した具体機械。 -/
def domSet : Concrete Nat Req Out Unit where
  Init := good.Init
  Dom r := True ∧ r.n < 100
  step := good.step

@[obligation "ABS-914"]
theorem v4_domSet : Refines spec domSet (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  Refines.restrictConcrete MachineTest.Adequacy.good_refines fun r => r.n < 100

/-- 補助定義で包んだ貼り合わせ。 -/
def myGlue : Glue Nat Nat Nat Req Out Out := Glue.ofStd betaS (fun _ => True) aiS aoS

@[obligation "ABS-915"]
theorem v5_helperGlue : Refines spec good myGlue := MachineTest.Adequacy.good_refines

/-- `@[deviation]` の無い観測の成分。 -/
def obsPlain (_ _ : Out) : Prop := False

@[obligation "ABS-916"]
theorem v5_plainObs : Refines spec good (Glue.ofStd betaS (fun _ => True) aiS aoS never obsPlain) :=
  MachineTest.Adequacy.good_refines

/-- `@[std_abs]` の無い入力の写像。 -/
def aiPlain (r : Req) : Option Nat := some r.n

@[obligation "ABS-917"]
theorem v5_plainAi : Refines spec good (Glue.ofStd betaS (fun _ => True) aiPlain aoS) :=
  MachineTest.Adequacy.good_refines

/-- 付帯の定理の無い具体機械。 -/
def good2 : Concrete Nat Req Out Unit := MachineTest.Adequacy.good

@[obligation "ABS-918"]
theorem v6_noCompanions : Refines spec good2 (Glue.ofStd betaS (fun _ => True) aiS aoS) :=
  MachineTest.Adequacy.good_refines

/-- 分岐を含む合成の標準の抽象化。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoIf (o : Out) : Option Out := if o = .full then some .ok else some o

/-- `Nontrivial` の無い差異の述語。 -/
@[deviation "D-902"] def devNoW (r : Req) : Prop := r.n < 3

end Tests.ObFix
