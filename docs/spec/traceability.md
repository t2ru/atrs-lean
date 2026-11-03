---
type: Specification
title: "追跡（トレーサビリティ）"
description: "ATRS の両端の追跡: 使うロケータ種別、運賃計算の追跡例と検査の判定、生成表、予定対応、対象外。方式はスキル spec-pivot に従う。"
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

ロケータの文法、版の宣言とインベントリ、注釈と検査済みハッシュ、検査（TR-S1〜TR-R。TR-D・TR-K・TR-G・TR-N・TR-V・TR-PE を含む）、道具は、スキル spec-pivot の [traceability.md](../../.agents/skills/spec-pivot/references/docs/spec/traceability.md) に従う（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)）。
ATRS が使うロケータの種別は次のとおり（文法は各言語パックの `locators.md`）。

| 側 | 種別 | 言語パック |
| --- | --- | --- |
| 移植元 | `java:` `prop:` `msg:` `http:` `xml:` `tmpl:` | [java/locators.md](../../.agents/skills/spec-pivot/references/docs/lang/java/locators.md) |
| 移植元 | `sql:` `ddl:` `seed:` | [sql/locators.md](../../.agents/skills/spec-pivot/references/docs/lang/sql/locators.md) |
| 移植先 | `rust:`（クレート `atrs`） | [rust/locators.md](../../.agents/skills/spec-pivot/references/docs/lang/rust/locators.md) |
| 両側 | `dep:` `lang:` | ATRS で必須の `dep:` は [atrs-porting.md](../rules/atrs-porting.md#source-に必ず含める依存atrs) |

道具は spec-pivot の `scripts/trace`（以下 `trace`。[backlog ffdc](../backlog/ffdc-trace-tooling.md)）である。細部（本文ハッシュ・正規化・ロケータの形・版の文字列・警告と誤りの区別）は [ADR 0eea](../../.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md) による。

| ファイル | 内容 | 作り方 |
| --- | --- | --- |
| `trace/source-inventory.json` | 移植元のインベントリ（上流の submodule の走査結果） | `trace inventory source` |
| `trace/target-inventory.json` | 移植先のインベントリ（`rust/src/` の走査結果と `/// trace: models` の札） | `trace inventory target` |
| `trace/manifest.json` | ノード・型付きのリンク・合格した検査の記録 | `trace manifest`（合格の記録は `trace rehash`） |
| `trace/project.json` | スキルの道具が読む ATRS の設定（crate 名・移植元/移植先の配置・文書のパス・言語の組・Lean のルート・ID の道具。形はスキルの [traceability.md](../../.agents/skills/spec-pivot/references/docs/spec/traceability.md#プロジェクトの設定)） | 手で書く |
| `trace/features.json` | 機能と backlog・ロケータ・Lean の名前空間・R 課題の対応表。TR-S1・TR-T1・TR-P・TR-PE・TR-D の警告と誤りを決める | 手で書く |
| `trace/checks.json` | `rehash` が実行する決定論的な検査と、それが覆う Lean の定義（名前の glob と、ベクタの `modelDef`） | 手で書く（検査を足す backlog が登録する） |
| `trace/renames.json` | ハッシュで判別できない改名の対応 | 手で書く（版上げのとき） |

道具の細部のうち `rehash`・`diff`・`impact`・`checks.json`・`renames.json`・「出典:」の検査は [ADR 9cd9](../../.agents/skills/spec-pivot/references/docs/decision/9cd9-rehash-diff-impact-details.md) による。

| 使い方 | コマンド |
| --- | --- |
| 注釈のハッシュの更新（検査を実行し、合格した組だけ更新して manifest に記録する） | `trace rehash --dump <trace-dump.json>`（`--dry-run` で対象と検査を表示するだけ） |
| 新旧のインベントリの分類（版上げの手順 3） | `trace diff --old git:<rev>`（`--side target` で移植先） |
| 証明のグラフに沿った影響一覧（版上げの手順 5） | `trace impact --dump <trace-dump.json> --obligations <obligation-check.json> <ロケータ・Lean 名…>`（`--diff git:<rev>` で差分を起点にする） |

CI（`mise run ci`）は、インベントリ・manifest・下の生成区画が最新であることと、`trace check` の誤りが 0 件であることを確かめる。

## 例: 運賃計算（基本運賃）

### 注釈

```lean
-- lean/SourceModel/Domain/Service/B0/TicketSharedServiceImpl.lean
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@<h1>",
         "lang:java#JLS-15.17.1@java-17"]
def calculateBasicFare ... -- [Source]

-- lean/Abstraction/Fare.lean
@[deviation "D-001"]
def dev_D001 : Spec.Fare.BasicFareInput → Prop := ...   -- 前提型の差異（ABS-101 で確定）

@[obligation "ABS-001"]
theorem basicFare_refines :
  Machine.Refines (Spec.Fare.basicFareMachine.restrict dev_D001)
                  SourceModel.FareQuery.basicFareConcrete
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
| TR-S1 | `calculateBasicFare` は `@[source]` で覆われる。private の `getMultiplicationRatio` はインベントリの単位ではなく、その本文は `<h1>` に含まれる（[ADR 0eea](../../.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md)）。同じクラスの他のメソッドは、別の `SourceModel` 定義が覆う必要がある |
| TR-S2 | `<h1>` が `source-inventory` の現在値と一致し、`<h1>` と定義の Merkle の組に合格の記録があれば合格。上流の版上げで本文が変わると失敗する。`trace rehash` が、`trace/checks.json` で `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` を覆う検査（`source-model/fare` のベクタの照合）を実行し、合格した場合に限ってハッシュを更新して記録する |
| TR-T1 | `TargetModel.Fare.basicFare` は `@[target]` を持つ。Rust の `atrs::fare::basic_fare` は覆われる。`atrs::model::fare::basic_fare`（写し）は TR-T2 で扱う |
| TR-T2 | `<h3>` が `target-inventory` と、`<m1>` が `TargetModel.Fare.basicFare` の Merkle ハッシュと一致すれば合格。Rust の本文を変えると `<h3>` がずれ、Lean を変えると `<m1>` がずれる |
| TR-P | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` は、R 課題 ABS-001 の具体機械 `SourceModel.FareQuery.basicFareConcrete` の操作（定義が参照する定数の閉包）に含まれる。`TargetModel.Fare.basicFare` も同様に REF-004 の具体機械に含まれるので合格 |
| TR-D | D-001 の `Abstraction.Fare.Alpha.dev_D001` が `@[deviation "D-001"]` を持ち、ABS-001 の型に現れ、W 課題 ABS-101 があれば合格 |
| TR-K | D-001 の登録 `Abstraction.Gap.D001`（`@[gap_entry]`）に対し、`Spec.Fare.basicFare` と `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` が `@[gap "D-001"]` を持てば合格 |
| TR-X | Lean の移植元側に `rust:` が無く、Rust と `TargetModel` に `java:` が無いので合格 |
| TR-R | 参照先がすべて存在すれば合格 |

影響分析の例: 上流で `calculateBasicFare` の本文が変わると、TR-S2 → `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` → ABS-001 → `Spec.Fare.basicFare` の順に影響が出る。印 `@[gap]` から、見直すギャップとして D-001・D-030 が出る。`Spec` を変えない判断なら、ここで止まる（`TargetModel`・Rust には影響しない）。

## 生成される表

以下の 2 本の表は `trace manifest` が生成する。生成区画の中を手で編集してはならない。

### ① 移植元ソース ⇔ SourceModel

<!-- BEGIN GENERATED: source-trace -->
移植元ソース ⇔ SourceModel: インベントリ 1963 件（対象範囲 1322 件、対象外 641 件）、対応あり 348 件。`trace manifest` が生成する（手で編集しない）。

| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |
| --- | --- | --- | --- |
| `java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)` | `SourceModel.App.B0.TicketHelper.toFlightList` | `3fef600108b03c6e` | lake-test |
| `dep:org.mapstruct:mapstruct#Mapper` | `SourceModel.App.B2.B2Mapper.mapPassenger` | `mapstruct-1.6.3` | （なし） |
| `java:jp.co.ntt.atrs.app.b2.B2Mapper#map(PassengerForm)` | `SourceModel.App.B2.B2Mapper.mapPassenger` | `0685ad6f1c953274` | java-origin-run, lake-test |
| `dep:org.mapstruct:mapstruct#Mapper` | `SourceModel.App.B2.B2Mapper.mapReservation` | `mapstruct-1.6.3` | （なし） |
| `java:jp.co.ntt.atrs.app.b2.B2Mapper#map(TicketReserveForm,Reservation)` | `SourceModel.App.B2.B2Mapper.mapReservation` | `b1198d19edff71a3` | java-origin-run, lake-test |
| `dep:org.springframework:spring-core#StringUtils` | `SourceModel.App.B2.PassengerForm.isEmpty` | `spring-core-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.app.b2.PassengerForm#isEmpty()` | `SourceModel.App.B2.PassengerForm.isEmpty` | `4c989a582a1c8d97` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveForm#<init>()` | `SourceModel.App.B2.TicketReserveForm.MAX_PASSENGERS_NUMBER` | `e8da8828068e2108` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveForm.MAX_PASSENGERS_NUMBER` | `SourceModel.App.B2.TicketReserveForm.MAX_PASSENGERS_NUMBER` | `ce743698ff3529b4` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveForm#resetPassengersIndex()` | `SourceModel.App.B2.TicketReserveForm.resetPassengersIndex` | `402fa38c7797fc36` | java-origin-run, lake-test |
| `lang:java#java.lang.String.format` | `SourceModel.App.B2.TicketReserveHelper.createReservation` | `java-17` | （なし） |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserve(TicketReserveForm,List)` | `SourceModel.App.B2.TicketReserveHelper.reserve` | `adcae9fef7b9df35` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserveConfirm(TicketReserveForm,List)` | `SourceModel.App.B2.TicketReserveHelper.reserveConfirm` | `7b28499828937c4a` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#validateFlightList(List)` | `SourceModel.App.B2.TicketReserveHelper.validateFlightList` | `d6700fbbefbc4997` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.app.common.exception.BadRequestException#<init>(Exception)` | `SourceModel.App.B2.TicketReserveHelper.validateFlightList` | `e6ed9d4d70fd7b28` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.config.app.ApplicationContextConfig#propertySourcesPlaceholderConfigurer(Resource...)` | `SourceModel.AtrsProperties.upstreamConfig` | `135db67a97375a9c` | pg-master-sql |
| `prop:atrs.properties#atrs.adultPassengerMinAge` | `SourceModel.AtrsProperties.upstreamConfig` | `6b51d431df5d7f14` | pg-master-sql |
| `prop:atrs.properties#atrs.childFareRate` | `SourceModel.AtrsProperties.upstreamConfig` | `39fa9ec190eee7b6` | pg-master-sql |
| `prop:atrs.properties#atrs.dateOfBirthMinDate` | `SourceModel.AtrsProperties.upstreamConfig` | `16b66d733ba7d984` | pg-master-sql |
| `prop:atrs.properties#atrs.limitDay` | `SourceModel.AtrsProperties.upstreamConfig` | `69f59c273b6e669a` | pg-master-sql |
| `prop:atrs.properties#atrs.representativeMinAge` | `SourceModel.AtrsProperties.upstreamConfig` | `4ec9599fc203d176` | pg-master-sql |
| `prop:atrs.properties#atrs.reserveIntervalTime` | `SourceModel.AtrsProperties.upstreamConfig` | `2abaca4911e68fa9` | pg-master-sql |
| `prop:atrs.properties#default.arrAirportCd` | `SourceModel.AtrsProperties.upstreamConfig` | `44f7c891ed8c4f86` | pg-master-sql |
| `prop:atrs.properties#default.boardingClassCd` | `SourceModel.AtrsProperties.upstreamConfig` | `8ce86a6ae65d3692` | pg-master-sql |
| `prop:atrs.properties#default.depAirportCd` | `SourceModel.AtrsProperties.upstreamConfig` | `44f7c891ed8c4f86` | pg-master-sql |
| `prop:atrs.properties#default.flightType` | `SourceModel.AtrsProperties.upstreamConfig` | `3165be96f5833ae0` | pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITMONTH()` | `SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITMONTH` | `80b00a5795cfaa5b` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITYEAR()` | `SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITYEAR` | `8771de6e4c3fecac` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FLIGHTTYPE()` | `SourceModel.Config.App.AtrsCodeListConfig.CL_FLIGHTTYPE` | `53a98f3857bc2251` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_GENDER()` | `SourceModel.Config.App.AtrsCodeListConfig.CL_GENDER` | `ae7bc36378865373` | lake-test |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()` | `SourceModel.Config.App.AtrsCodeListConfig.airportCodeListRows` | `6236d6ba59dfd39c` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_BOARDINGCLASS()` | `SourceModel.Config.App.AtrsCodeListConfig.boardingClassCodeListRows` | `c0ccb970d9355072` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITTYPE()` | `SourceModel.Config.App.AtrsCodeListConfig.creditTypeCodeListRows` | `14fc9ae274494f99` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FARETYPE()` | `SourceModel.Config.App.AtrsCodeListConfig.fareTypeCodeListRows` | `49649a5d73522449` | lake-test, pg-master-sql |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#JdbcCodeList.retrieveMap` | `SourceModel.Config.App.AtrsCodeListConfig.jdbcCodeList` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#jdbcTemplateForCodeList()` | `SourceModel.Config.App.AtrsCodeListConfig.jdbcCodeList` | `7719b7cc8cb21bb3` | lake-test |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.days` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.names` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.slots` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.vacant0` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.vacant1` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00250_insert_flight.sql#FLIGHT` | `SourceModel.Db.FlightSeed.vacant2` | `ebc1effd92f8d4a3` | pg-flight-sql |
| `seed:00200_insert_fixed_value.sql#AIRPORT` | `SourceModel.Db.MasterSeed.airport` | `e5f2a74a341d1ab1` | seed-lean |
| `seed:00200_insert_fixed_value.sql#BOARDING_CLASS` | `SourceModel.Db.MasterSeed.boardingClass` | `0c0030e40bed7655` | seed-lean |
| `seed:00200_insert_fixed_value.sql#CREDIT_TYPE` | `SourceModel.Db.MasterSeed.creditType` | `5cac07149240715c` | seed-lean |
| `seed:00200_insert_fixed_value.sql#FARE_TYPE` | `SourceModel.Db.MasterSeed.fareType` | `9d4738994cba9a16` | seed-lean |
| `seed:00220_insert_flight_master.sql#FLIGHT_MASTER` | `SourceModel.Db.MasterSeed.flightMaster` | `ce88990bf3547005` | seed-lean |
| `seed:00240_insert_peak_time.sql#PEAK_TIME` | `SourceModel.Db.MasterSeed.peakTime` | `3eead422572ddcea` | seed-lean |
| `seed:00200_insert_fixed_value.sql#PLANE` | `SourceModel.Db.MasterSeed.plane` | `4dd53d69f0fe3e83` | seed-lean |
| `seed:00210_insert_route.sql#ROUTE` | `SourceModel.Db.MasterSeed.route` | `376e285ef8a7ec0a` | seed-lean |
| `seed:00230_insert_member.sql#MEMBER_LOGIN` | `SourceModel.Db.MemberSeed.memberLoginRows` | `d692d2c1627b0945` | pg-reservation-sql |
| `seed:00230_insert_member.sql#MEMBER` | `SourceModel.Db.MemberSeed.memberRows` | `0fa5d725ee1debb7` | pg-reservation-sql |
| `seed:00230_insert_member.sql#MEMBER` | `SourceModel.Db.MemberSeed.sqMember` | `0fa5d725ee1debb7` | pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#AIRPORT` | `SourceModel.Db.Schema.AirportRow` | `bf8ca7804ba932ce` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_AIRPORT` | `SourceModel.Db.Schema.AirportRow` | `33090112cf970113` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#BOARDING_CLASS` | `SourceModel.Db.Schema.BoardingClassRow` | `74a735596ef8e4ee` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_BOARDING_CLASS` | `SourceModel.Db.Schema.BoardingClassRow` | `ac50cd0d76cd2c66` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#CREDIT_TYPE` | `SourceModel.Db.Schema.CreditTypeRow` | `22a8264dca01d374` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_CREDIT_TYPE` | `SourceModel.Db.Schema.CreditTypeRow` | `f4279a12f9998bef` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FARE_TYPE` | `SourceModel.Db.Schema.FareTypeRow` | `25297f0a00f0d6fc` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_FARE_TYPE` | `SourceModel.Db.Schema.FareTypeRow` | `149b5d905d80158c` | lake-test, pg-master-sql |
| `dep:org.springframework:spring-tx#Transactional` | `SourceModel.Db.Schema.FlightDb.rollback` | `spring-tx-7.0.3` | （なし） |
| `ddl:00100_create_all_tables.sql#FK_FLIGHT_MASTER_1` | `SourceModel.Db.Schema.FlightMasterRow` | `4daa481a0c253ad9` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_FLIGHT_MASTER_2` | `SourceModel.Db.Schema.FlightMasterRow` | `32419bcbe5e7e96d` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FLIGHT_MASTER` | `SourceModel.Db.Schema.FlightMasterRow` | `d92b2c0f805256a1` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_FLIGHT_MASTER` | `SourceModel.Db.Schema.FlightMasterRow` | `88b87dbbb2237387` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_FLIGHT_1` | `SourceModel.Db.Schema.FlightRow` | `2d0e26c837cc8f79` | lake-test, pg-flight-sql, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_FLIGHT_2` | `SourceModel.Db.Schema.FlightRow` | `d395df3615466997` | lake-test, pg-flight-sql, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_FLIGHT_3` | `SourceModel.Db.Schema.FlightRow` | `d4327a6873ccf4c0` | lake-test, pg-flight-sql, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FLIGHT` | `SourceModel.Db.Schema.FlightRow` | `97fb492b5adfbec4` | lake-test, pg-flight-sql, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_FLIGHT` | `SourceModel.Db.Schema.FlightRow` | `75e469d15a6da12e` | lake-test, pg-flight-sql, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_MEMBER_LOGIN_1` | `SourceModel.Db.Schema.MemberLoginRow` | `1759f86c859d73ff` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#MEMBER_LOGIN` | `SourceModel.Db.Schema.MemberLoginRow` | `c876b54c793bc20b` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PK_MEMBER_LOGIN` | `SourceModel.Db.Schema.MemberLoginRow` | `946bc5e00f703c39` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_MEMBER_1` | `SourceModel.Db.Schema.MemberRow` | `f973f6fb19c6579a` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#MEMBER` | `SourceModel.Db.Schema.MemberRow` | `27ed37725641693d` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PK_MEMBER` | `SourceModel.Db.Schema.MemberRow` | `0ef1b6d6f5d103cb` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_PASSENGER_1` | `SourceModel.Db.Schema.PassengerRow` | `73e9ec7955ed6537` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_PASSENGER_2` | `SourceModel.Db.Schema.PassengerRow` | `38e248347f807a22` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PASSENGER` | `SourceModel.Db.Schema.PassengerRow` | `798b3b804ed44e20` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PK_PASSENGER` | `SourceModel.Db.Schema.PassengerRow` | `a65be50c47900082` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PEAK_TIME` | `SourceModel.Db.Schema.PeakTimeRow` | `2639ea660139925b` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_PEAK_TIME` | `SourceModel.Db.Schema.PeakTimeRow` | `bbba432826561bb6` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_PLANE` | `SourceModel.Db.Schema.PlaneRow` | `1ddda697876bfc78` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PLANE` | `SourceModel.Db.Schema.PlaneRow` | `31641da45eeb4327` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_RESERVATION_1` | `SourceModel.Db.Schema.ReservationRow` | `dc02d22353059eb2` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PK_RESERVATION` | `SourceModel.Db.Schema.ReservationRow` | `bd7d930ed9b812f9` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#RESERVATION` | `SourceModel.Db.Schema.ReservationRow` | `b760349f34b7abf9` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_RESERVE_FLIGHT_1` | `SourceModel.Db.Schema.ReserveFlightRow` | `3326d08660a32a50` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_RESERVE_FLIGHT_2` | `SourceModel.Db.Schema.ReserveFlightRow` | `0fa426c3b4f30b61` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#PK_RESERVE_FLIGHT` | `SourceModel.Db.Schema.ReserveFlightRow` | `61fc69db73a3d3f9` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#RESERVE_FLIGHT` | `SourceModel.Db.Schema.ReserveFlightRow` | `bbf4d320c62e6860` | java-origin-run, lake-test, pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#FK_ROUTE_1` | `SourceModel.Db.Schema.RouteRow` | `f2f8da7a7846c31e` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#FK_ROUTE_2` | `SourceModel.Db.Schema.RouteRow` | `2903eca0fa0ebcd3` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#IX_ROUTE_1` | `SourceModel.Db.Schema.RouteRow` | `4b7b42e33ff4788b` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#PK_ROUTE` | `SourceModel.Db.Schema.RouteRow` | `9b19f26a2b262fa1` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#ROUTE` | `SourceModel.Db.Schema.RouteRow` | `b26d30be10a7908d` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#UK_ROUTE_1` | `SourceModel.Db.Schema.RouteRow` | `32f01bacba919d17` | lake-test, pg-master-sql |
| `ddl:00100_create_all_tables.sql#SQ_MEMBER_1` | `SourceModel.Db.Schema.sqMember` | `fca537c311ef1688` | pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#SQ_PASSENGER_1` | `SourceModel.Db.Schema.sqMember` | `331c9fe98f49d0a3` | pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#SQ_RESERVATION_1` | `SourceModel.Db.Schema.sqMember` | `280c70c2218d134c` | pg-master-sql, pg-reservation-sql |
| `ddl:00100_create_all_tables.sql#SQ_RESERVE_FLIGHT_1` | `SourceModel.Db.Schema.sqMember` | `c7bb105cb9521b63` | pg-master-sql, pg-reservation-sql |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#ClockFactory.tick` | `SourceModel.Db.Tx.now` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `dep:org.springframework:spring-tx#Transactional` | `SourceModel.Db.Tx.transactional` | `spring-tx-7.0.3` | （なし） |
| `dep:org.mybatis:mybatis-spring#MyBatisExceptionTranslator` | `SourceModel.Db.Tx.translate` | `mybatis-spring-4.0.0` | （なし） |
| `dep:org.springframework:spring-jdbc#SQLErrorCodeSQLExceptionTranslator` | `SourceModel.Db.Tx.translate` | `spring-jdbc-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#afterPropertiesSet()` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `b418d81d146f85b8` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `ee05610976981369` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopInsertOrder(int)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `4315f7151eeddd11` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopName(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `43f9d2d05dbfb456` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopValue(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `c833910b855ec69d` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setDataSource(DataSource)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `be6d1fb6e225aecc` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setJdbcTemplate(JdbcTemplate)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `6e673815724a50bf` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setLabelColumn(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `a20c04fdbe9c4744` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setOrderColumn(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `79c49c88225297cd` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setQuerySql(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `35a9be27051026b5` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setValueColumn(String)` | `SourceModel.Domain.Common.Codelist.AirportCodeList.afterPropertiesSet` | `3ce171d35383e4f7` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException#<init>(AtrsErrorCode,Object...)` | `SourceModel.Domain.Common.Exception.AtrsBusinessException.new` | `70bc401f3ab46d0d` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException.serialVersionUID` | `SourceModel.Domain.Common.Exception.AtrsBusinessException.new` | `3d4b63a6702d11d1` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException#<init>(AtrsErrorCode,Object...)` | `SourceModel.Domain.Common.Exception.AtrsBusinessException.newArgs` | `70bc401f3ab46d0d` | java-origin-run, lake-test |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#SystemException` | `SourceModel.Domain.Common.Logging.LogMessages.E_AR_A0_L9002` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.logging.LogMessages#getCode()` | `SourceModel.Domain.Common.Logging.LogMessages.E_AR_A0_L9002` | `da85740cb21790bb` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.logging.LogMessages#getMessage(Object...)` | `SourceModel.Domain.Common.Logging.LogMessages.E_AR_A0_L9002` | `a089f7300284d09d` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.logging.LogMessages.E_AR_A0_L9002` | `SourceModel.Domain.Common.Logging.LogMessages.E_AR_A0_L9002` | `53a1080bdf3ccc39` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)` | `SourceModel.Domain.Common.Masterdata.BoardingClassProvider.getBoardingClass` | `363af6d3dd2e282d` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#load()` | `SourceModel.Domain.Common.Masterdata.BoardingClassProvider.load` | `ea4f74c6c99e9b67` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll()` | `SourceModel.Domain.Common.Masterdata.BoardingClassProvider.load` | `a75e2344e7b09314` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#getFareType(FareTypeCd)` | `SourceModel.Domain.Common.Masterdata.FareTypeProvider.getFareType` | `8cca1518f179d5a0` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#load()` | `SourceModel.Domain.Common.Masterdata.FareTypeProvider.load` | `accd51e500f0cb16` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll()` | `SourceModel.Domain.Common.Masterdata.FareTypeProvider.load` | `c01904394de5db65` | lake-test |
| `dep:org.springframework:spring-core#Assert.hasText` | `SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster` | `spring-core-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#getFlightMaster(String)` | `SourceModel.Domain.Common.Masterdata.FlightMasterProvider.getFlightMaster` | `73525e4cbaf2e787` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider#load()` | `SourceModel.Domain.Common.Masterdata.FlightMasterProvider.load` | `42b24c5f9549b118` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster()` | `SourceModel.Domain.Common.Masterdata.FlightMasterProvider.load` | `0563c719a0a21f51` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)` | `SourceModel.Domain.Common.Masterdata.PeakTimeProvider.getPeakTime` | `1b19d6cad612b687` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#load()` | `SourceModel.Domain.Common.Masterdata.PeakTimeProvider.load` | `604b187a665e10c5` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll()` | `SourceModel.Domain.Common.Masterdata.PeakTimeProvider.load` | `4020414e93f77c78` | lake-test |
| `dep:org.springframework:spring-core#Assert.hasText` | `SourceModel.Domain.Common.Masterdata.RouteProvider.getRouteByAirportCd` | `spring-core-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)` | `SourceModel.Domain.Common.Masterdata.RouteProvider.getRouteByAirportCd` | `4266ccb1fdc24df9` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#load()` | `SourceModel.Domain.Common.Masterdata.RouteProvider.load` | `ce13818ba91368aa` | lake-test |
| `java:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll()` | `SourceModel.Domain.Common.Masterdata.RouteProvider.load` | `3cd8d3e7f6409637` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatDateString(LocalDate)` | `SourceModel.Domain.Common.Util.DateTimeUtil.toFormatDateString` | `a9c17cb275f550f1` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.DATE_FORMATTER` | `SourceModel.Domain.Common.Util.DateTimeUtil.toFormatDateString` | `6231e4eebda71cf4` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toFormatTimeString(String)` | `SourceModel.Domain.Common.Util.DateTimeUtil.toFormatTimeString` | `45ff7b872987b979` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.TIME_FORMATTER` | `SourceModel.Domain.Common.Util.DateTimeUtil.toFormatTimeString` | `b3ea6e972e16ec6a` | lake-test |
| `lang:java#java.lang.String.format` | `SourceModel.Domain.Common.Util.DateTimeUtil.toFormatTimeString` | `java-17` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toLocalDateTime(LocalDate,String)` | `SourceModel.Domain.Common.Util.DateTimeUtil.toLocalDateTime` | `77b0547624f167eb` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil#toLocalTime(String)` | `SourceModel.Domain.Common.Util.DateTimeUtil.toLocalTime` | `f681e7086ea22011` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.DateTimeUtil.TIME_FORMATTER` | `SourceModel.Domain.Common.Util.DateTimeUtil.toLocalTime` | `b3ea6e972e16ec6a` | java-origin-run, lake-test |
| `lang:java#java.time.format.DateTimeFormatter` | `SourceModel.Domain.Common.Util.DateTimeUtil.toLocalTime` | `java-17` | （なし） |
| `java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ONE_WAY_FARETYPES` | `SourceModel.Domain.Common.Util.FareTypeUtil.ONE_WAY_FARETYPES` | `13a685de676dd6d0` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil.ROUND_TRIP_FARETYPES` | `SourceModel.Domain.Common.Util.FareTypeUtil.ROUND_TRIP_FARETYPES` | `93a93cb033a0d234` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil#getFareTypeCdList(FlightType)` | `SourceModel.Domain.Common.Util.FareTypeUtil.getFareTypeCdList` | `23c5f6e900fea030` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightType#getCode()` | `SourceModel.Domain.Common.Util.FareTypeUtil.getFareTypeCdList` | `3855e45998af62f8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightType.OW` | `SourceModel.Domain.Common.Util.FareTypeUtil.getFareTypeCdList` | `7e4b60f4d2ee743b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightType.RT` | `SourceModel.Domain.Common.Util.FareTypeUtil.getFareTypeCdList` | `3165be96f5833ae0` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil#isOneWay(FareTypeCd)` | `SourceModel.Domain.Common.Util.FareTypeUtil.isOneWay` | `5e37c894868f1832` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareTypeUtil#isRoundTrip(FareTypeCd)` | `SourceModel.Domain.Common.Util.FareTypeUtil.isRoundTrip` | `38d25dfb5555891f` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)` | `SourceModel.Domain.Common.Util.FareUtil.ceilFare` | `345c1d9656b3930c` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareUtil.CEIL_FARE_SCALE` | `SourceModel.Domain.Common.Util.FareUtil.ceilFare` | `cd0475f0dda7e5e1` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#getCode()` | `SourceModel.Domain.Model.Airport` | `da85740cb21790bb` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#getDisplayOrder()` | `SourceModel.Domain.Model.Airport` | `15b3aeb33df2350d` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#getName()` | `SourceModel.Domain.Model.Airport` | `36c200189d0d5290` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#setCode(String)` | `SourceModel.Domain.Model.Airport` | `fe06ceaece4b0839` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#setDisplayOrder(Integer)` | `SourceModel.Domain.Model.Airport` | `811041ac15b071c0` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#setName(String)` | `SourceModel.Domain.Model.Airport` | `d75eb48ec8bce02e` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport#toString()` | `SourceModel.Domain.Model.Airport` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Airport.serialVersionUID` | `SourceModel.Domain.Model.Airport` | `8bae105bbb3f3f93` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassCd()` | `SourceModel.Domain.Model.BoardingClass` | `2c95f973159bc7cc` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#getBoardingClassName()` | `SourceModel.Domain.Model.BoardingClass` | `a4962e4cdd7f7b0b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#getExtraCharge()` | `SourceModel.Domain.Model.BoardingClass` | `c2ed357f647cbb3f` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassCd(BoardingClassCd)` | `SourceModel.Domain.Model.BoardingClass` | `fab24fded6a99658` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#setBoardingClassName(String)` | `SourceModel.Domain.Model.BoardingClass` | `11476b38898738b2` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#setExtraCharge(Integer)` | `SourceModel.Domain.Model.BoardingClass` | `a9a095c60eef4b98` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass#toString()` | `SourceModel.Domain.Model.BoardingClass` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClass.serialVersionUID` | `SourceModel.Domain.Model.BoardingClass` | `7a425c3cfaa07f43` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClassCd#getCode()` | `SourceModel.Domain.Model.BoardingClassCd.valueOf` | `3855e45998af62f8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClassCd.N` | `SourceModel.Domain.Model.BoardingClassCd.valueOf` | `8ce86a6ae65d3692` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.BoardingClassCd.S` | `SourceModel.Domain.Model.BoardingClassCd.valueOf` | `8de0b3c47f112c59` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getDiscountRate()` | `SourceModel.Domain.Model.FareType` | `ed3dd8409edfd508` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeCd()` | `SourceModel.Domain.Model.FareType` | `0ad0a31bd0da4f1d` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getFareTypeName()` | `SourceModel.Domain.Model.FareType` | `fe0943673fcac4f0` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getPassengerMinNum()` | `SourceModel.Domain.Model.FareType` | `a825d94771937aa7` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableEndDayNum()` | `SourceModel.Domain.Model.FareType` | `c72ad3c4851e2bbf` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#getRsrvAvailableStartDayNum()` | `SourceModel.Domain.Model.FareType` | `14927cc7d58ca59b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setDiscountRate(Integer)` | `SourceModel.Domain.Model.FareType` | `5d282bd1a68ca907` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeCd(FareTypeCd)` | `SourceModel.Domain.Model.FareType` | `028d6508ed1eadd9` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setFareTypeName(String)` | `SourceModel.Domain.Model.FareType` | `a37098988b7af7bb` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setPassengerMinNum(Integer)` | `SourceModel.Domain.Model.FareType` | `2f6371e03bcf7124` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableEndDayNum(Integer)` | `SourceModel.Domain.Model.FareType` | `96031ccbe007803c` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#setRsrvAvailableStartDayNum(Integer)` | `SourceModel.Domain.Model.FareType` | `f740fe7fa648536d` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType#toString()` | `SourceModel.Domain.Model.FareType` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareType.serialVersionUID` | `SourceModel.Domain.Model.FareType` | `7ac4c51a2e13b2a2` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()` | `SourceModel.Domain.Model.FareTypeCd.getCode` | `3855e45998af62f8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `3855e45998af62f8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.ED` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `4ef203daf77cede7` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.GD` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `884d5bff79c10dff` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.LD` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `ab31ea4ae5075371` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.OW` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `7e4b60f4d2ee743b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD1` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `1cfb19d902ca71fd` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD7` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `5003a843107c47b7` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.RT` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `3165be96f5833ae0` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.SOW` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `7b105823acf590f2` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRD` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `b111f3efc4632267` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRT` | `SourceModel.Domain.Model.FareTypeCd.valueOf` | `8a21220051bcc7d6` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#getBoardingClass()` | `SourceModel.Domain.Model.Flight` | `590aaacf8b6bb288` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#getDepartureDate()` | `SourceModel.Domain.Model.Flight` | `5fac0b39eeb51c0a` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#getFareType()` | `SourceModel.Domain.Model.Flight` | `70c7e2748ef109e1` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#getFlightMaster()` | `SourceModel.Domain.Model.Flight` | `9870269e2c0916c0` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#getVacantNum()` | `SourceModel.Domain.Model.Flight` | `1727d00958d6c3a3` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#setBoardingClass(BoardingClass)` | `SourceModel.Domain.Model.Flight` | `4881f219e0e20946` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#setDepartureDate(LocalDate)` | `SourceModel.Domain.Model.Flight` | `596fcb7473f9f84f` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#setFareType(FareType)` | `SourceModel.Domain.Model.Flight` | `1ced11692bc11e36` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#setFlightMaster(FlightMaster)` | `SourceModel.Domain.Model.Flight` | `8563a05050c6b001` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#setVacantNum(Integer)` | `SourceModel.Domain.Model.Flight` | `29bf39575d8c8abb` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight#toString()` | `SourceModel.Domain.Model.Flight` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Flight.serialVersionUID` | `SourceModel.Domain.Model.Flight` | `943c963ca9c1a2b3` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#getArrivalTime()` | `SourceModel.Domain.Model.FlightMaster` | `2be7080f706c1c52` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#getDepartureTime()` | `SourceModel.Domain.Model.FlightMaster` | `c36b7283ab99fa22` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#getFlightName()` | `SourceModel.Domain.Model.FlightMaster` | `56b669a044a195ca` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#getPlane()` | `SourceModel.Domain.Model.FlightMaster` | `cb4c505335b9f144` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#getRoute()` | `SourceModel.Domain.Model.FlightMaster` | `bb4d94a040ef721d` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#setArrivalTime(String)` | `SourceModel.Domain.Model.FlightMaster` | `64637d5d4f7ee1aa` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#setDepartureTime(String)` | `SourceModel.Domain.Model.FlightMaster` | `581010abbef112c0` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#setFlightName(String)` | `SourceModel.Domain.Model.FlightMaster` | `c8ed541ae69f3cad` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#setPlane(Plane)` | `SourceModel.Domain.Model.FlightMaster` | `b6b44d1417f9fdef` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#setRoute(Route)` | `SourceModel.Domain.Model.FlightMaster` | `876e919b14d523f8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster#toString()` | `SourceModel.Domain.Model.FlightMaster` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.FlightMaster.serialVersionUID` | `SourceModel.Domain.Model.FlightMaster` | `8eded4361c5b9f70` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Gender#getCode()` | `SourceModel.Domain.Model.Gender.getCode` | `a9f1cc11acd733ab` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.model.Gender.F` | `SourceModel.Domain.Model.Gender.getCode` | `f67ab10ad4e4c531` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.model.Gender.M` | `SourceModel.Domain.Model.Gender.getCode` | `08f271887ce94707` | java-origin-run, lake-test |
| `dep:org.mybatis:mybatis#EnumTypeHandler` | `SourceModel.Domain.Model.Gender.valueOf` | `mybatis-3.5.19` | （なし） |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#getMultiplicationRatio()` | `SourceModel.Domain.Model.PeakTime` | `0b4e159bab8a2bad` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakEndDate()` | `SourceModel.Domain.Model.PeakTime` | `3320372937ffb1c6` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakStartDate()` | `SourceModel.Domain.Model.PeakTime` | `8c5afe3863a52476` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakTimeCd()` | `SourceModel.Domain.Model.PeakTime` | `bf567cee012c32c7` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#setMultiplicationRatio(Integer)` | `SourceModel.Domain.Model.PeakTime` | `2a4c3f761ef3b3ac` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakEndDate(LocalDate)` | `SourceModel.Domain.Model.PeakTime` | `7d72acc8b47d2285` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakStartDate(LocalDate)` | `SourceModel.Domain.Model.PeakTime` | `a620abe6a1283db9` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakTimeCd(String)` | `SourceModel.Domain.Model.PeakTime` | `df6461ab2c7d6c5e` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime#toString()` | `SourceModel.Domain.Model.PeakTime` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.PeakTime.serialVersionUID` | `SourceModel.Domain.Model.PeakTime` | `2f2b16014969a5f5` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#getCraftType()` | `SourceModel.Domain.Model.Plane` | `01576ceec214b3c8` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#getNSeatNum()` | `SourceModel.Domain.Model.Plane` | `f5d712d167c0596e` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#getSSeatNum()` | `SourceModel.Domain.Model.Plane` | `99c381dae97878b5` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#setCraftType(String)` | `SourceModel.Domain.Model.Plane` | `91f4b11b9bd54c75` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#setNSeatNum(Integer)` | `SourceModel.Domain.Model.Plane` | `6e34b482ab4e2e96` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#setSSeatNum(Integer)` | `SourceModel.Domain.Model.Plane` | `a1d12f387b95199b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane#toString()` | `SourceModel.Domain.Model.Plane` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Plane.serialVersionUID` | `SourceModel.Domain.Model.Plane` | `ee869d61bf2fce1b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#getArrivalAirport()` | `SourceModel.Domain.Model.Route` | `e4e63cfd9aa52b7c` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#getBasicFare()` | `SourceModel.Domain.Model.Route` | `89a978cfeb517ad4` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#getDepartureAirport()` | `SourceModel.Domain.Model.Route` | `c52377ce8cec2f3c` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#getRouteNo()` | `SourceModel.Domain.Model.Route` | `4c60bbfe1a09e09b` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#setArrivalAirport(Airport)` | `SourceModel.Domain.Model.Route` | `8f997e7447e48706` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#setBasicFare(Integer)` | `SourceModel.Domain.Model.Route` | `dcef121f022ac443` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#setDepartureAirport(Airport)` | `SourceModel.Domain.Model.Route` | `ba74485411a2bc4f` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#setRouteNo(Integer)` | `SourceModel.Domain.Model.Route` | `a9c754e56f9d626c` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route#toString()` | `SourceModel.Domain.Model.Route` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.model.Route.serialVersionUID` | `SourceModel.Domain.Model.Route` | `e55e25f5719b321f` | lake-test |
| `sql:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll` | `SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository.findAll` | `9b228eec7b3acd6a` | lake-test, pg-master-sql |
| `sql:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll` | `SourceModel.Domain.Repository.Faretype.FareTypeRepository.findAll` | `7ff78a19a79f16de` | lake-test, pg-master-sql |
| `dep:org.mybatis:mybatis#EnumTypeHandler` | `SourceModel.Domain.Repository.Flight.FlightRepository.bind` | `mybatis-3.5.19` | （なし） |
| `dep:org.mybatis:mybatis#EnumTypeHandler` | `SourceModel.Domain.Repository.Flight.FlightRepository.bindKey` | `mybatis-3.5.19` | （なし） |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#exists(LocalDate,String,BoardingClass,FareType)` | `SourceModel.Domain.Repository.Flight.FlightRepository.exists` | `963eff23e19232bd` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#exists` | `SourceModel.Domain.Repository.Flight.FlightRepository.existsRows` | `fe988ee9710d5e94` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster` | `SourceModel.Domain.Repository.Flight.FlightRepository.findAllFlightMaster` | `ebfbc030ba80f150` | lake-test, pg-flight-sql, pg-master-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findOneForUpdate(LocalDate,String,BoardingClass,FareType)` | `SourceModel.Domain.Repository.Flight.FlightRepository.findOneForUpdate` | `852c2d72ff703d07` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findOneForUpdate` | `SourceModel.Domain.Repository.Flight.FlightRepository.findOneForUpdateRows` | `a0b73cb5abc18dbc` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria(VacantSeatSearchCriteriaDto)` | `SourceModel.Domain.Repository.Flight.FlightRepository.flightMap` | `642c24ce08bfe364` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#update(Flight)` | `SourceModel.Domain.Repository.Flight.FlightRepository.update` | `3a289afa23fe78a3` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#update` | `SourceModel.Domain.Repository.Flight.FlightRepository.updateRows` | `de19197b9e62d467` | java-origin-run, lake-test, pg-flight-sql, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria` | `SourceModel.Domain.Repository.Flight.FlightRepository.vacantSeatRows` | `2fbe03024cd7d231` | java-origin-run, lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#<init>(LocalDate,Route,BoardingClassCd,Long,List)` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `da10cbbc34c14874` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBeforeDayNum()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `87c12b12578b0d7e` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBoardingClass()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `14872a96b272a9e5` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getDepDate()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `9e5ad0157d1bece7` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getFareTypeList()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `108313590608caad` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getRoute()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `bb4d94a040ef721d` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#toString()` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `b78e85e304022465` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto.serialVersionUID` | `SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto` | `652bd2782db8027a` | lake-test, pg-flight-sql |
| `java:jp.co.ntt.atrs.domain.repository.member.MemberRepository#findOne(String)` | `SourceModel.Domain.Repository.Member.MemberRepository.findOne` | `451a02e1a5c2ef0a` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.member.MemberRepository#findOne` | `SourceModel.Domain.Repository.Member.MemberRepository.findOneRows` | `0d19f186b308dbfd` | java-origin-run, lake-test, pg-reservation-sql |
| `dep:org.postgresql:postgresql#TimestampUtils.toLocalDateTime` | `SourceModel.Domain.Repository.Member.MemberRepository.localDateOfTimestamp` | `postgresql-42.7.9` | （なし） |
| `sql:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll` | `SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.findAll` | `52311345757d8bde` | lake-test, pg-master-sql |
| `dep:org.mybatis:mybatis#SelectKeyGenerator` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insert` | `mybatis-3.5.19` | （なし） |
| `java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert(Reservation)` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insert` | `3d5880d4f5b24ab0` | java-origin-run, lake-test, pg-reservation-sql |
| `dep:org.mybatis:mybatis#SelectKeyGenerator` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertPassenger` | `mybatis-3.5.19` | （なし） |
| `java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger(Passenger)` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertPassenger` | `1ba685e68ed407bf` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertPassengerRow` | `143c319a42242366` | java-origin-run, lake-test, pg-reservation-sql |
| `dep:org.mybatis:mybatis#SelectKeyGenerator` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertReserveFlight` | `mybatis-3.5.19` | （なし） |
| `java:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight(ReserveFlight)` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertReserveFlight` | `88ff643e818d213a` | java-origin-run, lake-test, pg-reservation-sql |
| `dep:org.mybatis:mybatis#EnumTypeHandler` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertReserveFlightRow` | `mybatis-3.5.19` | （なし） |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertReserveFlightRow` | `c6374f352f5e8516` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.insertRow` | `24efe7b0cbd4877c` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.nextPassengerNo` | `143c319a42242366` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.nextReserveFlightNo` | `c6374f352f5e8516` | java-origin-run, lake-test, pg-reservation-sql |
| `sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.nextReserveNo` | `24efe7b0cbd4877c` | java-origin-run, lake-test, pg-reservation-sql |
| `dep:org.postgresql:postgresql#PgResultSet.getInt` | `SourceModel.Domain.Repository.Reservation.ReservationRepository.readInteger` | `postgresql-42.7.9` | （なし） |
| `sql:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll` | `SourceModel.Domain.Repository.Route.RouteRepository.findAll` | `0a9a6b28094e3e9a` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.AtrsInfraConfig#sqlSessionFactory(DataSource)` | `SourceModel.Domain.Repository.Route.RouteRepository.routeMap` | `b1ab3854afd9d9e6` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.config.app.mybatis.MybatisConfig#configuration()` | `SourceModel.Domain.Repository.Route.RouteRepository.routeMap` | `81014029228aac4a` | lake-test, pg-master-sql |
| `java:jp.co.ntt.atrs.domain.service.b0.InvalidFlightException#<init>(String)` | `SourceModel.Domain.Service.B0.InvalidFlightException.new` | `80edf1af3fd26cf2` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.InvalidFlightException.serialVersionUID` | `SourceModel.Domain.Service.B0.InvalidFlightException.new` | `2d16bfba7652351b` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` | `9872678663e9a896` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` | `5b0822fe4c6991ac` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl.MULTIPLICATION_RATIO_IN_NORMAL_TIME` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` | `48440c4bc2152d40` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateFare(int,int)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare` | `8088a7f2c9efaf7e` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare` | `1e12eb714e2bc395` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#existsFlight(Flight)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.existsFlight` | `3a7ea0432fb7d108` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#existsFlight(Flight)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.existsFlight` | `a4e50b127ec510cf` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#getSearchLimitDate()` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getSearchLimitDate` | `9196be73040e6f0f` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getSearchLimitDate()` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getSearchLimitDate` | `07352a31cf61634a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#isAvailableFareType(FareType,LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType` | `920d960054ac73a8` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#isAvailableFareType(FareType,LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType` | `c724cf20ebe62f82` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#validateDepatureDate(LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateDepatureDate` | `9b898d66ce284b6a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateDepatureDate(LocalDate)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateDepatureDate` | `ab7abd9ac674d349` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#validateFlightList(List)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList` | `cab75bbff4478e82` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateFlightList(List)` | `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList` | `31235b0af5e54df0` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#<init>(String,String,Integer)` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `b5ab6bf246edfbbf` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFare()` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `3aecf0e9bebb654a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getFareTypeName()` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `fe0943673fcac4f0` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#getVacantNum()` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `1727d00958d6c3a3` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto#toString()` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto.serialVersionUID` | `SourceModel.Domain.Service.B1.FareTypeVacantInfoDto` | `dd46f950a2716a7f` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException#<init>()` | `SourceModel.Domain.Service.B1.FlightNotFoundException.new` | `a759c61b6ed17dc4` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException.serialVersionUID` | `SourceModel.Domain.Service.B1.FlightNotFoundException.new` | `8c008f35f98c4bb6` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrAirportName()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `168f6313b91f7efc` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrTime()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `eba19a6e8cfe7373` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getBoardingClassCd()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `2c95f973159bc7cc` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepAirportName()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `613fd9acef107682` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepDate()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `369d89134caefd5a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepTime()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `e8756384892001a1` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFareTypes()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `b4cb9d39c4e1670d` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFlightName()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `56b669a044a195ca` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrAirportName(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `6ed33d2eb1ba891b` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrTime(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `a72394c9d4069159` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setBoardingClassCd(BoardingClassCd)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `fab24fded6a99658` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepAirportName(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `fccb4abecff6d001` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepDate(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `962bd97bc530d3db` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepTime(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `a032ee060e4c3da2` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFareTypes(Map)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `28c6e4b5185f43b9` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFlightName(String)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `c8ed541ae69f3cad` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#toString()` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto.serialVersionUID` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto` | `c450724693049058` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#addFareTypeVacantInfo(FareTypeCd,FareTypeVacantInfoDto)` | `SourceModel.Domain.Service.B1.FlightVacantInfoDto.addFareTypeVacantInfo` | `1c016d6655a35b9a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getArrivalAirportCd()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `1c111d784bf8d220` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getBoardingClassCd()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `2c95f973159bc7cc` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepDate()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `9e5ad0157d1bece7` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getDepartureAirportCd()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `08763144c723fca5` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#getFlightType()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `a815d39b257bbd2b` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setArrivalAirportCd(String)` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `922656e0efb53e00` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setBoardingClassCd(BoardingClassCd)` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `fab24fded6a99658` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepDate(LocalDate)` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `e4d262f79ebcb7ac` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setDepartureAirportCd(String)` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `48b1037e44becf59` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#setFlightType(FlightType)` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `7f178ac43c6090bd` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto#toString()` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `b78e85e304022465` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto.serialVersionUID` | `SourceModel.Domain.Service.B1.TicketSearchCriteriaDto` | `c846f41752a6a6bf` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode#code()` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `5fde806a365dc7a0` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2001` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `d4efdf3f2ea8e7cc` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2002` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `c1a57c4052f9c12b` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_2003` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `2ea2beee13c2ea3a` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5001` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `9bd02ea3ebb9a87f` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchErrorCode.E_AR_B1_5002` | `SourceModel.Domain.Service.B1.TicketSearchErrorCode.code` | `c2b041fc47e7f619` | lake-test |
| `lang:java#java.text.DecimalFormat` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.createFlightVacantInfoList` | `java-17` | （なし） |
| `lang:java#java.util.LinkedHashMap` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.createFlightVacantInfoList` | `java-17` | （なし） |
| `dep:org.springframework:spring-core#Assert.hasText` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight` | `spring-core-7.0.3` | （なし） |
| `dep:org.springframework:spring-core#Assert.notNull` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight` | `spring-core-7.0.3` | （なし） |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchService#searchFlight(TicketSearchCriteriaDto)` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight` | `aebd2fb115cd02fc` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)` | `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight` | `75061ffc6ae02ecb` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode#code()` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `5fde806a365dc7a0` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2001` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `48c863106106d000` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2002` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `cd7ca684671ce46f` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2003` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `e38fa5a882084768` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2004` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `4e63e291bfee3d2a` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2005` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `ddb39f02b8f2ef71` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2006` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `7f2e00f344361b5e` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2007` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `1ad572ad2b5e701d` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2008` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `25e29d5a5f6f2214` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2009` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `9810cb0c99b4d473` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveErrorCode.E_AR_B2_2010` | `SourceModel.Domain.Service.B2.TicketReserveErrorCode.code` | `d64487b413becec0` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare` | `ca1a14757ce1cb33` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare` | `35bc5d27ed5f2ca9` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#registerReservation(Reservation)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.registerReservation` | `4df168e425feb579` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#registerReservation(Reservation)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.registerReservation` | `14ec7266e29f86b3` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#validateReservation(Reservation)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.validateReservation` | `66cb03764db77def` | java-origin-run, lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#validateReservation(Reservation)` | `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.validateReservation` | `d94a3852f47a03d1` | java-origin-run, lake-test |
| `dep:org.terasoluna.gfw:terasoluna-gfw-common#NumberRangeCodeList.afterPropertiesSet` | `SourceModel.Gfw.CodeList.numberRange` | `terasoluna-gfw-common-5.11.0.RELEASE` | （なし） |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.days` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.names` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.slots` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.vacant0` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.vacant1` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00250_insert_flight.sql#FLIGHT` | `Spec.Seed.Flight.vacant2` | `ebc1effd92f8d4a3` | seed-lean |
| `seed:00230_insert_member.sql#MEMBER` | `Spec.Seed.Member.members` | `0fa5d725ee1debb7` | seed-lean |
| `seed:00230_insert_member.sql#MEMBER_LOGIN` | `Spec.Seed.Member.members` | `d692d2c1627b0945` | seed-lean |
| `seed:00230_insert_member.sql#MEMBER` | `Spec.Seed.Member.sequences` | `0fa5d725ee1debb7` | seed-lean |
| `seed:00200_insert_fixed_value.sql#AIRPORT` | `Spec.Seed.airports` | `e5f2a74a341d1ab1` | seed-lean |
| `seed:00200_insert_fixed_value.sql#BOARDING_CLASS` | `Spec.Seed.boardingClasses` | `0c0030e40bed7655` | seed-lean |
| `seed:00200_insert_fixed_value.sql#CREDIT_TYPE` | `Spec.Seed.creditTypes` | `5cac07149240715c` | seed-lean |
| `seed:00200_insert_fixed_value.sql#FARE_TYPE` | `Spec.Seed.fareTypes` | `9d4738994cba9a16` | seed-lean |
| `seed:00220_insert_flight_master.sql#FLIGHT_MASTER` | `Spec.Seed.flightMasters` | `ce88990bf3547005` | seed-lean |
| `seed:00240_insert_peak_time.sql#PEAK_TIME` | `Spec.Seed.peakTimes` | `3eead422572ddcea` | seed-lean |
| `seed:00200_insert_fixed_value.sql#PLANE` | `Spec.Seed.planes` | `4dd53d69f0fe3e83` | seed-lean |
| `seed:00210_insert_route.sql#ROUTE` | `Spec.Seed.routes` | `376e285ef8a7ec0a` | seed-lean |
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
