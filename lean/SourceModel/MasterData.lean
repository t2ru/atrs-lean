import LangSemantics.Java
import SourceModel.Model

/-!
# SourceModel.MasterData

マスタの Provider（`jp.co.ntt.atrs.domain.common.masterdata`）。Provider は起動時（`@PostConstruct load()`）に
マスタを読んでキャッシュし、以後は変えない。マスタは不変なので、キャッシュを操作の入力の成分として受ける
（`docs/spec/abstraction.md`）。キャッシュを SQL から作る `load` と、運賃計算が使わない Provider（`FareTypeProvider` など）は、backlog 0004 の第 2 段で写す。
-/

namespace SourceModel.MasterData

open LangSemantics.Java SourceModel.Model

/-- `BoardingClassProvider` のキャッシュ（`Map<BoardingClassCd, BoardingClass>`）。 -/
structure BoardingClassProvider where
  boardingClassCodeMap : JHashMap Spec.BoardingClassCd BoardingClass := {}

/-- `PeakTimeProvider` のキャッシュ（`List<PeakTime>`。取得順）。 -/
structure PeakTimeProvider where
  peakTimeList : List PeakTime := []

/-- `getBoardingClass`: 無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)@363af6d3dd2e282d"]
def getBoardingClass (p : BoardingClassProvider) (cd : JRef Spec.BoardingClassCd) : JResult (JRef BoardingClass) := do
  let cd ← match cd with
    | some c => pure c
    | none => throw (.illegalArgument "boardingClassCd must not null.")
  return p.boardingClassCodeMap.get cd

/-- `getPeakTime`: 取得順に走査し、`depLocalDate` を両端を含めて含む最初のピーク時期。無ければ `null`。 -/
@[source "java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)@1b19d6cad612b687"]
def getPeakTime (p : PeakTimeProvider) (depLocalDate : JRef JLocalDate) : JResult (JRef PeakTime) := do
  let d ← match depLocalDate with
    | some d => pure d
    | none => throw (.illegalArgument "depLocalDate must not null.")
  let rec go : List PeakTime → JResult (JRef PeakTime)
    | [] => pure none
    | pt :: rest => do
      let s ← pt.peakStartDate.deref "peakStartDate"
      let e ← pt.peakEndDate.deref "peakEndDate"
      if !(d.isBefore s || d.isAfter e) then pure (some pt) else go rest
  go p.peakTimeList

end SourceModel.MasterData
