import Abstraction.MasterData.Lookup
import Abstraction.MasterData.Join
import Abstraction.MasterData.Key

/-!
# Abstraction.MasterData.Query

ABS-026 の問い合わせごとの一致。DB の表の写し（`mapM` の行の葉）と MD-1〜MD-8 の下で、各 Provider の `load()` は
例外を投げず、Mapper の結果のどの許される並びでも、参照の答えの写し（`answerOf?`）は [Spec] の答えに等しい。
-/

namespace Abstraction.MasterData

open LangSemantics.Java LangSemantics.Sql Spec Spec.Prim Abstraction.Prim
  SourceModel.Repository.Schema SourceModel.Repository.MasterData SourceModel.MasterData SourceModel.MasterQuery

/-! ## 搭乗クラス -/

/-- `boardingClassFindAll` の射影。 -/
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
    Answer.boardingClass (boardingClassOf (projBC r) x.boardingClassCd) = some x.info := by
  simp only [boardingClassOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, _, nm, hnm, ex, hex, d, _, rfl⟩ := h
  simp only [Answer.boardingClass, boardingClassOf, projBC, hnm, Option.map_some, natOfJ32_int, hex,
    Option.bind_eq_bind, Option.bind_some, Option.pure_def, BoardingClass.info]

theorem boardingClass_query {db : MasterDb} {bcs : List BoardingClass}
    (hm : db.boardingClass.mapM boardingClassOfRow = some bcs) (hnd : (bcs.map (·.boardingClassCd)).Nodup)
    {o : List BoardingClassResult} (hp : o.Perm (boardingClassFindAll db)) (cd : BoardingClassCd) :
    ∃ bcp, BoardingClassProvider.load o = .ok bcp ∧
      answerOf? (.boardingClass (bcp.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((bcs.find? fun b => b.boardingClassCd == cd).map (·.info))) := by
  have hp' : o.Perm (db.boardingClass.map projBC) := hp
  have hk : ∀ b ∈ o, SourceModel.Repository.Mapping.boardingClassCd b.boardingClassCd.val = .ok (keyBC b) := by
    intro b hb
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp (hp'.mem_iff.mp hb)
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm hr
    rw [keyBC_proj hx]
    exact bcCdOf_mapping (boardingClassOfRow_code hx)
  refine ⟨_, boardingClassLoad_eq o keyBC hk, ?_⟩
  have hkeys : db.boardingClass.map (keyBC ∘ projBC) = bcs.map (·.boardingClassCd) :=
    (mapM_some_map hm fun _ _ h => (keyBC_proj h).symm).symm
  rw [get_ofList_perm hp' (hkeys ▸ hnd) cd,
    find?_mapM hm (p := fun r => keyBC (projBC r) == cd) fun _ _ h => by simp only [keyBC_proj h]]
  cases hf : db.boardingClass.find? (fun r => keyBC (projBC r) == cd) with
  | none => rfl
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm (List.mem_of_find?_eq_some hf)
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, keyBC_proj hx, answerOf?, Answer.opt,
      answer_boardingClassOf hx]

/-! ## 運賃種別 -/

/-- `fareTypeFindAll` の射影。 -/
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
    Answer.fareType (fareTypeOf (projFT r) x.fareTypeCd) = some x.info := by
  simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cd, _, dr, hdr, st, hst, en, hen, pm, hpm, d, _, rfl⟩ := h
  simp only [Answer.fareType, fareTypeOf, projFT, SourceModel.Repository.Mapping.str, natOfJ32_int, hdr, hst, hen,
    hpm, Option.bind_eq_bind, Option.bind_some, Option.pure_def, FareType.info]

theorem fareType_query {db : MasterDb} {fts : List FareType}
    (hm : db.fareType.mapM fareTypeOfRow = some fts) (hnd : (fts.map (·.fareTypeCd)).Nodup)
    {o : List FareTypeResult} (hp : o.Perm (fareTypeFindAll db)) (cd : FareTypeCd) :
    ∃ ftp, FareTypeProvider.load o = .ok ftp ∧
      answerOf? (.fareType (ftp.fareTypeCodeMap.get cd)) =
        some (.fareType ((fts.find? fun f => f.fareTypeCd == cd).map (·.info))) := by
  have hp' : o.Perm (db.fareType.map projFT) := hp
  have hk : ∀ f ∈ o, SourceModel.Repository.Mapping.fareTypeCd f.fareTypeCd.val = .ok (keyFT f) := by
    intro f hf
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp (hp'.mem_iff.mp hf)
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm hr
    rw [keyFT_proj hx]
    exact ftCdOf_mapping (fareTypeOfRow_code hx)
  refine ⟨_, fareTypeLoad_eq o keyFT hk, ?_⟩
  have hkeys : db.fareType.map (keyFT ∘ projFT) = fts.map (·.fareTypeCd) :=
    (mapM_some_map hm fun _ _ h => (keyFT_proj h).symm).symm
  rw [get_ofList_perm hp' (hkeys ▸ hnd) cd,
    find?_mapM hm (p := fun r => keyFT (projFT r) == cd) fun _ _ h => by simp only [keyFT_proj h]]
  cases hf : db.fareType.find? (fun r => keyFT (projFT r) == cd) with
  | none => rfl
  | some r =>
    obtain ⟨x, _, hx⟩ := mapM_some_mem hm (List.mem_of_find?_eq_some hf)
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, keyFT_proj hx, answerOf?, Answer.opt,
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
    a.code = ⟨r.airportCd.val⟩ := by
  simp only [airportOfRow, Option.map_eq_some_iff] at h
  obtain ⟨_, _, rfl⟩ := h; rfl

theorem routeOfRow_codes {r : RouteRow} {x : Route} (h : routeOfRow r = some x) :
    x.depAirportCd = ⟨r.depAirportCd.val⟩ ∧ x.arrAirportCd = ⟨r.arrAirportCd.val⟩ := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, _, _, rfl⟩ := h; exact ⟨rfl, rfl⟩

/-- MD-1: 空港コードは DB の表の中で重複しない。 -/
theorem airportCodes_nodup {db : MasterDb} {as : List Airport} (ha : db.airport.mapM airportOfRow = some as)
    (hnd : (as.map (·.code)).Nodup) : (db.airport.map (·.airportCd.val)).Nodup := by
  rw [mapM_some_map ha (g := fun r => (⟨r.airportCd.val⟩ : AirportCd)) fun _ _ h => airportOfRow_code h] at hnd
  exact nodup_map_of_imp hnd fun _ _ _ _ e => by simp only [e]

/-- MD-3・MD-8: 区間の空港は DB の空港の表にあり、そのコードは `WellFormed`。 -/
theorem route_airport {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h3 : md.MD3)
    (h8 : md.MD8) {r : RouteRow} (hr : r ∈ db.route) :
    (∃ a ∈ db.airport, a.airportCd.val = r.depAirportCd.val) ∧ (∃ a ∈ db.airport, a.airportCd.val = r.arrAirportCd.val) ∧
      (⟨r.depAirportCd.val⟩ : AirportCd).WellFormed ∧ (⟨r.arrAirportCd.val⟩ : AirportCd).WellFormed := by
  obtain ⟨ha, hrt, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨x, hx, hxr⟩ := mapM_some_mem hrt hr
  obtain ⟨hdep, harr⟩ := routeOfRow_codes hxr
  obtain ⟨⟨a, ham, hac⟩, ⟨b, hbm, hbc⟩⟩ := h3.1 x hx
  obtain ⟨ar, har, hae⟩ := mapM_some_mem' ha ham
  obtain ⟨br, hbr, hbe⟩ := mapM_some_mem' ha hbm
  have e1 := airportOfRow_code hae
  have e2 := airportOfRow_code hbe
  refine ⟨⟨ar, har, ?_⟩, ⟨br, hbr, ?_⟩, ?_, ?_⟩
  · have := hac.trans hdep; rw [e1] at this; exact congrArg AirportCd.val this
  · have := hbc.trans harr; rw [e2] at this; exact congrArg AirportCd.val this
  · rw [← hdep, ← hac]; exact (h8.1 a ham).1
  · rw [← harr, ← hbc]; exact (h8.1 b hbm).1

/-! ## 区間 -/

theorem answer_route {db : MasterDb} {r : RouteRow} {x : Route} (h : routeOfRow r = some x)
    (hd : AirportAt db (apOf db) r.depAirportCd.val) (ha : AirportAt db (apOf db) r.arrAirportCd.val) :
    Answer.route (SourceModel.Repository.Mapping.route
      (routeResultOf r (apOf db r.depAirportCd.val) (apOf db r.arrAirportCd.val))) = some x := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨no, hno, bf, hbf, rfl⟩ := h
  simp only [Answer.route, SourceModel.Repository.Mapping.route, routeResultOf, SourceModel.Repository.Mapping.str,
    natOfJ32_int, hno, hbf, hd.2, ha.2, Option.bind_eq_bind, Option.bind_some, Option.pure_def]

theorem route_query {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h2 : md.MD2) (h3 : md.MD3) (h8 : md.MD8) {o : List RouteResult} (hp : o.Perm (routeFindAll db))
    {dep arr : AirportCd} (hdep : dep.WellFormed) (harr : arr.WellFormed) :
    ∃ rtp, RouteProvider.load o = .ok rtp ∧ ∃ ans, getRouteByAirportCd rtp dep.val arr.val = .ok ans ∧
      answerOf? (.route ans) = some (.route (md.routeOf dep arr)) := by
  obtain ⟨ha, hrt, -⟩ := masterDataOf_eq_some.mp hm
  have hapnd := airportCodes_nodup ha h1.1
  have hat : ∀ r ∈ db.route, AirportAt db (apOf db) r.depAirportCd.val ∧ AirportAt db (apOf db) r.arrAirportCd.val :=
    fun r hr => ⟨apOf_at (route_airport hm h3 h8 hr).1, apOf_at (route_airport hm h3 h8 hr).2.1⟩
  rw [routeFindAll_eq hapnd hat] at hp
  refine ⟨_, routeLoad_eq o, (JHashMap.ofList (o.map fun r =>
    (makeCacheKey r.depAirportCd.val r.aarAirportCd.val, SourceModel.Repository.Mapping.route r))).get
      (makeCacheKey dep.val arr.val), ?_, ?_⟩
  · simp only [getRouteByAirportCd, assertHasText_ok (AirportCd.hasText_of_wellFormed hdep),
      assertHasText_ok (AirportCd.hasText_of_wellFormed harr)]
    rfl
  let key : RouteResult → String := fun res => makeCacheKey res.depAirportCd.val res.aarAirportCd.val
  let projR : RouteRow → RouteResult := fun r =>
    routeResultOf r (apOf db r.depAirportCd.val) (apOf db r.arrAirportCd.val)
  have hkey : ∀ r ∈ db.route, key (projR r) = makeCacheKey r.depAirportCd.val r.arrAirportCd.val := by
    intro r hr
    simp only [key, projR, routeResultOf, (hat r hr).1.2, (hat r hr).2.2]
  have hpairs : (db.route.map fun r => ((⟨r.depAirportCd.val⟩ : AirportCd), (⟨r.arrAirportCd.val⟩ : AirportCd))).Nodup := by
    rw [← mapM_some_map hrt (k := fun x : Route => (x.depAirportCd, x.arrAirportCd)) fun _ _ h => by
      rw [(routeOfRow_codes h).1, (routeOfRow_codes h).2]]
    exact h2.1
  have hnd : (db.route.map (key ∘ projR)).Nodup := by
    refine nodup_map_of_imp hpairs fun a ha b hb e => ?_
    simp only [Function.comp, hkey a ha, hkey b hb] at e
    obtain ⟨e1, e2⟩ := makeCacheKey_inj (AirportCd.no_dash_of_wellFormed (route_airport hm h3 h8 ha).2.2.1)
      (AirportCd.no_dash_of_wellFormed (route_airport hm h3 h8 hb).2.2.1) e
    have e1' : a.depAirportCd.val = b.depAirportCd.val := e1
    simp only [e1', e2]
  show answerOf? (.route ((JHashMap.ofList (o.map fun b => (key b, SourceModel.Repository.Mapping.route b))).get
    (makeCacheKey dep.val arr.val))) = _
  rw [get_ofList_perm hp hnd]
  have hspec : md.routeOf dep arr =
      (db.route.find? fun r => key (projR r) == makeCacheKey dep.val arr.val).bind routeOfRow := by
    unfold MasterData.routeOf
    rw [find?_mapM hrt (p := fun r => (⟨r.depAirportCd.val⟩ : AirportCd) == dep && (⟨r.arrAirportCd.val⟩ : AirportCd) == arr)
      fun _ _ h => by rw [(routeOfRow_codes h).1, (routeOfRow_codes h).2]]
    congr 1
    refine find?_congr fun r hr => ?_
    rw [hkey r hr]
    have nd := AirportCd.no_dash_of_wellFormed (route_airport hm h3 h8 hr).2.2.1
    rw [Bool.eq_iff_iff]
    simp only [Bool.and_eq_true, beq_iff_eq]
    constructor
    · rintro ⟨rfl, rfl⟩; rfl
    · intro e
      obtain ⟨e1, e2⟩ := makeCacheKey_inj nd (AirportCd.no_dash_of_wellFormed hdep) e
      exact ⟨by cases dep; simp only [AirportCd.mk.injEq] at *; exact e1,
        by cases arr; simp only [AirportCd.mk.injEq] at *; exact e2⟩
  rw [hspec]
  cases hf : db.route.find? (fun r => key (projR r) == makeCacheKey dep.val arr.val) with
  | none => rfl
  | some r =>
    have hr := List.mem_of_find?_eq_some hf
    obtain ⟨x, _, hx⟩ := mapM_some_mem hrt hr
    simp only [Option.map_some, Option.bind_some, hx, Function.comp, answerOf?, Answer.opt,
      answer_route hx (hat r hr).1 (hat r hr).2]

end Abstraction.MasterData
