---
type: Architecture Decision Record
title: "移植元ソース⇔SourceModel と TargetModel⇔移植先ソースを、ロケータ・モデル側注釈・本文ハッシュで追跡する"
description: "両端のトレースをロケータとモデル側の注釈で表し、確認済みハッシュで陳腐化を検出し、manifest 生成と TR 検査で網羅性と直接接続の禁止を機械的に保つ。"
tags: [adr, traceability]
id: "81ab9a21-02d3-4fe4-8f3a-53366e2cb7c9"
status: deprecated
decision_status: superseded
superseded_by: "e2a45550-1535-4d77-b945-d3dcb49fd16b"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 移植元ソース⇔SourceModel と TargetModel⇔移植先ソースを、ロケータ・モデル側注釈・本文ハッシュで追跡する

## Context and Problem Statement

[ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) で、トレースは両端の 2 本（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）だけとし、移植元ソースと移植先ソースは直接つながないと決めた。
既存の [traceability.md](../spec/traceability.md) は手書きのファイル単位の表で、腐りやすく、片側が変わったときに相手側の見直し漏れを検出できない。
さらに移植元の版上げに追従する必要がある（[ADR 3f36](3f36-following-upstream-releases.md)）。トレースの表現・保守・検査の方式を決める。

## Decision Drivers

* 上流のファイル構成・行番号が変わっても壊れにくいこと
* リンクの正を一か所に置き、二重管理しないこと
* 片側の変更で相手側が「要再確認」になること（陳腐化の機械検出）
* 網羅性と「直接つながない」規則を CI で検査できること

## Considered Options

* 記号的ロケータ ＋ モデル側の注釈（確認済みハッシュ付き）＋ 生成した manifest ＋ CI 検査
* 手書きの対応表を維持する
* ファイルパスと行番号による参照

## Decision Outcome

Chosen option: "記号的ロケータ ＋ モデル側の注釈 ＋ 生成 manifest ＋ CI 検査", because 版上げに強く、リンクの正をモデル側に一本化でき、陳腐化と規則違反を機械的に検出できるため。

### ロケータ

