---
type: Specification
title: "設定パラメータ"
description: "業務規則に影響する設定値とその既定値。純粋関数には Config として明示的に渡す。"
tags: [spec, configuration]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:52:11+09:00
---

# 設定パラメータ

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

**[Spec=Source]** 業務規則に影響する設定値は `Config` レコードにまとめ、純粋関数・ユースケースに明示的に渡す。
既定値は原典の設定ファイルの値である。

出典: atrs-domain/src/main/resources/META-INF/spring/atrs.properties, atrs-env/src/main/resources/META-INF/spring/atrs-infra.properties

## Config

| フィールド | 原典キー | 型 | 既定値 | 意味 |
| --- | --- | --- | --- | --- |
| `limitDay` | `atrs.limitDay` | Nat | `90` | 照会可能限界日数。今日から何日後の搭乗日まで空席照会できるか。予約（`validateFlightList`・`reserve`）では検査しない（予約で見るのは運賃種別の予約可能期間だけ。[reservation.md](reservation.md#validateflightlist)）。出典: d/service/b0/TicketSharedServiceImpl.java `getSearchLimitDate` |
| `reserveIntervalTime` | `atrs.reserveIntervalTime` | Nat（分） | `120` | 往路の到着時刻から、復路として予約可能になる出発時刻までの最小間隔 |
| `representativeMinAge` | `atrs.representativeMinAge` | Nat | `18` | 予約代表者の最小年齢 |
| `adultPassengerMinAge` | `atrs.adultPassengerMinAge` | Nat | `12` | 大人運賃が適用される最小年齢（未満は小児） |
| `childFareRate` | `atrs.childFareRate` | Nat（%） | `60` | 大人運賃に対する小児運賃の比率 |
| `dateOfBirthMinDate` | `atrs.dateOfBirthMinDate` | Date | `1900-01-01` | 会員登録できる生年月日の下限 |
| `defaultFlightType` | `default.flightType` | FlightType | `RT` | 空席照会画面の初期値 |
| `defaultDepAirportCd` | `default.depAirportCd` | AirportCd | `HND` | 空席照会画面の初期値 |
| `defaultArrAirportCd` | `default.arrAirportCd` | AirportCd | `HND` | 空席照会画面の初期値（出発と同じ値が既定である点も原典どおり） |
| `defaultBoardingClassCd` | `default.boardingClassCd` | BoardingClassCd | `N` | 空席照会画面の初期値 |

## 画面・入力に関する定数

| 名前 | 値 | 意味 | 出典 |
| --- | --- | --- | --- |
| `initialPassengersNumber` | `3` | 予約画面で最初に表示する搭乗者欄の数 | atrs-web/.../app/b2/TicketReserveForm.java |
| `maxPassengersNumber` | `6` | 1 予約の最大搭乗者数 | 同上 |
| `telAreaAndLocalMinLength` | `6` | 電話番号[1]+[2] の合計桁数の下限 | atrs-domain/.../common/validate/ValidationUtil.java |
| `telAreaAndLocalMaxLength` | `7` | 同上限 | 同上 |
| `transactionTokenSizePerNamespace` | `20` | トランザクショントークンの保持数（契約外。参考） | atrs-web/.../config/web/SpringMvcConfig.java |

## 不変条件

[Spec] は次を前提とする（[Source] では検査しない）。

- `childFareRate ≤ 100`
- すべての運賃種別について `discountRate ≤ childFareRate`（[fare-calculation.md](fare-calculation.md#合計金額) の小児運賃が負にならないため。破れた場合の [Source] の振る舞いは、参考 [D-003](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない）
- `adultPassengerMinAge ≤ representativeMinAge`
