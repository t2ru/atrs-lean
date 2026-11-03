---
type: Backlog Item
title: "Lean のソース全体を本にする"
description: "mdgen と mdbook の本の範囲を、Spec だけから Lean のソース全体（lean/ とスキルの assets/lean）に広げ、目次を層ごとの部に分ける。"
tags: [backlog, documentation, lean, mdbook]
id: "63a3a945-ab83-421c-a7ae-62e3a6054bbf"
state: done
depends_on: ["c89a3bd3-e71a-45cc-bb2f-f31de6f430d9"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T13:00:00+09:00
---

# Lean のソース全体を本にする

## 目的

モデル・仕様・証明を、層をまたいで 1 冊の HTML で読めるようにする（[ADR f779](../decision/f779-whole-lean-source-book.md)）。

## 範囲

- スキル spec-pivot の `scripts/book/build.py` を部（`book.parts`）に対応させる。合わせて、部をまたぐリンク、名前の階層の目次（中間の名前の見出し）も扱う。
- `trace/project.json` の `book` に、6 つの部を置く。
- `book:build` の範囲と、CI・タスクの説明を改める。

## 対象外

- 本の公開（GitHub Pages など）。本は CI の artifact だけとする
- Lean のシンタックスハイライト（mdbook の既定の highlight.js は Lean を持たない）

## 完了条件

- [x] `mise run book:build` が、`lean/` とスキルの `assets/lean` の Lean のファイルすべて（約 300）を、6 つの部に分けた 1 冊にする
- [x] 部をまたぐ `.lean` へのリンクが、本の中のページへ向く
- [x] PR の CI（全数）で、本物の mdgen による `book:build` が通る

## 参照

- [ADR f779](../decision/f779-whole-lean-source-book.md)、[ADR 68a6](../decision/68a6-business-spec-in-lean-module-docs-and-book.md)、[backlog c89a](c89a-business-spec-in-lean-module-docs.md)
- スキル spec-pivot の [ADR d2b6](../../.agents/skills/spec-pivot/references/docs/decision/d2b6-book-parts-and-namespace-toc.md)
