---
type: Backlog Item
title: "Rust: HTTP 契約アダプタ"
description: "http-contract.md の画面遷移と REST API を Rust の target_model::adapter で実装し、REF-006 を結合テストで検証する。"
tags: [backlog, rust, target-model, http]
id: "0014"
state: todo
depends_on: ["0011"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust: HTTP 契約アダプタ

> 2026-10-29 に Lean の TargetModel 向けから Rust 向けに範囲を変更した（[ADR 0020](../decision/0020-rust-as-target-language.md)）。

## 目的

外形的な互換性（URL・ステータス・JSON）を確認できる移植先を作る。

## 範囲

- HTTP フレームワークの選定（ADR を作る）
- `Spec.Http`（Lean。契約の抽象表現）の形式化と、その Verus 写し
- `target_model::adapter::http`（リクエスト → `core` → 応答）
- トランザクショントークン・CSRF の実装（[http-contract.md](../spec/http-contract.md#共通) の規範節）
- HTTP レベルの適合ベクタ（`conformance/*/http/`）と結合テスト

## 対象外

- HTML の描画

## 完了条件

- [ ] [http-contract.md](../spec/http-contract.md) の全リクエストにベクタがある
- [ ] REF-006 を満たす

## 参照

- [http-contract.md](../spec/http-contract.md)
- [ADR 0012](../decision/0012-http-contract-specification.md)
- [rules/rust.md](../rules/rust.md)
