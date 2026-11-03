import Lean.Data.Json
import SourceModel
import Tests.Conformance
import Tests.MasterSql

/-!
# Tests.FlightSql

空席照会の文 `findByVacantSeatSearchCriteria` の差分実行（backlog 0be7 の第 2 段）。
`conformance/sql/flight-search.json`（`tools/conformance/master_sql.py` が PostgreSQL で生成）と照合する。

- FLIGHT 表: PostgreSQL に投入した表は、生成器 `flight_seed.py` の展開と md5 で照合済み（生成器の側）。ここでは、
  `SourceModel.Db.FlightSeed.seedFlightDb` の全行（生成順）の行数と多項式ハッシュが、同じ展開の値と一致することを
  確かめる。こうして PostgreSQL の表と `seedFlightDb` が結ばれる。
- 各条件: マスタの表（`master-data.json` の `tables`）と `seedFlightDb` から `vacantSeatRowsOn`（条件の押し下げ。
  `vacantSeatRows_eq_on` で `vacantSeatRows` に等しい）を評価し、PostgreSQL の結果の並びが許される並び
  （`isAllowedOrder`）であること、列の値が一致すること、結果の写像 `flight-map` が例外を投げず、写した値が列と一致することを
  確かめる。束縛する値は、原典の条件 `VacantSeatSearchCriteriaDto` から `bind`（MyBatis の型ハンドラの写し）で作る。
-/

open Lean LangSemantics.Sql.Core LangSemantics.Sql.Postgresql LangSemantics.Sql.Query
  SourceModel.Db.Schema SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository ConformanceKit
  Tests.Conformance

open ConformanceKit.SqlTable ConformanceKit.Runner

namespace Tests.FlightSql

def polyMod : Nat := 2 ^ 61 - 1

/-- 文字列の多項式ハッシュ（`master_sql.py` の `poly_hash` と同じ）。 -/
def polyHash (h : Nat) (s : String) : Nat := s.foldl (fun h c => (h * 31 + c.toNat) % polyMod) h

/-- FLIGHT の行の正規の 1 行（`yyyy-MM-dd,便名,搭乗クラス,運賃種別,空席数` と改行）。 -/
def canon (r : FlightRow) : String :=
  s!"{(Tests.MasterSql.sD r.departureDate).getD "?"},{r.flightName.val},{r.boardingClassCd.val},{r.fareTypeCd.val},{r.vacantNum.val}\n"

/-- `seedFlightDb` の（行数, 多項式ハッシュ）。 -/
def seedSummary : Nat × Nat :=
  let rows := SourceModel.Db.FlightSeed.seedFlightDb.flight
  (rows.length, rows.foldl (fun h r => polyHash h (canon r)) 0)

/-- 束縛した値（`params`）から、原典の `VacantSeatSearchCriteriaDto` を作る（`bind` が SQL の値にする）。 -/
def criteria (p : Json) : Except String VacantSeatSearchCriteriaDto := do
  let d ← decodeDate (← getStr p "depDate")
  let ld ← need (LangSemantics.Java.JLocalDate.ofYMD? d.year d.month d.day) "depDate"
  let bc ← need (Spec.Model.BoardingClassCd.ofCode? (← getStr p "boardingClass")) "boardingClass"
  let fts ← (← getArr p "fareTypeList").mapM fun j => do
    match j with
    | .str s => need (Spec.Model.FareTypeCd.ofCode? s) s!"fare type {s}"
    | _ => throw "fareTypeList"
  return { boardingClass := some bc, depDate := some ld,
           route := some { departureAirport := some { code := some (← getStr p "depAirportCd") },
                           arrivalAirport := some { code := some (← getStr p "arrAirportCd") } },
           beforeDayNum := some (LangSemantics.Java.Int.J64.ofInt (← getInt p "beforeDayNum")),
           fareTypeList := some fts }

/-- `flight-map` の結果を、結果の列の表し方にする。 -/
def mappedRow (f : SourceModel.Domain.Model.Flight) : Row :=
  [f.departureDate.map (·.formatYMD "-"), f.flightMaster.bind (·.flightName),
   (f.fareType.bind (·.fareTypeCd)).map Spec.Model.FareTypeCd.toCode, f.vacantNum.map fun v => toString v.val,
   (f.boardingClass.bind (·.boardingClassCd)).map Spec.Model.BoardingClassCd.toCode]

/-- 結果の行の列（`departure_date, flight_name, fare_type_cd, vacant_num, boarding_class_cd`）。 -/
def resultRow (r : VacantSeatRow) : Row :=
  [Tests.MasterSql.sD r.result.departureDate, some r.result.flightName.val, some r.result.fareTypeCd.val,
   some (toString r.result.vacantNum.val), some r.result.boardingClassCd.val]

/-- 1 つの条件の照合: 許される並び・列の値・写像。 -/
def checkStatement (db : MasterDb) (st : Json) : Except String (String × Bool × String) := do
  let id ← getStr st "id"
  let p := bind (← criteria (← st.getObjVal? "params"))
  let pg ← (← getArr st "rows").mapM rowOf
  let rows := vacantSeatRowsOn db SourceModel.Db.FlightSeed.seedFlightDb p
  -- PostgreSQL の各行を、モデルの行（列の値が等しいもの。主キーの列を含むのでただ 1 つ）に戻す
  let o ← pg.mapM fun r => do
    match rows.filter (fun x => resultRow x == r) with
    | [x] => pure x
    | xs => throw s!"{id}: {r} matches {xs.length} model rows"
  let allowed := isAllowedOrder SourceModel.Db.Schema.sortCfg vacantSeatOrder rows o
  -- 結果の写像 `flight-map` が例外を投げず、写した値が PostgreSQL の列と一致する
  let mapped := match o.mapM fun r => SourceModel.Domain.Repository.Flight.FlightRepository.flightMap r.result with
    | .ok fs => fs.map mappedRow == pg
    | .error _ => false
  return (id, allowed && mapped && o.length == rows.length, s!"{pg.length} rows (model {rows.length}), ORDER BY")

def run (master : Json) (doc : Json) : Except String (List (String × Bool × String)) := do
  let db ← Tests.MasterSql.decodeDb master
  (← getArr doc "statements").mapM (checkStatement db)

end Tests.FlightSql
