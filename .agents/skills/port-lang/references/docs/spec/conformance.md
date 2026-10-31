---
type: Specification
title: "適合テストベクタの形式"
description: "言語中立な適合テストベクタの置き場所・JSON の形式・比較の規則・生成と実行器。"
tags: [conformance]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

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
  "operation": "pricing.taxIncluded",
  "modelDef": "Spec.Pricing.taxIncluded",
  "specRef": "<仕様文書のパス>#<アンカー>",
  "fixtures": { "master": "fixtures/master-data.json", "config": "fixtures/config.json" },
  "cases": [
    {
      "id": "tax-1000",
      "description": "double の丸め誤差で Source が 1 円少なくなる例",
      "input": { "price": 1000 },
      "expected": { "ok": 1100 },
      "source": "lean-spec",
      "differences": ["D-001"]
    }
  ]
}
```

| キー | 必須 | 内容 |
| --- | --- | --- |
| `operation` | 必須 | 操作名 |
| `modelDef` | 必須 | ベクタが試すモデル定義の完全名（`Spec.*` / `SourceModel.*` / `TargetModel.*`）。`shared/` では、モデルごとの名前の配列にしてよい（例 `["Spec.Pricing.taxIncluded", "SourceModel.Pricing.calcTax"]`）。実行器は、実行するモデルの層の名前を選ぶ。追跡の検査 TR-R と、`rehash` の検査の登録（`vectors`）の対象 |
| `specRef` | 必須 | 仕様文書の節への相対パス＋アンカー |
| `upstream` | `source-model/` では必須 | 期待値を得た移植元の版 `{"release": …, "commit": …}` |
| `fixtures` | 任意 | 既定の共有入力（`{"master": …, "config": …}`）。ケースの `input` で上書きできる。共有入力は、移植元のシードから生成器で作るとよい（転記の誤りを防ぎ、版上げで差分が見える）。モデルの値域の外の行は、行を残したまま `outsideSpec` に理由を書き、`Spec` 用の読み込みだけが除く |
| `cases[].id` | 必須 | ファイル内で一意 |
| `cases[].today` / `now` | 日付・日時に依存する操作では必須 | `"yyyy-MM-dd"` / `"yyyy-MM-ddTHH:mm:ss"`（タイムゾーン無し） |
| `cases[].world` | 状態を使う操作では必須 | 実行前の状態、またはその fixture への参照 |
| `cases[].input` | 必須 | 操作の入力 |
| `cases[].expected` | 必須 | `{"ok": 値}` または `{"error": {"kind": "...", "code": "...", "args": []}}`。状態を変える操作は `"worldAfter"` も持てる |
| `cases[].source` | 必須 | `lean-spec` / `lean-source-model` / `<移植元>-oracle` / `lean-target-model` |
| `cases[].differences` | 任意 | 関係する既知差異 ID |
| `cases[].outsidePre` | 前提の外に落ちるケースでは必須 | 外に落ちる理由の配列。前提型の差異の前提（具体側の定義域・制限した PRE）を破るなら差異の ID、基底の PRE（値域など）を破るなら `PRE`、具体側の不変条件を破るなら `INV`。付けたケースと外に落ちるケースが一致することを、TR-V で検査する |
| `cases[].environment` | 環境の選択を試すケースでは必須 | 具体側の入力の環境（衝突・I/O の失敗・配備の設定）。省いたケースは障害の無い環境（`Spec` の標準の選択）とする |

- TR-V の判定のため、`Spec` の PRE・前提型の差異の述語・具体側の不変条件・環境の前提は決定可能（Lean の `Decidable`）でなければならない。

## 意図から書く例

`spec/` のベクタは `Spec` の標準の選択 `run` から生成するので、`Spec` が業務の意図どおりであること（仕様の妥当性）は確かめない。
そこで、仕様文書の「例」（[spec-documents.md](../rules/spec-documents.md#定義の節構成draft-と-normative)）は、ベクタとは別に、期待値を手で書いた検査で `Spec` に照らす（Spec-Testing Proofs の考え方）。

- 形は `#guard`（実行できる計算）か定理（関係 `step` や PRE についての命題）とする。期待値を `run` から写してはならない。
- 許す例だけでなく、拒む例も書く。
  - 許す例: 意図した入力が PRE を満たす。意図した結果が `step` に含まれる
  - 拒む例: 意図した不正な結果が `step` に含まれない（`¬ step s i s' o`）。意図した不正な入力が PRE を満たさない
- 例の期待値と `Spec` が食い違ったら、どちらが意図と異なるかを判断する。`Spec` を直すか、仕様文書の例を直し、判断を意思決定として記録する。

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

## 比較の規則

- 移植元のほうが非決定性が大きい結果（例: 検証エラーの並びが `HashSet` の反復順で決まる）は、ベクタの期待値を `Spec` の定順の値で書き、移植元のベクタでは、観測型の差異の成分と同じ同一視（例: 多重集合として比べる）で比べる。同一視は差異として登録し、ケースの `differences` に ID を書く（[architecture.md](architecture.md#差異)）。`oneOf` で全順列を並べる書き方は、要素が多いと使えない。
- 日付に依存する共有入力（シードの日付・予約の期限など）は、固定の基準日から生成し、ケースの `today` をその基準日に合わせる。実行した日によってベクタの意味が変わらないようにするためである。基準日はプロジェクトの意思決定として記録する。
- 非決定的な外部要素（パスワードのハッシュ、採番）を使う操作は、決定的な参照実装（例: テスト用のハッシュ関数、決まった順に返す採番）を、ポートの実装として与えてから比べる。参照実装の選択は `Spec` の非決定性（自由な選択）の範囲になければならない。

## 実行器

Lean の実行器はスキルの `assets/lean/ConformanceKit` にある（`ConformanceKit.runDoc`・`runDir`・`runDirFx`・`selectModelDef`・`loadFixtures`）。
プロジェクトは、操作の割当（`operation` → モデルの関数。`List (String × ConformanceKit.Op)`）と、`Spec` の値の表現の読み取り（暦日・時刻など）を書き、`lake test` のドライバから実行器を呼ぶ。
SQL の差分実行の結果（[sql/harness.md](../lang/sql/harness.md#差分実行の結果)）の表は、`ConformanceKit.SqlTable` で読む。
