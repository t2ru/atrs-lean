import Abstraction.Fare.Load
import Abstraction.FlightSearch.Candidates
import Spec.FlightSearch

/-!
# Abstraction.FlightSearch.Providers

ABS-011 の補題: 起動時の読み込みで作られるキャッシュ（Provider）の答え。

- `flightMaster_full`: 便マスタのキャッシュの答えは、便名・時刻のほか、区間の出発・到着の空港名を持ち、それは [Spec] の
  空港名（`airportName?`）。`Abstraction.Fare.Load.flightMaster_fare` と同じ形で、空港の行まで追う。
- `fareType_of_answer'`: 運賃種別のキャッシュの答えから、コード・名前・割引率を取り出す。
- `load_fs`: 空席照会が使う読み込みの性質をまとめたもの。
-/

namespace Abstraction.FlightSearch.Providers
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Join Abstraction.MasterData.Load
  Abstraction.MasterData.Lookup Abstraction.MasterData.Pre Abstraction.MasterData.Query Abstraction.MasterData.QueryRun
  Spec.Model Spec.Prim.Text Abstraction.Fare.Load
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.Exception LangSemantics.Java.HashMap
  LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas

open LangSemantics.Java Spec Spec.Prim LangSemantics.Core
  SourceModel.Db.Schema SourceModel.Domain.Repository.Route SourceModel.Domain.Repository.Route.RouteRepository SourceModel.Domain.Repository.Flight
  SourceModel.Domain.Repository.Flight.FlightRepository SourceModel.Domain.Repository.Boardingclass SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository SourceModel.Domain.Repository.Faretype
  SourceModel.Domain.Repository.Faretype.FareTypeRepository SourceModel.Domain.Repository.Peaktime SourceModel.Domain.Repository.Peaktime.PeakTimeRepository SourceModel.Config.App
  SourceModel.Config.App.AtrsCodeListConfig SourceModel.Domain.Common.Masterdata SourceModel.MasterQuery

