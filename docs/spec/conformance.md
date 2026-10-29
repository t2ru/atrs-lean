---
type: Specification
title: "適合テストベクタ（ATRS）"
description: "ATRS の適合テストベクタの機能区分・操作名・共有入力・ATRS 固有の前提。形式はスキル port-lang に従う。"
tags: [spec, conformance, testing]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:39:02+09:00
---

# 適合テストベクタ（ATRS）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

ディレクトリ構成・ファイル形式・値の表現・期待値の出所は、スキル port-lang の [conformance.md](../../.agents/skills/port-lang/references/conformance.md) に従う（[ADR 0013](../decision/0013-conformance-test-vectors.md)）。本書は ATRS 固有の事項だけを定める。

## 機能区分（`<feature>`）

`fare`, `flight-search`, `reservation`, `member`, `authentication`, `report`, `validation`, `format`, `http`（[atrs-porting.md](../rules/atrs-porting.md#機能名層をまたいで共通) の機能名と対応）。

## 操作名

| 操作 | 仕様 |
| --- | --- |
| `fare.basicFare`, `fare.fare`, `fare.totalFare` | [fare-calculation.md](fare-calculation.md) |
| `flightSearch.validateDepartureDate`, `flightSearch.isAvailableFareType`, `flightSearch.searchFlight` | [flight-search.md](flight-search.md) |
| `reservation.validateFlightList`, `reservation.validateReservation`, `reservation.reserveConfirm`, `reservation.reserve` | [reservation.md](reservation.md) |
| `member.toMember`, `member.toMemberUpdateInput`, `member.register`, `member.update` | [member.md](member.md) |
| `auth.login`, `auth.logout` | [authentication.md](authentication.md) |
| `report.reportFileName`, `report.renderCsv`, `report.createReport`, `report.listReports` | [reservation-history-report.md](reservation-history-report.md) |
| `validation.<入力名>` | [input-validation.md](input-validation.md) |
| `format.fmtDate`, `format.fmtTime`, `format.fmtYen`, `format.fullYearsBetween` | [domain-model.md](domain-model.md) |
| `http.<リクエスト>` | [http-contract.md](http-contract.md) |

## 共有入力（fixtures）

| ファイル | 内容 |
| --- | --- |
| `fixtures/master-data.json` | 原典のシードデータ（空港 51・区間 20・便マスタ 126、搭乗クラス、運賃種別、ピーク時期、カード種別）。[master-data.md](master-data.md#シードデータ) |
| `fixtures/config.json` | 設定の既定値。[configuration.md](configuration.md) |
| `fixtures/world-*.json` | 状態を使う操作の初期状態（フライトの空席数、会員、予約） |

## ATRS 固有の前提

- `PasswordHasher` を使う操作のベクタは、参照ハッシュ `"{test}" ++ raw` を前提とする（[atrs-porting.md](../rules/atrs-porting.md#atrs-で採った値)）。
- ピーク時期のシードは投入年に依存するため、fixture では年を固定した値に置き換える。
- `source-model/` のベクタの `upstream` は `trace/upstream.json` の release・commit とする。
