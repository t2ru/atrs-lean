---
type: Architecture Decision Record
title: "原典の安全でない振る舞いと前提違反は Spec では正し、既知差異として記録する"
description: "セッション固定化、オープンリダイレクト、ロケール依存の曜日、前提違反による 500、緩すぎる数値・日付の解析について、Spec は安全で決定的な振る舞いを定め、原典との差を D-016〜D-021 とする。"
tags: [adr, security, http, validation]
id: "e10f17b4-5c61-4adf-9175-fee48c2388ac"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 原典の安全でない振る舞いと前提違反は Spec では正し、既知差異として記録する

## Context and Problem Statement

上流（`f4bfbf06`）のソースを調べたところ、仕様文書に書かれていない次の振る舞いが見つかった。

* ログイン時にセッション ID を変えない。`AtrsUsernamePasswordAuthenticationFilter` に `SessionAuthenticationStrategy` が設定されていない。
* ログイン成功時の `redirectTo` に絶対 URL を渡すと、外部サイトへリダイレクトする（オープンリダイレクト）。
* 支払期限の曜日が、要求の `Accept-Language` によって変わる。
* `GET /ticket/reserve?form` に便マスタに無い便名を渡すと、`NullPointerException` で 500 になる。
* 文字列の `Min`・`Max` を `BigDecimal` として判定するので、`"1e1"` も 10 として通る。日付は `+10000/01/01` や年 0 も受け付ける。

[Spec] がこれらを写すと、安全でない振る舞いや、前提違反（`PreconditionViolation` は [Source] にしか無い分類）を正規仕様に持ち込むことになる。

## Decision Drivers

* 正規仕様が、移植先に安全でない振る舞いを要求しないこと
* [Spec] の結果が決定的で、環境（ロケール）に依存しないこと
* 原典との差を漏れなく記録し、一致する前提を明示すること

## Considered Options

* [Spec] では正し、既知差異として記録する
* [Spec] も原典どおりにする

## Decision Outcome

Chosen option: "[Spec] では正し、既知差異として記録する", because 業務の意図は変わらず、安全性と決定性を移植先で保証できるため。差は [abstraction.md](../spec/abstraction.md#既知差異) に一致の前提とともに記録する。

| 差異 | [Spec] の振る舞い |
| --- | --- |
| D-016 | ログイン時にセッション ID を新しくする（[http-contract.md](../spec/http-contract.md#セッション)） |
| D-017 | `redirectTo` は、`/` で始まり `//` で始まらないアプリ内のパスだけを受け付ける |
| D-018 | 文字列の `Min`・`Max` は十進整数だけを数として扱う |
| D-019 | 支払期限の曜日は常に日本語にする |
| D-020 | 解決できない選択フライトは `InvalidRequest`（400）にする |
| D-021 | 日付は符号無し 4 桁の年 1〜9999 だけを受け付ける |

### Consequences

* Good, because 移植先は安全で決定的な振る舞いだけを実装すればよい
* Bad, because 差分の原典実行でこれらの入力を使うと差が出るので、前提を満たさない入力として除外する必要がある

### Confirmation

* `http` と `validation` の適合テストベクタに、各差異の境界例（外部 URL の `redirectTo`、`"1e1"`、`0000/01/01` など）を `spec/` 側の期待値で置く。
* 差分の原典実行（[backlog 773f](../backlog/773f-differential-oracle.md)）は、既知差異の前提を満たさない入力を比較対象から外す。

## Pros and Cons of the Options

### [Spec] では正す

* Good, because 安全で決定的
* Bad, because 既知差異が増える

### 原典どおり

* Good, because 差異が無い
* Bad, because オープンリダイレクトやセッション固定化を、移植先にも要求することになる

## More Information

* [spec/http-contract.md](../spec/http-contract.md), [spec/input-validation.md](../spec/input-validation.md), [spec/domain-model.md](../spec/domain-model.md), [spec/abstraction.md](../spec/abstraction.md)
* [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)（移植元モデルと抽象モデルを分ける方針）
* （補足 2026-10-30）[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) により、D-016〜D-021 は次の 2 つで確認する。上の Confirmation のベクタは、その補助である。
  * リファインメントの主定理（R 課題）の名前付きの仮定または観測成分
  * 差異の証拠（W 課題）
  
  課題は [spec/abstraction.md](../spec/abstraction.md#証明課題) を参照。
* （補足 2026-10-30・訂正）Consequences と Confirmation にある「差分の原典実行で既知差異の前提を満たさない入力を外す」は誤りである。差分の原典実行は新旧 2 版の原典どうしを比べるので、`Spec` との差異は関係しない。差分の原典実行では入力を除外しない。前提を満たさない入力を除くのは、[Source] と [Spec] を比べる場合（`spec/` のベクタと `source-model/` のベクタの対応づけ）だけである。
