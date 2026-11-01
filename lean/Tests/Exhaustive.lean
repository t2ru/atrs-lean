import Tests.Report
import Tests.DateExhaustive
import Tests.JavaDouble

/-!
# Tests.Exhaustive

総当たりの検査のドライバ（実行ファイル `exhaustive`。`lake exe exhaustive`、mise の `lean:exhaustive`）。

- 暦日の全日の検査（`Tests.DateExhaustive.dateExhaustive`）。
- 運賃計算の double 式の、ソフトモデルとネイティブ `Float` の突き合わせ（`Tests.JavaDouble`）。

どちらも数分かかるため `lake test` から分けた。`lake test` のドライバ（`Tests.Main`）と `Tests` は、これらのモジュールを
import しない（閉じた項がモジュールの初期化で評価され、`lake test` の時間に戻らないようにする）。
実行の時点は `docs/rules/checks.md`、変更の範囲は `tools/ci/check-scopes.toml` の `lean:exhaustive`。
-/

open Tests.Report

namespace Tests.Exhaustive

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

end Tests.Exhaustive

open Tests.Exhaustive

def main : IO UInt32 := do
  timed "date" dateTests
  timed "java double" javaDoubleTests
  finish
