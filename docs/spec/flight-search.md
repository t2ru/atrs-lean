---
type: Specification
title: "空席照会（B1）"
description: "搭乗日・区間・搭乗クラス・フライト種別から、予約可能な運賃種別ごとの空席数と運賃を出発時刻順に返す。"
tags: [spec, flight-search, b1]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T06:36:39+09:00
---

# 空席照会（B1）

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。
>
> 照会可能期間・運賃種別の予約可能判定・`searchFlight` は Lean [`Spec.FlightSearch`](../../lean/Spec/FlightSearch.lean) に形式化した（正。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。以下のそれらの定義は、Lean の非規範の要約である。[Source] の写しは [`SourceModel.FlightSearch`](../../lean/SourceModel/FlightSearch.lean)・[`SourceModel.Repository.Flight`](../../lean/SourceModel/Repository/Flight.lean)。適合テストベクタは `conformance/shared/flight-search/`。抽象機械 `searchMachine`・具体機械 `SourceModel.FlightSearchQuery.searchConcrete` と、シードの初期状態は第 2 段で置いた（[ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)）。リファインメント（ABS-010・ABS-011）は [backlog 0be7](../backlog/0be7-flight-search-usecase.md) の第 3 段で置く。

## 照会可能期間

**[Spec=Source]**

- `searchLimitDate(today) = addDays(today, limitDay)`
- `validateDepartureDate(depDate, today)`: `depDate < today ∨ depDate > searchLimitDate(today)` なら `Business("e.ar.b1.2001")`。両端を含む。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getSearchLimitDate()`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateDepatureDate(LocalDate)`

## 運賃種別の予約可能判定

**[Spec=Source]**

`isAvailableFareType(fareType, depDate, today)`:

```
start = addDays(depDate, −fareType.rsrvAvailableStartDayNum)
end   = addDays(depDate, −fareType.rsrvAvailableEndDayNum)
result = start ≤ today ≤ end
```

