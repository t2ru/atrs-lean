import Abstraction.MasterData.Lookup
import Abstraction.MasterData.Join
import Abstraction.MasterData.Key
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Domain.Common.Util.FareUtil
import SourceModel.Domain.Service.B2.TicketReserveServiceImpl
import LangSemantics.Sql.QueryLemmas

/-!
# Abstraction.MasterData.Query

ABS-026 の問い合わせごとの一致。DB の表の写し（`mapM` の行の葉）と MD-1〜MD-8 の下で、各 Provider の `load()` は
例外を投げず、Mapper の結果のどの許される並びでも、参照の答えの写し（`answerOf?`）は [Spec] の答えに等しい。
-/

namespace Abstraction.MasterData.Query
open Spec.MasterData (Airport Route FlightMaster
  BoardingClass FareType PeakTime Plane
  CreditType BoardingClassInfo FareTypeInfo)
open Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.CodeList Abstraction.MasterData.Join
  Abstraction.MasterData.Key Abstraction.MasterData.Load Abstraction.MasterData.Lookup Abstraction.MasterData.Pre
  Spec.CodeList Spec.Model Spec.Prim.Text
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.Exception LangSemantics.Java.HashMap
  LangSemantics.Java.ResultLemmas LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas Machine.Kernel

open LangSemantics.Java Spec Spec.Prim LangSemantics.Core
  SourceModel.Db.Schema SourceModel.Domain.Repository.Route SourceModel.Domain.Repository.Route.RouteRepository SourceModel.Domain.Repository.Flight
  SourceModel.Domain.Repository.Flight.FlightRepository SourceModel.Domain.Repository.Boardingclass SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository SourceModel.Domain.Repository.Faretype
  SourceModel.Domain.Repository.Faretype.FareTypeRepository SourceModel.Domain.Repository.Peaktime SourceModel.Domain.Repository.Peaktime.PeakTimeRepository SourceModel.Config.App
  SourceModel.Config.App.AtrsCodeListConfig SourceModel.Domain.Common.Masterdata SourceModel.MasterQuery

/-! ## 搭乗クラス -/

/-- `BoardingClassRepository.findAll` の射影。 -/
def projBC (b : BoardingClassRow) : BoardingClassResult := ⟨b.boardingClassCd, b.boardingClassName, b.extraCharge⟩

/-- キャッシュのキー（コードが列挙型の値なら、その値）。 -/
def keyBC (b : BoardingClassResult) : BoardingClassCd := (bcCdOf b.boardingClassCd.val).getD .N

