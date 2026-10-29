---
type: Backlog Item
title: "TargetModel と Refinement: 空席照会・予約・会員・認証・レポート"
description: "残りの機能の TargetModel を書き、Refinement で Spec との一致と空席の不変条件を証明し、target-model ベクタを生成する。"
tags: [backlog, lean, target-model, refinement]
id: "0023"
state: todo
depends_on: ["0022", "0006", "0007", "0008", "0009", "0010"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# TargetModel と Refinement: 空席照会・予約・会員・認証・レポート

## 目的

移植先側のモデルと証明を全機能で完成させる。

## 範囲

- `TargetModel.*`（各機能）
- REF-001, REF-002, REF-003, REF-005, REF-006
- `conformance/target-model/` の生成

## 対象外

- Rust の実装（[backlog 0020](0020-rust-usecases-core.md)）

## 完了条件

- [ ] REF-001〜REF-006 の定理が `sorry` 無しで存在する
- [ ] TR-P（`TargetModel` 側）が通る

## 参照

- [refinement.md](../spec/refinement.md)
