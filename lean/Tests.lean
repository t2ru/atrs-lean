import Tests.Conformance
import Tests.ConformanceFare
import Tests.ConformanceMaster
import Tests.ConformanceFlightSearch
import Tests.ConformanceReservation
import Tests.MasterSql
import Tests.FlightSql
import Tests.ReservationSql
import Tests.SpecChecks
import Tests.JavaDouble
import Tests.TicketChecks

/-!
# Tests

テスト。`lake test` は `Tests.Main`（実行ファイル `tests`）を実行する。
`native_decide`・`bv_decide` はここでだけ使ってよい（spec-pivot の `lang/lean/rules.md`）。
-/
