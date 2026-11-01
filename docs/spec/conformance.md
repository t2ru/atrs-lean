---
type: Specification
title: "適合テストベクタ（ATRS）"
description: "ATRS の適合テストベクタの機能区分・操作名・共有入力・ATRS 固有の前提。形式はスキル spec-pivot に従う。"
tags: [spec, conformance, testing]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# 適合テストベクタ（ATRS）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

ディレクトリ構成・ファイル形式・値の表現・期待値の出所は、スキル spec-pivot の [conformance.md](../../.agents/skills/spec-pivot/references/docs/spec/conformance.md) に従う（[ADR dc3a](../decision/dc3a-conformance-test-vectors.md)）。本書は ATRS 固有の事項だけを定める。

## 機能区分（`<feature>`）

`fare`, `flight-search`, `reservation`, `member`, `authentication`, `report`, `validation`, `format`, `http`（[atrs-porting.md](../rules/atrs-porting.md#機能名層をまたいで共通) の機能名と対応）。

## 操作名

| 操作 | 仕様 |
| --- | --- |
| `fare.basicFare`, `fare.fare`, `fare.totalFare` | [fare-calculation.md](fare-calculation.md) |
| `master.routeOf`, `master.flightMasterOf`, `master.fareTypeOf`, `master.boardingClassOf`, `master.peakTimeOn`, `master.multiplicationRatioOn`, `master.config`, `master.codeList` | [master-data.md](master-data.md#参照関数)（R 課題 ABS-026 の両側。`Spec.MasterQuery.queryMachine` と `SourceModel.MasterQuery.queryConcrete`） |
| `reservation.validateFlightList`, `reservation.validateReservation`, `reservation.confirm`, `reservation.reserve` | [reservation.md](reservation.md)（ベクタは `shared/reservation/`。入力は `flights`・`members`・`sequences`（採番の次の値）・`today`・`selectFlights`・`form`（入力検証の後の予約入力）。`reservation.reserve` の期待値は、結果と実行後の状態（フライト・予約・採番の次の値）。エラーは `{"error": {"kind": …}}` で、`business` は `code`・`args` を持つ。`invalidRequest` の詳細は比較しない（N-004）。[Source] の `BadRequestException`・`InvalidFlightException` が `invalidRequest` に当たる。形式の詳細は `lean/Tests/ConformanceReservation.lean`） |
| `flightSearch.validateDepartureDate`, `flightSearch.isAvailableFareType`, `flightSearch.searchFlight` | [flight-search.md](flight-search.md)（ベクタは `shared/flight-search/`。入力のフライト `flights` は、[Spec] では `World.flights`、[Source] では FLIGHT 表の行。エラーは `{"error": {"kind": "business" \| "notFound", "code": …}}` として期待値に書く。[Source] の `AtrsBusinessException` が `business`、`FlightNotFoundException` が `notFound` に当たる） |
| `reservation.validateFlightList`, `reservation.validateReservation`, `reservation.reserveConfirm`, `reservation.reserve` | [reservation.md](reservation.md) |
| `member.toMember`, `member.toMemberUpdateInput`, `member.register`, `member.update` | [member.md](member.md) |
| `auth.login`, `auth.logout` | [authentication.md](authentication.md) |
| `report.reportFileName`, `report.renderCsv`, `report.createReport`, `report.listReports` | [reservation-history-report.md](reservation-history-report.md) |
| `validation.<入力名>` | [input-validation.md](input-validation.md) |
| `format.fmtDate`, `format.fmtIsoDate`, `format.fmtTime`, `format.fmtTimestamp`, `format.fmtYen`, `format.fmtPaymentDate`, `format.fullYearsBetween`, `format.parseHHmm`, `format.addDays`, `format.daysBetween` | [domain-model.md](domain-model.md) |
| `http.<リクエスト>` | [http-contract.md](http-contract.md)（HTTP レベルの原典実行の採取結果は、`SourceModel.Http` ができるまで `tools/origin-run/http/` に置く。`modelDef` は `null`。[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)） |

## 共有入力（fixtures）

| ファイル | 内容 |
| --- | --- |
| `fixtures/master-data.json` | 原典のシードデータ（空港 51・区間 20・便マスタ 126、搭乗クラス、運賃種別、ピーク時期、機材、カード種別）。投入日を固定して展開したもの（下記）。[master-data.md](master-data.md#シードデータ) |
| `fixtures/config.json` | 設定の既定値（原典の `atrs.properties`）。[configuration.md](configuration.md) |

`master-data.json`・`config.json` は、生成器 `tools/conformance/master_fixture.py` が上流のシードの SQL と `atrs.properties` から書き出す（手で編集しない。CI が `--check` で確かめる。[ADR 8f18](../decision/8f18-fare-source-model-and-shared-vectors.md)）。行の順はシードの順で、[Source] の Provider のキャッシュはこの順に作る。[Spec] の値域の外の時刻の便マスタには `outsideSpec` が付く（上流のシードには無い。到着時刻 `2415` は [Spec] の値域の内である。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。

マスタの Mapper の文とコードリストの SQL の PostgreSQL での結果は、`conformance/sql/master-data.json` にある（`tools/conformance/master_sql.py` が生成する。`lake test` の `Tests.MasterSql` が `SourceModel.Domain.Repository.*`・`SourceModel.Config.App.AtrsCodeListConfig` と照合する。[ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md)）。空席照会の文 `findByVacantSeatSearchCriteria` の結果は `conformance/sql/flight-search.json` にあり、`Tests.FlightSql` が照合する。FLIGHT 表は 00250 を投入日で実行したもので、生成器 `tools/conformance/flight_seed.py` の展開・`SourceModel.Db.FlightSeed` と要約で照合する（[ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)）。

`shared/` のベクタの `modelDef` は、`Spec` と `SourceModel` の名前の配列とする（例 `["Spec.Fare.fare", "SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare"]`）。`source-model/` の期待値は、原典を実行して得る（Java の原典実行。`source: "java-origin-run"`、`upstream` に版。[backlog f18c](../backlog/f18c-java-oracle-harness.md)、[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)）。原典実行は `shared/`・`source-model/` の手で書いたケースを原典で照合し、シードの範囲から作った入力の期待値を `source-model/<feature>/origin-run-*.json` に書き出す（手で編集しない。`mise run origin-run:gen` で再生成し、CI の `origin-run:domain` が再生成との差分 0 を確かめる）。原典実行の無い操作の `source-model/` の期待値は、仕様の例の [Source] の値を使う（`source: "lean-source-model"`）。
| `fixtures/world-*.json` | 状態を使う操作の初期状態（フライトの空席数、会員、予約、各シーケンスの次の値） |

## ATRS 固有の前提

- `PasswordHasher` を使う操作のベクタは、参照ハッシュ `"{test}" ++ raw` を前提とする（[atrs-porting.md](../rules/atrs-porting.md#atrs-で採った値)）。
- 投入日に依存するシードは、投入日 **2026-11-01**（投入年 `Y = 2026`）として展開する（[ADR 9ee4](../decision/9ee4-clock-timezone-and-fixture-base-date.md)）。
  - ピーク時期: 2026 年と 2027 年の 2 年分。
  - フライト: 2026-11-01 から 120 日後の 2027-03-01 まで（両端を含む 121 日分。原典 `00250_insert_flight.sql` の `currentDate <= current_date + 120`）。空席数のパターン `i mod 3` の `i` は 2026-11-01 を 0 とする。
  - ベクタの `today` は各ベクタで明示する。既定は投入日と同じ 2026-11-01。
- シーケンスの初期値は、シード投入後の原典の値とする。採番を伴う操作のベクタは、参照実装（`n`, `n+1`, …）で採番した番号を期待値として厳密に比較する（[ports.md](ports.md#idgenerator)）。
- `source-model/` のベクタでは、入力検証エラーを多重集合として比較する（[ADR e24e](../decision/e24e-validation-error-ordering.md)）。
- `source-model/` のベクタの `upstream` は `trace/upstream.json` の release・commit とする。
