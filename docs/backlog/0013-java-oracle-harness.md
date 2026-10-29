---
type: Backlog Item
title: "Java オラクルハーネス"
description: "原典の Java クラスを直接呼び出し、[Source] ベクタの期待値を採取するハーネスを作る。"
tags: [backlog, java, oracle, testing]
id: "0013"
state: todo
depends_on: ["0012"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# Java オラクルハーネス

## 目的

[Source] の正しさを原典そのもので確認する。

## 範囲

- 原典のドメイン層（Spring 不要な部分）を呼ぶ小さな Java プログラム
- ベクタの `input` から呼び出し、`expected` を出力（`source: java-oracle`）
- REST の日付 JSON 表現の確認（[http-contract.md](../spec/http-contract.md) の TODO）

## 対象外

- 原典の改変

## 完了条件

- [ ] 運賃計算の [Source] ベクタが Java オラクルと一致する
- [ ] http-contract.md の TODO(spec) を解消した

## 参照

- [port-lang/java/harness.md](../../.agents/skills/port-lang/references/java/harness.md)
