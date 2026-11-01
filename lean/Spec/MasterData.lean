import Machine
import Spec.Config

/-!
# Spec.MasterData

マスタデータ（`docs/spec/master-data.md`）。起動時に読み込まれ、実行中は変化しない不変の入力であり、
`World` には含めない。不変条件 MD-1〜MD-8（`MasterData.Valid`）は、[Spec] の各操作の PRE に含める。

- 参照関数は、各マスタを先頭から調べて最初に一致したものを返す。MD-1〜MD-4 の下では一致するものは
  高々 1 つなので、結果は順序に依存しない（`routeOf_eq_some_iff` など）。
- SPEC 課題（SPEC-001〜003）: 参照関数をまとめた状態を持たない抽象機械 `queryMachine` について示す。
-/

namespace Spec
open Spec.Config Spec.Model Spec.Prim.Time

open Spec.Prim

namespace MasterData

/-! ## マスタの型 -/

/-- 空港。 -/
@[spec_doc "docs/spec/master-data.md#airport"]
structure Airport where
  code : AirportCd
  name : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 区間。 -/
@[spec_doc "docs/spec/master-data.md#route"]
structure Route where
  routeNo : Nat
  depAirportCd : AirportCd
  arrAirportCd : AirportCd
  /-- 路線基本運賃。所要時間（DB の `FLIGHT_TIME`）は、原典のどの処理も読まないので持たない（ADR c108）。 -/
  basicFare : Nat
  deriving DecidableEq, Repr

/-- 便マスタ。到着時刻は出発日 0:00 からの時分で表す（翌日着は 24 時以降。ADR ce36）。 -/
@[spec_doc "docs/spec/master-data.md#flightmaster"]
structure FlightMaster where
  flightName : FlightName
  routeNo : Nat
  departureTime : HourMinute
  arrivalTime : ArrivalTime
  craftType : String
  deriving DecidableEq

/-- 搭乗クラス。 -/
@[spec_doc "docs/spec/master-data.md#boardingclass"]
structure BoardingClass where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "docs/spec/master-data.md#faretype"]
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
@[spec_doc "docs/spec/master-data.md#peaktime"]
structure PeakTime where
  peakTimeCd : String
  peakStartDate : Date
  peakEndDate : Date
  /-- 積算比率（%）。 -/
  multiplicationRatio : Nat
  deriving DecidableEq

/-- 機材（参考。業務ロジックでは使わない）。 -/
@[spec_doc "docs/spec/master-data.md#plane--credittype"]
structure Plane where
  craftType : String
  nSeatNum : Nat
  sSeatNum : Nat
  deriving DecidableEq, Repr

/-- カード種別。 -/
@[spec_doc "docs/spec/master-data.md#plane--credittype"]
structure CreditType where
  creditTypeCd : CreditTypeCd
  creditFirm : String
  displayOrder : Nat
  deriving DecidableEq, Repr

/-- 搭乗クラスの参照の結果（表示順を除く。表示順はコードリストの問い合わせだけが観測する）。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
structure BoardingClassInfo where
  boardingClassCd : BoardingClassCd
  boardingClassName : String
  extraCharge : Nat
  deriving DecidableEq, Repr

/-- 運賃種別の参照の結果（表示順を除く）。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
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
@[spec_doc "docs/spec/master-data.md#masterdata"]
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

/-! ## 不変条件 MD-1〜MD-8 -/

/-- MD-1: 各キーは一意。各マスタの `displayOrder` も一意。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-015"]
def MD1 (md : MasterData) : Prop :=
  (md.airports.map (·.code)).Nodup ∧ (md.routes.map (·.routeNo)).Nodup ∧
  (md.flightMasters.map (·.flightName)).Nodup ∧ (md.boardingClasses.map (·.boardingClassCd)).Nodup ∧
  (md.fareTypes.map (·.fareTypeCd)).Nodup ∧
  (md.peakTimes.map fun p => (p.peakTimeCd, p.peakStartDate, p.peakEndDate)).Nodup ∧
  (md.planes.map (·.craftType)).Nodup ∧ (md.creditTypes.map (·.creditTypeCd)).Nodup ∧
  (md.airports.map (·.displayOrder)).Nodup ∧ (md.boardingClasses.map (·.displayOrder)).Nodup ∧
  (md.fareTypes.map (·.displayOrder)).Nodup ∧ (md.creditTypes.map (·.displayOrder)).Nodup

/-- MD-2: `(depAirportCd, arrAirportCd)` は区間の間で一意で、`depAirportCd ≠ arrAirportCd`。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-015"]
def MD2 (md : MasterData) : Prop :=
  (md.routes.map fun r => (r.depAirportCd, r.arrAirportCd)).Nodup ∧
  ∀ r ∈ md.routes, r.depAirportCd ≠ r.arrAirportCd

/-- MD-3: 参照整合性（区間の空港、便マスタの区間）。フライトの便名・搭乗クラス・運賃種別の存在は、
フライトを持つ `World` の不変条件で課す。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-015"]
def MD3 (md : MasterData) : Prop :=
  (∀ r ∈ md.routes, (∃ a ∈ md.airports, a.code = r.depAirportCd) ∧ (∃ a ∈ md.airports, a.code = r.arrAirportCd)) ∧
  ∀ f ∈ md.flightMasters, ∃ r ∈ md.routes, r.routeNo = f.routeNo

