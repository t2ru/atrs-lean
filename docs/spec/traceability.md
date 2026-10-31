---
type: Specification
title: "追跡（トレーサビリティ）"
description: "ATRS の両端の追跡: 使うロケータ種別、運賃計算の追跡例と検査の判定、生成表、予定対応、対象外。方式はスキル port-lang に従う。"
tags: [spec, traceability]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:30:00+09:00
---

# 追跡（トレーサビリティ）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

方針は [ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md)（構成）、[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)（追跡の方式）、[ADR 3f36](../decision/3f36-following-upstream-releases.md)（版上げ）。

```
移植元ソース  ⇔①⇔  SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel  ⇔②⇔  移植先ソース
(Java/SQL)                                                                         (Rust)
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側（`SourceModel` ↔ `Spec` ↔ `TargetModel`）は、追跡ではなく **証明** でつながる。証明は、B メソッドのリファインメントである `Abstraction`・`Refinement` である（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)）。
- 追跡は対応を示すだけである。一致は、決定論的な検査で確かめる（[assurance.md](assurance.md)）。注釈のハッシュは、その検査が合格した版の記録である。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。

## 方式

ロケータの文法、版の宣言とインベントリ、注釈と検査済みハッシュ、検査（TR-S1〜TR-R。TR-D・TR-K・TR-G・TR-N・TR-V・TR-PE を含む）、道具は、スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/docs/traceability.md) に従う（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)）。
ATRS が使うロケータの種別は次のとおり（文法は各言語パックの `locators.md`）。

| 側 | 種別 | 言語パック |
| --- | --- | --- |
| 移植元 | `java:` `prop:` `msg:` `http:` `xml:` `tmpl:` | [java/locators.md](../../.agents/skills/port-lang/references/docs/java/locators.md) |
| 移植元 | `sql:` `ddl:` `seed:` | [sql/locators.md](../../.agents/skills/port-lang/references/docs/sql/locators.md) |
| 移植先 | `rust:`（クレート `atrs`） | [rust/locators.md](../../.agents/skills/port-lang/references/docs/rust/locators.md) |
| 両側 | `dep:` `lang:` | ATRS で必須の `dep:` は [atrs-porting.md](../rules/atrs-porting.md#source-に必ず含める依存atrs) |

道具は port-lang の `scripts/trace`（以下 `trace`。[backlog ffdc](../backlog/ffdc-trace-tooling.md)）である。細部（本文ハッシュ・正規化・ロケータの形・版の文字列・警告と誤りの区別）は [ADR 0eea](../../.agents/skills/port-lang/references/docs/decision/0eea-trace-tooling-unresolved-details.md) による。

| ファイル | 内容 | 作り方 |
| --- | --- | --- |
| `trace/source-inventory.json` | 移植元のインベントリ（上流の submodule の走査結果） | `trace inventory source` |
| `trace/target-inventory.json` | 移植先のインベントリ（`rust/src/` の走査結果と `/// trace: models` の札） | `trace inventory target` |
| `trace/manifest.json` | ノード・型付きのリンク・合格した検査の記録 | `trace manifest`（合格の記録は `trace rehash`） |
| `trace/project.json` | スキルの道具が読む ATRS の設定（crate 名・移植元/移植先の配置・文書のパス・言語の組・Lean のルート・ID の道具。形はスキルの [traceability.md](../../.agents/skills/port-lang/references/docs/traceability.md#プロジェクトの設定)） | 手で書く |
| `trace/features.json` | 機能と backlog・ロケータ・Lean の名前空間・R 課題の対応表。TR-S1・TR-T1・TR-P・TR-PE・TR-D の警告と誤りを決める | 手で書く |
| `trace/checks.json` | `rehash` が実行する決定論的な検査と、それが覆う Lean の定義（名前の glob と、ベクタの `modelDef`） | 手で書く（検査を足す backlog が登録する） |
| `trace/renames.json` | ハッシュで判別できない改名の対応 | 手で書く（版上げのとき） |

道具の細部のうち `rehash`・`diff`・`impact`・`checks.json`・`renames.json`・「出典:」の検査は [ADR 9cd9](../../.agents/skills/port-lang/references/docs/decision/9cd9-rehash-diff-impact-details.md) による。

| 使い方 | コマンド |
| --- | --- |
| 注釈のハッシュの更新（検査を実行し、合格した組だけ更新して manifest に記録する） | `trace rehash --dump <trace-dump.json>`（`--dry-run` で対象と検査を表示するだけ） |
| 新旧のインベントリの分類（版上げの手順 3） | `trace diff --old git:<rev>`（`--side target` で移植先） |
| 証明のグラフに沿った影響一覧（版上げの手順 5） | `trace impact --dump <trace-dump.json> --obligations <obligation-check.json> <ロケータ・Lean 名…>`（`--diff git:<rev>` で差分を起点にする） |

CI（`tools/ci/lean.sh`）は、インベントリ・manifest・下の生成区画が最新であることと、`trace check` の誤りが 0 件であることを確かめる。

## 例: 運賃計算（基本運賃）

### 注釈

```lean
-- lean/SourceModel/Fare.lean
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@<h1>",
         "lang:java#JLS-15.17.1@java-17"]
def calculateBasicFare ... -- [Source]

-- lean/Abstraction/Fare.lean
@[deviation "D-001"]
def dev_D001 : Spec.Fare.BasicFareInput → Prop := ...   -- 前提型の差異（ABS-101 で確定）

@[obligation "ABS-001"]
theorem basicFare_refines :
  Machine.Refines (Spec.Fare.basicFareMachine.restrict dev_D001)
                  SourceModel.Fare.basicFareMachine
                  basicFareGlue

-- lean/Spec/Fare.lean
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def basicFare ... -- [Spec]

-- lean/Refinement/Fare.lean
@[obligation "REF-004"]
theorem basicFare_target_refines_spec :
  Machine.Refines Spec.Fare.basicFareMachine
                  TargetModel.Fare.basicFareMachine
                  basicFareGlue

-- lean/TargetModel/Fare.lean
@[target "rust:atrs::fare::basic_fare@<h3>", "lang:rust#integer-overflow@<rust の版>"]
def basicFare ... -- [Target]
```

```rust
// rust/src/model/fare.rs   （lake exe gen-verus の生成物。手で編集しない）
/// trace: models TargetModel.Fare.basicFare @<m1>
pub open spec fn basic_fare(...) -> int { ... }

// rust/src/fare.rs   （移植元ロケータは書かない）
pub fn basic_fare(...) -> (r: u64)
    ensures r == model::fare::basic_fare(...)
{ ... }
```

### 検査の判定

| 検査 | この例での判定 |
| --- | --- |
| TR-S1 | `calculateBasicFare` は `@[source]` で覆われる。private の `getMultiplicationRatio` はインベントリの単位ではなく、その本文は `<h1>` に含まれる（[ADR 0eea](../../.agents/skills/port-lang/references/docs/decision/0eea-trace-tooling-unresolved-details.md)）。同じクラスの他のメソッドは、別の `SourceModel` 定義が覆う必要がある |
| TR-S2 | `<h1>` が `source-inventory` の現在値と一致し、`<h1>` と定義の Merkle の組に合格の記録があれば合格。上流の版上げで本文が変わると失敗する。`trace rehash` が、`trace/checks.json` で `SourceModel.Fare.calculateBasicFare` を覆う検査（`source-model/fare` のベクタの照合）を実行し、合格した場合に限ってハッシュを更新して記録する |
| TR-T1 | `TargetModel.Fare.basicFare` は `@[target]` を持つ。Rust の `atrs::fare::basic_fare` は覆われる。`atrs::model::fare::basic_fare`（写し）は TR-T2 で扱う |
| TR-T2 | `<h3>` が `target-inventory` と、`<m1>` が `TargetModel.Fare.basicFare` の Merkle ハッシュと一致すれば合格。Rust の本文を変えると `<h3>` がずれ、Lean を変えると `<m1>` がずれる |
| TR-P | `SourceModel.Fare.calculateBasicFare` は、R 課題 ABS-001 の具体機械 `SourceModel.Fare.basicFareMachine` の操作（定義が参照する定数の閉包）に含まれる。`TargetModel.Fare.basicFare` も同様に REF-004 の具体機械に含まれるので合格 |
| TR-D | D-001 の `Abstraction.Fare.dev_D001` が `@[deviation "D-001"]` を持ち、ABS-001 の型に現れ、W 課題 ABS-101 があれば合格 |
| TR-K | D-001 の登録 `Abstraction.Gap.D001`（`@[gap_entry]`）に対し、`Spec.Fare.basicFare` と `SourceModel.Fare.calculateBasicFare` が `@[gap "D-001"]` を持てば合格 |
| TR-X | Lean の移植元側に `rust:` が無く、Rust と `TargetModel` に `java:` が無いので合格 |
| TR-R | 参照先がすべて存在すれば合格 |

影響分析の例: 上流で `calculateBasicFare` の本文が変わると、TR-S2 → `SourceModel.Fare.calculateBasicFare` → ABS-001 → `Spec.Fare.basicFare` の順に影響が出る。印 `@[gap]` から、見直すギャップとして D-001・D-030 が出る。`Spec` を変えない判断なら、ここで止まる（`TargetModel`・Rust には影響しない）。

## 生成される表

以下の 2 本の表は `trace manifest` が生成する。生成区画の中を手で編集してはならない。

### ① 移植元ソース ⇔ SourceModel

<!-- BEGIN GENERATED: source-trace -->
移植元ソース ⇔ SourceModel: インベントリ 1963 件（対象範囲 1323 件、対象外 640 件）、対応あり 55 件。`trace manifest` が生成する（手で編集しない）。

| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |
| --- | --- | --- | --- |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()` | `SourceModel.CodeList.airportCodeList` | `ee05610976981369` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITMONTH()` | `SourceModel.CodeList.creditMonth` | `80b00a5795cfaa5b` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITYEAR()` | `SourceModel.CodeList.creditYear` | `8771de6e4c3fecac` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FLIGHTTYPE()` | `SourceModel.CodeList.flightType` | `53a98f3857bc2251` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_GENDER()` | `SourceModel.CodeList.gender` | `ae7bc36378865373` | lake-test |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#JdbcCodeList.retrieveMap` | `SourceModel.CodeList.jdbcCodeList` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#NumberRangeCodeList.afterPropertiesSet` | `SourceModel.CodeList.numberRange` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `prop:atrs.properties#atrs.adultPassengerMinAge` | `SourceModel.Config.upstreamConfig` | `6b51d431df5d7f14` | pg-master-sql |
| `prop:atrs.properties#atrs.childFareRate` | `SourceModel.Config.upstreamConfig` | `39fa9ec190eee7b6` | pg-master-sql |
| `prop:atrs.properties#atrs.dateOfBirthMinDate` | `SourceModel.Config.upstreamConfig` | `16b66d733ba7d984` | pg-master-sql |
| `prop:atrs.properties#atrs.limitDay` | `SourceModel.Config.upstreamConfig` | `69f59c273b6e669a` | pg-master-sql |
| `prop:atrs.properties#atrs.representativeMinAge` | `SourceModel.Config.upstreamConfig` | `4ec9599fc203d176` | pg-master-sql |
| `prop:atrs.properties#atrs.reserveIntervalTime` | `SourceModel.Config.upstreamConfig` | `2abaca4911e68fa9` | pg-master-sql |
| `prop:atrs.properties#default.arrAirportCd` | `SourceModel.Config.upstreamConfig` | `44f7c891ed8c4f86` | pg-master-sql |
| `prop:atrs.properties#default.boardingClassCd` | `SourceModel.Config.upstreamConfig` | `8ce86a6ae65d3692` | pg-master-sql |
| `prop:atrs.properties#default.depAirportCd` | `SourceModel.Config.upstreamConfig` | `44f7c891ed8c4f86` | pg-master-sql |
| `prop:atrs.properties#default.flightType` | `SourceModel.Config.upstreamConfig` | `3165be96f5833ae0` | pg-master-sql |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Fare.calculateBasicFare` | `9872678663e9a896` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Fare.calculateBasicFare` | `5b0822fe4c6991ac` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateFare(int,int)` | `SourceModel.Fare.calculateFare` | `8088a7f2c9efaf7e` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)` | `SourceModel.Fare.calculateFare` | `1e12eb714e2bc395` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)` | `SourceModel.Fare.calculateTotalFare` | `ca1a14757ce1cb33` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)` | `SourceModel.Fare.calculateTotalFare` | `35bc5d27ed5f2ca9` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)` | `SourceModel.Fare.ceilFare` | `345c1d9656b3930c` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#load()` | `SourceModel.MasterData.BoardingClassProvider.load` | `ea4f74c6c99e9b67` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll()` | `SourceModel.MasterData.BoardingClassProvider.load` | `a75e2344e7b09314` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#load()` | `SourceModel.MasterData.FareTypeProvider.load` | `accd51e500f0cb16` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll()` | `SourceModel.MasterData.FareTypeProvider.load` | `c01904394de5db65` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#load()` | `SourceModel.MasterData.FlightMasterProvider.load` | `42b24c5f9549b118` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster()` | `SourceModel.MasterData.FlightMasterProvider.load` | `0563c719a0a21f51` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#load()` | `SourceModel.MasterData.PeakTimeProvider.load` | `604b187a665e10c5` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll()` | `SourceModel.MasterData.PeakTimeProvider.load` | `4020414e93f77c78` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#load()` | `SourceModel.MasterData.RouteProvider.load` | `ce13818ba91368aa` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll()` | `SourceModel.MasterData.RouteProvider.load` | `3cd8d3e7f6409637` | lake-test |
| `dep:org.springframework:spring-core#Assert.hasText` | `SourceModel.MasterData.assertHasText` | `spring-core-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)` | `SourceModel.MasterData.getBoardingClass` | `363af6d3dd2e282d` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#getFareType(FareTypeCd)` | `SourceModel.MasterData.getFareType` | `8cca1518f179d5a0` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#getFlightMaster(String)` | `SourceModel.MasterData.getFlightMaster` | `73525e4cbaf2e787` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)` | `SourceModel.MasterData.getPeakTime` | `1b19d6cad612b687` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)` | `SourceModel.MasterData.getRouteByAirportCd` | `4266ccb1fdc24df9` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()` | `SourceModel.Repository.MasterData.airportCodeListRows` | `6236d6ba59dfd39c` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_BOARDINGCLASS()` | `SourceModel.Repository.MasterData.boardingClassCodeListRows` | `c0ccb970d9355072` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll` | `SourceModel.Repository.MasterData.boardingClassFindAll` | `9b228eec7b3acd6a` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITTYPE()` | `SourceModel.Repository.MasterData.creditTypeCodeListRows` | `14fc9ae274494f99` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FARETYPE()` | `SourceModel.Repository.MasterData.fareTypeCodeListRows` | `49649a5d73522449` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll` | `SourceModel.Repository.MasterData.fareTypeFindAll` | `7ff78a19a79f16de` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster` | `SourceModel.Repository.MasterData.flightMasterFindAll` | `ebfbc030ba80f150` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll` | `SourceModel.Repository.MasterData.peakTimeFindAll` | `52311345757d8bde` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll` | `SourceModel.Repository.MasterData.routeFindAll` | `0a9a6b28094e3e9a` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#AIRPORT` | `SourceModel.Repository.Schema.AirportRow` | `bf8ca7804ba932ce` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#BOARDING_CLASS` | `SourceModel.Repository.Schema.BoardingClassRow` | `74a735596ef8e4ee` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#CREDIT_TYPE` | `SourceModel.Repository.Schema.CreditTypeRow` | `22a8264dca01d374` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FARE_TYPE` | `SourceModel.Repository.Schema.FareTypeRow` | `25297f0a00f0d6fc` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FLIGHT_MASTER` | `SourceModel.Repository.Schema.FlightMasterRow` | `d92b2c0f805256a1` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PEAK_TIME` | `SourceModel.Repository.Schema.PeakTimeRow` | `2639ea660139925b` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PLANE` | `SourceModel.Repository.Schema.PlaneRow` | `31641da45eeb4327` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#ROUTE` | `SourceModel.Repository.Schema.RouteRow` | `b26d30be10a7908d` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)` | `SourceModel.Ticket.toFlightList` | `3fef600108b03c6e` | lake-test |
<!-- END GENERATED: source-trace -->

