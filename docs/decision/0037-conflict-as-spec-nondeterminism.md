---
type: Architecture Decision Record
title: "排他制御の失敗 Conflict を、Spec の状態変更操作の非決定的な結果とする"
description: "AtrsError.Conflict とポートの I/O の失敗を、Spec の状態変更操作が採番以外の状態を変えずに選びうる非決定的な結果として定め、活性の限界を明示する。実行可能な Spec の標準の選択はこれらを選ばない。画面は 500、REST は 409。ADR 0029 を置き換える。"
tags: [adr, errors, transaction, refinement]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
---

# 排他制御の失敗 Conflict を、Spec の状態変更操作の非決定的な結果とする

## Context and Problem Statement

[ADR 0029](0029-concurrency-failure-as-conflict-error.md) は、排他制御の失敗を `AtrsError.Conflict` として表すと決めた。対象は、デッドロック・ロック待ちのタイムアウト・直列化の失敗・楽観ロックの衝突である。
そのうえで「[Spec] では `Conflict` は発生せず、`TargetModel` と実行環境が返してよい」とした。
この定め方では、具体側（`TargetModel`）に、抽象側（`Spec`）で模倣できない遷移ができる。そのため、B メソッドのリファインメント（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)）が成り立たない。
また、「仕様にない振る舞いを実装してはならない」（[AGENTS.md](../../AGENTS.md)、[port-lang/process.md](../../.agents/skills/port-lang/references/process.md)）とも矛盾する。

## Decision Drivers

* 具体側のすべての遷移が、抽象側で模倣できること（原則 2）
* [Spec] の直列化可能性の要件を弱めないこと
* 実行可能な `Spec` から、決定的なベクタを生成できること
* REST の応答を原典と互換にすること（409）

## Considered Options

* `Conflict` を、`Spec` の状態変更操作の非決定的な結果とする
* `Spec` は変えず、`Conflict` を移植先の既知差異 `T-NNN` とする（「競合が起きない」を前提にする）

## Decision Outcome

Chosen option: "`Conflict` を、`Spec` の状態変更操作の非決定的な結果とする", because 抽象側の非決定性を具体側で減らすのは B メソッドのリファインメントで許される。この選択なら、実装が `Conflict` を返しても返さなくても、リファインメントが成り立つため。

* `AtrsError.Conflict(reason)` を置く。`reason` はログ用で、利用者には示さない（ADR 0029 から引き継ぐ）。
* `Spec` の **状態を変更する** 各操作の事後の関係 `step` は、通常の結果に加えて次の結果を許す。
  * 出力は `Conflict`。
  * 事後の状態は、採番の前進（[spec/ports.md](../spec/ports.md#idgenerator)）を除いて、事前の状態と等しい。
* 実行可能な `Spec` の標準の選択 `run` は、`Conflict` を選ばない。そのため、`spec/` のベクタに `Conflict` は現れない。
* 状態を変更しない操作（照会・計算）は、`Conflict` を返さない。移植先は、照会を直列化の失敗が起きない方法（例: PostgreSQL の `READ ONLY DEFERRABLE`）で実行するか、成功するまで再試行する。
* 画面では 500 のシステムエラー画面（`e.ar.fw.9999`）とする。REST では 409、`code = "e.ar.fw.9999"` とする（[spec/http-contract.md](../spec/http-contract.md#apierror)）。
* 原典が同じ状況で返す応答も、この結果で模倣される。原典の応答は、REST では 409、画面ではシステムエラーである。そのため、移植元側の差異にはならない。
* 直列化可能性そのもの、すなわち並行実行が逐次実行のどれかと一致することは、モデルの外の要件である（[spec/ports.md](../spec/ports.md#トランザクション) の規範節）。各モデルでは、操作は原子的に実行される。実際の並行実行とモデルとの一致は、[spec/assurance.md](../spec/assurance.md) に限界として扱う。

### 実行環境の失敗

* 同じ考え方で、ポートの I/O の失敗も `Spec` の非決定的な結果とする。例は、DB に接続できない場合や、ファイルの書き込みが失敗する場合である。
  * ポートの各操作は、通常の結果に加えて `System`（I/O 失敗のコード）を返しうる。
  * そのユースケースは、採番以外の状態を変えない。
  * 実行可能な `Spec` の標準の選択は、この結果を選ばない。
* 対象の操作とコードは [spec/ports.md](../spec/ports.md) に定める。

### 活性の限界

* 常に `Conflict`（または I/O 失敗）を返す実装も、`Spec` をリファインしてしまう。リファインメントは安全性を保証するが、活性（いつかは成功すること）は保証しない。
* 活性は、次の 2 つでだけ確かめる。
  * ベクタ: 標準の選択と同じく、`Conflict` が出ないこと
  * 結合テスト
* この限界を [spec/assurance.md](../spec/assurance.md) に載せる。

### Consequences

* Good, because 実装が `Conflict` を返すことが、仕様にある振る舞いになる
* Good, because 楽観ロックなど、多様な実装を許しつつリファインメントが成り立つ
* Bad, because `Spec` の状態変更操作が非決定的な関係になり、実行可能な標準の選択との 2 本立てになる

### Confirmation

* 状態を変更する各操作について、`Spec` の定理「`Conflict` の結果では採番以外の状態が不変」を証明する。
* `Refinement` の R 課題（[spec/refinement.md](../spec/refinement.md)）の正しさの PO で、`TargetModel` の `Conflict` の結果が `Spec` の `Conflict` の結果で模倣されることを示す。
* REST アダプタの結合テストで、`Conflict` が 409 になることを確認する。

## Pros and Cons of the Options

### `Spec` の非決定的な結果

* Good, because 原則 2 を満たし、仕様にない振る舞いが無くなる
* Bad, because `Spec` に関係と標準の選択の 2 本立てが必要

### 移植先の既知差異

* Good, because `Spec` を決定的なまま保てる
* Bad, because 実装が仕様にない振る舞いをすることになり、差異の前提「競合が起きない」は並行実行では成り立たない

## More Information

* 本 ADR は [ADR 0029](0029-concurrency-failure-as-conflict-error.md) を置き換える。
* [ADR 0039](0039-refinement-non-vacuity-obligations.md) で次のように補った。
  * `Conflict` と I/O の失敗を、環境の非決定性 N-001・N-002 として登録した。
  * 具体側では、環境を入力の成分として表す。障害の無い環境ではこれらを選べないこと（`Refines.Pinned`）を、R 課題に課す。これにより、移植元の不具合による失敗がこれらの結果に紛れなくなる。
* [ADR 0008](0008-errors-as-values-with-stable-codes.md)（エラー分類）, [ADR 0011](0011-persistence-and-transaction-semantics.md), [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)
