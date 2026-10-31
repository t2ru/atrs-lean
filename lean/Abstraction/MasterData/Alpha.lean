import Abstraction.MasterData.AlphaLeaf
import SourceModel.MasterQuery
import Abstraction.MasterData.CodeList

/-!
# Abstraction.MasterData.Alpha

ABS-026 の標準の抽象化 α（`docs/spec/abstraction.md#抽象化関数-α`）と、既知差異 D-027 の成分 `dev_D027`。

- 入力 `aiMQ`: DB のマスタの各行・設定・問い合わせを、[Spec] の値に写す。行と問い合わせは葉（核の定理を持つ）で、
  マスタ全体・設定・入力は、葉を `Option.bind`・`Option.map`・`List.mapM`・構築子・射影だけで組んだ合成である（G7）。
  行の葉は `RouteRow.flightTime` だけを捨てる（核 `routeRowKer`）。
- 出力 `answerOf?`（葉）: 答えのうち [Spec] が観測する成分（`answerObs`）だけを写す。
  区間の空港名・空港の表示順、便マスタの区間の運賃・空港・機材の座席数は捨てる。核は `answerKer`。
- `dev_D027`: 入力全体が [Spec] の型で表せる（`aiMQ` が定義される）。
-/

namespace Abstraction.MasterData

open Machine LangSemantics.Java LangSemantics.Sql.Postgresql Spec Spec.Prim Abstraction.Prim
  SourceModel.Repository.Schema SourceModel.MasterQuery SourceModel.Config

/-- 核から、定義域の上の単射性を取り出す。 -/
theorem inj_of_kernel {α β : Type} {f : α → Option β} (hk : KernelIs f (undefOrEq f)) {x y : α} {b : β}
    (hx : f x = some b) (hy : f y = some b) : x = y := by
  rcases (hk x y).mp (hx.trans hy.symm) with ⟨h, _⟩ | h
  · rw [hx] at h; cases h
  · exact h

/-! ## DB の行（葉） -/

/-- `AIRPORT` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def airportOfRow (r : AirportRow) : Option Airport :=
  (natOfInt4 r.displayOrder).map fun d => ⟨⟨r.airportCd.val⟩, r.airportName.val, d⟩

/-- `ROUTE` の行（`FLIGHT_TIME` は捨てる。ADR c108）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def routeOfRow (r : RouteRow) : Option Route :=
  (natOfInt4 r.routeNo).bind fun no => (natOfInt4 r.basicFare).map fun bf =>
    ⟨no, ⟨r.depAirportCd.val⟩, ⟨r.arrAirportCd.val⟩, bf⟩

/-- `FLIGHT_MASTER` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def flightMasterOfRow (f : FlightMasterRow) : Option FlightMaster :=
  (natOfInt4 f.routeNo).bind fun no => (hmOfStr f.departureTime.val).bind fun dt =>
    (hmOfStr f.arrivalTime.val).map fun ar => ⟨⟨f.flightName.val⟩, no, dt, ar, f.craftType.val⟩

/-- `BOARDING_CLASS` の行（`BOARDING_CLASS_NAME` が `NULL` なら定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def boardingClassOfRow (b : BoardingClassRow) : Option BoardingClass :=
  (bcCdOf b.boardingClassCd.val).bind fun cd => b.boardingClassName.bind fun nm =>
    (natOfInt4 b.extraCharge).bind fun ex => (natOfInt4 b.displayOrder).map fun d => ⟨cd, nm.val, ex, d⟩

/-- `FARE_TYPE` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def fareTypeOfRow (f : FareTypeRow) : Option FareType :=
  (ftCdOf f.fareTypeCd.val).bind fun cd => (natOfInt4 f.discountRate).bind fun dr =>
    (natOfInt4 f.rsrvAvailableStartDayNum).bind fun s => (natOfInt4 f.rsrvAvailableEndDayNum).bind fun e =>
      (natOfInt4 f.passengerMinNum).bind fun pm => (natOfInt4 f.displayOrder).map fun d =>
        ⟨cd, f.fareTypeName.val, dr, s, e, pm, d⟩

/-- `PEAK_TIME` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def peakTimeOfRow (p : PeakTimeRow) : Option PeakTime :=
  (dateOfPg p.peakStartDate).bind fun s => (dateOfPg p.peakEndDate).bind fun e =>
    (natOfInt4 p.multiplicationRatio).map fun r => ⟨p.peakTimeCd.val, s, e, r⟩

