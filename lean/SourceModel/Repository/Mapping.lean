import Trace
import LangSemantics.Java
import LangSemantics.Sql
import SourceModel.Model
import SourceModel.Repository.MasterData
import SourceModel.Repository.Flight

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
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Model SourceModel.Repository.MasterData
  SourceModel.Repository.Schema

/-- `INT` の値を `Integer` に。 -/
def int (v : Int4) : JRef J32 := some (J32.ofInt v.val)

/-- `DATE` の値を `LocalDate` に。 -/
def date (d : PgDate) : JRef JLocalDate := some (JLocalDate.ofEpochDay d.val)

/-- `VARCHAR` の値を `String` に。 -/
def str {n : Nat} (s : Varchar n) : JRef String := some s.val

/-- `Enum.valueOf(BoardingClassCd.class, s)`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.BoardingClassCd#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.BoardingClassCd.N@8ce86a6ae65d3692",
  "java:jp.co.ntt.atrs.domain.model.BoardingClassCd.S@8de0b3c47f112c59"]
def boardingClassCd (s : String) : JResult Spec.Model.BoardingClassCd :=
  match s with
  | "N" => pure .N
  | "S" => pure .S
  | _ => throw (.illegalArgument s!"No enum constant BoardingClassCd.{s}")

/-- `Enum.valueOf(FareTypeCd.class, s)`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.ED@4ef203daf77cede7",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.GD@884d5bff79c10dff",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.LD@ab31ea4ae5075371",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.OW@7e4b60f4d2ee743b",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD1@1cfb19d902ca71fd",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD7@5003a843107c47b7",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RT@3165be96f5833ae0",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SOW@7b105823acf590f2",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRD@b111f3efc4632267",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRT@8a21220051bcc7d6"]
def fareTypeCd (s : String) : JResult Spec.Model.FareTypeCd :=
  match s with
  | "OW" => pure .OW | "RT" => pure .RT | "RD1" => pure .RD1 | "RD7" => pure .RD7 | "ED" => pure .ED
  | "LD" => pure .LD | "GD" => pure .GD | "SOW" => pure .SOW | "SRT" => pure .SRT | "SRD" => pure .SRD
  | _ => throw (.illegalArgument s!"No enum constant FareTypeCd.{s}")

/-- `route-map`。`departureAirport.code` などの点つきの属性は、空港を作って値を入れる。 -/
@[source "java:jp.co.ntt.atrs.config.app.mybatis.MybatisConfig#configuration()@81014029228aac4a",
  "java:jp.co.ntt.atrs.config.app.AtrsInfraConfig#sqlSessionFactory(DataSource)@b1ab3854afd9d9e6"]
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

/-- `flight-map`（`FlightRepository.findByVacantSeatSearchCriteria` の結果）。入れ子の対応が無いので、行をまとめない。
便マスタ・運賃種別・搭乗クラスは、コードだけを入れた値になる（`searchFlight` が Provider で詰め直す）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria(VacantSeatSearchCriteriaDto)@642c24ce08bfe364"]
def flight (r : SourceModel.Repository.Flight.FlightResult) : JResult Flight := do
  let bc ← boardingClassCd r.boardingClassCd.val
  let ft ← fareTypeCd r.fareTypeCd.val
  return { departureDate := date r.departureDate, flightMaster := some { flightName := str r.flightName },
           boardingClass := some { boardingClassCd := some bc }, fareType := some { fareTypeCd := some ft },
           vacantNum := int r.vacantNum }

end SourceModel.Repository.Mapping
