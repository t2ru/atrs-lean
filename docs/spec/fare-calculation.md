---
type: Specification
title: "運賃計算"
description: "基本運賃・運賃（大人 1 名）・合計金額（大人・小児、往復）の計算と 100 円単位の切上げ。[Spec] は厳密整数、[Source] は Java の double/int32 意味論。"
tags: [spec, fare]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 運賃計算

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

## 基本運賃

### シグネチャ

`basicFare(routeBasicFare: Nat, boardingClassCd, depDate: Date; master) : Nat`

### 事前条件

- `boardingClassOf(boardingClassCd)` が存在する（MD-3）。
- [Source]: `routeBasicFare ≥ 0`（`Assert`）。違反時 `PreconditionViolation`。

### 定義

`extra = boardingClassOf(boardingClassCd).extraCharge`、`ratio = multiplicationRatioOn(depDate)`（[master-data.md](master-data.md#参照関数)）として、

**[Spec]**

```
basicFare = floorDiv((routeBasicFare + extra) * ratio, 100)
```

**[Source]**

```
basicFare = jd2i( jdmul( jd(j32add(routeBasicFare, extra)),
                         jdmul( jd(ratio), jdLit("0.01") ) ) )
```

（原典: `(int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))`）

差異: [D-001](abstraction.md#既知差異)。値域内（[domain-model.md](domain-model.md#値域)）での一致は課題 [ABS-001](abstraction.md#証明課題)。

### 例

| routeBasicFare | 搭乗クラス | 積算比率 | [Spec] | [Source] |
| --- | --- | --- | --- | --- |
| 20600 | N（0） | 100 | 20600 | 20600 |
| 20600 | N（0） | 140 | 28840 | 28840 |
| 20600 | S（5000） | 125 | 32000 | 32000 |
| 37900 | S（5000） | 140 | 60060 | 60060 |

出典: atrs-domain/.../service/b0/TicketSharedServiceImpl.java `calculateBasicFare`, `getMultiplicationRatio`

## 運賃

大人 1 名・1 区間あたりの運賃。

### シグネチャ

`fare(basicFare: Nat, discountRate: Nat) : Nat`

### 事前条件

- `0 ≤ discountRate ≤ 100`。[Source]: さらに `basicFare ≥ 0`（いずれも `Assert`。違反時 `PreconditionViolation`）。

### 定義

**[Spec]**

```
fare = ceilTo( floorDiv(basicFare * (100 − discountRate), 100), 100 )
```

すなわち「基本運賃に (100 − 割引率)% を掛けて 1 円未満を切り捨て、100 円未満を切り上げる」。

**[Source]**

```
fare = bdCeilHundredUp( jd2i( jdmul( jd(basicFare),
                                     jdsub( jd(1), jdmul( jd(discountRate), jdLit("0.01") ) ) ) ) )
```

（原典: `FareUtil.ceilFare((int) (basicFare * (1 - (discountRate * 0.01))))`）

差異: [D-002](abstraction.md#既知差異)。例えば `basicFare = 1430, discountRate = 30` で [Spec] は `floorDiv(1430 * 70, 100) = 1001 → 1100`、
[Source] は `1430 * 0.69999999999999995559… = 1000.99…` を切り捨てて `1000 → 1000` となる。

### 例

| basicFare | discountRate | [Spec] | [Source] |
| --- | --- | --- | --- |
| 20600 | 0 | 20600 | 20600 |
| 20600 | 5 | 19600 | 19600 |
| 28840 | 30 | 20200 | 20200 |
| 32000 | 10 | 28800 | 28800 |
| 1430 | 30 | 1100 | **1000** |
| 0 | 30 | 0 | 0 |

出典: atrs-domain/.../service/b0/TicketSharedServiceImpl.java `calculateFare`, atrs-domain/.../common/util/FareUtil.java `ceilFare`

## 合計金額

予約全体の支払額。

### シグネチャ

`totalFare(flights: [Flight], passengers: [Passenger]; master, config) : Nat`

### 事前条件

- `flights` は 1 件以上、`passengers` は 1 件以上（[Source]: `Assert`）。
- 各フライトの便マスタ・区間・搭乗クラス・運賃種別が存在する。
- [Spec]: 各運賃種別で `discountRate ≤ childFareRate`（MD-7）。

### 定義

`childNum` = `age < adultPassengerMinAge` の搭乗者数、`adultNum = len(passengers) − childNum`。
**すべてのフライトに同じ搭乗者列が搭乗する**（往復予約の往路・復路で搭乗者は同一）。

各フライト `f` について、`b = basicFare(routeOf(f).basicFare, f.boardingClassCd, f.departureDate)`、`r = fareTypeOf(f.fareTypeCd).discountRate` として、

**[Spec]**

```
flightTotal(f) = fare(b, r) * adultNum + floorDiv(b * (childFareRate − r), 100) * childNum
totalFare      = ceilTo( Σ_f flightTotal(f), 100 )
```

小児 1 名分は「基本運賃 × (小児運賃比率 − 割引率)%」の 1 円未満切捨てで、**100 円単位の切上げは合計にだけ** 行う（原典どおり）。

**[Source]**

```
boardingFare(f) = fare_Source(b, r)
childPart(f)    = j32mul( jdiv32( j32mul(b, j32sub(childFareRate, r)), 100 ), childNum )
flightTotal(f)  = j32add( j32mul(boardingFare(f), adultNum), childPart(f) )
totalFare       = bdCeilHundredUp( foldl j32add 0 [flightTotal(f) | f ← flights] )
```

（原典: `boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum` を左から評価）

差異: [D-002](abstraction.md#既知差異)（`fare` 経由）、[D-003](abstraction.md#既知差異)（`discountRate > childFareRate` のとき）。

### 例

設定 `childFareRate = 60`, `adultPassengerMinAge = 12`。

| ケース | フライト | 搭乗者 | [Spec] = [Source] |
| --- | --- | --- | --- |
| 片道・大人 1 | 基本運賃 20600, OW(0%) | 30 歳 | 20600 |
| 片道・大人 2 小児 1 | 基本運賃 20600, OW(0%) | 30, 28, 5 歳 | 20600×2 + floorDiv(20600×60, 100)×1 = 41200 + 12360 = 53560 → **53600** |
| 往復・大人 1 | 往路 基本運賃 20600 RT(5%), 復路 基本運賃 20600 RT(5%) | 40 歳 | 19600 + 19600 = **39200** |
| 往復・大人 1 小児 1 | 同上 | 40, 11 歳 | (19600 + floorDiv(20600×55,100)) × 2 = (19600 + 11330) × 2 = 61860 → **61900** |

出典: atrs-domain/.../service/b2/TicketReserveServiceImpl.java `calculateTotalFare`

## 画面表示用の運賃

空席照会結果・予約確認画面では `fmtYen(fare)`（[domain-model.md](domain-model.md#書式)）で表示する。予約画面のフライト一覧の運賃（`SelectFlightDto.fare`）は `fare(basicFare(...), discountRate)` の整数値である。

出典: atrs-domain/.../service/b1/TicketSearchServiceImpl.java `createFlightVacantInfoList`, atrs-web/.../app/b2/TicketReserveHelper.java `createSelectFlightDtoList`
