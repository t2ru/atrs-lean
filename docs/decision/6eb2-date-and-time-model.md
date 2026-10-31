---
type: Architecture Decision Record
title: "日付はタイムゾーン無しの暦日とし、今日の日付を入力として注入する"
description: "暦日・時刻・日時の表現、書式、日数差の定義、Clock ポートによる現在日時の注入を定める。"
tags: [adr, date-time]
id: "6eb2264c-1ab2-466e-9019-56b04386cf08"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:52:11+09:00
---

# 日付はタイムゾーン無しの暦日とし、今日の日付を入力として注入する

## Context and Problem Statement

原典は `LocalDate.now(dateFactory.tick())`（`ClockFactory`）で今日を取得し、照会可能期間・運賃種別の予約可能期間・年齢計算・生年月日の範囲・レポートファイル名の日時に使っている。
便の時刻は `"0900"` のような 4 桁文字列、搭乗日は `LocalDate`、日数差は `Duration.between(a.atTime(0,0), b.atTime(0,0)).toDays()` で求めている。
これらを言語中立に定義する必要がある。

## Decision Drivers

* 実行環境のタイムゾーン・時計に結果が依存しないこと
* テストベクタで「今日」を固定できること
* 原典の境界条件（以前・以後の包含）を正確に再現できること

## Considered Options

* タイムゾーン無しの暦日 + 現在日時を Clock ポートで注入
* UTC のタイムスタンプで統一
* 実行環境のローカル時刻をそのまま使う

## Decision Outcome

Chosen option: "タイムゾーン無しの暦日 + Clock ポート", because 原典が `LocalDate`/`LocalDateTime` のみを使っており、タイムゾーンの意味を持たないため。

* `Date`: 先発グレゴリオ暦の年月日（年 1〜9999）。比較は辞書順。`addDays`, `daysBetween(a, b)`（b − a の日数、負もありうる）を定義する。
* `HourMinute`: 時（0–23）と分（0–59）。原典の 4 桁文字列 `HHmm` との相互変換を定義する。
* `DateTime`: `Date` + 時・分・秒（レポートファイル名の `yyyyMMddHHmmss` に使用）。
* 書式: `yyyy/MM/dd`（画面・CSV）、`HH:mm`（画面表示）、`yyyyMMddHHmmss`（ファイル名）。いずれもゼロ埋め固定桁。
* 「今日」「現在日時」は `Clock` ポートから取得する（[spec/ports.md](../spec/ports.md)）。純粋関数は `today : Date` を引数に取る。
* 年齢: `fullYearsBetween(birthday, now)`（`ChronoUnit.YEARS.between` と同じく、誕生日の到来前は 1 少ない）。閏日生まれの扱いは [spec/domain-model.md](../spec/domain-model.md) に定義する。

### Consequences

* Good, because テストベクタに `today` を書くだけで再現できる
* Good, because 日付演算は整数（通算日数）で実装できる
* Bad, because 日付演算ライブラリを持たない言語では自前実装が必要（Lean も同様。[backlog 591d](../backlog/591d-abstract-domain-types-and-master-data.md)）

### Confirmation

* 日付演算の境界（月末・閏年・年越し）をテストベクタに含める。
* `Spec` が実時計に触れないこと（`IO` を使わないこと）を確認する。

## Pros and Cons of the Options

### 暦日 + Clock

* Good, because 原典の意味と一致し、決定的
* Bad, because 日付演算の実装が必要

### UTC タイムスタンプ

* Good, because 一般的
* Bad, because 原典に無いタイムゾーン変換が入り、日付境界がずれうる

### ローカル時刻

* Good, because 実装が簡単
* Bad, because 非決定的で、テスト・証明ができない

## More Information

* [spec/domain-model.md](../spec/domain-model.md), [spec/ports.md](../spec/ports.md)
* 後続: [ADR 9ee4](9ee4-clock-timezone-and-fixture-base-date.md)（本番の `Clock` のタイムゾーンと fixture の投入日）
