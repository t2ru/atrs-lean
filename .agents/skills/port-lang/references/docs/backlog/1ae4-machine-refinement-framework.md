---
type: Backlog Item
title: "Machine: 抽象機械と B メソッドのリファインメントの枠組み"
description: "アプリに依存しない Lean ライブラリ Machine（抽象機械、Refines、証明義務 INIT・適用可能性・正しさ、差異の仮定・成分）をスキルの assets/lean/Machine/ に実装する。"
tags: [backlog, lean, refinement, proof]
id: "1ae40815-ac5a-4602-99bc-1d9ad267dd0b"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:20:16+09:00
---

# Machine: 抽象機械と B メソッドのリファインメントの枠組み

> 来歴: ATRS の `docs/backlog` で作り、ATRS の backlog be49（Lean の雛形）の後に行った項目を、スキルのバンドルへ移した。CI の節は ATRS での作業である。

## 目的

原則 2（ATRS の ADR c336）を満たすため、次の 2 つの定理を同じ形で書ける枠組みを用意する。

- `SourceModel` が `Spec` をリファインする定理
- `TargetModel` が `Spec` をリファインする定理

定義は ATRS の ADR 01d4 による。

## 範囲

- `.agents/skills/port-lang/assets/lean/Machine/`（core だけに依存。アプリ固有の型を入れない）
  - `Machine.Machine`: 状態・INV・INIT・操作（PRE、関係 `step`、実行可能な標準の選択 `run`、`run` が `step` に含まれる定理）
  - `Machine.Concrete`: 具体機械。正常終了でない結果（パニック・前提違反・溢れによる誤り・α/β の未定義）を結果として持つ。業務エラーは正常な結果である
  - `Machine.Refines`: 貼り合わせ不変条件 `J`・入力の対応 `αᵢ`・出力の対応 `αₒ` と、証明義務 INIT・入力の全域性・適用可能性・正しさ
  - `Machine.Machine.restrict`・`restrictState`: 前提型の差異の述語（抽象側）で PRE を強める
  - `Machine.Concrete.restrict`: 前提型の差異の述語（具体側だけにある入力・環境）で具体機械を制限する
  - 推移性など、基本の補題
- `assets/lean/MachineTest/`: 小さな例。例として、非決定的な抽象機械を決定的な具体機械がリファインする場合と、具体側の非決定性のすべての分岐を模倣する場合を扱う
- ルートの `lakefile.lean` と `lean/` から `require` する
- スキルの [SKILL.md](../../../SKILL.md) の assets の表の「未整備」を外す

## 対象外

- ATRS 固有の機械（各機能の backlog 項目で扱う）
- Mathlib（ATRS の ADR 659f）

## 完了条件

- [x] `assets/lean/` で `lake build` が通り、`MachineTest` の例が `sorry`・`native_decide`・`bv_decide` 無しで証明される
- [x] 具体側が抽象側より大きな非決定性を持つ例で、`Refines` が成り立たないこと（反例）を示した
- [x] `#print axioms` で、`propext`・`Quot.sound`・`Classical.choice` 以外の公理が無い

## 結果

- `assets/lean/Machine/`: `Basic`（`Machine.Machine`・`Sound`・`restrict`・`restrictState`・`pure`）、`Concrete`（`Machine.Concrete`・`ofFun`・`pure`・`restrict`・`Machine.toConcrete`）、`Refines`（`Glue`・`Refines`・制限の補題・`refl`・`trans`・`of_pure`）。
  - `ADR 01d4` の名前 `Machine.restrict`・`Machine.restrictConcrete` は、dot 記法（`A.restrict P`・`C.restrict P`）で書けるように `Machine.Machine.restrict`・`Machine.Concrete.restrict` とした。ADR の記述も直した。
  - 具体側の定義域 `Dom` は入力だけの述語とし、具体側だけにある環境は入力の成分として表す（推移性で中間の状態を必要としないため）。
  - α/β の未定義は、`J`・`αo` に像が無いこととして正しさの義務が排除する。
- `assets/lean/MachineTest/`: 非決定的な抽象機械を決定的な具体機械がリファインする例、具体側の両方の分岐を模倣する例、反例（順序不定の具体側は定順の抽象側をリファインしない）と観測型の成分で成り立つ例、具体側の入力の制限の例、状態を持つカウンタ（溢れの前提型の差異の模擬、`refl`・`trans`）。公理は `#guard_msgs in #print axioms` で固定した。
- CI: `tools/ci/lean.sh` が `assets/lean/` で `lake build` するようにした（`LangSemanticsTest` も CI で走るようになった）。`axiom-check`・`trace-dump` の対象に `Machine` を加えた。`check_lean.py` は `MachineTest` を `Tests` の層として扱う。

## 参照

- ATRS の ADR 01d4, ATRS の ADR 0bd3
- [port-lang/architecture.md](../architecture.md#リファインメントb-メソッド)
