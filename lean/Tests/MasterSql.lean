import Lean.Data.Json
import SourceModel
import Tests.Conformance
import Tests.ConformanceMaster

/-!
# Tests.MasterSql

マスタの Mapper の文とコードリストの SQL の差分実行（backlog 0004、ADR 0043）。
`conformance/sql/master-data.json`（`tools/conformance/master_sql.py` が PostgreSQL で生成）の表の行から
`SourceModel.Repository.MasterData` の各文を評価し、PostgreSQL の結果と照合する。

- 順序の無い文: 結果がバッグとして等しい（値は文字列にして比べる）。
- `ORDER BY` の文: PostgreSQL の結果の並びが、モデルの許される順列（`isAllowedOrder`）である。
- あわせて、共有入力 `fixtures/master-data.json` の行が、PostgreSQL に投入した表の行とバッグとして等しいことを確かめる
  （共有入力の生成器 `master_fixture.py` と、PostgreSQL への投入の突き合わせ）。
-/

open Lean LangSemantics.Sql LangSemantics.Sql.Postgresql SourceModel.Repository.Schema SourceModel.Repository.MasterData
  Tests.Conformance

namespace Tests.MasterSql

abbrev Row := List (Option String)

def getArr (j : Json) (k : String) : Except String (List Json) := (j.getObjValAs? (Array Json) k).map (·.toList)

def rowOf (j : Json) : Except String Row := do
  let .arr xs := j | throw "row is not an array"
  return xs.toList.map fun v => match v with | .str s => some s | _ => none

/-- 表: 列名と行。 -/
structure Table where
  columns : List String
  rows : List Row

def table (doc : Json) (name : String) : Except String Table := do
  let t ← doc.getObjVal? "tables" >>= (·.getObjVal? name)
  let cols ← (t.getObjValAs? (Array String) "columns").map (·.toList)
  return { columns := cols, rows := ← (← getArr t "rows").mapM rowOf }

def col (t : Table) (r : Row) (c : String) : Except String (Option String) := do
  let some i := t.columns.idxOf? c | throw s!"no column {c}"
  return (r[i]?).getD none

def lift {α : Type} (r : SqlResult α) (what : String) : Except String α :=
  match r with
  | .ok a => .ok a
  | .error e => .error s!"{what}: {repr e}"

def need (o : Option String) (c : String) : Except String String :=
  match o with | some s => .ok s | none => .error s!"{c} is NULL"

def vcol (n : Nat) (t : Table) (r : Row) (c : String) : Except String (Varchar n) := do
  lift (Varchar.ofString c n (← need (← col t r c) c)) c
def icol (t : Table) (r : Row) (c : String) : Except String Int4 := do
  let s ← need (← col t r c) c
  let some v := s.toInt? | throw s!"{c}: not an integer: {s}"
  lift (Int4.ofInt v) c
def dcol (t : Table) (r : Row) (c : String) : Except String PgDate := do
  let d ← decodeDate (← need (← col t r c) c)
  lift (date d.epochDay) c

