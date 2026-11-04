import Abstraction.Reserve.Port
import Abstraction.Reserve.Providers
import Abstraction.Reserve.Flights
import Abstraction.Fare.TotalFareRun

/-!
# Abstraction.Reserve.Select

ABS-041 の補題: 選択フライト情報から `TicketHelper.toFlightList` が作るフライト情報（`mkFlight`）の性質
（backlog aedf の第 3 段）。読み込んだ Provider の答え（`Abstraction.Reserve.Providers.load_res`）と、フライトの参照整合性
（`World.RefMaster`）から、便マスタの有無・存在の確認の文の結果・運賃種別のコードを [Spec] の値で表す。
-/

namespace Abstraction.Reserve.Select
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.MasterData.Pre Abstraction.World.Alpha
  Abstraction.Fare.TotalAlpha Abstraction.Fare.TotalFareRun Abstraction.Fare.Load Abstraction.Reserve.Port
  Abstraction.Reserve.Flights
open Spec.Model Spec.Prim Spec.Prim.Text Spec.Env.MasterData
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Sql.Core LangSemantics.Sql.Query
open SourceModel.Db.Schema SourceModel.MasterQuery SourceModel.App.B0 SourceModel.Domain.Common.Masterdata
open SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository

/-- 便マスタの Provider の答え（`getFlightMaster`）は、キャッシュの値。 -/
theorem getFlightMaster_eq {fmp : FlightMasterProvider} {s : String} (h : hasText s = true) :
    FlightMasterProvider.getFlightMaster fmp s = .ok (fmp.flightMasterMap.get s) := by
  simp only [FlightMasterProvider.getFlightMaster, assertHasText_ok h]
  rfl

/-- 搭乗クラスのキャッシュの答えが無いなら、キャッシュの値は `null`。 -/
theorem boardingClass_none {r : JRef SourceModel.Domain.Model.BoardingClass}
    (h : answerOf? (.boardingClass r) = some (.boardingClass none)) : r = none := by
  cases r with
  | none => rfl
  | some b =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, -, hx⟩ := h
    simp [Function.comp] at hx

/-- 運賃種別のキャッシュの答えが無いなら、キャッシュの値は `null`。 -/
theorem fareType_none {r : JRef SourceModel.Domain.Model.FareType}
    (h : answerOf? (.fareType r) = some (.fareType none)) : r = none := by
  cases r with
  | none => rfl
  | some b =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, -, hx⟩ := h
    simp [Function.comp] at hx

