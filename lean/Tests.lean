import Tests.Conformance
import Tests.ConformanceFare
import Tests.ConformanceMaster
import Tests.ConformanceFlightSearch
import Tests.ConformanceReservation
import Tests.MasterSql
import Tests.FlightSql
import Tests.ReservationSql
import Tests.SpecChecks
import Tests.Report
import Tests.TicketChecks

/-!
# Tests

テスト。`lake test` は `Tests.Main`（実行ファイル `tests`）を実行する。
長い検査（`Tests.Long`。暦日の全日・double の総当たり・シードの DB を使う照合）は実行ファイル `long-tests`（`Tests.LongMain`）が実行する。
`Tests.DateExhaustive`・`Tests.JavaDouble`・`Tests.Long` は、ここでは import しない（`docs/rules/checks.md`）。
`native_decide`・`bv_decide` はここでだけ使ってよい（spec-pivot の `lang/lean/rules.md`）。
-/
