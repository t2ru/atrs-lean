import Lean.Util.CollectAxioms
import Trace.Gap

/-!
# Trace.Dump

`lake exe trace-dump` の本体。全定義について、層・追跡属性・Merkle ハッシュ・参照を JSON で返す
（port-lang の `lang/lean/trace-attributes.md`）。

- **references**: 定義の型と本体（帰納型は構築子の型）に現れる定数。`match_1`・`proof_1` などの
  補助定数は、その中身を展開して親の参照に含める。
- **merkle**: 型と本体の `Expr` の構造ハッシュ（補助定数の分を含む）に、`references` のうち
  同じ層と、`LangSemantics`・`Machine` の層の定数の `merkle` を名前順に合成したもの。
  相互再帰は強連結成分（SCC）ごとにまとめて計算する。値は 64 bit の 16 進 16 桁。
  属性（追跡属性を含む）は含めない。注釈のハッシュを `rehash` が書き換えても値は変わらない。
- **module**: 定義のあるモジュール。`scripts/trace` の `rehash` が注釈を書き換えるファイルを引くのに使う。
- **gaps**: ギャップの登録簿（`@[gap_entry]` の宣言の値と docstring、印 `@[gap]`・`@[deviation]` の定数。`Trace.Gap.gapsJson`）。
- ハッシュは処理系の内部表現に依存しうる。Lean の版を上げると全定義の値が変わりうる。
-/

namespace Trace.Dump
open Trace.Attr

open Lean

/-- 層の名前。`LangSemantics` は言語まで含める（`LangSemantics.Rust` など）。 -/
abbrev Layer := String

/-- 対象とする層の決め方。 -/
structure Config where
  /-- 定数の層。`none` は出力の対象外（core・Batteries など）。 -/
  layerOf : Name → Option Layer
  /-- `fromL` の定義の `merkle` に、`toL` の参照先の `merkle` を合成するか。 -/
  merkleScope : Layer → Layer → Bool

/-- 層とするトップレベル名前空間。 -/
def modelRoots : List String :=
  ["LangSemantics", "Machine", "Spec", "SourceModel", "Abstraction", "TargetModel", "Refinement"]

/-- 名前の先頭から `n` 個の成分を取る。 -/
def namePrefix (name : Name) (n : Nat) : Name :=
  let cs := name.components
  cs.take n |>.foldl (fun acc c => acc ++ c) Name.anonymous

/-- 既定の層の決め方: トップレベル名前空間で決め、`LangSemantics` は 2 成分とする。 -/
def defaultLayerOf (extraRoots : List String := []) (name : Name) : Option Layer :=
  match name.components with
  | [] => none
  | root :: rest =>
    let r := root.toString
    if r == "LangSemantics" then
      match rest with
      | [] => some r
      | l :: _ => some s!"{r}.{l}"
    else if modelRoots.contains r || extraRoots.contains r then some r
    else none

/-- 既定の合成範囲: 同じ層と、`LangSemantics.*`・`Machine`。 -/
def defaultMerkleScope (fromL toL : Layer) : Bool :=
  fromL == toL || toL.startsWith "LangSemantics" || toL == "Machine"

/-- 既定の設定。 -/
def defaultConfig (extraRoots : List String := []) : Config :=
  { layerOf := defaultLayerOf extraRoots, merkleScope := defaultMerkleScope }

/--
名前の順。完全名の文字列の辞書順とする（`Name.quickLt` はハッシュ順、`Name.lt` は成分の構造順で、
他の道具から再現しにくいため）。出力と合成の両方に使う。
-/
def nameLt (a b : Name) : Bool := a.toString < b.toString

/-- 出力しない補助的な定数か（内部名・private・自動生成の再帰子・matcher・予約名）。 -/
def isHidden (env : Environment) (name : Name) : Bool :=
  name.isInternalDetail || isPrivateName name || isAuxRecursor env name ||
  isNoConfusion env name || Meta.isMatcherCore env name || isReservedName env name ||
  match env.find? name with
  | some (.recInfo _) => true
  | some (.quotInfo _) => true
  | _ => false

/-- 定数の型と本体に現れる式。帰納型は構築子の型も含める。 -/
def exprsOf (env : Environment) (ci : ConstantInfo) : Array Expr :=
  let base := match ci.value? (allowOpaque := true) with
    | some v => #[ci.type, v]
    | none => #[ci.type]
  match ci with
  | .inductInfo info =>
    info.ctors.foldl (fun acc c =>
      match env.find? c with
      | some cci => acc.push cci.type
      | none => acc) base
  | _ => base

