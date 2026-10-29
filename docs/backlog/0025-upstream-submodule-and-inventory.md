---
type: Backlog Item
title: "上流の submodule 化と版の宣言"
description: "上流 ATRS を git submodule として commit 固定で取り込み、trace/upstream.json と移植元インベントリを作る。"
tags: [backlog, upstream, traceability]
id: "0025"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 上流の submodule 化と版の宣言

## 目的

移植元ソースの版を 1 か所で固定・宣言し、版上げ追従の起点を作る。

## 範囲

- `upstream/atrs` を submodule として追加（commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`。Windows の `core.longpaths=true` を手順に書く）
- `trace/upstream.json`（repo, variant, release, commit, `pom.xml` から抽出した依存の版, Java・PostgreSQL の版）
- `trace/out-of-scope.json`（[traceability.md](../spec/traceability.md#対象外) の内容を移す）

## 対象外

- push（しない）

## 完了条件

- [ ] submodule の commit が `trace/upstream.json` と一致する

## 参照

- [ADR 0024](../decision/0024-following-upstream-releases.md)
- [port-lang/upgrade.md](../../.agents/skills/port-lang/references/upgrade.md)
