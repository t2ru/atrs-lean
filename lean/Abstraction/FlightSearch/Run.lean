import Abstraction.FlightSearch.Order
import Abstraction.FlightSearch.Group
import Abstraction.FlightSearch.Providers
import Abstraction.FlightSearch.Period
import Abstraction.Fare.Loop
import SourceModel.FlightSearchQuery

/-!
# Abstraction.FlightSearch.Run

ABS-011 の補題: 空席照会の具体機械の 1 歩（`runSearchFlight` と `catchBusiness`）の結果の写しは、[Spec] の `answer`
（`run_spec`）。結合（`Join`・`Candidates`）・整列（`Order`）・Provider（`Providers`）・畳み込み（`Group`）・期間
（`Period`）・運賃（`Abstraction.Fare.Loop`）の補題を合わせる。
-/

namespace Abstraction.FlightSearch.Run
open Spec.MasterData (Airport Route FlightMaster BoardingClass FareType)
open Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Pre Abstraction.MasterData.Query
  Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Join Abstraction.FlightSearch.Candidates
  Abstraction.FlightSearch.Order
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.Exception LangSemantics.Java.Int
  LangSemantics.Java.ResultLemmas Spec.Model Spec.FlightSearch

open LangSemantics.Java LangSemantics.Sql.Postgresql LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas Spec Spec.Prim
  SourceModel.Repository.Schema SourceModel.Repository.Flight

/-! ## キーの一意性（MD-1・MD-2 から） -/

theorem fareTypeCodes_nodup {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1) :
    (db.fareType.map (·.fareTypeCd.val)).Nodup := by
  obtain ⟨-, -, -, -, hfts, -⟩ := masterDataOf_eq_some.mp hm
  have e : md.fareTypes.map (fun x => some x.fareTypeCd) = db.fareType.map fun r => ftCdOf r.fareTypeCd.val :=
    mapM_some_map hfts fun _ _ h => (fareTypeOfRow_code h).symm
  have hnd : (md.fareTypes.map fun x => some x.fareTypeCd).Nodup :=
    nodup_map_of_imp h1.2.2.2.2.1 fun _ _ _ _ e => Option.some.inj e
  rw [e] at hnd
  exact nodup_map_of_imp hnd fun _ _ _ _ e => by simp only [e]

theorem flightNames_nodup {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1) :
    (db.flightMaster.map (·.flightName.val)).Nodup := by
  obtain ⟨-, -, hfm, -⟩ := masterDataOf_eq_some.mp hm
  have e : md.flightMasters.map (·.flightName) = db.flightMaster.map fun f => (⟨f.flightName.val⟩ : FlightName) :=
    mapM_some_map hfm fun _ _ h => (flightMasterOfRow_fields h).2
  have := h1.2.2.1
  rw [e] at this
  exact nodup_map_of_imp this fun _ _ _ _ e => by simp only [e]

theorem routeKeys_nodup {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h2 : md.MD2) :
    (db.route.map routeKey).Nodup := by
  obtain ⟨-, hrts, -⟩ := masterDataOf_eq_some.mp hm
  have e : md.routes.map (fun r => (r.depAirportCd, r.arrAirportCd)) =
      db.route.map fun r => ((⟨r.depAirportCd.val⟩ : AirportCd), (⟨r.arrAirportCd.val⟩ : AirportCd)) :=
    mapM_some_map hrts fun _ _ h => by rw [(routeOfRow_codes h).1, (routeOfRow_codes h).2]
  have := h2.1
  rw [e] at this
  exact nodup_map_of_imp this fun a _ b _ e => by
    simp only [routeKey, Prod.mk.injEq] at e
    rw [e.1, e.2]

/-! ## 束縛する値と文の結果 -/

theorem getFareTypeCdList_eq (t : FlightType) :
    SourceModel.FlightSearch.getFareTypeCdList (some t) = fareTypesFor t := by
  cases t <;> rfl

