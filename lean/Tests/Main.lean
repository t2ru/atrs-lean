import Trace.Dump
import Tests

/-!
# Tests.Main

`lake test` のドライバ（実行ファイル `tests`）。追跡属性の道具の検査は、スキルの `assets/lean` の `lake exe trace-test` にある。

- 適合テストベクタ（`../conformance/`）を実行する（`Tests.Conformance`・`Tests.ConformanceFare`・`Tests.ConformanceMaster`）。`Spec` は `spec/`・`shared/`、`SourceModel` は `source-model/`・`shared/`。
- マスタの Mapper の文・コードリストの SQL の、PostgreSQL との差分実行の結果（`Tests.MasterSql`）。
- 暦日の全日の検査（`Tests.SpecChecks.dateExhaustive`）。
- 運賃計算の double 式の、ソフトモデルとネイティブ `Float` の突き合わせ（`Tests.JavaDouble`）。
-/

open Lean Trace.Dump

namespace Tests.Main

/-- 失敗した検査の数。 -/
initialize failures : IO.Ref Nat ← IO.mkRef 0

def check (label : String) (ok : Bool) : IO Unit := do
  if ok then IO.println s!"  ok   {label}"
  else
    IO.eprintln s!"  FAIL {label}"
    failures.modify (· + 1)

/-- 適合テストベクタを実行する。`Spec` は `spec/`・`shared/`、`SourceModel` は `source-model/`・`shared/`。 -/
unsafe def conformanceTests : IO Unit := do
  IO.println "conformance (Spec: spec/*, shared/*; SourceModel: source-model/*, shared/*)"
  let env ← loadEnv #[`Spec, `SourceModel]
  let root : System.FilePath := "../conformance"
  let report (label : String) (results : Array ConformanceKit.Runner.FileResult) : IO Unit := do
    check s!"conformance: {label}: files found" (!results.isEmpty)
    for r in results do
      for f in r.failures do IO.eprintln s!"    {label}/{r.path.fileName.getD ""}: {f}"
      check s!"conformance: {label}/{r.path.fileName.getD ""} ({r.passed} cases)" (r.failures.isEmpty && r.passed > 0)
  report "shared/format (Spec)" (← ConformanceKit.Runner.runDir Tests.Conformance.formatOps env.contains (root / "shared/format"))
  for (dir, layer, ops) in [("spec/fare", "Spec", Tests.ConformanceFare.specOps), ("shared/fare", "Spec", Tests.ConformanceFare.specOps),
      ("source-model/fare", "SourceModel", Tests.ConformanceFare.sourceOps), ("shared/fare", "SourceModel", Tests.ConformanceFare.sourceOps),
      ("shared/master-data", "Spec", Tests.ConformanceMaster.specOps),
      ("shared/master-data", "SourceModel", Tests.ConformanceMaster.sourceOps),
      ("shared/flight-search", "Spec", Tests.ConformanceFlightSearch.specOps),
      ("shared/flight-search", "SourceModel", Tests.ConformanceFlightSearch.sourceOps)] do
    report s!"{dir} ({layer})" (← ConformanceKit.Runner.runDirFx ops layer env.contains root (root / dir))

/-- マスタの Mapper の文とコードリストの SQL の、PostgreSQL との差分実行（`conformance/sql/master-data.json`）。
あわせて、共有入力の表と PostgreSQL に投入した表、共有入力の設定と上流の設定の一致を確かめる。 -/
def masterSqlTests : IO Unit := do
  IO.println "master SQL (PostgreSQL results vs SourceModel.Domain.Repository)"
  let doc ← match Json.parse (← IO.FS.readFile "../conformance/sql/master-data.json") with
    | .ok d => pure d
    | .error e => do check s!"master-data.json: {e}" false; return
  let fixture ← match Json.parse (← IO.FS.readFile "../conformance/fixtures/master-data.json") with
    | .ok d => pure d
    | .error e => do check s!"fixtures/master-data.json: {e}" false; return
  match Tests.MasterSql.run doc with
  | .error e => check s!"master SQL: {e}" false
  | .ok rs => for (id, ok, info) in rs do check s!"master SQL: {id} ({info})" ok
  match Tests.MasterSql.fixtureMatches doc fixture with
  | .error e => check s!"fixture vs PostgreSQL: {e}" false
  | .ok rs => for (t, ok) in rs do check s!"fixture vs PostgreSQL: {t}" ok
  let config ← match Json.parse (← IO.FS.readFile "../conformance/fixtures/config.json") with
    | .ok d => pure d
    | .error e => do check s!"fixtures/config.json: {e}" false; return
  check "fixtures/config.json = SourceModel.AtrsProperties.upstreamConfig"
    ((Tests.ConformanceMaster.srcConfig config).toOption == some SourceModel.AtrsProperties.upstreamConfig)

/-- 空席照会の文の、PostgreSQL との差分実行（`conformance/sql/flight-search.json`）と、シードの FLIGHT 表の照合。 -/
def flightSqlTests : IO Unit := do
  IO.println "flight search SQL (PostgreSQL results vs SourceModel.Domain.Repository.Flight)"
  let master ← match Json.parse (← IO.FS.readFile "../conformance/sql/master-data.json") with
    | .ok d => pure d
    | .error e => do check s!"master-data.json: {e}" false; return
  let doc ← match Json.parse (← IO.FS.readFile "../conformance/sql/flight-search.json") with
    | .ok d => pure d
    | .error e => do check s!"flight-search.json: {e}" false; return
  let (n, h) := Tests.FlightSql.seedSummary
  let seed := (doc.getObjVal? "flightSeed").toOption.getD .null
  check s!"seedFlightDb = PostgreSQL FLIGHT after 00250 ({n} rows, hash)"
    ((seed.getObjValAs? Nat "rows").toOption == some n && (seed.getObjValAs? Nat "polyHash").toOption == some h)
  match Tests.FlightSql.run master doc with
  | .error e => check s!"flight SQL: {e}" false
  | .ok rs => for (id, ok, info) in rs do check s!"flight SQL: {id} ({info})" ok

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

end Tests.Main

open Tests.Main

unsafe def main : IO UInt32 := do
  dateTests
  javaDoubleTests
  conformanceTests
  masterSqlTests
  flightSqlTests
  let n ← failures.get
  if n == 0 then
    IO.println "all tests passed"
    return 0
  else
    IO.eprintln s!"{n} test(s) failed"
    return 1
