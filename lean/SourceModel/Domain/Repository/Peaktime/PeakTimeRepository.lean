import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Domain.Model.PeakTime
import Spec.Model

/-!
# SourceModel.Domain.Repository.Peaktime.PeakTimeRepository

原典の `jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/peaktime/PeakTimeRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/peaktime/PeakTimeRepository.xml`）の写し。
-/

namespace SourceModel.Domain.Repository.Peaktime
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Peaktime
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model
open SourceModel.Db.MyBatis

namespace PeakTimeRepository

/-- `SELECT peak_time_cd, peak_start_date, peak_end_date, multiplication_ratio FROM peak_time` -/
@[source "sql:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll@52311345757d8bde"]
def findAll (db : MasterDb) : Bag PeakTimeRow := db.peakTime

/-- `peakTime-map`。 -/
def peakTimeMap (p : PeakTimeRow) : PeakTime :=
  { peakTimeCd := str p.peakTimeCd, peakStartDate := date p.peakStartDate, peakEndDate := date p.peakEndDate,
    multiplicationRatio := int p.multiplicationRatio }

end PeakTimeRepository

end SourceModel.Domain.Repository.Peaktime
