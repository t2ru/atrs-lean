import Abstraction.World.Alpha
import Spec.Seed.World
import SourceModel.Db.Seed

/-!
# Abstraction.World.Init

初期状態の対応（ABS-011・ABS-041 の INIT）: シードを投入した後の状態の表（[Source] の初期状態 `seedDb`）は、α `worldOfDb`
で、シードを投入した後の `World`（[Spec] の初期状態 `Spec.Seed.World.world`）に写り、具体側の不変条件 `IcW` を満たす。

FLIGHT は、両方とも生成器 `flight_seed.py` が同じ形（日付の列 × 便名の列 × 枠の列、空席数のパターン 3）で書き出すので、
日付の列（121 個）と、パターンごとの便名・枠・空席数の組（3 × 1260 個）をカーネルで照合し（`days_map`・`cells_map`）、
全件（15 万行）には展開せずに、生成の形の上で合成する。MEMBER・MEMBER_LOGIN（7 行。生成器 `member_seed.py`）は
カーネルで照合する。予約の表は空、シーケンスは会員だけが使われている。
-/

namespace Abstraction.World.Init
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.World.Alpha Spec.Model

open LangSemantics.Sql.Postgresql SourceModel.Db.Schema Spec.Prim

namespace FS
open SourceModel.Db.FlightSeed

/-- 1 日分の行の、日付を除いた成分（便名・搭乗クラス・運賃種別・空席数）の列。 -/
def cells (vs : List (List Int4)) : List (Varchar 6 × Varchar 1 × Varchar 4 × Int4) :=
  (names.zip vs).flatMap fun (n, row) => (slots.zip row).map fun ((b, f), v) => (n, b, f, v)

theorem dayRows_eq (d : PgDate) (vs : List (List Int4)) :
    dayRows d vs = (cells vs).map fun c => ⟨d, c.1, c.2.1, c.2.2.1, c.2.2.2⟩ := by
  simp only [dayRows, cells, List.map_flatMap, List.map_map]
  rfl

end FS

namespace SF
open Spec.Seed.Flight

/-- 1 日分のフライトの、日付を除いた成分の列。 -/
def cells (vs : List (List Nat)) : List (FlightName × BoardingClassCd × FareTypeCd × Nat) :=
  (names.zip vs).flatMap fun (n, row) => (slots.zip row).map fun ((b, f), v) => (n, b, f, v)

theorem dayFlights_eq (d : Date) (vs : List (List Nat)) :
    dayFlights d vs = (cells vs).map fun c => ⟨⟨d, c.1, c.2.1, c.2.2.1⟩, c.2.2.2⟩ := by
  simp only [dayFlights, cells, List.map_flatMap, List.map_map]
  rfl

end SF

/-- 日付を除いた成分の α（`flightOfRow` の日付以外の部分）。 -/
def cellOf (c : Varchar 6 × Varchar 1 × Varchar 4 × Int4) : Option (FlightName × BoardingClassCd × FareTypeCd × Nat) := do
  let bc ← bcCdOf c.2.1.val
  let ft ← ftCdOf c.2.2.1.val
  let v ← natOfInt4 c.2.2.2
  pure (⟨c.1.val⟩, bc, ft, v)

theorem days_map :
    SourceModel.Db.FlightSeed.days.mapM dateOfPg = some Spec.Seed.Flight.days := by
  decide +kernel

theorem cells_map0 :
    (FS.cells SourceModel.Db.FlightSeed.vacant0).mapM cellOf = some (SF.cells Spec.Seed.Flight.vacant0) := by
  decide +kernel

theorem cells_map1 :
    (FS.cells SourceModel.Db.FlightSeed.vacant1).mapM cellOf = some (SF.cells Spec.Seed.Flight.vacant1) := by
  decide +kernel

theorem cells_map2 :
    (FS.cells SourceModel.Db.FlightSeed.vacant2).mapM cellOf = some (SF.cells Spec.Seed.Flight.vacant2) := by
  decide +kernel

