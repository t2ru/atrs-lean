---
type: Backlog Item
title: "Rust: 空席照会・予約・会員・認証・レポートのコア"
description: "各機能の純粋なコアと状態遷移を target_model::core に実装し、Verus で Spec の写しとの一致と空席の不変条件を証明する。"
tags: [backlog, rust, verus, target-model, refinement]
id: "0020"
state: todo
depends_on: ["0006", "0007", "0008", "0009", "0010", "0019"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust: 空席照会・予約・会員・認証・レポートのコア

## 目的

業務ロジック全体を Rust に移し、REF-002・REF-004・REF-007 を充足する。

## 範囲

- `spec` の写し: 照会・予約・会員・認証・レポート・入力検証（Lean の各 `Spec` モジュールに対応）
- `target_model::core`: 各機能（状態は引数と戻り値で受け渡す）
- REF-002（予約確定前後の `vacantNum ≥ 0`、失敗時の状態不変）、REF-004、REF-007 を Verus で
- 各機能の適合テスト（REF-001）

## 対象外

- アダプタ・HTTP（[backlog 0011](0011-in-memory-adapters-and-seed-data.md), [0014](0014-http-contract-adapter.md)）

## 完了条件

- [ ] 全機能の `conformance/spec/`・`shared/` のベクタが通る
- [ ] REF-002, REF-004, REF-007 の状況欄が証明へのリンクで埋まっている

## 参照

- [refinement.md](../spec/refinement.md)
- [rules/rust.md](../rules/rust.md)
