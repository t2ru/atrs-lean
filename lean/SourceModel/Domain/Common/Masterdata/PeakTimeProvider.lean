import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.Schema
import SourceModel.Domain.Model.PeakTime
import SourceModel.Domain.Repository.Peaktime.PeakTimeRepository
import Spec.Model

/-!
# SourceModel.Domain.Common.Masterdata.PeakTimeProvider

原典の `jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/masterdata/PeakTimeProvider.java`）の写し。
-/

namespace SourceModel.Domain.Common.Masterdata
open LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.String LangSemantics.Java.Spring
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Db.Schema SourceModel.Domain.Repository.Peaktime
  SourceModel.Domain.Repository.Peaktime.PeakTimeRepository
open SourceModel.Domain.Common.Masterdata

/-- `PeakTimeProvider` のキャッシュ（`List<PeakTime>`。取得順）。 -/
structure PeakTimeProvider where
  peakTimeList : List PeakTime := []

namespace PeakTimeProvider

/-- `PeakTimeProvider.load()`: `findAll` の結果を取得順のまま `addAll` する。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#load()@604b187a665e10c5",
  "java:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll()@4020414e93f77c78"]
def load (rows : List SourceModel.Db.Schema.PeakTimeRow) : PeakTimeProvider :=
  { peakTimeList := rows.map SourceModel.Domain.Repository.Peaktime.PeakTimeRepository.peakTimeMap }

/-- `PeakTimeProvider.getPeakTime`: 取得順に走査し、`depLocalDate` を両端を含めて含む最初のピーク時期。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)@1b19d6cad612b687", gap "D-004"]
def getPeakTime (p : PeakTimeProvider) (depLocalDate : JRef JLocalDate) : JResult (JRef PeakTime) := do
  let d ← Assert.notNullValue depLocalDate "depLocalDate must not null."
  let rec go : List PeakTime → JResult (JRef PeakTime)
    | [] => pure none
    | pt :: rest => do
      let s ← pt.peakStartDate.deref "peakStartDate"
      let e ← pt.peakEndDate.deref "peakEndDate"
      if java! !(d.isBefore(s) || d.isAfter(e)) then pure (some pt) else go rest
  go p.peakTimeList

end PeakTimeProvider

end SourceModel.Domain.Common.Masterdata