theorem flightMasterOfRow_arr {f : FlightMasterRow} {x : FlightMaster} (h : flightMasterOfRow f = some x) :
    arrOfStr f.arrivalTime.val = some x.arrivalTime := by
  simp only [flightMasterOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, _, _, ar, har, rfl⟩ := h
  exact har

/-- 空港コードの行があれば、[Spec] の空港名は、`apOf` の行の空港名。 -/
theorem airportName_eq {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md)
    (hnd : (db.airport.map (·.airportCd.val)).Nodup) {c : String} (h : ∃ a ∈ db.airport, a.airportCd.val = c) :
    Spec.FlightSearch.airportName? md ⟨c⟩ = some (apOf db c).airportName.val := by
  obtain ⟨ha, -⟩ := masterDataOf_eq_some.mp hm
  have hat := apOf_at h
  have hfind : db.airport.find? (fun a => a.airportCd.val == c) = some (apOf db c) := by
    have := filter_airport hnd hat
    cases hf : db.airport.find? (fun a => a.airportCd.val == c) with
    | none =>
      rw [List.find?_eq_none] at hf
      exact absurd (by simpa using hat.2) (hf _ hat.1)
    | some a =>
      have ha' := List.mem_of_find?_eq_some hf
      have hc := List.find?_some hf
      simp only [beq_iff_eq] at hc
      rw [inj_of_nodup_map hnd ha' hat.1 (by rw [hc, hat.2])]
  unfold Spec.FlightSearch.airportName?
  rw [find?_mapM ha (p := fun a => a.airportCd.val == c) fun r x h => by
    rw [airportOfRow_code h, Bool.eq_iff_iff]; simp [AirportCd.mk.injEq], hfind]
  obtain ⟨x, -, hx⟩ := mapM_some_mem ha hat.1
  simp only [Option.bind_some, hx, Option.map_some]
  simp only [airportOfRow, Option.map_eq_some_iff] at hx
  obtain ⟨_, _, rfl⟩ := hx
  rfl

/-- 便マスタのキャッシュの答え（空席照会が使う成分）: 便名・出発時刻・到着時刻と、区間の出発・到着の空港名。 -/
theorem flightMaster_full {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h3 : md.MD3) (h8 : md.MD8) {o : List FlightMasterResult} (hp : o.Perm (FlightRepository.findAllFlightMaster db)) :
    ∃ fmp, FlightMasterProvider.load o = .ok fmp ∧ ∀ name : FlightName, hasText name.val = true →
      ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
      ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster fmp name.val = .ok (some fm) ∧ fm.flightName = some name.val ∧
        fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧ fm.arrivalTime = some art ∧
        arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧ r.departureAirport = some da ∧
        da.name = Spec.FlightSearch.airportName? md rt.depAirportCd ∧ r.arrivalAirport = some aa ∧
        aa.name = Spec.FlightSearch.airportName? md rt.arrAirportCd := by
  obtain ⟨ha, hrts, hfm, -⟩ := masterDataOf_eq_some.mp hm
  have hapnd := airportCodes_nodup ha h1.1
  have hrnd := routeNos_nodup hrts h1.2.1
  have hat : ∀ r ∈ db.route, AirportAt db (apOf db) r.depAirportCd.val ∧ AirportAt db (apOf db) r.arrAirportCd.val :=
    fun r hr => ⟨apOf_at (route_airport hm h3 h8 hr).1, apOf_at (route_airport hm h3 h8 hr).2.1⟩
  have hrt : ∀ f ∈ db.flightMaster, RouteAt db (rtOf db) f.routeNo.val :=
    fun f hf => rtOf_at (flightMaster_route hm h3 hf)
  rw [flightMasterFindAll_eq hapnd hrnd hat hrt] at hp
  have hnames : (db.flightMaster.map (·.flightName.val)).Nodup := by
    have e : md.flightMasters.map (·.flightName) = db.flightMaster.map fun f => (⟨f.flightName.val⟩ : FlightName) :=
      mapM_some_map hfm fun _ _ h => (flightMasterOfRow_fields h).2
    have := h1.2.2.1
    rw [e] at this
    exact nodup_map_of_imp this fun _ _ _ _ e => by simp only [e]
  have hnd : (o.map (·.flightName.val)).Nodup :=
    (hp.map _).nodup_iff.mpr (by rw [List.map_map]; exact hnames)
  refine ⟨_, flightMasterLoad_eq hnd, fun name hname X hX rt hrt' => ?_⟩
  have hget : FlightMasterProvider.getFlightMaster (⟨JHashMap.ofList (o.map fun f =>
      (f.flightName.val, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap f))⟩ : FlightMasterProvider) name.val =
      .ok ((JHashMap.ofList (o.map fun f =>
        (f.flightName.val, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap f))).get name.val) := by
    simp only [FlightMasterProvider.getFlightMaster, assertHasText_ok hname]; rfl
  rw [JHashMap.get_ofList_perm hp (key := fun f : FlightMasterResult => f.flightName.val) hnames] at hget
  rw [show (fun r : FlightMasterRow => (flightMasterResultOf r (rtOf db r.routeNo.val)
      (apOf db (rtOf db r.routeNo.val).depAirportCd.val) (apOf db (rtOf db r.routeNo.val).arrAirportCd.val)).flightName.val
      == name.val) = (fun f => f.flightName.val == name.val) from rfl] at hget
  have hspec : md.flightMasterOf name =
      (db.flightMaster.find? fun f => f.flightName.val == name.val).bind flightMasterOfRow := by
    unfold MasterData.flightMasterOf
    rw [find?_mapM hfm (p := fun f => f.flightName.val == name.val) fun _ _ h => by
      rw [(flightMasterOfRow_fields h).2, Bool.eq_iff_iff]; cases name; simp [FlightName.mk.injEq]]
  rw [hspec] at hX
  cases hf : db.flightMaster.find? (fun f => f.flightName.val == name.val) with
  | none => simp [hf] at hX
  | some f =>
    rw [hf, Option.bind_some] at hX
    rw [hf] at hget
    have hfr := List.mem_of_find?_eq_some hf
    have hfn := List.find?_some hf
    simp only [beq_iff_eq] at hfn
    have hxno := (flightMasterOfRow_fields hX).1
    rw [find?_mapM hrts (p := fun r => r.routeNo.val == f.routeNo.val) fun a b h => by
      rw [Bool.eq_iff_iff]; simp only [beq_iff_eq]; have := Abstraction.FlightSearch.Candidates.routeOfRow_no h; omega] at hrt'
    cases hr0 : db.route.find? (fun r => r.routeNo.val == f.routeNo.val) with
    | none => simp [hr0] at hrt'
    | some r0 =>
      rw [hr0, Option.bind_some] at hrt'
      have hrt0 : rtOf db f.routeNo.val = r0 := by simp only [rtOf, hr0, Option.getD_some]
      have hr0m := List.mem_of_find?_eq_some hr0
      obtain ⟨hd, ha'⟩ := routeOfRow_codes hrt'
      obtain ⟨hda, haa, -⟩ := route_airport hm h3 h8 hr0m
      refine ⟨_, _, _, _, _, _, by rw [hget]; rfl, ?_, rfl, ?_, rfl, ?_, rfl, rfl, ?_, rfl, ?_⟩
      · simp only [Function.comp, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap, flightMasterResultOf,
          SourceModel.Db.MyBatis.str, hfn]
      · exact Abstraction.FlightSearch.Candidates.flightMasterOfRow_dep hX
      · exact flightMasterOfRow_arr hX
      · rw [hd, airportName_eq hm hapnd hda]
        simp only [flightMasterResultOf, routeResultOf, SourceModel.Db.MyBatis.str, hrt0]
      · rw [ha', airportName_eq hm hapnd haa]
        simp only [flightMasterResultOf, routeResultOf, SourceModel.Db.MyBatis.str, hrt0]

/-- 運賃種別のキャッシュの答えから、コード・名前・割引率を取り出す。 -/
theorem fareType_of_answer' {r : JRef SourceModel.Domain.Model.FareType} {ft : FareType}
    (h : answerOf? (.fareType r) = some (.fareType (some ft.info))) :
    ∃ f d, r = some f ∧ f.fareTypeCd = some ft.fareTypeCd ∧ f.fareTypeName = some ft.fareTypeName ∧
      f.discountRate = some d ∧ d.val = (ft.discountRate : Int) := by
  cases r with
  | none => simp [answerOf?, AnswerOf.opt] at h
  | some f =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, Spec.MasterQuery.Answer.fareType.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [AnswerOf.fareType, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, hc0, nm, hn0, dr, hdr, s0, hs0, e0, he0, pm0, hp0, he⟩ := hx
    obtain ⟨d, hd1, hd2⟩ := hdr
    rw [natOfJ32_eq_some] at hd2
    simp only [FareType.info, MasterData.FareTypeInfo.mk.injEq] at he
    obtain ⟨rfl, rfl, rfl, -⟩ := he
    exact ⟨f, d, rfl, hc0, hn0, hd1, hd2⟩

/-- 空席照会が使う読み込みの性質: 区間・運賃種別・搭乗クラス・便マスタのキャッシュの答えと、積算比率の Provider。 -/
theorem load_fs {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {o : Order} (ho : o.Allowed db) :
    ∃ p, load o = .ok p ∧ p.peakTime = PeakTimeProvider.load o.peakTime ∧
      (∀ dep arr : AirportCd, hasText dep.val = true → hasText arr.val = true →
        ∃ ans, RouteProvider.getRouteByAirportCd p.route dep.val arr.val = .ok ans ∧
          answerOf? (.route ans) = some (.route (md.routeOf dep arr))) ∧
      (∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((md.boardingClassOf cd).map (·.info)))) ∧
      (∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeCodeMap.get cd)) =
        some (.fareType ((md.fareTypeOf cd).map (·.info)))) ∧
      (∀ name : FlightName, hasText name.val = true →
        ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
        ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok (some fm) ∧ fm.flightName = some name.val ∧
          fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧ fm.arrivalTime = some art ∧
          arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧ r.departureAirport = some da ∧
          da.name = Spec.FlightSearch.airportName? md rt.depAirportCd ∧ r.arrivalAirport = some aa ∧
          aa.name = Spec.FlightSearch.airportName? md rt.arrAirportCd) := by
  obtain ⟨-, -, -, hbcs, hfts, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨hpr, hpf, hpb, hpft, -, -, -, -, -⟩ := ho
  obtain ⟨bcp, hbl, hbq⟩ := boardingClass_query hbcs hv.md1.2.2.2.1 hpb
  obtain ⟨ftp, hfl, hfq⟩ := fareType_query hfts hv.md1.2.2.2.2.1 hpft
  obtain ⟨rtp, hrl, hrq⟩ := route_query hm hv.md1 hv.md2 hv.md3 hv.md8 hpr
  obtain ⟨fmp, hml, hmf⟩ := flightMaster_full hm hv.md1 hv.md3 hv.md8 hpf
  exact ⟨_, by simp only [load, hbl, hfl, hrl, hml, ok_bind]; rfl, rfl, hrq, fun cd => hbq cd, fun cd => hfq cd, hmf⟩

end Abstraction.FlightSearch.Providers
