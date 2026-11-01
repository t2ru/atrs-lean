import Trace.Dump
import Tests.Report
import Tests.ConformanceMaster
import Tests.ConformanceFlightSearch
import Tests.FlightSql
import Tests.ConformanceReservation
import Tests.ReservationSql
import Tests.DateExhaustive
import Tests.JavaDouble

/-!
# Tests.Long

長い検査（実行ファイル `long-tests`。`lake exe long-tests`、mise の `lean:test-long`）。入口は `Tests.LongMain`。
CI で 20 秒以上かかる節を、`lake test`（`Tests.Main`）から分けた（`docs/rules/checks.md`）。

- 暦日の全日の検査（`Tests.DateExhaustive.dateExhaustive`）。
- 運賃計算の double 式の、ソフトモデルとネイティブ `Float` の突き合わせ（`Tests.JavaDouble`）。
- シードの DB を使う SourceModel の適合ベクタ（`shared/master-data`・`shared/flight-search`・`source-model/flight-search`）。
- 空席照会の文の、PostgreSQL との差分実行の結果と、シードの FLIGHT 表の照合（`Tests.FlightSql`）。
- 予約の SourceModel の適合ベクタ（`shared/reservation`・`source-model/reservation`）と、予約が使う文・シードの会員の、PostgreSQL との差分実行の結果（`Tests.ReservationSql`）。

`main` を持たないので、layout-check はこのモジュールを他の `Tests` と同じ組で読む（組を増やすと環境の分だけメモリが増える）。
`Tests` と `Tests.Main` は、このモジュールを import しない。
-/

open Lean Trace.Dump Tests.Report

namespace Tests.Long

/-- 暦日の全日の検査。 -/
def dateTests : IO Unit := do
  IO.println "date (0001-01-01 .. 9999-12-31)"
  let (bad, n) := Tests.DateExhaustive.dateExhaustive
  unless bad.isEmpty do IO.eprintln s!"    failed ordinals: {bad}"
  check s!"date: ofOrdinal? round trip and successor ({n} days)" bad.isEmpty

/-- double のソフトモデルとネイティブ `Float` の突き合わせ。 -/
def javaDoubleTests : IO Unit := do
  IO.println "java double (soft model vs native Float, fare expressions)"
  let r := Tests.JavaDouble.run
  for b in r.bad do IO.eprintln s!"    mismatch: {b}"
  check s!"java double: bit-exact ({r.count} cases)" r.bad.isEmpty

/-- シードの DB を使う SourceModel の適合ベクタ。 -/
unsafe def conformanceTests : IO Unit := do
  IO.println "conformance (SourceModel with the seed DB: shared/master-data, shared/flight-search, source-model/flight-search)"
  let env ← loadEnv #[`Spec, `SourceModel]
  let root : System.FilePath := "../conformance"
  for (dir, layer, ops) in [("shared/master-data", "SourceModel", Tests.ConformanceMaster.sourceOps),
      ("shared/flight-search", "SourceModel", Tests.ConformanceFlightSearch.sourceOps),
      ("source-model/flight-search", "SourceModel", Tests.ConformanceFlightSearch.sourceOps),
      ("shared/reservation", "SourceModel", Tests.ConformanceReservation.sourceOps),
      ("source-model/reservation", "SourceModel", Tests.ConformanceReservation.sourceOps)] do
    timed s!"conformance {dir} ({layer})" do
      reportConformance s!"{dir} ({layer})" (← ConformanceKit.Runner.runDirFx ops layer env.contains root (root / dir))

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

/-- 予約が使う文の、PostgreSQL との差分実行（`conformance/sql/reservation.json`）と、シードの会員の照合。
`knownMismatch` のあるケースは、モデルと異なると分かっているもので、実際に異なることを確かめる。 -/
def reservationSqlTests : IO Unit := do
  IO.println "reservation SQL (PostgreSQL results vs SourceModel.Domain.Repository.{Flight,Member,Reservation})"
  let master ← match Json.parse (← IO.FS.readFile "../conformance/sql/master-data.json") with
    | .ok d => pure d
    | .error e => do check s!"master-data.json: {e}" false; return
  let doc ← match Json.parse (← IO.FS.readFile "../conformance/sql/reservation.json") with
    | .ok d => pure d
    | .error e => do check s!"reservation.json: {e}" false; return
  match Tests.ReservationSql.seedMatches doc with
  | .error e => check s!"member seed: {e}" false
  | .ok rs => for (label, ok) in rs do check s!"member seed vs PostgreSQL: {label}" ok
  match Tests.ReservationSql.run master doc with
  | .error e => check s!"reservation SQL: {e}" false
  | .ok rs =>
    for (id, ok, info, known) in rs do
      if known then
        check s!"reservation SQL: {id} (known mismatch, expected to differ: {info})" (!ok)
      else
        check s!"reservation SQL: {id} ({info})" ok


/-- 長い検査をすべて実行する。 -/
unsafe def run : IO Unit := do
  timed "date" dateTests
  timed "java double" javaDoubleTests
  timed "conformance (seed DB)" conformanceTests
  timed "flight search SQL" flightSqlTests
  timed "reservation SQL" reservationSqlTests

end Tests.Long
