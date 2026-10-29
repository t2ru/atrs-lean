---
type: Guideline
title: "テスト規約"
description: "適合テストベクタ・性質テスト・証明・Java オラクルによる検証規約。"
tags: [rules, testing]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# テスト規約

検証は 3 層で行う。

| 層 | 目的 | 手段 |
| --- | --- | --- |
| 適合テストベクタ | 各モデルとソースの振る舞いの一致を言語中立に確認（Java ⇔ `SourceModel`、`TargetModel` ⇔ Rust、`Spec` 自身） | `conformance/` の JSON（[ADR 0013](../decision/0013-conformance-test-vectors.md)） |
| 有界検査・性質テスト | ベクタでは覆えない広い入力域での性質確認 | Rust の Kani（[rules/rust.md](rust.md)）、Lean の実行テスト（乱数は固定シード） |
| 証明 | [Spec] の不変条件と [Source]→[Spec]（`Abstraction`）、[Spec]→[Target]（`Refinement`）の関係を全入力について保証。Rust の実行コード ＝ `TargetModel` の Verus 写し | Lean の定理（[abstraction.md](../spec/abstraction.md), [refinement.md](../spec/refinement.md)）、Rust の Verus |

## 適合テストベクタ

- 形式は [spec/conformance.md](../spec/conformance.md) に従う。
- ベクタは **モデル別**（`spec/`, `source-model/`）に置く。両モデルで同じ期待値になるベクタは `shared/` に置いてよい。
- 仕様の各節の「例」は必ずベクタ化する。境界値（0、上限、日付の境界、空列、最大人数）を含める。
- `spec/`・`shared/` の期待値は Lean `Spec` を実行して生成する（`source: "lean-spec"`。[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。`source-model/` の期待値は Lean `SourceModel` の実行（`lean-source-model`）または Java オラクル（`java-oracle`）で得る。
- 手計算の例（`hand-calculated`）は、Lean `Spec` 自身のテストとして使う。生成値と手計算が食い違ったら、どちらが誤りかを調べてから直す。
- 「今日」は必ずベクタに明示する（`today`）。実行時の日付に依存するベクタを作ってはならない。
- 生成したベクタはコミットする。`Spec` の変更でベクタが変わった場合、その差分を **必ずレビュー** する（意図しない振る舞いの変化を検出するため）。Rust の実装の出力からベクタを作ってはならない。

## 性質テスト

- 乱数生成器のシードを固定し、失敗時に再現できるようにする。
- 証明済みの性質を性質テストで重複確認する必要はない。証明が未完の性質に優先して使う。

## Java オラクル

- [backlog 0013](../backlog/0013-java-oracle-harness.md) のハーネスで、原典の Java コードを直接呼び出して [Source] ベクタの期待値を採取できる。
- [Source] ベクタの `source` が `java-oracle` のものは、Lean の `SourceModel` が一致しなければ **`SourceModel` 側の不具合** とみなす。

## 実行

- Lean: `lake build` と `lake test`（[backlog 0001](../backlog/0001-lean-project-scaffold.md)）。
- Rust: Verus の検証、`cargo kani`、`cargo test`（[backlog 0018](../backlog/0018-rust-project-scaffold.md)）。
- ベクタを追加・変更した変更は、Lean の `Spec`・`SourceModel` が対応する全ベクタを通る状態で取り込む。
- `conformance/target-model/` の期待値は Lean `TargetModel` を実行して生成する（`source: "lean-target-model"`）。
- Rust は `conformance/target-model/` と `conformance/shared/` の全ベクタを通さなければならない。
- 移植元の版上げ時は、`source-model/` の全入力を新旧 2 版の Java で実行する差分オラクルを使う（[upstream-upgrade.md](upstream-upgrade.md)）。
