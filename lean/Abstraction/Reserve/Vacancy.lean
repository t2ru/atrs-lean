import Abstraction.Reserve.Port
import Abstraction.Reserve.Tx
import Abstraction.MasterData.Pre
import Abstraction.FlightSearch.Alpha
import Abstraction.FlightSearch.Period
import Abstraction.Reserve.Select
import LangSemantics.Java.EStateSimp

/-!
# Abstraction.Reserve.Vacancy

ABS-041 の補題: 予約確定の空席の確保（`TicketReserveServiceImpl.validateAndUpdateVacancy`）と、[Spec] の
`secureSeats` の対応（backlog aedf の第 3 段）。

- 排他でのフライトの取得（`findOneForUpdate`）の行の写像（`flightMap`）は、主キーの束縛変数が行の α の主キーで、
  空席数が行の空席数のフライト情報。
- 空席数の更新（`update`）の後の状態の表の α は、`World.updateVacantNum`。
-/

namespace Abstraction.Reserve.Vacancy
open Abstraction.World.Alpha Abstraction.Reserve.Port Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Pre
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Sql.Core LangSemantics.Sql.Query
open SourceModel.Db.Schema SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository
open Spec.Model

/-- 状態の表 FLIGHT だけを替えたときの α。 -/
theorem worldOfDb_setFlights {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w)
    {rows : List FlightRow} {fs : List Flight} (hr : rows.mapM flightOfRow = some fs) :
    worldOfDb { fd with flight := rows } = some { w with flights := fs } := by
  obtain ⟨-, hm, hrs, hsq⟩ := worldOfDb_eq_some.mp hw
  exact worldOfDb_eq_some.mpr ⟨hr, hm, hrs, hsq⟩

/-- `findOneForUpdate` の結果の列（射影）。 -/
def resultOf (r : FlightRow) : FlightResult :=
  ⟨r.departureDate, r.flightName, r.fareTypeCd, r.vacantNum, r.boardingClassCd⟩

/-- 行の写像（`flight-map`）: 行の α がフライト `f` なら、例外を投げず、主キーの束縛変数は `f` の主キー、空席数は
行の空席数。 -/
theorem flightMap_ok {r : FlightRow} {f : Flight} (hf : flightOfRow r = some f) :
    ∃ L, flightMap (resultOf r) = .ok L ∧
      bindKey L.departureDate (L.flightMaster.bind (·.flightName)) L.boardingClass L.fareType = keyParams f.key ∧
      ∃ v, L.vacantNum = some v ∧ v.val = (f.vacantNum : Int) := by
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hf
  obtain ⟨d, hd, bc, hbc, ft, hft, v, hv, rfl⟩ := hf
  have ed := Spec.Prim.Date.epochDay_ofEpochDay? hd
  refine ⟨_, by simp only [flightMap, resultOf, bcCdOf_mapping hbc, ftCdOf_mapping hft]; rfl, ?_, ?_⟩
  · simp only [bindKey, keyParams, SourceModel.Db.MyBatis.date, SourceModel.Db.MyBatis.str, sqlOf, Option.bind_some,
      Abstraction.FlightSearch.Alpha.boardingClassCdName_eq, Abstraction.FlightSearch.Alpha.fareTypeCdName_eq,
      JLocalDate.toEpochDay_ofEpochDay, ed]
  · refine ⟨_, rfl, ?_⟩
    have := natOfJ32_int (v := r.vacantNum)
    simp only [SourceModel.Db.MyBatis.int, Option.bind_some] at this
    rw [hv, natOfJ32_eq_some] at this
    exact this

