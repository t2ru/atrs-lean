import SourceModel.MasterData

/-!
# Abstraction.MasterData.Key

`RouteProvider` のキャッシュのキー `makeCacheKey dep arr = dep ++ "-" ++ arr` は、空港コードが `-` を含まなければ
単射である（`WellFormed` な空港コードは英大文字だけからなる）。
-/

namespace Abstraction.MasterData

open SourceModel.MasterData

theorem append_sep_inj {c : Char} : ∀ {a a' b b' : List Char}, c ∉ a → c ∉ a' →
    a ++ c :: b = a' ++ c :: b' → a = a' ∧ b = b'
  | [], [], _, _, _, _, h => by simpa using h
  | [], x :: a', _, _, _, h', h => by
    simp only [List.nil_append, List.cons_append, List.cons.injEq] at h
    exact absurd (h.1 ▸ List.mem_cons_self ..) h'
  | x :: a, [], _, _, h, _, h' => by
    simp only [List.nil_append, List.cons_append, List.cons.injEq] at h'
    exact absurd (h'.1 ▸ List.mem_cons_self ..) h
  | x :: a, y :: a', _, _, h, h', e => by
    simp only [List.cons_append, List.cons.injEq] at e
    obtain ⟨rfl, e⟩ := e
    obtain ⟨rfl, rfl⟩ := append_sep_inj (fun m => h (List.mem_cons_of_mem _ m))
      (fun m => h' (List.mem_cons_of_mem _ m)) e
    exact ⟨rfl, rfl⟩

/-- 出発の空港コードがどちらも `-` を含まなければ、キーが等しい区間は、出発・到着の空港コードが等しい。 -/
theorem makeCacheKey_inj {dep arr dep' arr' : String} (h : '-' ∉ dep.toList) (h' : '-' ∉ dep'.toList)
    (e : makeCacheKey dep arr = makeCacheKey dep' arr') : dep = dep' ∧ arr = arr' := by
  have e := congrArg String.toList e
  simp only [makeCacheKey, String.toList_append] at e
  have : dep.toList ++ '-' :: arr.toList = dep'.toList ++ '-' :: arr'.toList := by simpa using e
  obtain ⟨h1, h2⟩ := append_sep_inj h h' this
  exact ⟨String.toList_inj.mp h1, String.toList_inj.mp h2⟩

end Abstraction.MasterData
