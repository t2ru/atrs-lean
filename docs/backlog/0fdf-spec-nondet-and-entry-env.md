---
type: Backlog Item
title: "Spec の非決定性の選択の型と入口の環境の前提"
description: "Spec の非決定性 N-001〜N-005 の選択の型（@[nondet]）と、入口の環境の前提（マスタ・設定の妥当性と入力の値域。@[env_pre]）を Lean に定義し、両向きの例とシードの妥当性を示す。"
tags: [backlog, lean, spec, refinement]
id: "0fdf5090-3432-4a6e-9064-40f53e4231a9"
state: todo
depends_on: ["591d9aa4-065b-4975-8146-86aae05b780a", "f7b791e2-3d95-4436-a2d9-0320ad16a4fa"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
---

# Spec の非決定性の選択の型と入口の環境の前提

## 目的

[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md) の義務（SPEC-005・SPEC-006）を各機能の `Spec` が使えるように、非決定性の選択の型と、入口の環境の前提を先に定義する。
[backlog 591d](591d-abstract-domain-types-and-master-data.md) は ADR 70eb より前に完了したので、その範囲に含めなかった部分である。

## 範囲

- `Spec.Nondet`: [Spec の非決定性](../spec/abstraction.md#spec-の非決定性n-nnn) N-001〜N-005 の選択の型（`@[nondet]`）と、環境の選択の標準値
- 入口の環境の前提: マスタ・設定の妥当性（`Spec.MasterData.Valid`、`Spec.Config` の妥当性）と入力の値域（[domain-model.md](../spec/domain-model.md#値域)）を、入力の成分だけで書いた決定可能な述語（`@[env_pre]`）と、その両向きの例（`Nontrivial`）
- シードのマスタ・設定が環境の前提を満たすことの証明（`decide` で証明できない場合は、真偽値の関数とその正しさの定理で示す）

## 対象外

- 各機能の抽象機械（`Machine.ofChoice`）と `TotalUnder` の証明（各機能の backlog 項目）

## 完了条件

- [ ] N-001〜N-005 の選択の型に `@[nondet]` を付け、`check_obligations.py` の OB-N2 の警告が消えた
- [ ] 環境の前提に `@[env_pre]` と `Nontrivial` があり、`obligation-check` が通る
- [ ] シードのマスタ・設定が環境の前提を満たすことを示した

## 参照

- [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)
- [abstraction.md](../spec/abstraction.md#spec-の非決定性n-nnn)
- [master-data.md](../spec/master-data.md)
