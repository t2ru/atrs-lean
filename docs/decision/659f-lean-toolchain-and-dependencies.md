---
type: Architecture Decision Record
title: "Lean 4 を lean-toolchain で固定し、依存は Batteries のみとする（Mathlib 不使用）"
description: "Lean 4 + Lake を使い、依存ライブラリを Batteries に限定して Mathlib を使わない。"
tags: [adr, lean, toolchain]
id: "659f8739-1579-4d0b-8640-77ef36c4b235"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T07:30:00+09:00
---

# Lean 4 を lean-toolchain で固定し、依存は Batteries のみとする（Mathlib 不使用）

## Context and Problem Statement

Lean プロジェクト（正規仕様 `Spec` の形式化と抽象化証明。[ADR 61bc](61bc-lean-spec-as-normative-source.md)）のツールチェーンと依存ライブラリを決める。
Mathlib は証明を楽にする一方、ビルドが重く、他言語に写しにくい抽象（代数構造・実数など）を持ち込みやすい。

## Decision Drivers

* ビルドが軽く、CI と新規参加者の環境構築が容易であること
* 実装に使う型が他言語に写しやすい素朴なものに留まること
* 必要な証明（整数の不等式・ビットベクタ・有限の場合分け）が書けること

## Considered Options

* core + Batteries のみ
* Mathlib を使う
* core のみ

## Decision Outcome

Chosen option: "core + Batteries のみ", because 必要な証明は `omega`・`decide`・`simp`・`bv_decide` で賄え、Batteries の追加データ構造・補題があれば十分なため。

* Lean のバージョンは `lean/lean-toolchain` で固定する。版は着手時点の最新安定版とし、[backlog be49](../backlog/be49-lean-project-scaffold.md) で決めて本 ADR の More Information に追記する。
* ビルドは Lake。テストは `lake test`（テストドライバ `Tests`）。トップレベル名前空間は [ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md) に従う。
* JSON の読み書きは core の `Lean.Data.Json` を使う。
* 依存を追加するときは新しい ADR を作る。

### Consequences

* Good, because ビルドが速く、依存の更新負担が小さい
* Good, because 他言語に写しにくい抽象が入り込みにくい
* Bad, because 有理数・実数の補題を自前で用意する必要がある（JDouble の丸めの証明で必要になる分のみ）

### Confirmation

* `lakefile.lean` の `require` が Batteries のみであることをレビューで確認する。

## Pros and Cons of the Options

### core + Batteries

* Good, because 軽量で十分
* Bad, because 一部の補題を自作する

### Mathlib

* Good, because 補題が豊富
* Bad, because ビルドが重く、抽象が仕様に漏れやすい

### core のみ

* Good, because 最も軽量
* Bad, because リスト・配列の基本補題や便利なデータ構造が不足する

## More Information

* [port-lang/lean/rules.md](../../.agents/skills/port-lang/references/docs/lang/lean/rules.md)
* （補足 2026-10-30）[backlog be49](../backlog/be49-lean-project-scaffold.md) で採った版: Lean `leanprover/lean4:v4.35.0`（着手時点の最新安定版）、Batteries `v4.35.0`（commit `66e469188fe07963e5cf666c7d4433f45b8131c5`）。`lean/`・ルートのワークスペース・スキルの `assets/lean` の `lean-toolchain` を同じ版にそろえる。

* （補足 2026-10-30）[ADR c336](c336-foundational-principles.md) により、`bv_decide` と `native_decide` は、証明（`Spec`・`Abstraction`・`Refinement` と、それらが依存する補題）で使ってはならない。どちらも公理 `Lean.ofReduceBool` に依存し、コンパイラを信頼の基盤に加えるからである。`Tests` での確認には使ってよい。ビットベクタの性質は、`decide`・`omega`・`simp` で示す。
