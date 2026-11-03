import Abstraction.FlightSearch.Join
import Abstraction.FlightSearch.Period
import Abstraction.MasterData.Query

/-!
# Abstraction.FlightSearch.Candidates

ABS-011 の補題: FLIGHT の行ごとの結合の結果（`Join.rowAt`）と、[Spec] の候補（`candidateOf`）の対応。

- マスタの引き方の対応: DB の表の `find?`（コード・便名・空港コード）の α は、[Spec] の `fareTypeOf`・`flightMasterOf`・
  `routeOf`（`fareTypeOf_find`・`flightMasterOf_find`・`routeOf_find`）。
- 条件の対応: 束縛した値が照会条件の写しなら、文の条件は候補の条件と同値（`rowAt_rel`）。結果の行は、候補のフライトの
  行と、運賃種別の表示順・便マスタの出発時刻を持つ（`RowRel`）。
-/

namespace Abstraction.FlightSearch.Candidates
open Abstraction.World.Alpha
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.MasterData.Query
open Abstraction.MasterData.Pre Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Join
open LangSemantics.Sql.Core LangSemantics.Core.MapM Machine.Kernel Spec.Model
  Spec.FlightSearch

open LangSemantics.Sql.Postgresql SourceModel.Db.Schema SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository
  Spec.Prim Spec.MasterData SourceModel.Domain.Repository.Route SourceModel.Domain.Repository.Route.RouteRepository
  SourceModel.Domain.Repository.Boardingclass SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository SourceModel.Domain.Repository.Faretype SourceModel.Domain.Repository.Faretype.FareTypeRepository
  SourceModel.Domain.Repository.Peaktime SourceModel.Domain.Repository.Peaktime.PeakTimeRepository SourceModel.Config.App SourceModel.Config.App.AtrsCodeListConfig
  Abstraction.MasterData.Join Abstraction.FlightSearch.Period

/-! ## マスタの引き方 -/

theorem fareTypeOf_find {db : MasterDb} {md : Spec.MasterData} (hm : masterDataOf db = some md) (s : String)
    {cd : FareTypeCd} (hcd : ftCdOf s = some cd) :
    md.fareTypeOf cd = (db.fareType.find? fun ft => ft.fareTypeCd.val == s).bind fareTypeOfRow := by
  obtain ⟨-, -, -, -, hfts, -⟩ := masterDataOf_eq_some.mp hm
  unfold Spec.MasterData.fareTypeOf
  refine find?_mapM hfts fun r x hx => ?_
  have e := fareTypeOfRow_code hx
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]
  constructor
  · rintro rfl; exact inj_of_kernel ftCdOf_kernel e hcd
  · rintro h; rw [h] at e; rw [hcd] at e; exact (Option.some.inj e).symm

theorem flightMasterOf_find {db : MasterDb} {md : Spec.MasterData} (hm : masterDataOf db = some md) (s : String) :
    md.flightMasterOf ⟨s⟩ = (db.flightMaster.find? fun fm => fm.flightName.val == s).bind flightMasterOfRow := by
  obtain ⟨-, -, hfms, -⟩ := masterDataOf_eq_some.mp hm
  unfold Spec.MasterData.flightMasterOf
  refine find?_mapM hfms fun r x hx => ?_
  rw [(flightMasterOfRow_fields hx).2]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, FlightName.mk.injEq]

theorem routeOf_find {db : MasterDb} {md : Spec.MasterData} (hm : masterDataOf db = some md) (dep arr : String) :
    md.routeOf dep arr = (db.route.find? fun r => routeKey r == (dep, arr)).bind routeOfRow := by
  obtain ⟨-, hrts, -⟩ := masterDataOf_eq_some.mp hm
  unfold Spec.MasterData.routeOf
  refine find?_mapM hrts fun r x hx => ?_
  obtain ⟨e1, e2⟩ := routeOfRow_codes hx
  rw [e1, e2, Bool.eq_iff_iff]
  simp only [routeKey, Bool.and_eq_true, beq_iff_eq, Prod.mk.injEq]

/-! ## 結合の結果と候補 -/

/-- FLIGHT の行の、文の結果の列。 -/
def resultOf (f : FlightRow) : FlightResult :=
  ⟨f.departureDate, f.flightName, f.fareTypeCd, f.vacantNum, f.boardingClassCd⟩

