---
type: Backlog Item
title: "運賃計算（Spec と SourceModel）"
description: "基本運賃・運賃・合計金額を Spec（厳密整数）と SourceModel（LangSemantics.Java）の両方で実装する。"
tags: [backlog, spec, source-model, fare]
id: "0004"
state: todo
depends_on: ["0002", "0003"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 運賃計算（Spec と SourceModel）

## 目的

二層モデルの最初の具体例として、差異が実在する運賃計算を両モデルで実装する。

## 範囲

- `Spec.Fare`: `basicFare`, `fare`, `totalFare`
- `SourceModel.Fare`: `calculateBasicFare`, `calculateFare`, `calculateTotalFare`（原典名）
- `conformance/spec/fare/`, `conformance/source-model/fare/`, `conformance/shared/fare/` のベクタ

## 対象外

- 証明（[backlog 0005](0005-fare-abstraction-proofs.md)）

## 完了条件

- [ ] [fare-calculation.md](../spec/fare-calculation.md) の全例がベクタ化され、両モデルで通る
- [ ] 1430 円・30% の例で [Spec] 1100、[Source] 1000 になる

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
