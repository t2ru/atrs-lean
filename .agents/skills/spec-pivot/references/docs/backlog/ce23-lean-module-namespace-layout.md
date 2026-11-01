---
type: Backlog Item
title: "Lean の宣言をモジュール名の下に置く規則と検査"
description: "宣言の完全名をモジュール名の下に限る規則（NS-1）と証明課題の配置（TR-L）を定め、検査の道具 layout-check・TR-L・改名の道具 rename.py を作り、スキルの assets の宣言を書き換える。"
tags: [backlog, lean, namespace, skill]
id: "ce23298a-ee5e-4458-9b32-0037b17a7c02"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T22:40:00+09:00
---

# Lean の宣言をモジュール名の下に置く規則と検査

## 目的

名前から定義の場所が分かり、ファイルのパスで層を決める道具と名前で層を決める道具が同じ答えを出すようにする。機能の証明課題を補題から分けて読めるようにする（[ADR 1a30](../decision/1a30-lean-module-namespace-layout.md)）。

## 範囲

- 規則: [lean/rules.md](../lang/lean/rules.md#モジュールと名前空間) の NS-1 と例外 E1〜E4、[証明課題の配置](../lang/lean/rules.md#証明課題の配置)。[architecture.md](../spec/architecture.md#層) から参照する
- 道具: `Trace.Layout`（`layout-check` の本体）、属性 `@[ns_exception]`、assets の入口 `Test/Trace/LayoutCheck.lean`、フィクスチャ `Test/Trace/LayoutFixture.lean` と `trace-test` の検査
- `trace check` の TR-L1・TR-L2（[traceability.md](../spec/traceability.md#検査)）と `cargo test` の違反例
- 改名の道具 `scripts/lean/rename.py`（`--self-test`・`check`）。`scripts/README.md`
- assets の書き換え: `LangSemantics`・`Machine`・`Trace`・`ConformanceKit`・`Test` の全宣言をモジュール名の下に置く（型名のモジュール `JDouble`・`JLocalDate`・`Machine.Machine`・`Machine.Glue`・`Trace.Gap`、`Machine.Adequacy` の型ごとの分割、`Machine.Adequate`、`Machine.*.Sum` と `Machine.Sum.sumPred`、`LangSemantics.Java.DoubleOps`、`Machine.Concrete.ofMachine`）

## 対象外

- 適用先のモデルの書き換え（適用先の作業項目で行う。ATRS では backlog 9ed8）
- C 課題と L 課題の機械的な区別（規約にとどめる）

## 完了条件

- [x] assets で `lake build`・`lake exe trace-test`・`lake exe layout-check`（違反 0）が通る
- [x] `cargo test --release`（`scripts/trace`）が TR-L の違反例を検出する
- [x] `rename.py --self-test` と `check_lean.py --self-test` が通る
- [x] このバンドルが `okf_check.py` と `ids.py check` を違反なしで通る

## 参照

- [ADR 1a30](../decision/1a30-lean-module-namespace-layout.md)、[lean/rules.md](../lang/lean/rules.md)、[traceability.md](../spec/traceability.md#検査)