Lean の `Spec.FlightSearch.isAvailableFareType` は、次の日数の形で定義する（下の日付の形との同値は L 課題 ABS-010。backlog 0be7 の第 3 段）。これは `beforeDayNum = daysBetween(today, depDate)` について `rsrvAvailableEndDayNum ≤ beforeDayNum ≤ rsrvAvailableStartDayNum` と同値である（課題 [ABS-010](abstraction.md#証明課題)）。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#isAvailableFareType(FareType,LocalDate)`

## searchFlight

### シグネチャ

```
searchFlight(criteria: { depDate, boardingClassCd, depAirportCd, arrAirportCd, flightType },
             flights: [Flight]; master, config, today) : Except AtrsError [FlightVacantInfo]
```

`flights` はフライトの全件（[ports.md](ports.md) の `FlightRepository.findAll` 相当。抽象状態 `World.flights`。実装は絞り込みを永続化層に押し下げてよい）。
Lean では、MD-3 かフライトの参照整合性（`World.RefMaster`。FK_FLIGHT_1〜3）が破れて区間の空港名か搭乗クラスがマスタに無いとき（PRE の外）、結果を `none` とする。

### 事前条件

- [Source]: 各フィールドが null でない・空文字でない（`Assert`）。入力検証（[input-validation.md](input-validation.md)）を通過していれば満たされる。
- [Spec]（Lean `Spec.FlightSearch.SearchInput.Pre`）: 次の連言。どれも入力だけの条件である（[ADR 0b0c](../decision/0b0c-flight-search-stage3-abs011.md)）。
  - 設定とマスタの不変条件（MD-1〜MD-8）
  - 照会の搭乗クラスがマスタにあること（入力検証の `ExistInCodeList` に当たる）
  - 照会の空港コードが空白でないこと。空港コードの形（英大文字 3 文字）は課さない（形の違うコードは区間が無いので `e.ar.b1.2002`。[Source] も同じ）
  - 便マスタの便名が空白でないこと（`FlightNamesHaveText`）。空白の便名の便マスタが結果に現れると、[Source] は `getFlightMaster` の `Assert.hasText` で例外を投げる（D-033。PRE の外）
- フライトの参照整合性（`World.RefMaster`）は PRE に課さない。マスタに無い便名・運賃種別を指すフライトは、[Spec] の候補の条件でも [Source] の結合でも除かれる。

### 定義（評価順）

1. `validateDepartureDate(depDate, today)`。失敗時 `e.ar.b1.2001`。
2. `route = routeOf(depAirportCd, arrAirportCd)`。無ければ `Business("e.ar.b1.2002")`。
3. `beforeDayNum = daysBetween(today, depDate)`。
4. `fareTypeCds = fareTypesFor(flightType)`（[domain-model.md](domain-model.md#列挙)）。
5. 候補 `cs` = 次をすべて満たすフライト `f`:
   - `f.departureDate = depDate`
   - `flightMasterOf(f.flightName).routeNo = route.routeNo`
   - `f.boardingClassCd = boardingClassCd`
   - `f.fareTypeCd ∈ fareTypeCds`
   - `ft = fareTypeOf(f.fareTypeCd)` について `ft.rsrvAvailableEndDayNum ≤ beforeDayNum ≤ ft.rsrvAvailableStartDayNum`
   - **空席数 0 のフライトも含む**（除外しない）
6. `cs` を整列キー `(fareTypeOf(f.fareTypeCd).displayOrder, flightMasterOf(f.flightName).departureTime)` の昇順に並べる。
   - **[Spec]**: 同順位は `flightName` の昇順（MD-1・MD-2・MD-5 と `World` の主キーの一意性の下では同順位は生じない）。
   - **[Source]**: 同順位の順序は未規定（SQL の `ORDER BY` に含まれない）。
7. `cs` が空なら `NotFound("e.ar.b1.2003")`。
8. `b = basicFare(route.basicFare, boardingClassCd, depDate)`（全候補で共通）。
9. グループ化: `cs` を先頭から走査し、**便マスタの出発時刻**（`departureTime`）をキーとして、キーの初出順にグループ `FlightVacantInfo` を作る。
   - グループの見出し項目は、そのキーで最初に現れたフライトから作る（下表）。
   - 各フライト `f` について `fareTypes` に `f.fareTypeCd ↦ { fareTypeName, fare: fmtYen(fare(b, discountRate)), vacantNum: f.vacantNum }` を **挿入** する。同じキーが既にあれば値を置き換え、順序は最初の挿入位置のまま（[Source] の `LinkedHashMap.put`）。MD-1・MD-2・MD-5 と `World` の主キーの一意性の下ではグループ内の便は 1 つであり、置き換えは生じない。
10. グループの列を返す。

### 出力 FlightVacantInfo

| フィールド | 値 |
| --- | --- |
| `flightName` | `flightName` |
| `depAirportName` | 区間の出発空港の `name` |
| `arrAirportName` | 区間の到着空港の `name` |
| `depTime` | `fmtTime(departureTime)`（`HH:mm`） |
| `arrTime` | `fmtArrTime(arrivalTime)`（翌日着は `24:15` のように 24 時以降で表す。[Source] の `toFormatTimeString` と同じ） |
| `depDate` | `fmtDate(departureDate)`（`yyyy/MM/dd`） |
| `boardingClassCd` | `boardingClassCd` |
| `fareTypes`（`fare` は `fmtYen`。[Source] の区切り文字は既定の書式ロケールによる。既知差異 [D-032](abstraction.md#既知差異)） | 順序付き写像 `FareTypeCd ↦ { fareTypeName: String, fare: String, vacantNum: Nat }` |

出力の順序の性質: 第 1 グループの並びは「最も表示順の小さい運賃種別を持つ便の出発時刻順」であり、単純な出発時刻順ではない。
例えば片道照会で搭乗日が 10 日後なら、`OW`（表示順 1）は全便にあるので全グループが出発時刻順になる。一方、ある便に `OW` の行が無ければ、その便のグループは後ろに回る。

### エラー

| 条件 | エラー |
| --- | --- |
| 搭乗日が照会可能期間外 | `Business("e.ar.b1.2001")` |
| 区間が存在しない | `Business("e.ar.b1.2002")` |
| 候補が 0 件 | `NotFound("e.ar.b1.2003")` |

### 例

`today = 2026-04-01`、区間 HND→ITM（路線基本運賃 20600）、便 NTT001（09:00–10:00）・NTT031（09:45–10:45）、
`depDate = 2026-04-11`（ピーク時期外）、`N`、`OW` のとき `beforeDayNum = 10`。
候補となる運賃種別は `OW`(0–90), `RD1`(1–60), `RD7`(7–60), `LD`(1–60), `GD`(1–60), `SRD` は `S` 専用のため無し、`ED`(30–60) は対象外。
結果は 2 グループ（09:00, 09:45）、各グループの `fareTypes` は `OW: "20,600"`, `RD1: "18,600"`, `RD7: "16,500"`, `LD: "14,500"`, `GD: "14,500"` の順。

（`fare(20600, 10) = ceilTo(18540, 100) = 18600`、`fare(20600, 20) = ceilTo(16480, 100) = 16500`、`fare(20600, 30) = ceilTo(14420, 100) = 14500`）

出典: `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)`（private の `createFlightVacantInfoList` を含む）, `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria`

## 照会画面の初期値

**[Spec=Source]**

- 照会条件の初期値: `flightType = defaultFlightType`, `depAirportCd = defaultDepAirportCd`, `arrAirportCd = defaultArrAirportCd`, `outwardDate = today`, `homewardDate = today`, `boardingClassCd = defaultBoardingClassCd`。
- 照会可能期間の表示: `beginningPeriod = today`, `endingPeriod = searchLimitDate(today)`, `reserveIntervalTime = config.reserveIntervalTime`。

出典: `java:jp.co.ntt.atrs.app.b1.TicketSearchHelper#createDefaultTicketSearchForm()`, `java:jp.co.ntt.atrs.app.b1.TicketSearchHelper#createFlightSearchOutputDto()`
