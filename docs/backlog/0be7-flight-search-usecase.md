---
type: Backlog Item
title: "空席照会（B1）"
description: "照会可能期間・運賃種別の予約可能判定・searchFlight を両モデルで実装し、ABS-010/011 を証明する。"
tags: [backlog, spec, source-model, flight-search]
id: "0be7c5d4-01d9-43f4-a50d-227f174830f0"
state: done
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
  - `Spec.Env.MasterData.FlightMaster.arrivalTime` を、翌日着を表せる形に改める。
  - [Source] の `DateTimeParseException` を既知差異 D-031 として登録する。例外は空席照会でなく、予約（B2）の往復便の検査で起きる（W 課題 ABS-131 は [backlog aedf](aedf-reservation-usecase.md) で証明する）。
  - fixture の `outsideSpec` を外す（[`Spec.Env.MasterData`](../../lean/Spec/Env/MasterData.lean)、[ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md)）。
- ベクタ

## 対象外

- HTTP（[backlog a89e](a89e-http-contract-adapter.md)）
- `source-model/` ベクタと Java の原典実行との一致（[backlog f18c](f18c-java-oracle-harness.md) に移した。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)。プロジェクトオーナーの決定）

## 進め方

3 段に分ける（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)。プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 第 1 段 | `Spec.FlightSearch`・`SourceModel.FlightSearch`（SQL の `Bag` 式を含む）の関数、`Spec.World`、到着時刻 `ArrivalTime`、D-031 の登録、共有ベクタ |
| 第 2 段 | 初期状態（シード 00250 の展開）、FLIGHT 表を含む PostgreSQL での差分実行、`Spec`・`SourceModel` の機械と SPEC 課題。FLIGHT の α（`FlightDb` → `World`）と D-027 の範囲の拡大（状態の表の値・導出した日付）、PRE への `World.RefMaster`、具体機械の 1 歩の `mo.Allowed`・`SortAllowed`（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md) の敵対的レビュー） |
| 第 3 段 | ABS-010・ABS-011 の証明と、トップレベルの主定理（`Abstraction.refines`・`preserves`・`abstracts`）への統合 |

## 完了条件

- [x] [`Spec.FlightSearch`](../../lean/Spec/FlightSearch.lean) の例がベクタで通る
- [x] ABS-010, ABS-011 を証明した（ABS-011 は `Machine.Refines` の形。運賃計算の `dev_D001`・`dev_D002` を引き継ぐ）
- [x] 空席照会の SPEC-001 を証明した
- [x] SQL `findByVacantSeatSearchCriteria` の写しを PostgreSQL での差分実行で照合した
- [x] 翌日着の便を [Spec] で表し、fixture の `outsideSpec` を外し、D-031 を登録した

## 第 1 段の結果

2026-11-01 に完了した（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。

- [Spec]: `ArrivalTime`（翌日着）、`Spec.Error`、`Spec.World`（`Inv`・`RefMaster`）、`Spec.FlightSearch`（照会可能期間・運賃種別の予約可能判定・`searchFlight`）。
- [Source]: `SourceModel.Repository.Flight`（SQL の `Bag` 式と許される並べ方）、FLIGHT の行と `flight-map`、`SourceModel.FlightSearch`（`searchFlight`・`runSearchFlight`）。スキルの `LangSemantics.Java` に `String.substring` と `DecimalFormat` を足した（スキルの版 0.15）。
- 翌日着の便を [Spec] で表し、fixture の `outsideSpec` を外した。ABS-026 の証明は、到着時刻の葉 `arrOfStr` で通る。
- 既知差異: D-031（往復便の検査の `DateTimeParseException`）、D-032（運賃の書式の既定ロケール）を登録した。D-014・D-027 に ABS-011 を加えた。
- ベクタ `conformance/shared/flight-search/` の 21 件が、`Spec` と `SourceModel` の両方で通る（期待値は仕様の例と手計算で確かめた。敵対的レビューで独立に再計算した）。
- 完了条件のうち「flight-search.md の例がベクタで通る」と「翌日着の便を表し、D-031 を登録した」を満たした。残りは第 2・3 段で行う。

## 第 2 段の結果

