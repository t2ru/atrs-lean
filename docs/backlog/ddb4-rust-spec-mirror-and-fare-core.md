---
type: Backlog Item
title: "Rust: 運賃計算の移植先ソースと TargetModel の写し"
description: "Lean TargetModel.Fare を Verus の model に写し、Rust の運賃計算を ensures 付きで実装・証明し、target-model ベクタを通す。"
tags: [backlog, rust, verus, fare]
id: "ddb4cafe-4bc3-4235-8efa-7f6eb7ff0ea8"
state: todo
depends_on: ["fb50dcb4-2c24-46aa-ad02-cee5924cd095", "eff6bfce-0ef0-49a1-8c6e-e2b7235fd113", "d77caf9a-257d-4bcc-9be8-f34b6c03f2b6", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Rust: 運賃計算の移植先ソースと TargetModel の写し

> 2026-10-29 に ADR 796c（モデルは Lean、Rust は移植先ソース）と ADR 81ab（両端の追跡）に合わせて範囲を改めた。

## 目的

両端の追跡と確認（`TargetModel` ⇔ Rust）を、運賃計算で端から端まで通す最初の例にする。

## 範囲

- `rust/src/model/fare.rs`（`TargetModel.Fare` から `lake exe gen-verus` で生成した Verus の写し。手で編集しない）
- `rust/src/fare.rs`（`u64` 等、`requires` で値域、`ensures` で `model` と一致）
- `rust/tests/`: ベクタ実行器（JSON 読み込みと操作名の割当）
- SRC-001・SRC-002・SRC-003・SRC-009（運賃分）

## 対象外

- 空席照会以降の機能

## 完了条件

- [ ] 写しの再生成で差分が無い（SRC-002）
- [ ] Verus の検証が `assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` 無しで通り、`gen-verus --check-contracts` が通る
- [ ] `conformance/target-model/fare/`・`shared/fare/` の全ベクタが通る
- [ ] TR-T1・TR-T2・TR-X が通る（SRC-007・SRC-008）
- [ ] [refinement.md](../spec/refinement.md) の状況欄を更新した

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [refinement.md](../spec/refinement.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/docs/rust/layout.md)
