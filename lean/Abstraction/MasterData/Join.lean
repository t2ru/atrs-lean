import LangSemantics.Sql.QueryLemmas
import SourceModel.Repository.MasterData

/-!
# Abstraction.MasterData.Join

Mapper の結合の文（`routeFindAll`・`flightMasterFindAll`）の形。空港コード（区間番号）が表の中で一意で、
区間の空港（便マスタの区間）が存在するなら、結合の結果は、左の表の行ごとに 1 行ずつ、同じ順に並ぶ。
-/

namespace Abstraction.MasterData.Join
open LangSemantics.Core.List
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas

open LangSemantics.Sql.Postgresql SourceModel.Repository.Schema
  SourceModel.Repository.MasterData LangSemantics.Core

theorem eqText_holds {m n : Nat} (a : Varchar m) (b : Varchar n) : (eqText a b).holds = (a.val == b.val) :=
  SqlValue.eq_text_holds a.val b.val

theorem eqInt_holds (a b : Int4) : (eqInt a b).holds = (a.val == b.val) :=
  SqlValue.eq_int_holds _ a.val b.val

/-- 区間の行に、出発・到着の空港の行を結合した結果の行。 -/
def routeResultOf (r : RouteRow) (dep arr : AirportRow) : RouteResult :=
  ⟨r.routeNo, r.basicFare, dep.airportCd, dep.airportName, arr.airportCd, arr.airportName⟩

/-- 空港 `ap c` が、コード `c` の空港の行である。 -/
def AirportAt (db : MasterDb) (ap : String → AirportRow) (c : String) : Prop :=
  ap c ∈ db.airport ∧ (ap c).airportCd.val = c

/-- 空港コードが一意な表で、コード `c` の行で選ぶと、その行だけが残る。 -/
theorem filter_airport {db : MasterDb} {ap : String → AirportRow} {c : String}
    (hnd : (db.airport.map (·.airportCd.val)).Nodup) (h : AirportAt db ap c) :
    db.airport.filter (fun d => c == d.airportCd.val) = [ap c] := by
  have := filter_key_eq_singleton (f := fun d : AirportRow => d.airportCd.val) hnd h.1
  rw [← this, h.2]
  exact List.filter_congr fun d _ => by rw [Bool.beq_comm]

/-- `routeFindAll`: 区間の行ごとに、出発・到着の空港を結合した 1 行。 -/
theorem routeFindAll_eq {db : MasterDb} {ap : String → AirportRow}
    (hnd : (db.airport.map (·.airportCd.val)).Nodup)
    (hap : ∀ r ∈ db.route, AirportAt db ap r.depAirportCd.val ∧ AirportAt db ap r.arrAirportCd.val) :
    routeFindAll db = db.route.map fun r => routeResultOf r (ap r.depAirportCd.val) (ap r.arrAirportCd.val) := by
  have e1 : Bag.select (fun ((r, d), a) =>
        (eqText r.depAirportCd d.airportCd).and (eqText r.arrAirportCd a.airportCd))
        (Bag.cross (Bag.cross db.route db.airport) db.airport) =
      ((Bag.cross db.route db.airport).filter (fun x => x.1.depAirportCd.val == x.2.airportCd.val)).map
        fun x => (x, ap x.1.arrAirportCd.val) := by
    unfold Bag.select
    rw [← filter_cross (q := fun x a => x.1.arrAirportCd.val == a.airportCd.val)]
    · exact List.filter_congr fun x _ => by
        obtain ⟨⟨r, d⟩, a⟩ := x
        simp only [Truth.holds_and, eqText_holds]
    · intro x hx _
      exact filter_airport hnd (hap _ (mem_cross.mp hx).1).2
  have e2 : (Bag.cross db.route db.airport).filter (fun x => x.1.depAirportCd.val == x.2.airportCd.val) =
      db.route.map fun r => (r, ap r.depAirportCd.val) := by
    have := filter_cross (xs := db.route) (bs := db.airport) (c := fun _ => true)
      (q := fun r a => r.depAirportCd.val == a.airportCd.val) (g := fun r => ap r.depAirportCd.val)
      (fun r hr _ => filter_airport hnd (hap r hr).1)
    rw [List.filter_eq_self.mpr (fun _ _ => rfl)] at this
    simpa using this
  unfold routeFindAll Bag.project
  rw [e1, e2, List.map_map, List.map_map]
  exact List.map_congr_left fun _ _ => rfl

