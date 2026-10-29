---
type: Architecture Decision Record
title: "予約履歴レポートの非同期生成をキューとストアのポートで表し、CSV をバイト単位で規定する"
description: "JMS とファイルシステムを ReportQueue/ReportStore ポートに抽象化し、CSV の書式・ファイル名・一覧順を厳密に定義する。"
tags: [adr, report, async]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:52:11+09:00
---

# 予約履歴レポートの非同期生成をキューとストアのポートで表し、CSV をバイト単位で規定する

## Context and Problem Statement

D1 予約履歴レポートは、画面から JMS キュー `jms/queue/ReservationHistoryReportRequestQueue` に会員番号を送り、
リスナが予約履歴を取得して CSV を `report.dir/tmp` に書き、`report.dir/<会員番号>/` へ移動する。
一覧は会員ディレクトリのファイル名の降順、ダウンロードは存在確認後にファイルを返す。
JMS・ファイルシステムは言語・環境依存であり、CSV の書式（引用・改行・日付書式）は互換性に直結する。

## Decision Drivers

* 非同期性（要求の受付と生成の分離）を仕様として残すこと
* CSV の内容をどの言語でもバイト単位で一致させること
* ファイル名の時刻依存を決定的にテストできること

## Considered Options

* `ReportQueue`（送信・受信）と `ReportStore`（一時書込・確定・一覧・取得）のポート + CSV のバイト仕様
* JMS とファイルシステムをそのまま仕様にする
* 同期生成に単純化する

## Decision Outcome

Chosen option: "キューとストアのポート + CSV のバイト仕様", because 非同期性と原子的な公開（tmp → 確定）を保ったまま、技術を差し替えられるため。

* `ReportQueue.send(membershipNumber)` / 受信側は `onReportRequested(message)` ユースケース。メッセージが文字列でない・長さが 10 でない場合は無視する（原典どおり）。
* `ReportStore` は会員番号ごとの名前空間にファイルを持ち、`writeTemp`, `publish`（原子的移動）, `list`, `read` を提供する。
* CSV: 文字コード UTF-8（BOM なし）、改行 CRLF、全項目をダブルクォートで囲む（内部のクォートのエスケープは行わない。原典どおり。値に `"` が入らないことは型で保証される）。ヘッダ・列順・日付書式は [spec/reservation-history-report.md](../spec/reservation-history-report.md) に定義する。
* ファイル名: `atrs_report_<会員番号>_<yyyyMMddHHmmss>.csv`。時刻は `Clock` から取得する。
* 一覧: ファイル名の降順（Unicode スカラ値の辞書順の逆）。

### Consequences

* Good, because 任意のメッセージング・ストレージで実装でき、CSV の互換性をベクタで検証できる
* Bad, because 同一秒に 2 回生成すると原典では移動先の衝突で失敗する。[Source] では再現し、[Spec] では「同名が存在すれば失敗（システムエラー）」と明記する

### Confirmation

* CSV 生成の純粋関数に対し、バイト列を期待値とするテストベクタを置く。

## Pros and Cons of the Options

### ポート + バイト仕様

* Good, because 技術非依存で互換性を検証可能
* Bad, because ポートの契約記述が必要

### JMS とファイルシステムをそのまま

* Good, because 原典どおり
* Bad, because 特定ミドルウェアへの依存を強いる

### 同期生成

* Good, because 単純
* Bad, because 原典の「受付 → 後で取得」という利用者体験が失われる

## More Information

* [spec/reservation-history-report.md](../spec/reservation-history-report.md), [spec/ports.md](../spec/ports.md)
* 後続: [ADR 0031](0031-report-queue-at-least-once-delivery.md)（要求キューの配信保証と再配信の上限）
