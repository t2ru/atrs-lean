---
type: Backlog Item
title: "OKF バンドルとリンクの検査"
description: "docs/ が OKF v0.2 に適合し、相対リンクとアンカーが切れていないことを CI で検査する。"
tags: [backlog, docs, okf, ci]
id: "0017"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# OKF バンドルとリンクの検査

## 目的

文書の形式と索引の整合を機械的に保つ。

## 範囲

- frontmatter の YAML 解析と `type` の検査（OKF §11）
- `docs/index.md` が全文書を列挙しているかの検査
- 相対リンクと見出しアンカーの検査
- ADR の必須節の検査

## 対象外

- なし

## 完了条件

- [ ] CI で検査が走り、違反を検出できることを確認した

## 参照

- [ADR 0017](../decision/0017-documentation-format-okf-v0-2.md)
- [rules/documentation.md](../rules/documentation.md#okf-v02)