theorem boardingClassOfRow_code {r : BoardingClassRow} {x : BoardingClass} (h : boardingClassOfRow r = some x) :
    bcCdOf r.boardingClassCd.val = some x.boardingClassCd := by
  simp only [boardingClassOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, hcd, _, _, _, _, _, _, rfl⟩ := h
  exact hcd

theorem keyBC_proj {r : BoardingClassRow} {x : BoardingClass} (h : boardingClassOfRow r = some x) :
    keyBC (projBC r) = x.boardingClassCd := by
  simp only [keyBC, projBC, boardingClassOfRow_code h, Option.getD_some]

theorem answer_boardingClassOf {r : BoardingClassRow} {x : BoardingClass} (h : boardingClassOfRow r = some x) :
    AnswerOf.boardingClass (boardingClassOf (projBC r) x.boardingClassCd) = some x.info := by
  simp only [boardingClassOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, _, nm, hnm, ex, hex, d, _, rfl⟩ := h
  simp only [AnswerOf.boardingClass, boardingClassOf, projBC, hnm, Option.map_some, natOfJ32_int, hex,
    Option.bind_eq_bind, Option.bind_some, Option.pure_def, BoardingClass.info]

theorem boardingClass_query {db : MasterDb} {bcs : List BoardingClass}
    (hm : db.boardingClass.mapM boardingClassOfRow = some bcs) (hnd : (bcs.map (·.boardingClassCd)).Nodup)
    {o : List BoardingClassResult} (hp : o.Perm (BoardingClassRepository.findAll db)) :
    ∃ bcp, BoardingClassProvider.load o = .ok bcp ∧ ∀ cd : BoardingClassCd,
      answerOf? (.boardingClass (bcp.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((bcs.find? fun b => b.boardingClassCd == cd).map (·.info))) := by
  have hp' : o.Perm (db.boardingClass.map projBC) := hp
  have hk : ∀ b ∈ o, SourceModel.Domain.Model.BoardingClassCd.valueOf b.boardingClassCd.val = .ok (keyBC b) := by
    intro b hb
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp (hp'.mem_iff.mp hb)
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm hr
    rw [keyBC_proj hx]
    exact bcCdOf_mapping (boardingClassOfRow_code hx)
  refine ⟨_, boardingClassLoad_eq o keyBC hk, fun cd => ?_⟩
  have hkeys : db.boardingClass.map (keyBC ∘ projBC) = bcs.map (·.boardingClassCd) :=
    (mapM_some_map hm fun _ _ h => (keyBC_proj h).symm).symm
  rw [JHashMap.get_ofList_perm hp' (hkeys ▸ hnd) cd,
    find?_mapM hm (p := fun r => keyBC (projBC r) == cd) fun _ _ h => by simp only [keyBC_proj h]]
  cases hf : db.boardingClass.find? (fun r => keyBC (projBC r) == cd) with
  | none => rfl
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm (List.mem_of_find?_eq_some hf)
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, keyBC_proj hx, answerOf?, AnswerOf.opt,
      answer_boardingClassOf hx]

/-! ## 運賃種別 -/

/-- `FareTypeRepository.findAll` の射影。 -/
def projFT (f : FareTypeRow) : FareTypeResult :=
  ⟨f.fareTypeCd, f.fareTypeName, f.discountRate, f.rsrvAvailableStartDayNum, f.rsrvAvailableEndDayNum,
    f.passengerMinNum⟩

/-- キャッシュのキー。 -/
def keyFT (f : FareTypeResult) : FareTypeCd := (ftCdOf f.fareTypeCd.val).getD .OW

theorem fareTypeOfRow_code {r : FareTypeRow} {x : FareType} (h : fareTypeOfRow r = some x) :
    ftCdOf r.fareTypeCd.val = some x.fareTypeCd := by
  simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, hcd, _, _, _, _, _, _, _, _, _, _, rfl⟩ := h
  exact hcd

theorem keyFT_proj {r : FareTypeRow} {x : FareType} (h : fareTypeOfRow r = some x) :
    keyFT (projFT r) = x.fareTypeCd := by
  simp only [keyFT, projFT, fareTypeOfRow_code h, Option.getD_some]

theorem answer_fareTypeOf {r : FareTypeRow} {x : FareType} (h : fareTypeOfRow r = some x) :
    AnswerOf.fareType (fareTypeOf (projFT r) x.fareTypeCd) = some x.info := by
  simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, _, dr, hdr, st, hst, en, hen, pm, hpm, d, _, rfl⟩ := h
  simp only [AnswerOf.fareType, fareTypeOf, projFT, SourceModel.Db.MyBatis.str, natOfJ32_int, hdr, hst, hen,
    hpm, Option.bind_eq_bind, Option.bind_some, Option.pure_def, FareType.info]

theorem fareType_query {db : MasterDb} {fts : List FareType}
    (hm : db.fareType.mapM fareTypeOfRow = some fts) (hnd : (fts.map (·.fareTypeCd)).Nodup)
    {o : List FareTypeResult} (hp : o.Perm (FareTypeRepository.findAll db)) :
    ∃ ftp, FareTypeProvider.load o = .ok ftp ∧ ∀ cd : FareTypeCd,
      answerOf? (.fareType (ftp.fareTypeMap.get cd)) =
        some (.fareType ((fts.find? fun f => f.fareTypeCd == cd).map (·.info))) := by
  have hp' : o.Perm (db.fareType.map projFT) := hp
  have hk : ∀ f ∈ o, SourceModel.Domain.Model.FareTypeCd.valueOf f.fareTypeCd.val = .ok (keyFT f) := by
    intro f hf
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp (hp'.mem_iff.mp hf)
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm hr
    rw [keyFT_proj hx]
    exact ftCdOf_mapping (fareTypeOfRow_code hx)
  refine ⟨_, fareTypeLoad_eq o keyFT hk, fun cd => ?_⟩
  have hkeys : db.fareType.map (keyFT ∘ projFT) = fts.map (·.fareTypeCd) :=
    (mapM_some_map hm fun _ _ h => (keyFT_proj h).symm).symm
  rw [JHashMap.get_ofList_perm hp' (hkeys ▸ hnd) cd,
    find?_mapM hm (p := fun r => keyFT (projFT r) == cd) fun _ _ h => by simp only [keyFT_proj h]]
  cases hf : db.fareType.find? (fun r => keyFT (projFT r) == cd) with
  | none => rfl
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm (List.mem_of_find?_eq_some hf)
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, keyFT_proj hx, answerOf?, AnswerOf.opt,
      answer_fareTypeOf hx]

/-! ## 空港と区間（DB の側の事実） -/

/-- 既定の空港の行（`find?` が見つけないときの値。使われない）。 -/
def dummyAirport : AirportRow := ⟨⟨"", by decide⟩, ⟨"", by decide⟩, ⟨0, by decide⟩⟩

/-- 空港コードで引いた空港の行。 -/
def apOf (db : MasterDb) (c : String) : AirportRow :=
  (db.airport.find? fun a => a.airportCd.val == c).getD dummyAirport

theorem apOf_at {db : MasterDb} {c : String} (h : ∃ a ∈ db.airport, a.airportCd.val = c) :
    AirportAt db (apOf db) c := by
  obtain ⟨a, ha, hc⟩ := h
  cases hf : db.airport.find? (fun a => a.airportCd.val == c) with
  | none =>
    rw [List.find?_eq_none] at hf
    exact absurd (by simpa using hc) (hf a ha)
  | some a' =>
    have := List.find?_some hf
    simp only [beq_iff_eq] at this
    exact ⟨by simp only [apOf, hf, Option.getD_some]; exact List.mem_of_find?_eq_some hf,
      by simp only [apOf, hf, Option.getD_some, this]⟩

theorem airportOfRow_code {r : AirportRow} {a : Airport} (h : airportOfRow r = some a) :
    a.code.val = r.airportCd.val := (airportOfRow_eq_some h).1

theorem routeOfRow_codes {r : RouteRow} {x : Route} (h : routeOfRow r = some x) :
    x.depAirportCd.val = r.depAirportCd.val ∧ x.arrAirportCd.val = r.arrAirportCd.val := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, _, hd, _, ha, _, _, rfl⟩ := h
  exact ⟨AirportCd.val_of_ofString? hd, AirportCd.val_of_ofString? ha⟩

/-- MD-1: 空港コードは DB の表の中で重複しない。 -/
theorem airportCodes_nodup {db : MasterDb} {as : List Airport} (ha : db.airport.mapM airportOfRow = some as)
    (hnd : (as.map (·.code)).Nodup) : (db.airport.map (·.airportCd.val)).Nodup := by
  have hnd' : (as.map (·.code.val)).Nodup := nodup_map_of_imp hnd fun _ _ _ _ e => AirportCd.ext e
  rwa [mapM_some_map ha (g := fun r => r.airportCd.val) fun _ _ h => airportOfRow_code h] at hnd'

/-- MD-3: 区間の空港は DB の空港の表にあり、そのコードは空港コードの形式（`AirportCd.valid`）を満たす
（α が定義されるので、行のコードは [Spec] の空港コードとして読めた）。 -/
theorem route_airport {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h3 : md.MD3)
    {r : RouteRow} (hr : r ∈ db.route) :
    (∃ a ∈ db.airport, a.airportCd.val = r.depAirportCd.val) ∧ (∃ a ∈ db.airport, a.airportCd.val = r.arrAirportCd.val) ∧
      AirportCd.valid r.depAirportCd.val = true ∧ AirportCd.valid r.arrAirportCd.val = true := by
  obtain ⟨ha, hrt, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨x, hx, hxr⟩ := mapM_some_mem hrt hr
  obtain ⟨hdep, harr⟩ := routeOfRow_codes hxr
  obtain ⟨⟨a, ham, hac⟩, ⟨b, hbm, hbc⟩⟩ := h3.1 x hx
  obtain ⟨ar, har, hae⟩ := mapM_some_mem' ha ham
  obtain ⟨br, hbr, hbe⟩ := mapM_some_mem' ha hbm
  have e1 := airportOfRow_code hae
  have e2 := airportOfRow_code hbe
  refine ⟨⟨ar, har, ?_⟩, ⟨br, hbr, ?_⟩, ?_, ?_⟩
  · rw [← e1, hac, hdep]
  · rw [← e2, hbc, harr]
  · rw [← hdep]; exact x.depAirportCd.wf
  · rw [← harr]; exact x.arrAirportCd.wf

/-! ## 区間 -/

theorem answer_route {db : MasterDb} {r : RouteRow} {x : Route} (h : routeOfRow r = some x)
    (hd : AirportAt db (apOf db) r.depAirportCd.val) (ha : AirportAt db (apOf db) r.arrAirportCd.val) :
    AnswerOf.route (SourceModel.Domain.Repository.Route.RouteRepository.routeMap
      (routeResultOf r (apOf db r.depAirportCd.val) (apOf db r.arrAirportCd.val))) = some x := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨no, hno, dep, hdep, arr, harr, bf, hbf, rfl⟩ := h
  simp only [AnswerOf.route, SourceModel.Domain.Repository.Route.RouteRepository.routeMap, routeResultOf, SourceModel.Db.MyBatis.str,
    natOfJ32_int, hno, hbf, hd.2, ha.2, Option.bind_eq_bind, Option.bind_some, Option.pure_def, hdep, harr]

theorem route_query {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h2 : md.MD2) (h3 : md.MD3) {o : List RouteResult} (hp : o.Perm (RouteRepository.findAll db)) :
    ∃ rtp, RouteProvider.load o = .ok rtp ∧ ∀ dep arr : String, hasText dep = true → hasText arr = true →
      ∃ ans, RouteProvider.getRouteByAirportCd rtp dep arr = .ok ans ∧
      answerOf? (.route ans) = some (.route (md.routeOf dep arr)) := by
  obtain ⟨ha, hrt, -⟩ := masterDataOf_eq_some.mp hm
  have hapnd := airportCodes_nodup ha h1.1
  have hat : ∀ r ∈ db.route, AirportAt db (apOf db) r.depAirportCd.val ∧ AirportAt db (apOf db) r.arrAirportCd.val :=
    fun r hr => ⟨apOf_at (route_airport hm h3 hr).1, apOf_at (route_airport hm h3 hr).2.1⟩
  rw [routeFindAll_eq hapnd hat] at hp
  refine ⟨_, routeLoad_eq o, fun dep arr hdep harr => ?_⟩
  refine ⟨(JHashMap.ofList (o.map fun r =>
    (RouteProvider.makeCacheKey r.depAirportCd.val r.aarAirportCd.val, SourceModel.Domain.Repository.Route.RouteRepository.routeMap r))).get
      (RouteProvider.makeCacheKey dep arr), ?_, ?_⟩
  · simp only [RouteProvider.getRouteByAirportCd, assertHasText_ok hdep, assertHasText_ok harr]
    rfl
  let key : RouteResult → String := fun res => RouteProvider.makeCacheKey res.depAirportCd.val res.aarAirportCd.val
  let projR : RouteRow → RouteResult := fun r =>
    routeResultOf r (apOf db r.depAirportCd.val) (apOf db r.arrAirportCd.val)
  have hkey : ∀ r ∈ db.route, key (projR r) = RouteProvider.makeCacheKey r.depAirportCd.val r.arrAirportCd.val := by
    intro r hr
    simp only [key, projR, routeResultOf, (hat r hr).1.2, (hat r hr).2.2]
  have hpairs : (db.route.map fun r => (r.depAirportCd.val, r.arrAirportCd.val)).Nodup := by
    rw [← mapM_some_map hrt (k := fun x : Route => (x.depAirportCd.val, x.arrAirportCd.val)) fun _ _ h => by
      rw [(routeOfRow_codes h).1, (routeOfRow_codes h).2]]
    refine nodup_map_of_imp h2.1 fun a _ b _ e => ?_
    simp only [Prod.mk.injEq] at e ⊢
    exact ⟨AirportCd.ext e.1, AirportCd.ext e.2⟩
  have hnd : (db.route.map (key ∘ projR)).Nodup := by
    refine nodup_map_of_imp hpairs fun a ha b hb e => ?_
    simp only [Function.comp, hkey a ha, hkey b hb] at e
    obtain ⟨e1, e2⟩ := makeCacheKey_inj (AirportCd.no_dash_of_valid (route_airport hm h3 ha).2.2.1)
      (AirportCd.no_dash_of_valid (route_airport hm h3 hb).2.2.1) e
    have e1' : a.depAirportCd.val = b.depAirportCd.val := e1
    simp only [e1', e2]
  show answerOf? (.route ((JHashMap.ofList (o.map fun b => (key b, SourceModel.Domain.Repository.Route.RouteRepository.routeMap b))).get
    (RouteProvider.makeCacheKey dep arr))) = _
  rw [JHashMap.get_ofList_perm hp hnd]
  have hspec : md.routeOf dep arr =
      (db.route.find? fun r => key (projR r) == RouteProvider.makeCacheKey dep arr).bind routeOfRow := by
    unfold MasterData.routeOf
    rw [find?_mapM hrt (p := fun r => r.depAirportCd.val == dep && r.arrAirportCd.val == arr)
      fun _ _ h => by rw [(routeOfRow_codes h).1, (routeOfRow_codes h).2]]
    congr 1
    refine find?_congr fun r hr => ?_
    rw [hkey r hr]
    have nd := AirportCd.no_dash_of_valid (route_airport hm h3 hr).2.2.1
    have nda := AirportCd.no_dash_of_valid (route_airport hm h3 hr).2.2.2
    rw [Bool.eq_iff_iff]
    simp only [Bool.and_eq_true, beq_iff_eq]
    constructor
    · rintro ⟨rfl, rfl⟩; rfl
    · intro e
      obtain ⟨e1, e2⟩ := makeCacheKey_inj' nd nda e
      exact ⟨e1, e2⟩
  rw [hspec]
  cases hf : db.route.find? (fun r => key (projR r) == RouteProvider.makeCacheKey dep arr) with
  | none => rfl
  | some r =>
    have hr := List.mem_of_find?_eq_some hf
    obtain ⟨x, _, hx⟩ := mapM_some_mem hrt hr
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, answerOf?, AnswerOf.opt,
      answer_route hx (hat r hr).1 (hat r hr).2]

/-! ## 便マスタ -/

/-- 既定の区間の行（使われない）。 -/
def dummyRoute : RouteRow := ⟨⟨0, by decide⟩, ⟨"", by decide⟩, ⟨"", by decide⟩, ⟨"", by decide⟩, ⟨0, by decide⟩⟩

/-- 区間番号で引いた区間の行。 -/
def rtOf (db : MasterDb) (n : Int) : RouteRow := (db.route.find? fun r => r.routeNo.val == n).getD dummyRoute

theorem rtOf_at {db : MasterDb} {n : Int} (h : ∃ r ∈ db.route, r.routeNo.val = n) : RouteAt db (rtOf db) n := by
  obtain ⟨r, hr, hn⟩ := h
  cases hf : db.route.find? (fun r => r.routeNo.val == n) with
  | none =>
    rw [List.find?_eq_none] at hf
    exact absurd (by simpa using hn) (hf r hr)
  | some r' =>
    have := List.find?_some hf
    simp only [beq_iff_eq] at this
    exact ⟨by simp only [rtOf, hf, Option.getD_some]; exact List.mem_of_find?_eq_some hf,
      by simp only [rtOf, hf, Option.getD_some, this]⟩

theorem routeOfRow_no {r : RouteRow} {x : Route} (h : routeOfRow r = some x) : (x.routeNo : Int) = r.routeNo.val := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨no, hno, _, _, _, _, _, _, rfl⟩ := h
  exact (natOfInt4_eq_some.mp hno).symm

theorem flightMasterOfRow_fields {f : FlightMasterRow} {x : FlightMaster} (h : flightMasterOfRow f = some x) :
    (x.routeNo : Int) = f.routeNo.val ∧ x.flightName.val = f.flightName.val := by
  simp only [flightMasterOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨n, hn, no, hno, _, _, _, _, rfl⟩ := h
  exact ⟨(natOfInt4_eq_some.mp hno).symm, flightNameOf_eq_some hn⟩

/-- MD-1: 便名は DB の表の中で重複しない。 -/
theorem flightMasterNames_nodup {db : MasterDb} {fms : List FlightMaster}
    (hfm : db.flightMaster.mapM flightMasterOfRow = some fms) (hnd : (fms.map (·.flightName)).Nodup) :
    (db.flightMaster.map (·.flightName.val)).Nodup := by
  have e : fms.map (·.flightName.val) = db.flightMaster.map (·.flightName.val) :=
    mapM_some_map hfm fun _ _ h => (flightMasterOfRow_fields h).2
  rw [← e]
  exact nodup_map_of_imp hnd fun _ _ _ _ e => FlightName.ext e

/-- [Spec] の便マスタの参照は、DB の表を便名で探した行の α。 -/
theorem flightMasterOf_db {db : MasterDb} {md : MasterData}
    (hfm : db.flightMaster.mapM flightMasterOfRow = some md.flightMasters) (name : String) :
    md.flightMasterOf name = (db.flightMaster.find? fun f => f.flightName.val == name).bind flightMasterOfRow := by
  unfold MasterData.flightMasterOf
  rw [find?_mapM hfm (p := fun f => f.flightName.val == name) fun _ _ h => by rw [(flightMasterOfRow_fields h).2]]

/-- MD-1: 区間番号は DB の表の中で重複しない。 -/
theorem routeNos_nodup {db : MasterDb} {rs : List Route} (hr : db.route.mapM routeOfRow = some rs)
    (hnd : (rs.map (·.routeNo)).Nodup) : (db.route.map (·.routeNo.val)).Nodup := by
  have e : rs.map (fun x => (x.routeNo : Int)) = db.route.map (·.routeNo.val) :=
    mapM_some_map hr fun _ _ h => routeOfRow_no h
  rw [← e]
  exact nodup_map_of_imp hnd fun _ _ _ _ e => by omega

/-- MD-3: 便マスタの区間は DB の区間の表にある。 -/
theorem flightMaster_route {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h3 : md.MD3)
    {f : FlightMasterRow} (hf : f ∈ db.flightMaster) : ∃ r ∈ db.route, r.routeNo.val = f.routeNo.val := by
  obtain ⟨_, hrt, hfm, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨x, hx, hxf⟩ := mapM_some_mem hfm hf
  obtain ⟨y, hy, hyx⟩ := h3.2 x hx
  obtain ⟨rr, hrr, hre⟩ := mapM_some_mem' hrt hy
  exact ⟨rr, hrr, by rw [← routeOfRow_no hre, hyx, (flightMasterOfRow_fields hxf).1]⟩

theorem answer_flightMaster {db : MasterDb} {f : FlightMasterRow} {x : FlightMaster} (h : flightMasterOfRow f = some x)
    (hrt : RouteAt db (rtOf db) f.routeNo.val) :
    AnswerOf.flightMaster (SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap (flightMasterResultOf f (rtOf db f.routeNo.val)
      (apOf db (rtOf db f.routeNo.val).depAirportCd.val) (apOf db (rtOf db f.routeNo.val).arrAirportCd.val))) =
      some x := by
  have hno : (rtOf db f.routeNo.val).routeNo = f.routeNo := Subtype.ext hrt.2
  simp only [flightMasterOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨nm, hnm, no, hn, dt, hdt, ar, har, rfl⟩ := h
  simp only [AnswerOf.flightMaster, hnm, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap, SourceModel.Domain.Repository.Route.RouteRepository.routeMap,
    flightMasterResultOf, routeResultOf, SourceModel.Db.MyBatis.str, hno, natOfJ32_int, hn, hdt, har,
    Option.bind_eq_bind, Option.bind_some, Option.pure_def]

theorem flightMaster_query {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h3 : md.MD3) {o : List FlightMasterResult} (hp : o.Perm (FlightRepository.findAllFlightMaster db)) :
    ∃ fmp, FlightMasterProvider.load o = .ok fmp ∧ ∀ name : String, hasText name = true →
      ∃ ans, FlightMasterProvider.getFlightMaster fmp name = .ok ans ∧
      answerOf? (.flightMaster ans) = some (.flightMaster (md.flightMasterOf name)) := by
  obtain ⟨ha, hrts, hfm, -⟩ := masterDataOf_eq_some.mp hm
  have hapnd := airportCodes_nodup ha h1.1
  have hrnd := routeNos_nodup hrts h1.2.1
  have hat : ∀ r ∈ db.route, AirportAt db (apOf db) r.depAirportCd.val ∧ AirportAt db (apOf db) r.arrAirportCd.val :=
    fun r hr => ⟨apOf_at (route_airport hm h3 hr).1, apOf_at (route_airport hm h3 hr).2.1⟩
  have hrt : ∀ f ∈ db.flightMaster, RouteAt db (rtOf db) f.routeNo.val :=
    fun f hf => rtOf_at (flightMaster_route hm h3 hf)
  rw [flightMasterFindAll_eq hapnd hrnd hat hrt] at hp
  -- 便名は重複しない（MD-1）
  have hnames : (db.flightMaster.map (·.flightName.val)).Nodup := flightMasterNames_nodup hfm h1.2.2.1
  have hnd : (o.map (·.flightName.val)).Nodup :=
    (hp.map _).nodup_iff.mpr (by rw [List.map_map]; exact hnames)
  refine ⟨_, flightMasterLoad_eq hnd, fun name hname => ?_⟩
  refine ⟨(JHashMap.ofList (o.map fun f =>
    (f.flightName.val, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap f))).get name, ?_, ?_⟩
  · simp only [FlightMasterProvider.getFlightMaster, assertHasText_ok hname]; rfl
  rw [JHashMap.get_ofList_perm hp (key := fun f : FlightMasterResult => f.flightName.val) hnames]
  rw [show (fun r : FlightMasterRow => (flightMasterResultOf r (rtOf db r.routeNo.val)
      (apOf db (rtOf db r.routeNo.val).depAirportCd.val) (apOf db (rtOf db r.routeNo.val).arrAirportCd.val)).flightName.val
      == name) = (fun f => f.flightName.val == name) from rfl]
  rw [flightMasterOf_db hfm name]
  cases hf : db.flightMaster.find? (fun f => f.flightName.val == name) with
  | none => simp only [Option.map_none, Option.bind_none, answerOf?, AnswerOf.opt, Option.map_some]
  | some f =>
    have hfr := List.mem_of_find?_eq_some hf
    obtain ⟨x, _, hx⟩ := mapM_some_mem hfm hfr
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, answerOf?, AnswerOf.opt,
      answer_flightMaster hx (hrt f hfr)]

/-! ## ピーク時期・積算比率 -/

theorem Date.le_iff_epochDay_le (a b : Date) : a ≤ b ↔ a.epochDay ≤ b.epochDay := by
  show a.ordinal ≤ b.ordinal ↔ _
  unfold Date.epochDay; omega

/-- `PeakTimeProvider.getPeakTime` の判定（`depLocalDate` が期間に両端を含めて入る）を、DB の行で書いたもの。 -/
def peakPred (d : JLocalDate) (r : PeakTimeRow) : Bool :=
  !(d.isBefore (JLocalDate.ofEpochDay r.peakStartDate.val) || d.isAfter (JLocalDate.ofEpochDay r.peakEndDate.val))

theorem getPeakTime_go (d : JLocalDate) : ∀ l : List PeakTimeRow,
    PeakTimeProvider.getPeakTime.go d (l.map SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap) =
      .ok ((l.find? (peakPred d)).map SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap)
  | [] => rfl
  | r :: l => by
    simp only [List.map_cons, PeakTimeProvider.getPeakTime.go, SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap,
      SourceModel.Db.MyBatis.date, JRef.deref, ok_bind, List.find?_cons]
    unfold peakPred
    cases (!(d.isBefore (JLocalDate.ofEpochDay r.peakStartDate.val) ||
      d.isAfter (JLocalDate.ofEpochDay r.peakEndDate.val)))
    · exact getPeakTime_go d l
    · rfl

theorem peakTimeOfRow_dates {r : PeakTimeRow} {x : PeakTime} (h : peakTimeOfRow r = some x) :
    x.peakStartDate.epochDay = r.peakStartDate.val ∧ x.peakEndDate.epochDay = r.peakEndDate.val := by
  simp only [peakTimeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨s, hs, e, he, _, _, rfl⟩ := h
  exact ⟨Date.epochDay_ofEpochDay? hs, Date.epochDay_ofEpochDay? he⟩

theorem peakPred_eq {d : JLocalDate} {D : Date} (hd : dateOfJ d = some D) {r : PeakTimeRow} {x : PeakTime}
    (h : peakTimeOfRow r = some x) :
    peakPred d r = decide (x.peakStartDate ≤ D ∧ D ≤ x.peakEndDate) := by
  obtain ⟨hs, he⟩ := peakTimeOfRow_dates h
  have hD := (dateOfJ_eq_some hd).2
  simp only [peakPred, JLocalDate.isBefore, JLocalDate.isAfter, JLocalDate.toEpochDay_ofEpochDay, hD,
    Date.le_iff_epochDay_le, hs, he]
  rw [Bool.eq_iff_iff]
  simp only [Bool.not_eq_true', Bool.or_eq_false_iff, decide_eq_false_iff_not, decide_eq_true_eq]
  omega

theorem answer_peakTime {r : PeakTimeRow} {x : PeakTime} (h : peakTimeOfRow r = some x) :
    AnswerOf.peakTime (SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap r) = some x := by
  simp only [peakTimeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨s, hs, e, he, m, hmr, rfl⟩ := h
  simp only [AnswerOf.peakTime, SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap, SourceModel.Db.MyBatis.str,
    SourceModel.Db.MyBatis.date, Option.bind_some, dateOfJ_ofEpochDay, natOfJ32_int, hmr,
    Option.bind_eq_bind, Option.pure_def]
  simp only [dateOfPg] at hs he
  simp only [hs, he, Option.bind_some]

/-- ピーク時期の参照は、Mapper の結果のどの並びでも、DB の行で `peakPred` を満たす行の写し（MD-4 で高々 1 つ）。 -/
theorem getPeakTime_eq {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h4 : md.MD4)
    {o : List PeakTimeRow} (hp : o.Perm (PeakTimeRepository.findAll db)) {d : JLocalDate} {D : Date} (hd : dateOfJ d = some D) :
    PeakTimeProvider.getPeakTime (PeakTimeProvider.load o) (some d) =
      .ok ((db.peakTime.find? (peakPred d)).map SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap) ∧
    md.peakTimeOn D = (db.peakTime.find? (peakPred d)).bind peakTimeOfRow := by
  obtain ⟨-, -, -, -, -, hpt, -⟩ := masterDataOf_eq_some.mp hm
  have hp' : o.Perm db.peakTime := hp
  constructor
  · simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.Spring.Assert.notNull_some, PeakTimeProvider.getPeakTime, PeakTimeProvider.load, pure_bind]
    rw [getPeakTime_go, find?_perm hp']
    intro a ha b hb ea eb
    obtain ⟨x, hx, hxa⟩ := mapM_some_mem hpt (hp'.mem_iff.mp ha)
    obtain ⟨y, hy, hyb⟩ := mapM_some_mem hpt (hp'.mem_iff.mp hb)
    rw [peakPred_eq hd hxa, decide_eq_true_eq] at ea
    rw [peakPred_eq hd hyb, decide_eq_true_eq] at eb
    have ex := (MasterData.peakTimeOn_eq_some_iff h4).mpr ⟨hx, ea⟩
    have ey := (MasterData.peakTimeOn_eq_some_iff h4).mpr ⟨hy, eb⟩
    have exy : x = y := Option.some.inj (ex.symm.trans ey)
    subst exy
    exact inj_of_kernel peakTimeOfRow_kernel hxa hyb
  · unfold MasterData.peakTimeOn
    exact find?_mapM hpt fun _ _ h => (peakPred_eq hd h).symm

theorem peakTime_query {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h4 : md.MD4)
    {o : List PeakTimeRow} (hp : o.Perm (PeakTimeRepository.findAll db)) {d : JLocalDate} {D : Date} (hd : dateOfJ d = some D) :
    ∃ ans, PeakTimeProvider.getPeakTime (PeakTimeProvider.load o) (some d) = .ok ans ∧
      answerOf? (.peakTime ans) = some (.peakTime (md.peakTimeOn D)) := by
  obtain ⟨-, -, -, -, -, hpt, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨e1, e2⟩ := getPeakTime_eq hm h4 hp hd
  refine ⟨_, e1, ?_⟩
  rw [e2]
  cases hf : db.peakTime.find? (peakPred d) with
  | none => simp only [Option.map_none, Option.bind_none, answerOf?, AnswerOf.opt, Option.map_some]
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hpt (List.mem_of_find?_eq_some hf)
    simp only [Option.map_some, Option.bind_some, hx, answerOf?, AnswerOf.opt, answer_peakTime hx]

theorem ratio_query {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h4 : md.MD4)
    {o : List PeakTimeRow} (hp : o.Perm (PeakTimeRepository.findAll db)) {d : JLocalDate} {D : Date} (hd : dateOfJ d = some D)
    (bcp : BoardingClassProvider) :
    ∃ n, SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getMultiplicationRatio
        { boardingClassProvider := bcp, peakTimeProvider := PeakTimeProvider.load o } (some d) = .ok n ∧
      answerOf? (.ratio n) = some (.ratio (md.multiplicationRatioOn D)) := by
  obtain ⟨-, -, -, -, -, hpt, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨e1, e2⟩ := getPeakTime_eq hm h4 hp hd
  simp only [SourceModel.Domain.Service.B0.TicketSharedServiceImpl.getMultiplicationRatio, e1, ok_bind, MasterData.multiplicationRatioOn, e2]
  cases hf : db.peakTime.find? (peakPred d) with
  | none =>
    refine ⟨_, rfl, ?_⟩
    simp only [Option.bind_none, answerOf?, SourceModel.Domain.Service.B0.TicketSharedServiceImpl.MULTIPLICATION_RATIO_IN_NORMAL_TIME]
    rfl
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hpt (List.mem_of_find?_eq_some hf)
    have hr : natOfInt4 r.multiplicationRatio = some x.multiplicationRatio := by
      simp only [peakTimeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hx
      obtain ⟨_, _, _, _, m, hmr, rfl⟩ := hx
      exact hmr
    refine ⟨_, rfl, ?_⟩
    simp only [Option.bind_some, hx, answerOf?, Option.map_eq_some_iff]
    refine ⟨x.multiplicationRatio, ?_, rfl⟩
    rw [← hr, ← natOfJ32_int]; rfl

/-! ## コードリスト -/

/-- コードリストの要素の写し（`answerOf?` の `codeList`）。 -/
def toEntry (e : String × String) : CodeEntry := ⟨e.1, e.2⟩

/-- `ORDER BY display_order` の許される並びを行の葉で写すと、[Spec] の `mergeSort`（表示順が重複しないとき）。 -/
theorem allowed_mergeSort {ρ ω : Type} [DecidableEq ρ] {rows o : List ρ} {f : ρ → LangSemantics.Sql.Postgresql.Int4}
    {a : ρ → Option ω} {ws : List ω} (hm : rows.mapM a = some ws) (dOrd : ω → Nat)
    (hd : ∀ r w, a r = some w → (dOrd w : Int) = (f r).val) (hnd : (ws.map dOrd).Nodup)
    (h : isAllowedOrder sortCfg [.asc] (orderKey f) rows o = true) (dflt : ω) :
    o.map (fun r => (a r).getD dflt) = ws.mergeSort fun x y => decide (dOrd x ≤ dOrd y) := by
  have e := mapM_some_getD hm dflt
  rw [← e]
  refine allowed_map_eq_mergeSort (f := fun r => (f r).val) _ dOrd (fun r hr => ?_) (by rw [e]; exact hnd) h
  obtain ⟨w, _, hw⟩ := mapM_some_mem hm hr
  simp only [hw, Option.getD_some]
  exact hd r w hw

/-- 既定の [Spec] の空港（使われない）。 -/
def dummyAirportSpec : Airport := ⟨{ val := "AAA" }, "", 0⟩

theorem codeList_airport {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h8 : md.MD8) {o : List AirportRow}
    (ho : isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (airportCodeListRows db) o = true) :
    (SourceModel.Config.App.AtrsCodeListConfig.CL_AIRPORT o).map toEntry = CodeList.airport md := by
  obtain ⟨ha, -⟩ := masterDataOf_eq_some.mp hm
  have hp : o.Perm db.airport := allowed_perm ho
  have hnd := airportCodes_nodup ha h1.1
  have hf : ∀ r ∈ o, AirportOf r ((airportOfRow r).getD dummyAirportSpec) := fun r hr => by
    obtain ⟨w, _, hw⟩ := mapM_some_mem ha (hp.mem_iff.mp hr)
    simp only [hw, Option.getD_some]
    exact airportOfRow_eq_some hw
  rw [airport_eq_insertNop o _ hf ((hp.map _).nodup_iff.mpr hnd) fun r hr => ?_]
  · rw [List.map_map]
    have : toEntry ∘ CodeEntry.toPair = id := funext fun _ => rfl
    rw [this, List.map_id, CodeList.airport]
    congr 1
    rw [← allowed_mergeSort ha (·.displayOrder) (fun r w h => ?_) h1.2.2.2.2.2.2.2.2.1 ho dummyAirportSpec]
    simp only [airportOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨_, _, d, hd, rfl⟩ := h
    exact (natOfInt4_eq_some.mp hd).symm
  · obtain ⟨w, hw, hwr⟩ := mapM_some_mem ha (hp.mem_iff.mp hr)
    have := h8.1 w hw
    rw [airportOfRow_code hwr] at this
    exact this

theorem boardingClassOfRow_parts {r : BoardingClassRow} {w : BoardingClass} (h : boardingClassOfRow r = some w) :
    r.boardingClassCd.val = w.boardingClassCd.toCode ∧ r.boardingClassName.map (·.val) = some w.boardingClassName ∧
      (w.displayOrder : Int) = r.displayOrder.val := by
  refine ⟨bcCdOf_eq_some (boardingClassOfRow_code h), ?_⟩
  simp only [boardingClassOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, nm, hnm, _, _, d, hd, rfl⟩ := h
  exact ⟨by simp [hnm], (natOfInt4_eq_some.mp hd).symm⟩

theorem codeList_boardingClass {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    {o : List BoardingClassRow}
    (ho : isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (boardingClassCodeListRows db) o = true) :
    (SourceModel.Config.App.AtrsCodeListConfig.CL_BOARDINGCLASS o).map toEntry = CodeList.boardingClass md := by
  obtain ⟨-, -, -, hb, -⟩ := masterDataOf_eq_some.mp hm
  have hp : o.Perm db.boardingClass := allowed_perm ho
  let g : BoardingClassRow → BoardingClass := fun r => (boardingClassOfRow r).getD ⟨.N, "", 0, 0⟩
  have hg : ∀ r ∈ o, boardingClassOfRow r = some (g r) := by
    intro r hr
    obtain ⟨w, _, hw⟩ := mapM_some_mem hb (hp.mem_iff.mp hr)
    simp only [g, hw, Option.getD_some]
  have hsort : o.map g = md.boardingClasses.mergeSort fun x y => decide (x.displayOrder ≤ y.displayOrder) :=
    allowed_mergeSort hb (·.displayOrder) (fun _ _ h => (boardingClassOfRow_parts h).2.2)
      h1.2.2.2.2.2.2.2.2.2.1 ho _
  have e1 : o.map (fun r => (some r.boardingClassCd.val, r.boardingClassName.map (·.val))) =
      ((o.map g).map fun b => (b.boardingClassCd.toCode, b.boardingClassName)).map fun e => (some e.1, some e.2) := by
    rw [List.map_map, List.map_map]
    refine List.map_congr_left fun r hr => ?_
    obtain ⟨c, n, -⟩ := boardingClassOfRow_parts (hg r hr)
    simp only [Function.comp, c, n]
  have hnd : (((o.map g).map fun b => (b.boardingClassCd.toCode, b.boardingClassName)).map Prod.fst).Nodup := by
    rw [List.map_map, hsort]
    have := (List.mergeSort_perm md.boardingClasses fun x y => decide (x.displayOrder ≤ y.displayOrder)).map
      (·.boardingClassCd)
    refine nodup_map_of_imp (this.nodup_iff.mpr h1.2.2.2.1) fun a _ b _ e => ?_
    have := congrArg BoardingClassCd.ofCode? e
    simpa [Function.comp, BoardingClassCd.ofCode?_toCode] using this
  unfold SourceModel.Config.App.AtrsCodeListConfig.CL_BOARDINGCLASS
  rw [e1, jdbcCodeList_eq _ hnd, List.map_map, hsort, CodeList.boardingClass]
  rfl

theorem codeList_fareType {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    {o : List FareTypeRow}
    (ho : isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (fareTypeCodeListRows db) o = true) :
    (SourceModel.Config.App.AtrsCodeListConfig.CL_FARETYPE o).map toEntry = CodeList.fareType md := by
  obtain ⟨-, -, -, -, hf, -⟩ := masterDataOf_eq_some.mp hm
  have hp : o.Perm db.fareType := allowed_perm ho
  let g : FareTypeRow → FareType := fun r => (fareTypeOfRow r).getD ⟨.OW, "", 0, 0, 0, 0, 0⟩
  have parts : ∀ r w, fareTypeOfRow r = some w → r.fareTypeCd.val = w.fareTypeCd.toCode ∧
      r.fareTypeName.val = w.fareTypeName ∧ (w.displayOrder : Int) = r.displayOrder.val := by
    intro r w h
    refine ⟨ftCdOf_eq_some (fareTypeOfRow_code h), ?_⟩
    simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨_, _, _, _, _, _, _, _, _, _, d, hd, rfl⟩ := h
    exact ⟨rfl, (natOfInt4_eq_some.mp hd).symm⟩
  have hg : ∀ r ∈ o, fareTypeOfRow r = some (g r) := by
    intro r hr
    obtain ⟨w, _, hw⟩ := mapM_some_mem hf (hp.mem_iff.mp hr)
    simp only [g, hw, Option.getD_some]
  have hsort : o.map g = md.fareTypes.mergeSort fun x y => decide (x.displayOrder ≤ y.displayOrder) :=
    allowed_mergeSort hf (·.displayOrder) (fun r w h => (parts r w h).2.2) h1.2.2.2.2.2.2.2.2.2.2.1 ho _
  have e1 : o.map (fun r => (some r.fareTypeCd.val, some r.fareTypeName.val)) =
      ((o.map g).map fun b => (b.fareTypeCd.toCode, b.fareTypeName)).map fun e => (some e.1, some e.2) := by
    rw [List.map_map, List.map_map]
    refine List.map_congr_left fun r hr => ?_
    obtain ⟨c, n, -⟩ := parts r _ (hg r hr)
    simp only [Function.comp, c, n]
  have hnd : (((o.map g).map fun b => (b.fareTypeCd.toCode, b.fareTypeName)).map Prod.fst).Nodup := by
    rw [List.map_map, hsort]
    have := (List.mergeSort_perm md.fareTypes fun x y => decide (x.displayOrder ≤ y.displayOrder)).map
      (·.fareTypeCd)
    refine nodup_map_of_imp (this.nodup_iff.mpr h1.2.2.2.2.1) fun a _ b _ e => ?_
    have := congrArg FareTypeCd.ofCode? e
    simpa [Function.comp, FareTypeCd.ofCode?_toCode] using this
  unfold SourceModel.Config.App.AtrsCodeListConfig.CL_FARETYPE
  rw [e1, jdbcCodeList_eq _ hnd, List.map_map, hsort, CodeList.fareType]
  rfl

theorem codeList_creditType {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    {o : List CreditTypeRow}
    (ho : isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (creditTypeCodeListRows db) o = true) :
    (SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITTYPE o).map toEntry = CodeList.creditType md := by
  obtain ⟨-, -, -, -, -, -, -, hc⟩ := masterDataOf_eq_some.mp hm
  have hp : o.Perm db.creditType := allowed_perm ho
  let g : CreditTypeRow → CreditType := fun r => (creditTypeOfRow r).getD ⟨{ val := "AAA" }, "", 0⟩
  have parts : ∀ r w, creditTypeOfRow r = some w → r.creditTypeCd.val = w.creditTypeCd.val ∧
      r.creditFirm.val = w.creditFirm ∧ (w.displayOrder : Int) = r.displayOrder.val := by
    intro r w h
    simp only [creditTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨k, hk, d, hd, rfl⟩ := h
    exact ⟨(CreditTypeCd.val_of_ofString? hk).symm, rfl, (natOfInt4_eq_some.mp hd).symm⟩
  have hg : ∀ r ∈ o, creditTypeOfRow r = some (g r) := by
    intro r hr
    obtain ⟨w, _, hw⟩ := mapM_some_mem hc (hp.mem_iff.mp hr)
    simp only [g, hw, Option.getD_some]
  have hsort : o.map g = md.creditTypes.mergeSort fun x y => decide (x.displayOrder ≤ y.displayOrder) :=
    allowed_mergeSort hc (·.displayOrder) (fun r w h => (parts r w h).2.2) h1.2.2.2.2.2.2.2.2.2.2.2 ho _
  have e1 : o.map (fun r => (some r.creditTypeCd.val, some r.creditFirm.val)) =
      ((o.map g).map fun b => (b.creditTypeCd.val, b.creditFirm)).map fun e => (some e.1, some e.2) := by
    rw [List.map_map, List.map_map]
    refine List.map_congr_left fun r hr => ?_
    obtain ⟨c, n, -⟩ := parts r _ (hg r hr)
    simp only [Function.comp, c, n]
  have hnd : (((o.map g).map fun b => (b.creditTypeCd.val, b.creditFirm)).map Prod.fst).Nodup := by
    rw [List.map_map, hsort]
    have := (List.mergeSort_perm md.creditTypes fun x y => decide (x.displayOrder ≤ y.displayOrder)).map
      (·.creditTypeCd)
    refine nodup_map_of_imp (this.nodup_iff.mpr h1.2.2.2.2.2.2.2.1) fun a _ b _ e => ?_
    exact CreditTypeCd.ext e
  unfold SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITTYPE
  rw [e1, jdbcCodeList_eq _ hnd, List.map_map, hsort, CodeList.creditType]
  rfl

theorem codeList_fixed :
    SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITMONTH.map toEntry = CodeList.creditMonth ∧
    SourceModel.Config.App.AtrsCodeListConfig.CL_CREDITYEAR.map toEntry = CodeList.creditYear ∧
    SourceModel.Config.App.AtrsCodeListConfig.CL_GENDER.map toEntry = CodeList.gender ∧
    SourceModel.Config.App.AtrsCodeListConfig.CL_FLIGHTTYPE.map toEntry = CodeList.flightType := by
  refine ⟨by decide, by decide, by decide, by decide⟩

end Abstraction.MasterData.Query