/-- 結果の行と候補の対応: 行は FLIGHT の行 `f` の列と、運賃種別の表示順・便マスタの出発時刻の写し。 -/
def RowRel (f : FlightRow) (row : VacantSeatRow) (X : Candidate) : Prop :=
  row.result = resultOf f ∧ flightOfRow f = some X.flight ∧ natOfInt4 row.displayOrder = some X.fareType.displayOrder ∧
    hmOfStr row.departureTime.val = some X.master.departureTime

/-- 照会条件の写しを束縛した値。 -/
def paramsOf (c : Criteria) (dep arr : String) (bdn : Int) : Params :=
  ⟨(fareTypesFor c.flightType).map fun t => .text t.toCode, .text dep, .text arr, .date c.depDate.epochDay,
    .text c.boardingClassCd.toCode, .int bdn⟩

theorem toCode_contains (xs : List FareTypeCd) (t : FareTypeCd) :
    (xs.map FareTypeCd.toCode).contains t.toCode = decide (t ∈ xs) := by
  have hinj : ∀ a b : FareTypeCd, a.toCode = b.toCode → a = b := by
    intro a b h; cases a <;> cases b <;> first | rfl | (simp [FareTypeCd.toCode] at h)
  induction xs with
  | nil => simp
  | cons x xs ih =>
    simp only [List.map_cons, List.contains_cons, ih, List.mem_cons]
    by_cases h : t = x
    · subst h; simp
    · have : (t.toCode == x.toCode) = false := by simp; exact fun e => h (hinj _ _ e)
      simp [this, h]

