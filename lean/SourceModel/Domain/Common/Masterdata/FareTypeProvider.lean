import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Repository.Faretype.FareTypeRepository
import Spec.Model

/-!
# SourceModel.Domain.Common.Masterdata.FareTypeProvider

原典の `jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/masterdata/FareTypeProvider.java`）の写し。
-/

namespace SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.Domain.Repository.Faretype
  SourceModel.Domain.Repository.Faretype.FareTypeRepository
open SourceModel.Domain.Common.Masterdata

/-- `FareTypeProvider` のキャッシュ（`Map<FareTypeCd, FareType>`）。 -/
structure FareTypeProvider where
  fareTypeMap : JHashMap Spec.Model.FareTypeCd FareType := {}

namespace FareTypeProvider

/-- `FareTypeProvider.load()`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#load()@accd51e500f0cb16",
  "java:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll()@c01904394de5db65", gap "D-015"]
def load (rows : List FareTypeResult) : JResult FareTypeProvider := do
  let list ← rows.mapM SourceModel.Domain.Repository.Faretype.FareTypeRepository.fareTypeMap
  let mut m : JHashMap Spec.Model.FareTypeCd FareType := {}
  for ft in list do
    m := m.put (← ft.fareTypeCd.deref "fareTypeCd") ft
  return { fareTypeMap := m }

/-- `FareTypeProvider.getFareType`: 無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider#getFareType(FareTypeCd)@8cca1518f179d5a0"]
def getFareType (p : FareTypeProvider) (fareTypeCd : JRef Spec.Model.FareTypeCd) : JResult (JRef FareType) := do
  let fareTypeCd ← Assert.notNullValue fareTypeCd "fareTypeCd must not null."
  return p.fareTypeMap.get fareTypeCd

end FareTypeProvider

end SourceModel.Domain.Common.Masterdata