/-- 便マスタの行に、区間と空港を結合した結果の行。 -/
def flightMasterResultOf (f : FlightMasterRow) (r : RouteRow) (dep arr : AirportRow) : FlightMasterResult :=
  ⟨f.flightName, f.departureTime, f.arrivalTime, f.craftType, routeResultOf r dep arr⟩

/-- 区間 `rt n` が、区間番号 `n` の区間の行である。 -/
def RouteAt (db : MasterDb) (rt : Int → RouteRow) (n : Int) : Prop :=
  rt n ∈ db.route ∧ (rt n).routeNo.val = n

/-- `flightMasterFindAll`: 便マスタの行ごとに、区間と、その出発・到着の空港を結合した 1 行。 -/
theorem flightMasterFindAll_eq {db : MasterDb} {ap : String → AirportRow} {rt : Int → RouteRow}
    (hnd : (db.airport.map (·.airportCd.val)).Nodup) (hrn : (db.route.map (·.routeNo.val)).Nodup)
    (hap : ∀ r ∈ db.route, AirportAt db ap r.depAirportCd.val ∧ AirportAt db ap r.arrAirportCd.val)
    (hrt : ∀ f ∈ db.flightMaster, RouteAt db rt f.routeNo.val) :
    flightMasterFindAll db = db.flightMaster.map fun f =>
      flightMasterResultOf f (rt f.routeNo.val) (ap (rt f.routeNo.val).depAirportCd.val)
        (ap (rt f.routeNo.val).arrAirportCd.val) := by
  have e1 : Bag.select (fun (((f, r), d), a) =>
        ((eqInt f.routeNo r.routeNo).and (eqText r.depAirportCd d.airportCd)).and
          (eqText r.arrAirportCd a.airportCd))
        (Bag.cross (Bag.cross (Bag.cross db.flightMaster db.route) db.airport) db.airport) =
      ((Bag.cross (Bag.cross db.flightMaster db.route) db.airport).filter
        (fun x => x.1.1.routeNo.val == x.1.2.routeNo.val && x.1.2.depAirportCd.val == x.2.airportCd.val)).map
        fun x => (x, ap x.1.2.arrAirportCd.val) := by
    unfold Bag.select
    rw [← filter_cross (q := fun x a => x.1.2.arrAirportCd.val == a.airportCd.val)]
    · exact List.filter_congr fun x _ => by
        obtain ⟨⟨⟨f, r⟩, d⟩, a⟩ := x
        simp only [Truth.holds_and, eqText_holds, eqInt_holds]
    · intro x hx _
      exact filter_airport hnd (hap _ (mem_cross.mp (mem_cross.mp hx).1).2).2
  have e2 : (Bag.cross (Bag.cross db.flightMaster db.route) db.airport).filter
        (fun x => x.1.1.routeNo.val == x.1.2.routeNo.val && x.1.2.depAirportCd.val == x.2.airportCd.val) =
      ((Bag.cross db.flightMaster db.route).filter (fun y => y.1.routeNo.val == y.2.routeNo.val)).map
        fun y => (y, ap y.2.depAirportCd.val) :=
    filter_cross (c := fun y : FlightMasterRow × RouteRow => y.1.routeNo.val == y.2.routeNo.val)
      (q := fun y (d : AirportRow) => y.2.depAirportCd.val == d.airportCd.val) (g := fun y => ap y.2.depAirportCd.val)
      fun y hy _ => filter_airport hnd (hap _ (mem_cross.mp hy).2).1
  have e3 : (Bag.cross db.flightMaster db.route).filter (fun y => y.1.routeNo.val == y.2.routeNo.val) =
      db.flightMaster.map fun f => (f, rt f.routeNo.val) := by
    have := filter_cross (xs := db.flightMaster) (bs := db.route) (c := fun _ => true)
      (q := fun f r => f.routeNo.val == r.routeNo.val) (g := fun f => rt f.routeNo.val) fun f hf _ => by
        have := filter_key_eq_singleton (f := fun r : RouteRow => r.routeNo.val) hrn (hrt f hf).1
        rw [← this, (hrt f hf).2]
        exact List.filter_congr fun r _ => by rw [Bool.beq_comm]
    rw [List.filter_eq_self.mpr (fun _ _ => rfl)] at this
    simpa using this
  unfold flightMasterFindAll Bag.project
  rw [e1, e2, e3, List.map_map, List.map_map, List.map_map]
  exact List.map_congr_left fun _ _ => rfl

end Abstraction.MasterData.Join
