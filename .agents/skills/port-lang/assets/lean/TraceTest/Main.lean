import Trace.Dump
import Trace.Obligation
import Trace.Gap
import TraceTest

/-!
# TraceTest.Main

追跡属性の道具の検査（実行ファイル `trace-test`。`lake exe trace-test`）。

- `TraceTest.Fixture` を `trace-dump` と同じ処理にかけ、属性・層・参照・Merkle ハッシュ・ギャップの登録簿を確かめる。
- `TraceTest.ObligationFixture` を `obligation-check` と同じ処理にかけ、正例を通し、違反例を規則ごとに検出することを確かめる。
- Merkle の合成（伝播・範囲・強連結成分）は、合成した小さなグラフで確かめる。
  カーネルの定義は直接には再帰しないため、相互再帰の閉路は実際の定義からは作れない。
-/

open Lean Trace.Dump

/-- フィクスチャの層: 接頭辞 `TraceTest.Fixture` を除いた名前で、既定の決め方を使う。 -/
def fixtureLayerOf (n : Name) : Option Layer :=
  match n.components with
  | `TraceTest :: `Fixture :: rest => defaultLayerOf [] (rest.foldl (· ++ ·) Name.anonymous)
  | _ => none

def fixtureConfig : Config := { layerOf := fixtureLayerOf, merkleScope := defaultMerkleScope }

/-- 失敗した検査の数。 -/
initialize failures : IO.Ref Nat ← IO.mkRef 0

def check (label : String) (ok : Bool) : IO Unit := do
  if ok then IO.println s!"  ok   {label}"
  else
    IO.eprintln s!"  FAIL {label}"
    failures.modify (· + 1)

