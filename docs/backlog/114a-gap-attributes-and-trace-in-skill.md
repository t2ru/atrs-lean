---
type: Backlog Item
title: "追跡属性をスキルへ移し、ギャップを Lean の属性で表す"
description: "lean/Trace をスキル port-lang の assets/lean/Trace に移す。Spec と SourceModel のギャップ（既知差異・PRE の外・未確定）を @[gap_entry]（型 Trace.Gap）で登録し、箇所の印 @[gap] を付け、文書の表を生成し、検査を JSON から行う。"
tags: [backlog, lean, tooling, traceability]
id: "114a8bdd-9aac-40c9-a364-048a59fa6224"
state: done
depends_on: ["ffdc480d-eaf2-42a0-9818-0b128e9403d4", "ae0448b1-af43-4d95-af6f-cfec8c58768c"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:30:00+09:00
---

# 追跡属性をスキルへ移し、ギャップを Lean の属性で表す

## 目的

追跡属性の仕組みはアプリに依存しないので、スキルに置く（[ADR 7fe4](../../.agents/skills/port-lang/references/docs/decision/7fe4-move-trace-attributes-to-skill.md)）。
あわせて、[Spec] とモデルのギャップを Lean の属性で表し、機械で扱えるようにする（[ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)）。

## 範囲

- スキル port-lang の `assets/lean/`
  - `Trace/`（`lean/Trace` から移す）
  - `Trace/Gap.lean`（`Trace.Gap`・`@[gap_entry]`）、`Trace.Attr` の `@[gap]`
  - `trace-dump`・`obligation-check` の `gaps` と GK
  - `TraceTest/`（`lean/Tests` から移したフィクスチャと `GapErrors`）、`lake exe trace-test`
- ATRS の `lean/`
  - `Abstraction/Gap.lean`（D-001〜D-030 の登録）、`Refinement/Gap.lean`（空）
  - 運賃計算・マスタの `Spec`・`SourceModel` の定義の `@[gap]`
- `tools/trace`
  - 表の生成（`gaps.rs`）
  - TR-D を `gaps` から判定し、TR-K を足す
  - `impact` の見直すギャップ
  - manifest の `gap`・`gap_entry` のリンク
- `tools/ci/check_obligations.py` とその fixtures、`tools/ci/check_lean.py`、`tools/ci/lean.sh`
- 文書
  - ADR 7fe4・cc24
  - [abstraction.md](../spec/abstraction.md)・[refinement.md](../spec/refinement.md) の生成区画
  - [assurance.md](../spec/assurance.md)
  - スキルの SKILL.md・architecture・traceability・trace-attributes・spec-documents・lean/rules・workflow
  - [AGENTS.md](../../AGENTS.md)・[atrs-porting.md](../rules/atrs-porting.md)

## 対象外

- 未実装の機能（入力検証・HTTP・予約など）のギャップの箇所の印。各機能の backlog で付ける（TR-K の段階導入で警告になる）
- `LangSemantics` への `@[source "lang:…"]` の付与

## 完了条件

- [x] スキルの `assets/lean` で `lake build` と `lake exe trace-test` が通る
- [x] `lean/` の `lake build`・`lake test`・`axiom-check`・`obligation-check` が通り、移動と印の前後で全定義の `merkle` が一致する
- [x] 生成した表が、移行前の表と行ごとに一致する（新しく採番した D-028〜D-030 と、D-006 の区切りの統一を除く）
- [x] `@[gap_entry]` の値の誤り（`TraceTest/GapErrors`）と GK の違反（`TraceTest/ObligationFixture`）を検出する
- [x] TR-K の各規則と表の生成を `tools/trace` の自己テストで確かめた
- [x] 完了した backlog（25f7）に属するギャップ（D-003・D-004・D-015・D-027・D-029・D-030）の印がそろい、TR-K が誤りを出さない
- [x] `tools/ci/lean.sh` が全段通る（JVM・PostgreSQL の突き合わせを含む）

## 参照

- [ADR 7fe4](../../.agents/skills/port-lang/references/docs/decision/7fe4-move-trace-attributes-to-skill.md)
- [ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)
- [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)
- [backlog ffdc](ffdc-trace-tooling.md)
