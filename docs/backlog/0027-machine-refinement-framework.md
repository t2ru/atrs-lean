---
type: Backlog Item
title: "Machine: 抽象機械と B メソッドのリファインメントの枠組み"
description: "アプリに依存しない Lean ライブラリ Machine（抽象機械、Refines、証明義務 INIT・適用可能性・正しさ、差異の仮定・成分）をスキルの assets/Machine/ に実装する。"
tags: [backlog, lean, refinement, proof]
id: "0027"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Machine: 抽象機械と B メソッドのリファインメントの枠組み

## 目的

原則 2（[ADR 0033](../decision/0033-foundational-principles.md)）を満たすため、次の 2 つの定理を同じ形で書ける枠組みを用意する。

- `SourceModel` が `Spec` をリファインする定理
- `TargetModel` が `Spec` をリファインする定理

定義は [ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md) による。

## 範囲

- `.agents/skills/port-lang/assets/Machine/`（core だけに依存。アプリ固有の型を入れない）
  - `Machine.Machine`: 状態・INV・INIT・操作（PRE、関係 `step`、実行可能な標準の選択 `run`、`run` が `step` に含まれる定理）
  - `Machine.Concrete`: 具体機械。正常終了でない結果（パニック・前提違反・溢れによる誤り・α/β の未定義）を結果として持つ。業務エラーは正常な結果である
  - `Machine.Refines`: 貼り合わせ不変条件 `J`・入力の対応 `αᵢ`・出力の対応 `αₒ` と、証明義務 INIT・入力の全域性・適用可能性・正しさ
  - `Machine.restrict`: 前提型の差異の述語（抽象側）で PRE を強める
  - `Machine.restrictConcrete`: 前提型の差異の述語（具体側だけにある入力・環境）で具体機械を制限する
  - 推移性など、基本の補題
- `assets/MachineTest/`: 小さな例。例として、非決定的な抽象機械を決定的な具体機械がリファインする場合と、具体側の非決定性のすべての分岐を模倣する場合を扱う
- ルートの `lakefile.lean` と `lean/` から `require` する
- スキルの [SKILL.md](../../.agents/skills/port-lang/SKILL.md) の assets の表の「未整備」を外す

## 対象外

- ATRS 固有の機械（各機能の backlog 項目で扱う）
- Mathlib（[ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md)）

## 完了条件

- [ ] `assets/` で `lake build` が通り、`MachineTest` の例が `sorry`・`native_decide`・`bv_decide` 無しで証明される
- [ ] 具体側が抽象側より大きな非決定性を持つ例で、`Refines` が成り立たないこと（反例）を示した
- [ ] `#print axioms` で、`propext`・`Quot.sound`・`Classical.choice` 以外の公理が無い

## 参照

- [ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md), [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)
- [port-lang/architecture.md](../../.agents/skills/port-lang/references/architecture.md#リファインメントb-メソッド)
