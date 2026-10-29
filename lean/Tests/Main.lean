import Trace.Dump
import Tests

/-!
# Tests.Main

`lake test` のドライバ（実行ファイル `tests`）。

- `Tests.TraceFixture` を `trace-dump` と同じ処理にかけ、属性・層・参照・Merkle ハッシュを確かめる。
- Merkle の合成（伝播・範囲・強連結成分）は、合成した小さなグラフで確かめる。
- 適合テストベクタ（`../conformance/shared/format/`）を `Spec` で実行する（`Tests.Conformance`）。
- 暦日の全日の検査（`Tests.SpecChecks.dateExhaustive`）。
- 運賃計算の double 式の、ソフトモデルとネイティブ `Float` の突き合わせ（`Tests.JavaDouble`）。
  カーネルの定義は直接には再帰しないため、相互再帰の閉路は実際の定義からは作れない。
-/

open Lean Trace.Dump

/-- フィクスチャの層: 接頭辞 `Tests.Fixture` を除いた名前で、既定の決め方を使う。 -/
def fixtureLayerOf (n : Name) : Option Layer :=
  match n.components with
  | `Tests :: `Fixture :: rest => defaultLayerOf [] (rest.foldl (· ++ ·) Name.anonymous)
  | _ => none

def fixtureConfig : Config := { layerOf := fixtureLayerOf, merkleScope := defaultMerkleScope }

/-- 失敗した検査の数。 -/
initialize failures : IO.Ref Nat ← IO.mkRef 0

def check (label : String) (ok : Bool) : IO Unit := do
  if ok then IO.println s!"  ok   {label}"
  else
    IO.eprintln s!"  FAIL {label}"
    failures.modify (· + 1)

def fx (s : String) : Name := (`Tests.Fixture).append s.toName

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
  IO.println "trace-dump (Tests.TraceFixture)"
  let es := dump env fixtureConfig
  check "attributes: source (2 args)"
    (attrsOf? es "SourceModel.base" ==
      [("source", ["java:com.example.Fare#base(int)@0123456789abcdef", "lang:java#JLS-15.17.1@java-17"])])
  check "attributes: target"
    (attrsOf? es "TargetModel.double" == [("target", ["rust:atrs::fare::double@0123456789abcdef"])])
  check "attributes: spec_doc and no_source on one decl"
    (attrsOf? es "Spec.base" ==
      [("spec_doc", ["docs/spec/fare-calculation.md#基本運賃"]), ("no_source", ["フィクスチャ"])])
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
  check "dump: sorted by name"
    ((es.map (·.name.toString)).toList == ((es.map (·.name.toString)).qsort (· < ·)).toList)

/-- 適合テストベクタを `Spec` で実行する。 -/
unsafe def conformanceTests : IO Unit := do
  IO.println "conformance (Spec: shared/format)"
  let env ← loadEnv #[`Spec]
  let results ← Tests.Conformance.runDir Tests.Conformance.formatOps env.contains "../conformance/shared/format"
  check "conformance: files found" (!results.isEmpty)
  for r in results do
    for f in r.failures do IO.eprintln s!"    {r.path.fileName.getD ""}: {f}"
    check s!"conformance: {r.path.fileName.getD ""} ({r.passed} cases)" (r.failures.isEmpty && r.passed > 0)

/-- 暦日の全日の検査。 -/
def dateTests : IO Unit := do
  IO.println "date (0001-01-01 .. 9999-12-31)"
  let (bad, n) := Tests.SpecChecks.dateExhaustive
  unless bad.isEmpty do IO.eprintln s!"    failed ordinals: {bad}"
  check s!"date: ofOrdinal? round trip and successor ({n} days)" bad.isEmpty

/-- double のソフトモデルとネイティブ `Float` の突き合わせ。 -/
def javaDoubleTests : IO Unit := do
  IO.println "java double (soft model vs native Float, fare expressions)"
  let r := Tests.JavaDouble.run
  for b in r.bad do IO.eprintln s!"    mismatch: {b}"
  check s!"java double: bit-exact ({r.count} cases)" r.bad.isEmpty

unsafe def main : IO UInt32 := do
  merkleTests
  dateTests
  javaDoubleTests
  conformanceTests
  let env ← loadEnv #[`Tests.TraceFixture]
  fixtureTests env
  let n ← failures.get
  if n == 0 then
    IO.println "all tests passed"
    return 0
  else
    IO.eprintln s!"{n} test(s) failed"
    return 1
