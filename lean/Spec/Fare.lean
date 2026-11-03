import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.EnvPre

/-!
# 運賃計算（`Spec.Fare`）

運賃計算。厳密整数で計算する（ADR e41d）。
[Source] との差異は D-001・D-002・D-012（[既知差異](../../docs/spec/abstraction.md#既知差異)）で、
リファインメントの証明は backlog bbcc で行う。

> **区分: 要約（informative）。** [Spec] は Lean [`Spec.Fare`](Fare.lean)、[Source] は Lean [`SourceModel.Domain.Service.B0.TicketSharedServiceImpl`](../SourceModel/Domain/Service/B0/TicketSharedServiceImpl.lean)・[`SourceModel.Domain.Common.Util.FareUtil`](../SourceModel/Domain/Common/Util/FareUtil.lean)・[`SourceModel.Domain.Service.B2.TicketReserveServiceImpl`](../SourceModel/Domain/Service/B2/TicketReserveServiceImpl.lean)（Provider のキャッシュは `SourceModel.Domain.Common.Masterdata.*Provider`。原典のクラスと 1 対 1。[ADR e41c](../../docs/decision/e41c-source-model-mirrors-java-tree.md)）に形式化した（[backlog 25f7](../../docs/backlog/25f7-fare-calculation-both-models.md)）。本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。例は適合テストベクタ `conformance/{spec,source-model,shared}/fare/` として両モデルで実行する（[ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md)）。
-/

namespace Spec.Fare
open Spec.Config Spec.Model Spec.Prim.Int Spec.Prim.Text

open Spec.Prim Spec.MasterData

/-!
## 基本運賃

### シグネチャ

`basicFare(routeBasicFare: Nat, boardingClassCd, depDate: Date; master) : Nat`

Lean: [Spec] `Spec.Fare.basicFare`（搭乗クラスが無ければ `none`）、[Source] `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare`（`getMultiplicationRatio` を含む）。

### 事前条件

- `boardingClassOf(boardingClassCd)` が存在する（`BasicFareInput.Pre` の連言。MD-3 は区間の空港と便マスタの区間だけを課し、搭乗クラスの存在は含まない）。無ければ [Source] は `NullPointerException`（参考 [D-035](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。
- [Source]: `routeBasicFare ≥ 0`（`Assert`）。違反時 `PreconditionViolation`。

### 定義

`extra = boardingClassOf(boardingClassCd).extraCharge`、`ratio = multiplicationRatioOn(depDate)`（[`Spec.MasterData`](MasterData.lean#参照関数)）として、

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

差異: [D-001](../../docs/spec/abstraction.md#既知差異)。[Source] は [Spec] に等しいか 1 小さい。1 小さいのは、`(routeBasicFare + extra) × ratio` が 100 で割り切れ、積算比率の因子 `ratio × 0.01`（double）が安全でない（`ratio/100` を `2^-54` 以上下回る）ときに限る。例えば `routeBasicFare + extra = 100, ratio = 29` で [Spec] は 29、[Source] は `100 × (29 × 0.01)` が `28.999999999999996` になり、切り捨てて 28 となる。`dev_D001` の下でのリファインメントは課題 [ABS-001](../../docs/spec/abstraction.md#証明課題)、差の条件は ABS-007（[ADR e9bc](../../docs/decision/e9bc-fare-double-analysis.md)）。

抽象機械は `Spec.Fare.basicFareMachine`（`Machine.pure`）である。PRE は、設定とマスタの不変条件、搭乗クラスがマスタに在ること、`routeBasicFare + extraCharge ≤ 10,000,000`（[値域](Model.lean#値域)）である。

### 例

| routeBasicFare | 搭乗クラス | 積算比率 | [Spec] | [Source] |
| --- | --- | --- | --- | --- |
| 20600 | N（0） | 100 | 20600 | 20600 |
| 20600 | N（0） | 140 | 28840 | 28840 |
| 20600 | S（5000） | 125 | 32000 | 32000 |
| 37900 | S（5000） | 140 | 60060 | 60060 |

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)`（private の `getMultiplicationRatio` を含む）
-/

/-- 基本運賃。`floorDiv((routeBasicFare + extra) * ratio, 100)`。搭乗クラスがマスタに無ければ `none`（PRE: `BasicFareInput.Pre`。MD-3 は搭乗クラスの存在を課さない）。 -/
@[spec_doc "lean/Spec/Fare.lean#基本運賃", gap "D-001"]
def basicFare (md : MasterData) (routeBasicFare : Nat) (cd : BoardingClassCd) (depDate : Date) : Option Nat :=
  (md.boardingClassOf cd).map fun bc => (routeBasicFare + bc.extraCharge) * md.multiplicationRatioOn depDate / 100

/-!
## 運賃

大人 1 名・1 区間あたりの運賃。

### シグネチャ

`fare(basicFare: Nat, discountRate: Nat) : Nat`

Lean: [Spec] `Spec.Fare.fare`、[Source] `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare`（`FareUtil.ceilFare` は `SourceModel.Domain.Common.Util.FareUtil.ceilFare`）。1430 円・30% の例は、定理 `Spec.Fare.fare_1430_30`（1100）と `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateFare_1430_30`（1000）である。

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

差異: [D-002](../../docs/spec/abstraction.md#既知差異)。[Source] は [Spec] に等しいか 100 円少ない。少ないのは、`basicFare × (100 − discountRate) ≡ 100 (mod 10000)`（1 円未満を切り捨てた値が `≡ 1 (mod 100)`）で、割引率の因子 `1 − discountRate × 0.01`（double）が安全でないときに限る（[ADR e9bc](../../docs/decision/e9bc-fare-double-analysis.md)）。例えば `basicFare = 1430, discountRate = 30` で [Spec] は `floorDiv(1430 * 70, 100) = 1001 → 1100`、
[Source] は `1430 * 0.69999999999999995559… = 1000.99…` を切り捨てて `1000 → 1000` となる。

抽象機械は `Spec.Fare.fareMachine`（`Machine.pure`）である。PRE は、`basicFare ≤ 100,000,000`・`discountRate ≤ 100`（[値域](Model.lean#値域)）である。

### 例

| basicFare | discountRate | [Spec] | [Source] |
| --- | --- | --- | --- |
| 20600 | 0 | 20600 | 20600 |
| 20600 | 5 | 19600 | 19600 |
| 28840 | 30 | 20200 | 20200 |
| 32000 | 10 | 28800 | 28800 |
| 1430 | 30 | 1100 | **1000** |
| 0 | 30 | 0 | 0 |

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)`, `java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)`
-/

/-- 運賃（大人 1 名・1 区間）。基本運賃に `(100 − discountRate)`% を掛けて 1 円未満を切り捨て、100 円単位に切り上げる。 -/
@[spec_doc "lean/Spec/Fare.lean#運賃", gap "D-002"]
def fare (basicFare discountRate : Nat) : Nat :=
  ceilTo (pct basicFare (100 - discountRate)) 100

/-!
## 合計金額

予約全体の支払額。

### シグネチャ

`totalFare(flights: [Flight], passengers: [Passenger]; master, config) : Nat`

Lean: [Spec] `Spec.Fare.totalFare`（便・区間・搭乗クラス・運賃種別のどれかが無ければ `none`）、[Source] `SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare`。

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

差異: [D-002](../../docs/spec/abstraction.md#既知差異)（`fare` 経由）、[D-012](../../docs/spec/abstraction.md#既知差異)（`b × (childFareRate − r)` が int32 を超えるとき、[Source] の `j32mul` が折り返す）。`discountRate > childFareRate` のときの [Source] の振る舞い（D-003）は、[Spec] の前提 MD-7 の外なので差異ではない（[abstraction.md](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。

抽象機械は `Spec.Fare.totalFareMachine`（`Machine.pure`）である。入力はフライトのキーの列と搭乗者の年齢の列で、合計金額はこの 2 つだけで決まる（`totalFareOfKeys`）。PRE は、設定とマスタの不変条件、予約フライト数 1〜2・搭乗者数 1〜6・年齢 0〜999（[値域](Model.lean#値域)）、便名が空白でないこと、各フライトの便マスタ・区間・搭乗クラス・運賃種別がマスタに在ること（`totalFareOfKeys` が値を持つこと）である。PRE の外での [Source] の前提違反（`Assert`・`NullPointerException`）は、参考 [D-035](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。

### 例

設定 `childFareRate = 60`, `adultPassengerMinAge = 12`。

| ケース | フライト | 搭乗者 | [Spec] = [Source] |
| --- | --- | --- | --- |
| 片道・大人 1 | 基本運賃 20600, OW(0%) | 30 歳 | 20600 |
| 片道・大人 2 小児 1 | 基本運賃 20600, OW(0%) | 30, 28, 5 歳 | 20600×2 + floorDiv(20600×60, 100)×1 = 41200 + 12360 = 53560 → **53600** |
| 往復・大人 1 | 往路 基本運賃 20600 RT(5%), 復路 基本運賃 20600 RT(5%) | 40 歳 | 19600 + 19600 = **39200** |
| 往復・大人 1 小児 1 | 同上 | 40, 11 歳 | (19600 + floorDiv(20600×55,100)) × 2 = (19600 + 11330) × 2 = 61860 → **61900** |

出典: `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)`
-/

/-- 便名の区間（便マスタの区間番号で引く）。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def routeOfFlightName (md : MasterData) (name : FlightName) : Option Route := do
  let fm ← md.flightMasterOf name.val
  md.routes.find? fun r => r.routeNo == fm.routeNo

/-- 便の区間。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def routeOfFlight (md : MasterData) (f : Flight) : Option Route := routeOfFlightName md f.key.flightName

/-- 小児（`age < adultPassengerMinAge`）の人数（搭乗者の年齢の列から）。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def childNumOfAges (cfg : Config) (ages : List Nat) : Nat :=
  (ages.filter fun a => decide (a < cfg.adultPassengerMinAge)).length

/-- 小児（`age < adultPassengerMinAge`）の人数。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def childNum (cfg : Config) (passengers : List Passenger) : Nat := childNumOfAges cfg (passengers.map (·.age))

/-- 1 便の合計（100 円単位の切上げ前）。フライトのキーと搭乗者の年齢の列から決まる。
小児 1 名分は `floorDiv(b * (childFareRate − r), 100)`。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額", gap "D-003", "D-012"]
def flightTotalOfKey (cfg : Config) (md : MasterData) (ages : List Nat) (k : FlightKey) : Option Nat := do
  let route ← routeOfFlightName md k.flightName
  let b ← basicFare md route.basicFare k.boardingClassCd k.departureDate
  let ft ← md.fareTypeOf k.fareTypeCd
  let r := ft.discountRate
  let child := childNumOfAges cfg ages
  let adult := ages.length - child
  return fare b r * adult + pct b (cfg.childFareRate - r) * child

/-- 1 便の合計（100 円単位の切上げ前）。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def flightTotal (cfg : Config) (md : MasterData) (passengers : List Passenger) (f : Flight) : Option Nat :=
  flightTotalOfKey cfg md (passengers.map (·.age)) f.key

/-- 合計金額（フライトのキーの列と搭乗者の年齢の列から）。100 円単位の切上げは合計にだけ行う。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def totalFareOfKeys (cfg : Config) (md : MasterData) (keys : List FlightKey) (ages : List Nat) : Option Nat := do
  let parts ← keys.mapM (flightTotalOfKey cfg md ages)
  return ceilTo parts.sum 100

/-- 合計金額。すべてのフライトに同じ搭乗者列が搭乗する。100 円単位の切上げは合計にだけ行う。
マスタに便・区間・搭乗クラス・運賃種別が無ければ `none`（PRE: `TotalFareInput.Pre` の `totalFareOfKeys` の連言。MD-3 は区間の空港と便マスタの区間だけを課す）。合計金額が観測するのは、フライトのキーと
搭乗者の年齢だけである（`totalFare`＝`totalFareOfKeys`）。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def totalFare (cfg : Config) (md : MasterData) (flights : List Flight) (passengers : List Passenger) : Option Nat :=
  totalFareOfKeys cfg md (flights.map (·.key)) (passengers.map (·.age))

theorem totalFare_eq (cfg : Config) (md : MasterData) (flights : List Flight) (passengers : List Passenger) :
    totalFare cfg md flights passengers = totalFareOfKeys cfg md (flights.map (·.key)) (passengers.map (·.age)) := rfl

/-! ## 抽象機械（R 課題 ABS-001・ABS-002 の抽象側） -/

/-- 基本運賃の入力。マスタ・設定は不変の入力である。 -/
@[raw_input "機械の入力。妥当性 BasicFareInput.Pre は PRE"]
structure BasicFareInput where
  cfg : Config
  md : MasterData
  routeBasicFare : Nat
  boardingClassCd : BoardingClassCd
  depDate : Date

/-- 基本運賃の PRE: 設定とマスタの検証が通ること（`EnvPre.masterConfigOk`。設定の不変条件と MD-1〜MD-8）、搭乗クラスがマスタに在ること、
`routeBasicFare + extraCharge` の値域（`lean/Spec/Model.lean#値域`）。 -/
@[spec_doc "lean/Spec/Fare.lean#基本運賃", gap "D-035"]
def BasicFareInput.Pre (i : BasicFareInput) : Prop :=
  EnvPre.masterConfigOk (i.cfg, i.md) ∧
    (i.md.boardingClassOf i.boardingClassCd).any (fun bc => decide (i.routeBasicFare + bc.extraCharge ≤ Range.maxBasicFareWithCharge)) = true

instance (i : BasicFareInput) : Decidable i.Pre := by unfold BasicFareInput.Pre; infer_instance

/-- 基本運賃の抽象機械（状態を持たない）。PRE の下で、`basicFare` は値を持つ。 -/
@[spec_doc "lean/Spec/Fare.lean#基本運賃"]
def basicFareMachine : Machine.Machine Unit BasicFareInput Nat :=
  Machine.Machine.pure BasicFareInput.Pre fun i => (basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).getD 0

/-- 運賃の入力。 -/
@[raw_input "機械の入力。妥当性 FareInput.Pre は PRE"]
structure FareInput where
  basicFare : Nat
  discountRate : Nat

/-- 運賃の PRE: 基本運賃と割引率の値域。 -/
@[spec_doc "lean/Spec/Fare.lean#運賃", gap "D-030"]
def FareInput.Pre (i : FareInput) : Prop := i.basicFare ≤ Range.maxBasicFare ∧ i.discountRate ≤ Range.maxDiscountRate

instance (i : FareInput) : Decidable i.Pre := by unfold FareInput.Pre; infer_instance

/-- 運賃の抽象機械（状態を持たない）。 -/
@[spec_doc "lean/Spec/Fare.lean#運賃"]
def fareMachine : Machine.Machine Unit FareInput Nat :=
  Machine.Machine.pure FareInput.Pre fun i => fare i.basicFare i.discountRate

/-- SPEC-001: PRE の下で、標準の選択は関係に含まれる。 -/
@[obligation "SPEC-001"]
theorem basicFareMachine_run_step :
    ∀ s i, basicFareMachine.Pre s i → basicFareMachine.step s i (basicFareMachine.run s i).1 (basicFareMachine.run s i).2 :=
  basicFareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem basicFareMachine_sound : basicFareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem basicFareMachine_initIs : basicFareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- SPEC-001。 -/
@[obligation "SPEC-001"]
theorem fareMachine_run_step :
    ∀ s i, fareMachine.Pre s i → fareMachine.step s i (fareMachine.run s i).1 (fareMachine.run s i).2 :=
  fareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem fareMachine_sound : fareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem fareMachine_initIs : fareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- 合計金額の入力: 設定・マスタ・フライトのキーの列・搭乗者の年齢の列。 -/
@[raw_input "機械の入力。妥当性 TotalFareInput.Pre は PRE"]
structure TotalFareInput where
  cfg : Config
  md : MasterData
  flights : List FlightKey
  ages : List Nat

/-- 合計金額の PRE: 設定とマスタの検証が通ること（`EnvPre.masterConfigOk`。設定の不変条件と MD-1〜MD-8）、予約フライト数（1〜2）と搭乗者数（1〜6）と年齢（0〜999）の値域、
便名が空白でないこと（原典の `Assert.hasText`）、各フライトの便マスタ・区間・搭乗クラス・運賃種別がマスタに在ること。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額", gap "D-035"]
def TotalFareInput.Pre (i : TotalFareInput) : Prop :=
  EnvPre.masterConfigOk (i.cfg, i.md) ∧
    Range.minReserveFlights ≤ i.flights.length ∧ i.flights.length ≤ Range.maxReserveFlights ∧
    Range.minPassengers ≤ i.ages.length ∧ i.ages.length ≤ Range.maxPassengers ∧
    (∀ a ∈ i.ages, a ≤ Range.maxAge) ∧
    (∀ k ∈ i.flights, hasText k.flightName.val = true) ∧
    (totalFareOfKeys i.cfg i.md i.flights i.ages).isSome = true

instance (i : TotalFareInput) : Decidable i.Pre := by unfold TotalFareInput.Pre; infer_instance

/-- 合計金額の抽象機械（状態を持たない）。 -/
@[spec_doc "lean/Spec/Fare.lean#合計金額"]
def totalFareMachine : Machine.Machine Unit TotalFareInput Nat :=
  Machine.Machine.pure TotalFareInput.Pre fun i => (totalFareOfKeys i.cfg i.md i.flights i.ages).getD 0

/-- SPEC-001。 -/
@[obligation "SPEC-001"]
theorem totalFareMachine_run_step :
    ∀ s i, totalFareMachine.Pre s i → totalFareMachine.step s i (totalFareMachine.run s i).1 (totalFareMachine.run s i).2 :=
  totalFareMachine.run_step

/-- SPEC-002・SPEC-003。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem totalFareMachine_sound : totalFareMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007。 -/
@[obligation "SPEC-007"]
theorem totalFareMachine_initIs : totalFareMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩

/-- PRE の下で、基本運賃は値を持つ。 -/
theorem basicFare_isSome {i : BasicFareInput} (h : i.Pre) :
    (basicFare i.md i.routeBasicFare i.boardingClassCd i.depDate).isSome = true := by
  obtain ⟨-, h⟩ := h
  unfold basicFare
  cases hb : i.md.boardingClassOf i.boardingClassCd <;> simp_all

/-- D-002 の例: 基本運賃 1430 円・割引率 30% で 1100 円（[Source] は 1000 円）。 -/
theorem fare_1430_30 : fare 1430 30 = 1100 := by decide

end Spec.Fare

/-!
## 画面表示用の運賃

空席照会結果・予約確認画面では `fmtYen(fare)`（[`Spec.Prim.Format`](Prim/Format.lean#書式)）で表示する。予約画面のフライト一覧の運賃（`SelectFlightDto.fare`）は `fare(basicFare(...), discountRate)` の整数値である。

出典: `java:jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl#searchFlight(TicketSearchCriteriaDto)`（private の `createFlightVacantInfoList` を含む）, `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#createSelectFlightDtoList(List)`
-/
