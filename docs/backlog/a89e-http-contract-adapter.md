---
type: Backlog Item
title: "Rust: HTTP 契約アダプタ"
description: "http-contract.md の画面遷移と REST API を Rust で実装し、SRC-006 を結合テストで確認する。"
tags: [backlog, rust, http]
id: "a89ec8f0-4d15-46a6-86fa-a640e4df0b44"
state: todo
depends_on: ["4b0e2070-e086-4966-95f8-9e366f4324a0", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:24:54+09:00
---

# Rust: HTTP 契約アダプタ

> 2026-10-29 に ADR 796c（モデルは Lean、Rust は移植先ソース）と ADR 81ab（両端の追跡）に合わせて範囲を改めた。

## 目的

外形的な互換性（URL・ステータス・JSON）を確認できる移植先ソースを作る。

## 範囲

- HTTP フレームワークの選定（ADR を作る。依存の版は `trace/target.json`）
- `Spec.Http`（契約の抽象表現）と `TargetModel.Http`、R 課題 REF-007（`Refinement` の証明）
- `SourceModel.Http` と R 課題 ABS-045、W 課題 ABS-117・ABS-119・ABS-120（D-017・D-019・D-020）。ABS-031・ABS-107（D-007）・ABS-126（D-026）、L 課題 ABS-047
- `rust/src/adapter/http`（リクエスト → 業務機能 → 応答）
- トランザクショントークン・CSRF（[http-contract.md](../spec/http-contract.md#共通) の規範節）
- HTTP レベルの適合ベクタ（`conformance/*/http/`）と結合テスト
- 入口の環境の前提: 入力の値域（[domain-model.md](../spec/domain-model.md#値域)。搭乗者数・予約フライト数・年齢など）の述語を入口の機械の入力の型で書き、`Spec.masterConfigOk` と組み合わせて `@[env_pre]` を付ける（[ADR cd33](../decision/cd33-spec-nondet-types-and-env-pre.md)）

## 対象外

- HTML の描画

## 完了条件

- [ ] [http-contract.md](../spec/http-contract.md) の全リクエストにベクタがある
- [ ] SRC-006・SRC-007・SRC-008 を満たす
- [ ] HTTP の `source-model/` ベクタが、HTTP レベルの Java オラクルと一致する
- [ ] Kani のハーネスの境界を [assurance.md](../spec/assurance.md) の付録に記入した
- [ ] REF-007・ABS-031・ABS-045・ABS-047 と、関係する W 課題を証明し、TR-D が通る
- [ ] HTTP の規範節で、ベクタで確かめきれない部分を [assurance.md](../spec/assurance.md) に記載した

## 参照

- [http-contract.md](../spec/http-contract.md)
- [ADR 1b00](../decision/1b00-http-contract-specification.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/docs/lang/rust/layout.md)
