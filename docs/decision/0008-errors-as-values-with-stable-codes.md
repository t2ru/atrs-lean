---
type: Architecture Decision Record
title: "エラーを値として返し、原典のメッセージキーを安定したエラーコードとする"
description: "業務・入力・前提違反・システムの各エラーを直和型の値で返し、e.ar.b2.2001 等の原典キーをコードとして使う。"
tags: [adr, errors]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# エラーを値として返し、原典のメッセージキーを安定したエラーコードとする

## Context and Problem Statement

原典は `AtrsBusinessException`（業務エラー、`e.ar.b2.2001` 等のコードと引数）、`InvalidFlightException`（改竄検知）、
`BadRequestException`、`SystemException`（更新件数不一致など）、Spring の `Assert`（`IllegalArgumentException`）、
Bean Validation のエラー（フィールドエラー・グローバルエラー）を例外として使い分けている。
例外の伝播規則は言語ごとに異なるため、仕様では別の表現が必要である。

## Decision Drivers

* 全言語で同じ表現ができること
* 画面・API が表示するメッセージを原典と一致させられること
* エラーの評価順序（どの検査が先に失敗するか）を仕様にできること

## Considered Options

* 直和型のエラー値 + 原典のメッセージキーをコードに使う
* 例外として仕様化する
* 新しいエラーコード体系を作る

## Decision Outcome

Chosen option: "直和型のエラー値 + 原典のメッセージキー", because 例外機構に依存せず、原典の画面・API が出すメッセージと 1 対 1 に対応付けられるため。

`AtrsError` は次の分類を持つ（詳細は [spec/errors-and-messages.md](../spec/errors-and-messages.md)）。

| 分類 | 原典 | 例 |
| --- | --- | --- |
| `Business(code, args)` | `AtrsBusinessException` | `e.ar.b2.2009`（空席不足） |
| `NotFound(code)` | `FlightNotFoundException` 等 | `e.ar.b1.2003` |
| `Validation(errors)` | Bean Validation / 相関検証 | フィールドエラーとグローバルエラーの列 |
| `InvalidRequest(reason)` | `InvalidFlightException`, `BadRequestException` | 改竄検知（`e.ar.a0.L9001`） |
| `PreconditionViolation(reason)` | `Assert` 失敗 | [Source] のみ。[Spec] では型で排除する |
| `System(code, args)` | `SystemException` | `e.ar.a0.L9002`（更新件数不一致） |

* コード文字列は原典のキーをそのまま使う（`e.ar.<機能>.<番号>`、ログ用は `e.ar.<機能>.L<番号>`）。
* メッセージ文言（日本語）はデータとして [spec/errors-and-messages.md](../spec/errors-and-messages.md) に持ち、引数 `{0}`, `{1}` の置換規則を定義する。
* Lean では `Except AtrsError α` を使う。

### Consequences

* Good, because 言語非依存で、テストベクタに期待エラーを JSON で書ける
* Good, because 原典の表示メッセージを再現できる
* Bad, because 原典で例外の型階層に頼っていた分岐（`FlightNotFoundException` が `AtrsBusinessException` の部分型である等）を、分類として明示し直す必要がある

### Confirmation

* 全エラーコードが [spec/errors-and-messages.md](../spec/errors-and-messages.md) に掲載され、各ユースケースのエラー表から参照されていることをレビューで確認する。

## Pros and Cons of the Options

### 直和型のエラー値

* Good, because 移植性・検査可能性が高い
* Bad, because 呼び出し側で明示的に伝播させる必要がある

### 例外として仕様化

* Good, because 原典に近い
* Bad, because 例外を持たない言語・伝播規則の違う言語で再現しにくい

### 新しいコード体系

* Good, because 整理できる
* Bad, because 原典との対応表が別途必要になり、メッセージの互換性検証が難しい

## More Information

* [spec/errors-and-messages.md](../spec/errors-and-messages.md)
