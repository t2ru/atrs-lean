---
type: Backlog Item
title: "予約履歴レポート（D1）"
description: "要求・受信・生成・一覧・取得と CSV のバイト仕様を両モデルで実装する。"
tags: [backlog, spec, source-model, report]
id: "0010"
state: todo
depends_on: ["0007", "0008", "0013", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 予約履歴レポート（D1）

## 目的

非同期処理とバイト単位の出力互換性を確定させる。

## 範囲

- `Spec.UseCase.Report`, `SourceModel.UseCase.Report`
- `renderCsv` のバイト列ベクタ
- 同一秒の再生成の扱い
- R 課題 ABS-044（予約履歴レポート）、ABS-025（ReportStore・ReportQueue）
- SPEC 課題: レポートの SPEC-001〜SPEC-004

## 対象外

- なし

## 完了条件

- [ ] CSV のベクタ（CRLF、引用、日付書式）が両モデルで通る
- [ ] ABS-025・ABS-044 と SPEC 課題を証明し、TR-D が通る（D-006 の W 課題は [backlog 0008](0008-member-usecases-and-input-validation.md)）
- [ ] レポートの `source-model/` ベクタが Java オラクルと一致する

## 参照

- [reservation-history-report.md](../spec/reservation-history-report.md)
- [ADR 0016](../decision/0016-asynchronous-report-generation.md)