/-- PostgreSQL の表の行から `MasterDb` を作る（列の型の範囲を検査する）。 -/
def decodeDb (doc : Json) : Except String MasterDb := do
  let a ← table doc "AIRPORT"
  let r ← table doc "ROUTE"
  let f ← table doc "FLIGHT_MASTER"
  let b ← table doc "BOARDING_CLASS"
  let ft ← table doc "FARE_TYPE"
  let p ← table doc "PEAK_TIME"
  let pl ← table doc "PLANE"
  let c ← table doc "CREDIT_TYPE"
  return {
    airport := ← a.rows.mapM fun x => do
      return { airportCd := ← vcol 3 a x "airport_cd", airportName := ← vcol 15 a x "airport_name",
               displayOrder := ← icol a x "display_order" }
    route := ← r.rows.mapM fun x => do
      return { routeNo := ← icol r x "route_no", depAirportCd := ← vcol 3 r x "dep_airport_cd",
               arrAirportCd := ← vcol 3 r x "arr_airport_cd", flightTime := ← vcol 4 r x "flight_time",
               basicFare := ← icol r x "basic_fare" }
    flightMaster := ← f.rows.mapM fun x => do
      return { flightName := ← vcol 6 f x "flight_name", routeNo := ← icol f x "route_no",
               departureTime := ← vcol 4 f x "departure_time", arrivalTime := ← vcol 4 f x "arrival_time",
               craftType := ← vcol 16 f x "craft_type" }
    boardingClass := ← b.rows.mapM fun x => do
      let name ← match ← col b x "boarding_class_name" with
        | none => pure none
        | some s => (some ·) <$> lift (Varchar.ofString "boarding_class_name" 10 s) "boarding_class_name"
      return { boardingClassCd := ← vcol 1 b x "boarding_class_cd", boardingClassName := name,
               extraCharge := ← icol b x "extra_charge", displayOrder := ← icol b x "display_order" }
    fareType := ← ft.rows.mapM fun x => do
      return { fareTypeCd := ← vcol 4 ft x "fare_type_cd", fareTypeName := ← vcol 10 ft x "fare_type_name",
               discountRate := ← icol ft x "discount_rate",
               rsrvAvailableStartDayNum := ← icol ft x "rsrv_available_start_day_num",
               rsrvAvailableEndDayNum := ← icol ft x "rsrv_available_end_day_num",
               passengerMinNum := ← icol ft x "passenger_min_num", displayOrder := ← icol ft x "display_order" }
    peakTime := ← p.rows.mapM fun x => do
      return { peakTimeCd := ← vcol 10 p x "peak_time_cd", peakStartDate := ← dcol p x "peak_start_date",
               peakEndDate := ← dcol p x "peak_end_date", multiplicationRatio := ← icol p x "multiplication_ratio" }
    plane := ← pl.rows.mapM fun x => do
      return { craftType := ← vcol 16 pl x "craft_type", nSeatNum := ← icol pl x "n_seat_num", sSeatNum := ← icol pl x "s_seat_num" }
    creditType := ← c.rows.mapM fun x => do
      return { creditTypeCd := ← vcol 3 c x "credit_type_cd", creditFirm := ← vcol 80 c x "credit_firm",
               displayOrder := ← icol c x "display_order" } }

/-! ## 値を文字列に（PostgreSQL の CSV の表し方） -/

def sI (v : Int4) : Option String := some (toString v.val)
def sV {n : Nat} (v : Varchar n) : Option String := some v.val
def sD (d : PgDate) : Option String :=
  (Spec.Prim.Date.ofEpochDay? d.val).map Spec.Prim.fmtIsoDate

def routeRow (r : RouteResult) : Row :=
  [sI r.routeNo, sI r.basicFare, sV r.depAirportCd, sV r.depAirportName, sV r.aarAirportCd, sV r.aarAirportName]

def evalStatement (db : MasterDb) : String → Option (List Row)
  | "route.findAll" => some ((routeFindAll db).map routeRow)
  | "flight.findAllFlightMaster" => some ((flightMasterFindAll db).map fun f =>
      [sV f.flightName, sV f.departureTime, sV f.arrivalTime, sV f.craftType] ++ routeRow f.route)
  | "boardingclass.findAll" => some ((boardingClassFindAll db).map fun b =>
      [sV b.boardingClassCd, b.boardingClassName.map (·.val), sI b.extraCharge])
  | "faretype.findAll" => some ((fareTypeFindAll db).map fun f =>
      [sV f.fareTypeCd, sV f.fareTypeName, sI f.discountRate, sI f.rsrvAvailableStartDayNum, sI f.rsrvAvailableEndDayNum,
       sI f.passengerMinNum])
  | "peaktime.findAll" => some ((peakTimeFindAll db).map fun p =>
      [sV p.peakTimeCd, sD p.peakStartDate, sD p.peakEndDate, sI p.multiplicationRatio])
  | _ => none

