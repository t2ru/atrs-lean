import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.BoardingClassCd
import Spec.Model

/-!
# SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository

原典の `jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/boardingclass/BoardingClassRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/boardingclass/BoardingClassRepository.xml`）の写し。
-/

namespace SourceModel.Domain.Repository.Boardingclass
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Boardingclass
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model
open SourceModel.Db.MyBatis

namespace BoardingClassRepository

/-- `SELECT boarding_class_cd, boarding_class_name, extra_charge FROM boarding_class` -/
structure BoardingClassResult where
  boardingClassCd : Varchar 1
  boardingClassName : Option (Varchar 10)
  extraCharge : Int4
  deriving DecidableEq, Repr

@[source "sql:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll@9b228eec7b3acd6a"]
def findAll (db : MasterDb) : Bag BoardingClassResult :=
  Bag.project (fun b => ⟨b.boardingClassCd, b.boardingClassName, b.extraCharge⟩) db.boardingClass

/-- `boardingClass-map`。 -/
def boardingClassMap (b : BoardingClassResult) : JResult BoardingClass := do
  let cd ← BoardingClassCd.valueOf b.boardingClassCd.val
  return { boardingClassCd := some cd, boardingClassName := b.boardingClassName.map (·.val), extraCharge := int b.extraCharge }

end BoardingClassRepository

end SourceModel.Domain.Repository.Boardingclass