/-- 空席数の更新の文: 主キーのフライト `f` があり、空席数 `v` が `int` の値域の自然数 `n` なら、更新件数は 1 で、更新後の
状態の表の α は `World.updateVacantNum`。 -/
theorem updateRows_alpha {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (hinv : w.Inv)
    {k : FlightKey} {f : Flight} (hf : w.findForUpdate k = some f) {v : Int.J32} {n : Nat}
    (hv : v.val = (n : Int)) (hn : n ≤ 2147483647) :
    ∃ fd', updateRows fd (keyParams k) (some v) = .ok (1, fd') ∧
      worldOfDb fd' = some (w.updateVacantNum k n) := by
  have hsel := select_key_find hw hinv k
  rw [hf, Option.toList_some] at hsel
  have hne : (Bag.select (keyCond (keyParams k)) fd.flight).isEmpty = false := by
    cases h : Bag.select (keyCond (keyParams k)) fd.flight with
    | nil => rw [h] at hsel; cases hsel
    | cons _ _ => rfl
  have hr : (-2147483648 : Int) ≤ v.val ∧ v.val ≤ 2147483647 := by omega
  obtain ⟨h1, h2⟩ := updateWhere_alpha (k := k) (v := ⟨v.val, hr⟩) (n := n) hv (worldOfDb_flights hw)
  have hcount : (w.flights.filter (·.key == k)).length = 1 := by
    rw [filter_key_eq hinv k]
    unfold Spec.Port.World.findForUpdate at hf
    rw [hf]
    rfl
  refine ⟨_, ?_, worldOfDb_setFlights hw h1⟩
  simp only [updateRows, hne, Bool.false_eq_true, ite_false]
  unfold LangSemantics.Sql.Postgresql.Int4.ofInt
  rw [dite_eq_left_of_eq_true (eq_true hr)]
  simp only [Bind.bind, Except.bind, Pure.pure, Except.pure]
  rw [h2, hcount]

