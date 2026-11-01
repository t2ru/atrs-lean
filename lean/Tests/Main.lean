import Trace.Dump
import Tests
import Tests.Report

/-!
# Tests.Main

`lake test` のドライバ（実行ファイル `tests`）。追跡属性の道具の検査は、スキルの `assets/lean` の `lake exe trace-test` にある。

- 適合テストベクタ（`../conformance/`）を実行する（`Tests.Conformance`・`Tests.ConformanceFare`・`Tests.ConformanceMaster`）。`Spec` は `spec/`・`shared/`、`SourceModel` は `source-model/`・`shared/`。
- マスタの Mapper の文・コードリストの SQL の、PostgreSQL との差分実行の結果（`Tests.MasterSql`）。
- 空席照会の文の、PostgreSQL との差分実行の結果（`Tests.FlightSql`）。

暦日の全日の検査と double の総当たりは、数分かかるため実行ファイル `exhaustive`（`Tests.Exhaustive`）に分けた。
実行の時点は `docs/rules/checks.md`。節ごとの経過時間を表示する（`Tests.Report.timed`）。
-/

open Lean Trace.Dump Tests.Report

namespace Tests.Main

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
  timed "conformance shared/format (Spec)" do
    report "shared/format (Spec)" (← ConformanceKit.Runner.runDir Tests.Conformance.formatOps env.contains (root / "shared/format"))
  for (dir, layer, ops) in [("spec/fare", "Spec", Tests.ConformanceFare.specOps), ("shared/fare", "Spec", Tests.ConformanceFare.specOps),
      ("source-model/fare", "SourceModel", Tests.ConformanceFare.sourceOps), ("shared/fare", "SourceModel", Tests.ConformanceFare.sourceOps),
      ("shared/master-data", "Spec", Tests.ConformanceMaster.specOps),
      ("shared/master-data", "SourceModel", Tests.ConformanceMaster.sourceOps),
      ("shared/flight-search", "Spec", Tests.ConformanceFlightSearch.specOps),
      ("shared/flight-search", "SourceModel", Tests.ConformanceFlightSearch.sourceOps),
      ("source-model/flight-search", "SourceModel", Tests.ConformanceFlightSearch.sourceOps)] do
    timed s!"conformance {dir} ({layer})" do
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

end Tests.Main

open Tests.Main

unsafe def main : IO UInt32 := do
  timed "conformance" conformanceTests
  timed "master SQL" masterSqlTests
  timed "flight search SQL" flightSqlTests
  finish
