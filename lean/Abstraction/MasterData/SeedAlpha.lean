import Abstraction.MasterData.Alpha
import SourceModel.Db.MasterSeed
import Spec.Seed

/-!
# Abstraction.MasterData.SeedAlpha

シードのマスタの具体側の DB（`SourceModel.Db.MasterSeed.masterDb`）の α は、[Spec] のシードのマスタ
`Spec.Seed.masterData` である（ADR ab93 の 3d。予約の束の環境の前提の証人を初期状態で示すのに使う）。
どちらも同じ共有入力 `conformance/fixtures/master-data.json` からの生成物で、カーネルでの評価で示す。
-/

namespace Abstraction.MasterData.SeedAlpha
open Abstraction.MasterData.Alpha

theorem masterDataOf_seed : masterDataOf SourceModel.Db.MasterSeed.masterDb = some Spec.Seed.masterData := by
  decide +kernel

end Abstraction.MasterData.SeedAlpha