/-- `PLANE` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def planeOfRow (p : PlaneRow) : Option Plane :=
  (natOfInt4 p.nSeatNum).bind fun n => (natOfInt4 p.sSeatNum).map fun s => ⟨p.craftType.val, n, s⟩

/-- `CREDIT_TYPE` の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def creditTypeOfRow (c : CreditTypeRow) : Option CreditType :=
  (natOfInt4 c.displayOrder).map fun d => ⟨⟨c.creditTypeCd.val⟩, c.creditFirm.val, d⟩

/-! ### 行の葉の核 -/

theorem natOfInt4_inj {x y : Int4} {n : Nat} (hx : natOfInt4 x = some n) (hy : natOfInt4 y = some n) : x = y :=
  inj_of_kernel natOfInt4_kernel hx hy

@[obligation "ABS-048"]
theorem airportOfRow_kernel : KernelIs airportOfRow (undefOrEq airportOfRow) := by
  apply kernelIs_undefOrEq
  intro r r' a h h'
  simp only [airportOfRow, Option.map_eq_some_iff] at h h'
  obtain ⟨d, hd, rfl⟩ := h
  obtain ⟨d', hd', h⟩ := h'
  simp only [Airport.mk.injEq, AirportCd.mk.injEq] at h
  obtain ⟨h1, h2, rfl⟩ := h
  cases r; cases r'
  simp only [AirportRow.mk.injEq] at *
  exact ⟨Subtype.ext h1.symm, Subtype.ext h2.symm, natOfInt4_inj hd' hd |>.symm⟩

