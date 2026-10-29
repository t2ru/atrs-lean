import Trace
import Machine
import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.CodeList

/-!
# Spec

抽象モデル（言語中立・厳密整数の正規仕様。ADR 0021）。各機能は `Machine.Machine` の抽象機械として与える。
依存してよいもの: `Spec`, `Machine`, `Trace`（port-lang の `architecture.md#依存の向き`）。

| モジュール | 内容 |
| --- | --- |
| `Spec.Prim` | 基本演算・暦日・時刻・書式・文字クラス |
| `Spec.Model` | 列挙・コード値・エンティティ・値域 |
| `Spec.Config` | 設定値と不変条件 |
| `Spec.MasterData` | マスタデータ、不変条件 MD-1〜MD-8、参照関数、SPEC 課題 |
| `Spec.CodeList` | コードリスト |
-/
