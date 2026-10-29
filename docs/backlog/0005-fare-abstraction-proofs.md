---
type: Backlog Item
title: "運賃計算の抽象化証明"
description: "ABS-001〜ABS-006 を Abstraction.Fare で証明し、成り立たない場合は反例と前提を abstraction.md に記録する。"
tags: [backlog, abstraction, proof, fare]
id: "0005"
state: todo
depends_on: ["0004"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 運賃計算の抽象化証明

## 目的

[Source] と [Spec] の運賃の差異を、一致する前提と差の上限として定理で確定させる。

## 範囲

- ABS-001（基本運賃の一致）
- ABS-002（シード前提での運賃の一致）
- ABS-003（差は 0〜100 円）
- ABS-004（合計金額）
- ABS-005（int32 オーバーフローが無い）
- ABS-006（ピーク時期の一意性）

## 対象外

- `native_decide` による全探索だけで主定理とすること

## 完了条件

- [ ] 各課題に対応する定理が `sorry` 無しで存在する
- [ ] [abstraction.md](../spec/abstraction.md) の D-001〜D-004 の「一致する前提」を証明結果で更新した

## 参照

- [abstraction.md](../spec/abstraction.md)
- [ADR 0004](../decision/0004-two-layer-model-java-faithful-and-abstract.md)
