import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.FareTypeCd
import SourceModel.Domain.Service.B1.FareTypeVacantInfoDto
import Spec.Model

/-!
# SourceModel.Domain.Service.B1.FlightVacantInfoDto

原典の `jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b1/FlightVacantInfoDto.java`）の写し。
-/

namespace SourceModel.Domain.Service.B1
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.String LangSemantics.Java.HashMap
  LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model
open SourceModel.Domain.Service.B1

/-- `FlightVacantInfoDto`（便ごとの空席情報）。`fareTypes` は `LinkedHashMap<String, FareTypeVacantInfoDto>`。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrAirportName()@168f6313b91f7efc",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getArrTime()@eba19a6e8cfe7373",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getBoardingClassCd()@2c95f973159bc7cc",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepAirportName()@613fd9acef107682",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepDate()@369d89134caefd5a",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getDepTime()@e8756384892001a1",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFareTypes()@b4cb9d39c4e1670d",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#getFlightName()@56b669a044a195ca",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrAirportName(String)@6ed33d2eb1ba891b",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setArrTime(String)@a72394c9d4069159",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setBoardingClassCd(BoardingClassCd)@fab24fded6a99658",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepAirportName(String)@fccb4abecff6d001",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepDate(String)@962bd97bc530d3db",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setDepTime(String)@a032ee060e4c3da2",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFareTypes(Map)@28c6e4b5185f43b9",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#setFlightName(String)@c8ed541ae69f3cad",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto.serialVersionUID@c450724693049058"]
structure FlightVacantInfoDto where
  flightName : JRef String := none
  depAirportName : JRef String := none
  arrAirportName : JRef String := none
  depTime : JRef String := none
  arrTime : JRef String := none
  depDate : JRef String := none
  boardingClassCd : JRef Spec.Model.BoardingClassCd := none
  fareTypes : JLinkedHashMap String FareTypeVacantInfoDto := {}
  deriving Repr

namespace FlightVacantInfoDto

/-- `addFareTypeVacantInfo(fareTypeCd, info)`: `fareTypes.put(fareTypeCd.getCode(), info)`（`null` なら NPE）。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto#addFareTypeVacantInfo(FareTypeCd,FareTypeVacantInfoDto)@1c016d6655a35b9a"]
def addFareTypeVacantInfo (v : FlightVacantInfoDto) (fareTypeCd : JRef Spec.Model.FareTypeCd)
    (fareTypeVacantInfo : FareTypeVacantInfoDto) : JResult FlightVacantInfoDto := do
  let cd ← fareTypeCd.deref "fareTypeCd"
  return { v with fareTypes := v.fareTypes.put (SourceModel.Domain.Model.FareTypeCd.getCode cd) fareTypeVacantInfo }

end FlightVacantInfoDto

end SourceModel.Domain.Service.B1
