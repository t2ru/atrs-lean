import Tests.Conformance
import Tests.ConformanceFare
import Tests.ConformanceMaster
import Tests.ConformanceFlightSearch
import Tests.MasterSql
import Tests.FlightSql
import Tests.SpecChecks
import Tests.Report
import Tests.TicketChecks

/-!
# Tests

テスト。`lake test` は `Tests.Main`（実行ファイル `tests`）を実行する。
総当たりの検査（`Tests.DateExhaustive`・`Tests.JavaDouble`）は実行ファイル `exhaustive`（`Tests.Exhaustive`）が実行し、ここでは import しない
（閉じた項がモジュールの初期化で評価され、`lake test` の時間に戻らないようにする。`docs/rules/checks.md`）。
`native_decide`・`bv_decide` はここでだけ使ってよい（spec-pivot の `lang/lean/rules.md`）。
-/
