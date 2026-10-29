---
type: Backlog Item
title: "TargetModel と Refinement: 運賃計算"
description: "Lean に TargetModel.Fare（Rust の意味論で書く運賃計算）を書き、Refinement で Spec.Fare との一致を証明し、target-model ベクタを生成する。"
tags: [backlog, lean, target-model, refinement, fare]
id: "0022"
state: todo
depends_on: ["0004", "0012", "0021"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# TargetModel と Refinement: 運賃計算

## 目的

移植先側の最初の機能で、`Spec` → `TargetModel` の証明と、`TargetModel` からのベクタ生成を通す。

## 範囲

- `TargetModel.Fare`（`LangSemantics.Rust.U64` で、`requires` 相当の値域を前提にする。`@[target]` は Rust 実装後に付ける）
- `Refinement.Fare`: REF-004（運賃の一致）と REF-003（値域内でオーバーフローしない）
- `conformance/target-model/fare/` を `TargetModel` から生成

## 対象外

- Rust の実装（[backlog 0019](0019-rust-spec-mirror-and-fare-core.md)）

## 完了条件

- [ ] REF-003・REF-004（運賃分）の定理が `sorry` 無しで存在する
- [ ] `target-model/fare/` のベクタを生成し、`TargetModel` 自身が通る

## 参照

- [refinement.md](../spec/refinement.md)
- [fare-calculation.md](../spec/fare-calculation.md)
