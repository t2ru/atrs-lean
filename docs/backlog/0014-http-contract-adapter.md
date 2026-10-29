---
type: Backlog Item
title: "Rust: HTTP 契約アダプタ"
description: "http-contract.md の画面遷移と REST API を Rust で実装し、SRC-006 を結合テストで確認する。"
tags: [backlog, rust, http]
id: "0014"
state: todo
depends_on: ["0011", "0013", "0005", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Rust: HTTP 契約アダプタ

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

外形的な互換性（URL・ステータス・JSON）を確認できる移植先ソースを作る。

## 範囲

- HTTP フレームワークの選定（ADR を作る。依存の版は `trace/target.json`）
- `Spec.Http`（契約の抽象表現）と `TargetModel.Http`、R 課題 REF-007（`Refinement` の証明）
- `SourceModel.Http` と R 課題 ABS-045、W 課題 ABS-117・ABS-119・ABS-120（D-017・D-019・D-020）。ABS-031・ABS-107（D-007）・ABS-126（D-026）、L 課題 ABS-047
- `rust/src/adapter/http`（リクエスト → 業務機能 → 応答）
- トランザクショントークン・CSRF（[http-contract.md](../spec/http-contract.md#共通) の規範節）
- HTTP レベルの適合ベクタ（`conformance/*/http/`）と結合テスト

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
- [ADR 0012](../decision/0012-http-contract-specification.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)
