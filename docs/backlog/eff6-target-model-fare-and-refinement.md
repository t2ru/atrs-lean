---
type: Backlog Item
title: "TargetModel と Refinement: 運賃計算"
description: "Lean に TargetModel.Fare（Rust の意味論で書く運賃計算）を書き、Refinement で Spec.Fare との一致を証明し、target-model ベクタを生成する。"
tags: [backlog, lean, target-model, refinement, fare]
id: "eff6bfce-0ef0-49a1-8c6e-e2b7235fd113"
state: todo
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "a8ef4e5b-1870-4669-9398-1916a439a6f7", "a936801c-476d-4b16-baed-ca3bab07cee3", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# TargetModel と Refinement: 運賃計算

## 目的

移植先側の最初の機能で、`Spec` → `TargetModel` の証明と、`TargetModel` からのベクタ生成を通す。

## 範囲

- `TargetModel.Fare`（`LangSemantics.Rust.U64` で書く。値域は `Spec` の PRE として受け取る。`@[target]` は Rust 実装後に付ける。写しの生成器の部分集合で書く）
- `Refinement.Fare`: R 課題 REF-004（`Machine.Refines` の形）と L 課題 REF-003（PRE の下でオーバーフローしない）
- `conformance/target-model/fare/` を `TargetModel` から生成

## 対象外

- Rust の実装（[backlog ddb4](ddb4-rust-spec-mirror-and-fare-core.md)）

## 完了条件

- [ ] REF-003・REF-004（運賃分）の定理が `sorry` 無しで存在する
- [ ] `target-model/fare/` のベクタを生成し、`TargetModel` 自身が通る

## 参照

- [refinement.md](../spec/refinement.md)
- [fare-calculation.md](../spec/fare-calculation.md)
