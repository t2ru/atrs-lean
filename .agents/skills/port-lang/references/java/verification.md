# Java: 検証器

## 移植元として

原典に検証器を当てる必要は無い。原典と `SourceModel` の対応は、オラクル（[harness.md](harness.md)）と追跡注釈で確認する。

## 移植先として

Java のコードと、Lean `TargetModel` の Java での写しとの一致を確認する手段は次のとおり。

| 手段 | 用途 |
| --- | --- |
| JML ＋ OpenJML（または KeY） | 純粋なメソッドの事前・事後条件を JML で書き、`TargetModel` の写し（JML のモデルメソッド）との一致を検証する |
| jqwik などの性質テスト | 検証器で扱いにくい部分の補助 |
| JUnit の照合テスト | `target-model/`・`shared/` のベクタ（必須） |

> **未整備:** JML の写しの書き方、追跡タグ（`trace: models …`）の置き場所、OpenJML の版固定。Java を移植先にするときに [layout.md](layout.md) とあわせて整備する。
