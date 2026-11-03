---
type: Backlog Item
title: "Spec の非決定性の選択の型と入口の環境の前提"
description: "Spec の非決定性 N-001〜N-005 の選択の型（@[nondet]）と、入口の環境の前提（マスタ・設定の妥当性。@[env_pre]）を Lean に定義し、両向きの例とシードの妥当性を示す。入力の値域の前提は各機能の backlog で置く。"
tags: [backlog, lean, spec, refinement]
id: "0fdf5090-3432-4a6e-9064-40f53e4231a9"
state: done
depends_on: ["591d9aa4-065b-4975-8146-86aae05b780a", "f7b791e2-3d95-4436-a2d9-0320ad16a4fa"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:24:54+09:00
---

# Spec の非決定性の選択の型と入口の環境の前提

## 目的

[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md) の義務（SPEC-005・SPEC-006）を各機能の `Spec` が使えるように、非決定性の選択の型と、入口の環境の前提を先に定義する。
[backlog 591d](591d-abstract-domain-types-and-master-data.md) は ADR 70eb より前に完了したので、その範囲に含めなかった部分である。

## 範囲

- `Spec.Nondet`: [Spec の非決定性](../spec/abstraction.md#spec-の非決定性n-nnn) N-001〜N-005 の選択の型（`@[nondet]`）と、環境の選択の標準値
- 入口の環境の前提: マスタ・設定の妥当性（`Spec.MasterData.Valid`、`Spec.Config` の妥当性）を、入力の成分だけで書いた決定可能な述語（`@[env_pre]`）と、その両向きの例（`Nontrivial`）。入力の値域（[`Spec.Model`](../../lean/Spec/Model.lean#値域)）の述語は、入口の機械の入力の型に合わせて各機能の backlog（[a89e](a89e-http-contract-adapter.md)・[ac71](ac71-reservation-history-report.md)）で置く（プロジェクトオーナーの決定。[ADR cd33](../decision/cd33-spec-nondet-types-and-env-pre.md)）
- シードのマスタ・設定が環境の前提を満たすことの証明（`decide` で証明できない場合は、真偽値の関数とその正しさの定理で示す）

## 対象外

- 各機能の抽象機械（`Machine.ofChoice`）と `TotalUnder` の証明（各機能の backlog 項目）

## 完了条件

- [x] N-001〜N-005 の選択の型に `@[nondet]` を付け、`check_obligations.py` の OB-N2 の警告が消えた（`Spec.Nondet`）
- [x] 環境の前提に `@[env_pre]` と `Nontrivial` があり、`obligation-check` が通る（`Spec.EnvPre.masterConfigOk`・`masterConfigOk_nontrivial`）
- [x] シードのマスタ・設定が環境の前提を満たすことを示した（`Spec.EnvPre.seed_env`。生成した `Spec.Seed` と検査関数 `EnvPre.validB`・`validB_sound`）

## 参照

- [ADR cd33](../decision/cd33-spec-nondet-types-and-env-pre.md)

- [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)
- [abstraction.md](../spec/abstraction.md#spec-の非決定性n-nnn)
- [`Spec.MasterData`](../../lean/Spec/MasterData.lean)
