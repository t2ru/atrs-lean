import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.Airport
import Spec.Model

/-!
# SourceModel.Domain.Model.Route

原典の `jp.co.ntt.atrs.domain.model.Route`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/Route.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `Route`。Mapper の `findAll` は所要時間を読まない。 -/
@[source "java:jp.co.ntt.atrs.domain.model.Route#getArrivalAirport()@e4e63cfd9aa52b7c",
  "java:jp.co.ntt.atrs.domain.model.Route#getBasicFare()@89a978cfeb517ad4",
  "java:jp.co.ntt.atrs.domain.model.Route#getDepartureAirport()@c52377ce8cec2f3c",
  "java:jp.co.ntt.atrs.domain.model.Route#getRouteNo()@4c60bbfe1a09e09b",
  "java:jp.co.ntt.atrs.domain.model.Route#setArrivalAirport(Airport)@8f997e7447e48706",
  "java:jp.co.ntt.atrs.domain.model.Route#setBasicFare(Integer)@dcef121f022ac443",
  "java:jp.co.ntt.atrs.domain.model.Route#setDepartureAirport(Airport)@ba74485411a2bc4f",
  "java:jp.co.ntt.atrs.domain.model.Route#setRouteNo(Integer)@a9c754e56f9d626c",
  "java:jp.co.ntt.atrs.domain.model.Route#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.Route.serialVersionUID@e55e25f5719b321f"]
structure Route where
  routeNo : JRef J32 := none
  basicFare : JRef J32 := none
  arrivalAirport : JRef Airport := none
  departureAirport : JRef Airport := none
  deriving Repr, DecidableEq

namespace Route

end Route

end SourceModel.Domain.Model
