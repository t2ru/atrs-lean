import Test.Trace.Fixture
import Test.Trace.AttrErrors
import Test.Trace.ObligationFixture
import Test.Trace.GapErrors

/-!
# Test.Trace

追跡属性（`Trace`）の検査。属性の引数の誤りは `#guard_msgs` でビルド時に確かめる。
`trace-dump`・`obligation-check` の処理は、`lake exe trace-test`（`Test.Trace.Main`）がフィクスチャにかけて確かめる。
-/
