---
type: Architecture Decision Record
title: "本番の Clock は Asia/Tokyo で今日を決め、fixture の投入日は 2026-11-01 に固定する"
description: "Clock ポートの本番アダプタが使うタイムゾーンと、投入日に依存するシードデータ（ピーク時期・フライト）を fixture にするときの基準日を定める。"
tags: [adr, date-time, conformance]
id: "9ee48fe1-9894-43e4-a2fd-48e81954b63c"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:40:00+09:00
---

# 本番の Clock は Asia/Tokyo で今日を決め、fixture の投入日は 2026-11-01 に固定する

## Context and Problem Statement

[ADR 6eb2](6eb2-date-and-time-model.md) は、日付をタイムゾーン無しの暦日とし、今日の日付を `Clock` ポートで注入すると決めた。
しかし、本番の `Clock` がどのタイムゾーンで「今日」を決めるかは決めていない。原典は JVM の既定のタイムゾーンに従うので、実行環境によって照会可能期間・予約可能期間・年齢・レポートのファイル名が変わる。
また、原典のシードは投入時の年（ピーク時期）と投入日（フライトの 120 日分と空席数のパターン）に依存するため、そのままでは適合テストの共有入力（fixture）にできない。

## Decision Drivers

* 国内線の予約システムとして、利用者から見た「今日」が実行環境に左右されないこと
* fixture が決定的で、年の境目とピーク時期の両方を含むこと

## Considered Options

* 本番は Asia/Tokyo、fixture の投入日は 2026-11-01
* 本番は Asia/Tokyo、fixture の投入日は 2026-01-01
* 本番は実行環境の既定のタイムゾーン（原典どおり）、fixture の投入日は 2026-11-01

## Decision Outcome

Chosen option: "本番は Asia/Tokyo、fixture の投入日は 2026-11-01", because 国内線の業務日付は日本時間で決まり、投入日を 11 月 1 日にすると フライトが年をまたぎ（2026-11-01〜2027-03-01。原典は投入日から 120 日後までの 121 日分を作る）、ピーク時期（12/19〜1/5 など）も含むため。

* 本番の `Clock` アダプタは、現在時刻を Asia/Tokyo（UTC+9、夏時間なし）の暦日と時刻に変換して返す。これは実行環境に課す要件であり、[spec/ports.md](../../lean/Spec/Port.lean#clock) の規範節に書く。
* fixture の投入日は `2026-11-01`、投入年 `Y = 2026` とする。ピーク時期は 2026 年と 2027 年の 2 年分、フライトは投入日から 120 日後（2027-03-01）までの両端を含む 121 日分とし、空席数のパターンの起点 `i = 0` を投入日とする（[spec/conformance.md](../spec/conformance.md)）。
* 適合テストベクタの `today` は、各ベクタで明示する。

### Consequences

* Good, because 実行環境のタイムゾーン設定に依存しない
* Bad, because 原典を UTC で動かした場合と、0 時〜9 時（JST）の間で今日の日付が異なる。原典は JST で動かす前提で比較する

### Confirmation

* `Clock` アダプタの単体テストで、UTC 2026-10-31T15:00:00Z が 2026-11-01 になることを確認する。
* fixture の件数とピーク時期の期間を、[backlog 4b0e](../backlog/4b0e-in-memory-adapters-and-seed-data.md) の完了条件で確認する。

## Pros and Cons of the Options

### Asia/Tokyo、2026-11-01

* Good, because 年の境目とピーク時期を 1 つの fixture で試せる
* Bad, because 投入日より後の日付で照会するベクタでは、`today` を明示する必要がある

### Asia/Tokyo、2026-01-01

* Good, because 年の初めで分かりやすい
* Bad, because フライトの期間（121 日分）が年をまたがない

### 実行環境の既定、2026-11-01

* Good, because 原典と同じ
* Bad, because 本番の振る舞いが環境設定に依存する

## More Information

* [ADR 6eb2](6eb2-date-and-time-model.md) の補足である（決定内容は変えない）
* [spec/ports.md](../../lean/Spec/World.lean), [spec/conformance.md](../spec/conformance.md), [spec/master-data.md](../../lean/Spec/Env/MasterData.lean#シードデータ)
