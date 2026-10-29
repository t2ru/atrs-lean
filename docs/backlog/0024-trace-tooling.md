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
  at: 2026-10-30T10:00:00+09:00
---

# 追跡の道具（tools/trace）

## 目的

両端の追跡（[ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)）を機械的に保守・検査できるようにする。

## 範囲

- `tools/trace/`（独立 Cargo プロジェクト、stable ツールチェーン）
- `inventory source`（tree-sitter-java、Mapper XML・DDL・properties・pom の簡易パーサ、正規化した本文ハッシュ）
- `inventory target`（tree-sitter-rust と doc タグの行走査）
- `ingest-lean`（`lake exe trace-dump` の取り込み）, `manifest`（`trace/manifest.json` と traceability.md の生成区画）
- `check`（TR-S1〜TR-R と TR-D。警告にしてよいのは、backlog で完了していない機能だけ）, `rehash`（決定論的な検査を実行し、合格した定義だけハッシュを更新する）, `diff`（新旧インベントリの分類）, `impact`（証明グラフに沿った影響一覧）
- `tmpl:` ロケータ（Thymeleaf テンプレートの式）のインベントリ
- 最初の `trace/source-inventory.json` の生成（[backlog 0025](0025-upstream-submodule-and-inventory.md) の submodule から）
- 本文の正規化で文字列リテラルの中身を保つこと。`renames.json` の対応を `rehash` で検査すること
- 既存草案の「出典:」のパス表記をロケータ表記に書き換える（運賃計算・空席照会・予約から）

## 対象外

- 移植元ソースと移植先ソースを直接結ぶ機能（作ってはならない）

## 完了条件

- [ ] CI で `tools/trace check` が走る
- [ ] [traceability.md](../spec/traceability.md) の生成区画が埋まる
- [ ] 最初の `trace/source-inventory.json` を生成し、件数（Java メソッド・SQL 文・設定キー・メッセージキー）を記録した
- [ ] 故意に入れた TR-X 違反（`TargetModel` に `java:` を書く）を検出できる
- [ ] 故意に入れた TR-D 違反（文書の D-NNN に対応する `@[deviation]` が無い、R 課題に無名の仮定がある）を検出できる
- [ ] 検査が合格していない定義のハッシュを `rehash` が更新しないことを確認した

## 参照

- [ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)
- [traceability.md](../spec/traceability.md)
