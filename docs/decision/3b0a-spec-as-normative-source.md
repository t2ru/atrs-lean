---
type: Architecture Decision Record
title: "docs/spec を唯一の正規仕様とし、Lean を参照実装とする"
description: "docs/spec を唯一の正規仕様、Lean を参照実装、Java 原典をオラクルとする。"
tags: [adr, spec]
id: "3b0ab328-a955-4296-a49f-8b6b28cb3b1a"
status: deprecated
decision_status: superseded
superseded_by: "61bce953-a515-42f0-a216-a3af9ef39e1d"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# docs/spec を唯一の正規仕様とし、Lean を参照実装とする

## Context and Problem Statement

移植では「Java 原典」「仕様文書」「Lean 実装」の三つが振る舞いの根拠になりうる。
三者が食い違ったときにどれを正とするかが決まっていないと、他言語移植者はどれを写せばよいか判断できない。

## Decision Drivers

* 他言語移植者が単一の根拠だけを読めばよいこと
* Java 原典の偶発的な振る舞い（不具合・フレームワーク依存）を無批判に固定しないこと
* 仕様の曖昧さを実行可能な実装で早期に発見できること

## Considered Options

* `docs/spec` を正規とし、Lean は参照実装、Java はオラクル
* Lean 実装を正規（「コードが仕様」）とする
* Java 原典を正規とし、仕様文書は説明に留める

## Decision Outcome

Chosen option: "`docs/spec` を正規とし、Lean は参照実装、Java はオラクル", because 言語中立な文書だけを読めば移植できる状態を最終目標としており、Lean はそれを機械的に検証する手段として最も価値が高いため。

優先関係は次のとおり。

1. `docs/spec`（正規）
2. 適合テストベクタ `conformance/`（仕様の例を機械可読にしたもの。仕様と矛盾したら仕様を正として直す）
3. Lean 参照実装（仕様に従う。食い違いは Lean の不具合か仕様の不備として扱う）
4. Java 原典（振る舞いの発見と [Source] モデルの検証に使うオラクル）

### Consequences

* Good, because 他言語移植者は spec と conformance だけで作業できる
* Good, because Lean の型検査・証明が仕様の矛盾を検出する
* Bad, because 仕様と実装の二重管理になる。食い違いを放置しない運用が必要

### Confirmation

* Lean の公開定義の docstring に対応する spec 節を書く（[port-lang/lean/rules.md](../../.agents/skills/port-lang/references/docs/lean/rules.md)）。
* Lean 実装が `conformance/` の全ベクタを通すことを CI で確認する。

## Pros and Cons of the Options

### spec を正規、Lean を参照実装

* Good, because 言語中立の根拠が一つに定まる
* Bad, because 文書の精度を高く保つ必要がある

### Lean を正規

* Good, because 曖昧さが無い
* Bad, because 他言語移植者に Lean の読解を強いる。証明用の型が仕様に混入する

### Java を正規

* Good, because 調査の手間が少ない
* Bad, because 浮動小数点・フレームワーク依存の偶発的振る舞いまで仕様になる

## More Information

* **本 ADR は [ADR 61bc](61bc-lean-spec-as-normative-source.md) に置き換えられた**（Lean の `Spec` を正規とし、`Spec` で表現できない仕様だけを `docs/spec` で定義する）。

* [ADR a43d](a43d-two-layer-model-java-faithful-and-abstract.md): Java の振る舞いは [Source] モデルとして別途正規化する
* [ADR dc3a](dc3a-conformance-test-vectors.md)
