---
type: Backlog Item
title: "TargetModel と Refinement: 空席照会・予約・会員・認証・レポート"
description: "残りの機能の TargetModel を書き、Refinement で Spec との一致と空席の不変条件を証明し、target-model ベクタを生成する。"
tags: [backlog, lean, target-model, refinement]
id: "26c57ac3-b6b7-440a-aca5-994943bd7ebd"
state: todo
depends_on: ["eff6bfce-0ef0-49a1-8c6e-e2b7235fd113", "0be7c5d4-01d9-43f4-a50d-227f174830f0", "aedfeffc-3e82-46b1-b497-3d8b7808d068", "4e0e3dd1-d282-46e2-aa98-719853bc9fd2", "44f89eb1-e59a-4573-8129-7b0c1d4699bb", "ac713033-9b94-4e5a-bfc4-d27bdee7ee2e", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# TargetModel と Refinement: 空席照会・予約・会員・認証・レポート

## 目的

移植先側のモデルと証明を全機能で完成させる。

## 範囲

- `TargetModel.*`（各機能）
- REF-001, REF-002（`Conflict` と I/O 失敗の模倣を含む）, REF-003, REF-005, REF-006（REF-008 は [backlog 4b0e](4b0e-in-memory-adapters-and-seed-data.md)）
- `conformance/target-model/` の生成

## 対象外

- Rust の実装（[backlog 9c1b](9c1b-rust-usecases-core.md)）

## 完了条件

- [ ] REF-001〜REF-006 の定理が `sorry` 無しで存在する（R 課題は `Machine.Refines` の形）
- [ ] TR-P（`TargetModel` 側）が通る

## 参照

- [refinement.md](../spec/refinement.md)