/-- 文の結果の並び: 並べ方が許される並びを返すなら、並べた行の写しは [Spec] の整列した候補で、各行は `RowOk`。 -/
theorem repo_spec {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (hinv : w.Inv)
    {c : Criteria} {dep arr : String} {route : Route} (hroute : md.routeOf ⟨dep⟩ ⟨arr⟩ = some route) (bdn : Int)
    {sortRows : List VacantSeatRow → List VacantSeatRow} (hs : SortAllowed sortRows) :
    (sortRows (vacantSeatRows db fd (paramsOf c dep arr bdn))).mapM (candOfRow md) =
        some ((w.flights.filterMap (candidateOf md c route bdn)).mergeSort candidateLe) ∧
      ∀ r ∈ sortRows (vacantSeatRows db fd (paramsOf c dep arr bdn)),
        ∃ X ∈ w.flights.filterMap (candidateOf md c route bdn), RowOk md r X := by
  have hfl : fd.flight.mapM flightOfRow = some w.flights := by
    simp only [worldOfDb, Option.map_eq_some_iff] at hw
    obtain ⟨fs, hfs, rfl⟩ := hw
    exact hfs
  rw [vacantSeatRows_eq (fareTypeCodes_nodup hm hv.md1) (flightNames_nodup hm hv.md1) (routeKeys_nodup hm hv.md2)
    (dep := dep) (arr := arr) rfl rfl]
  obtain ⟨h1, h2⟩ := rows_cands hm hroute bdn hfl (c := c)
  have ho := hs (fd.flight.filterMap (rowAt db (paramsOf c dep arr bdn) dep arr))
  refine ⟨sorted_cands h1 h2 (noTie_cands hv hinv c route bdn) ho, fun r hr => ?_⟩
  exact h2 r ((allowed_perm ho).mem_iff.mp hr)

/-! ## 行ごとの写像と Provider での詰め直し -/

/-- `searchFlight` の `flightList.mapM` の本体（Provider で詰め直す）。 -/
def enrich (ftp : SourceModel.MasterData.FareTypeProvider) (fmp : SourceModel.MasterData.FlightMasterProvider)
    (bcp : SourceModel.MasterData.BoardingClassProvider) (flight : SourceModel.Model.Flight) :
    JResult SourceModel.Model.Flight := do
  let ftCd := (← flight.fareType.deref "fareType").fareTypeCd
  let fareType ← SourceModel.MasterData.getFareType ftp ftCd
  let name ← match (← flight.flightMaster.deref "flightMaster").flightName with
    | some n => pure n
    | none => throw (.illegalArgument "flightName must have some text.")
  let flightMaster ← SourceModel.MasterData.getFlightMaster fmp name
  let bcCd := (← flight.boardingClass.deref "boardingClass").boardingClassCd
  let boardingClass ← SourceModel.MasterData.getBoardingClass bcp bcCd
  return { flight with fareType := fareType, flightMaster := flightMaster, boardingClass := boardingClass }

theorem find?_routeNo {md : MasterData} (h1 : md.MD1) {route : Route} (hr : route ∈ md.routes) :
    md.routes.find? (fun r => r.routeNo == route.routeNo) = some route := by
  cases hf : md.routes.find? (fun r => r.routeNo == route.routeNo) with
  | none =>
    rw [List.find?_eq_none] at hf
    exact absurd (by simp) (hf route hr)
  | some r =>
    have hc := List.find?_some hf
    simp only [beq_iff_eq] at hc
    rw [inj_of_nodup_map h1.2.1 (List.mem_of_find?_eq_some hf) hr hc]

/-- 行ごと: 結果の行の写像は例外を投げず、Provider で詰め直した値は、候補の写し（`FlightOk`）。 -/
theorem row_ok {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {w : Spec.Port.World} {c : Criteria} {route : Route}
    (hroute : md.routeOf c.depAirportCd c.arrAirportCd = some route) (hfn : FlightNamesHaveText md c) {bdn : Int}
    {p : SourceModel.MasterQuery.Providers}
    (hbcq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hftq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeCodeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    (hfmq : ∀ name : FlightName, Text.hasText name.val = true →
      ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
      ∃ fm r da aa dt art, SourceModel.MasterData.getFlightMaster p.flightMaster name.val = .ok (some fm) ∧
        fm.flightName = some name.val ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
        fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
        r.departureAirport = some da ∧ da.name = airportName? md rt.depAirportCd ∧ r.arrivalAirport = some aa ∧
        aa.name = airportName? md rt.arrAirportCd)
    {bcM : BoardingClass} (hbcM : md.boardingClassOf c.boardingClassCd = some bcM)
    {depName arrName : String} (hdn : airportName? md route.depAirportCd = some depName)
    (han : airportName? md route.arrAirportCd = some arrName)
    {bfJ : J32} {b : Nat} (hbf : bfJ.val = (b : Int)) (hb : b ≤ Range.maxBasicFare)
    (hd2 : ∀ ft ∈ md.fareTypes, ft.fareTypeCd ∈ fareTypesFor c.flightType → Abstraction.Fare.Alpha.dev_D002 ⟨b, ft.discountRate⟩)
    {r : VacantSeatRow} {X : Candidate} (hr : RowOk md r X) (hX : X ∈ w.flights.filterMap (candidateOf md c route bdn)) :
    ∃ F0, SourceModel.Repository.Mapping.flight r.result = .ok F0 ∧
      ∃ E, enrich p.fareType p.flightMaster p.boardingClass F0 = .ok E ∧
        Abstraction.FlightSearch.Group.FlightOk LangSemantics.Java.DecimalFormat.Symbols.ascii bfJ b depName arrName E X := by
  obtain ⟨hc, -, -⟩ := hr
  obtain ⟨F', -, hF'X⟩ := List.mem_filterMap.mp hX
  obtain ⟨eF', -, -, -, hrno, hbcF, hftin⟩ := candidateOf_cond hF'X
  simp only [candOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hc
  obtain ⟨F, hF, fm, hfm, ft, hft, rfl⟩ := hc
  simp only at eF' hrno
  subst eF'
  simp only [flightOfRow, rowFlight, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at hF
  obtain ⟨d, hd, bc, hbc, ftc, hftc, v, hvn, rfl⟩ := hF
  simp only at hbcF hfm hft hftin
  subst hbcF
  refine ⟨(⟨some { fareTypeCd := some ftc }, SourceModel.Repository.Mapping.date r.result.departureDate,
    SourceModel.Repository.Mapping.int r.result.vacantNum, some { flightName := some r.result.flightName.val },
    some { boardingClassCd := some c.boardingClassCd }⟩ : SourceModel.Model.Flight), ?_, ?_⟩
  · simp only [SourceModel.Repository.Mapping.flight, bcCdOf_mapping hbc, ftCdOf_mapping hftc, ok_bind]
    rfl
  -- 便マスタ
  have hfmm := List.mem_of_find?_eq_some hfm
  have hfmn := List.find?_some hfm
  simp only [beq_iff_eq] at hfmn
  have hname : Text.hasText r.result.flightName.val = true := by
    have := hfn route hroute fm hfmm hrno; rw [hfmn] at this; exact this
  have hroutem : route ∈ md.routes := List.mem_of_find?_eq_some hroute
  obtain ⟨fmJ, rJ, da, aa, dt, art, hgfm, hfmJn, hdt, hdt', hat, hat', hrJ, hda, hdan, haa, haan⟩ :=
    hfmq ⟨r.result.flightName.val⟩ hname fm hfm route (by rw [hrno]; exact find?_routeNo hv.md1 hroutem)
  -- 搭乗クラス
  obtain ⟨bJ, -, hbJ, hbJc, -, -⟩ := Abstraction.Fare.Load.boardingClass_of_answer (by rw [hbcq, hbcM]; rfl)
  have hbcMc := List.find?_some hbcM
  simp only [beq_iff_eq] at hbcMc
  -- 運賃種別
  obtain ⟨fJ, dJ, hfJ, hfJc, hfJn, hdJ, hdJv⟩ := Abstraction.FlightSearch.Providers.fareType_of_answer'
    (by rw [hftq, hft]; rfl)
  have hftm := List.mem_of_find?_eq_some hft
  have hftcc := List.find?_some hft
  simp only [beq_iff_eq] at hftcc
  have hr100 : ft.discountRate ≤ 100 := hv.md8.2.2.2 ft hftm
  have hb' : b ≤ 100000000 := hb
  have hfare := Abstraction.Fare.Factors.fare_src_eq' hr100 (b := b) (by omega)
    (Nat.lt_of_le_of_lt (Nat.mul_le_mul hb' (Nat.sub_le 100 ft.discountRate)) (by decide)) (hd2 ft hftm (by
      have hc' := List.find?_some hft; simp only [beq_iff_eq] at hc'; rw [hc']; exact hftin))
  refine ⟨(⟨p.fareType.fareTypeCodeMap.get ftc, SourceModel.Repository.Mapping.date r.result.departureDate,
    SourceModel.Repository.Mapping.int r.result.vacantNum, some fmJ,
    p.boardingClass.boardingClassCodeMap.get c.boardingClassCd⟩ : SourceModel.Model.Flight), ?_, ?_⟩
  · simp only [enrich, JRef.deref, SourceModel.MasterData.getFareType, SourceModel.MasterData.getBoardingClass,
      hgfm, ok_bind, pure_bind]
    rfl
  · refine ⟨⟨fmJ, rJ, da, aa, dt, art, rfl, hfmJn, hdt, hdt', hat, hat', hrJ, hda, by rw [hdan, hdn], haa,
      by rw [haan, han]⟩, ⟨bJ, hbJ, by rw [hbJc, hbcMc]⟩, ⟨_, rfl, ?_⟩, ⟨fJ, dJ, _, hfJ, by rw [hfJc, hftcc], hfJn,
      hdJ, Abstraction.Fare.Loop.calculateFare_ok hbf hdJv hr100, ?_⟩, ⟨_, rfl, ?_⟩⟩
    · simp only [dateOfJ_ofEpochDay]; exact hd
    · exact Abstraction.FlightSearch.Format.formatJ32S_ascii hfare
    · apply natOfJ32_eq_some.mpr
      rw [J32.val_ofInt_of_inRange _ ⟨by have := r.result.vacantNum.property.1; simp only [J32.minValue]; omega,
        by have := r.result.vacantNum.property.2; simp only [J32.maxValue]; omega⟩]
      exact natOfInt4_eq_some.mp hvn

/-! ## 畳み込みまで -/

/-- 正常終了の値（例外なら既定値）。 -/
def okD {α : Type} (d : α) : JResult α → α
  | .ok a => a
  | .error _ => d

theorem mapM_ok_of {β γ : Type} (l : List β) (f : β → JResult γ) (d : γ) (h : ∀ x ∈ l, ∃ y, f x = .ok y) :
    l.mapM f = .ok (l.map fun x => okD d (f x)) := by
  apply mapM_ok
  intro x hx
  obtain ⟨y, hy⟩ := h x hx
  rw [hy]; rfl

/-- 詰め直しと畳み込み: 各行で詰め直しが例外を投げず `FlightOk` なら、業務例外にならず、写しは [Spec] の `group`。 -/
theorem tail_ok {ρ : Type} (o : List ρ) (F : SourceModel.Model.Flight → JResult SourceModel.Model.Flight)
    (M : ρ → SourceModel.Model.Flight) (C : ρ → Candidate) {bf : J32} {b : Nat} {dn an : String}
    (h : ∀ r ∈ o, ∃ E, F (M r) = .ok E ∧ Abstraction.FlightSearch.Group.FlightOk LangSemantics.Java.DecimalFormat.Symbols.ascii bf b dn an E (C r)) :
    ∃ oc, SourceModel.FlightSearchQuery.catchBusiness
        ((o.map M).mapM F >>= fun fl => SourceModel.FlightSearch.createFlightVacantInfoList LangSemantics.Java.DecimalFormat.Symbols.ascii fl bf) = .ok oc ∧
      aoS oc = some (.ok (group dn an b (o.map C))) := by
  have hm : (o.map M).mapM F = .ok (o.map fun r => okD {} (F (M r))) := by
    rw [mapM_ok_of (o.map M) F {} (fun x hx => by
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hx
      obtain ⟨E, hE, -⟩ := h r hr
      exact ⟨E, hE⟩), List.map_map]
    rfl
  obtain ⟨ds, hds, hα⟩ := Abstraction.FlightSearch.Group.group_spec (sep := LangSemantics.Java.DecimalFormat.Symbols.ascii) (bf := bf) (b := b) (depName := dn)
    (arrName := an) o (fun r => okD {} (F (M r))) C (fun r hr => by
      obtain ⟨E, hE, hok⟩ := h r hr
      simp only [hE, okD]; exact hok)
  refine ⟨.ok ds, ?_, ?_⟩
  · rw [hm, ok_bind, hds]; rfl
  · simp only [aoS, hα, Option.map_some]

/-! ## 1 歩 -/

/-- 具体側の 1 歩: D-027（入力の像がある）・PRE・D-001・D-002・D-014・D-032 の下で、どの許される並びでも、
`catchBusiness (runSearchFlight …)` は例外を投げず、結果の写しは [Spec] の `answer`。 -/
theorem run_spec {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (hinv : w.Inv)
    {ic : SourceModel.FlightSearch.SearchInput} {i : Spec.FlightSearch.SearchInput} (hα : aiS ic = some i)
    (hp : SearchInput.Pre w i) (h1 : dev_D001S i) (h2 : dev_D002S i) (h14 : dev_D014S ic) (h32 : dev_D032 ic)
    {mo : SourceModel.MasterQuery.Order} (hmo : mo.Allowed ic.db) {sortRows : List VacantSeatRow → List VacantSeatRow}
    (hs : SortAllowed sortRows) :
    ∃ oc, SourceModel.FlightSearchQuery.catchBusiness (SourceModel.FlightSearch.runSearchFlight fd ic mo sortRows) = .ok oc ∧
      aoS oc = some (answer w i) := by
  simp only [aiS, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hα
  obtain ⟨cfg, hcfg, md, hm, T, hT, c, hc, rfl⟩ := hα
  obtain ⟨tc, htc, hcrit⟩ := hc
  simp only [criteriaOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hcrit
  obtain ⟨D, hD, bc, hbc, dep, hdep, arr, harr, ft, hft, rfl⟩ := hcrit
  obtain ⟨dj, hdj, hDj⟩ := hD
  obtain ⟨hcv, hv, hbsome, hdepT, harrT, hfn⟩ := hp
  simp only at hcv hv hbsome hdepT harrT hfn h1 h2
  obtain ⟨p, hl, hpt, hrq, hbcq, hftq, hfmq⟩ := Abstraction.FlightSearch.Providers.load_fs hm hv hmo
  simp only [SourceModel.FlightSearch.runSearchFlight, hl, ok_bind, SourceModel.FlightSearch.searchFlight, htc, hdj, hbc,
    hdep, harr, hft, pure_bind, Option.getD_some, show ic.sharedClock = (ic.today, ic.today) from h14]
  have hL : ic.config.limitDay.val = (cfg.limitDay : Int) := by
    simp only [configOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hcfg
    obtain ⟨ld, hld, _, _, _, _, _, _, _, _, _, _, rfl⟩ := hcfg
    exact natOfJ32_eq_some.mp hld
  rw [assertHasText_ok hdepT, assertHasText_ok harrT, ok_bind, ok_bind,
    Abstraction.FlightSearch.Period.validateDepatureDate_eq hL hT hDj]
  -- [Spec] の側
  have hans : answer w ⟨cfg, md, T, ⟨D, bc, ⟨dep⟩, ⟨arr⟩, ft⟩⟩ =
      (searchFlight cfg md T ⟨D, bc, ⟨dep⟩, ⟨arr⟩, ft⟩ w.findAll).getD (.ok []) := rfl
  rw [hans]
  unfold searchFlight validateDepartureDate
  cases hop : outOfPeriod cfg T D
  · simp only [Bool.false_eq_true, ↓reduceIte, ok_bind]
    obtain ⟨ans, hget, hansα⟩ := hrq ⟨dep⟩ ⟨arr⟩ hdepT harrT
    rw [hget, ok_bind]
    cases hro : md.routeOf ⟨dep⟩ ⟨arr⟩ with
    | none =>
      rw [hro] at hansα
      cases ans with
      | some rr =>
        simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at hansα
        obtain ⟨x, -, hx⟩ := hansα
        simp at hx
      | none =>
        refine ⟨.error (.business "e.ar.b1.2002"), ?_, rfl⟩
        rfl
    | some route =>
      rw [hro] at hansα
      cases ans with
      | none => simp [answerOf?, AnswerOf.opt] at hansα
      | some rr =>
      simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff, Function.comp,
        Spec.MasterQuery.Answer.route.injEq, Option.some.injEq] at hansα
      obtain ⟨x, hx, rfl⟩ := hansα
      simp only [AnswerOf.route, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
        Option.some.injEq] at hx
      obtain ⟨no, hno, bfr, hbfr, dc, hdc, ac, hac, rfl⟩ := hx
      obtain ⟨bfJ, hbfJ, hbfJv⟩ := hbfr
      obtain ⟨da, hda, hdac⟩ := hdc
      obtain ⟨aa, haa, haac⟩ := hac
      simp only
      -- 区間の空港コードは照会のもの
      have hrc := List.find?_some hro
      simp only [Bool.and_eq_true, beq_iff_eq, AirportCd.mk.injEq] at hrc
      obtain ⟨rfl, rfl⟩ := hrc
      have hroutem := List.mem_of_find?_eq_some hro
      -- 束縛する値
      have hbdn := Abstraction.FlightSearch.Period.beforeDayNum_val hT hDj
      have hparams : bind (⟨some bc, some dj, some rr, some (J64.ofInt (ic.today.daysBetween dj)),
          some (SourceModel.FlightSearch.getFareTypeCdList (some ft))⟩ : VacantSeatSearchCriteriaDto) =
          paramsOf ⟨D, bc, ⟨dc⟩, ⟨ac⟩, ft⟩ dc ac (Date.daysBetween T D) := by
        simp only [SourceModel.Repository.Flight.bind, sqlOf, paramsOf, hda, hdac, haa, haac, Option.bind_some, Option.getD_some,
          getFareTypeCdList_eq, hbdn, (dateOfJ_eq_some hDj).2, fareTypeCdName_eq, boardingClassCdName_eq]
      -- 基本運賃
      obtain ⟨bcM, hbcM⟩ := Option.isSome_iff_exists.mp hbsome
      obtain ⟨bJ, e, hgetb, -, hex, heval⟩ := Abstraction.Fare.Load.boardingClass_of_answer (by rw [hbcq, hbcM]; rfl)
      have hbcMm := List.mem_of_find?_eq_some hbcM
      have hX : bfr + bcM.extraCharge ≤ 10000000 := hv.md8.2.1 _ hroutem bcM hbcMm
      have hdev := h1 _ hro hop
      unfold Abstraction.Fare.Alpha.dev_D001 at hdev
      simp only [hbcM] at hdev
      obtain ⟨v, hcalc, hvv⟩ := Abstraction.Fare.Loop.calculateBasicFare_eq hm hv hmo.2.2.2.2.1 hpt hgetb hex heval
        (natOfJ32_eq_some.mp hbfJv) hDj hX hdev
      have hbasic : Spec.Fare.basicFare md bfr bc D =
          some ((bfr + bcM.extraCharge) * md.multiplicationRatioOn D / 100) := by
        simp only [Spec.Fare.basicFare, hbcM, Option.map_some]
      have hratio := Abstraction.Fare.BasicFareRun.ratioOn_le hv.md8 D
      have hbmax : (bfr + bcM.extraCharge) * md.multiplicationRatioOn D / 100 ≤ Range.maxBasicFare := by
        have := Nat.mul_le_mul hX hratio
        show _ ≤ 100000000
        omega
      -- 空港名
      obtain ⟨⟨a1, ha1, hc1⟩, ⟨a2, ha2, hc2⟩⟩ := hv.md3.1 _ hroutem
      have hdn' : (airportName? md ⟨dc⟩).isSome := by
        unfold airportName?; rw [Option.isSome_map, List.find?_isSome]; exact ⟨a1, ha1, by simp [hc1]⟩
      have han' : (airportName? md ⟨ac⟩).isSome := by
        unfold airportName?; rw [Option.isSome_map, List.find?_isSome]; exact ⟨a2, ha2, by simp [hc2]⟩
      obtain ⟨dn, hdn⟩ := Option.isSome_iff_exists.mp hdn'
      obtain ⟨an, han⟩ := Option.isSome_iff_exists.mp han'
      -- 文の結果
      obtain ⟨hcs, hok⟩ := repo_spec hm hv hw hinv hro (Date.daysBetween T D) hs (c := ⟨D, bc, ⟨dc⟩, ⟨ac⟩, ft⟩)
      have hd2 := h2 _ _ hro hop hbasic
      have hrepo : SourceModel.FlightSearch.repositoryOf ic.db fd sortRows
          (⟨some bc, some dj, some rr, some (J64.ofInt (ic.today.daysBetween dj)),
            some (SourceModel.FlightSearch.getFareTypeCdList (some ft))⟩ : VacantSeatSearchCriteriaDto) =
          .ok ((sortRows (vacantSeatRows ic.db fd (paramsOf ⟨D, bc, ⟨dc⟩, ⟨ac⟩, ft⟩ dc ac (Date.daysBetween T D)))).map
            fun r => okD {} (SourceModel.Repository.Mapping.flight r.result)) := by
        unfold SourceModel.FlightSearch.repositoryOf
        rw [hparams]
        apply mapM_ok_of
        intro r hr
        obtain ⟨X, hX, hrX⟩ := hok r hr
        obtain ⟨F0, hF0, -⟩ := row_ok hm hv hro hfn hbcq hftq hfmq hbcM hdn han hvv hbmax hd2 hrX hX
        exact ⟨F0, hF0⟩
      rw [hrepo, ok_bind]
      generalize sortRows (vacantSeatRows ic.db fd (paramsOf ⟨D, bc, ⟨dc⟩, ⟨ac⟩, ft⟩ dc ac (Date.daysBetween T D))) = o
        at hcs hok
      cases o with
      | nil =>
        simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at hcs
        refine ⟨.error (.notFound "e.ar.b1.2003"), ?_, ?_⟩
        · rfl
        · simp only [Spec.Port.World.findAll, ← hcs, List.isEmpty_nil, ↓reduceIte, Option.getD_some]
          rfl
      | cons r0 os =>
        obtain ⟨X0, -, hX0, -, -⟩ := hok r0 (List.mem_cons_self ..)
        have hsorted := mapM_eq_map_getD X0 hcs
        obtain ⟨Y, Ys, -, -, hYs⟩ := mapM_some_cons hcs
        have hne : (List.map (fun r => okD {} (SourceModel.Repository.Mapping.flight r.result)) (r0 :: os)).isEmpty =
          false := rfl
        rw [hne]
        simp only [Bool.false_eq_true, ↓reduceIte, hbfJ, JRef.deref, ok_bind, hcalc, show ic.formatSymbols = LangSemantics.Java.DecimalFormat.Symbols.ascii from h32]
        simp only [Spec.Port.World.findAll]
        have hne2 : ((w.flights.filterMap (candidateOf md ⟨D, bc, ⟨dc⟩, ⟨ac⟩, ft⟩ ⟨no, ⟨dc⟩, ⟨ac⟩, bfr⟩
            (Date.daysBetween T D))).mergeSort candidateLe).isEmpty = false := by rw [hYs]; rfl
        simp only [hne2, Bool.false_eq_true, ↓reduceIte, hbasic, hdn, han, Option.bind_eq_bind,
          Option.bind_some, Option.pure_def, Option.getD_some]
        rw [hsorted]
        refine tail_ok (r0 :: os) _ _ (fun r => (candOfRow md r).getD X0) ?_
        intro r hr
        obtain ⟨X, hX, hrX⟩ := hok r hr
        obtain ⟨F0, hF0, E, hE, hfok⟩ := row_ok hm hv hro hfn hbcq hftq hfmq hbcM hdn han hvv hbmax hd2 hrX hX
        refine ⟨E, ?_, by simp only [hrX.1, Option.getD_some]; exact hfok⟩
        rw [hF0, ← hE]
        simp only [okD, enrich, JRef.deref, pure_bind]
        rfl
  · refine ⟨.error (.business "e.ar.b1.2001"), ?_, rfl⟩
    simp only [↓reduceIte]
    rfl
end Abstraction.FlightSearch.Run
