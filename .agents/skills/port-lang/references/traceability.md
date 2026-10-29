# 両端の追跡（トレーサビリティ）

```
移植元ソース ⇔①⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔②⇔ 移植先ソース
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側は追跡ではなく **証明** でつながる。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。
- ① と ② は同じ仕組みを使う。違いは、使う言語パック（移植元の言語か、移植先の言語か）と、注釈の名前（`@[source]` / `@[target]`）だけである。

## ロケータ

ソースの位置は、版に依存しない記号的なロケータで指す。行番号は道具が版ごとに解決し、permalink を生成する。

```
locator = kind ":" body
```

- `kind` と `body` の文法は言語パックの `locators.md` が定める（例: Java の `java:`、SQL の `sql:`、Rust の `rust:`）。言語パックのロケータは、その言語が移植元・移植先のどちらでも同じ文法で使う。
- 全言語共通の kind が 2 つある。

| kind | 形式 | 例 |
| --- | --- | --- |
| `dep` | `<パッケージ座標>#<シンボル>`（フレームワーク・ライブラリ） | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText`, `dep:serde_json#from_str` |
| `lang` | `<言語>#<仕様の節>`（言語・処理系そのもの） | `lang:java#JLS-5.1.3`, `lang:rust#integer-overflow` |

- フレームワーク・処理系の挙動に依存するモデル定義は、`dep`・`lang` ロケータを **必ず** 含める。依存の版が変わると、影響する定義が自動で出る。

## 版の宣言とインベントリ

| ファイル | 内容 |
| --- | --- |
| `trace/upstream.json` | 移植元: repo・variant・release・commit、依存の版、言語・処理系の版 |
| `trace/target.json` | 移植先: ツールチェーン・検証器・依存の版 |
| `trace/source-inventory.json` | 移植元ソースを走査した、ロケータ・ファイル・行範囲・**正規化した本文ハッシュ** |
| `trace/target-inventory.json` | 移植先ソースを走査した、同じ形式の一覧 |
| `trace/manifest.json` | 全ノードと型付きのリンク（生成） |
| `trace/renames.json` | 版上げ時の、ハッシュで判別できない改名の対応（手書き） |
| `trace/out-of-scope.json` | 追跡の対象外とするロケータと理由（手書き） |

- インベントリの取り方（パーサ・正規化の規則）は言語パックの `locators.md` が定める。
- `dep`・`lang` の項目は、本文ハッシュの代わりに版文字列を持つ。

## 注釈（リンクの正はモデル側）

| 置き場所 | 注釈 | リンク |
| --- | --- | --- |
| `SourceModel`, 移植元の `LangSemantics` | `@[source "<ロケータ>@<確認済みハッシュ>", …]` | ① |
| `TargetModel`, 移植先の `LangSemantics` | `@[target "<ロケータ>@<確認済みハッシュ>", …]` | ② |
| 移植先ソース内のモデルの写し（例: Verus の spec 関数） | `trace: models <TargetModel の完全名> @<Lean Merkle ハッシュ>`（書き方は言語パックの `layout.md`） | ②（逆向きの確認） |
| `Abstraction`, `Refinement` | `@[obligation "ABS-NNN" / "REF-NNN"]`。モデル間の対応は定理の型から自動導出する | 内側（証明） |
| `Spec` | `@[spec_doc "<仕様文書#アンカー>"]`、`@[no_source "<理由>"]` | 文書 |
| ベクタ | `modelDef`, `upstream`（[conformance.md](conformance.md)） | テスト |

属性の定義と `trace-dump` は [lean/trace-attributes.md](lean/trace-attributes.md)。

### 確認済みハッシュ

注釈には、相手側を確認した時点のハッシュを記録する。現在の値とずれたら「要再確認」とし、検査を失敗させる。
再確認の結果、振る舞いが変わっていなければハッシュだけを更新する。変わっていればモデルを直す。

| 境界 | ずれる契機 |
| --- | --- |
| 移植元ソース → `SourceModel` | 移植元の版上げ、依存・処理系の版の変化 |
| 移植先ソース → `TargetModel` | 移植先ソースの変更 |
| `TargetModel` → 移植先ソース内の写し | Lean `TargetModel` の変更 |

### 直接接続の禁止

- 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`, `Spec`）に、移植先の言語のロケータを書いてはならない。
- 移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）と移植先ソースに、移植元の言語のロケータを書いてはならない。
- 同じ言語が移植元と移植先の両方になる場合（例: Java から Java への移植）は、ロケータにリポジトリの区別を付ける（`java@source:` / `java@target:`）。

## 検査

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の `source-inventory` の項目が `@[source]` で覆われず、`out-of-scope.json` にも無い |
| TR-S2 | `@[source]` のハッシュが `source-inventory` と一致しない |
| TR-T1 | `TargetModel` の公開定義に `@[target]` が無い。または `target-inventory` の公開項目が覆われず、対象外でもない |
| TR-T2 | `@[target]` のハッシュが `target-inventory` と、写しのハッシュが Lean の Merkle ハッシュと一致しない |
| TR-P | `SourceModel` の公開定義に `Abstraction` 定理が、`TargetModel` の公開定義に `Refinement` 定理が無い（理由付きの例外を除く） |
| TR-X | 直接接続の禁止に違反している |
| TR-R | 存在しない Lean 名・ロケータ・課題 ID への参照がある |

段階導入: モデルとソースがそろうまで、TR-S1・TR-T1・TR-P は警告にしてよい。他は最初から失敗とする。

## 道具

専用の CLI（例: `tools/trace/`）に次の機能を持たせる。言語ごとの部分（パーサ）は言語パックの `locators.md` に従う。

| サブコマンド | 機能 |
| --- | --- |
| `inventory source` / `inventory target` | インベントリの生成 |
| `ingest-lean` | `lake exe trace-dump` の出力の取り込み |
| `manifest` | manifest と、仕様文書の生成区画（① と ② の 2 本の表）の生成 |
| `check` | TR 検査 |
| `diff` | 新旧インベントリの分類（[upgrade.md](upgrade.md)） |
| `impact` | 証明グラフに沿った影響一覧 |

生成区画は `<!-- BEGIN GENERATED: source-trace -->` / `<!-- END GENERATED: source-trace -->`（② は `target-trace`）で区切る。区画の中を手で編集してはならない。
