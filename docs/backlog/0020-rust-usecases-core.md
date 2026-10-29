---
type: Backlog Item
title: "Rust: 空席照会・予約・会員・認証・レポートの移植先ソース"
description: "各機能の Rust 実装と TargetModel の Verus 写しを作り、Verus で一致を証明し、target-model ベクタを通す。"
tags: [backlog, rust, verus]
id: "0020"
state: todo
depends_on: ["0019", "0023"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust: 空席照会・予約・会員・認証・レポートの移植先ソース

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

業務ロジック全体を Rust に移し、SRC-001〜SRC-003 を全機能で満たす。

## 範囲

- `model/` の写し: 照会・予約・会員・認証・レポート・入力検証（Lean の各 `TargetModel` モジュールに対応）
- 業務機能の実装（状態は引数と戻り値で受け渡す）
- SRC-001, SRC-002, SRC-003

## 対象外

- アダプタ・HTTP（[backlog 0011](0011-in-memory-adapters-and-seed-data.md), [0014](0014-http-contract-adapter.md)）

## 完了条件

- [ ] 全機能の `conformance/target-model/`・`shared/` のベクタが通る
- [ ] SRC-001〜SRC-003 の状況欄が埋まっている
- [ ] TR-T1・TR-T2 が通る

## 参照

- [refinement.md](../spec/refinement.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)
