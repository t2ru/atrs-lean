---
type: Backlog Item
title: "差分オラクル（新旧 2 版の振る舞い比較）"
description: "Java オラクルハーネスを拡張し、source-model ベクタの全入力を新旧 2 版の上流で実行して出力の差分を取る。"
tags: [backlog, java, oracle, upstream, testing]
id: "773f2c47-5a43-4da9-9c16-b9f36bfe5765"
state: todo
depends_on: ["f18c3c0f-4007-42c1-ba25-102fb385a16c", "455ffb21-3a0e-4833-b82c-2d972bfec450"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 差分オラクル（新旧 2 版の振る舞い比較）

## 目的

版上げ時に、コード差分に現れない振る舞いの変化（依存フレームワークの挙動など）を検出する。

## 範囲

- 2 つの上流 commit を指定してそれぞれのハーネスを構築・実行する仕組み
- ケースごとの出力差分の一覧（`trace/upgrade-impact.md` への入力）
- [port-lang/upgrade.md](../../.agents/skills/port-lang/references/docs/upgrade.md) の手順 4 の具体化

## 対象外

- 新しい上流版への実際の追従（版上げのたびに別項目）

## 完了条件

- [ ] 同じ commit を新旧に指定すると差分 0 になる
- [ ] 故意に設定値（`atrs.childFareRate`）を変えた版で、関係するケースだけに差分が出る

## 参照

- [ADR 3f36](../decision/3f36-following-upstream-releases.md)
- [backlog f18c](f18c-java-oracle-harness.md)
