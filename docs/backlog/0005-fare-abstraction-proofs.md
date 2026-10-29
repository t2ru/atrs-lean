---
type: Backlog Item
title: "運賃計算の抽象化証明"
description: "ABS-001〜ABS-006 を Abstraction.Fare で証明し、成り立たない場合は反例と前提を abstraction.md に記録する。"
tags: [backlog, abstraction, proof, fare]
id: "0005"
state: todo
depends_on: ["0004", "0027", "0013", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 運賃計算の抽象化証明

## 目的

[Source] と [Spec] の運賃の差異を、一致する前提と差の上限として定理で確定させる。

## 範囲

- R 課題: ABS-001（基本運賃）、ABS-002（運賃）、ABS-004（合計金額）、ABS-006（ピーク時期）。いずれも `Machine.Refines` の形で示す
- W 課題: ABS-101（D-001 の証拠、または差異が無いことの証明）、ABS-102（D-002）、ABS-112（D-012）
- C・L 課題: ABS-003（差は 0〜100 円）、ABS-005（D-012 の前提の下で int32 の溢れが無い）、ABS-007（値域全体での基本運賃の一致の試み）
- 前提型の差異の述語 `dev_D001`・`dev_D002`・`dev_D012`（`@[deviation]`）

## 対象外

- `native_decide`・`bv_decide` を証明に使うこと（[verification.md](../../.agents/skills/port-lang/references/verification.md#証明の運用)）

## 完了条件

- [ ] 各課題に対応する定理が `sorry`・`native_decide`・`bv_decide` 無しで存在する
- [ ] D-001 を確定した（証拠 ABS-101 を示したか、ABS-007 で差異が無いことを証明して D-001・ABS-101 を取り消した）
- [ ] 運賃計算の SPEC-001 を証明した
- [ ] 運賃計算の `source-model/` ベクタが Java オラクルと一致する（[backlog 0013](0013-java-oracle-harness.md)）
- [ ] [abstraction.md](../spec/abstraction.md) の D-001・D-002・D-012 の前提を証明結果で更新し、TR-D が通る

## 参照

- [abstraction.md](../spec/abstraction.md)
- [ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md)
