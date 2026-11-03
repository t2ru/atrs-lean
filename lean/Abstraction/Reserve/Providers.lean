import Abstraction.FlightSearch.Providers

/-!
# Abstraction.Reserve.Providers

予約が使う便マスタの Provider の答え（backlog aedf の第 3 段）。空席照会の `Abstraction.FlightSearch.Providers.flightMaster_full`
と同じ前提で、便マスタの区間の空港コード（往復の逆区間の検査）と、便マスタが無い場合の答え（`null`）を示す。
-/

namespace Abstraction.Reserve.Providers
open Abstraction.World.Alpha Abstraction.FlightSearch.Providers
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

/-- 便マスタの Provider の答えの、区間の空港コード。 -/
theorem flightMaster_codes {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h3 : md.MD3) (h8 : md.MD8) {o : List FlightMasterResult} (hp : o.Perm (FlightRepository.findAllFlightMaster db)) :
    ∃ fmp, FlightMasterProvider.load o = .ok fmp ∧ ∀ name : FlightName, hasText name.val = true →
      ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
      ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster fmp name.val = .ok (some fm) ∧ fm.flightName = some name.val ∧
        fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧ fm.arrivalTime = some art ∧
        arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧ r.departureAirport = some da ∧
        da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
        aa.code = some rt.arrAirportCd.val := by
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
      · rw [hd]
        simp only [flightMasterResultOf, routeResultOf, SourceModel.Db.MyBatis.str, hrt0]
        exact congrArg some (apOf_at hda).2
      · rw [ha']
        simp only [flightMasterResultOf, routeResultOf, SourceModel.Db.MyBatis.str, hrt0]
        exact congrArg some (apOf_at haa).2

/-- 便マスタが無い便名の Provider の答えは `null`。 -/
theorem flightMaster_none {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h3 : md.MD3) (h8 : md.MD8) {o : List FlightMasterResult} (hp : o.Perm (FlightRepository.findAllFlightMaster db)) :
    ∃ fmp, FlightMasterProvider.load o = .ok fmp ∧ ∀ name : FlightName, hasText name.val = true →
      md.flightMasterOf name = none → FlightMasterProvider.getFlightMaster fmp name.val = .ok none := by
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
  refine ⟨_, flightMasterLoad_eq hnd, fun name hname hX => ?_⟩
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
  | none => rw [hget, hf]; rfl
  | some f =>
    rw [hf, Option.bind_some] at hX
    obtain ⟨_, -, e⟩ := mapM_some_mem hfm (List.mem_of_find?_eq_some hf)
    rw [hX] at e
    cases e

/-- 予約が使う読み込みの性質: 搭乗クラス・運賃種別のキャッシュの答えと、便マスタの Provider の答え（無い場合は `null`、
ある場合は便名・時刻・区間の空港コード）。 -/
theorem load_res {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {o : Order} (ho : o.Allowed db) :
    ∃ p, load o = .ok p ∧
      (∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((md.boardingClassOf cd).map (·.info)))) ∧
      (∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
        some (.fareType ((md.fareTypeOf cd).map (·.info)))) ∧
      (∀ name : FlightName, hasText name.val = true → md.flightMasterOf name = none →
        FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok none) ∧
      (∀ name : FlightName, hasText name.val = true →
        ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
        ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok (some fm) ∧
          fm.flightName = some name.val ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
          fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
          r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
          aa.code = some rt.arrAirportCd.val) := by
  obtain ⟨-, -, -, hbcs, hfts, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨hpr, hpf, hpb, hpft, -, -, -, -, -⟩ := ho
  obtain ⟨bcp, hbl, hbq⟩ := boardingClass_query hbcs hv.md1.2.2.2.1 hpb
  obtain ⟨ftp, hfl, hfq⟩ := fareType_query hfts hv.md1.2.2.2.2.1 hpft
  obtain ⟨rtp, hrl, -⟩ := route_query hm hv.md1 hv.md2 hv.md3 hv.md8 hpr
  obtain ⟨fmp, hml, hmc⟩ := flightMaster_codes hm hv.md1 hv.md3 hv.md8 hpf
  obtain ⟨fmp', hml', hmn⟩ := flightMaster_none hm hv.md1 hv.md3 hv.md8 hpf
  rw [hml] at hml'
  cases hml'
  exact ⟨_, by simp only [load, hbl, hfl, hrl, hml, ok_bind]; rfl, fun cd => hbq cd, fun cd => hfq cd, hmn, hmc⟩

end Abstraction.Reserve.Providers
