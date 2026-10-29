---
type: Backlog Item
title: "Rust: 運賃計算の移植先ソースと TargetModel の写し"
description: "Lean TargetModel.Fare を Verus の model に写し、Rust の運賃計算を ensures 付きで実装・証明し、target-model ベクタを通す。"
tags: [backlog, rust, verus, fare]
id: "0019"
state: todo
depends_on: ["0018", "0022"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust: 運賃計算の移植先ソースと TargetModel の写し

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

両端の追跡と確認（`TargetModel` ⇔ Rust）を、運賃計算で端から端まで通す最初の例にする。

## 範囲

- `rust/src/model/fare.rs`（`TargetModel.Fare` の Verus 写し。`/// trace: models … @hash`）
- `rust/src/fare.rs`（`u64` 等、`requires` で値域、`ensures` で `model` と一致）
- `rust/tests/`: ベクタ実行器（JSON 読み込みと操作名の割当）
- SRC-001・SRC-002（運賃分）

## 対象外

- 空席照会以降の機能

## 完了条件

- [ ] Verus の検証が `assume`・`admit` 無しで通る
- [ ] `conformance/target-model/fare/`・`shared/fare/` の全ベクタが通る
- [ ] TR-T1・TR-T2・TR-X が通る
- [ ] [refinement.md](../spec/refinement.md) の状況欄を更新した

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [refinement.md](../spec/refinement.md)
- [rules/rust.md](../rules/rust.md)
