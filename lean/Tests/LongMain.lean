import Tests.Long

/-!
# Tests.LongMain

実行ファイル `long-tests` の入口（`main` だけを置く。検査の本体は `Tests.Long`）。
-/

unsafe def main : IO UInt32 := do
  Tests.Long.run
  Tests.Report.finish
