import Machine
import Spec.Env.Config

/-!
# マスタデータ（`Spec.Env.MasterData`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。
> 「[Source] で破れた場合」の列は、前提の外での原典の振る舞いの参考である。

マスタデータ `MasterData` は、空港・区間・便・搭乗クラス・運賃種別・ピーク時期・機材・カード種別の表の組である。
起動時に読み込まれ、実行中は変化しない不変の入力として純粋関数に渡す（環境の一部。[`Spec.Env`](../Env.lean)）。
抽象状態 `World` には含めない。

- 不変条件 MD-1〜MD-8（`MasterData.Valid`）は、[Spec] の各操作の事前条件（PRE）に含まれる。
- 参照関数は、各表を先頭から調べて最初に一致したものを返す。MD-1〜MD-4 の下では一致するものは高々 1 つなので、
  結果は表の並びに依存しない（`routeOf_eq_some_iff` など）。
- 原典は `*Provider` クラスが起動時にマスタをキャッシュする（出典: atrs-domain/.../common/masterdata/*Provider.java）。

シードのマスタ（原典の初期データ）は [`Spec.Seed`](../Seed.lean) にある。

資料: [00200_insert_fixed_value.sql](https://github.com/terasolunaorg/atrs/blob/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf/atrs/atrs-initdb/src/sqls/integration-test-postgres/00200_insert_fixed_value.sql)
-/

namespace Spec.Env
open Spec.Env.Config Spec.Model Spec.Prim.Time

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

`routeNo: Nat`, `depAirportCd`, `arrAirportCd`, `basicFare: Nat`（路線基本運賃）。DB の `FLIGHT_TIME`（所要時間）は、原典のどの処理も読まないので [Spec] には持たない

### FlightMaster

`flightName`, `routeNo`, `departureTime: HourMinute`, `arrivalTime: ArrivalTime`, `craftType`

到着時刻は **出発日 0:00 からの時分** で表し、24 時以降は翌日着である（[`Spec.Prim.Time`](../Prim/Time.lean#arrivaltime)）。シードの NTT523（HND→OKA）・NTT528（OKA→HND）の到着時刻は `2415`（翌日 0:15）である。`arrivalTime < departureTime` の便は [Spec] の不変条件 MD-6 で禁止する。

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
@[spec_doc "lean/Spec/Env/MasterData.lean#airport"]
structure Airport where
  code : AirportCd
  name : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 区間。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#route"]
structure Route where
  routeNo : Nat
  depAirportCd : AirportCd
  arrAirportCd : AirportCd
  /-- 路線基本運賃。所要時間（DB の `FLIGHT_TIME`）は、原典のどの処理も読まないので持たない。 -/
  basicFare : Nat
  deriving DecidableEq, Repr

/-- 便マスタ。到着時刻は出発日 0:00 からの時分で表す（翌日着は 24 時以降）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#flightmaster"]
structure FlightMaster where
  flightName : FlightName
  routeNo : Nat
  departureTime : HourMinute
  arrivalTime : ArrivalTime
  craftType : String
  deriving DecidableEq

/-- 搭乗クラス。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#boardingclass"]
structure BoardingClass where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#faretype"]
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
@[spec_doc "lean/Spec/Env/MasterData.lean#peaktime"]
structure PeakTime where
  peakTimeCd : String
  peakStartDate : Date
  peakEndDate : Date
  /-- 積算比率（%）。 -/
  multiplicationRatio : Nat
  deriving DecidableEq

/-- 機材（参考。業務ロジックでは使わない）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#plane--credittype"]
structure Plane where
  craftType : String
  nSeatNum : Nat
  sSeatNum : Nat
  deriving DecidableEq, Repr

/-- カード種別。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#plane--credittype"]
structure CreditType where
  creditTypeCd : CreditTypeCd
  creditFirm : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 搭乗クラスの参照の結果（表示順を除く。表示順はコードリストの問い合わせだけが観測する）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
structure BoardingClassInfo where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  deriving DecidableEq, Repr

/-- 運賃種別の参照の結果（表示順を除く）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
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
@[spec_doc "lean/Spec/Env/MasterData.lean#masterdata"]
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

`MasterData.Valid`（成分 `md1`〜`md8` が `MD1`〜`MD8`。判定可能）。

[Spec] の全定義は `MasterData` が次を満たすことを前提とする。[Source] はこれらを検査せず、満たさない場合の振る舞いは原典どおり（多くは「最初に見つかったもの」または上書き）である。

| ID | 不変条件 | [Source] で破れた場合 |
| --- | --- | --- |
| MD-1 | 各キーは一意。各マスタの `displayOrder` も一意（原典の DB 制約 `DISPLAY_ORDER INT NOT NULL UNIQUE` と同じ） | `HashMap` への後勝ち上書き。`displayOrder` の重複は DB が拒む |
| MD-2 | `(depAirportCd, arrAirportCd)` は区間間で一意。`depAirportCd ≠ arrAirportCd` | 後勝ち上書き |
| MD-3 | 参照整合性（区間の空港・便マスタの区間）。フライトの便名・搭乗クラス・運賃種別がマスタにあること（`World.RefMaster`）と、会員のカード種別がマスタにあること（`World.MemberRefMaster`）は、マスタと状態の組の述語で、`World` の不変条件には含めない（予約は PRE に課し、空席照会は課さない。[`Spec.World`](../World.lean#world抽象状態)）。運賃計算の入力が指すマスタの存在は各操作の PRE で課す | `null` による前提違反（運賃計算の入力の場合は参考 [D-035](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)） |
| MD-4 | ピーク時期の期間は互いに重ならない（`peakStartDate ≤ peakEndDate`） | 取得順（未規定）で最初に一致したもの（参考 [D-004](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-5 | 同一区間の便マスタは出発時刻が互いに異なる | 空席照会で同一出発時刻の便が 1 件に統合される（参考 [D-005](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)。差異ではない） |
| MD-6 | 各便マスタで `departureTime ≤ arrivalTime`（出発日 0:00 からの分数で比べる） | — |
| MD-7 | 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1` | — |
| MD-8 | [`Spec.Model`](../Model.lean#値域) の値域（空港コードは区切り行のコード `NOP` でない。英大文字 3 文字の形式は型 `AirportCd` が持つ） | int32 の折り返し（参考 [D-030](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。空港コードに `-` があると区間のキーが衝突しうるが、[Spec] の型はそのマスタを表せない（[D-036](../../../docs/spec/abstraction.md#既知差異)。D-027 に覆われる）。`NOP` の空港があると、コードリストの区切り行がその空港で置き換わる（参考 [D-029](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)） |

マスタは不変の入力であり（[`Spec.World`](../World.lean#world抽象状態)）、MD-1〜MD-8 は [Spec] の各操作の事前条件 PRE に含まれる。リファインメントの証明義務は PRE の内についてだけ課される。破れた場合の [Source] の振る舞い（MD-1〜MD-3 は D-015、MD-4・MD-5 は D-004・D-005、MD-8 は D-029・D-030・D-036）は差異ではなく、参考として [abstraction.md](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) に記録する。
-/

/-! ### 不変条件 MD-1〜MD-8 -/

/-- MD-1: 各キーは一意。各マスタの `displayOrder` も一意。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-015"]
def MD1 (md : MasterData) : Prop :=
  (md.airports.map (·.code)).Nodup ∧ (md.routes.map (·.routeNo)).Nodup ∧
  (md.flightMasters.map (·.flightName)).Nodup ∧ (md.boardingClasses.map (·.boardingClassCd)).Nodup ∧
  (md.fareTypes.map (·.fareTypeCd)).Nodup ∧
  (md.peakTimes.map fun p => (p.peakTimeCd, p.peakStartDate, p.peakEndDate)).Nodup ∧
  (md.planes.map (·.craftType)).Nodup ∧ (md.creditTypes.map (·.creditTypeCd)).Nodup ∧
  (md.airports.map (·.displayOrder)).Nodup ∧ (md.boardingClasses.map (·.displayOrder)).Nodup ∧
  (md.fareTypes.map (·.displayOrder)).Nodup ∧ (md.creditTypes.map (·.displayOrder)).Nodup

/-- MD-2: `(depAirportCd, arrAirportCd)` は区間の間で一意で、`depAirportCd ≠ arrAirportCd`。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-015"]
def MD2 (md : MasterData) : Prop :=
  (md.routes.map fun r => (r.depAirportCd, r.arrAirportCd)).Nodup ∧
  ∀ r ∈ md.routes, r.depAirportCd ≠ r.arrAirportCd

/-- MD-3: 参照整合性（区間の空港、便マスタの区間）。フライトの便名・搭乗クラス・運賃種別の存在は、
マスタと `World` の組の述語 `World.RefMaster` で表す。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-015"]
def MD3 (md : MasterData) : Prop :=
  (∀ r ∈ md.routes, (∃ a ∈ md.airports, a.code = r.depAirportCd) ∧ (∃ a ∈ md.airports, a.code = r.arrAirportCd)) ∧
  ∀ f ∈ md.flightMasters, ∃ r ∈ md.routes, r.routeNo = f.routeNo

/-- MD-4: ピーク時期の期間は互いに重ならず、`peakStartDate ≤ peakEndDate`。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-004"]
def MD4 (md : MasterData) : Prop :=
  (∀ p ∈ md.peakTimes, p.peakStartDate ≤ p.peakEndDate) ∧
  md.peakTimes.Pairwise fun p q => p.peakEndDate < q.peakStartDate ∨ q.peakEndDate < p.peakStartDate

/-- MD-5: 同一区間の便マスタは、出発時刻が互いに異なる。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-005"]
def MD5 (md : MasterData) : Prop :=
  md.flightMasters.Pairwise fun f g => f.routeNo = g.routeNo → f.departureTime ≠ g.departureTime

/-- MD-6: 各便マスタで `departureTime ≤ arrivalTime`（出発日 0:00 からの分数で比べる）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec"]
def MD6 (md : MasterData) : Prop :=
  ∀ f ∈ md.flightMasters, f.departureTime.toMinutes ≤ f.arrivalTime.toMinutes

/-- MD-7: 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、
`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1`。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-003"]
def MD7 (cfg : Config) (md : MasterData) : Prop :=
  ∀ ft ∈ md.fareTypes, ft.rsrvAvailableEndDayNum ≤ ft.rsrvAvailableStartDayNum ∧
    ft.discountRate ≤ cfg.childFareRate ∧ 1 ≤ ft.passengerMinNum

/-- 空港コードリストの区切り行のコード（`CL_AIRPORT` の `airportNopValue`）。空港のコードには使えない（MD-8）。 -/
@[gap "D-029"]
def airportNopCode : String := "NOP"

/-- MD-8: 値域（[`Spec.Model`](../Model.lean#値域) の値域のうちマスタのもの）と、空港コードが区切り行のコードでないこと。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec", gap "D-029", "D-030"]
def MD8 (md : MasterData) : Prop :=
  (∀ a ∈ md.airports, a.code.val ≠ airportNopCode) ∧
  (∀ r ∈ md.routes, ∀ b ∈ md.boardingClasses, r.basicFare + b.extraCharge ≤ Range.maxBasicFareWithCharge) ∧
  (∀ p ∈ md.peakTimes, p.multiplicationRatio ≤ Range.maxMultiplicationRatio) ∧
  (∀ ft ∈ md.fareTypes, ft.discountRate ≤ Range.maxDiscountRate)

/-- マスタの不変条件 MD-1〜MD-8。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec"]
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

**[Spec=Source]**（MD-1〜MD-4 の下で）どの参照関数も表を先頭から調べて最初に一致したものを返す。不変条件の下では一致するものが
高々 1 つなので、結果は表の並びに依存しない（`routeOf_eq_some_iff` など）。

- `routeOf(dep, arr) : Route?` — `(dep, arr)` に一致する区間。無ければ無し。
- `flightMasterOf(name) : FlightMaster?`、`fareTypeOf(cd) : FareType?`、`boardingClassOf(cd) : BoardingClass?`
- `peakTimeOn(d) : PeakTime?` — `peakStartDate ≤ d ≤ peakEndDate` を満たすピーク時期。[Source] では `peakTimes` を取得順に走査し最初に一致したもの。
- `multiplicationRatioOn(d)` = `peakTimeOn(d)` があればその `multiplicationRatio`、無ければ `100`。

参照関数・設定・コードリストへの問い合わせをまとめた抽象機械と、その事前条件（問い合わせの引数の値域）は
[`Spec.MasterQuery`](../MasterQuery.lean) にある。

出典: `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)`, `java:jp.co.ntt.atrs.domain.common.masterdata.RouteProvider#getRouteByAirportCd(String,String)`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)`（private の `getMultiplicationRatio` を含む）
-/


/-- `(dep, arr)` に一致する区間。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
def routeOf (md : MasterData) (dep arr : String) : Option Route :=
  md.routes.find? fun r => r.depAirportCd.val == dep && r.arrAirportCd.val == arr

/-- 便名（文字列）に一致する便マスタ。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
def flightMasterOf (md : MasterData) (name : String) : Option FlightMaster :=
  md.flightMasters.find? fun f => f.flightName.val == name

/-- 運賃種別。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
def fareTypeOf (md : MasterData) (cd : FareTypeCd) : Option FareType :=
  md.fareTypes.find? fun f => f.fareTypeCd == cd

/-- 搭乗クラス。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
def boardingClassOf (md : MasterData) (cd : BoardingClassCd) : Option BoardingClass :=
  md.boardingClasses.find? fun b => b.boardingClassCd == cd

/-- 日付 `d` を含むピーク時期。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数", gap "D-004"]
def peakTimeOn (md : MasterData) (d : Date) : Option PeakTime :=
  md.peakTimes.find? fun p => decide (p.peakStartDate ≤ d ∧ d ≤ p.peakEndDate)

/-- 日付 `d` の積算比率（%）。ピーク時期でなければ 100。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数"]
def multiplicationRatioOn (md : MasterData) (d : Date) : Nat :=
  match md.peakTimeOn d with
  | some p => p.multiplicationRatio
  | none => 100

/-! ## 性質（MD-1〜MD-4 の下で、参照関数の結果は表の並びに依存しない） -/

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

end Spec.Env

/-!
## 根拠と対応

- 根拠: [ADR f0e4](../../../docs/decision/f0e4-functional-core-with-ports.md)（マスタは不変の入力として純粋関数に渡す）、
  [ADR c108](../../../docs/decision/c108-master-data-source-model-and-spec-fixes.md)（マスタの移植元モデルと、所要時間を持たないこと）、
  [ADR ce36](../../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)（翌日着の到着時刻）、
  [ADR f353](../../../docs/decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)（区切り行のコード `NOP`）
- 既知差異: DB の値が [Spec] の型で表せない場合は D-027、`-` を含む空港コードは D-036（いずれも
  [abstraction.md](../../../docs/spec/abstraction.md#既知差異)）。不変条件が破れた場合の [Source] の振る舞い
  （D-003・D-004・D-005・D-015・D-029・D-030・D-035）は差異ではなく参考
  （[abstraction.md](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）
- 移植元モデル: [`SourceModel.Domain.Common.Masterdata`](../../SourceModel/Domain/Common/Masterdata/)（各 Provider）と
  [`SourceModel.Domain.Repository`](../../SourceModel/Domain/Repository/)（Mapper の SQL の写し）
- 抽象化の証明: [`Abstraction.MasterData`](../../Abstraction/MasterData.lean)
- 適合テストベクタ: `conformance/shared/master-data/`、SQL の差分実行の結果 `conformance/sql/master-data.json`
-/