### ② TargetModel ⇔ 移植先ソース

<!-- BEGIN GENERATED: target-trace -->
TargetModel ⇔ 移植先ソース: インベントリ 0 件（対象範囲 0 件、対象外 0 件）、対応あり 0 件。`trace manifest` が生成する（手で編集しない）。

| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |
| --- | --- | --- | --- |
| （対応なし） | | | |
<!-- END GENERATED: target-trace -->

機能ごとの移植元の範囲（ロケータの glob）・Lean の名前空間・R 課題・backlog は [`trace/features.json`](../../trace/features.json) にある。道具ができる前の見取り図だった「初期の予定対応」の表は、これと生成表に置き換えて削除した。

## 対象外

`atrs-web/src/main/java/jp/co/ntt/atrs/app/common/logging/AccessLogFilter.java`、`atrs-env/**`、`atrs-selenium/**`、`atrs-web/src/main/webapp/**/*.html` の HTML 構造・静的資源（[ADR 84bf](../decision/84bf-porting-scope.md)）。一覧の正は [`trace/out-of-scope.json`](../../trace/out-of-scope.json) であり、各項目に ADR 84bf の該当節を書いている。

ただし、テンプレートのうち [Source] の観測可能な振る舞いに影響する式は、対象外にしない。たとえば支払期限の曜日の書式（`#temporals.format`。既知差異 D-019）がこれに当たる。これらは `tmpl:` ロケータで追跡する（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)）。
