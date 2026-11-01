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
import Tests.DateExhaustive
import Tests.JavaDouble

/-!
# Tests

テスト。`lake test` は `Tests.Main`（実行ファイル `tests`）を実行する。
暦日の全日（`Tests.DateExhaustive`）と double の総当たり（`Tests.JavaDouble`）も `lake test` が実行する（長い検査の段 `long-tests` は ADR aaf8 で無くした）。
`native_decide`・`bv_decide` はここでだけ使ってよい（spec-pivot の `lang/lean/rules.md`）。
-/
