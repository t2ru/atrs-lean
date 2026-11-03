import Machine
import Spec.Config

/-!
# マスタデータ（`Spec.MasterData`）

マスタデータ。起動時に読み込まれ、実行中は変化しない不変の入力であり、
`World` には含めない。不変条件 MD-1〜MD-8（`MasterData.Valid`）は、[Spec] の各操作の PRE に含める。

- 参照関数は、各マスタを先頭から調べて最初に一致したものを返す。MD-1〜MD-4 の下では一致するものは
  高々 1 つなので、結果は順序に依存しない（`routeOf_eq_some_iff` など）。
- SPEC 課題（SPEC-001〜003）: 参照関数をまとめた状態を持たない抽象機械 `queryMachine` について示す。

> **区分: 要約（informative）と草案（draft）の混在。** 構造・不変条件・参照関数・コードリストは Lean に形式化した（[`Spec.MasterData`](MasterData.lean)、[`Spec.CodeList`](CodeList.lean)。[backlog 591d](../../docs/backlog/591d-abstract-domain-types-and-master-data.md)）。これらの節の本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。「[Source] で破れた場合」と「シードデータ」は草案（draft）である。シードデータの内容は fixture（`conformance/fixtures/`）として管理し、Lean `Spec` には含めない。

マスタは起動時に読み込まれ、実行中は変化しない不変の値 `MasterData` として純粋関数に渡す（[ADR f0e4](../../docs/decision/f0e4-functional-core-with-ports.md)）。
原典では `*Provider` クラスがキャッシュしている（出典: atrs-domain/.../common/masterdata/*Provider.java）。

資料: [00200_insert_fixed_value.sql](https://github.com/terasolunaorg/atrs/blob/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf/atrs/atrs-initdb/src/sqls/integration-test-postgres/00200_insert_fixed_value.sql)
-/

namespace Spec
open Spec.Config Spec.Model Spec.Prim.Time

open Spec.Prim

namespace MasterData

/-!
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

`routeNo: Nat`, `depAirportCd`, `arrAirportCd`, `basicFare: Nat`（路線基本運賃）。DB の `FLIGHT_TIME`（所要時間）は、原典のどの処理も読まないので [Spec] には持たない（[ADR c108](../../docs/decision/c108-master-data-source-model-and-spec-fixes.md)）

### FlightMaster

`flightName`, `routeNo`, `departureTime: HourMinute`, `arrivalTime: ArrivalTime`, `craftType`

到着時刻は **出発日 0:00 からの時分** で表し、24 時以降は翌日着である（[`Spec.Prim.Time`](Prim/Time.lean#arrivaltime)、[ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。シードの NTT523（HND→OKA）・NTT528（OKA→HND）の到着時刻は `2415`（翌日 0:15）である。`arrivalTime < departureTime` の便は [Spec] の不変条件 MD-6 で禁止する。

### BoardingClass

`boardingClassCd`, `boardingClassName: String`, `extraCharge: Nat`, `displayOrder: Nat`

### FareType

`fareTypeCd`, `fareTypeName: String`, `discountRate: Nat`（%）, `rsrvAvailableStartDayNum: Nat`, `rsrvAvailableEndDayNum: Nat`, `passengerMinNum: Nat`, `displayOrder: Nat`（一意）

### PeakTime

`peakTimeCd: String`, `peakStartDate: Date`, `peakEndDate: Date`, `multiplicationRatio: Nat`（%）

### Plane / CreditType

`Plane`: `craftType`, `nSeatNum`, `sSeatNum`（参考。業務ロジックでは未使用）。
`CreditType`: `creditTypeCd`, `creditFirm`, `displayOrder`。
-/

/-! ### マスタの型 -/

/-- 空港。 -/
@[spec_doc "lean/Spec/MasterData.lean#airport"]
structure Airport where
  code : AirportCd
  name : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 区間。 -/
@[spec_doc "lean/Spec/MasterData.lean#route"]
structure Route where
  routeNo : Nat
  depAirportCd : AirportCd
  arrAirportCd : AirportCd
  /-- 路線基本運賃。所要時間（DB の `FLIGHT_TIME`）は、原典のどの処理も読まないので持たない（ADR c108）。 -/
  basicFare : Nat
  deriving DecidableEq, Repr

/-- 便マスタ。到着時刻は出発日 0:00 からの時分で表す（翌日着は 24 時以降。ADR ce36）。 -/
@[spec_doc "lean/Spec/MasterData.lean#flightmaster"]
structure FlightMaster where
  flightName : FlightName
  routeNo : Nat
  departureTime : HourMinute
  arrivalTime : ArrivalTime
  craftType : String
  deriving DecidableEq

/-- 搭乗クラス。 -/
@[spec_doc "lean/Spec/MasterData.lean#boardingclass"]
structure BoardingClass where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "lean/Spec/MasterData.lean#faretype"]
structure FareType where
  fareTypeCd : FareTypeCd
  fareTypeName : String
  /-- 割引率（%）。 -/
  discountRate : Nat
  rsrvAvailableStartDayNum : Nat
  rsrvAvailableEndDayNum : Nat
  passengerMinNum : Nat
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- ピーク時期。 -/
@[spec_doc "lean/Spec/MasterData.lean#peaktime"]
structure PeakTime where
  peakTimeCd : String
  peakStartDate : Date
  peakEndDate : Date
  /-- 積算比率（%）。 -/
  multiplicationRatio : Nat
  deriving DecidableEq

/-- 機材（参考。業務ロジックでは使わない）。 -/
@[spec_doc "lean/Spec/MasterData.lean#plane--credittype"]
structure Plane where
  craftType : String
  nSeatNum : Nat
  sSeatNum : Nat
  deriving DecidableEq, Repr

/-- カード種別。 -/
@[spec_doc "lean/Spec/MasterData.lean#plane--credittype"]
structure CreditType where
  creditTypeCd : CreditTypeCd
  creditFirm : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 搭乗クラスの参照の結果（表示順を除く。表示順はコードリストの問い合わせだけが観測する）。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
structure BoardingClassInfo where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  deriving DecidableEq, Repr

/-- 運賃種別の参照の結果（表示順を除く）。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
structure FareTypeInfo where
  fareTypeCd : FareTypeCd
  fareTypeName : String
  discountRate : Nat
  rsrvAvailableStartDayNum : Nat
  rsrvAvailableEndDayNum : Nat
  passengerMinNum : Nat
  deriving DecidableEq, Repr

/-- 表示順を除いた射影。 -/
def BoardingClass.info (b : BoardingClass) : BoardingClassInfo :=
  ⟨b.boardingClassCd, b.boardingClassName, b.extraCharge⟩

/-- 表示順を除いた射影。 -/
def FareType.info (f : FareType) : FareTypeInfo :=
  ⟨f.fareTypeCd, f.fareTypeName, f.discountRate, f.rsrvAvailableStartDayNum, f.rsrvAvailableEndDayNum,
    f.passengerMinNum⟩

end MasterData

open MasterData in
/-- マスタデータ。 -/
@[spec_doc "lean/Spec/MasterData.lean#masterdata"]
structure MasterData where
  airports : List Airport
  routes : List Route
  flightMasters : List FlightMaster
  boardingClasses : List BoardingClass
  fareTypes : List FareType
  peakTimes : List PeakTime
  planes : List Plane
  creditTypes : List CreditType
  deriving DecidableEq

namespace MasterData

/-!
## 不変条件（[Spec]）

Lean: `Spec.MasterData.Valid`（成分 `md1`〜`md8` が `MD1`〜`MD8`。判定可能）。MD-3 のうちフライトの参照整合性は、フライトを持つ `World` の不変条件で課す。

[Spec] の全定義は `MasterData` が次を満たすことを前提とする。[Source] はこれらを検査せず、満たさない場合の振る舞いは原典どおり（多くは「最初に見つかったもの」または上書き）である。

| ID | 不変条件 | [Source] で破れた場合 |
| --- | --- | --- |
| MD-1 | 各キーは一意。各マスタの `displayOrder` も一意（原典の DB 制約 `DISPLAY_ORDER INT NOT NULL UNIQUE` と同じ） | `HashMap` への後勝ち上書き。`displayOrder` の重複は DB が拒む |
| MD-2 | `(depAirportCd, arrAirportCd)` は区間間で一意。`depAirportCd ≠ arrAirportCd` | 後勝ち上書き |
| MD-3 | 参照整合性（区間の空港・便マスタの区間。フライトの便名/搭乗クラス/運賃種別の存在は `World` の不変条件、運賃計算の入力が指すマスタの存在は各操作の PRE で課す） | `null` による前提違反（運賃計算の入力の場合は参考 [D-035](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)） |
| MD-4 | ピーク時期の期間は互いに重ならない（`peakStartDate ≤ peakEndDate`） | 取得順（未規定）で最初に一致したもの（参考 [D-004](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-5 | 同一区間の便マスタは出発時刻が互いに異なる | 空席照会で同一出発時刻の便が 1 件に統合される（参考 [D-005](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-6 | 各便マスタで `departureTime ≤ arrivalTime`（出発日 0:00 からの分数で比べる） | — |
| MD-7 | 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1` | — |
| MD-8 | [`Spec.Model`](Model.lean#値域) の値域（空港コードは区切り行のコード `NOP` でない。英大文字 3 文字の形式は型 `AirportCd` が持つ） | int32 の折り返し（参考 [D-030](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。空港コードに `-` があると区間のキーが衝突しうるが、[Spec] の型はそのマスタを表せない（[D-036](../../docs/spec/abstraction.md#既知差異)。D-027 に覆われる）。`NOP` の空港があると、コードリストの区切り行がその空港で置き換わる（参考 [D-029](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)） |

マスタは不変の入力であり（[`Spec.Port`](Port.lean#world抽象状態)）、MD-1〜MD-8 は [Spec] の各操作の事前条件 PRE に含まれる。リファインメントの証明義務は PRE の内についてだけ課される。破れた場合の [Source] の振る舞い（MD-1〜MD-3 は D-015、MD-4・MD-5 は D-004・D-005、MD-8 は D-029・D-030・D-036）は差異ではなく、参考として [abstraction.md](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) に記録する。
-/

/-! ### 不変条件 MD-1〜MD-8 -/

/-- MD-1: 各キーは一意。各マスタの `displayOrder` も一意。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-015"]
def MD1 (md : MasterData) : Prop :=
  (md.airports.map (·.code)).Nodup ∧ (md.routes.map (·.routeNo)).Nodup ∧
  (md.flightMasters.map (·.flightName)).Nodup ∧ (md.boardingClasses.map (·.boardingClassCd)).Nodup ∧
  (md.fareTypes.map (·.fareTypeCd)).Nodup ∧
  (md.peakTimes.map fun p => (p.peakTimeCd, p.peakStartDate, p.peakEndDate)).Nodup ∧
  (md.planes.map (·.craftType)).Nodup ∧ (md.creditTypes.map (·.creditTypeCd)).Nodup ∧
  (md.airports.map (·.displayOrder)).Nodup ∧ (md.boardingClasses.map (·.displayOrder)).Nodup ∧
  (md.fareTypes.map (·.displayOrder)).Nodup ∧ (md.creditTypes.map (·.displayOrder)).Nodup

/-- MD-2: `(depAirportCd, arrAirportCd)` は区間の間で一意で、`depAirportCd ≠ arrAirportCd`。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-015"]
def MD2 (md : MasterData) : Prop :=
  (md.routes.map fun r => (r.depAirportCd, r.arrAirportCd)).Nodup ∧
  ∀ r ∈ md.routes, r.depAirportCd ≠ r.arrAirportCd

/-- MD-3: 参照整合性（区間の空港、便マスタの区間）。フライトの便名・搭乗クラス・運賃種別の存在は、
フライトを持つ `World` の不変条件で課す。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-015"]
def MD3 (md : MasterData) : Prop :=
  (∀ r ∈ md.routes, (∃ a ∈ md.airports, a.code = r.depAirportCd) ∧ (∃ a ∈ md.airports, a.code = r.arrAirportCd)) ∧
  ∀ f ∈ md.flightMasters, ∃ r ∈ md.routes, r.routeNo = f.routeNo

/-- MD-4: ピーク時期の期間は互いに重ならず、`peakStartDate ≤ peakEndDate`。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-004"]
def MD4 (md : MasterData) : Prop :=
  (∀ p ∈ md.peakTimes, p.peakStartDate ≤ p.peakEndDate) ∧
  md.peakTimes.Pairwise fun p q => p.peakEndDate < q.peakStartDate ∨ q.peakEndDate < p.peakStartDate

/-- MD-5: 同一区間の便マスタは、出発時刻が互いに異なる。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-005"]
def MD5 (md : MasterData) : Prop :=
  md.flightMasters.Pairwise fun f g => f.routeNo = g.routeNo → f.departureTime ≠ g.departureTime

/-- MD-6: 各便マスタで `departureTime ≤ arrivalTime`（出発日 0:00 からの分数で比べる）。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec"]
def MD6 (md : MasterData) : Prop :=
  ∀ f ∈ md.flightMasters, f.departureTime.toMinutes ≤ f.arrivalTime.toMinutes

/-- MD-7: 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、
`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1`。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-003"]
def MD7 (cfg : Config) (md : MasterData) : Prop :=
  ∀ ft ∈ md.fareTypes, ft.rsrvAvailableEndDayNum ≤ ft.rsrvAvailableStartDayNum ∧
    ft.discountRate ≤ cfg.childFareRate ∧ 1 ≤ ft.passengerMinNum

/-- 空港コードリストの区切り行のコード（`CL_AIRPORT` の `airportNopValue`）。空港のコードには使えない（MD-8）。 -/
@[gap "D-029"]
def airportNopCode : String := "NOP"

/-- MD-8: 値域（`lean/Spec/Model.lean#値域` のうちマスタのもの）。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec", gap "D-029", "D-030"]
def MD8 (md : MasterData) : Prop :=
  (∀ a ∈ md.airports, a.code.val ≠ airportNopCode) ∧
  (∀ r ∈ md.routes, ∀ b ∈ md.boardingClasses, r.basicFare + b.extraCharge ≤ Range.maxBasicFareWithCharge) ∧
  (∀ p ∈ md.peakTimes, p.multiplicationRatio ≤ Range.maxMultiplicationRatio) ∧
  (∀ ft ∈ md.fareTypes, ft.discountRate ≤ Range.maxDiscountRate)

/-- マスタの不変条件 MD-1〜MD-8。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec"]
structure Valid (cfg : Config) (md : MasterData) : Prop where
  md1 : md.MD1
  md2 : md.MD2
  md3 : md.MD3
  md4 : md.MD4
  md5 : md.MD5
  md6 : md.MD6
  md7 : md.MD7 cfg
  md8 : md.MD8

instance (md : MasterData) : Decidable md.MD1 := by unfold MD1; infer_instance
instance (md : MasterData) : Decidable md.MD2 := by unfold MD2; infer_instance
instance (md : MasterData) : Decidable md.MD3 := by unfold MD3; infer_instance
instance (md : MasterData) : Decidable md.MD4 := by unfold MD4; infer_instance
instance (md : MasterData) : Decidable md.MD5 := by unfold MD5; infer_instance
instance (md : MasterData) : Decidable md.MD6 := by unfold MD6; infer_instance
instance (cfg : Config) (md : MasterData) : Decidable (md.MD7 cfg) := by unfold MD7; infer_instance
instance (md : MasterData) : Decidable md.MD8 := by unfold MD8; infer_instance

instance (cfg : Config) (md : MasterData) : Decidable (md.Valid cfg) :=
  decidable_of_iff (md.MD1 ∧ md.MD2 ∧ md.MD3 ∧ md.MD4 ∧ md.MD5 ∧ md.MD6 ∧ md.MD7 cfg ∧ md.MD8)
    ⟨fun ⟨a, b, c, d, e, f, g, h⟩ => ⟨a, b, c, d, e, f, g, h⟩,
     fun ⟨a, b, c, d, e, f, g, h⟩ => ⟨a, b, c, d, e, f, g, h⟩⟩

/-!
## 参照関数

**[Spec=Source]**（MD-1〜MD-4 の下で）Lean: `Spec.MasterData.routeOf` ほか。どれも先頭から調べて最初に一致したものを返し、不変条件の下では一致するものが高々 1 つなので、結果は並びに依存しない（`routeOf_eq_some_iff` など）。

参照関数・設定・コードリストをまとめた抽象機械は [`Spec.MasterQuery`](MasterQuery.lean) の `queryMachine` である。PRE は、設定とマスタの不変条件と、問い合わせの引数の値域（`Query.Valid`。区間の空港コード（生の文字列）が空港コードの形式 `AirportCd.valid` に合い、便名が `WellFormed` で、便名は空白でない（[文字クラス](Prim/Text.lean#文字クラス) の `hasText`。原典の `Assert.hasText`））である。引数がこれを満たさないときの [Source] の振る舞い（`Assert.hasText` の例外、`-` を含む空港コードでのキャッシュのキーの衝突）は、参考 [D-034](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。

機械の答えのうち、搭乗クラスと運賃種別は表示順を除いた射影（`BoardingClassInfo`・`FareTypeInfo`）である。表示順を観測するのはコードリストの問い合わせだけとする（原典の参照の結果にも表示順は無い。[ADR f353](../../docs/decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）。SPEC 課題（SPEC-001〜003・SPEC-007）はこの機械について証明した。

[Source] の具体機械は [`SourceModel.MasterQuery`](../SourceModel/MasterQuery.lean) の `queryConcrete` である（[ADR c108](../../docs/decision/c108-master-data-source-model-and-spec-fixes.md)）。
- 起動時に、各 Provider の `load()` とコードリストの読み込みを行う。
- Mapper の文の結果は順序が未規定なので、許される並びのどれでも答えが同じことを ABS-026 で示す（[backlog 25f7](../../docs/backlog/25f7-fare-calculation-both-models.md) の第 2 段 b）。
- Mapper の SQL の写しは、PostgreSQL で差分実行して照合する（`conformance/sql/master-data.json`）。
- DB の値が [Spec] の型で表せない場合は、既知差異 [D-027](../../docs/spec/abstraction.md#既知差異) である。

- `routeOf(dep, arr) : Route?` — `(dep, arr)` に一致する区間。無ければ無し。
- `flightMasterOf(name) : FlightMaster?`、`fareTypeOf(cd) : FareType?`、`boardingClassOf(cd) : BoardingClass?`
- `peakTimeOn(d) : PeakTime?` — `peakStartDate ≤ d ≤ peakEndDate` を満たすピーク時期。[Source] では `peakTimes` を取得順に走査し最初に一致したもの。
- `multiplicationRatioOn(d)` = `peakTimeOn(d)` があればその `multiplicationRatio`、無ければ `100`。

出典: `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)`, `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)`（private の `getMultiplicationRatio` を含む）
-/


/-- `(dep, arr)` に一致する区間。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
def routeOf (md : MasterData) (dep arr : String) : Option Route :=
  md.routes.find? fun r => r.depAirportCd.val == dep && r.arrAirportCd.val == arr

/-- 便名（文字列）に一致する便マスタ。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
def flightMasterOf (md : MasterData) (name : String) : Option FlightMaster :=
  md.flightMasters.find? fun f => f.flightName.val == name

/-- 運賃種別。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
def fareTypeOf (md : MasterData) (cd : FareTypeCd) : Option FareType :=
  md.fareTypes.find? fun f => f.fareTypeCd == cd

/-- 搭乗クラス。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
def boardingClassOf (md : MasterData) (cd : BoardingClassCd) : Option BoardingClass :=
  md.boardingClasses.find? fun b => b.boardingClassCd == cd

/-- 日付 `d` を含むピーク時期。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数", gap "D-004"]
def peakTimeOn (md : MasterData) (d : Date) : Option PeakTime :=
  md.peakTimes.find? fun p => decide (p.peakStartDate ≤ d ∧ d ≤ p.peakEndDate)

/-- 日付 `d` の積算比率（%）。ピーク時期でなければ 100。 -/
@[spec_doc "lean/Spec/MasterData.lean#参照関数"]
def multiplicationRatioOn (md : MasterData) (d : Date) : Nat :=
  match md.peakTimeOn d with
  | some p => p.multiplicationRatio
  | none => 100

/-! ## 参照関数の性質（MD-1〜MD-4 の下で、結果は順序に依存しない） -/

/-- 述語を満たす要素が高々 1 つなら、`find?` の結果は、述語を満たす唯一の要素である。 -/
theorem find?_eq_some_iff_of_pairwise {α : Type} {p : α → Bool} {l : List α} {x : α}
    (h : l.Pairwise fun a b => ¬ (p a = true ∧ p b = true)) : l.find? p = some x ↔ x ∈ l ∧ p x = true := by
  induction l with
  | nil => simp
  | cons a l ih =>
    rw [List.pairwise_cons] at h
    by_cases hpa : p a = true
    · simp only [List.find?_cons, hpa, Option.some.injEq, List.mem_cons]
      constructor
      · intro e; subst e; exact ⟨Or.inl rfl, hpa⟩
      · intro ⟨hm, hpx⟩
        rcases hm with rfl | hm
        · rfl
        · exact absurd ⟨hpa, hpx⟩ (h.1 x hm)
    · have hpa' : p a = false := by simpa using hpa
      simp only [List.find?_cons, hpa', List.mem_cons]
      rw [ih h.2]
      constructor
      · intro ⟨hm, hpx⟩; exact ⟨Or.inr hm, hpx⟩
      · intro ⟨hm, hpx⟩
        rcases hm with rfl | hm
        · exact absurd hpx hpa
        · exact ⟨hm, hpx⟩

/-- キーが一意なら、キーで探した結果は、そのキーを持つ唯一の要素である。 -/
theorem find?_key_eq_some_iff {α κ : Type} [DecidableEq κ] {f : α → κ} {l : List α} {k : κ} {x : α}
    (h : (l.map f).Nodup) : l.find? (fun a => f a == k) = some x ↔ x ∈ l ∧ f x = k := by
  rw [find?_eq_some_iff_of_pairwise]
  · simp
  · rw [List.Nodup, List.pairwise_map] at h
    refine h.imp fun hne ⟨ha, hb⟩ => hne ?_
    simp at ha hb; rw [ha, hb]

theorem routeOf_eq_some_iff {md : MasterData} (h : md.MD2) {dep arr : String} {r : Route} :
    md.routeOf dep arr = some r ↔ r ∈ md.routes ∧ r.depAirportCd.val = dep ∧ r.arrAirportCd.val = arr := by
  unfold routeOf
  rw [find?_eq_some_iff_of_pairwise]
  · simp
  · have h₁ := h.1
    rw [List.Nodup, List.pairwise_map] at h₁
    refine h₁.imp fun hne ⟨ha, hb⟩ => hne ?_
    simp only [Bool.and_eq_true, beq_iff_eq] at ha hb
    rw [AirportCd.ext (ha.1.trans hb.1.symm), AirportCd.ext (ha.2.trans hb.2.symm)]

theorem flightMasterOf_eq_some_iff {md : MasterData} (h : md.MD1) {name : String} {f : FlightMaster} :
    md.flightMasterOf name = some f ↔ f ∈ md.flightMasters ∧ f.flightName.val = name := by
  unfold flightMasterOf
  rw [find?_eq_some_iff_of_pairwise]
  · simp
  · have h₁ := h.2.2.1
    rw [List.Nodup, List.pairwise_map] at h₁
    refine h₁.imp fun hne ⟨ha, hb⟩ => hne ?_
    simp only [beq_iff_eq] at ha hb
    exact FlightName.ext (ha.trans hb.symm)

theorem fareTypeOf_eq_some_iff {md : MasterData} (h : md.MD1) {cd : FareTypeCd} {f : FareType} :
    md.fareTypeOf cd = some f ↔ f ∈ md.fareTypes ∧ f.fareTypeCd = cd :=
  find?_key_eq_some_iff h.2.2.2.2.1

theorem boardingClassOf_eq_some_iff {md : MasterData} (h : md.MD1) {cd : BoardingClassCd}
    {b : BoardingClass} : md.boardingClassOf cd = some b ↔ b ∈ md.boardingClasses ∧ b.boardingClassCd = cd :=
  find?_key_eq_some_iff h.2.2.2.1

theorem peakTimeOn_eq_some_iff {md : MasterData} (h : md.MD4) {d : Date} {p : PeakTime} :
    md.peakTimeOn d = some p ↔ p ∈ md.peakTimes ∧ p.peakStartDate ≤ d ∧ d ≤ p.peakEndDate := by
  unfold peakTimeOn
  rw [find?_eq_some_iff_of_pairwise]
  · simp
  · refine h.2.imp fun {a b} hpq hab => ?_
    simp only [decide_eq_true_eq] at hab
    obtain ⟨⟨ha₁, ha₂⟩, ⟨hb₁, hb₂⟩⟩ := hab
    have ha₁ : a.peakStartDate.ordinal ≤ d.ordinal := ha₁
    have ha₂ : d.ordinal ≤ a.peakEndDate.ordinal := ha₂
    have hb₁ : b.peakStartDate.ordinal ≤ d.ordinal := hb₁
    have hb₂ : d.ordinal ≤ b.peakEndDate.ordinal := hb₂
    rcases hpq with hpq | hpq
    · have : a.peakEndDate.ordinal < b.peakStartDate.ordinal := hpq; omega
    · have : b.peakEndDate.ordinal < a.peakStartDate.ordinal := hpq; omega

end MasterData

end Spec

/-!
## シードデータ

原典の初期データ[^seed-fixed]。適合テストの共有入力 `conformance/fixtures/master-data.json` の元になる（[backlog 4b0e](../../docs/backlog/4b0e-in-memory-adapters-and-seed-data.md)）。

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

初期データ投入時の年 `Y` と `Y+1` の 2 年分（投入時点の年に依存する）。fixture では `Y = 2026` とする（[conformance.md](../../docs/spec/conformance.md#atrs-固有の前提)）。

| cd | 期間 | 積算比率 |
| --- | --- | --- |
| `PEAK1` | 01/01–01/05, 03/20–03/31, 08/08–08/18, 12/26–12/31 | 140 |
| `PEAK2` | 03/13–03/19, 07/18–08/07, 08/19–08/31, 12/19–12/25 | 125 |

期間は互いに重ならない（MD-4 を満たす）。

### 空港・区間・便

- 空港 51 件（主要空港 9 件は表示順 1〜9、その他 42 件は表示順 100〜141）。
- 区間 20 件。路線基本運賃はすべて 100 円単位（20,100〜52,400 円）。
- 便マスタ 126 件。
- フライト: 投入日から 120 日後まで（両端を含む）の各日について、便ごとに搭乗クラス×運賃種別の行を作る。空席数は日ごとに 3 パターン（`i mod 3`）で変わる。fixture では投入日を 2026-11-01 とする（[ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)）。

### 会員

7 件（会員番号は `0000000001` から採番）。全員のパスワードは `aaaaa11111`（前回パスワード `aaaaa00000`）の `{pbkdf2}` ハッシュ。

### カード種別

`VIS`（VISA）, `MTR`（MASTER）, `JCB`（JCB）, `DNS`（DNS）, `AMX`（American Express）

シードの全件（空港・区間・便マスタ・搭乗クラス・運賃種別・ピーク時期・機材・カード種別）は、生成器 `tools/conformance/master_fixture.py` が上流の SQL から `conformance/fixtures/master-data.json` に書き出す（投入日 2026-11-01。[ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md)）。

シードのマスタ・設定の [Spec] の値は `Spec.Seed`（生成器 `tools/conformance/seed_lean.py`。`outsideSpec` の行を除くが、上流のシードには無い）で、MD-1〜MD-8 と設定の不変条件を満たすことを定理 `Spec.EnvPre.seed_env` で示した（入口の環境の前提 `Spec.EnvPre.masterConfigOk`。前提は、設定とマスタの検証 `Spec.EnvPre.validate` が、不変条件の証明を持つ検証済みの型 `ValidEnv` を返すことである。機械の入力の設定・マスタは生の型のまま持つ（[ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)）。[ADR cd33](../../docs/decision/cd33-spec-nondet-types-and-env-pre.md)）。

翌日着の便（NTT523・NTT528）について、[Source] の空席照会は到着時刻を文字列として整形するだけで（`DateTimeUtil.toFormatTimeString`。`2415` → `24:15`）、[Spec] と一致する。
[Source] の `DateTimeFormatter("HHmm")` が `DateTimeParseException` を投げるのは、予約の往復便の検査で往路便がこの便のとき（`TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight`）で、既知差異 [D-031](../../docs/spec/abstraction.md#既知差異) である（[ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)。[ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md) の暫定措置 `outsideSpec` は外した）。

[^seed-fixed]: atrs-initdb/src/sqls/integration-test-postgres/00200〜00250_*.sql
-/