/-- `Expr` の構造ハッシュを合成する。 -/
def hashExprs (es : Array Expr) : UInt64 :=
  es.foldl (fun h e => mixHash h e.hash) 7

/--
定数の自身のハッシュと参照を求める。補助定数（`isHidden`）は展開し、その式のハッシュを自身のハッシュに、
その参照を自身の参照に含める。
-/
partial def ownHashAndRefs (env : Environment) (name : Name) : UInt64 × Array Name := Id.run do
  let mut visited : NameSet := {}
  let mut stack : Array Name := #[name]
  let mut refs : NameSet := {}
  let mut hidden : Array (Name × UInt64) := #[]
  let mut own : UInt64 := 0
  while h : stack.size > 0 do
    let n := stack[stack.size - 1]
    stack := stack.pop
    if visited.contains n then continue
    visited := visited.insert n
    let some ci := env.find? n | continue
    let es := exprsOf env ci
    let hh := hashExprs es
    if n == name then own := hh else hidden := hidden.push (n, hh)
    for e in es do
      for c in e.getUsedConstants do
        if c == name || visited.contains c then continue
        if isHidden env c then stack := stack.push c
        else refs := refs.insert c
  let sorted := hidden.qsort (fun a b => nameLt a.1 b.1)
  let total := sorted.foldl (fun h (n, x) => mixHash (mixHash h (hash n)) x) (mixHash own (hash name))
  return (total, refs.toArray.qsort nameLt)

/-- Merkle の計算に使う節点。 -/
structure Node where
  name : Name
  layer : Layer
  own : UInt64
  /-- 合成範囲の参照先（名前順）。 -/
  edges : Array Name
  deriving Inhabited

/-- Tarjan の強連結成分分解。成分は逆位相順（参照先の成分が先）に並ぶ。 -/
partial def sccs (nodes : Array Node) : Array (Array Name) := Id.run do
  let idx : NameMap Nat := nodes.foldl (init := {}) fun m n => m.insert n.name m.size
  let edgesOf (i : Nat) : Array Nat :=
    (nodes[i]!).edges.filterMap fun e => idx.find? e
  -- 反復版 Tarjan（深い参照鎖でもスタックを溢れさせない）
  let mut index : Array (Option Nat) := Array.replicate nodes.size none
  let mut low : Array Nat := Array.replicate nodes.size 0
  let mut onStack : Array Bool := Array.replicate nodes.size false
  let mut st : Array Nat := #[]
  let mut counter := 0
  let mut out : Array (Array Name) := #[]
  for root in [0:nodes.size] do
    if index[root]!.isSome then continue
    -- 呼び出しスタック: (節点, 次に見る辺の位置)
    let mut call : Array (Nat × Nat) := #[(root, 0)]
    index := index.set! root (some counter); low := low.set! root counter; counter := counter + 1
    st := st.push root; onStack := onStack.set! root true
    while h : call.size > 0 do
      let (v, ei) := call[call.size - 1]
      let es := edgesOf v
      if ei < es.size then
        call := call.set! (call.size - 1) (v, ei + 1)
        let w := es[ei]!
        match index[w]! with
        | none =>
          index := index.set! w (some counter); low := low.set! w counter; counter := counter + 1
          st := st.push w; onStack := onStack.set! w true
          call := call.push (w, 0)
        | some wi =>
          if onStack[w]! then low := low.set! v (min low[v]! wi)
      else
        call := call.pop
        if h' : call.size > 0 then
          let (u, _) := call[call.size - 1]
          low := low.set! u (min low[u]! low[v]!)
        if low[v]! == (index[v]!).getD 0 then
          let mut comp : Array Name := #[]
          let mut done := false
          while !done do
            match st.back? with
            | none => done := true
            | some w =>
              st := st.pop; onStack := onStack.set! w false
              comp := comp.push (nodes[w]!).name
              if w == v then done := true
          out := out.push (comp.qsort nameLt)
  return out

