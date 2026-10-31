import SourceModel.MasterData
import LangSemantics.Core.List

/-!
# Abstraction.MasterData.Key

`RouteProvider` のキャッシュのキー `makeCacheKey dep arr = dep ++ "-" ++ arr` は、空港コードが `-` を含まなければ
単射である（`WellFormed` な空港コードは英大文字だけからなる）。
-/

namespace Abstraction.MasterData.Key
open LangSemantics.Core.List

open SourceModel.MasterData


/-- 出発の空港コードがどちらも `-` を含まなければ、キーが等しい区間は、出発・到着の空港コードが等しい。 -/
theorem makeCacheKey_inj {dep arr dep' arr' : String} (h : '-' ∉ dep.toList) (h' : '-' ∉ dep'.toList)
    (e : makeCacheKey dep arr = makeCacheKey dep' arr') : dep = dep' ∧ arr = arr' := by
  have e := congrArg String.toList e
  simp only [makeCacheKey, String.toList_append] at e
  have : dep.toList ++ '-' :: arr.toList = dep'.toList ++ '-' :: arr'.toList := by simpa using e
  obtain ⟨h1, h2⟩ := append_sep_inj h h' this
  exact ⟨String.toList_inj.mp h1, String.toList_inj.mp h2⟩

end Abstraction.MasterData.Key
