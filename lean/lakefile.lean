import Lake
open Lake DSL

/-!
ATRS の Lean プロジェクト（全モデルと証明）。

- 依存は Batteries と、port-lang スキルの言語意味論モデル（`langSemantics`）だけとする（ADR 659f）。
  `LangSemantics` には ATRS に固有の定義を足さないため、`lean/` に写さず Lake 依存として取り込む。
- `Machine`（抽象機械とリファインメントの枠組み）と `Trace`（追跡属性・ギャップの登録簿と、trace-dump・obligation-check の本体）も、
  同じ `langSemantics` パッケージから取り込む。道具の入口（`Tools`）だけをここに置く。
- 名前空間の依存の向きは port-lang の `scripts/ci/check_lean.py` で検査する。
-/
package atrs where
  leanOptions := #[⟨`autoImplicit, false⟩]
  testDriver := "tests"

require batteries from git "https://github.com/leanprover-community/batteries" @ "v4.35.0"
require langSemantics from "../.agents/skills/port-lang/assets/lean"

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

/-- 全宣言がモジュール名の下にあることの検査（port-lang の `Trace.Layout`）。 -/
@[default_target] lean_exe «layout-check» where
  root := `Tools.LayoutCheck
  supportInterpreter := true

/-- `lake test` のドライバ。 -/
@[default_target] lean_exe tests where
  root := `Tests.Main
  supportInterpreter := true
