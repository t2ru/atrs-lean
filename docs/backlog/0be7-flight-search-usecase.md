---
type: Backlog Item
title: "空席照会（B1）"
description: "照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。"
tags: [backlog, spec, source-model, flight-search]
id: "0be7c5d4-01d9-43f4-a50d-227f174830f0"
state: todo
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "c7e8d83d-8d90-44fe-a6f5-de54b2efe811", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:18:59+09:00
---

# 空席照会（B1）

## 目的

SQL に業務ロジックを含む最初の機能を、LangSemantics.Sql を使って忠実に写す。

## 範囲

- `Spec.FlightSearch`
- `SourceModel.Repository.Flight`（`findByVacantSeatSearchCriteria` を SQL 式で）と `SourceModel.FlightSearch`
- ABS-010（L）, ABS-011（R。INV MD-5 の下で、SQL の許されるすべての結果について）
- 翌日着の便（到着時刻 `2415`。シードの NTT523・NTT528）
  - `Spec.MasterData.FlightMaster.arrivalTime` を、翌日着を表せる形に改める。
  - [Source] の `DateTimeParseException` を既知差異 D-NNN として登録する（W 課題を含む）。
  - fixture の `outsideSpec` を外す（[master-data.md](../spec/master-data.md)、[ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md)）。
- ベクタ

## 対象外

- HTTP（[backlog a89e](a89e-http-contract-adapter.md)）

## 完了条件

- [ ] [flight-search.md](../spec/flight-search.md) の例がベクタで通る
- [ ] ABS-010, ABS-011 を証明した（ABS-011 は `Machine.Refines` の形。運賃計算の `dev_D001`・`dev_D002` を引き継ぐ）
- [ ] 空席照会の SPEC-001 を証明し、`source-model/` ベクタが Java オラクルと一致する
- [ ] SQL `findByVacantSeatSearchCriteria` の写しを PostgreSQL での差分実行で照合した

## 参照

- [flight-search.md](../spec/flight-search.md)
- [ADR 5fcb](../decision/5fcb-sql-semantics-for-source-repositories.md)
