---
type: Specification
title: "追跡表"
description: "原典の Java クラス・SQL 文と、仕様の節、Lean の名前空間（SourceModel / Spec）、Rust のモジュールの対応表。"
tags: [spec, traceability]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 追跡表

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

原典パスは `JavaConfig-Thymeleaf/atrs/` からの相対で、`d/` = `atrs-domain/src/main/java/jp/co/ntt/atrs/domain/`、`w/` = `atrs-web/src/main/java/jp/co/ntt/atrs/`、`x/` = `atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/` の省略。
Lean 列は予定名であり、実装したら確定させる（[rules/porting.md](../rules/porting.md#追跡可能性)）。

## ドメイン（Java）

| 原典 | 仕様 | SourceModel | Spec |
| --- | --- | --- | --- |
| `d/common/util/FareUtil.java` | [fare-calculation.md#運賃](fare-calculation.md#運賃) | `SourceModel.Fare` | `Spec.Fare` |
| `d/common/util/FareTypeUtil.java` | [domain-model.md#列挙](domain-model.md#列挙) | `SourceModel.Model` | `Spec.Model` |
| `d/common/util/DateTimeUtil.java` | [domain-model.md#書式](domain-model.md#書式) | `SourceModel.Format` | `Spec.Prim.Format` |
| `d/common/validate/*.java`（FixedLength, FullWidth, FullWidthKatakana, HalfWidth, HalfWidthNumber, ValidationUtil） | [input-validation.md#文字クラス](input-validation.md#文字クラス) | `SourceModel.Validation` | `Spec.Validation` |
| `d/common/masterdata/*Provider.java`（BoardingClass, FareType, FlightMaster, PeakTime, Route） | [master-data.md#参照関数](master-data.md#参照関数) | `SourceModel.MasterData` | `Spec.MasterData` |
| `d/common/codelist/AirportCodeList.java` | [master-data.md#空港コードリスト画面用](master-data.md#空港コードリスト画面用) | `SourceModel.CodeList` | `Spec.CodeList` |
| `d/common/exception/*`, `d/service/*/*ErrorCode.java` | [errors-and-messages.md](errors-and-messages.md) | `SourceModel.Error` | `Spec.Error` |
| `d/common/logging/LogMessages.java` | [errors-and-messages.md#ログシステムコード](errors-and-messages.md#ログシステムコード) | — | — |
| `d/common/security/*Listener.java` | [authentication.md](authentication.md) | `SourceModel.UseCase.Auth` | `Spec.UseCase.Auth` |
| `d/model/*.java` | [domain-model.md#エンティティ](domain-model.md#エンティティ) | `SourceModel.Model` | `Spec.Model` |
| `d/service/a0/MembershipSharedServiceImpl.java` | [member.md#会員の存在確認](member.md#会員の存在確認) | `SourceModel.UseCase.Member` | `Spec.UseCase.Member` |
| `d/service/a1/AuthLoginServiceImpl.java`, `AtrsUserDetailsService.java`, `AtrsUserDetails.java` | [authentication.md#ログインlogin](authentication.md#ログインlogin) | `SourceModel.UseCase.Auth` | `Spec.UseCase.Auth` |
| `d/service/a2/AuthLogoutServiceImpl.java` | [authentication.md#ログアウトlogout](authentication.md#ログアウトlogout) | `SourceModel.UseCase.Auth` | `Spec.UseCase.Auth` |
| `d/service/b0/TicketSharedServiceImpl.java` | [fare-calculation.md](fare-calculation.md), [flight-search.md](flight-search.md), [reservation.md#validateflightlist](reservation.md#validateflightlist) | `SourceModel.Fare`, `SourceModel.Ticket` | `Spec.Fare`, `Spec.Ticket` |
| `d/service/b1/TicketSearchServiceImpl.java`, `FlightVacantInfoDto.java`, `FareTypeVacantInfoDto.java`, `FlightNotFoundException.java` | [flight-search.md#searchflight](flight-search.md#searchflight) | `SourceModel.FlightSearch` | `Spec.FlightSearch` |
| `d/service/b2/TicketReserveServiceImpl.java` | [reservation.md](reservation.md), [fare-calculation.md#合計金額](fare-calculation.md#合計金額) | `SourceModel.UseCase.Reserve` | `Spec.UseCase.Reserve` |
| `d/service/c1/MemberRegisterServiceImpl.java` | [member.md#会員登録register](member.md#会員登録register) | `SourceModel.UseCase.Member` | `Spec.UseCase.Member` |
| `d/service/c2/MemberUpdateServiceImpl.java` | [member.md#会員情報変更update](member.md#会員情報変更update) | `SourceModel.UseCase.Member` | `Spec.UseCase.Member` |
| `d/service/d1/ReservationHistoryReportServiceImpl.java`, `d/repository/reservation/ReservationHistoryDto.java` | [reservation-history-report.md](reservation-history-report.md) | `SourceModel.UseCase.Report` | `Spec.UseCase.Report` |

## SQL（Mapper XML）

すべて `LangSemantics.Sql` 上の式として `SourceModel.Repository.*` に写す（[ADR 0019](../decision/0019-sql-semantics-for-source-repositories.md)）。

| 原典 | 文 | 仕様 | SourceModel |
| --- | --- | --- | --- |
| `x/flight/FlightRepository.xml` | `findByVacantSeatSearchCriteria` | [flight-search.md#searchflight](flight-search.md#searchflight) | `SourceModel.Repository.Flight` |
| 同 | `findOneForUpdate`, `update`, `exists` | [ports.md#flightrepository](ports.md#flightrepository) | 同 |
| 同 | `findAllFlightMaster` | [master-data.md](master-data.md) | 同 |
| `x/member/MemberRepository.xml` | `findOne`, `findOneForLogin`, `insert`（`selectKey`）, `insertMemberLogin`, `update`, `updateMemberLogin`, `updateToLoginStatus`, `updateToLogoutStatus` | [ports.md#memberrepository](ports.md#memberrepository) | `SourceModel.Repository.Member` |
| `x/reservation/ReservationRepository.xml` | `insert`（`selectKey`）, `insertReserveFlight`, `insertPassenger`, `findAllByMembershipNumberForReport` | [ports.md#reservationrepository](ports.md#reservationrepository) | `SourceModel.Repository.Reservation` |
| `x/peaktime/PeakTimeRepository.xml`, `x/route/RouteRepository.xml`, `x/faretype/FareTypeRepository.xml`, `x/boardingclass/BoardingClassRepository.xml` | `findAll` | [master-data.md](master-data.md) | `SourceModel.Repository.Master` |
| `atrs-initdb/src/sqls/integration-test-postgres/00100_create_all_tables.sql` | テーブル・シーケンス定義 | [ports.md#idgenerator](ports.md#idgenerator) | `SourceModel.Repository.Schema` |
| `atrs-initdb/src/sqls/integration-test-postgres/002x0_*.sql` | シードデータ | [master-data.md#シードデータ](master-data.md#シードデータ) | （fixture） |

## Web 層

| 原典 | 仕様 | SourceModel | Spec |
| --- | --- | --- | --- |
| `w/app/common/binding/GlobalBindingInitializer.java` | [input-validation.md#前処理](input-validation.md#前処理) | `SourceModel.Validation` | `Spec.Validation` |
| `w/app/a0/*.java` | [http-contract.md#a0a1-トップログイン](http-contract.md#a0a1-トップログイン) | `SourceModel.Http` | `Spec.Http` |
| `w/app/a1/AuthLoginController.java`, `w/app/common/security/*.java` | [authentication.md](authentication.md), [http-contract.md#認証と権限](http-contract.md#認証と権限) | `SourceModel.Http` | `Spec.Http` |
| `w/app/b0/*.java` | [reservation.md#選択フライト](reservation.md#選択フライト), [input-validation.md#フライト選択b0](input-validation.md#フライト選択b0) | `SourceModel.Validation` | `Spec.Validation` |
| `w/app/b1/*.java` | [flight-search.md](flight-search.md), [input-validation.md#空席照会b1](input-validation.md#空席照会b1), [http-contract.md#b1-空席照会](http-contract.md#b1-空席照会) | `SourceModel.Http` | `Spec.Http` |
| `w/app/b2/*.java` | [reservation.md](reservation.md), [input-validation.md#予約入力b2](input-validation.md#予約入力b2), [http-contract.md#b2-予約](http-contract.md#b2-予約) | `SourceModel.Http` | `Spec.Http` |
| `w/app/c0/*.java`, `w/app/c1/*.java`, `w/app/c2/*.java` | [member.md](member.md), [input-validation.md#会員入力c1c2](input-validation.md#会員入力c1c2) | `SourceModel.Http` | `Spec.Http` |
| `w/app/d1/*.java`, `w/listener/d1/*.java` | [reservation-history-report.md](reservation-history-report.md), [http-contract.md#d1-予約履歴レポート](http-contract.md#d1-予約履歴レポート) | `SourceModel.UseCase.Report` | `Spec.UseCase.Report` |
| `w/app/common/error/*`, `w/app/common/exception/*` | [http-contract.md#エラー画面](http-contract.md#エラー画面) | `SourceModel.Http` | `Spec.Http` |
| `w/api/**/*.java` | [http-contract.md#rest-apiapiv1](http-contract.md#rest-apiapiv1) | `SourceModel.Http` | `Spec.Http` |
| `w/config/web/*.java`, `atrs-web/src/main/webapp/WEB-INF/web.xml` | [http-contract.md#共通](http-contract.md#共通) | — | — |
| `atrs-web/src/main/resources/i18n/*.properties`, `ValidationMessages.properties` | [errors-and-messages.md](errors-and-messages.md) | `SourceModel.Message` | `Spec.Message` |
| `atrs-domain/src/main/resources/META-INF/spring/atrs.properties` | [configuration.md](configuration.md) | `SourceModel.Config` | `Spec.Config` |

## 対象外

`w/app/common/logging/AccessLogFilter.java`、`atrs-env/**`、`atrs-selenium/**`、`atrs-web/src/main/webapp/**/*.html` の HTML 構造・静的資源（[ADR 0002](../decision/0002-porting-scope.md)）。

Rust の `target_model` 列は Rust 実装の着手時（[backlog 0019](../backlog/0019-rust-spec-mirror-and-fare-core.md) 以降）に追加する。下位モジュール名は Lean と同じ機能名の snake_case とする（[rules/rust.md](../rules/rust.md#構成)）。
