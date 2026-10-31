import Lake
open Lake DSL

/-!
ATRS の Lean プロジェクト（全モデルと証明）。

- 依存は Batteries と、port-lang スキルの言語意味論モデル（`langSemantics`）だけとする（ADR 659f）。
  `LangSemantics` には ATRS に固有の定義を足さないため、`lean/` に写さず Lake 依存として取り込む。
- `Machine`（抽象機械とリファインメントの枠組み）も同じ `langSemantics` パッケージから取り込む。
- 名前空間の依存の向きは `tools/ci/check_lean.py` で検査する。
-/
package atrs where
  leanOptions := #[⟨`autoImplicit, false⟩]
  testDriver := "tests"

require batteries from git "https://github.com/leanprover-community/batteries" @ "v4.35.0"
require langSemantics from "../.agents/skills/port-lang/assets/lean"

/-- 追跡属性と trace-dump の基盤。どのモデルにも依存しない。 -/
@[default_target] lean_lib Trace

/-- 抽象モデル（正規仕様）。 -/
@[default_target] lean_lib Spec

/-- 移植元モデル。 -/
@[default_target] lean_lib SourceModel

/-- 抽象化証明課題（`SourceModel` が `Spec` をリファインする）。 -/
@[default_target] lean_lib Abstraction

/-- 移植先モデル。 -/
@[default_target] lean_lib TargetModel

/-- 具体化証明課題（`TargetModel` が `Spec` をリファインする）。 -/
@[default_target] lean_lib Refinement

/-- テスト（フィクスチャと `lake test` のドライバ）。 -/
@[default_target] lean_lib Tests

/-- 全定義の属性・Merkle ハッシュ・参照を JSON で出力する。 -/
@[default_target] lean_exe «trace-dump» where
  root := `Tools.TraceDump
  supportInterpreter := true

/-- 許可した公理（`propext`, `Quot.sound`, `Classical.choice`）以外への依存を検出する。 -/
@[default_target] lean_exe «axiom-check» where
  root := `Tools.AxiomCheck
  supportInterpreter := true

/-- R 課題の形と付帯の義務（TR-G。ADR 70eb）を判定する。 -/
@[default_target] lean_exe «obligation-check» where
  root := `Tools.ObligationCheck
  supportInterpreter := true

/-- `lake test` のドライバ。 -/
@[default_target] lean_exe tests where
  root := `Tests.Main
  supportInterpreter := true
