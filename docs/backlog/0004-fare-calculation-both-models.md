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
  at: 2026-10-31T13:25:01+09:00
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
- [ ] fare-calculation.md の例を、`run` から写さずに期待値を手で書いた検査（拒む例を含む）で [Spec] に照らした（意図から書く例。[ADR 0043](../decision/0043-vacuity-literature-necessity-and-mutation.md)）

## 進め方

2 段に分ける（2026-10-31 の決定）。この項目は第 2 段で `done` にする。細部は [ADR 0042](../decision/0042-fare-source-model-and-shared-vectors.md) で決めた。

- **第 1 段（済み）**: 運賃計算の `Spec`・`SourceModel` と、両モデルで実行するベクタ
- **第 2 段**は、さらに a・b に分けた（2026-10-31 の決定）。細部は [ADR 0045](../decision/0045-master-data-source-model-and-spec-fixes.md) で決めた。
  - **2a（済み）**: [Spec] の修正、マスタ・設定・コードリストの読み込みの `SourceModel`、PostgreSQL での差分実行、差異 D-027 の登録
  - **2b** は、さらに 2b-1・2b-2 に分けた（2026-10-31 の決定）。細部は [ADR 0046](../decision/0046-abs-026-proof-structure-nop-and-d027-scope.md) で決めた。
    - **2b-1（済み）**: ABS-026 の補題と [Spec] の修正（MD-8 の `NOP`、D-027 の範囲）
    - **2b-2（残り）**: ABS-026 の主定理と付帯の義務（`InitSurj`・`Sound`・`InitIs`、`dev_D027` の `@[deviation]` と `Nontrivial`、`std_abs` の α と核、必要性 G9）、W 課題 ABS-127。この項目は 2b-2 で `done` にする

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

## 第 2 段 b-1 の結果

- [Spec] の修正
  - MD-8 に「空港のコードは `NOP` でない」を加えた（`Spec.MasterData.airportNopCode`）。`Tests.SpecChecks` に違反例を加えた。
  - D-027 の対象を、具体側の入力全体（DB・設定・問い合わせの引数）に広げた（[abstraction.md](../spec/abstraction.md#既知差異)）。
- `LangSemantics.Java` の誤りの修正: `LocalDate` の `toEpochDay`・`ofEpochDay` が、負の年で JVM と食い違っていた（0 方向の除算のつもりで床除算に写していた）。床除算で書き直し、JVM の突き合わせ表に負の年と範囲の端を加えた。
- 補題（どれも `sorry`・公理・`native_decide` なし。`@[obligation]` は付けない）

| モジュール | 補題 | 内容 |
| --- | --- | --- |
| スキル `LangSemantics.Java.LocalDateLemmas` | `toEpochDay_ofEpochDay` | すべての整数 `z` で `toEpochDay (ofEpochDay z) = z`。周期の中の範囲は `decide +kernel` で確かめる |
| スキル `LangSemantics.Java.HashMapLemmas` | `ofList_entries`・`get_ofList` | キーが重複しない列の `ofList` は列そのもので、`get` は列の `find?` |
| スキル `LangSemantics.Java.Int` | `J32.val_ofInt_of_inRange` | 値域内の整数は `int` にしても変わらない |
| スキル `LangSemantics.Sql.Core` | `Truth.holds_and`・`SqlValue.eq_text_holds`・`eq_int_holds` | `AND` と等号の採否 |
| `Abstraction.Prim.Date` | `toEpochDay_eq_epochDay` | [Spec] の暦日の通算日数と `LocalDate.toEpochDay` の一致 |
| `Abstraction.Prim.List` | `find?_perm`・`filter_key_eq_singleton`・`filter_cross` | 一意な検索は並べ替えで変わらない。キーでの選択。結合の 1 段 |
| `Abstraction.Prim.Order` | `allowed_map_eq_mergeSort` | キーが一意なら、`ORDER BY` の許される順列は [Spec] の `mergeSort` に一致する |
| `Abstraction.MasterData.Join` | `routeFindAll_eq`・`flightMasterFindAll_eq` | 結合の結果は、左の表の行ごとに 1 行 |
| `Abstraction.MasterData.Key` | `makeCacheKey_inj` | `-` を含まない空港コードでは、キャッシュのキーは単射 |
| `Abstraction.MasterData.Load` | `boardingClassLoad_eq`・`fareTypeLoad_eq`・`routeLoad_eq`・`flightMasterLoad_eq` | `load()` は例外を投げず、キャッシュは（キー, 値）の列の `ofList` |
| `Abstraction.MasterData.CodeList` | `airport_eq_insertNop`・`jdbcCodeList_eq` | 空港コードリストは [Spec] の `insertNop` に、DB のコードリストは行の列に一致する |

## 参照

- [fare-calculation.md](../spec/fare-calculation.md)
- [ADR 0042](../decision/0042-fare-source-model-and-shared-vectors.md)、[ADR 0045](../decision/0045-master-data-source-model-and-spec-fixes.md)、[ADR 0046](../decision/0046-abs-026-proof-structure-nop-and-d027-scope.md)
