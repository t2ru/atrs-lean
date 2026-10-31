import Abstraction.MasterData.Refines

/-!
# Abstraction.Fare.Load

合計金額の R 課題（ABS-004）で使う、起動時の読み込みとキャッシュの参照の補題。

- `flightMaster_fare`: 便マスタのキャッシュの答えが持つ区間の運賃は、[Spec] の便名の区間（`routeOfFlightName`）の運賃
- `boardingClass_of_answer`・`fareType_of_answer`: 搭乗クラス・運賃種別のキャッシュの答えから、コード・加算料金・割引率を取り出す
- `load_correct'`: `load_correct` に、便マスタ・運賃種別のキャッシュの性質を加えたもの
-/

namespace Abstraction.MasterData
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas LangSemantics.Sql.Sequence

open LangSemantics.Java LangSemantics.Sql Spec Spec.Prim LangSemantics.Core
  SourceModel.Repository.Schema SourceModel.Repository.MasterData SourceModel.MasterData SourceModel.MasterQuery

theorem routeOfRow_fare {r : RouteRow} {x : Route} (h : routeOfRow r = some x) : (x.basicFare : Int) = r.basicFare.val := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨no, -, bf, hbf, rfl⟩ := h
  exact (natOfInt4_eq_some.mp hbf).symm

/-- 便マスタのキャッシュの答えが持つ区間の運賃は、[Spec] の便名の区間の運賃。 -/
theorem flightMaster_fare {db : MasterDb} {md : MasterData} (hm : masterDataOf db = some md) (h1 : md.MD1)
    (h3 : md.MD3) (h8 : md.MD8) {o : List FlightMasterResult} (hp : o.Perm (flightMasterFindAll db)) :
    ∃ fmp, FlightMasterProvider.load o = .ok fmp ∧ ∀ name : FlightName, hasText name.val = true →
      ∀ rt, Spec.Fare.routeOfFlightName md name = some rt →
      ∃ fm r b, getFlightMaster fmp name.val = .ok (some fm) ∧ fm.route = some r ∧ r.basicFare = some b ∧
        b.val = (rt.basicFare : Int) := by
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
  refine ⟨_, flightMasterLoad_eq hnd, fun name hname rt hrt' => ?_⟩
  have hget : getFlightMaster (⟨JHashMap.ofList (o.map fun f =>
      (f.flightName.val, SourceModel.Repository.Mapping.flightMasterRow f))⟩ : FlightMasterProvider) name.val =
      .ok ((JHashMap.ofList (o.map fun f =>
        (f.flightName.val, SourceModel.Repository.Mapping.flightMasterRow f))).get name.val) := by
    simp only [getFlightMaster, assertHasText_ok hname]; rfl
  rw [JHashMap.get_ofList_perm hp (key := fun f : FlightMasterResult => f.flightName.val) hnames] at hget
  rw [show (fun r : FlightMasterRow => (flightMasterResultOf r (rtOf db r.routeNo.val)
      (apOf db (rtOf db r.routeNo.val).depAirportCd.val) (apOf db (rtOf db r.routeNo.val).arrAirportCd.val)).flightName.val
      == name.val) = (fun f => f.flightName.val == name.val) from rfl] at hget
  have hspec : md.flightMasterOf name =
      (db.flightMaster.find? fun f => f.flightName.val == name.val).bind flightMasterOfRow := by
    unfold MasterData.flightMasterOf
    rw [find?_mapM hfm (p := fun f => f.flightName.val == name.val) fun _ _ h => by
      rw [(flightMasterOfRow_fields h).2, Bool.eq_iff_iff]; cases name; simp [FlightName.mk.injEq]]
  unfold Spec.Fare.routeOfFlightName at hrt'
  rw [hspec] at hrt'
  cases hf : db.flightMaster.find? (fun f => f.flightName.val == name.val) with
  | none => simp [hf] at hrt'
  | some f =>
    rw [hf] at hrt' hget
    have hrt'' : (flightMasterOfRow f).bind (fun fm => md.routes.find? fun r => r.routeNo == fm.routeNo) = some rt :=
      hrt'
    obtain ⟨x, hx, hr⟩ := Option.bind_eq_some_iff.mp hrt''
    have hfr := List.mem_of_find?_eq_some hf
    have hxno := (flightMasterOfRow_fields hx).1
    rw [find?_mapM hrts (p := fun r => r.routeNo.val == f.routeNo.val) fun a b h => by
      rw [Bool.eq_iff_iff]; simp only [beq_iff_eq]; have := routeOfRow_no h; omega] at hr
    cases hr0 : db.route.find? (fun r => r.routeNo.val == f.routeNo.val) with
    | none => simp [hr0] at hr
    | some r0 =>
      rw [hr0, Option.bind_some] at hr
      have hrt0 : rtOf db f.routeNo.val = r0 := by simp only [rtOf, hr0, Option.getD_some]
      refine ⟨_, _, _, by rw [hget]; rfl, rfl, rfl, ?_⟩
      simp only [Function.comp, SourceModel.Repository.Mapping.flightMasterRow, flightMasterResultOf,
        SourceModel.Repository.Mapping.route, routeResultOf, SourceModel.Repository.Mapping.int, hrt0]
      rw [routeOfRow_fare hr]
      exact J32.val_ofInt_of_inRange _ ⟨by have := r0.basicFare.property.1; simp only [J32.minValue]; omega,
        by have := r0.basicFare.property.2; simp only [J32.maxValue]; omega⟩

