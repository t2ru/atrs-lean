---
type: Backlog Item
title: "Rust: HTTP 契約アダプタ"
description: "http-contract.md の画面遷移と REST API を Rust で実装し、SRC-006 を結合テストで確認する。"
tags: [backlog, rust, http]
id: "0014"
state: todo
depends_on: ["0011"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust: HTTP 契約アダプタ

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

外形的な互換性（URL・ステータス・JSON）を確認できる移植先ソースを作る。

## 範囲

- HTTP フレームワークの選定（ADR を作る。依存の版は `trace/target.json`）
- `Spec.Http`（契約の抽象表現）と `TargetModel.Http`、`Refinement` の証明
- `rust/src/adapter/http`（リクエスト → 業務機能 → 応答）
- トランザクショントークン・CSRF（[http-contract.md](../spec/http-contract.md#共通) の規範節）
- HTTP レベルの適合ベクタ（`conformance/*/http/`）と結合テスト

## 対象外

- HTML の描画

## 完了条件

- [ ] [http-contract.md](../spec/http-contract.md) の全リクエストにベクタがある
- [ ] SRC-006 を満たす

## 参照

- [http-contract.md](../spec/http-contract.md)
- [ADR 0012](../decision/0012-http-contract-specification.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)