ソース側の位置は版に依存しない記号で指す。行番号は道具が版ごとに解決し、permalink を生成する。文法は [port-lang/traceability.md](../../.agents/skills/port-lang/references/docs/spec/traceability.md#ロケータ) に定義する。

| 側 | 種別 |
| --- | --- |
| 移植元 | `java:<FQCN>#<method>(<引数型>)`, `sql:<namespace>#<id>`, `ddl:<file>#<object>`, `prop:<file>#<key>`, `msg:<file>#<key>`, `http:<METHOD> <path>?<param>` |
| 移植先 | `rust:<crate>::<path>` |
| 両側 | `dep:<座標>#<シンボル>`（フレームワーク・クレート）、`lang:<言語>#<節>`（処理系） |

### インベントリ

* `trace/source-inventory.json`（上流を走査）と `trace/target-inventory.json`（`rust/` を走査）を道具で生成し、コミットする。
* 各項目は、ロケータ・ファイル・行範囲・**正規化した本文ハッシュ**（空白とコメントを除いて計算）を持つ。`dep:`・`lang:` は版文字列をハッシュの代わりに使う。
* 版の宣言は `trace/upstream.json`（上流 repo・variant・release・commit・依存の版・Java/PostgreSQL の版）と `trace/target.json`（Rust ツールチェーン・Verus・Kani・依存クレートの版）に置く。

### 注釈（リンクの正はモデル側）

| 置き場所 | 注釈 |
| --- | --- |
| Lean `SourceModel`, `LangSemantics.Java/Sql` | `@[source "<移植元ロケータ>@<確認済み本文ハッシュ>", …]` |
| Lean `TargetModel`, `LangSemantics.Rust` | `@[target "<移植先ロケータ>@<確認済み本文ハッシュ>", …]` |
| Rust `model/`（Verus の写し） | `/// trace: models <TargetModel の完全名> @<確認済み Lean Merkle ハッシュ>` |
| Lean `Abstraction`, `Refinement` | `@[obligation "ABS-NNN"]` / `@[obligation "REF-NNN"]`。モデル間の対応は定理の型に現れる定数から自動導出する |
| Lean `Spec` | `@[spec_doc "docs/spec/…#…"]` |
| 適合テストベクタ | `modelDef`（試すモデル定義の完全名）。`source-model/` には `upstream`（release と commit） |

* 属性は、どのモデルにも依存しない小さな基盤モジュールに定義する。`lake exe trace-dump` で、定義名・属性・**Merkle ハッシュ** を JSON に出力する。Merkle ハッシュは、定義の型と本体のハッシュに、参照する同じ層の定数のハッシュを合成したものである。
* Rust の `verus!` は一般的なパーサで読めないため、doc コメントの行走査で抽出する。

### 確認済みハッシュによる陳腐化の検出

注釈には、相手側を確認した時点のハッシュを記録する。現在の値とずれたら「要再確認」とし、検査を失敗させる。
再確認して振る舞いが変わらなければハッシュだけを更新し、変わればモデルを直す。どちらの場合も、確認したことが差分としてコミットに残る。

| 境界 | ずれる契機 |
| --- | --- |
| 移植元ソース → `SourceModel`（`@[source]`） | 上流の版上げ、依存・処理系の版の変化 |
| 移植先ソース → `TargetModel`（`@[target]`） | Rust ソースの変更 |
| `TargetModel` → Rust の写し（`/// trace: models`） | Lean `TargetModel` の変更 |

### 直接接続の禁止

* `SourceModel`・`LangSemantics.Java/Sql`・`Abstraction`・`Spec` に移植先ロケータ（`rust:`）を書いてはならない。
* `TargetModel`・`LangSemantics.Rust`・`Refinement` と `rust/` に移植元ロケータ（`java:` `sql:` `ddl:` `prop:` `msg:` `http:`、および移植元側の `dep:`）を書いてはならない。
* 移植元ソースと移植先ソースを直接対応づける表・ファイルを作ってはならない。影響分析は証明グラフ（`SourceModel` → `Abstraction` → `Spec` → `Refinement` → `TargetModel`）をたどって行う。

### 生成物と検査

* `trace/manifest.json`（生成・コミット対象）: 全ノードと型付きのリンク。
* [traceability.md](../spec/traceability.md) の 2 本の表（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）を manifest から生成する。

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の上流インベントリ項目が `@[source]` で覆われず、対象外一覧にも無い |
| TR-S2 | `@[source]` の確認済みハッシュが上流インベントリと一致しない |
| TR-T1 | `TargetModel` の公開定義に `@[target]` が無い。またはスコープ内の Rust 公開項目が `@[target]` で覆われず、対象外一覧にも無い |
| TR-T2 | `@[target]` のハッシュが Rust インベントリと一致しない。または `/// trace: models` のハッシュが Lean Merkle ハッシュと一致しない |
| TR-P | `SourceModel` の公開定義に `Abstraction` 定理が、`TargetModel` の公開定義に `Refinement` 定理が無い（理由付きの例外を除く） |
| TR-X | 直接接続の禁止に違反している |
| TR-R | 参照切れ（存在しない Lean 名・ロケータ・課題 ID） |

段階導入: Lean と Rust のコードがそろうまで、TR-S1・TR-T1・TR-P は警告とし、その他は最初から失敗とする。全検査を失敗扱いに切り替える時期は ADR で決める。

### 道具

* `tools/trace/` に Rust の独立 Cargo プロジェクト（stable ツールチェーン）を置く。`rust/`（Verus に合わせて版を固定）とは分ける。`tools/` は名前空間規則の例外（ビルド用の実行ファイル）とする。
* サブコマンド:
  * `inventory source|target`（tree-sitter-java・tree-sitter-rust と XML・properties・pom の簡易パーサ）
  * `ingest-lean`（`trace-dump` の取り込み）
  * `manifest`
  * `check`（TR 検査）
  * `diff`（新旧インベントリの分類）
  * `impact`（影響一覧）

### Consequences

* Good, because 上流の版上げ・Rust の変更・Lean の変更のいずれでも、見直しの必要な箇所が機械的に出る
* Good, because リンクの正がモデル側の注釈だけになり、表は生成物になる
* Bad, because 注釈とハッシュの更新が日常の作業に加わる
* Bad, because 道具（インベントリ生成・Lean の属性と Merkle ハッシュ）の初期実装が必要

### Confirmation

* CI で `tools/trace check` を実行する。
* [traceability.md](../spec/traceability.md) の例（運賃計算の 1 系統）で、各検査の判定を確認できる。

## Pros and Cons of the Options

### ロケータ＋モデル側注釈＋生成

* Good, because 版上げに強く、検査可能
* Bad, because 道具が必要

### 手書きの対応表

* Good, because すぐ始められる
* Bad, because 腐り、陳腐化を検出できない

### パスと行番号

* Good, because 単純
* Bad, because 上流の小さな変更で大量に壊れる

## More Information

* [ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md), [ADR 3f36](3f36-following-upstream-releases.md)
* [backlog ffdc](../backlog/ffdc-trace-tooling.md)

* （補足 2026-10-30）本 ADR は [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) で置き換えられた（[ADR c336](c336-foundational-principles.md) の基本原則に合わせるため）。
