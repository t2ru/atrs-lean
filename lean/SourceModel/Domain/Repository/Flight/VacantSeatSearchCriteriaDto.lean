import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import LangSemantics.Sql.QueryLemmas
import SourceModel.Domain.Model.Route
import Spec.Model

/-!
# SourceModel.Domain.Repository.Flight.VacantSeatSearchCriteriaDto

原典の `jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/flight/VacantSeatSearchCriteriaDto.java`）の写し。
-/

namespace SourceModel.Domain.Repository.Flight
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Java.Exception LangSemantics.Java.Int
open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Domain.Repository.Flight

/-- `VacantSeatSearchCriteriaDto`（空席照会の条件）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#<init>(LocalDate,Route,BoardingClassCd,Long,List)@da10cbbc34c14874",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBeforeDayNum()@87c12b12578b0d7e",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getBoardingClass()@14872a96b272a9e5",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getDepDate()@9e5ad0157d1bece7",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getFareTypeList()@108313590608caad",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#getRoute()@bb4d94a040ef721d",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.repository.flight.VacantSeatSearchCriteriaDto.serialVersionUID@652bd2782db8027a"]
structure VacantSeatSearchCriteriaDto where
  boardingClass : JRef Spec.Model.BoardingClassCd := none
  depDate : JRef JLocalDate := none
  route : JRef SourceModel.Domain.Model.Route := none
  beforeDayNum : JRef J64 := none
  fareTypeList : JRef (List Spec.Model.FareTypeCd) := none
  deriving DecidableEq, Repr

namespace VacantSeatSearchCriteriaDto

end VacantSeatSearchCriteriaDto

end SourceModel.Domain.Repository.Flight
