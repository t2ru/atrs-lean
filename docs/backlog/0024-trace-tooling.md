---
type: Backlog Item
title: "追跡の道具（tools/trace）"
description: "インベントリ生成・Lean ダンプの取り込み・manifest と表の生成・TR 検査・差分・影響分析を行う Rust 製の道具を作る。"
tags: [backlog, tooling, traceability]
id: "0024"
state: todo
depends_on: ["0001", "0025"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 追跡の道具（tools/trace）

## 目的

両端の追跡（[ADR 0023](../decision/0023-cross-language-traceability.md)）を機械的に保守・検査できるようにする。

## 範囲

- `tools/trace/`（独立 Cargo プロジェクト、stable ツールチェーン）
- `inventory source`（tree-sitter-java、Mapper XML・DDL・properties・pom の簡易パーサ、正規化した本文ハッシュ）
- `inventory target`（tree-sitter-rust と doc タグの行走査）
- `ingest-lean`（`lake exe trace-dump` の取り込み）, `manifest`（`trace/manifest.json` と traceability.md の生成区画）
- `check`（TR-S1〜TR-R、段階導入の警告／失敗の切り替え）, `diff`（新旧インベントリの分類）, `impact`（証明グラフに沿った影響一覧）
- 既存草案の「出典:」のパス表記をロケータ表記に書き換える（運賃計算・空席照会・予約から）

## 対象外

- 移植元ソースと移植先ソースを直接結ぶ機能（作ってはならない）

## 完了条件

- [ ] CI で `tools/trace check` が走る
- [ ] [traceability.md](../spec/traceability.md) の生成区画が埋まる
- [ ] 故意に入れた TR-X 違反（`TargetModel` に `java:` を書く）を検出できる

## 参照

- [ADR 0023](../decision/0023-cross-language-traceability.md)
- [traceability.md](../spec/traceability.md)