/-- 搭乗クラスのキャッシュの答えから、コードと加算料金を取り出す。 -/
theorem boardingClass_of_answer {r : JRef SourceModel.Model.BoardingClass} {bc : BoardingClass}
    (h : answerOf? (.boardingClass r) = some (.boardingClass (some bc.info))) :
    ∃ b e, r = some b ∧ b.boardingClassCd = some bc.boardingClassCd ∧ b.extraCharge = some e ∧
      e.val = (bc.extraCharge : Int) := by
  cases r with
  | none => simp [answerOf?, Answer.opt] at h
  | some b =>
    simp only [answerOf?, Answer.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, MasterData.Answer.boardingClass.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [Answer.boardingClass, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, hcd, nm, -, ex, hex, he⟩ := hx
    obtain ⟨e, he1, he2⟩ := hex
    rw [natOfJ32_eq_some] at he2
    simp only [BoardingClass.info, MasterData.BoardingClassInfo.mk.injEq] at he
    obtain ⟨rfl, -, rfl⟩ := he
    exact ⟨b, e, rfl, hcd, he1, he2⟩

/-- 運賃種別のキャッシュの答えから、割引率を取り出す。 -/
theorem fareType_of_answer {r : JRef SourceModel.Model.FareType} {ft : FareType}
    (h : answerOf? (.fareType r) = some (.fareType (some ft.info))) :
    ∃ f d, r = some f ∧ f.discountRate = some d ∧ d.val = (ft.discountRate : Int) := by
  cases r with
  | none => simp [answerOf?, Answer.opt] at h
  | some f =>
    simp only [answerOf?, Answer.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, MasterData.Answer.fareType.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [Answer.fareType, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, hc0, nm, hn0, dr, hdr, s0, hs0, e0, he0, pm0, hp0, he⟩ := hx
    obtain ⟨d, hd1, hd2⟩ := hdr
    rw [natOfJ32_eq_some] at hd2
    simp only [FareType.info, MasterData.FareTypeInfo.mk.injEq] at he
    obtain ⟨-, -, rfl, -⟩ := he
    exact ⟨f, d, rfl, hd1, hd2⟩

/-- `load_correct` に、運賃種別・便マスタのキャッシュの性質を加えたもの。 -/
theorem load_correct' {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {o : Order} (ho : o.Allowed db) :
    ∃ p, load o = .ok p ∧ p.peakTime = PeakTimeProvider.load o.peakTime ∧
      (∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((md.boardingClassOf cd).map (·.info)))) ∧
      (∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeCodeMap.get cd)) =
        some (.fareType ((md.fareTypeOf cd).map (·.info)))) ∧
      (∀ name : FlightName, hasText name.val = true → ∀ rt, Spec.Fare.routeOfFlightName md name = some rt →
        ∃ fm r b, getFlightMaster p.flightMaster name.val = .ok (some fm) ∧ fm.route = some r ∧ r.basicFare = some b ∧
          b.val = (rt.basicFare : Int)) := by
  obtain ⟨-, -, -, hbcs, hfts, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨hpr, hpf, hpb, hpft, -, -, -, -, -⟩ := ho
  obtain ⟨bcp, hbl, hbq⟩ := boardingClass_query hbcs hv.md1.2.2.2.1 hpb
  obtain ⟨ftp, hfl, hfq⟩ := fareType_query hfts hv.md1.2.2.2.2.1 hpft
  obtain ⟨rtp, hrl, -⟩ := route_query hm hv.md1 hv.md2 hv.md3 hv.md8 hpr
  obtain ⟨fmp, hml, hmf⟩ := flightMaster_fare hm hv.md1 hv.md3 hv.md8 hpf
  exact ⟨_, by simp only [load, hbl, hfl, hrl, hml, ok_bind]; rfl, rfl, fun cd => hbq cd, fun cd => hfq cd, hmf⟩

end Abstraction.MasterData
