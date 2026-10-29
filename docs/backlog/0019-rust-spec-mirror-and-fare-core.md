---
type: Backlog Item
title: "Rust: Spec の Verus 写しと運賃計算コア"
description: "Lean Spec.Prim・Spec.Fare を Verus の spec に写し、target_model::core::fare を ensures 付きで実装・証明し、適合テストを通す。"
tags: [backlog, rust, verus, fare, refinement]
id: "0019"
state: todo
depends_on: ["0004", "0012", "0018"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust: Spec の Verus 写しと運賃計算コア

## 目的

信頼の連鎖（Lean `Spec` → ベクタ → Rust → Verus 写し）を、運賃計算で端から端まで通す最初の例にする。

## 範囲

- `spec::prim`（`floor_div`, `ceil_div`, `ceil_to`）、`spec::fare`（`basic_fare`, `fare`, `total_fare`）。各定義に Lean の完全名を注記
- `target_model::core::fare`（`u64` 等の固定長整数、`requires` で値域、`ensures` で `spec` と一致）
- `refinement::conformance`: ベクタ実行器（JSON 読み込みと操作名の割当）
- REF-004（運賃分）を Verus で、REF-001（運賃分）を適合テストで充足

## 対象外

- 空席照会以降の機能

## 完了条件

- [ ] Verus の検証が `assume`・`admit` 無しで通る
- [ ] `conformance/spec/fare/`・`shared/fare/` の全ベクタが通る
- [ ] 値域の上限でオーバーフローしないことが Verus で示されている
- [ ] [refinement.md](../spec/refinement.md) の状況欄を更新した

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [refinement.md](../spec/refinement.md)
- [rules/rust.md](../rules/rust.md)
