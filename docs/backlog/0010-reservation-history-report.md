---
type: Backlog Item
title: "予約履歴レポート（D1）"
description: "要求・受信・生成・一覧・取得と CSV のバイト仕様を両モデルで実装する。"
tags: [backlog, spec, source-model, report]
id: "0010"
state: todo
depends_on: ["0007"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 予約履歴レポート（D1）

## 目的

非同期処理とバイト単位の出力互換性を確定させる。

## 範囲

- `Spec.UseCase.Report`, `SourceModel.UseCase.Report`
- `renderCsv` のバイト列ベクタ
- 同一秒の再生成の扱い

## 対象外

- なし

## 完了条件

- [ ] CSV のベクタ（CRLF、引用、日付書式）が両モデルで通る

## 参照

- [reservation-history-report.md](../spec/reservation-history-report.md)
- [ADR 0016](../decision/0016-asynchronous-report-generation.md)
