import Abstraction.FlightSearch.Alpha
import Abstraction.MasterData.Join

/-!
# Abstraction.FlightSearch.Join

ABS-011 の補題: 空席照会の文の結合（FLIGHT × FARE_TYPE × FLIGHT_MASTER × ROUTE）は、運賃種別のコード・便名・
区間の空港コードの組がそれぞれ表の中で重複しなければ、FLIGHT の行ごとに、対応する運賃種別・便マスタ・区間の行を
`find?` で引いて条件を評価したものに等しい（`vacantSeatRows_eq`）。キーが重複しないことは MD-1・MD-2 から出る。
-/

namespace Abstraction.FlightSearch.Join
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas Abstraction.MasterData.Join

open LangSemantics.Sql.Postgresql SourceModel.Repository.Schema SourceModel.Repository.MasterData
  SourceModel.Repository.Flight

/-- 区間の行を引くキー（出発・到着の空港コード）。 -/
def routeKey (r : RouteRow) : String × String := (r.depAirportCd.val, r.arrAirportCd.val)

/-- FLIGHT の行 1 つの結果: 運賃種別・便マスタ・区間の行を引き、条件を満たせば結果の行。 -/
def rowAt (db : MasterDb) (p : Params) (dep arr : String) (f : FlightRow) : Option VacantSeatRow :=
  (db.fareType.find? fun ft => ft.fareTypeCd.val == f.fareTypeCd.val).bind fun ft =>
  (db.flightMaster.find? fun fm => fm.flightName.val == f.flightName.val).bind fun fm =>
  (db.route.find? fun r => routeKey r == (dep, arr)).bind fun r =>
  if (vacantSeatCond p (((f, ft), fm), r)).holds then some (vacantSeatProj (((f, ft), fm), r)) else none

theorem map_filter_eq_filterMap {α β : Type} (l : List α) (p : α → Bool) (f : α → β) :
    (l.filter p).map f = l.filterMap fun x => if p x then some (f x) else none := by
  induction l with
  | nil => rfl
  | cons x l ih => by_cases h : p x <;> simp [List.filter_cons, h, ih]

theorem text_eq_holds (a b : String) : (SqlValue.eq collationC (.text a) (.text b)).holds = (a == b) :=
  SqlValue.eq_text_holds a b

/-- 結合: 運賃種別のコード・便名・区間の空港コードの組が重複しなければ、文の結果は FLIGHT の行ごとの `rowAt`。 -/
theorem vacantSeatRows_eq {db : MasterDb} {fd : FlightDb} {p : Params} {dep arr : String}
    (hft : (db.fareType.map (·.fareTypeCd.val)).Nodup) (hfm : (db.flightMaster.map (·.flightName.val)).Nodup)
    (hrt : (db.route.map routeKey).Nodup) (hdep : p.depAirportCd = .text dep) (harr : p.arrAirportCd = .text arr) :
    vacantSeatRows db fd p = fd.flight.filterMap (rowAt db p dep arr) := by
  unfold vacantSeatRows Bag.project Bag.select
  rw [map_filter_eq_filterMap]
  -- 区間（最も外の直積）
  rw [filterMap_cross _ db.route (fun x r => if (vacantSeatCond p (x, r)).holds then some (vacantSeatProj (x, r)) else none)
    (fun _ => db.route.find? fun r => routeKey r == (dep, arr)) ?hr]
  case hr =>
    intro x _
    apply filterMap_unique db.route routeKey (dep, arr) _ hrt
    intro r _ hne
    obtain ⟨⟨f, ft⟩, fm⟩ := x
    have : (vacantSeatCond p (((f, ft), fm), r)).holds = false := by
      simp only [vacantSeatCond, Truth.holds_and, hdep, harr, Varchar.toSql, collationC, SqlValue.eq_text_holds]
      have : ¬ (r.depAirportCd.val = dep ∧ r.arrAirportCd.val = arr) := fun ⟨a, b⟩ => hne (by simp [routeKey, a, b])
      by_cases a : r.depAirportCd.val = dep
      · have b : (r.arrAirportCd.val == arr) = false := by simp; exact fun e => this ⟨a, e⟩
        simp [b]
      · have b : (r.depAirportCd.val == dep) = false := by simp [a]
        simp [b]
    simp [this]
  -- 便マスタ
  rw [filterMap_cross _ db.flightMaster
    (fun x fm => (db.route.find? fun r => routeKey r == (dep, arr)).bind fun r =>
      if (vacantSeatCond p ((x, fm), r)).holds then some (vacantSeatProj ((x, fm), r)) else none)
    (fun x => db.flightMaster.find? fun fm => fm.flightName.val == x.1.flightName.val) ?hm]
  case hm =>
    intro x _
    apply filterMap_unique db.flightMaster (·.flightName.val) x.1.flightName.val _ hfm
    intro fm _ hne
    obtain ⟨f, ft⟩ := x
    cases (db.route.find? fun r => routeKey r == (dep, arr)) with
    | none => rfl
    | some r =>
      have : (vacantSeatCond p (((f, ft), fm), r)).holds = false := by
        simp only [vacantSeatCond, Truth.holds_and, eqText_holds]
        have : (f.flightName.val == fm.flightName.val) = false := by simp; exact fun e => hne e.symm
        simp [this]
      simp [this]
  -- 運賃種別
  rw [filterMap_cross _ db.fareType
    (fun f ft => (db.flightMaster.find? fun fm => fm.flightName.val == f.flightName.val).bind fun fm =>
      (db.route.find? fun r => routeKey r == (dep, arr)).bind fun r =>
      if (vacantSeatCond p (((f, ft), fm), r)).holds then some (vacantSeatProj (((f, ft), fm), r)) else none)
    (fun f => db.fareType.find? fun ft => ft.fareTypeCd.val == f.fareTypeCd.val) ?hf]
  case hf =>
    intro f _
    apply filterMap_unique db.fareType (·.fareTypeCd.val) f.fareTypeCd.val _ hft
    intro ft _ hne
    cases (db.flightMaster.find? fun fm => fm.flightName.val == f.flightName.val) with
    | none => rfl
    | some fm =>
      cases (db.route.find? fun r => routeKey r == (dep, arr)) with
      | none => rfl
      | some r =>
        have : (vacantSeatCond p (((f, ft), fm), r)).holds = false := by
          simp only [vacantSeatCond, Truth.holds_and, eqText_holds]
          have : (f.fareTypeCd.val == ft.fareTypeCd.val) = false := by simp; exact fun e => hne e.symm
          simp [this]
        simp [this]
  rfl

end Abstraction.FlightSearch.Join