/-- 主キーの条件の束縛変数に `NULL` があれば、条件はどの行でも成り立たない。 -/
theorem existsRows_null {fd : FlightDb} {p : KeyParams} (h : p.boardingClass = .null ∨ p.fareType = .null) :
    existsRows fd p = false := by
  have e : ∀ x : SqlValue, SqlValue.eq LangSemantics.Sql.Postgresql.collationC x .null = .unknown := by
    intro x; cases x <;> rfl
  unfold existsRows Bag.exists' Bag.select
  simp only [Bool.not_eq_false', List.isEmpty_iff, List.filter_eq_nil_iff]
  intro r _
  have hu : Truth.unknown.holds = false := rfl
  rcases h with h | h <;> simp only [keyCond, h, Truth.holds_and, e, hu, Bool.and_false, Bool.false_and] <;> decide

section
variable {db : MasterDb} {md : Spec.Env.MasterData} {p : Providers} {fd : FlightDb} {w : Spec.World}
  (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
    some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
  (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
    some (.fareType ((md.fareTypeOf cd).map (·.info))))
  (hw : worldOfDb fd = some w) (href : w.RefMaster md)
include hbq hfq hw href

/-- 存在の確認の文の結果は、`World.existsFlight`（搭乗クラス・運賃種別がマスタに無ければ、どちらも偽）。 -/
theorem exists_mkFlight {f : SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    {fm : SourceModel.Domain.Model.FlightMaster} (hfn : fm.flightName = some k.flightName.val) :
    existsRows fd (bindKey (mkFlight p f).departureDate fm.flightName (mkFlight p f).boardingClass
      (mkFlight p f).fareType) = w.existsFlight k := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := keyOfForm_eq hk
  have ed := (dateOfJ_eq_some hd).2
  simp only [mkFlight, hdj, hbc, hft, Option.bind_some, hfn]
  cases hb : md.boardingClassOf k.boardingClassCd with
  | none =>
    have := hbq k.boardingClassCd
    rw [hb] at this
    rw [boardingClass_none this, existsRows_null (.inl rfl)]
    symm
    rw [Bool.eq_false_iff]
    intro he
    simp only [Spec.World.existsFlight, List.any_eq_true, beq_iff_eq] at he
    obtain ⟨g, hg, rfl⟩ := he
    obtain ⟨-, ⟨b, hbm, hbe⟩, -⟩ := href g hg
    have : md.boardingClassOf g.key.boardingClassCd ≠ none := by
      unfold Spec.Env.MasterData.boardingClassOf
      rw [ne_eq, List.find?_eq_none]
      intro hall
      exact hall b hbm (by simp [hbe])
    exact this hb
  | some BC =>
    cases hf : md.fareTypeOf k.fareTypeCd with
    | none =>
      have := hfq k.fareTypeCd
      rw [hf] at this
      rw [fareType_none this, existsRows_null (.inr (by rfl))]
      symm
      rw [Bool.eq_false_iff]
      intro he
      simp only [Spec.World.existsFlight, List.any_eq_true, beq_iff_eq] at he
      obtain ⟨g, hg, rfl⟩ := he
      obtain ⟨-, -, ⟨t, htm, hte⟩⟩ := href g hg
      have : md.fareTypeOf g.key.fareTypeCd ≠ none := by
        unfold Spec.Env.MasterData.fareTypeOf
        rw [ne_eq, List.find?_eq_none]
        intro hall
        exact hall t htm (by simp [hte])
      exact this hf
    | some FT =>
      have hb' := hbq k.boardingClassCd
      rw [hb] at hb'
      have hBC : BC.boardingClassCd = k.boardingClassCd := by
        have := List.find?_some hb; simpa using this
      rw [← hBC] at hb'
      obtain ⟨b, e, hbe, hbcd, -⟩ := boardingClass_of_answer (by simpa [hBC] using hb')
      have hf' := hfq k.fareTypeCd
      rw [hf] at hf'
      have hFT : FT.fareTypeCd = k.fareTypeCd := by
        have := List.find?_some hf; simpa using this
      obtain ⟨t, d, hte, htcd, -, -⟩ := Abstraction.FlightSearch.Providers.fareType_of_answer' (by simpa using hf')
      rw [hbe, hte]
      have : bindKey (some dj) (some k.flightName.val) (some b) (some t) = keyParams k := by
        simp only [bindKey, sqlOf, Option.bind_some, hbcd, htcd, hBC, hFT, keyParams, ed,
          Abstraction.FlightSearch.Alpha.boardingClassCdName_eq, Abstraction.FlightSearch.Alpha.fareTypeCdName_eq]
      rw [this, existsRows_eq hw]

end

section
variable {md : Spec.Env.MasterData} {p : Providers}
  (hmn : ∀ name : String, hasText name = true → md.flightMasterOf name = none →
    FlightMasterProvider.getFlightMaster p.flightMaster name = .ok none)
  (hmc : ∀ name : String, hasText name = true →
    ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
    ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name = .ok (some fm) ∧
      fm.flightName = some name ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
      fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
      r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
      aa.code = some rt.arrAirportCd.val)

include hmn in
/-- 便マスタが無ければ、フライト情報の便マスタは `null`。 -/
theorem mkFlight_master_none {f : SelectFlightForm} {n : String} (hn : f.flightName = some n)
    (ht : hasText n = true) (h : md.flightMasterOf n = none) :
    (mkFlight p f).flightMaster = none := by
  have := hmn n ht h
  rw [getFlightMaster_eq ht] at this
  simp only [mkFlight, hn, Option.bind_some]
  exact Except.ok.inj this

include hmc in
/-- 便マスタがあれば、フライト情報の便マスタは、便名・時刻・区間の空港コードを持つ。 -/
theorem mkFlight_master_some {f : SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    (ht : hasText k.flightName.val = true) {X : FlightMaster} (h : md.flightMasterOf k.flightName.val = some X)
    {rt : Route} (hrt : Spec.Reserve.FlightSelection.routeOfMaster md X = some rt) :
    ∃ fm dt art, (mkFlight p f).flightMaster = some fm ∧ fm.flightName = some k.flightName.val ∧
      fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧ fm.arrivalTime = some art ∧
      arrOfStr art = some X.arrivalTime ∧ HasRoute fm rt := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := keyOfForm_eq hk
  obtain ⟨fm, r, da, aa, dt, art, hg, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10⟩ := hmc k.flightName.val ht X h rt hrt
  rw [getFlightMaster_eq ht] at hg
  refine ⟨fm, dt, art, ?_, h1, h2, h3, h4, h5, r, da, aa, h6, h7, h8, h9, h10⟩
  simp only [mkFlight, hn, Option.bind_some]
  exact Except.ok.inj hg

end

/-- 主キーのフライトがあれば、フライト情報の運賃種別のコードは主キーのもの。 -/
theorem mkFlight_fareType {md : Spec.Env.MasterData} {p : Providers} {w : Spec.World}
    (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    (href : w.RefMaster md) {f : SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    (he : w.existsFlight k = true) : HasFareType (some (mkFlight p f)) k.fareTypeCd := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := keyOfForm_eq hk
  simp only [Spec.World.existsFlight, List.any_eq_true, beq_iff_eq] at he
  obtain ⟨g, hg, rfl⟩ := he
  obtain ⟨-, -, ⟨t, htm, hte⟩⟩ := href g hg
  obtain ⟨FT, hF⟩ : ∃ FT, md.fareTypeOf g.key.fareTypeCd = some FT := by
    apply Option.isSome_iff_exists.mp
    unfold Spec.Env.MasterData.fareTypeOf
    rw [List.find?_isSome]
    exact ⟨t, htm, by simp [hte]⟩
  have hFT : FT.fareTypeCd = g.key.fareTypeCd := by have := List.find?_some hF; simpa using this
  have hf' := hfq g.key.fareTypeCd
  rw [hF] at hf'
  obtain ⟨t', d, hte', htcd, -, -⟩ := Abstraction.FlightSearch.Providers.fareType_of_answer' (by simpa using hf')
  exact ⟨_, t', rfl, by simp only [mkFlight, hft, Option.bind_some, hte'], by rw [htcd, hFT]⟩

end Abstraction.Reserve.Select
