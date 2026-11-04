---
type: Architecture Decision Record
title: "予約履歴レポートの要求キューは少なくとも 1 回配信し、再配信に上限を設ける"
description: "レポート生成に失敗した要求を再配信し、上限を超えたら破棄してログに残す。重複配信で別の秒のレポートが 2 本できることを許す。"
tags: [adr, report, async]
id: "90f57e28-6457-40a3-a50c-43683fb05336"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:40:00+09:00
---

# 予約履歴レポートの要求キューは少なくとも 1 回配信し、再配信に上限を設ける

## Context and Problem Statement

[ADR ff4d](ff4d-asynchronous-report-generation.md) は、レポートの非同期生成を `ReportQueue` と `ReportStore` のポートで表すと決めた。
しかし、生成に失敗した要求をどう扱うか（再配信するか、何回までか、重複配信を許すか）は「キューの実装に委ねる」とされ、規範として決まっていなかった。
原典はトランザクション付きの JMS セッションで受信するので、例外が出るとロールバックされ、ブローカーの設定に従って再配信される。

## Decision Drivers

* 一時的な失敗（I/O など）でレポートが失われないこと
* 恒久的な失敗（同一秒の再生成など）で無限に再試行しないこと
* キューの実装を特定の製品に縛らないこと

## Considered Options

* 少なくとも 1 回配信し、再配信に上限を設ける
* 最大 1 回配信する（再配信しない）

## Decision Outcome

Chosen option: "少なくとも 1 回配信し、再配信に上限を設ける", because 原典の JMS の振る舞いに近く、一時的な失敗から回復できるため。

* `onReportRequested` が失敗したら、その要求を再配信する。
* 再配信の上限回数は実装で定める。参考値は原典のブローカーの既定値とする（[spec/ports.md](../../lean/Spec/Port.lean#reportqueue)）。上限を超えた要求は破棄し、ログに残す。
* 同じ要求が重複して配信されてもよい。その結果、別の秒のレポートが 2 本できることを許す。同じ秒なら、2 本目は「同名が存在する」ので失敗する（[spec/reservation-history-report.md](../../lean/Spec/Report.lean)）。
* 配信の順序は保証しない。同時に処理する要求は 1 件とする（既存の契約どおり）。

### Consequences

* Good, because 一時的な失敗でレポートが失われにくい
* Bad, because 重複したレポートができうる

### Confirmation

* インメモリのキューアダプタで、失敗した要求が上限回数まで再配信され、その後破棄されることをテストで確認する。

## Pros and Cons of the Options

### 少なくとも 1 回、上限あり

* Good, because 原典に近く、回復できる
* Bad, because 重複を許す必要がある

### 最大 1 回

* Good, because 重複が起きない
* Bad, because 一時的な失敗でレポートが失われ、原典と異なる

## More Information

* [ADR ff4d](ff4d-asynchronous-report-generation.md) の補足である
* [spec/ports.md](../../lean/Spec/World.lean), [spec/reservation-history-report.md](../../lean/Spec/Report.lean)
