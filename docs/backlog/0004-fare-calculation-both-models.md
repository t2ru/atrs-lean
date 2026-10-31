---
type: Backlog Item
title: "運賃計算（Spec と SourceModel）"
description: "基本運賃・運賃・合計金額を Spec（厳密整数）と SourceModel（LangSemantics.Java）の両方で実装する。"
tags: [backlog, spec, source-model, fare]
id: "0004"
state: doing
depends_on: ["0002", "0003", "0016", "0027", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:18:59+09:00
---

# 運賃計算（Spec と SourceModel）

## 目的

二層モデルの最初の具体例として、差異が実在する運賃計算を両モデルで実装する。

## 範囲

- `Spec.Fare`: `basicFare`, `fare`, `totalFare`
- `SourceModel.Fare`: `calculateBasicFare`, `calculateFare`, `calculateTotalFare`（原典名）
- `conformance/spec/fare/`, `conformance/source-model/fare/`, `conformance/shared/fare/` のベクタ
- `SourceModel.MasterData`・`CodeList`・`Config`（マスタの Mapper の SQL を含む）と、R 課題 ABS-026（[abstraction.md](../spec/abstraction.md#証明課題)）

## 対象外

- 証明（[backlog 0005](0005-fare-abstraction-proofs.md)）

## 完了条件

- [x] [fare-calculation.md](../spec/fare-calculation.md) の全例がベクタ化され、両モデルで通る
- [ ] ABS-026 を証明し、マスタの Mapper の SQL を PostgreSQL での差分実行で照合した
- [x] 1430 円・30% の例で [Spec] 1100、[Source] 1000 になる

## 進め方

2 段に分ける（2026-10-31 の決定）。この項目は第 2 段で `done` にする。細部は [ADR 0042](../decision/0042-fare-source-model-and-shared-vectors.md) で決めた。

- **第 1 段（済み）**: 運賃計算の `Spec`・`SourceModel` と、両モデルで実行するベクタ
- **第 2 段（残り）**
  - マスタの Mapper の SQL（`findAll` など）を `LangSemantics.Sql` で写す（`SourceModel.Repository.*`）
  - seed を入れた PostgreSQL で差分実行し、照合する
  - Provider の `load`（`FareTypeProvider`・`RouteProvider`・`FlightMasterProvider` を含む）、`CodeList`・`Config` の読み込みを写す
  - ABS-026 を証明する

## 第 1 段の結果

- Lean
  - `Spec.Fare`: `basicFare`・`fare`・`routeOfFlight`・`childNum`・`flightTotal`・`totalFare`
  - `SourceModel.Model`: 原典の domain model
  - `SourceModel.MasterData`: `BoardingClassProvider`・`PeakTimeProvider` のキャッシュと参照
  - `SourceModel.Fare`: `calculateBasicFare`・`calculateFare`・`ceilFare`・`calculateTotalFare`
  - `LangSemantics.Java.JHashMap` を追加した。
- 1430 円・30% の例: 定理 `Spec.Fare.fare_1430_30`（1100）と `SourceModel.Fare.calculateFare_1430_30`（1000）
- ベクタ（`lake test` で実行）
  - `shared/fare/`（13 件）は、`Spec` と `SourceModel` の両方で実行する。
    - 内訳は `basicFare` 4 件・`fare` 5 件・`totalFare` 4 件。
  - `spec/fare/`（1 件）と `source-model/fare/`（1 件）は、1430 円の例。
- 共有入力: `conformance/fixtures/master-data.json`・`config.json` を、上流のシードから生成する（`tools/conformance/master_fixture.py`。CI で最新であることを確かめる）。
- 追跡
  - `@[source]` を 9 件付けた（運賃の 4 定義と、Provider の参照 2 つ）。
  - `tools/trace rehash` で、`lake-test` の合格を記録した。最初の実データでの rehash である。
  - `traceability.md` の生成区画に 9 件の対応が出る。
- 見つかったこと: 上流のシードの便マスタに、到着時刻 `2415`（翌日着）が 2 件ある。
  - プロジェクトオーナーの決定で、[Spec] で翌日着を表せるように改める（[backlog 0006](0006-flight-search-usecase.md)）。
  - それまでは、fixture の `outsideSpec` で Spec の読み込みから除く（ADR 0042）。

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [ADR 0042](../decision/0042-fare-source-model-and-shared-vectors.md)
