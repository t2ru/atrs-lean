import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository
import Spec.Model

/-!
# SourceModel.Domain.Common.Masterdata.BoardingClassProvider

原典の `jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/masterdata/BoardingClassProvider.java`）の写し。
-/

namespace SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.Domain.Repository.Boardingclass
  SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository
open SourceModel.Domain.Common.Masterdata

/-- `BoardingClassProvider` のキャッシュ（`Map<BoardingClassCd, BoardingClass>`）。 -/
structure BoardingClassProvider where
  boardingClassCodeMap : JHashMap Spec.Model.BoardingClassCd BoardingClass := {}

namespace BoardingClassProvider

/-- `BoardingClassProvider.load()`: `findAll` の各行を、搭乗クラスコードをキーに `put` する（後勝ち）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#load()@ea4f74c6c99e9b67",
  "java:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll()@a75e2344e7b09314", gap "D-015"]
def load (rows : List BoardingClassResult) : JResult BoardingClassProvider := do
  let list ← rows.mapM SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository.boardingClassMap
  let mut m : JHashMap Spec.Model.BoardingClassCd BoardingClass := {}
  for bc in list do
    m := m.put (← bc.boardingClassCd.deref "boardingClassCd") bc
  return { boardingClassCodeMap := m }

/-- `BoardingClassProvider.getBoardingClass`: 無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)@363af6d3dd2e282d"]
def getBoardingClass (p : BoardingClassProvider) (cd : JRef Spec.Model.BoardingClassCd) : JResult (JRef BoardingClass) := do
  let cd ← Assert.notNullValue cd "boardingClassCd must not null."
  return p.boardingClassCodeMap.get cd

end BoardingClassProvider

end SourceModel.Domain.Common.Masterdata
