---
type: Backlog Item
title: "空席照会（B1）"
description: "照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。"
tags: [backlog, spec, source-model, flight-search]
id: "0006"
state: todo
depends_on: ["0004", "0016"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 空席照会（B1）

## 目的

SQL に業務ロジックを含む最初の機能を、LangSemantics.Sql を使って忠実に写す。

## 範囲

- `Spec.FlightSearch`
- `SourceModel.Repository.Flight`（`findByVacantSeatSearchCriteria` を SQL 式で）と `SourceModel.FlightSearch`
- ABS-010, ABS-011
- ベクタ

## 対象外

- HTTP（[backlog 0014](0014-http-contract-adapter.md)）

## 完了条件

- [ ] [flight-search.md](../spec/flight-search.md) の例がベクタで通る
- [ ] ABS-010, ABS-011 を証明した

## 参照

- [flight-search.md](../spec/flight-search.md)
- [ADR 0019](../decision/0019-sql-semantics-for-source-repositories.md)
