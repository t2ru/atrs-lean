import Tests.TraceFixture
import Tests.AttrErrors
import Tests.Conformance
import Tests.SpecChecks
import Tests.JavaDouble
import Tests.ObligationFixture

/-!
# Tests

テスト。`lake test` は `Tests.Main`（実行ファイル `tests`）を実行する。
`native_decide`・`bv_decide` はここでだけ使ってよい（port-lang の `lean/rules.md`）。
-/
