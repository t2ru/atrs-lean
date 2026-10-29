---
type: Architecture Decision Record
title: "排他制御の失敗をエラー分類 Conflict として表す"
description: "デッドロック・ロック待ちのタイムアウト・直列化失敗のように実行環境が吸収できない同時実行の失敗を AtrsError.Conflict とし、状態を変えず、画面は 500、REST は 409 とする。"
tags: [adr, errors, transaction]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:40:00+09:00
---

# 排他制御の失敗をエラー分類 Conflict として表す

## Context and Problem Statement

[spec/ports.md](../spec/ports.md#トランザクション) は、状態を変更するユースケースが原子的かつ直列化可能であることを要求し、実装として RDB のトランザクションや楽観ロックを認めている。
しかし実際の実装では、デッドロック、ロック待ちのタイムアウト、直列化失敗、楽観ロックの衝突が起こりうる。
原典の REST API は排他制御の例外を 409 に写すが、[ADR 0008](0008-errors-as-values-with-stable-codes.md) のエラー分類 `AtrsError` にはこれに当たる分類が無く、画面での扱いも決まっていない。

## Decision Drivers

* [Spec] の直列化可能性の要件を弱めないこと
* 実装が避けられない失敗を、状態を壊さずに利用者へ返せること
* REST の応答を原典と互換にすること

## Considered Options

* 新しい分類 `Conflict` を追加する
* `System` に含める

## Decision Outcome

Chosen option: "新しい分類 `Conflict` を追加する", because 原典の REST 応答（409）と互換になり、「再試行すれば成功しうる失敗」を `System`（整合性違反・I/O 失敗）と区別できるため。

* `AtrsError.Conflict(reason)` を追加する。`reason` はログ用で、利用者には示さない。
* [Spec] では、ユースケースは直列化可能に実行されるので `Conflict` は発生しない。`Conflict` は `TargetModel` と実行環境が、再試行などで吸収できなかったときだけ返してよい。返す場合、そのユースケースは状態を一切変えてはならない（採番の前進は除く。[spec/ports.md](../spec/ports.md#idgenerator)）。
* 画面: 500 のシステムエラー画面（`e.ar.fw.9999`）。REST: 409、`code = "e.ar.fw.9999"`（[spec/http-contract.md](../spec/http-contract.md#apierror)）。

### Consequences

* Good, because 楽観ロックなど多様な実装を許しつつ、失敗時の振る舞いを一意に定められる
* Bad, because エラー分類が 1 つ増え、すべての移植先で写す必要がある

### Confirmation

* `Refinement` の課題 REF-002（失敗時の状態不変）の対象に `Conflict` を含める。
* REST アダプタの結合テストで、`Conflict` が 409 になることを確認する。

## Pros and Cons of the Options

### `Conflict` を追加する

* Good, because 原典の 409 と互換で、意味が明確
* Bad, because 分類が増える

### `System` に含める

* Good, because 分類が増えない
* Bad, because REST が 500 になり、原典の 409 と異なる。既知差異の登録が必要になる

## More Information

* [ADR 0008](0008-errors-as-values-with-stable-codes.md) の補足である（既存の分類は変えない）
* [ADR 0011](0011-persistence-and-transaction-semantics.md), [spec/errors-and-messages.md](../spec/errors-and-messages.md#分類atrserror), [spec/ports.md](../spec/ports.md#トランザクション)
