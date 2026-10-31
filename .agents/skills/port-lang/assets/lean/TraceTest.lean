import TraceTest.Fixture
import TraceTest.AttrErrors
import TraceTest.ObligationFixture
import TraceTest.GapErrors

/-!
# TraceTest

追跡属性（`Trace`）の検査。属性の引数の誤りは `#guard_msgs` でビルド時に確かめる。
`trace-dump`・`obligation-check` の処理は、`lake exe trace-test`（`TraceTest.Main`）がフィクスチャにかけて確かめる。
-/
