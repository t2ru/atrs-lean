---
type: Architecture Decision Record
title: "言語中立な適合テストベクタを JSON で管理し、全実装の完了条件とする"
description: "conformance/ 配下にモデル別の JSON テストベクタを置き、Lean・他言語実装がすべて通すことを移植完了の条件とする。"
tags: [adr, testing, conformance]
id: "dc3a6a3c-03fd-445a-8856-f9e130cb35cf"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:18:59+09:00
---

# 言語中立な適合テストベクタを JSON で管理し、全実装の完了条件とする

## Context and Problem Statement

最終目標は他言語への同一ロジックの移植である。「同一」であることを確認する手段が、各言語の単体テストだけでは、
テストの網羅範囲が言語ごとにばらつき、比較できない。言語に依存しない検証手段が必要である。

## Decision Drivers

* どの言語でも読み込めること
* 仕様の例・境界値・既知差異（[Spec]/[Source]）を区別して表現できること
* 期待値の出所（手計算・Java の原典実行・Lean 生成）を追跡できること

## Considered Options

* JSON のテストベクタ（モデル別ディレクトリ）
* 各言語でテストコードを個別に書く
* Lean 実装を他言語から FFI で呼んで比較する

## Decision Outcome

Chosen option: "JSON のテストベクタ", because JSON はほぼ全言語で標準的に扱え、仕様の例をそのまま機械可読にできるため。

* 置き場所: リポジトリ直下の `conformance/`。
  * `conformance/spec/<feature>/*.json` — [Spec] の期待値
  * `conformance/source-model/<feature>/*.json` — [Source] の期待値
  * `conformance/target-model/<feature>/*.json` — 移植先モデル `TargetModel` の期待値（Lean `TargetModel` を実行して生成。[ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md)）
  * `conformance/shared/<feature>/*.json` — 複数のモデルで同じ期待値
  * `conformance/fixtures/*.json` — マスタデータ・設定値などの共有入力
* `spec/` と `shared/` の期待値は、正規仕様である Lean `Spec` を実行して生成する（[ADR 61bc](61bc-lean-spec-as-normative-source.md)）。`source-model/` の期待値は Lean `SourceModel` の実行と Java の原典実行で得る。
* 1 ファイル = 1 ケース群。各ケースは `id`, `description`, `operation`, `today`, `input`, `expected`（`ok` または `error`）, `source`, `specRef` を持つ（詳細は [spec/conformance.md](../spec/conformance.md)）。
* JSON の値は整数・文字列・真偽・null・配列・オブジェクトのみ（浮動小数を使わない）。日付は `"yyyy-MM-dd"` 文字列。
* 移植の完了条件: Rust の移植先ソースが `target-model/` と `shared/` の全ベクタを通すこと。Lean の `Spec` は `spec/`・`shared/`、`SourceModel` は `source-model/`・`shared/`、`TargetModel` は `target-model/`・`shared/` を通す。

### Consequences

* Good, because 言語間で同じ尺度の検証ができる
* Good, because 仕様の例とテストが一致し続ける
* Bad, because ベクタ読み込みと `operation` の割当を各言語で実装する必要がある

### Confirmation

* Lean の CI で `Spec`・`SourceModel`・`TargetModel` に対して、Rust の CI で移植先ソースに対して全ベクタを実行する（[backlog a8ef](../backlog/a8ef-conformance-vector-format-and-generator.md)）。
* 第二言語での試行（[backlog 31da](../backlog/31da-second-language-portability-pilot.md)）で、ベクタだけを頼りに移植できるかを確認する。

## Pros and Cons of the Options

### JSON ベクタ

* Good, because 言語中立・差分レビューが容易
* Bad, because 状態を伴うユースケースのベクタは記述が長くなる

### 各言語で個別にテスト

* Good, because 各言語の慣習に沿う
* Bad, because 網羅範囲が揃わず、同一性を示せない

### FFI で比較

* Good, because 任意入力で比較できる
* Bad, because Lean のビルド環境を全言語に要求する。仕様ではなく実装を正にしてしまう

## More Information

* [spec/conformance.md](../spec/conformance.md), [spec-pivot/verification.md](../../.agents/skills/spec-pivot/references/docs/spec/verification.md)
* `shared/` の `modelDef` の配列、共有入力の生成器、`source-model/` の暫定の期待値は [ADR 8f18](8f18-fare-source-model-and-shared-vectors.md) で補った
