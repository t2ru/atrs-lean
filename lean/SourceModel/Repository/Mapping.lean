import Trace
import LangSemantics.Java
import LangSemantics.Sql
import SourceModel.Model
import SourceModel.Repository.MasterData

/-!
# SourceModel.Repository.Mapping

MyBatis の結果の対応（`resultMap`）。列の値を Java の型へ写す。

- `INT` → `Integer`（`JRef J32`。`Int4` の範囲は int に収まる）
- `DATE` → `LocalDate`（`JLocalDate`）
- `VARCHAR` → `String`
- enum の列 → `Enum.valueOf`（MyBatis の `EnumTypeHandler`）。未知のコードは `IllegalArgumentException`
- 入れ子の `resultMap`（`flightMaster-map` の `association`）は、`<id>` の列が同じ行を 1 つにまとめ、最初の行を残す。

lang/dep: `dep:org.mybatis:mybatis#EnumTypeHandler`、`dep:org.mybatis:mybatis#DefaultResultSetHandler`
-/

namespace SourceModel.Repository.Mapping

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Model SourceModel.Repository.MasterData
  SourceModel.Repository.Schema

/-- `INT` の値を `Integer` に。 -/
def int (v : Int4) : JRef J32 := some (J32.ofInt v.val)

/-- `DATE` の値を `LocalDate` に。 -/
def date (d : PgDate) : JRef JLocalDate := some (JLocalDate.ofEpochDay d.val)

/-- `VARCHAR` の値を `String` に。 -/
def str {n : Nat} (s : Varchar n) : JRef String := some s.val

/-- `Enum.valueOf(BoardingClassCd.class, s)`。 -/
def boardingClassCd (s : String) : JResult Spec.BoardingClassCd :=
  match s with
  | "N" => pure .N
  | "S" => pure .S
  | _ => throw (.illegalArgument s!"No enum constant BoardingClassCd.{s}")

/-- `Enum.valueOf(FareTypeCd.class, s)`。 -/
def fareTypeCd (s : String) : JResult Spec.FareTypeCd :=
  match s with
  | "OW" => pure .OW | "RT" => pure .RT | "RD1" => pure .RD1 | "RD7" => pure .RD7 | "ED" => pure .ED
  | "LD" => pure .LD | "GD" => pure .GD | "SOW" => pure .SOW | "SRT" => pure .SRT | "SRD" => pure .SRD
  | _ => throw (.illegalArgument s!"No enum constant FareTypeCd.{s}")

/-- `route-map`。`departureAirport.code` などの点つきの属性は、空港を作って値を入れる。 -/
def route (r : RouteResult) : Route :=
  { routeNo := int r.routeNo, basicFare := int r.basicFare,
    departureAirport := some { code := str r.depAirportCd, name := str r.depAirportName },
    arrivalAirport := some { code := str r.aarAirportCd, name := str r.aarAirportName } }

/-- `flightMaster-map`（1 行分）。 -/
def flightMasterRow (f : FlightMasterResult) : FlightMaster :=
  { flightName := str f.flightName, departureTime := str f.departureTime, arrivalTime := str f.arrivalTime,
    plane := some { craftType := str f.craftType }, route := some (route f.route) }

/-- `flightMaster-map`: 入れ子の対応なので、`<id>`（`flight_name`）が同じ行は最初の 1 つにまとめる。 -/
def flightMasters (rows : List FlightMasterResult) : List FlightMaster :=
  (rows.foldl (fun (acc : List FlightMasterResult) r =>
    if acc.any (fun a => a.flightName.val == r.flightName.val) then acc else acc ++ [r]) []).map flightMasterRow

/-- `boardingClass-map`。 -/
def boardingClass (b : BoardingClassResult) : JResult BoardingClass := do
  let cd ← boardingClassCd b.boardingClassCd.val
  return { boardingClassCd := some cd, boardingClassName := b.boardingClassName.map (·.val), extraCharge := int b.extraCharge }

/-- `fareType-map`。 -/
def fareType (f : FareTypeResult) : JResult FareType := do
  let cd ← fareTypeCd f.fareTypeCd.val
  return { fareTypeCd := some cd, fareTypeName := str f.fareTypeName, discountRate := int f.discountRate,
           rsrvAvailableStartDayNum := int f.rsrvAvailableStartDayNum,
           rsrvAvailableEndDayNum := int f.rsrvAvailableEndDayNum, passengerMinNum := int f.passengerMinNum }

/-- `peakTime-map`。 -/
def peakTime (p : PeakTimeRow) : PeakTime :=
  { peakTimeCd := str p.peakTimeCd, peakStartDate := date p.peakStartDate, peakEndDate := date p.peakEndDate,
    multiplicationRatio := int p.multiplicationRatio }

end SourceModel.Repository.Mapping
