---
type: Backlog Item
title: "運賃計算（Spec と SourceModel）"
description: "基本運賃・運賃・合計金額を Spec（厳密整数）と SourceModel（LangSemantics.Java）の両方で実装する。"
tags: [backlog, spec, source-model, fare]
id: "25f7ef96-f77d-4ed8-973d-8cecc2a0f227"
state: doing
depends_on: ["a8be97e4-d846-4b86-bfcc-413d6d980578", "591d9aa4-065b-4975-8146-86aae05b780a", "c7e8d83d-8d90-44fe-a6f5-de54b2efe811", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T11:02:17+09:00
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

- 証明（[backlog bbcc](bbcc-fare-abstraction-proofs.md)）

## 完了条件

- [x] [fare-calculation.md](../spec/fare-calculation.md) の全例がベクタ化され、両モデルで通る
- [ ] ABS-026 を証明し、マスタの Mapper の SQL を PostgreSQL での差分実行で照合した
- [x] 1430 円・30% の例で [Spec] 1100、[Source] 1000 になる
- [ ] fare-calculation.md の例を、`run` から写さずに期待値を手で書いた検査（拒む例を含む）で [Spec] に照らした（意図から書く例。[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）

## 進め方

2 段に分ける（2026-10-31 の決定）。この項目は第 2 段で `done` にする。細部は [ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md) で決めた。

- **第 1 段（済み）**: 運賃計算の `Spec`・`SourceModel` と、両モデルで実行するベクタ
- **第 2 段**は、さらに a・b に分けた（2026-10-31 の決定）。細部は [ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md) で決めた。
  - **2a（済み）**: [Spec] の修正、マスタ・設定・コードリストの読み込みの `SourceModel`、PostgreSQL での差分実行、差異 D-027 の登録
  - **2b（残り）**: ABS-026 の証明と付帯の義務（`InitSurj`・`Sound`・`InitIs`、`dev_D027` の `@[deviation]` と `Nontrivial`、`std_abs` の α と核）、W 課題 ABS-127。この項目は 2b で `done` にする

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
  - プロジェクトオーナーの決定で、[Spec] で翌日着を表せるように改める（[backlog 0be7](0be7-flight-search-usecase.md)）。
  - それまでは、fixture の `outsideSpec` で Spec の読み込みから除く（ADR 8f18）。

## 第 2 段 a の結果

- [Spec] の修正（プロジェクトオーナーの決定を含む）
  - `Spec.Route.flightTime` を削除した（原典のどの処理も読まない）。
  - MD-8 に「空港コードは英大文字 3 文字」を足した。
  - 参照の機械を `Spec.MasterQuery` に移し、次の変更を加えた。
    - 設定・コードリストの問い合わせを足した。
    - 問い合わせの引数の値域を PRE に足した。
    - SPEC-007（`queryMachine_initIs`）を足した。
- `LangSemantics.Sql.Postgresql` に、範囲を持つ列の型 `Int4`・`PgDate`・`Varchar n` を足した。
  - 物理的なビット幅ではなく、範囲の制限を再現する（プロジェクトオーナーの指示）。
  - 日付の範囲は PostgreSQL 16.15 と突き合わせた。
- `LangSemantics.Java` に `JLinkedHashMap` を足した。
- `SourceModel` に次を足した。

  | 名前空間 | 内容 |
  | --- | --- |
  | `Repository.Schema` | 表 8 つ |
  | `Repository.MasterData` | Mapper の文 5 つと、コードリストの SQL 4 つ |
  | `Repository.Mapping` | MyBatis の対応 |
  | `MasterData` | Provider 5 つの `load()` と参照 |
  | `CodeList` | terasoluna の `JdbcCodeList` はソースで確かめた |
  | `Config` | 注入される設定 |
  | `MasterQuery.queryConcrete` | 具体機械。許される並びのどれかで読み込む |

- ベクタ
  - `shared/master-data/`（23 件）は、`Spec` と `SourceModel` の両方で実行する。
  - `source-model/master-data/` は、到着時刻 `2415` の便。D-027 の前提の外である。
- PostgreSQL での差分実行
  - `tools/conformance/master_sql.py` が `conformance/sql/master-data.json` を生成する。
  - `lake test` の `Tests.MasterSql` が、9 文を照合する。順序の無い文はバッグとして、`ORDER BY` は許される順列として照合する。
  - あわせて、共有入力の表 8 つと設定の一致も確かめる。
  - `trace/checks.json` に `pg-master-sql` を登録した。
- 追跡
  - `@[source]` を 45 件追加した。種類は `sql:`・`ddl:`・`prop:`・Provider・コードリスト・`dep:`。
  - `rehash` で `lake-test`・`pg-master-sql` の合格を記録した。
  - `trace/upstream.json` に `terasoluna-gfw-common`・`spring-core` を宣言した。
- 差異: D-027（前提型・具体側の入力。DB の値が [Spec] の型で表せる）と W 課題 ABS-127 を登録した。Lean の `@[deviation]` は 2b で書く。

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md)、[ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md)
