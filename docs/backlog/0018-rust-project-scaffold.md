---
type: Backlog Item
title: "Rust プロジェクトの雛形、Verus と Kani の併用確認、CI"
description: "rust/ に単一クレートの雛形を作り、Verus と Kani を同じコードに適用できるかを最初に確認し、追跡タグを含む CI を整える。"
tags: [backlog, rust, verus, kani, ci]
id: "0018"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust プロジェクトの雛形、Verus と Kani の併用確認、CI

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

Rust（移植先ソース）の作業の土台を作り、Verus と Kani の併用という技術的な不確実性を早期に解消する。

## 範囲

- `rust/rust-toolchain.toml`（Verus のリリースが要求する版）、`Cargo.toml`（パッケージ `atrs`）、`trace/target.json`
- 業務機能・`adapter/`・`model/`・`proof/`・`kani/`・`tests/` の空の構成（[rules/rust.md](../rules/rust.md#構成)）
- **併用確認**: `verus!` 内の小さな関数（例: `floor_div`）を Verus で検証し、同じ関数に Kani のハーネスを当てて実行できるか確かめる
- `model/` の `/// trace: models … @hash` タグの書式を試す
- CI: Verus の検証、`cargo kani`、`cargo test`、`cargo fmt --check`、`cargo clippy -- -D warnings`
- Verus・Kani の版を [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md) の More Information に追記

## 対象外

- 業務ロジックの実装

## 完了条件

- [ ] 併用確認の結果を ADR 0022 に追記した（併用できない場合は Kani の対象を `verus!` の外に限定し、[rules/rust.md](../rules/rust.md) を改訂した）
- [ ] CI の全ジョブが成功する
- [ ] AGENTS.md の「現在の状態」を更新した

## 参照

- [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)
- [rules/rust.md](../rules/rust.md)