/-- MD-4: ピーク時期の期間は互いに重ならず、`peakStartDate ≤ peakEndDate`。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-004"]
def MD4 (md : MasterData) : Prop :=
  (∀ p ∈ md.peakTimes, p.peakStartDate ≤ p.peakEndDate) ∧
  md.peakTimes.Pairwise fun p q => p.peakEndDate < q.peakStartDate ∨ q.peakEndDate < p.peakStartDate

/-- MD-5: 同一区間の便マスタは、出発時刻が互いに異なる。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-005"]
def MD5 (md : MasterData) : Prop :=
  md.flightMasters.Pairwise fun f g => f.routeNo = g.routeNo → f.departureTime ≠ g.departureTime

/-- MD-6: 各便マスタで `departureTime ≤ arrivalTime`（出発日 0:00 からの分数で比べる）。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec"]
def MD6 (md : MasterData) : Prop :=
  ∀ f ∈ md.flightMasters, f.departureTime.toMinutes ≤ f.arrivalTime.toMinutes

/-- MD-7: 各運賃種別で `rsrvAvailableEndDayNum ≤ rsrvAvailableStartDayNum`、
`discountRate ≤ childFareRate`、`passengerMinNum ≥ 1`。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-003"]
def MD7 (cfg : Config) (md : MasterData) : Prop :=
  ∀ ft ∈ md.fareTypes, ft.rsrvAvailableEndDayNum ≤ ft.rsrvAvailableStartDayNum ∧
    ft.discountRate ≤ cfg.childFareRate ∧ 1 ≤ ft.passengerMinNum

/-- 空港コードリストの区切り行のコード（`CL_AIRPORT` の `airportNopValue`）。空港のコードには使えない（MD-8）。 -/
@[gap "D-029"]
def airportNopCode : String := "NOP"

/-- MD-8: 値域（`docs/spec/domain-model.md#値域` のうちマスタのもの）。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec", gap "D-029"]
def MD8 (md : MasterData) : Prop :=
  (∀ a ∈ md.airports, a.code.WellFormed ∧ a.code.val ≠ airportNopCode) ∧
  (∀ r ∈ md.routes, ∀ b ∈ md.boardingClasses, r.basicFare + b.extraCharge ≤ Range.maxBasicFareWithCharge) ∧
  (∀ p ∈ md.peakTimes, p.multiplicationRatio ≤ Range.maxMultiplicationRatio) ∧
  (∀ ft ∈ md.fareTypes, ft.discountRate ≤ Range.maxDiscountRate)

/-- マスタの不変条件 MD-1〜MD-8。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec"]
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

/-! ## 参照関数 -/

/-- `(dep, arr)` に一致する区間。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
def routeOf (md : MasterData) (dep arr : AirportCd) : Option Route :=
  md.routes.find? fun r => r.depAirportCd == dep && r.arrAirportCd == arr

/-- 便名に一致する便マスタ。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
def flightMasterOf (md : MasterData) (name : FlightName) : Option FlightMaster :=
  md.flightMasters.find? fun f => f.flightName == name

/-- 運賃種別。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
def fareTypeOf (md : MasterData) (cd : FareTypeCd) : Option FareType :=
  md.fareTypes.find? fun f => f.fareTypeCd == cd

/-- 搭乗クラス。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
def boardingClassOf (md : MasterData) (cd : BoardingClassCd) : Option BoardingClass :=
  md.boardingClasses.find? fun b => b.boardingClassCd == cd

/-- 日付 `d` を含むピーク時期。 -/
@[spec_doc "docs/spec/master-data.md#参照関数", gap "D-004"]
def peakTimeOn (md : MasterData) (d : Date) : Option PeakTime :=
  md.peakTimes.find? fun p => decide (p.peakStartDate ≤ d ∧ d ≤ p.peakEndDate)

/-- 日付 `d` の積算比率（%）。ピーク時期でなければ 100。 -/
@[spec_doc "docs/spec/master-data.md#参照関数"]
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

theorem routeOf_eq_some_iff {md : MasterData} (h : md.MD2) {dep arr : AirportCd} {r : Route} :
    md.routeOf dep arr = some r ↔ r ∈ md.routes ∧ r.depAirportCd = dep ∧ r.arrAirportCd = arr := by
  unfold routeOf
  rw [find?_eq_some_iff_of_pairwise]
  · simp
  · have h₁ := h.1
    rw [List.Nodup, List.pairwise_map] at h₁
    refine h₁.imp fun hne ⟨ha, hb⟩ => hne ?_
    simp only [Bool.and_eq_true, beq_iff_eq] at ha hb
    rw [ha.1, ha.2, hb.1, hb.2]

theorem flightMasterOf_eq_some_iff {md : MasterData} (h : md.MD1) {name : FlightName} {f : FlightMaster} :
    md.flightMasterOf name = some f ↔ f ∈ md.flightMasters ∧ f.flightName = name :=
  find?_key_eq_some_iff h.2.2.1

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