open Abstraction.MasterData.Alpha in
/-- 運賃種別のキャッシュの答えから、コードと予約可能期間の日数を取り出す。 -/
theorem fareType_days {r : JRef SourceModel.Domain.Model.FareType} {FT : Spec.MasterData.FareType}
    (h : answerOf? (.fareType r) = some (.fareType (some FT.info))) :
    ∃ t s e, r = some t ∧ t.fareTypeCd = some FT.fareTypeCd ∧ t.rsrvAvailableStartDayNum = some s ∧
      s.val = (FT.rsrvAvailableStartDayNum : Int) ∧ t.rsrvAvailableEndDayNum = some e ∧
      e.val = (FT.rsrvAvailableEndDayNum : Int) := by
  cases r with
  | none => simp [answerOf?, AnswerOf.opt] at h
  | some f =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, Spec.MasterQuery.Answer.fareType.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [AnswerOf.fareType, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, hc0, nm, -, dr, -, s0, hs0, e0, he0, pm0, -, he⟩ := hx
    obtain ⟨s, hs1, hs2⟩ := hs0
    obtain ⟨e, he1, he2⟩ := he0
    rw [natOfJ32_eq_some] at hs2 he2
    simp only [Spec.MasterData.FareType.info, Spec.MasterData.FareTypeInfo.mk.injEq] at he
    obtain ⟨rfl, -, -, rfl, rfl, -⟩ := he
    exact ⟨f, s, e, rfl, hc0, hs1, hs2, he1, he2⟩

/-- 運賃種別の予約可能判定: [Source] の `isAvailableFareType`（日付の形）は、[Spec] の `isAvailableFareType`。 -/
theorem isAvailable_eq {t : SourceModel.Domain.Model.FareType} {FT : Spec.MasterData.FareType} {s e : Int.J32}
    (hs : t.rsrvAvailableStartDayNum = some s) (hsv : s.val = (FT.rsrvAvailableStartDayNum : Int))
    (he : t.rsrvAvailableEndDayNum = some e) (hev : e.val = (FT.rsrvAvailableEndDayNum : Int))
    {dJ tJ : JLocalDate} {D T : Spec.Prim.Date} (hD : dateOfJ dJ = some D) (hT : dateOfJ tJ = some T) :
    SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType (some t) (some dJ) tJ =
      .ok (Spec.FlightSearch.isAvailableFareType FT D T) := by
  rw [Abstraction.FlightSearch.Period.isAvailableFareType_between t s e hs he dJ tJ]
  have eD := (dateOfJ_eq_some hD).2
  have eT := (dateOfJ_eq_some hT).2
  have hb : JLocalDate.daysBetween tJ dJ = Spec.Prim.Date.daysBetween T D := by
    simp only [JLocalDate.daysBetween, Spec.Prim.Date.daysBetween, eT, eD]
  simp only [Abstraction.FlightSearch.Period.between_int_holds, hb, hsv, hev, Spec.FlightSearch.isAvailableFareType,
    Spec.FlightSearch.availableOnDayNum]

section
open Abstraction.MasterData.Alpha Abstraction.Fare.TotalFareRun Abstraction.Fare.TotalAlpha
variable {md : Spec.MasterData} {p : SourceModel.MasterQuery.Providers}
  (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
    some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
  (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
    some (.fareType ((md.fareTypeOf cd).map (·.info))))
include hbq hfq

/-- 選択フライト情報から作ったフライト情報の主キーの束縛変数は、主キー `k` の束縛変数（搭乗クラス・運賃種別がマスタに
ある場合）。 -/
theorem mkFlight_key {f : SourceModel.App.B0.SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    {BC : Spec.MasterData.BoardingClass} {FT : Spec.MasterData.FareType}
    (hb : md.boardingClassOf k.boardingClassCd = some BC) (hf : md.fareTypeOf k.fareTypeCd = some FT)
    {fm : SourceModel.Domain.Model.FlightMaster} (hfn : fm.flightName = some k.flightName.val) :
    bindKey (mkFlight p f).departureDate fm.flightName (mkFlight p f).boardingClass (mkFlight p f).fareType =
      keyParams k := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := keyOfForm_eq hk
  have ed := (dateOfJ_eq_some hd).2
  have hb' := hbq k.boardingClassCd
  rw [hb] at hb'
  have hBC : BC.boardingClassCd = k.boardingClassCd := by
    have := List.find?_some hb; simpa using this
  obtain ⟨b, e, hbe, hbcd, -⟩ := Abstraction.Fare.Load.boardingClass_of_answer (by simpa [hBC] using hb')
  have hf' := hfq k.fareTypeCd
  rw [hf] at hf'
  have hFT : FT.fareTypeCd = k.fareTypeCd := by
    have := List.find?_some hf; simpa using this
  obtain ⟨t, d, hte, htcd, -, -⟩ := Abstraction.FlightSearch.Providers.fareType_of_answer' (by simpa using hf')
  simp only [mkFlight, hdj, hbc, hft, Option.bind_some, hfn, hbe, hte]
  simp only [bindKey, sqlOf, Option.bind_some, hbcd, htcd, hBC, hFT, keyParams, ed,
    Abstraction.FlightSearch.Alpha.boardingClassCdName_eq, Abstraction.FlightSearch.Alpha.fareTypeCdName_eq]

omit hbq in
/-- 選択フライト情報から作ったフライト情報の運賃種別は、マスタの運賃種別 `FT` のコードと予約可能期間を持つ。 -/
theorem mkFlight_days {f : SourceModel.App.B0.SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    {FT : Spec.MasterData.FareType} (hf : md.fareTypeOf k.fareTypeCd = some FT) :
    ∃ t s e, (mkFlight p f).fareType = some t ∧ t.rsrvAvailableStartDayNum = some s ∧
      s.val = (FT.rsrvAvailableStartDayNum : Int) ∧ t.rsrvAvailableEndDayNum = some e ∧
      e.val = (FT.rsrvAvailableEndDayNum : Int) := by
  obtain ⟨-, -, -, -, -, hft⟩ := keyOfForm_eq hk
  have hf' := hfq k.fareTypeCd
  rw [hf] at hf'
  obtain ⟨t, s, e, hte, -, h1, h2, h3, h4⟩ := fareType_days (by simpa using hf')
  exact ⟨t, s, e, by simp only [mkFlight, hft, Option.bind_some, hte], h1, h2, h3, h4⟩

end

section
open LangSemantics.Core.EStateHoare Abstraction.Reserve.Tx
open Abstraction.MasterData.Alpha Abstraction.Fare.TotalFareRun Abstraction.Fare.TotalAlpha
open SourceModel.Db.Tx SourceModel.Domain.Service.B2 SourceModel.Domain.Common.Exception

theorem mapM_singleton {α β : Type} {g : α → Option β} {b : β} :
    ∀ {l : List α}, l.mapM g = some [b] → ∃ a, l = [a] ∧ g a = some b
  | [], h => by simp at h
  | [a], h => by
    simp only [List.mapM_cons, List.mapM_nil, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨b', hb, _, rfl, e⟩ := h
    cases e
    exact ⟨a, rfl, hb⟩
  | _ :: _ :: _, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨_, -, _, ⟨_, -, _, -, rfl⟩, e⟩ := h
    cases e

/-- 状態の表の α が `w` で、実行環境が `env`。 -/
def AtW (env : Env) (w : Spec.Port.World) (s : St) : Prop := worldOfDb s.db = some w ∧ s.env = env

/-- 空席の確保（1 便）。予約フライトは、選択フライト情報から作ったフライト情報と、搭乗者の列 `xs` を持つ。Clock の
読み出しはいつも `tJ`（D-014 の前提）。 -/
theorem vacancy_hoare {md : Spec.MasterData} {p : SourceModel.MasterQuery.Providers}
    (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    {env : Env} {w : Spec.Port.World} (hinv : w.Inv) (svc : TicketReserveServiceImpl)
    {f : SourceModel.App.B0.SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    {BC : Spec.MasterData.BoardingClass} {FT : Spec.MasterData.FareType}
    (hb : md.boardingClassOf k.boardingClassCd = some BC) (hft : md.fareTypeOf k.fareTypeCd = some FT)
    {fm : SourceModel.Domain.Model.FlightMaster} (hfm : (mkFlight p f).flightMaster = some fm)
    (hfn : fm.flightName = some k.flightName.val) {fX : Flight} (hfX : w.findForUpdate k = some fX)
    {xs : List SourceModel.Domain.Model.Passenger} (hlen : xs.length ≤ 6)
    {tJ : JLocalDate} {T : Spec.Prim.Date} (hclock : ∀ n, env.clock n = tJ) (hT : dateOfJ tJ = some T) :
    Hoare (AtW env w)
      (TicketReserveServiceImpl.validateAndUpdateVacancy svc
        (some { flight := some (mkFlight p f), passengerList := some (xs.map some) }))
      (fun _ s => ∃ w', Spec.UseCase.Reserve.secureSeats md T xs.length w k = some (.ok w') ∧ AtW env w' s)
      (fun e s => AtW env w s ∧ (IsFault env e ∨ ∃ c, e = AtrsBusinessException.newArgs c [] ∧
        Spec.UseCase.Reserve.secureSeats md T xs.length w k = some (.error (.business c [])))) := by
  intro s ⟨hdb, hse⟩
  obtain ⟨t, sd, ed, hte, hs1, hs2, he1, he2⟩ := mkFlight_days hfq hk hft
  obtain ⟨dj, hdj, hd, -⟩ := keyOfForm_eq hk
  have hdep : (mkFlight p f).departureDate = some dj := by simp only [mkFlight, hdj]
  have hav := isAvailable_eq hs1 hs2 he1 he2 hd hT
  have hkey := mkFlight_key hbq hfq hk hb hft hfn
  rw [hdep, hte] at hkey
  have hc : s.env.clock s.clockReads = tJ := hse ▸ hclock _
  have hsel := select_key_find hdb hinv k
  rw [hfX, Option.toList_some] at hsel
  obtain ⟨r, hsr, hr⟩ := mapM_singleton hsel
  have hfXk : fX.key = k := by
    unfold Spec.Port.World.findForUpdate at hfX
    simpa using List.find?_some hfX
  obtain ⟨L, hL, hLkey, v0, hv0, hv0v⟩ := flightMap_ok hr
  rw [hfXk] at hLkey
  have hrows : findOneForUpdateRows s.db (keyParams k) = [resultOf r] := by
    simp only [findOneForUpdateRows, hsr, Bag.project, List.map_cons, List.map_nil]
    rfl
  java_estate_simp [TicketReserveServiceImpl.validateAndUpdateVacancy, lift, now, hte, hdep, hfm, hc, hav,
    findOneForUpdate, lockQuery, sql, hkey, FlightRepository.update]
  have hn : (Int.J32.ofInt ((List.map some xs).length : Int)).val = (xs.length : Int) := by
    rw [List.length_map]; exact LangSemantics.Java.IntLemmas.ofInt_nat (by omega)
  have hss : Spec.UseCase.Reserve.secureSeats md T xs.length w k =
      if (!Spec.FlightSearch.isAvailableFareType FT k.departureDate T) = true then
        some (.error (.business "e.ar.b2.2008"))
      else if fX.vacantNum < xs.length then some (.error (.business "e.ar.b2.2009"))
      else some (.ok (w.updateVacantNum k (fX.vacantNum - xs.length))) := by
    simp only [Spec.UseCase.Reserve.secureSeats, hft, hfX, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
  rw [hss]
  have hat : ∀ (cr sc : Nat), AtW env w { db := s.db, env := s.env, clockReads := cr, sqlCalls := sc } :=
    fun _ _ => ⟨hdb, hse⟩
  have hbiz : ∀ (c : String), AtrsBusinessException.new (TicketReserveErrorCode.code c) =
      AtrsBusinessException.newArgs c [] := fun c => (AtrsBusinessException.newArgs_nil c).symm
  cases hA : Spec.FlightSearch.isAvailableFareType FT k.departureDate T
  · simp only [Bool.not_false, ite_true]
    exact ⟨hat _ _, .inr ⟨_, hbiz _, rfl⟩⟩
  simp only [Bool.not_true, Bool.false_eq_true, ite_false]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨hat _ _, .inl ⟨_, .inl ⟨rfl, by rw [← hse]; simp [h1]⟩⟩⟩
  by_cases h2 : s.env.conflictAt = some s.sqlCalls
  · simp only [h1, h2, ite_true, ite_false]
    exact ⟨hat _ _, .inl ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h2]⟩⟩⟩
  simp only [h1, h2, ite_false, hrows, hL]
  simp only [Functor.map, EStateM.map, EStateM.pure, LangSemantics.Java.EStateSimp.deref_some, hv0]
  simp only [hn]
  by_cases h9 : fX.vacantNum < xs.length
  · have : v0.val < (xs.length : Int) := by omega
    simp only [this, h9, decide_true, ite_true]
    exact ⟨hat _ _, .inr ⟨_, hbiz _, rfl⟩⟩
  have h9' : ¬ v0.val < (xs.length : Int) := by omega
  simp only [h9', h9, decide_false, Bool.false_eq_true, ite_false]
  by_cases h3 : s.env.ioFailAt = some (s.sqlCalls + 1)
  · simp only [h3, ite_true]
    exact ⟨hat _ _, .inl ⟨_, .inl ⟨rfl, by rw [← hse]; simp [h3]⟩⟩⟩
  by_cases h4 : s.env.conflictAt = some (s.sqlCalls + 1)
  · simp only [h3, h4, ite_true, ite_false]
    exact ⟨hat _ _, .inl ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h4]⟩⟩⟩
  have hvmax : fX.vacantNum ≤ 2147483647 := by
    have := v0.toInt_le
    simp only [Int.J32.val] at hv0v
    omega
  have hsub : (Int.j32sub v0 (Int.J32.ofInt ((List.map some xs).length : Int))).val =
      ((fX.vacantNum - xs.length : Nat) : Int) :=
    LangSemantics.Java.IntLemmas.j32sub_nat hv0v hn (by omega) hvmax
  obtain ⟨fd', hup, hw'⟩ := updateRows_alpha hdb hinv hfX hsub (by omega)
  simp only [h3, h4, ite_false, hLkey, hup]
  simp only [EStateM.modifyGet, EStateM.bind, EStateM.pure]
  have h1' : (Int.J32.ofInt ((1 : Nat) : Int)).val = 1 := by decide
  simp only [h1', ne_eq, not_true_eq_false, decide_false, Bool.false_eq_true, ite_false]
  exact ⟨_, rfl, hw', hse⟩

/-- 予約フライトを順に空席を確保する（[Spec] の `foldlM secureSeats`）。 -/
def secureAll (md : Spec.MasterData) (T : Spec.Prim.Date) (n : Nat) :
    List FlightKey → Spec.Port.World → Option (Except Spec.Error.AtrsError Spec.Port.World)
  | [], w => some (.ok w)
  | k :: ks, w => (Spec.UseCase.Reserve.secureSeats md T n w k).bind fun r =>
    match r with
    | .error e => some (.error e)
    | .ok w' => secureAll md T n ks w'

theorem foldlM_secure (md : Spec.MasterData) (T : Spec.Prim.Date) (n : Nat) :
    ∀ (ks : List FlightKey) (acc : Except Spec.Error.AtrsError Spec.Port.World),
      ks.foldlM (init := acc) (fun acc k => do
          match acc with
          | .error e => return .error e
          | .ok w' => Spec.UseCase.Reserve.secureSeats md T n w' k) =
        match acc with
        | .error e => some (.error e)
        | .ok w => secureAll md T n ks w
  | [], acc => by cases acc <;> rfl
  | k :: ks, acc => by
    rw [List.foldlM_cons]
    cases acc with
    | error e => exact foldlM_secure md T n ks (.error e)
    | ok w =>
      show Option.bind _ _ = Option.bind _ _
      congr 1
      funext r
      exact foldlM_secure md T n ks r

/-- 空席の確保の材料（予約フライトごと）: 主キー、搭乗クラス・運賃種別がマスタにあり、便マスタが便名を持つ。 -/
structure VacCond (md : Spec.MasterData) (p : SourceModel.MasterQuery.Providers)
    (f : SourceModel.App.B0.SelectFlightForm) (k : FlightKey) : Prop where
  key : keyOfForm f = some k
  bc : ∃ BC, md.boardingClassOf k.boardingClassCd = some BC
  ft : ∃ FT, md.fareTypeOf k.fareTypeCd = some FT
  fm : ∃ fm, (mkFlight p f).flightMaster = some fm ∧ fm.flightName = some k.flightName.val

theorem findForUpdate_isSome_of_keys {w w' : Spec.Port.World} (h : w'.flights.map (·.key) = w.flights.map (·.key))
    {k : FlightKey} (hk : (w.findForUpdate k).isSome) : (w'.findForUpdate k).isSome := by
  unfold Spec.Port.World.findForUpdate at hk ⊢
  rw [List.find?_isSome] at hk ⊢
  obtain ⟨g, hg, hgk⟩ := hk
  have : g.key ∈ w'.flights.map (·.key) := h ▸ List.mem_map_of_mem hg
  obtain ⟨g', hg', e⟩ := List.mem_map.mp this
  exact ⟨g', hg', by rw [e]; exact hgk⟩

theorem secureSeats_seq {md : Spec.MasterData} {T : Spec.Prim.Date} {n : Nat} {w w' : Spec.Port.World}
    {k : FlightKey} (h : Spec.UseCase.Reserve.secureSeats md T n w k = some (.ok w')) : w'.sequences = w.sequences := by
  unfold Spec.UseCase.Reserve.secureSeats at h
  simp only [Option.bind_eq_bind] at h
  cases hft : md.fareTypeOf k.fareTypeCd with
  | none => simp [hft] at h
  | some ft =>
    simp only [hft, Option.bind_some] at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · simp only [Option.pure_def, Option.some.injEq, Except.ok.injEq] at h
          subst h
          rfl

/-- 予約フライトの列の空席の確保。例外で終われば、状態の表の採番は変わっていない（取り消しで元に戻る）。 -/
theorem vacancies_hoare {md : Spec.MasterData} {p : SourceModel.MasterQuery.Providers}
    (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    {env : Env} (svc : TicketReserveServiceImpl) {xs : List SourceModel.Domain.Model.Passenger}
    (hlen : xs.length ≤ 6) {tJ : JLocalDate} {T : Spec.Prim.Date} (hclock : ∀ n, env.clock n = tJ)
    (hT : dateOfJ tJ = some T) :
    ∀ {fs : List SourceModel.App.B0.SelectFlightForm} {ks : List FlightKey},
      LangSemantics.Core.List.Forall₂ (VacCond md p) fs ks →
      ∀ {w : Spec.Port.World}, w.Inv → (∀ k ∈ ks, (w.findForUpdate k).isSome) →
      Hoare (AtW env w)
        (forIn (fs.map fun f => some { flight := some (mkFlight p f), passengerList := some (xs.map some) }) ()
          fun rf _ => do
            TicketReserveServiceImpl.validateAndUpdateVacancy svc rf
            pure (ForInStep.yield ()))
        (fun _ s => ∃ w', secureAll md T xs.length ks w = some (.ok w') ∧ AtW env w' s)
        (fun e s => ∃ w', AtW env w' s ∧ w'.sequences = w.sequences ∧ (IsFault env e ∨ ∃ c,
          e = AtrsBusinessException.newArgs c [] ∧ secureAll md T xs.length ks w = some (.error (.business c []))))
  | [], [], .nil, w, _, _ => fun s hs => ⟨w, rfl, hs⟩
  | f :: fs, k :: ks, .cons hc hr, w, hinv, hex => by
    obtain ⟨hk, ⟨BC, hb⟩, ⟨FT, hft⟩, ⟨fm, hfm, hfn⟩⟩ := hc
    obtain ⟨fX, hfX⟩ := Option.isSome_iff_exists.mp (hex k (List.mem_cons_self ..))
    have hv := vacancy_hoare hbq hfq hinv svc hk hb hft hfm hfn hfX hlen hclock hT
    rw [List.map_cons, List.forIn_cons]
    refine Hoare.bind' (R := fun r s => r = .yield () ∧
        ∃ w', Spec.UseCase.Reserve.secureSeats md T xs.length w k = some (.ok w') ∧ AtW env w' s)
      (Hoare.bind' (Hoare.conseq hv (fun _ h => h) (fun _ _ h => h) fun e s ⟨hat, he⟩ => ⟨w, hat, rfl, ?_⟩)
        fun _ => Hoare.pure' fun s h => ⟨rfl, h⟩) fun r => ?_
    · rcases he with he | ⟨c, rfl, hc⟩
      · exact .inl he
      · exact .inr ⟨c, rfl, by simp only [secureAll, hc, Option.bind_some]⟩
    · intro s ⟨hr0, w', hw', hat⟩
      subst hr0
      have hkeys := Spec.UseCase.Reserve.secureSeats_keys hw'
      have hinv' : w'.Inv := by unfold Spec.Port.World.Inv at hinv ⊢; rw [hkeys]; exact hinv
      have hex' : ∀ k ∈ ks, (w'.findForUpdate k).isSome := fun k' hk' =>
        findForUpdate_isSome_of_keys hkeys (hex k' (List.mem_cons_of_mem _ hk'))
      have hseq : w'.sequences = w.sequences := secureSeats_seq hw'
      have ih := vacancies_hoare hbq hfq svc hlen hclock hT hr hinv' hex'
      refine Hoare.conseq ih (fun _ h => h) (fun _ s ⟨w'', hw'', hat''⟩ => ⟨w'', ?_, hat''⟩)
        (fun e s ⟨w'', hat'', hseq'', he⟩ => ⟨w'', hat'', hseq''.trans hseq, ?_⟩) s hat
      · simp only [secureAll, hw', Option.bind_some, hw'']
      · rcases he with he | ⟨c, rfl, hc⟩
        · exact .inl he
        · exact .inr ⟨c, rfl, by simp only [secureAll, hw', Option.bind_some, hc]⟩

end

end Abstraction.Reserve.Vacancy
