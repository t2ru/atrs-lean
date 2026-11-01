---
type: Backlog Item
title: "空席照会（B1）"
description: "照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。"
tags: [backlog, spec, source-model, flight-search]
id: "0be7c5d4-01d9-43f4-a50d-227f174830f0"
state: doing
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "c7e8d83d-8d90-44fe-a6f5-de54b2efe811", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:18:59+09:00
---

# 空席照会（B1）

## 目的

SQL に業務ロジックを含む最初の機能を、LangSemantics.Sql を使って忠実に写す。

## 範囲

- `Spec.FlightSearch`・`Spec.Port`（`World`）
- `SourceModel.Repository.Flight`（`findByVacantSeatSearchCriteria` を SQL 式で）と `SourceModel.FlightSearch`
- ABS-010（L）, ABS-011（R。INV MD-5 の下で、SQL の許されるすべての結果について）
- 翌日着の便（到着時刻 `2415`。シードの NTT523・NTT528）
  - `Spec.MasterData.FlightMaster.arrivalTime` を、翌日着を表せる形に改める。
  - [Source] の `DateTimeParseException` を既知差異 D-031 として登録する。例外は空席照会でなく、予約（B2）の往復便の検査で起きる（W 課題 ABS-131 は [backlog aedf](aedf-reservation-usecase.md) で証明する）。
  - fixture の `outsideSpec` を外す（[master-data.md](../spec/master-data.md)、[ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md)）。
- ベクタ

## 対象外

- HTTP（[backlog a89e](a89e-http-contract-adapter.md)）
- `source-model/` ベクタと Java オラクルとの一致（[backlog f18c](f18c-java-oracle-harness.md) に移した。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)。プロジェクトオーナーの決定）

## 進め方

3 段に分ける（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)。プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 第 1 段 | `Spec.FlightSearch`・`SourceModel.FlightSearch`（SQL の `Bag` 式を含む）の関数、`Spec.Port.World`、到着時刻 `ArrivalTime`、D-031 の登録、共有ベクタ |
| 第 2 段 | 初期状態（シード 00250 の展開）、FLIGHT 表を含む PostgreSQL での差分実行、`Spec`・`SourceModel` の機械と SPEC 課題 |
| 第 3 段 | ABS-010・ABS-011 の証明と、トップレベルの主定理（`Abstraction.refines`・`preserves`・`abstracts`）への統合 |

## 完了条件

- [ ] [flight-search.md](../spec/flight-search.md) の例がベクタで通る
- [ ] ABS-010, ABS-011 を証明した（ABS-011 は `Machine.Refines` の形。運賃計算の `dev_D001`・`dev_D002` を引き継ぐ）
- [ ] 空席照会の SPEC-001 を証明した
- [ ] SQL `findByVacantSeatSearchCriteria` の写しを PostgreSQL での差分実行で照合した
- [ ] 翌日着の便を [Spec] で表し、fixture の `outsideSpec` を外し、D-031 を登録した

## 第 1 段の結果

（第 1 段の完了時に記す）

## 参照

- [flight-search.md](../spec/flight-search.md)
- [ADR 5fcb](../decision/5fcb-sql-semantics-for-source-repositories.md)
- [ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)