theorem cells_map (i : Nat) :
    (FS.cells (SourceModel.Db.FlightSeed.pattern i)).mapM cellOf =
      some (SF.cells (Spec.Seed.Flight.pattern i)) := by
  unfold SourceModel.Db.FlightSeed.pattern Spec.Seed.Flight.pattern
  split
  · exact cells_map0
  · split
    · exact cells_map1
    · exact cells_map2

/-- 日付を写せる日の 1 日分の行は、その日の 1 日分のフライトに写る。 -/
theorem mapM_day {d : PgDate} {d' : Date} (hd : dateOfPg d = some d')
    (cs : List (Varchar 6 × Varchar 1 × Varchar 4 × Int4)) {cs' : List (FlightName × BoardingClassCd × FareTypeCd × Nat)}
    (h : cs.mapM cellOf = some cs') :
    (cs.map fun c => (⟨d, c.1, c.2.1, c.2.2.1, c.2.2.2⟩ : FlightRow)).mapM flightOfRow =
      some (cs'.map fun c => (⟨⟨d', c.1, c.2.1, c.2.2.1⟩, c.2.2.2⟩ : Flight)) := by
  induction cs generalizing cs' with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | cons c cs ih =>
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨x, hx, xs, hxs, rfl⟩ := h
    simp only [List.map_cons, List.mapM_cons, Option.pure_def, Option.bind_eq_bind, ih hxs]
    simp only [cellOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hx
    obtain ⟨bc, hbc, ft, hft, v, hv, rfl⟩ := hx
    simp [flightOfRow, hd, hbc, hft, hv]

/-- 日付の列と、日の番号ごとの 1 日分の写しから、全体の写し。 -/
theorem mapM_days {ds : List PgDate} {ds' : List Date} (h : ds.mapM dateOfPg = some ds') (k : Nat) :
    ((ds.zipIdx k).flatMap fun (d, i) => SourceModel.Db.FlightSeed.dayRows d
        (SourceModel.Db.FlightSeed.pattern i)).mapM flightOfRow =
      some ((ds'.zipIdx k).flatMap fun (d, i) => Spec.Seed.Flight.dayFlights d (Spec.Seed.Flight.pattern i)) := by
  induction ds generalizing ds' k with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | cons d ds ih =>
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨d', hd, ds'', hds, rfl⟩ := h
    rw [List.zipIdx_cons, List.zipIdx_cons, List.flatMap_cons, List.flatMap_cons, List.mapM_append, ih hds (k + 1)]
    simp only
    rw [FS.dayRows_eq, mapM_day hd _ (cells_map k), SF.dayFlights_eq]
    rfl

/-- シードの FLIGHT 表は、シードのフライトに写る。 -/
theorem flights_seed :
    SourceModel.Db.Seed.seedDb.flight.mapM flightOfRow = some Spec.Seed.World.world.flights := by
  simp only [SourceModel.Db.Seed.seedDb, SourceModel.Db.FlightSeed.seedFlightDb, Spec.Seed.World.world,
    Spec.Seed.Flight.world, mapM_days days_map 0]

/-- シードの MEMBER・MEMBER_LOGIN は、シードの会員に写る。 -/
theorem members_seed :
    membersOf SourceModel.Db.MemberSeed.memberRows SourceModel.Db.MemberSeed.memberLoginRows =
      some Spec.Seed.Member.members := by
  decide +kernel

/-- 初期状態の対応: シードを投入した後の状態の表は、シードを投入した後の `World` に写る。 -/
theorem worldOfDb_seed : worldOfDb SourceModel.Db.Seed.seedDb = some Spec.Seed.World.world :=
  worldOfDb_eq_some.mpr ⟨flights_seed, members_seed, rfl, rfl⟩

/-- 初期状態は具体側の不変条件を満たす（予約が無い）。 -/
theorem icW_seed : IcW SourceModel.Db.Seed.seedDb := fun w h => by
  rw [worldOfDb_seed] at h
  cases h
  refine ⟨by decide, fun r hr => ?_⟩
  simp [Spec.Seed.World.world] at hr

end Abstraction.World.Init
