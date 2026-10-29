---
type: Architecture Decision Record
title: "HTTP 契約を画面遷移の状態機械と REST JSON 形状として記述する"
description: "画面遷移は URL・メソッド・パラメータ・遷移先の表、REST API は JSON 形状とステータスの表で、フレームワーク非依存に記述する。"
tags: [adr, http, api]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# HTTP 契約を画面遷移の状態機械と REST JSON 形状として記述する

## Context and Problem Statement

[ADR 0002](0002-porting-scope.md) で HTTP 契約をスコープに含めた。原典の Web 層は Spring MVC の
`@RequestMapping(params = "confirm")` のような「同一 URL + パラメータ名」による画面分岐、
hidden フィールド・リダイレクトパラメータ・フラッシュ属性による状態の受け渡し、
トランザクショントークン（二重送信防止）、CSRF、Spring Security のフォームログインを用いる。
REST API は `/api/v1/flight`, `/api/v1/ticket` 等で JSON を返す。
これを他言語の Web フレームワークでも再現できる形で記述する方法を決める。

## Decision Drivers

* Web フレームワークに依存しないこと
* 外形的な互換性（URL・ステータス・JSON）を検証できること
* セキュリティ要件（認証必須 URL、二重送信防止、CSRF）を落とさないこと

## Considered Options

* Markdown 表による状態機械 + JSON 形状表（必要に応じ JSON Schema）
* OpenAPI 3 のみ
* 原典の Controller を写す

## Decision Outcome

Chosen option: "Markdown 表による状態機械 + JSON 形状表", because 画面遷移（HTML フォーム投稿とリダイレクト）は OpenAPI で表しにくく、REST 部分も同じ表形式に揃えると読みやすいため。REST 部分の OpenAPI 化は将来の任意作業とする。

* 画面遷移: 各リクエストを `(メソッド, パス, 判別パラメータ)` で識別し、入力（フォーム項目）、事前条件（認証・トークン）、呼び出すユースケース、成功時・各エラー時の遷移（表示する画面 ID またはリダイレクト先とステータス）を表にする。
* 画面は「画面 ID と表示に必要なデータ（ビューモデル）」として定義し、HTML の構造は定義しない。
* REST API: パス・メソッド・クエリ/本文の JSON 形状・応答の JSON 形状・ステータスコード・エラー本文を表にする。日付の JSON 表現は [spec/http-contract.md](../spec/http-contract.md) で固定する。
* トランザクショントークン・CSRF は「一度だけ有効な不透明トークンの検証」という契約として記述し、実装方式は規定しない。
* 原典の不具合（例: `POST /api/v1/ticket` で相関検証が適用されない）は [Source] として記録し、[Spec] では相関検証を適用する（差異として [spec/abstraction.md](../spec/abstraction.md) に登録）。

### Consequences

* Good, because 任意の Web フレームワークで実装でき、外形テスト（HTTP レベルの適合テスト）も作れる
* Bad, because 表の記述量が多い。OpenAPI ツールの恩恵は受けられない

### Confirmation

* [backlog 0014](../backlog/0014-http-contract-adapter.md) の HTTP アダプタが、契約表から作った HTTP レベルのテストを通すことで確認する。

## Pros and Cons of the Options

### Markdown 表

* Good, because 画面遷移と REST を同じ形式で書ける
* Bad, because 機械検証にはパーサが必要

### OpenAPI 3 のみ

* Good, because ツールが豊富
* Bad, because フォーム投稿・リダイレクト・フラッシュ属性による画面遷移を自然に表せない

### Controller を写す

* Good, because 原典に忠実
* Bad, because Spring MVC の意味論（パラメータ分岐、バインド、`@ModelAttribute`）を仕様に持ち込む

## More Information

* [spec/http-contract.md](../spec/http-contract.md)
