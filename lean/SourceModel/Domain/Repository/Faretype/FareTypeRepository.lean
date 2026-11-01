import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.FareTypeCd
import Spec.Model

/-!
# SourceModel.Domain.Repository.Faretype.FareTypeRepository

原典の `jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/faretype/FareTypeRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/faretype/FareTypeRepository.xml`）の写し。
-/

namespace SourceModel.Domain.Repository.Faretype
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Faretype
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model
open SourceModel.Db.MyBatis

namespace FareTypeRepository

/-- `SELECT fare_type_cd, fare_type_name, discount_rate, rsrv_available_start_day_num, rsrv_available_end_day_num,
passenger_min_num FROM fare_type` -/
structure FareTypeResult where
  fareTypeCd : Varchar 4
  fareTypeName : Varchar 10
  discountRate : Int4
  rsrvAvailableStartDayNum : Int4
  rsrvAvailableEndDayNum : Int4
  passengerMinNum : Int4
  deriving DecidableEq, Repr

@[source "sql:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll@7ff78a19a79f16de"]
def findAll (db : MasterDb) : Bag FareTypeResult :=
  Bag.project (fun f => ⟨f.fareTypeCd, f.fareTypeName, f.discountRate, f.rsrvAvailableStartDayNum,
    f.rsrvAvailableEndDayNum, f.passengerMinNum⟩) db.fareType

/-- `fareType-map`。 -/
def fareTypeMap (f : FareTypeResult) : JResult FareType := do
  let cd ← FareTypeCd.valueOf f.fareTypeCd.val
  return { fareTypeCd := some cd, fareTypeName := str f.fareTypeName, discountRate := int f.discountRate,
           rsrvAvailableStartDayNum := int f.rsrvAvailableStartDayNum,
           rsrvAvailableEndDayNum := int f.rsrvAvailableEndDayNum, passengerMinNum := int f.passengerMinNum }

end FareTypeRepository

end SourceModel.Domain.Repository.Faretype