theorem fareTypeOfRow_fields {r : FareTypeRow} {x : FareType} (h : fareTypeOfRow r = some x) :
    (x.rsrvAvailableStartDayNum : Int) = r.rsrvAvailableStartDayNum.val ∧
      (x.rsrvAvailableEndDayNum : Int) = r.rsrvAvailableEndDayNum.val ∧ natOfInt4 r.displayOrder = some x.displayOrder := by
  simp only [fareTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, _, _, s, hs, e, he, _, _, d, hd, rfl⟩ := h
  exact ⟨(natOfInt4_eq_some.mp hs).symm, (natOfInt4_eq_some.mp he).symm, hd⟩

theorem flightMasterOfRow_dep {f : FlightMasterRow} {x : FlightMaster} (h : flightMasterOfRow f = some x) :
    hmOfStr f.departureTime.val = some x.departureTime := by
  simp only [flightMasterOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨_, _, dt, hdt, _, _, rfl⟩ := h
  exact hdt

theorem routeOfRow_no {r : RouteRow} {x : Route} (h : routeOfRow r = some x) : (x.routeNo : Int) = r.routeNo.val := by
  simp only [routeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨no, hno, _, _, _, _, _, _, rfl⟩ := h
  exact (natOfInt4_eq_some.mp hno).symm

theorem inList_codes_holds (a : String) (xs : List FareTypeCd) :
    (inList Collation.codepoint (.text a) (xs.map fun t => .text t.toCode)).holds = (xs.map FareTypeCd.toCode).contains a := by
  have : (xs.map fun t => SqlValue.text t.toCode) = (xs.map FareTypeCd.toCode).map SqlValue.text := by simp
  rw [this, inList_text_holds]

theorem bc_toCode_inj {a b : BoardingClassCd} : a.toCode = b.toCode ↔ a = b := by
  constructor
  · intro h; cases a <;> cases b <;> first | rfl | (simp [BoardingClassCd.toCode] at h)
  · rintro rfl; rfl

/-- 束縛した値が照会条件の写しで、運賃種別・便マスタ・区間の行がフライトの行のキーで引いたものなら、文の条件は
候補の条件と同値。 -/
theorem cond_holds {c : Criteria} {dep arr : String} {bdn : Int} {f : FlightRow} {ftr : FareTypeRow}
    {fmr : FlightMasterRow} {r0 : RouteRow} {d : Date} {bc : BoardingClassCd} {ftc : FareTypeCd} {ftX : FareType}
    {fmX : FlightMaster} {route : Route}
    (hc : (ftr.fareTypeCd.val == f.fareTypeCd.val) = true) (hn : (fmr.flightName.val == f.flightName.val) = true)
    (hk : (routeKey r0 == (dep, arr)) = true) (hd : dateOfPg f.departureDate = some d)
    (hbc : bcCdOf f.boardingClassCd.val = some bc) (hft : ftCdOf f.fareTypeCd.val = some ftc)
    (hftX : fareTypeOfRow ftr = some ftX) (hfmX : flightMasterOfRow fmr = some fmX) (hrX : routeOfRow r0 = some route) :
    (vacantSeatCond (paramsOf c dep arr bdn) (((f, ftr), fmr), r0)).holds =
      decide (d = c.depDate ∧ fmX.routeNo = route.routeNo ∧ bc = c.boardingClassCd ∧ ftc ∈ fareTypesFor c.flightType ∧
        availableOnDayNum ftX bdn = true) := by
  simp only [beq_iff_eq] at hc hn
  simp only [routeKey, beq_iff_eq, Prod.mk.injEq] at hk
  obtain ⟨hs, he, -⟩ := fareTypeOfRow_fields hftX
  have hfr := (flightMasterOfRow_fields hfmX).1
  have hrr := routeOfRow_no hrX
  have hde := Date.epochDay_ofEpochDay? hd
  simp only [vacantSeatCond, paramsOf, Truth.holds_and, eqText_holds, eqInt_holds, Varchar.toSql, PgDate.toSql,
    Int4.toSql, between_int_holds]
  simp only [collationC]
  simp only [inList_codes_holds, SqlValue.eq_text_holds, SqlValue.eq_date_holds]
  simp only [hc, hn, hk.1, hk.2, beq_self_eq_true, Bool.true_and, ftCdOf_eq_some hft, bcCdOf_eq_some hbc,
    toCode_contains, availableOnDayNum, ← hs, ← he, ← hfr, ← hrr, ← hde]
  rw [Bool.eq_iff_iff]
  simp only [Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, bc_toCode_inj]
  constructor
  · rintro ⟨h1, h2, h3, h4, h5, h6⟩
    exact ⟨Date.epochDay_inj h3, by omega, h4, h1, h5, h6⟩
  · rintro ⟨rfl, h2, h3, h4, h5, h6⟩
    exact ⟨h4, by omega, rfl, h3, h5, h6⟩

/-- FLIGHT の行 1 つについて、文の結果の行と [Spec] の候補が対応する（両方とも無いか、両方ともあって `RowRel`）。 -/
theorem rowAt_rel {db : MasterDb} {md : Spec.MasterData} (hm : masterDataOf db = some md) {c : Criteria}
    {dep arr : String} {route : Route} (hroute : md.routeOf dep arr = some route) (bdn : Int)
    {f : FlightRow} {F : Flight} (hf : flightOfRow f = some F) :
    Option.Rel (RowRel f) (rowAt db (paramsOf c dep arr bdn) dep arr f) (candidateOf md c route bdn F) := by
  have hf0 := hf
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hf
  obtain ⟨d, hd, bc, hbc, ftc, hft, v, hv, rfl⟩ := hf
  obtain ⟨-, hrts, hfms, -, hfts, -⟩ := masterDataOf_eq_some.mp hm
  rw [routeOf_find hm] at hroute
  obtain ⟨r0, hr0, hrX⟩ := Option.bind_eq_some_iff.mp hroute
  unfold rowAt candidateOf
  rw [flightMasterOf_find hm, fareTypeOf_find hm _ hft, hr0]
  cases hA : db.fareType.find? fun ft => ft.fareTypeCd.val == f.fareTypeCd.val with
  | none =>
    cases (db.flightMaster.find? fun fm => fm.flightName.val == f.flightName.val) <;>
      simp only [Option.bind_none, Option.bind_some] <;> first | exact .none | (cases flightMasterOfRow _ <;> exact .none)
  | some ftr =>
    obtain ⟨ftX, -, hftX⟩ := mapM_some_mem hfts (List.mem_of_find?_eq_some hA)
    have hc := List.find?_some hA
    cases hB : db.flightMaster.find? fun fm => fm.flightName.val == f.flightName.val with
    | none => exact .none
    | some fmr =>
      obtain ⟨fmX, -, hfmX⟩ := mapM_some_mem hfms (List.mem_of_find?_eq_some hB)
      have hn := List.find?_some hB
      have hk := List.find?_some hr0
      simp only [Option.bind_eq_bind, Option.bind_some, hftX, hfmX]
      rw [cond_holds hc hn hk hd hbc hft hftX hfmX hrX]
      split <;> split <;> rename_i h1 h2 <;> simp only [decide_eq_true_eq] at h1
      · exact .some ⟨rfl, hf0, (fareTypeOfRow_fields hftX).2.2, flightMasterOfRow_dep hfmX⟩
      · exact absurd h1 h2
      · exact absurd h2 h1
      · exact .none

/-! ## 結果の行から候補へ -/

/-- 結果の列から FLIGHT の行を作り直す。 -/
def rowFlight (r : FlightResult) : FlightRow :=
  ⟨r.departureDate, r.flightName, r.boardingClassCd, r.fareTypeCd, r.vacantNum⟩

/-- 結果の行の α: フライトの行の写しと、その便名・運賃種別のマスタの組（[Spec] の候補の形）。 -/
def candOfRow (md : Spec.MasterData) (row : VacantSeatRow) : Option Candidate := do
  let F ← flightOfRow (rowFlight row.result)
  let fm ← md.flightMasterOf F.key.flightName
  let ft ← md.fareTypeOf F.key.fareTypeCd
  pure ⟨F, fm, ft⟩

/-- 結果の行が候補 `X` に写り、整列キーの列が `X` の運賃種別の表示順・便マスタの出発時刻の写しである。 -/
def RowOk (md : Spec.MasterData) (row : VacantSeatRow) (X : Candidate) : Prop :=
  candOfRow md row = some X ∧ natOfInt4 row.displayOrder = some X.fareType.displayOrder ∧
    hmOfStr row.departureTime.val = some X.master.departureTime

theorem candidateOf_parts {md : Spec.MasterData} {c : Criteria} {route : Route} {bdn : Int} {F : Flight} {X : Candidate}
    (h : candidateOf md c route bdn F = some X) :
    X.flight = F ∧ md.flightMasterOf F.key.flightName = some X.master ∧ md.fareTypeOf F.key.fareTypeCd = some X.fareType := by
  unfold candidateOf at h
  simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
  obtain ⟨fm, hfm, ft, hft, h⟩ := h
  split at h
  · cases h; exact ⟨rfl, hfm, hft⟩
  · cases h

theorem rowOk_of_rel {md : Spec.MasterData} {c : Criteria} {route : Route} {bdn : Int} {f : FlightRow} {F : Flight}
    {row : VacantSeatRow} {X : Candidate} (hr : RowRel f row X) (hX : candidateOf md c route bdn F = some X) :
    RowOk md row X := by
  obtain ⟨h1, h2, h3, h4⟩ := hr
  obtain ⟨e1, e2, e3⟩ := candidateOf_parts hX
  subst e1
  refine ⟨?_, h3, h4⟩
  have : rowFlight row.result = f := by rw [h1]; rfl
  simp only [candOfRow, this, h2, Option.bind_eq_bind, Option.bind_some, e2, e3, Option.pure_def]

/-- 列の対応: FLIGHT の行の列の写しが `fs` なら、文の結果の行の列（`rowAt` で絞ったもの）は、`candOfRow` で
[Spec] の候補の列（`candidateOf` で絞ったもの）に写り、各行は `RowOk`。 -/
theorem rows_cands {db : MasterDb} {md : Spec.MasterData} (hm : masterDataOf db = some md) {c : Criteria}
    {dep arr : String} {route : Route} (hroute : md.routeOf dep arr = some route) (bdn : Int)
    {fl : List FlightRow} {fs : List Flight} (h : fl.mapM flightOfRow = some fs) :
    (fl.filterMap (rowAt db (paramsOf c dep arr bdn) dep arr)).mapM (candOfRow md) =
        some (fs.filterMap (candidateOf md c route bdn)) ∧
      ∀ row ∈ fl.filterMap (rowAt db (paramsOf c dep arr bdn) dep arr),
        ∃ X ∈ fs.filterMap (candidateOf md c route bdn), RowOk md row X := by
  induction fl generalizing fs with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; simp
  | cons f fl ih =>
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨F, hF, fs', hfs', rfl⟩ := h
    obtain ⟨ih1, ih2⟩ := ih hfs'
    have hrel := rowAt_rel hm hroute bdn (c := c) hF
    rw [List.filterMap_cons, List.filterMap_cons]
    generalize hro : rowAt db (paramsOf c dep arr bdn) dep arr f = ro at hrel ⊢
    generalize hco : candidateOf md c route bdn F = co at hrel ⊢
    cases hrel with
    | none => exact ⟨ih1, ih2⟩
    | some hr =>
      rename_i row X
      have hok := rowOk_of_rel hr hco
      refine ⟨?_, ?_⟩
      · simp only [List.mapM_cons, hok.1, ih1, Option.pure_def, Option.bind_eq_bind, Option.bind_some]
      · intro r hr'
        rcases List.mem_cons.mp hr' with rfl | hr'
        · exact ⟨X, List.mem_cons_self .., hok⟩
        · obtain ⟨Y, hY, hok'⟩ := ih2 r hr'
          exact ⟨Y, List.mem_cons_of_mem _ hY, hok'⟩

end Abstraction.FlightSearch.Candidates
