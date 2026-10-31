---
type: Backlog Item
title: "Rust: 空席照会・予約・会員・認証・レポートの移植先ソース"
description: "各機能の Rust 実装と TargetModel の Verus 写しを作り、Verus で一致を証明し、target-model ベクタを通す。"
tags: [backlog, rust, verus]
id: "9c1b5a33-ee88-4bd7-87f3-05094c95b55b"
state: todo
depends_on: ["ddb4cafe-4bc3-4235-8efa-7f6eb7ff0ea8", "26c57ac3-b6b7-440a-aca5-994943bd7ebd", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Rust: 空席照会・予約・会員・認証・レポートの移植先ソース

> 2026-10-29 に ADR 796c（モデルは Lean、Rust は移植先ソース）と ADR 81ab（両端の追跡）に合わせて範囲を改めた。

## 目的

業務ロジック全体を Rust に移し、SRC-001〜SRC-003 を全機能で満たす。

## 範囲

- `model/` の写し: 照会・予約・会員・認証・レポート・入力検証（Lean の各 `TargetModel` モジュールから生成する）
- 業務機能の実装（状態は引数と戻り値で受け渡す）
- SRC-001, SRC-002, SRC-003, SRC-009

## 対象外

- アダプタ・HTTP（[backlog 4b0e](4b0e-in-memory-adapters-and-seed-data.md), [a89e](a89e-http-contract-adapter.md)）

## 完了条件

- [ ] 全機能の `conformance/target-model/`・`shared/` のベクタが通る
- [ ] SRC-001〜SRC-003 の状況欄が埋まっている
- [ ] TR-T1・TR-T2 が通る（SRC-007・SRC-008）
- [ ] 写しの再生成で差分が無く、Verus の検証が `assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` 無しで通り、`gen-verus --check-contracts` が通る

## 参照

- [refinement.md](../spec/refinement.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/docs/lang/rust/layout.md)
