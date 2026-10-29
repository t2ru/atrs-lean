# 適合テストベクタの形式

## ディレクトリ

```
conformance/
  fixtures/                共有入力（マスタデータ、設定、状態のスナップショット）
  spec/<feature>/          [Spec] の期待値（Lean Spec を実行して生成）
  source-model/<feature>/  [Source] の期待値（Lean SourceModel の実行と移植元オラクル）
  target-model/<feature>/  [Target] の期待値（Lean TargetModel を実行して生成）
  shared/<feature>/        複数のモデルで同じ期待値
```

| 対象 | 通すベクタ |
| --- | --- |
| Lean `Spec` | `spec/`, `shared/` |
| Lean `SourceModel` と移植元ソース | `source-model/`, `shared/` |
| Lean `TargetModel` と移植先ソース | `target-model/`, `shared/` |

`<feature>` と操作名の一覧は、各プロジェクトの仕様文書（meta）に置く。

## ファイル形式

1 ファイル = 1 つの操作のケースの配列。

```json
{
  "operation": "fare.fare",
  "modelDef": "Spec.Fare.fare",
  "specRef": "<仕様文書のパス>#<アンカー>",
  "fixtures": { "master": "fixtures/master-data.json", "config": "fixtures/config.json" },
  "cases": [
    {
      "id": "fare-030-1430",
      "description": "丸め誤差で Source が少なくなる例",
      "input": { "basicFare": 1430, "discountRate": 30 },
      "expected": { "ok": 1100 },
      "source": "lean-spec",
      "differences": ["D-002"]
    }
  ]
}
```

| キー | 必須 | 内容 |
| --- | --- | --- |
| `operation` | 必須 | 操作名 |
| `modelDef` | 必須 | ベクタが試すモデル定義の完全名（`Spec.*` / `SourceModel.*` / `TargetModel.*`）。追跡の検査 TR-R の対象 |
| `specRef` | 必須 | 仕様文書の節への相対パス＋アンカー |
| `upstream` | `source-model/` では必須 | 期待値を得た移植元の版 `{"release": …, "commit": …}` |
| `fixtures` | 任意 | 既定の共有入力。ケースの `input` で上書きできる |
| `cases[].id` | 必須 | ファイル内で一意 |
| `cases[].today` / `now` | 日付・日時に依存する操作では必須 | `"yyyy-MM-dd"` / `"yyyy-MM-ddTHH:mm:ss"`（タイムゾーン無し） |
| `cases[].world` | 状態を使う操作では必須 | 実行前の状態、またはその fixture への参照 |
| `cases[].input` | 必須 | 操作の入力 |
| `cases[].expected` | 必須 | `{"ok": 値}` または `{"error": {"kind": "...", "code": "...", "args": []}}`。状態を変える操作は `"worldAfter"` も持てる |
| `cases[].source` | 必須 | `lean-spec` / `lean-source-model` / `<移植元>-oracle` / `lean-target-model` |
| `cases[].differences` | 任意 | 関係する既知差異 ID |

## 値の表現

| 型 | JSON |
| --- | --- |
| 整数 | 数値（整数のみ。小数・指数表記は使わない） |
| 文字列 | 文字列（UTF-8） |
| 暦日 | `"yyyy-MM-dd"` |
| 時刻 | `"HH:mm"` |
| 列挙 | 列挙子の綴りの文字列 |
| Option | 値または `null` |
| 順序付き写像 | `[[key, value], ...]`（JSON オブジェクトのキー順に依存しないため） |
| バイト列 | `{"utf8": "…"}`（UTF-8 として正しい場合）または `{"hex": "…"}` |
| 非決定的な結果（[Source]） | `{"oneOf": [値, ...]}` |

非決定的な外部要素（パスワードハッシュ、採番）を使う操作のベクタは、プロジェクトで決めた決定的な参照実装（例: テスト用ハッシュ関数）を前提にする。
