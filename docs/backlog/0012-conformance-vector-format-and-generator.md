---
type: Backlog Item
title: "適合テストベクタの生成と検査（Lean 側）"
description: "Lean Spec を実行して conformance/ の期待値を生成するツールと、スキーマ検査、Spec・SourceModel に対する実行器を作る。"
tags: [backlog, lean, conformance, testing]
id: "0012"
state: todo
depends_on: ["0004"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
---

# 適合テストベクタの生成と検査（Lean 側）

> 2026-10-29 に、実行器の置き場所を Lean の TargetModel から `Tests`/`Tools` に変更し、期待値を Lean `Spec` から生成する方針に改めた（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

## 目的

正規仕様（Lean `Spec`）から言語中立なベクタを機械的に作り、Rust の検証の基準にする。

## 範囲

- JSON スキーマ（[conformance.md](../spec/conformance.md)）の検査
- `Tools`: 入力ケースから Lean `Spec` を実行して `expected` を埋める生成器（`source: lean-spec`）
- `Tests`: `Spec` に対して `spec/`・`shared/`、`SourceModel` に対して `source-model/`・`shared/` を照合する実行器
- 生成したベクタの差分を CI でレビュー対象として示す仕組み
- TR-V（[ADR 0038](../decision/0038-refinement-non-vacuity-obligations.md)）: 各ケースについて、具体側の定義域・具体側の不変条件・制限した PRE を判定し、外に落ちることと `outsidePre` のラベルが一致することを検査する。判定のため、PRE・差異の述語・具体側の不変条件・環境の前提を `Decidable` にする
- `environment`（具体側の入力の環境）を持つケースの実行

## 対象外

- Rust 側の実行器（[backlog 0019](0019-rust-spec-mirror-and-fare-core.md)）

## 完了条件

- [ ] 運賃計算のベクタを Lean `Spec` から生成し、CI で照合できる
- [ ] 不正な形式のベクタを CI が検出する
- [ ] TR-V: ラベルの無い前提の外のケースと、前提の内にあるのにラベルのあるケースを、CI が検出する

## 参照

- [conformance.md](../spec/conformance.md)
- [ADR 0013](../decision/0013-conformance-test-vectors.md)
- [ADR 0021](../decision/0021-lean-spec-as-normative-source.md)