/-- `ORDER BY` の文: PostgreSQL の結果の各行を、表の行（コードで引く）に戻した並びが、許される順列か。 -/
def orderedAllowed (db : MasterDb) (id : String) (pg : List Row) : Except String Bool := do
  let code (r : Row) : Except String String := need r.head?.join "code"
  let back {α : Type} [BEq α] (rows : List α) (key : α → String) : Except String (List α) :=
    pg.mapM fun r => do
      let k ← code r
      match rows.filter (key · == k) with
      | [x] => pure x
      | _ => throw s!"{id}: {k} is not a unique row"
  match id with
  | "CL_AIRPORT" => do
    let o ← back (airportCodeListRows db) (·.airportCd.val)
    let ok := isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (airportCodeListRows db) o
    -- 表示の列も一致する
    return ok && o.map (fun a => [sV a.airportCd, sV a.airportName, sI a.displayOrder]) == pg
  | "CL_BOARDINGCLASS" => do
    let o ← back (boardingClassCodeListRows db) (·.boardingClassCd.val)
    return isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (boardingClassCodeListRows db) o &&
      o.map (fun b => [sV b.boardingClassCd, b.boardingClassName.map (·.val)]) == pg
  | "CL_FARETYPE" => do
    let o ← back (fareTypeCodeListRows db) (·.fareTypeCd.val)
    return isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (fareTypeCodeListRows db) o &&
      o.map (fun f => [sV f.fareTypeCd, sV f.fareTypeName]) == pg
  | "CL_CREDITTYPE" => do
    let o ← back (creditTypeCodeListRows db) (·.creditTypeCd.val)
    return isAllowedOrder sortCfg [.asc] (orderKey (·.displayOrder)) (creditTypeCodeListRows db) o &&
      o.map (fun c => [sV c.creditTypeCd, sV c.creditFirm]) == pg
  | _ => throw s!"unknown ordered statement {id}"

/-- 各文の照合（文の ID, 合否, 説明）。 -/
def run (doc : Json) : Except String (List (String × Bool × String)) := do
  let db ← decodeDb doc
  let sts ← getArr doc "statements"
  sts.mapM fun st => do
    let id ← getStr st "id"
    let pg ← (← getArr st "rows").mapM rowOf
    let ordered := (st.getObjValAs? Bool "ordered").toOption.getD false
    if ordered then
      let ok ← orderedAllowed db id pg
      return (id, ok, s!"{pg.length} rows, ORDER BY")
    else
      let some mine := evalStatement db id | throw s!"unknown statement {id}"
      return (id, Bag.bagEq mine pg, s!"{pg.length} rows (model {mine.length})")

/-- 共有入力の行（`Tests.ConformanceMaster.decodeDb`）と、PostgreSQL に投入した表の行が、バッグとして等しい。 -/
def fixtureMatches (doc : Json) (fixture : Json) : Except String (List (String × Bool)) := do
  let pg ← decodeDb doc
  let fx ← Tests.ConformanceMaster.decodeDb fixture
  return [("AIRPORT", Bag.bagEq pg.airport fx.airport), ("ROUTE", Bag.bagEq pg.route fx.route),
    ("FLIGHT_MASTER", Bag.bagEq pg.flightMaster fx.flightMaster), ("BOARDING_CLASS", Bag.bagEq pg.boardingClass fx.boardingClass),
    ("FARE_TYPE", Bag.bagEq pg.fareType fx.fareType), ("PEAK_TIME", Bag.bagEq pg.peakTime fx.peakTime),
    ("PLANE", Bag.bagEq pg.plane fx.plane), ("CREDIT_TYPE", Bag.bagEq pg.creditType fx.creditType)]

end Tests.MasterSql
