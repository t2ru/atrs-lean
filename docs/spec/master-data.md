---
type: Specification
title: "マスタデータ"
description: "空港・区間・便マスタ・搭乗クラス・運賃種別・ピーク時期・機材・カード種別の構造、不変条件、参照関数、シードデータ。"
tags: [spec, master-data]
status: draft
spec_role: [informative, draft]
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T08:12:23+09:00
sources:
  - id: seed-fixed
    resource: https://github.com/terasolunaorg/atrs/blob/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf/atrs/atrs-initdb/src/sqls/integration-test-postgres/00200_insert_fixed_value.sql
    title: 00200_insert_fixed_value.sql
---

# マスタデータ

> **区分: 要約（informative）と草案（draft）の混在。** 構造・不変条件・参照関数・コードリストは Lean に形式化した（[`Spec.MasterData`](../../lean/Spec/MasterData.lean)、[`Spec.CodeList`](../../lean/Spec/CodeList.lean)。[backlog 0003](../backlog/0003-abstract-domain-types-and-master-data.md)）。これらの節の本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。「[Source] で破れた場合」と「シードデータ」は草案（draft）である。シードデータの内容は fixture（`conformance/fixtures/`）として管理し、Lean `Spec` には含めない。

マスタは起動時に読み込まれ、実行中は変化しない不変の値 `MasterData` として純粋関数に渡す（[ADR 0007](../decision/0007-functional-core-with-ports.md)）。
原典では `*Provider` クラスがキャッシュしている（出典: atrs-domain/.../common/masterdata/*Provider.java）。

## MasterData

| フィールド | 型 | キー |
| --- | --- | --- |
| `airports` | [Airport] | `code` |
| `routes` | [Route] | `routeNo`、および `(depAirportCd, arrAirportCd)` |
| `flightMasters` | [FlightMaster] | `flightName` |
| `boardingClasses` | [BoardingClass] | `boardingClassCd` |
| `fareTypes` | [FareType] | `fareTypeCd` |
| `peakTimes` | [PeakTime] | `(peakTimeCd, peakStartDate, peakEndDate)` |
| `planes` | [Plane] | `craftType` |
| `creditTypes` | [CreditType] | `creditTypeCd` |

### Airport

`code: AirportCd`, `name: String`（最大 15 文字）, `displayOrder: Nat`（一意）

### Route

`routeNo: Nat`, `depAirportCd`, `arrAirportCd`, `flightTime: String`（`HHmm`、参考値）, `basicFare: Nat`（路線基本運賃）

### FlightMaster

`flightName`, `routeNo`, `departureTime: HourMinute`, `arrivalTime: HourMinute`, `craftType`

到着時刻は **同じ日付の時刻** として扱う（原典は日付を跨ぐ便を想定していない。`arrivalTime < departureTime` の便は [Spec] の不変条件で禁止する）。

### BoardingClass

`boardingClassCd`, `boardingClassName: String`, `extraCharge: Nat`, `displayOrder: Nat`

### FareType

`fareTypeCd`, `fareTypeName: String`, `discountRate: Nat`（%）, `rsrvAvailableStartDayNum: Nat`, `rsrvAvailableEndDayNum: Nat`, `passengerMinNum: Nat`, `displayOrder: Nat`（一意）

### PeakTime

`peakTimeCd: String`, `peakStartDate: Date`, `peakEndDate: Date`, `multiplicationRatio: Nat`（%）

### Plane / CreditType

`Plane`: `craftType`, `nSeatNum`, `sSeatNum`（参考。業務ロジックでは未使用）。
`CreditType`: `creditTypeCd`, `creditFirm`, `displayOrder`。

## 不変条件（[Spec]）

Lean: `Spec.MasterData.Valid`（成分 `md1`〜`md8` が `MD1`〜`MD8`。判定可能）。MD-3 のうちフライトの参照整合性は、フライトを持つ `World` の不変条件で課す。

[Spec] の全定義は `MasterData` が次を満たすことを前提とする。[Source] はこれらを検査せず、満たさない場合の振る舞いは原典どおり（多くは「最初に見つかったもの」または上書き）である。

| ID | 不変条件 | [Source] で破れた場合 |
| --- | --- | --- |
| MD-1 | 各キーは一意。各マスタの `displayOrder` も一意（原典の DB 制約 `DISPLAY_ORDER INT NOT NULL UNIQUE` と同じ） | `HashMap` への後勝ち上書き。`displayOrder` の重複は DB が拒む |
| MD-2 | `(depAirportCd, arrAirportCd)` は区間間で一意。`depAirportCd ≠ arrAirportCd` | 後勝ち上書き |
| MD-3 | 参照整合性（区間の空港・便マスタの区間・フライトの便名/搭乗クラス/運賃種別が存在する） | `null` による前提違反 |
| MD-4 | ピーク時期の期間は互いに重ならない（`peakStartDate ≤ peakEndDate`） | 取得順（未規定）で最初に一致したもの（参考 [D-004](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-5 | 同一区間の便マスタは出発時刻が互いに異なる | 空席照会で同一出発時刻の便が 1 件に統合される（参考 [D-005](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-6 | 各便マスタで `departureTime ≤ arrivalTime` | — |
| MD-7 | 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1` | — |
| MD-8 | [domain-model.md](domain-model.md#値域) の値域 | int32 の折り返し |

マスタは不変の入力であり（[ports.md](ports.md#world抽象状態)）、MD-1〜MD-8 は [Spec] の各操作の事前条件 PRE に含まれる。リファインメントの証明義務は PRE の内についてだけ課される。破れた場合の [Source] の振る舞い（MD-1〜MD-3 は D-015、MD-4・MD-5 は D-004・D-005）は差異ではなく、参考として [abstraction.md](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) に記録する。

## 参照関数

**[Spec=Source]**（MD-1〜MD-4 の下で）Lean: `Spec.MasterData.routeOf` ほか。どれも先頭から調べて最初に一致したものを返し、不変条件の下では一致するものが高々 1 つなので、結果は並びに依存しない（`routeOf_eq_some_iff` など）。SPEC 課題（SPEC-001〜003）は、参照関数をまとめた抽象機械 `queryMachine` について証明した。

- `routeOf(dep, arr) : Route?` — `(dep, arr)` に一致する区間。無ければ無し。
- `flightMasterOf(name) : FlightMaster?`、`fareTypeOf(cd) : FareType?`、`boardingClassOf(cd) : BoardingClass?`
- `peakTimeOn(d) : PeakTime?` — `peakStartDate ≤ d ≤ peakEndDate` を満たすピーク時期。[Source] では `peakTimes` を取得順に走査し最初に一致したもの。
- `multiplicationRatioOn(d)` = `peakTimeOn(d)` があればその `multiplicationRatio`、無ければ `100`。

出典: atrs-domain/.../common/masterdata/PeakTimeProvider.java `getPeakTime`, RouteProvider.java `getRouteByAirportCd`, atrs-domain/.../service/b0/TicketSharedServiceImpl.java `getMultiplicationRatio`

## 空港コードリスト（画面用）

**[Spec=Source]** Lean: [`Spec.CodeList`](../../lean/Spec/CodeList.lean)。画面の空港選択肢（`CL_AIRPORT`）は、空港を `displayOrder` 昇順に並べ、`displayOrder ≥ 100` の最初の空港の直前に区切り行 `("NOP", "-----------")` を 1 つ挿入したものである。
入力検証の「コードリストに存在する」（[input-validation.md](input-validation.md)）は **区切り行の `NOP` も存在するものとして扱う**。そのため `NOP` を指定した空席照会は入力検証を通過し、区間が見つからずに業務エラー `e.ar.b1.2002` となる。

出典: atrs-domain/.../common/codelist/AirportCodeList.java `retrieveMap`, atrs-domain/.../config/app/AtrsCodeListConfig.java `CL_AIRPORT`

その他のコードリスト:

| ID | 値 | 表示 |
| --- | --- | --- |
| `CL_BOARDINGCLASS` | 搭乗クラスを `displayOrder` 順 | `boardingClassName` |
| `CL_FARETYPE` | 運賃種別を `displayOrder` 順 | `fareTypeName` |
| `CL_CREDITTYPE` | カード種別を `displayOrder` 順 | `creditFirm` |
| `CL_CREDITMONTH` | `"01"`〜`"12"` | 同左 |
| `CL_CREDITYEAR` | `"00"`〜`"99"` | 同左 |
| `CL_GENDER` | `M`, `F` | 男性, 女性 |
| `CL_FLIGHTTYPE` | `RT`, `OW` | 往復, 片道 |

## シードデータ

原典の初期データ[^seed-fixed]。適合テストの共有入力 `conformance/fixtures/master-data.json` の元になる（[backlog 0011](../backlog/0011-in-memory-adapters-and-seed-data.md)）。

### 搭乗クラス

| cd | 名前 | 加算料金 | 表示順 |
| --- | --- | --- | --- |
| `N` | 一般席 | 0 | 1 |
| `S` | 特別席 | 5000 | 2 |

### 運賃種別

| cd | 名前 | 割引率 | 予約開始（日前） | 予約終了（日前） | 最少人数 | 表示順 | 分類 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `OW` | 片道運賃 | 0 | 90 | 0 | 1 | 1 | 片道 |
| `RT` | 往復運賃 | 5 | 90 | 0 | 1 | 2 | 往復 |
| `RD1` | 予約割1 | 10 | 60 | 1 | 1 | 3 | 片道 |
| `RD7` | 予約割7 | 20 | 60 | 7 | 1 | 4 | 片道 |
| `ED` | 早期割 | 30 | 60 | 30 | 1 | 5 | 片道 |
| `LD` | レディース割 | 30 | 60 | 1 | 1 | 6 | 片道 |
| `GD` | グループ割 | 30 | 60 | 1 | 3 | 7 | 片道 |
| `SOW` | 特別片道運賃 | 0 | 90 | 0 | 1 | 100 | 片道 |
| `SRT` | 特別往復運賃 | 5 | 90 | 0 | 1 | 101 | 往復 |
| `SRD` | 特別予約割 | 10 | 60 | 1 | 1 | 102 | 片道 |

シードのフライトでは、`S` クラスには `SOW`/`SRT`/`SRD`、`N` クラスにはそれ以外の運賃種別だけが存在する（運賃種別と搭乗クラスの組合せの制約はマスタには無く、フライトの有無で表現される）。

### ピーク時期

初期データ投入時の年 `Y` と `Y+1` の 2 年分（投入時点の年に依存する）。fixture では `Y = 2026` とする（[conformance.md](conformance.md#atrs-固有の前提)）。

| cd | 期間 | 積算比率 |
| --- | --- | --- |
| `PEAK1` | 01/01–01/05, 03/20–03/31, 08/08–08/18, 12/26–12/31 | 140 |
| `PEAK2` | 03/13–03/19, 07/18–08/07, 08/19–08/31, 12/19–12/25 | 125 |

期間は互いに重ならない（MD-4 を満たす）。

### 空港・区間・便

- 空港 51 件（主要空港 9 件は表示順 1〜9、その他 42 件は表示順 100〜141）。
- 区間 20 件。路線基本運賃はすべて 100 円単位（20,100〜52,400 円）。
- 便マスタ 126 件。
- フライト: 投入日から 120 日後まで（両端を含む）の各日について、便ごとに搭乗クラス×運賃種別の行を作る。空席数は日ごとに 3 パターン（`i mod 3`）で変わる。fixture では投入日を 2026-11-01 とする（[ADR 0028](../decision/0028-clock-timezone-and-fixture-base-date.md)）。

### 会員

7 件（会員番号は `0000000001` から採番）。全員のパスワードは `aaaaa11111`（前回パスワード `aaaaa00000`）の `{pbkdf2}` ハッシュ。

### カード種別

`VIS`（VISA）, `MTR`（MASTER）, `JCB`（JCB）, `DNS`（DNS）, `AMX`（American Express）

> **TODO(spec):** 空港名・区間・便マスタの全件を、投入日 2026-11-01 として `conformance/fixtures/master-data.json` に転記する（[backlog 0011](../backlog/0011-in-memory-adapters-and-seed-data.md)）。

[^seed-fixed]: atrs-initdb/src/sqls/integration-test-postgres/00200〜00250_*.sql
