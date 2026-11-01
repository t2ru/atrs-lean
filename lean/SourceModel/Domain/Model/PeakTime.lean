import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.PeakTime

原典の `jp.co.ntt.atrs.domain.model.PeakTime`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/PeakTime.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model

/-- `PeakTime`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.PeakTime#getMultiplicationRatio()@0b4e159bab8a2bad",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakEndDate()@3320372937ffb1c6",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakStartDate()@8c5afe3863a52476",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#getPeakTimeCd()@bf567cee012c32c7",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setMultiplicationRatio(Integer)@2a4c3f761ef3b3ac",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakEndDate(LocalDate)@7d72acc8b47d2285",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakStartDate(LocalDate)@a620abe6a1283db9",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#setPeakTimeCd(String)@df6461ab2c7d6c5e",
  "java:jp.co.ntt.atrs.domain.model.PeakTime#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.domain.model.PeakTime.serialVersionUID@2f2b16014969a5f5"]
structure PeakTime where
  peakTimeCd : JRef String := none
  peakStartDate : JRef JLocalDate := none
  peakEndDate : JRef JLocalDate := none
  multiplicationRatio : JRef J32 := none
  deriving Repr, DecidableEq

namespace PeakTime

end PeakTime

end SourceModel.Domain.Model
