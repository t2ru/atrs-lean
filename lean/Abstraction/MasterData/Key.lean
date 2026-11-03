import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.PeakTimeProvider
import SourceModel.Domain.Common.Masterdata.FareTypeProvider
import SourceModel.Domain.Common.Masterdata.RouteProvider
import SourceModel.Domain.Common.Masterdata.FlightMasterProvider
import LangSemantics.Core.List

/-!
# Abstraction.MasterData.Key

`RouteProvider` のキャッシュのキー `RouteProvider.makeCacheKey dep arr = dep ++ "-" ++ arr` は、空港コードが `-` を含まなければ
単射である（空港コードは形式 `AirportCd.valid` により英大文字だけからなる）。
-/

namespace Abstraction.MasterData.Key
open LangSemantics.Core.List

open SourceModel.Domain.Common.Masterdata

/-- 出発の空港コードがどちらも `-` を含まなければ、キーが等しい区間は、出発・到着の空港コードが等しい。 -/
theorem makeCacheKey_inj {dep arr dep' arr' : String} (h : '-' ∉ dep.toList) (h' : '-' ∉ dep'.toList)
    (e : RouteProvider.makeCacheKey dep arr = RouteProvider.makeCacheKey dep' arr') : dep = dep' ∧ arr = arr' := by
  have e := congrArg String.toList e
  simp only [RouteProvider.makeCacheKey, String.toList_append] at e
  have : dep.toList ++ '-' :: arr.toList = dep'.toList ++ '-' :: arr'.toList := by simpa using e
  obtain ⟨h1, h2⟩ := append_sep_inj h h' this
  exact ⟨String.toList_inj.mp h1, String.toList_inj.mp h2⟩

/-- 片方の区間の出発・到着の空港コードが `-` を含まなければ、キーが等しいもう片方も `-` を含まず、空港コードが等しい
（キー `dep ++ "-" ++ arr` の `-` はちょうど 1 つ）。照会の空港コードの形を課さないときに使う。 -/
theorem makeCacheKey_inj' {dep arr dep' arr' : String} (h : '-' ∉ dep.toList) (ha : '-' ∉ arr.toList)
    (e : RouteProvider.makeCacheKey dep arr = RouteProvider.makeCacheKey dep' arr') : dep = dep' ∧ arr = arr' := by
  have e' := congrArg (fun s => (String.toList s).count '-') e
  simp only [RouteProvider.makeCacheKey, String.toList_append, List.count_append] at e'
  have c1 : dep.toList.count '-' = 0 := List.count_eq_zero.mpr h
  have c2 : arr.toList.count '-' = 0 := List.count_eq_zero.mpr ha
  have hm : ("-" : String).toList.count '-' = 1 := by decide
  rw [c1, c2, hm] at e'
  have c3 : dep'.toList.count '-' = 0 := by omega
  exact makeCacheKey_inj h (List.count_eq_zero.mp c3) e

end Abstraction.MasterData.Key
