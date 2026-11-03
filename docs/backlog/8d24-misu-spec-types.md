---
type: Backlog Item
title: "Spec の型を、不正な状態を表現できない型にする"
description: "ADR 6d36 に従い、ATRS の Spec の型を L1（値）・L2（境界）・L3（関係）の順に書き換え、SourceModel の α・生成器・テスト・証明を追従させる。"
tags: [backlog, spec, types, misu]
id: "8d240cee-be76-41cb-857e-ebe44ad87e53"
state: done
depends_on: ["d3fd1f35-7c8a-4218-a2a8-c7f617541769"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T14:00:00+09:00
---

# Spec の型を、不正な状態を表現できない型にする

## 目的

[ADR 6d36](../decision/6d36-misu-spec-types.md) の決定を、ATRS の `Spec` とそれに依存する層に当てる。

## 範囲

- L1: コード値、`Reservation`（片道・往復の和型、写しの除去、搭乗者の列）、`AtrsError` のコードの列挙、`FaultSpec` の名前付きの組。
- L2: 機械の入力・要求・画面の入力を生の型（`@[raw_input]`）にし、検証の関数が検証済みの型を返す形にする。
- L3: 設定・マスタの生の型と検証済みの型、`EnvPre` の書き直し、`World` のキーの一意性の証明フィールド。
- 追従: `Abstraction` の α と証明、生成器 `tools/conformance/*_seed.py`・`seed_lean.py`、`Tests` の読み取り、ギャップの付け替え、`docs/spec/domain-model.md`。

## 対象外

- 機械の PRE・INV の枠と、状態とマスタの外部キー（ADR 6d36）。
- スキルの assets の型（[スキルの backlog d3fd](../../.agents/skills/spec-pivot/references/docs/backlog/d3fd-misu-skill-types.md)）。

## 完了条件

- [x] スキルの検査 MISU-1 が、ATRS の `Spec` で違反 0 件である。
- [x] `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts`、`seed_env` が通る。
- [x] `lake test` の適合テストベクタがすべて通る。
- [x] ギャップの付け替えを ADR 6d36 の段の記録に書き、`trace manifest` の表がそれと一致する。
- [x] 全数の `mise run ci` が通る。

## 参照

- [ADR 6d36](../decision/6d36-misu-spec-types.md)
- [スキルの ADR bf1b](../../.agents/skills/spec-pivot/references/docs/decision/bf1b-make-illegal-states-unrepresentable.md)
