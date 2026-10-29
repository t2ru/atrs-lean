---
type: Backlog Item
title: "Rust プロジェクトの雛形、Verus と Kani の併用確認、CI"
description: "rust/ に単一クレートの雛形を作り、Verus と Kani を同じコードに適用できるかを最初に確認し、CI を整える。"
tags: [backlog, rust, verus, kani, ci]
id: "0018"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust プロジェクトの雛形、Verus と Kani の併用確認、CI

## 目的

Rust 側の全作業の土台を作り、[ADR 0020](../decision/0020-rust-as-target-language.md) の技術的な不確実性（Verus と Kani の併用）を早期に解消する。

## 範囲

- `rust/rust-toolchain.toml`（Verus のリリースが要求する版）、`Cargo.toml`（パッケージ `atrs`）
- `spec`, `target_model::{core, adapter}`, `refinement::{lemmas, kani, conformance}` の空モジュール（[rules/rust.md](../rules/rust.md#構成)）
- **併用確認**: `verus!` 内の小さな関数（例: `floor_div`）を Verus で検証し、同じ関数に Kani のハーネスを当てて実行できるか確かめる
- CI: Verus の検証、`cargo kani`、`cargo test`、`cargo fmt --check`、`cargo clippy -- -D warnings`
- Verus・Kani の版を [ADR 0020](../decision/0020-rust-as-target-language.md) の More Information に追記

## 対象外

- 業務ロジックの実装

## 完了条件

- [ ] 併用確認の結果を ADR 0020 に追記した（併用できない場合は Kani の対象を `verus!` の外に限定し、[rules/rust.md](../rules/rust.md) を改訂した）
- [ ] CI の全ジョブが成功する
- [ ] AGENTS.md の「現在の状態」を更新した

## 参照

- [ADR 0020](../decision/0020-rust-as-target-language.md)
- [rules/rust.md](../rules/rust.md)
