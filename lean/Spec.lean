import Trace
import Machine
import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.CodeList
import Spec.MasterQuery
import Spec.Fare

/-!
# Spec

抽象モデル（言語中立・厳密整数の正規仕様。ADR 61bc）。各機能は `Machine.Machine` の抽象機械として与える。
依存してよいもの: `Spec`, `Machine`, `Trace`（port-lang の `architecture.md#依存の向き`）。

| モジュール | 内容 |
| --- | --- |
| `Spec.Prim` | 基本演算・暦日・時刻・書式・文字クラス |
| `Spec.Model` | 列挙・コード値・エンティティ・値域 |
| `Spec.Config` | 設定値と不変条件 |
| `Spec.MasterData` | マスタデータ、不変条件 MD-1〜MD-8、参照関数 |
| `Spec.CodeList` | コードリスト |
| `Spec.MasterQuery` | マスタ・設定・コードリストの参照の抽象機械（SPEC 課題、ABS-026 の抽象側） |
| `Spec.Fare` | 運賃計算（基本運賃・運賃・合計金額） |
-/