/--
Merkle ハッシュを求める。成分ごとに、構成員の名前と自身のハッシュ（名前順）、
成分の外の参照先の `merkle`（名前順）を合成し、構成員ごとに名前を混ぜる。
-/
def computeMerkle (nodes : Array Node) : NameMap UInt64 := Id.run do
  let byName : NameMap Node := nodes.foldl (init := {}) fun m n => m.insert n.name n
  let mut merkle : NameMap UInt64 := {}
  for comp in sccs nodes do
    let inComp (n : Name) := comp.contains n
    let mut h : UInt64 := 11
    for m in comp do
      if let some node := byName.find? m then
        h := mixHash (mixHash h (hash m)) node.own
    let mut ext : NameSet := {}
    for m in comp do
      if let some node := byName.find? m then
        for e in node.edges do
          if !inComp e && byName.contains e then ext := ext.insert e
    for e in ext.toArray.qsort nameLt do
      h := mixHash (mixHash h (hash e)) ((merkle.find? e).getD 0)
    for m in comp do
      merkle := merkle.insert m (if comp.size == 1 then h else mixHash h (hash m))
  return merkle

/-- 16 進 16 桁。 -/
def hex64 (x : UInt64) : String :=
  let s := String.ofList (Nat.toDigits 16 x.toNat)
  String.ofList (List.replicate (16 - s.length) '0') ++ s

/-- 定数を定義したモジュールの名前（読み込んだモジュールでなければ空）。 -/
def moduleOf (env : Environment) (n : Name) : String :=
  match env.getModuleIdxFor? n with
  | some i => (env.header.moduleNames[i.toNat]?.map (·.toString)).getD ""
  | none => ""

/-- 1 定義の出力。 -/
structure Entry where
  name : Name
  layer : Layer
  attributes : List (String × Array String)
  merkle : String
  references : Array Name
  /-- 定義のあるモジュール（`rehash` が注釈を書き換えるファイルを引くため）。 -/
  module : String

/-- JSON に変換する。 -/
def Entry.toJson (e : Entry) : Json :=
  Json.mkObj [
    ("name", Lean.toJson e.name.toString),
    ("layer", Lean.toJson e.layer),
    ("attributes", Json.mkObj (e.attributes.map fun (k, vs) => (k, Lean.toJson vs))),
    ("merkle", Lean.toJson e.merkle),
    ("references", Lean.toJson (e.references.map (·.toString))),
    ("module", Lean.toJson e.module)]

/-- 環境の全定義を走査して出力を作る（名前順）。 -/
def dump (env : Environment) (cfg : Config) : Array Entry := Id.run do
  let mut targets : Array (Name × Layer) := #[]
  for (n, _) in env.constants.toList do
    if let some l := cfg.layerOf n then
      if !isHidden env n then targets := targets.push (n, l)
  let sorted := targets.qsort (fun a b => nameLt a.1 b.1)
  let mut nodes : Array Node := #[]
  let mut refsOf : NameMap (Array Name) := {}
  for (n, l) in sorted do
    let (own, refs) := ownHashAndRefs env n
    refsOf := refsOf.insert n refs
    let edges := refs.filter fun r =>
      match cfg.layerOf r with
      | some rl => cfg.merkleScope l rl
      | none => false
    nodes := nodes.push { name := n, layer := l, own, edges }
  let merkle := computeMerkle nodes
  return nodes.map fun node => {
    name := node.name, layer := node.layer
    attributes := attrsOf env node.name
    merkle := hex64 ((merkle.find? node.name).getD 0)
    references := (refsOf.find? node.name).getD #[]
    module := moduleOf env node.name }

/-- 出力全体の JSON。 -/
def dumpJson (env : Environment) (cfg : Config) : Json :=
  Json.mkObj [
    ("lean_version", toJson Lean.versionString),
    ("definitions", toJson ((dump env cfg).map Entry.toJson)),
    ("gaps", Trace.Gap.gapsJson env (moduleOf env))]

/-- 定数が依存する公理のうち、`allowed` に無いもの。 -/
def disallowedAxioms (env : Environment) (allowed : List Name) (name : Name) : IO (Array Name) := do
  let ctx : Core.Context := { fileName := "<axiom-check>", fileMap := default }
  let (axs, _) ← (collectAxioms name : CoreM _).toIO ctx { env }
  return axs.filter (!allowed.contains ·)

/--
引数で受けたモジュールを読み込む（追跡属性の拡張も読み込む）。
拡張の初期化に初期化子の実行を許す必要があり、`unsafe` とする（道具とテストの入口だけが呼ぶ）。
-/
unsafe def loadEnv (modules : Array Name) : IO Environment := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  importModules (modules.map fun m => { module := m }) {} (loadExts := true)

end Trace.Dump
