---
type: Backlog Item
title: "Rust: DB・ファイル・時計のアダプタと TargetModel.Adapter"
description: "DB・ファイル・時計のアダプタを Rust で実装し、その振る舞いを TargetModel.Adapter（DB は LangSemantics.Sql の式）に写して REF-009 を証明し、SQL の差分実行（SRC-010）と結合テスト（SRC-005）で一致を確かめる。"
tags: [backlog, rust, adapter, refinement]
id: "0029"
state: todo
depends_on: ["0011", "0016", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Rust: DB・ファイル・時計のアダプタと TargetModel.Adapter

## 目的

本番で使う外部のアダプタも、移植先プログラムの一部である。原則 1・2（[ADR 0033](../decision/0033-foundational-principles.md)）を満たすため、次の 2 つを行う。

- 外部のアダプタを `TargetModel` に写し、`Spec` のポートの契約をリファインすることを証明する。
- Rust の実装とモデルの一致を、決定論的な手段で確かめる（[ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)）。

## 範囲

- `TargetModel.Adapter.Db`（DB アダプタの SQL を `LangSemantics.Sql` の式で写す）、`TargetModel.Adapter.File`、`TargetModel.Adapter.Clock`（Asia/Tokyo の変換）
- R 課題 REF-009。I/O の失敗を、[Spec] の非決定的な結果 `System` で模倣する（[ADR 0037](../decision/0037-conflict-as-spec-nondeterminism.md)）
- `rust/src/adapter/db`・`file`・`clock`（`#[verifier::external]`。[assurance.md](../spec/assurance.md#verifierexternal-の一覧) の一覧に載せる）
- SRC-010（SQL の差分実行）、SRC-005 のうち DB 分（SERIALIZABLE と再試行、照会は `READ ONLY DEFERRABLE`、固定の実行順の結合テスト）
- DB のクレートの選定（ADR を作る。版は `trace/target.json`）

## 対象外

- HTTP（[backlog 0014](0014-http-contract-adapter.md)）

## 完了条件

- [ ] REF-009 を `sorry` 無しで証明した
- [ ] SRC-005（DB 分）・SRC-010 が通る
- [ ] SRC-007・SRC-008（TR-T1・TR-T2・TR-D・TR-X）が通る
- [ ] SQL の差分実行で照合したデータと、結合テストの実行順を [assurance.md](../spec/assurance.md) の付録に記入した

## 参照

- [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md), [ADR 0037](../decision/0037-conflict-as-spec-nondeterminism.md)
- [refinement.md](../spec/refinement.md), [ports.md](../spec/ports.md), [port-lang/sql/verification.md](../../.agents/skills/port-lang/references/sql/verification.md)
