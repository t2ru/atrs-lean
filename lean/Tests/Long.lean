import Tests.Report
import Tests.DateExhaustive
import Tests.JavaDouble

/-!
# Tests.Long

長い検査（実行ファイル `long-tests`。`lake exe long-tests`、mise の `lean:test-long`）。入口は `Tests.LongMain`。
CI で 20 秒以上かかる節を、`lake test`（`Tests.Main`）から分けた（`docs/rules/checks.md`）。

- 暦日の全日の検査（`Tests.DateExhaustive.dateExhaustive`）。
- 運賃計算の double 式の、ソフトモデルとネイティブ `Float` の突き合わせ（`Tests.JavaDouble`）。

シードの DB を使う SourceModel の照合と空席照会の SQL の結果は、SQL の写しの結合を証明付きの `@[csimp]` で速くして
（CI で 20 秒未満）、`lake test` に戻した（ADR 9c1c）。

`main` を持たないので、layout-check はこのモジュールを他の `Tests` と同じ組で読む（組を増やすと環境の分だけメモリが増える）。
`Tests` と `Tests.Main` は、このモジュールを import しない。
-/

open Tests.Report

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

/-- 長い検査をすべて実行する。 -/
def run : IO Unit := do
  timed "date" dateTests
  timed "java double" javaDoubleTests

end Tests.Long