def fx (s : String) : Name := (`TraceTest.Fixture).append s.toName

def find? (es : Array Entry) (s : String) : Option Entry :=
  es.find? (·.name == fx s)

def attrsOf? (es : Array Entry) (s : String) : List (String × List String) :=
  match find? es s with
  | some e => e.attributes.map fun (k, vs) => (k, vs.toList)
  | none => []

def refs (es : Array Entry) (s : String) : Array Name :=
  match find? es s with
  | some e => e.references
  | none => #[]

def merkleOf (m : NameMap UInt64) (s : String) : UInt64 := (m.find? s.toName).getD 0

def node (n : String) (own : UInt64) (edges : List String) : Node :=
  { name := n.toName, layer := "L", own, edges := edges.toArray.map String.toName }

/-- 合成したグラフで Merkle の合成を確かめる。 -/
def merkleTests : IO Unit := do
  IO.println "merkle (synthetic graphs)"
  -- c → b → a
  let g1 := #[node "a" 1 [], node "b" 2 ["a"], node "c" 3 ["b"]]
  let g2 := #[node "a" 9 [], node "b" 2 ["a"], node "c" 3 ["b"]]
  let m1 := computeMerkle g1
  let m2 := computeMerkle g2
  check "leaf change propagates to direct referrer" (merkleOf m1 "b" != merkleOf m2 "b")
  check "leaf change propagates transitively" (merkleOf m1 "c" != merkleOf m2 "c")
  check "deterministic" (merkleOf m1 "c" == merkleOf (computeMerkle g1) "c")
  check "input order does not matter" (merkleOf m1 "c" == merkleOf (computeMerkle g1.reverse) "c")
  -- 辺の無い参照先（合成の範囲外）は影響しない
  let g3 := #[node "a" 1 [], node "b" 2 [], node "c" 3 ["b"]]
  let g4 := #[node "a" 9 [], node "b" 2 [], node "c" 3 ["b"]]
  check "no edge, no propagation" (merkleOf (computeMerkle g3) "b" == merkleOf (computeMerkle g4) "b")
  -- 閉路 a ⇄ b と、それを参照する c
  let s1 := #[node "a" 1 ["b"], node "b" 2 ["a"], node "c" 3 ["a"]]
  let s2 := #[node "a" 1 ["b"], node "b" 7 ["a"], node "c" 3 ["a"]]
  let n1 := computeMerkle s1
  let n2 := computeMerkle s2
  check "cycle: members get distinct hashes" (merkleOf n1 "a" != merkleOf n1 "b")
  check "cycle: change in one member changes the other" (merkleOf n1 "a" != merkleOf n2 "a")
  check "cycle: change propagates out of the component" (merkleOf n1 "c" != merkleOf n2 "c")
  check "sccs: cycle is one component" ((sccs s1).any (·.size == 2))
  check "scope: same layer" (defaultMerkleScope "TargetModel" "TargetModel")
  check "scope: LangSemantics" (defaultMerkleScope "TargetModel" "LangSemantics.Rust")
  check "scope: Machine" (defaultMerkleScope "Spec" "Machine")
  check "scope: not Spec from TargetModel" (!defaultMerkleScope "TargetModel" "Spec")
  check "layer: LangSemantics has two components"
    (defaultLayerOf [] `LangSemantics.Rust.U64.add == some "LangSemantics.Rust")
  check "layer: core is out of scope" (defaultLayerOf [] `Nat.add == none)

/-- フィクスチャを trace-dump の処理にかける。 -/
def fixtureTests (env : Environment) : IO Unit := do
  IO.println "trace-dump (TraceTest.Fixture)"
  let es := dump env fixtureConfig
  check "attributes: source (2 args)"
    (attrsOf? es "SourceModel.base" ==
      [("source", ["java:com.example.Fare#base(int)@0123456789abcdef", "lang:java#JLS-15.17.1@java-17"])])
  check "attributes: target"
    (attrsOf? es "TargetModel.double" == [("target", ["rust:app::fare::double@0123456789abcdef"])])
  check "attributes: spec_doc and no_source on one decl"
    (attrsOf? es "Spec.base" ==
      [("spec_doc", ["docs/spec/example.md#base"]), ("no_source", ["フィクスチャ"])])
  check "attributes: deviation" (attrsOf? es "Spec.smallInput" == [("deviation", ["T-999"])])
  check "attributes: obligation" (attrsOf? es "Refinement.double_eq" == [("obligation", ["REF-999"])])
  check "attributes: none" (attrsOf? es "TargetModel.useSpec" == [])
  check "layer: TargetModel" (((find? es "TargetModel.double").map (·.layer)) == some "TargetModel")
  check "layer: LangSemantics.Rust"
    (((find? es "LangSemantics.Rust.wrapAdd").map (·.layer)) == some "LangSemantics.Rust")
  check "references: LangSemantics" ((refs es "TargetModel.double").contains (fx "LangSemantics.Rust.wrapAdd"))
  check "references: through match_1" ((refs es "TargetModel.useMatch").contains (fx "TargetModel.double"))
  check "references: obligation theorem sees both models"
    ((refs es "Refinement.double_eq").contains (fx "TargetModel.double") &&
     (refs es "Refinement.double_eq").contains (fx "Spec.smallInput"))
  check "no hidden constants in output"
    (es.all fun e => !(isHidden env e.name) && !e.name.toString.contains "match_")
  check "no hidden constants in references"
    (es.all fun e => e.references.all fun r => !r.toString.contains "match_")
  check "mutual recursion: both present"
    ((find? es "TargetModel.isEven").isSome && (find? es "TargetModel.isOdd").isSome)
  check "merkle: distinct definitions differ"
    (((find? es "Spec.base").map (·.merkle)) != ((find? es "SourceModel.base").map (·.merkle)))
  check "merkle: 16 hex digits" (es.all fun e => e.merkle.length == 16)
  check "dump: deterministic" ((dumpJson env fixtureConfig).compress == (dumpJson env fixtureConfig).compress)
  check "attributes: gap" (attrsOf? es "TargetModel.isEven" == [("gap", ["T-998"])])
  let gaps := ((dumpJson env fixtureConfig).getObjValD "gaps").getArr?.toOption.getD #[]
  check "gaps: one entry" (gaps.size == 1)
  let g := gaps[0]?.getD Json.null
  let field (k : String) : Json := g.getObjValD k
  check "gaps: id, kind and label" (field "id" == "T-998" && field "kind" == "outside_pre" && field "kind_label" == "PRE の外")
  check "gaps: docstring" (field "doc" == "フィクスチャの **ギャップ** の説明。")
  check "gaps: sites" (field "sites" == Json.arr #[Json.mkObj [("label", "例"), ("path", "docs/spec/example.md#base"), ("note", "（注記）")]])
  check "gaps: markers" (field "markers" == Json.arr #["TraceTest.Fixture.TargetModel.isEven"])
  check "gaps: module" (field "module" == "TraceTest.Fixture")
  check "dump: sorted by name"
    ((es.map (·.name.toString)).toList == ((es.map (·.name.toString)).qsort (· < ·)).toList)

/-- 誤りの規則（`G1` など）の集合。 -/
def ruleCodes (errs : Array String) : List String :=
  (errs.toList.map fun e => (e.take 2).toString).eraseDups.mergeSort (· ≤ ·)

/-- フィクスチャの対象: 接頭辞 `TraceTest.ObFix` を除いた名前で、既定の層の決め方を使う。 -/
def obFixScope : Trace.Obligation.Scope :=
  { layerOf := fun n =>
      match n.components with
      | `TraceTest :: `ObFix :: rest => defaultLayerOf [] (rest.foldl (· ++ ·) Name.anonymous)
      | _ => none }

/-- フィクスチャを obligation-check の処理にかける。 -/
def obligationTests (env : Environment) : IO Unit := do
  IO.println "obligation-check (TraceTest.ObligationFixture)"
  let r := Trace.Obligation.check env obFixScope
  let ab (s : String) : Name := (`TraceTest.ObFix.Abstraction).append s.toName
  let codesOf (s : String) : Option (List String) :=
    (r.rs.find? (·.name == ab s)).map (ruleCodes ·.errors)
  for (s, expected) in [("good_refines", ([] : List String)), ("good_abbrev", []), ("v1_forall", ["G1"]),
      ("v2_plainRestrict", ["G2"]), ("v2_paramDev", ["G2", "G6"]), ("v3_choiceNoNondet", ["G3", "G6"]),
      ("v3_relSpec", ["G3", "G6"]), ("v3_free", ["G3", "G6"]), ("v4_domSet", ["G4", "G6"]),
      ("v4_taut", ["G4", "G6"]), ("v4_usesSpec", ["G4", "G6"]), ("v5_helperGlue", ["G5", "G6"]),
      ("v5_plainObs", ["G5", "G6"]), ("v5_plainAi", ["G5", "G6"]), ("v5_aoNoKernel", ["G6", "G7"]),
      ("v6_noCompanions", ["G6"]), ("v6_invFalse", ["G6"]), ("v6_ceCheat", ["G6"]),
      ("need_refines", []), ("obs_refines", []), ("v9_unneeded", ["G6"]), ("v9_noPinned", []),
      ("v9_sameId", ["G6"]), ("cover_refines", ["G6"]), ("v9_circular", ["G6"]), ("obs2_refines", []),
      ("pre_refines", ["G6"])] do
    check s!"{s}: {expected}" (codesOf s == some expected)
  check "R obligations: all found (v0_notRefines, need_devLang and need_arrow are not)" (r.rs.size == 27)
  let necessityOf (s : String) : Option (Array Name) := (r.rs.find? (·.name == ab s)).map (·.necessity)
  check "necessity: devLang is needed in need_refines, not in good_refines"
    (necessityOf "need_refines" == some #[ab "devLang"] && necessityOf "good_refines" == some #[])
  check "necessity: obsNaN (OO replaced by never, pure base)" (necessityOf "obs_refines" == some #[ab "obsNaN"])
  check "necessity: ¬ Refines (stronger) counts for an ofChoice base"
    (necessityOf "v9_noPinned" == some #[ab "devLang2"])
  check "necessity: anyOf leaf replaced by never" (necessityOf "obs2_refines" == some #[ab "obsNaN"])
  check "pre_refines: env_pre fact on a base with ¬ TotalUnder always"
    (match r.rs.find? (·.name == ab "pre_refines") with
     | some ri => ri.envNecessary && ri.totalUnder == #[(`TraceTest.ObFix.Spec.envOk, false)]
     | none => false)
  check "good_refines: kind, deviation, std_abs, choices, companions, entry and state safety facts"
    (match r.rs.find? (·.name == ab "good_refines") with
     | some ri => ri.absKind == "ofChoice" && ri.devs == #[ab "devLang"] &&
         ri.stdAbs == #[ab "betaS", ab "aiS", ab "aoS"] &&
         ri.envLeaves == #[`TraceTest.ObFix.Spec.Conflict] && ri.freeLeaves.isEmpty &&
         ri.hasInitSurj && ri.hasSound && ri.hasInitIs && ri.hasPinned && ri.hasNoFault &&
         ri.totalUnder == #[(`Machine.always, true)] && ri.stateSafe == #[ab "devLang"]
     | none => false)
  check "v3_free: free choice reported" (match r.rs.find? (·.name == ab "v3_free") with
    | some ri => ri.freeLeaves == #[`TraceTest.ObFix.Spec.AnyResult] | none => false)
  let expectedGlobal := ["G7: TraceTest.ObFix.Abstraction.aoIf", "G7: TraceTest.ObFix.Abstraction.aoPart2 ", "G7: TraceTest.ObFix.Abstraction.aoPart4 ", "G7: TraceTest.ObFix.Abstraction.ceCheat",
    "G7: TraceTest.ObFix.Abstraction.via", "G8: TraceTest.ObFix.Abstraction.devK", "G8: TraceTest.ObFix.Abstraction.devNoW",
    "G0: TraceTest.ObFix.Abstraction.v0_notRefines", "G3: TraceTest.ObFix.Spec.specRel",
    "G0: TraceTest.ObFixHelpers.devFalse", "G8: TraceTest.ObFixHelpers.devFalse",
    "G9: D-905", "G9: D-911", "G9: D-912", "G9: TraceTest.ObFix.Abstraction.devTwo",
    "G9: TraceTest.ObFix.Spec.envNoNeed", "G8: TraceTest.ObFix.Abstraction.devUndetermined",
    "GK: D-922 is declared by both", "GK: TraceTest.ObFix.Abstraction.gD923 (@[gap_entry] D-923) has no docstring",
    "GK: TraceTest.ObFix.Refinement.gD924 (@[gap_entry] D-924) must be in the Abstraction layer",
    "GK: TraceTest.ObFix.Abstraction.markedAbstraction has @[gap \"D-922\"] but is not in",
    "GK: TraceTest.ObFix.Spec.markedOutOfModel has @[gap \"D-920\"] but D-920 is out_of_model",
    "GK: TraceTest.ObFix.Spec.markedUnknown has @[gap \"D-999\"] but D-999 has no @[gap_entry]",
    "GK: TraceTest.ObFix.Abstraction.devUndetermined has @[deviation \"D-921\"] but D-921 is undetermined",
    "GK: TraceTest.ObFix.Abstraction.devLangB has @[deviation \"D-901\"] but the @[gap_entry] of D-901 does not list it",
    "GK: D-905: TraceTest.ObFix.Abstraction.need_arrow is not a necessity theorem",
    "GK: D-907: TraceTest.ObFix.Abstraction.obs2_needed (the evidence refuted) must have @[gap \"D-907\"]",
    "GK: D-911: the covered chain is cyclic", "GK: D-912: the covered chain is cyclic",
    "GK: D-921: the claim TraceTest.ObFix.Abstraction.claim921 must be an opaque Prop",
    "GK: TraceTest.ObFix.Abstraction.usesClaim refers to TraceTest.ObFix.Abstraction.claim920"]
  check s!"global errors: exactly {expectedGlobal.length}"
    (r.errors.size == expectedGlobal.length &&
      expectedGlobal.all fun p => r.errors.any (·.startsWith p))
  unless r.errors.size == expectedGlobal.length do
    for e in r.errors do IO.println s!"    global error: {e}"
  check "warnings: G9 of the pending D-913 only"
    (r.warnings.size == 1 && r.warnings.all (·.startsWith "G9: D-913"))
  let gapOf (id : String) : Json :=
    ((r.gaps.getArr?.toOption.getD #[]).find? fun g => g.getObjValD "id" == Json.str id).getD Json.null
  let evOf (id : String) (k : String) : Json := ((gapOf id).getObjValD "evidence").getObjValD k
  check "gaps: evidence states and labels"
    (evOf "D-901" "state" == "refuted" && evOf "D-910" "state" == "covered" && evOf "D-913" "state" == "pending" &&
      evOf "D-920" "state" == "unformalized" && evOf "D-922" "state" == "excluded_by" &&
      evOf "D-901" "label" == "偽を証明済み")
  check "gaps: witnesses, coverer and pre"
    (evOf "D-901" "witnesses" == Json.arr #["TraceTest.ObFix.Abstraction.need_devLang"] &&
      evOf "D-910" "coverer" == "TraceTest.ObFix.Abstraction.devLang" &&
      evOf "D-922" "pre" == Json.arr #["TraceTest.ObFix.Spec.markedSpec"])
  check "gaps: w_task from the @[obligation] of the refuting theorem, or the planned one"
    ((gapOf "D-901").getObjValD "w_task" == "ABS-951" && (gapOf "D-913").getObjValD "w_task" == "ABS-990" &&
      (gapOf "D-906").getObjValD "w_task" == Json.null)
  check "gaps: resolution of an unformalized undetermined gap"
    ((gapOf "D-921").getObjValD "resolution" == "オラクルで確かめる")
  check "obligations: v0_notRefines listed as not R"
    (r.obligations.any fun (n, _, isR) => n == ab "v0_notRefines" && !isR)
  check "nondet listed" (r.nondets.map (·.1) == #[`TraceTest.ObFix.Spec.AnyResult, `TraceTest.ObFix.Spec.Conflict])
  check "gaps: entries readable and listed in the report (D-901..D-913, D-920..D-924 and the duplicate)"
    ((r.gaps.getArr?.toOption.map (·.size)) == some 19)
  check "env_pre listed" (r.envPres.map (·.1) == #[`TraceTest.ObFix.Spec.envNoNeed, `TraceTest.ObFix.Spec.envOk])

unsafe def main : IO UInt32 := do
  merkleTests
  let env ← loadEnv #[`TraceTest.Fixture]
  fixtureTests env
  let env ← loadEnv #[`TraceTest.ObligationFixture]
  obligationTests env
  let n ← failures.get
  if n == 0 then
    IO.println "all trace tests passed"
    return 0
  else
    IO.eprintln s!"{n} test(s) failed"
    return 1
