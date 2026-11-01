import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.FlightMaster
import Spec.Model

/-!
# SourceModel.Domain.Model.Flight

原典の `jp.co.ntt.atrs.domain.model.Flight`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Flight.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Flight`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Flight#getBoardingClass()@590aaacf8b6bb288",
  "java:jp.co.ntt.atrs.domain.model.Flight#getDepartureDate()@5fac0b39eeb51c0a",
  "java:jp.co.ntt.atrs.domain.model.Flight#getFareType()@70c7e2748ef109e1",
  "java:jp.co.ntt.atrs.domain.model.Flight#getFlightMaster()@9870269e2c0916c0",
  "java:jp.co.ntt.atrs.domain.model.Flight#getVacantNum()@1727d00958d6c3a3",
  "java:jp.co.ntt.atrs.domain.model.Flight#setBoardingClass(BoardingClass)@4881f219e0e20946",
  "java:jp.co.ntt.atrs.domain.model.Flight#setDepartureDate(LocalDate)@596fcb7473f9f84f",
  "java:jp.co.ntt.atrs.domain.model.Flight#setFareType(FareType)@1ced11692bc11e36",
  "java:jp.co.ntt.atrs.domain.model.Flight#setFlightMaster(FlightMaster)@8563a05050c6b001",
  "java:jp.co.ntt.atrs.domain.model.Flight#setVacantNum(Integer)@29bf39575d8c8abb",
  "java:jp.co.ntt.atrs.domain.model.Flight#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Flight.serialVersionUID@943c963ca9c1a2b3"]
structure Flight where
  fareType : JRef FareType := none
  departureDate : JRef JLocalDate := none
  vacantNum : JRef J32 := none
  flightMaster : JRef FlightMaster := none
  boardingClass : JRef BoardingClass := none
  deriving Repr, DecidableEq

namespace Flight

end Flight

end SourceModel.Domain.Model
