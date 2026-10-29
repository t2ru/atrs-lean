---
type: Architecture Decision Record
title: "入力検証エラーの並びは Spec でだけ定め、Source では順序不定の多重集合とする"
description: "Bean Validation が順序を保証しないことを SourceModel に写し、Spec では単項目・相関・グローバルの順に並べる。抽象化では順序を無視して比較する。"
tags: [adr, validation]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
sources:
  - id: hv-context
    resource: https://github.com/hibernate/hibernate-validator/blob/9.1.0.Final/engine/src/main/java/org/hibernate/validator/internal/engine/validationcontext/AbstractValidationContext.java
    title: AbstractValidationContext.java (Hibernate Validator 9.1.0.Final)
---

# 入力検証エラーの並びは Spec でだけ定め、Source では順序不定の多重集合とする

## Context and Problem Statement

入力検証の結果は、画面ではエラー表示の並び、REST では `/api/flights` の `messages` と ApiError の `details` の並びとして外から見える。
原典では、Hibernate Validator が違反を `HashSet` に集め[^hv-context]、Spring の `SpringValidatorAdapter` がその反復順で `BindingResult` に積む。
そのため、1 項目に複数の違反がある場合だけでなく、項目をまたいでも並びは決まらない。
`HashSet` の反復順は違反オブジェクトのハッシュ値に依存し、移植先で再現できない。

## Decision Drivers

* [Spec] の結果を決定的にし、適合テストベクタで比較できること
* [Source] について、原典が保証しない性質を仮定しないこと

## Considered Options

* [Source] は順序不定（多重集合）とし、[Spec] だけで並びを定める
* [Source] も [Spec] と同じ並びと仮定する

## Decision Outcome

Chosen option: "[Source] は順序不定とし、[Spec] だけで並びを定める", because 原典が保証しない並びを仮定すると、`Abstraction` の証明が偽の前提に立つことになるため。

* [Spec] の並びは次のとおりとする（[spec/input-validation.md](../spec/input-validation.md#検証の順序とエラーの並び)）。
  1. 単項目エラー: 項目の宣言順。同じ項目のエラーは制約表の列挙順。
  2. 相関検証で生じるフィールドエラー: 発生順。
  3. グローバルエラー: 発生順。
* [Source] の検証結果は、エラーの多重集合として写す。抽象化関数 α は、[Source] の多重集合と [Spec] の列を、順序を無視して比較する（[spec/abstraction.md](../spec/abstraction.md#抽象化関数-α)）。
* `source-model/` の適合テストベクタは、検証エラーを多重集合として比較する。`spec/` と `target-model/` のベクタは列として比較する。

### Consequences

* Good, because [Spec] と移植先の出力が決定的になる
* Bad, because 原典の画面と移植先の画面で、エラーの表示順が異なることがある

### Confirmation

* `Abstraction` の課題 ABS-033 で、検証エラーの多重集合が一致することを証明する。
* 差分オラクル（[backlog 0026](../backlog/0026-differential-oracle.md)）では、検証エラーを多重集合として比較する。

## Pros and Cons of the Options

### [Source] は順序不定、[Spec] だけで並びを定める

* Good, because 原典の性質を正しく写す
* Bad, because 比較の方法が [Source] と [Spec] で異なる

### [Source] も同じ並びと仮定する

* Good, because モデルとテストが単純になる
* Bad, because 原典では成り立たない仮定であり、オラクルで差分が出たときに無視する運用が必要になる

## More Information

* [spec/input-validation.md](../spec/input-validation.md), [spec/http-contract.md](../spec/http-contract.md), [spec/abstraction.md](../spec/abstraction.md)
* [ADR 0008](0008-errors-as-values-with-stable-codes.md)

[^hv-context]: hibernate-validator 9.1.0.Final `AbstractValidationContext`（`failingConstraintViolations = new HashSet<>()`）
* （補足 2026-10-30）[Source] の順序不定と [Spec] の定順との違いは、観測型の既知差異 D-022 として登録する（[spec/abstraction.md](../spec/abstraction.md#既知差異)、[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)）。B メソッドでは、具体側が抽象側より大きな非決定性を持つとリファインメントにならない。そこで出力の対応 αₒ のうちエラーの列を多重集合として比べる成分を、名前付きの差異成分とする。
