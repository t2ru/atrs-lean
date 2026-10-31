import ConformanceKit.Runner
import ConformanceKit.SqlTable

/-!
# ConformanceKit

適合テストベクタの実行器と、SQL の差分実行の結果の表を読む道具（メタ層。`Trace` と同じく、モデルの層ではない）。
プロジェクトのテスト（例: `Tests`）が使う。モデルの層から import してはならない。

| モジュール | 内容 |
| --- | --- |
| `ConformanceKit.Runner` | ベクタのファイルの読み込み・形式の検査・`expected.ok` の比較、共有入力（`fixtures`）、`modelDef` の選択 |
| `ConformanceKit.SqlTable` | 差分実行の結果の表（`Row`・`Table`・`col`）と、`Varchar`・`Int4` の列の読み取り |
-/