/-- `ROUTE` の行の核: どちらも定義されないか、`FLIGHT_TIME` 以外が等しい。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def routeRowKer (r r' : RouteRow) : Prop :=
  (routeOfRow r = none ∧ routeOfRow r' = none) ∨ { r with flightTime := r'.flightTime } = r'

@[obligation "ABS-048"]
theorem routeOfRow_kernel : KernelIs routeOfRow routeRowKer := by
  intro r r'
  constructor
  · intro e
    cases h : routeOfRow r with
    | none => exact Or.inl ⟨h, by rw [← e, h]⟩
    | some a =>
      refine Or.inr ?_
      have h' : routeOfRow r' = some a := by rw [← e, h]
      simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
      obtain ⟨no, hno, bf, hbf, rfl⟩ := h
      obtain ⟨no', hno', bf', hbf', h⟩ := h'
      simp only [Spec.Route.mk.injEq, AirportCd.mk.injEq] at h
      obtain ⟨rfl, h2, h3, rfl⟩ := h
      cases r; cases r'
      simp only [RouteRow.mk.injEq] at *
      exact ⟨natOfInt4_inj hno hno', Subtype.ext h2.symm, Subtype.ext h3.symm, trivial, natOfInt4_inj hbf hbf'⟩
  · rintro (⟨h, h'⟩ | h)
    · rw [h, h']
    · rw [← h]; rfl

@[obligation "ABS-048"]
theorem flightMasterOfRow_kernel : KernelIs flightMasterOfRow (undefOrEq flightMasterOfRow) := by
  apply kernelIs_undefOrEq
  intro f f' a h h'
  simp only [flightMasterOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨no, hno, dt, hdt, ar, har, rfl⟩ := h
  obtain ⟨no', hno', dt', hdt', ar', har', h⟩ := h'
  simp only [FlightMaster.mk.injEq, FlightName.mk.injEq] at h
  obtain ⟨h1, rfl, rfl, rfl, h5⟩ := h
  cases f; cases f'
  simp only [FlightMasterRow.mk.injEq] at *
  exact ⟨Subtype.ext h1.symm, natOfInt4_inj hno hno', Subtype.ext (inj_of_kernel hmOfStr_kernel hdt hdt'),
    Subtype.ext (inj_of_kernel hmOfStr_kernel har har'), Subtype.ext h5.symm⟩

@[obligation "ABS-048"]
theorem boardingClassOfRow_kernel : KernelIs boardingClassOfRow (undefOrEq boardingClassOfRow) := by
  apply kernelIs_undefOrEq
  intro b b' a h h'
  simp only [boardingClassOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨cd, hcd, nm, hnm, ex, hex, d, hd, rfl⟩ := h
  obtain ⟨cd', hcd', nm', hnm', ex', hex', d', hd', h⟩ := h'
  simp only [BoardingClass.mk.injEq] at h
  obtain ⟨rfl, h2, rfl, rfl⟩ := h
  cases b; cases b'
  simp only [BoardingClassRow.mk.injEq] at *
  subst hnm hnm'
  exact ⟨Subtype.ext (inj_of_kernel bcCdOf_kernel hcd hcd'), by rw [Subtype.ext h2.symm],
    natOfInt4_inj hex hex', natOfInt4_inj hd hd'⟩

@[obligation "ABS-048"]
theorem fareTypeOfRow_kernel : KernelIs fareTypeOfRow (undefOrEq fareTypeOfRow) := by
  apply kernelIs_undefOrEq
  intro f f' a h h'
  simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨cd, hcd, dr, hdr, st, hst, en, hen, pm, hpm, d, hd, rfl⟩ := h
  obtain ⟨cd', hcd', dr', hdr', st', hst', en', hen', pm', hpm', d', hd', h⟩ := h'
  simp only [FareType.mk.injEq] at h
  obtain ⟨rfl, h2, rfl, rfl, rfl, rfl, rfl⟩ := h
  cases f; cases f'
  simp only [FareTypeRow.mk.injEq] at *
  exact ⟨Subtype.ext (inj_of_kernel ftCdOf_kernel hcd hcd'), Subtype.ext h2.symm, natOfInt4_inj hdr hdr',
    natOfInt4_inj hst hst', natOfInt4_inj hen hen', natOfInt4_inj hpm hpm', natOfInt4_inj hd hd'⟩

@[obligation "ABS-048"]
theorem peakTimeOfRow_kernel : KernelIs peakTimeOfRow (undefOrEq peakTimeOfRow) := by
  apply kernelIs_undefOrEq
  intro p p' a h h'
  simp only [peakTimeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨st, hst, en, hen, r, hr, rfl⟩ := h
  obtain ⟨st', hst', en', hen', r', hr', h⟩ := h'
  simp only [PeakTime.mk.injEq] at h
  obtain ⟨h1, rfl, rfl, rfl⟩ := h
  cases p; cases p'
  simp only [PeakTimeRow.mk.injEq] at *
  exact ⟨Subtype.ext h1.symm, inj_of_kernel dateOfPg_kernel hst hst', inj_of_kernel dateOfPg_kernel hen hen',
    natOfInt4_inj hr hr'⟩

@[obligation "ABS-048"]
theorem planeOfRow_kernel : KernelIs planeOfRow (undefOrEq planeOfRow) := by
  apply kernelIs_undefOrEq
  intro p p' a h h'
  simp only [planeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨n, hn, s, hs, rfl⟩ := h
  obtain ⟨n', hn', s', hs', h⟩ := h'
  simp only [Plane.mk.injEq] at h
  obtain ⟨h1, rfl, rfl⟩ := h
  cases p; cases p'
  simp only [PlaneRow.mk.injEq] at *
  exact ⟨Subtype.ext h1.symm, natOfInt4_inj hn hn', natOfInt4_inj hs hs'⟩

@[obligation "ABS-048"]
theorem creditTypeOfRow_kernel : KernelIs creditTypeOfRow (undefOrEq creditTypeOfRow) := by
  apply kernelIs_undefOrEq
  intro c c' a h h'
  simp only [creditTypeOfRow, Option.map_eq_some_iff] at h h'
  obtain ⟨d, hd, rfl⟩ := h
  obtain ⟨d', hd', h⟩ := h'
  simp only [CreditType.mk.injEq, CreditTypeCd.mk.injEq] at h
  obtain ⟨h1, h2, rfl⟩ := h
  cases c; cases c'
  simp only [CreditTypeRow.mk.injEq] at *
  exact ⟨Subtype.ext h1.symm, Subtype.ext h2.symm, natOfInt4_inj hd' hd |>.symm⟩

/-- DB のマスタ（表ごとに、行の並びのまま写す）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def masterDataOf (db : MasterDb) : Option MasterData :=
  (db.airport.mapM airportOfRow).bind fun a => (db.route.mapM routeOfRow).bind fun r =>
    (db.flightMaster.mapM flightMasterOfRow).bind fun f => (db.boardingClass.mapM boardingClassOfRow).bind fun b =>
      (db.fareType.mapM fareTypeOfRow).bind fun ft => (db.peakTime.mapM peakTimeOfRow).bind fun p =>
        (db.plane.mapM planeOfRow).bind fun pl => (db.creditType.mapM creditTypeOfRow).map fun c =>
          ⟨a, r, f, b, ft, p, pl, c⟩

/-! ## 設定（合成） -/

/-- 注入された設定。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def configOf (c : AtrsConfig) : Option Config :=
  (natOfJ32 c.limitDay).bind fun ld => (natOfJ32 c.reserveIntervalTime).bind fun ri =>
    (natOfJ32 c.representativeMinAge).bind fun rm => (natOfJ32 c.adultPassengerMinAge).bind fun am =>
      (natOfJ32 c.childFareRate).bind fun cr => (dateOfSlash c.dateOfBirthMinDate).map fun dob =>
        ⟨ld, ri, rm, am, cr, dob, c.defaultFlightType, ⟨c.defaultDepAirportCd⟩, ⟨c.defaultArrAirportCd⟩,
          c.defaultBoardingClassCd⟩

theorem configOf_inj {c c' : AtrsConfig} {x : Config} (h : configOf c = some x) (h' : configOf c' = some x) :
    c = c' := by
  simp only [configOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h h'
  obtain ⟨a1, e1, a2, e2, a3, e3, a4, e4, a5, e5, a6, e6, rfl⟩ := h
  obtain ⟨b1, f1, b2, f2, b3, f3, b4, f4, b5, f5, b6, f6, h'⟩ := h'
  simp only [Config.mk.injEq, AirportCd.mk.injEq] at h'
  obtain ⟨rfl, rfl, rfl, rfl, rfl, rfl, g7, g8, g9, g10⟩ := h'
  cases c; cases c'
  simp only at *
  rw [inj_of_kernel natOfJ32_kernel e1 f1, inj_of_kernel natOfJ32_kernel e2 f2,
    inj_of_kernel natOfJ32_kernel e3 f3, inj_of_kernel natOfJ32_kernel e4 f4,
    inj_of_kernel natOfJ32_kernel e5 f5, inj_of_kernel dateOfSlash_kernel e6 f6, g7, g8, g9, g10]

/-! ## 問い合わせ（葉） -/

/-- 問い合わせの引数。日付は `dateOfJ`、空港コード・便名はそのまま。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def queryOf? : SrcQuery → Option MasterData.Query
  | .routeOf dep arr => some (.routeOf ⟨dep⟩ ⟨arr⟩)
  | .flightMasterOf name => some (.flightMasterOf ⟨name⟩)
  | .fareTypeOf cd => some (.fareTypeOf cd)
  | .boardingClassOf cd => some (.boardingClassOf cd)
  | .peakTimeOn d => (dateOfJ d).map .peakTimeOn
  | .multiplicationRatioOn d => (dateOfJ d).map .multiplicationRatioOn
  | .config => some .config
  | .codeList n => some (.codeList n)

/-- `queryOf?` の逆（定義域の上）。 -/
def queryBack : MasterData.Query → SrcQuery
  | .routeOf dep arr => .routeOf dep.val arr.val
  | .flightMasterOf name => .flightMasterOf name.val
  | .fareTypeOf cd => .fareTypeOf cd
  | .boardingClassOf cd => .boardingClassOf cd
  | .peakTimeOn d => .peakTimeOn ⟨d.year, d.month, d.day⟩
  | .multiplicationRatioOn d => .multiplicationRatioOn ⟨d.year, d.month, d.day⟩
  | .config => .config
  | .codeList n => .codeList n

theorem queryOf?_eq_some {x : SrcQuery} {q : MasterData.Query} (h : queryOf? x = some q) : x = queryBack q := by
  cases x <;> simp only [queryOf?, Option.some.injEq, Option.map_eq_some_iff] at h
  all_goals first
    | (subst h; rfl)
    | (obtain ⟨D, hD, rfl⟩ := h; simp only [queryBack]; rw [dateOfJ_eq_some hD])

@[obligation "ABS-048"]
theorem queryOf?_kernel : KernelIs queryOf? (undefOrEq queryOf?) :=
  kernelIs_undefOrEq fun _ _ _ hx hy => (queryOf?_eq_some hx).trans (queryOf?_eq_some hy).symm

/-! ## 入力（合成） -/

/-- 抽象側の状態（どちらも状態を持たない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def betaMQ (t : Unit) : Option Unit := some t

@[obligation "ABS-048"]
theorem betaMQ_kernel : KernelIs betaMQ Eq := fun x y => by simp [betaMQ]

/-- 入力: 設定・マスタ・問い合わせ。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiMQ (ic : SrcInput) : Option (Config × MasterData × MasterData.Query) :=
  (configOf ic.config).bind fun cfg => (masterDataOf ic.db).bind fun md =>
    (queryOf? ic.query).map fun q => (cfg, md, q)

/-! ## 出力（葉） -/

namespace Answer

/-- 区間のうち [Spec] が観測する成分（区間番号・運賃・出発・到着の空港コード）。 -/
def routeObs (r : SourceModel.Model.Route) : SourceModel.Model.Route :=
  { routeNo := r.routeNo, basicFare := r.basicFare,
    departureAirport := r.departureAirport.map fun a => { code := a.code },
    arrivalAirport := r.arrivalAirport.map fun a => { code := a.code } }

/-- 便マスタのうち [Spec] が観測する成分（便名・時刻・区間番号・機材の型式）。 -/
def flightMasterObs (f : SourceModel.Model.FlightMaster) : SourceModel.Model.FlightMaster :=
  { flightName := f.flightName, departureTime := f.departureTime, arrivalTime := f.arrivalTime,
    route := f.route.map fun r => { routeNo := r.routeNo }, plane := f.plane.map fun p => { craftType := p.craftType } }

/-- `null` を `none` に、値を写せたものを `some` に。 -/
def opt {α β : Type} (f : α → Option β) : Option α → Option (Option β)
  | none => some none
  | some a => (f a).map some

def route (r : SourceModel.Model.Route) : Option Spec.Route := do
  let no ← r.routeNo.bind natOfJ32
  let bf ← r.basicFare.bind natOfJ32
  let dep ← r.departureAirport.bind (·.code)
  let arr ← r.arrivalAirport.bind (·.code)
  pure ⟨no, ⟨dep⟩, ⟨arr⟩, bf⟩

def flightMaster (f : SourceModel.Model.FlightMaster) : Option Spec.FlightMaster := do
  let name ← f.flightName
  let no ← (f.route.bind (·.routeNo)).bind natOfJ32
  let dt ← f.departureTime.bind hmOfStr
  let ar ← f.arrivalTime.bind hmOfStr
  let ct ← f.plane.bind (·.craftType)
  pure ⟨⟨name⟩, no, dt, ar, ct⟩

def boardingClass (b : SourceModel.Model.BoardingClass) : Option MasterData.BoardingClassInfo := do
  let cd ← b.boardingClassCd
  let nm ← b.boardingClassName
  let ex ← b.extraCharge.bind natOfJ32
  pure ⟨cd, nm, ex⟩

def fareType (f : SourceModel.Model.FareType) : Option MasterData.FareTypeInfo := do
  let cd ← f.fareTypeCd
  let nm ← f.fareTypeName
  let dr ← f.discountRate.bind natOfJ32
  let s ← f.rsrvAvailableStartDayNum.bind natOfJ32
  let e ← f.rsrvAvailableEndDayNum.bind natOfJ32
  let pm ← f.passengerMinNum.bind natOfJ32
  pure ⟨cd, nm, dr, s, e, pm⟩

def peakTime (p : SourceModel.Model.PeakTime) : Option Spec.PeakTime := do
  let cd ← p.peakTimeCd
  let s ← p.peakStartDate.bind dateOfJ
  let e ← p.peakEndDate.bind dateOfJ
  let r ← p.multiplicationRatio.bind natOfJ32
  pure ⟨cd, s, e, r⟩

end Answer

/-- 答えのうち [Spec] が観測する成分。区間の空港名・空港の表示順、便マスタの区間の運賃・空港、
機材の座席数は捨てる。 -/
def answerObs : SrcAnswer → SrcAnswer
  | .route r => .route (r.map Answer.routeObs)
  | .flightMaster f => .flightMaster (f.map Answer.flightMasterObs)
  | a => a

/-- 出力: 答えを [Spec] の答えに写す。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def answerOf? : SrcAnswer → Option MasterData.Answer
  | .route r => (Answer.opt Answer.route r).map .route
  | .flightMaster f => (Answer.opt Answer.flightMaster f).map .flightMaster
  | .fareType f => (Answer.opt Answer.fareType f).map .fareType
  | .boardingClass b => (Answer.opt Answer.boardingClass b).map .boardingClass
  | .peakTime p => (Answer.opt Answer.peakTime p).map .peakTime
  | .ratio n => (natOfJ32 n).map .ratio
  | .config c => (configOf c).map .config
  | .codeList l => some (.codeList (l.map fun e => ⟨e.1, e.2⟩))

/-- 出力の核: どちらも定義されないか、[Spec] が観測する成分（`answerObs`）が等しい。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def answerKer (a b : SrcAnswer) : Prop :=
  (answerOf? a = none ∧ answerOf? b = none) ∨ answerObs a = answerObs b

theorem answerOf?_obs (a : SrcAnswer) : answerOf? (answerObs a) = answerOf? a := by
  cases a with
  | route r =>
    cases r with
    | none => simp [answerObs]
    | some r =>
      simp only [answerObs, answerOf?, Option.map_some, Answer.opt, Answer.route, Answer.routeObs]
      cases r.departureAirport <;> cases r.arrivalAirport <;> rfl
  | flightMaster f =>
    cases f with
    | none => simp [answerObs]
    | some f =>
      simp only [answerObs, answerOf?, Option.map_some, Answer.opt, Answer.flightMaster, Answer.flightMasterObs]
      cases f.route <;> cases f.plane <;> rfl
  | _ => simp [answerObs]

theorem opt_inj {α β : Type} {f : α → Option β} {g : α → α} {x y : Option α} {b : Option β}
    (hf : ∀ a a' c, f a = some c → f a' = some c → g a = g a')
    (hx : Answer.opt f x = some b) (hy : Answer.opt f y = some b) : x.map g = y.map g := by
  cases x <;> cases y <;> simp only [Answer.opt, Option.some.injEq, Option.map_eq_some_iff] at hx hy
  · rfl
  · obtain ⟨c, _, rfl⟩ := hy; cases hx
  · obtain ⟨c, _, rfl⟩ := hx; cases hy
  · obtain ⟨c, hc, rfl⟩ := hx
    obtain ⟨c', hc', e⟩ := hy
    cases e
    simp only [Option.map_some, Option.some.injEq]
    exact hf _ _ _ hc hc'

theorem natOfJ32_inj {x y : J32} {n : Nat} (hx : natOfJ32 x = some n) (hy : natOfJ32 y = some n) : x = y :=
  inj_of_kernel natOfJ32_kernel hx hy

namespace Answer

theorem route_inj {r r' : SourceModel.Model.Route} {c : Spec.Route} (h : route r = some c)
    (h' : route r' = some c) : routeObs r = routeObs r' := by
  simp only [route, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨no, ⟨v, hv, e1⟩, bf, ⟨w, hw, e2⟩, dep, ⟨a, ha, e3⟩, arr, ⟨b, hb, e4⟩, rfl⟩ := h
  obtain ⟨no', ⟨v', hv', f1⟩, bf', ⟨w', hw', f2⟩, dep', ⟨a', ha', f3⟩, arr', ⟨b', hb', f4⟩, h⟩ := h'
  simp only [Spec.Route.mk.injEq, AirportCd.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl⟩ := h
  obtain ⟨ac, an, ad⟩ := a; obtain ⟨ac', an', ad'⟩ := a'; obtain ⟨bc, bn, bd⟩ := b; obtain ⟨bc', bn', bd'⟩ := b'
  simp only at e3 e4 f3 f4
  subst e3 e4 f3 f4
  cases r; cases r'
  simp only at hv hw ha hb hv' hw' ha' hb'
  subst hv hw ha hb hv' hw' ha' hb'
  simp only [routeObs, Option.map_some, natOfJ32_inj e1 f1, natOfJ32_inj e2 f2]

theorem flightMaster_inj {f f' : SourceModel.Model.FlightMaster} {c : Spec.FlightMaster}
    (h : flightMaster f = some c) (h' : flightMaster f' = some c) : flightMasterObs f = flightMasterObs f' := by
  simp only [flightMaster, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨nm, hn, no, ⟨v, ⟨r, hr, hv⟩, e1⟩, dt, ⟨s, hs, e2⟩, ar, ⟨t, ht, e3⟩, ct, ⟨p, hp, e4⟩, rfl⟩ := h
  obtain ⟨nm', hn', no', ⟨v', ⟨r', hr', hv'⟩, f1⟩, dt', ⟨s', hs', f2⟩, ar', ⟨t', ht', f3⟩, ct', ⟨p', hp', f4⟩, h⟩ := h'
  simp only [Spec.FlightMaster.mk.injEq, FlightName.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl, rfl⟩ := h
  obtain ⟨rn, rb, ra, rd⟩ := r; obtain ⟨rn', rb', ra', rd'⟩ := r'
  obtain ⟨pc, pn, ps⟩ := p; obtain ⟨pc', pn', ps'⟩ := p'
  simp only at hv hv' e4 f4
  subst hv hv' e4 f4
  cases f; cases f'
  simp only at hn hr hs ht hp hn' hr' hs' ht' hp'
  subst hn hr hs ht hp hn' hr' hs' ht' hp'
  simp only [flightMasterObs, Option.map_some, natOfJ32_inj e1 f1, inj_of_kernel hmOfStr_kernel e2 f2,
    inj_of_kernel hmOfStr_kernel e3 f3]

theorem boardingClass_inj {b b' : SourceModel.Model.BoardingClass} {c : MasterData.BoardingClassInfo}
    (h : boardingClass b = some c) (h' : boardingClass b' = some c) : b = b' := by
  simp only [boardingClass, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨cd, hc, nm, hn, ex, ⟨v, hv, e1⟩, rfl⟩ := h
  obtain ⟨cd', hc', nm', hn', ex', ⟨v', hv', f1⟩, h⟩ := h'
  simp only [MasterData.BoardingClassInfo.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  cases b; cases b'
  simp only at hc hn hv hc' hn' hv'
  subst hc hn hv hc' hn' hv'
  rw [natOfJ32_inj e1 f1]

theorem fareType_inj {f f' : SourceModel.Model.FareType} {c : MasterData.FareTypeInfo}
    (h : fareType f = some c) (h' : fareType f' = some c) : f = f' := by
  simp only [fareType, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨cd, hc, nm, hn, dr, ⟨v1, h1, e1⟩, st, ⟨v2, h2, e2⟩, en, ⟨v3, h3, e3⟩, pm, ⟨v4, h4, e4⟩, rfl⟩ := h
  obtain ⟨cd', hc', nm', hn', dr', ⟨w1, k1, f1⟩, st', ⟨w2, k2, f2⟩, en', ⟨w3, k3, f3⟩, pm', ⟨w4, k4, f4⟩, h⟩ := h'
  simp only [MasterData.FareTypeInfo.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩ := h
  cases f; cases f'
  simp only at hc hn h1 h2 h3 h4 hc' hn' k1 k2 k3 k4
  subst hc hn h1 h2 h3 h4 hc' hn' k1 k2 k3 k4
  rw [natOfJ32_inj e1 f1, natOfJ32_inj e2 f2, natOfJ32_inj e3 f3, natOfJ32_inj e4 f4]

theorem peakTime_inj {p p' : SourceModel.Model.PeakTime} {c : Spec.PeakTime}
    (h : peakTime p = some c) (h' : peakTime p' = some c) : p = p' := by
  simp only [peakTime, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨cd, hc, s, ⟨d1, h1, e1⟩, e, ⟨d2, h2, e2⟩, r, ⟨v, h3, e3⟩, rfl⟩ := h
  obtain ⟨cd', hc', s', ⟨d1', k1, f1⟩, e', ⟨d2', k2, f2⟩, r', ⟨v', k3, f3⟩, h⟩ := h'
  simp only [Spec.PeakTime.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl⟩ := h
  cases p; cases p'
  simp only at hc h1 h2 h3 hc' k1 k2 k3
  subst hc h1 h2 h3 hc' k1 k2 k3
  rw [inj_of_kernel dateOfJ_kernel e1 f1, inj_of_kernel dateOfJ_kernel e2 f2, natOfJ32_inj e3 f3]

end Answer

theorem answerOf?_inj {a b : SrcAnswer} {x : MasterData.Answer} (ha : answerOf? a = some x)
    (hb : answerOf? b = some x) : answerObs a = answerObs b := by
  cases a <;> cases b <;> simp only [answerOf?, Option.map_eq_some_iff, Option.some.injEq] at ha hb
  -- 構築子が違えば、答えの構築子も違う
  all_goals first
    | (obtain ⟨_, _, rfl⟩ := ha; obtain ⟨_, _, h⟩ := hb; cases h; done)
    | (obtain ⟨_, _, rfl⟩ := ha; cases hb; done)
    | (subst ha; obtain ⟨_, _, h⟩ := hb; cases h; done)
    | (subst ha; cases hb; done)
    | skip
  case route.route r r' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simp only [answerObs, SrcAnswer.route.injEq]
    exact opt_inj (fun _ _ _ => Answer.route_inj) hc hc'
  case flightMaster.flightMaster f f' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simp only [answerObs, SrcAnswer.flightMaster.injEq]
    exact opt_inj (fun _ _ _ => Answer.flightMaster_inj) hc hc'
  case fareType.fareType f f' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simpa [answerObs] using opt_inj (g := id) (fun _ _ _ => Answer.fareType_inj) hc hc'
  case boardingClass.boardingClass b b' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simpa [answerObs] using opt_inj (g := id) (fun _ _ _ => Answer.boardingClass_inj) hc hc'
  case peakTime.peakTime p p' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simpa [answerObs] using opt_inj (g := id) (fun _ _ _ => Answer.peakTime_inj) hc hc'
  case ratio.ratio n n' =>
    obtain ⟨c, hc, rfl⟩ := ha; obtain ⟨c', hc', h⟩ := hb; cases h
    simp only [answerObs, natOfJ32_inj hc hc']
  case config.config c c' =>
    obtain ⟨y, hy, rfl⟩ := ha; obtain ⟨y', hy', h⟩ := hb; cases h
    simp only [answerObs, configOf_inj hy hy']
  case codeList.codeList l l' =>
    subst ha
    simp only [MasterData.Answer.codeList.injEq] at hb
    simp only [answerObs, SrcAnswer.codeList.injEq]
    have hi : Function.Injective fun e : String × String => (⟨e.1, e.2⟩ : CodeEntry) := by
      intro e e' h; simp only [CodeEntry.mk.injEq] at h; exact Prod.ext h.1 h.2
    exact ((List.map_inj_right hi).mp hb).symm

/-- 出力の核の定理。 -/
@[obligation "ABS-048"]
theorem answerOf?_kernel : KernelIs answerOf? answerKer := by
  intro a b
  constructor
  · intro e
    cases ha : answerOf? a with
    | none => exact Or.inl ⟨ha, by rw [← e, ha]⟩
    | some x => exact Or.inr (answerOf?_inj ha (by rw [← e, ha]))
  · rintro (⟨ha, hb⟩ | h)
    · rw [ha, hb]
    · rw [← answerOf?_obs a, h, answerOf?_obs]

/-! ## 既知差異 D-027 -/

/-- D-027（前提型・具体側の入力）: DB のマスタの各行・設定・問い合わせの引数が、[Spec] の型で表せる。 -/
@[deviation "D-027"]
def dev_D027 (ic : SrcInput) : Prop := (aiMQ ic).isSome = true

/-- 前提を満たす入力: 空の DB・上流の設定・設定の問い合わせ。 -/
def ic_ok : SrcInput := { db := {}, config := upstreamConfig, query := .config }

/-- 前提を満たさない入力: 未知の搭乗クラスコード `X` の行を持つ DB（ABS-127 の例）。 -/
def ic_unknownBoardingClass : SrcInput :=
  { db := { boardingClass := [⟨⟨"X", by decide⟩, none, ⟨0, by decide⟩, ⟨1, by decide⟩⟩] },
    config := upstreamConfig, query := .config }

theorem dev_D027_nontrivial : Nontrivial dev_D027 :=
  ⟨⟨ic_ok, by unfold dev_D027; decide⟩, ⟨ic_unknownBoardingClass, by unfold dev_D027; decide⟩⟩

/-! ## 2b-1 の補題とのつなぎ -/

theorem airportOfRow_eq_some {r : AirportRow} {a : Airport} (h : airportOfRow r = some a) : a = airportOf r := by
  simp only [airportOfRow, Option.map_eq_some_iff] at h
  obtain ⟨d, hd, rfl⟩ := h
  rw [natOfInt4_eq_some] at hd
  simp only [airportOf, hd, Int.toNat_natCast]

/-- 空港の表の写しは、2b-1 の `airportOf` で各行を写した列。 -/
theorem mapM_airportOfRow {rows : List AirportRow} {as : List Airport} (h : rows.mapM airportOfRow = some as) :
    as = rows.map airportOf := by
  induction rows generalizing as with
  | nil => simp at h; simp [h]
  | cons r rows ih =>
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨a, ha, as', has, rfl⟩ := h
    simp only [List.map_cons, airportOfRow_eq_some ha, ih has]

end Abstraction.MasterData
