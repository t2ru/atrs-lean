---
type: Architecture Decision Record
title: "Lean のソース全体を 1 冊の本にし、層ごとの部に分ける"
description: "mdgen と mdbook で作る本の範囲を、Spec だけから Lean のソース全体（lean/ の Spec・SourceModel・Abstraction・TargetModel・Refinement・Tests・Tools と、スキル spec-pivot の assets/lean）に広げる。1 冊にし、目次を層ごとの部に分ける。部をまたぐリンクも本の中で辿れる。"
tags: [adr, documentation, lean, mdbook]
id: "f779d051-abba-426e-b0ba-08ec10a7fe68"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T13:00:00+09:00
---

# Lean のソース全体を 1 冊の本にし、層ごとの部に分ける

## Context and Problem Statement

[ADR 68a6](68a6-business-spec-in-lean-module-docs-and-book.md) で、`Spec` のモジュール文書を mdgen と mdbook で HTML の本にした。
その本は `lean/Spec.lean`・`lean/Spec/` だけを含むため、`SourceModel`・`Abstraction` などのモジュール文書と定義は本に無く、`Spec` の文書からそれらへのリンクは GitHub へ出ていた。
プロジェクトオーナーは、Lean のソース全体を mdgen と mdbook で HTML にするよう指示した（[backlog 63a3](../backlog/63a3-whole-lean-source-book.md)）。

## Decision Drivers

* モデル・仕様・証明を、層をまたいで 1 か所で読めること
* 業務の読者が、仕様（`Spec`）を最初に読めること
* 道具（`scripts/book/build.py`）をアプリに依存しないまま保つこと

## Considered Options

* 1 冊に統合し、層ごとの部に分ける
* 仕様の本と、ソース全体の本の 2 冊を作る

## Decision Outcome

Chosen option: "1 冊に統合し、層ごとの部に分ける", because 層をまたぐリンク（`Spec` の文書から `SourceModel` へ、`Abstraction` から `Spec` へ）が本の中で辿れ、ビルドと artifact も 1 つで済むため。仕様は最初の部に置くので、業務の読者もこれまでどおり読める。

* 範囲: `lean/` の `Spec`・`SourceModel`・`Abstraction`・`TargetModel`・`Refinement`・`Tests`・`Tools`（lakefile は除く）と、スキル spec-pivot の `assets/lean` の `LangSemantics`・`Machine`・`Trace`・`ConformanceKit`・`Test`。
* 部（`trace/project.json` の `book.parts`）: 仕様（Spec）／移植元モデル（SourceModel）／抽象化（Abstraction）／移植先モデルと具体化（TargetModel・Refinement）／テストと道具（Tests・Tools）／スキル spec-pivot のライブラリ。
* 目次は、各部の入口のモジュールの import の順に並べ、名前の階層で入れ子にする（規則はスキルの [ADR d2b6](../../.agents/skills/spec-pivot/references/docs/decision/d2b6-book-parts-and-namespace-toc.md)）。
* タスク `book:build` の範囲（`tools/ci/check-scopes.toml`）を、本に入るすべての Lean のファイルに広げる。CI の artifact の名前 `spec-book` は変えない。

### Consequences

* Good, because モデル・仕様・証明のすべてのモジュール文書と定義が、層をまたぐリンクごと本で読める。
* Bad, because 本が大きくなる（約 300 ページ、検索の索引が約 10 MB）。また、Lean のファイルを変えると `book:build` が選ばれやすくなる。

## More Information

* 本の道具と仕様の散文の置き場所: [ADR 68a6](68a6-business-spec-in-lean-module-docs-and-book.md)。
