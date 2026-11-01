---
type: Overview
title: "スキルの作業項目"
description: "スキル spec-pivot の作業項目の索引。状態と依存関係。"
tags: [backlog, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
---

# スキルの作業項目

書き方は [maintenance.md](../rules/maintenance.md#作業項目backlog)。状態は各項目の frontmatter の `state` が正である。
依存の列には、このバンドルの項目だけを書く。適用先の項目がスキルの項目に依存するのはよいが、その逆は書かない。

| ID | 項目 | state | 依存 |
| --- | --- | --- | --- |
| 1ae4 | [Machine: 抽象機械と B メソッドのリファインメントの枠組み](1ae4-machine-refinement-framework.md) | done | — |
| a936 | [LangSemantics.Rust: Rust の意味論](a936-lang-semantics-rust.md) | todo | — |
| de90 | [スキルの文書を OKF バンドルにし、スキルの決定と作業項目を移す](de90-skill-docs-okf-bundle-and-records.md) | done | — |
| a49c | [OKF バンドルとリンクの検査の道具](a49c-okf-bundle-check-tool.md) | done | [de90](de90-skill-docs-okf-bundle-and-records.md) |
| 97a7 | [スキルの文書を spec/・rules/・guide/・lang/ に分ける](97a7-skill-docs-category-directories.md) | done | [a49c](a49c-okf-bundle-check-tool.md) |
| ce23 | [Lean の宣言をモジュール名の下に置く規則と検査](ce23-lean-module-namespace-layout.md) | done | — |