2026-11-01 に完了した（[ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)）。

- シード 00250 の生成器 `tools/conformance/flight_seed.py` を置いた。生成の形（121 日 × 便名 126 × 枠 10、空席数のパターン 3）のまま、`Spec.Seed.Flight` と `SourceModel.Db.FlightSeed` を書き出す。
- [Spec]:
  - `world_inv`（主キーの一意性）と `world_refMaster` を、全件に展開せずに証明した。
  - 抽象機械 `searchMachine`（選択を持たない `ofChoice`。状態を変えない）を置いた。
  - `searchFlight_isSome` と SPEC-001・002・003・007 を証明した。
- [Source]:
  - 具体機械 `searchConcrete` を置いた。状態は FLIGHT 表、業務例外は出力の値で、1 歩は `mo.Allowed`・`SortAllowed` を課す。
  - 条件の押し下げ `vacantSeatRows_eq_on` を証明した（スキルの補題 `cross_filter_left`・`select_filter_of_imp`。スキルの版 0.16）。
- PostgreSQL での差分実行:
  - 00250 を投入日で実行した FLIGHT 表を、生成器の展開（md5）と `seedFlightDb`（多項式ハッシュ）に照合した。
  - `findByVacantSeatSearchCriteria` の 13 の条件の結果が、モデルの許される並びであることを確かめた（`conformance/sql/flight-search.json`、`Tests.FlightSql`、検査 `pg-flight-sql`）。
- D-027 の範囲を状態の表に広げ、α `flightOfRow`・`worldOfDb` と核の定理（ABS-048）を置いた。
- 第 3 段に申し送るもの: 初期状態の対応（`worldOfDb seedFlightDb = some world`）、ABS-010・ABS-011 とトップレベルへの統合、D-032 の述語。

## 第 3 段の結果

2026-11-01 に完了した（[ADR 0b0c](../decision/0b0c-flight-search-stage3-abs011.md)）。

- R 課題 ABS-011 `Abstraction.FlightSearch.searchRefines`（`Machine.Refines`）と、束 `searchPreserves`（`ch`・D-032 の `outsC` の層を含む）を証明した。
  - 1 歩の対応 `Run.run_spec` は、下位のモジュールの補題を合わせる。
  - 結合（`Join`・`Candidates`）、整列（`Order`。同順位が無いこと `noTie_cands`）、Provider（`Providers`）、畳み込み（`Group`）、期間（`Period`）、初期状態（`Init`）の補題である。
- L 課題 ABS-010 `Period.isAvailableFareType_between` を証明した。
- W 課題 ABS-132 `need_D032`（区切り文字 `.`）と ABS-114 `need_D014`（共有サービスの今日だけが進む）を証明した。証人は `Witness`。
- PRE を改めた。`World.RefMaster` を外し、照会の搭乗クラスがマスタにあることと、便マスタの便名が空白でないこと（`FlightNamesHaveText`）を課す。
  - 空白の便名での [Source] の例外を、PRE の外の差異 D-033 として登録した（プロジェクトオーナーの確認待ち）。
- 具体側の入力に、区切り文字 `groupingSeparator`（D-032）と、共有サービスが読む今日 `sharedClock`（D-014）を置いた。
  - 述語は `dev_D032`・`dev_D014S`。D-014 は計画では述語を置かない案だった。[Source] の 3 回の Clock の読み出しをモデルの形に隠さないため、述語を置いた。
- トップレベルの主定理 `Abstraction.refines`・`preserves`・`abstracts` に、空席照会を 5 番目の成分として加えた。
- `trace/features.json` の FlightSearch を 0be7 の範囲に絞り、移植元側の検査が失敗扱いで通ることを確かめた。HTTP の層は Http（a89e）、予約が使う文・メソッドは Reserve（aedf）へ移した。
- スキルに汎用の補題を足した（版 0.17）。

## 参照

- [`Spec.FlightSearch`](../../lean/Spec/FlightSearch.lean)
- [ADR 5fcb](../decision/5fcb-sql-semantics-for-source-repositories.md)
- [ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)
- [ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)
- [ADR 0b0c](../decision/0b0c-flight-search-stage3-abs011.md)
