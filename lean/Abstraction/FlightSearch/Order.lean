import Abstraction.FlightSearch.Candidates

/-!
# Abstraction.FlightSearch.Order

ABS-011 の補題: 空席照会の文の `ORDER BY ft.display_order ASC, fm.departure_time ASC` と、[Spec] の整列
`mergeSort candidateLe` の対応。

- 整列キーの比較は、表示順（整数）と出発時刻（`HHmm` の文字列、符号位置の照合）の辞書式（`key_cmp`・`key_le`）。
  4 桁の数字列の文字列の順序は、時分の分数の順序に等しい（`hm_le_iff`）。
- 許される並びの写し（`candOfRow`）は、候補の `mergeSort candidateLe` に等しい（`sorted_cands`）。候補の間で
  表示順と出発時刻が同じなら同じ候補であること（同順位が無いこと）を前提とする。
- 許される並びは存在する（`sortAllowed_mergeSortRows`。具体側の 1 歩が空でないことの証人）。
-/

namespace Abstraction.FlightSearch.Order
open Abstraction.MasterData.AlphaLeaf Abstraction.FlightSearch.Candidates Spec.FlightSearch Spec.Prim.Time
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas LangSemantics.Core.MapM

open LangSemantics.Sql.Postgresql SourceModel.Repository.Flight SourceModel.Repository.MasterData Spec.MasterData Spec.Model

/-! ## 4 桁の数字列の順序 -/

theorem char_lt_iff (c d : Char) : c < d ↔ c.toNat < d.toNat := by
  rw [Char.lt_def, UInt32.lt_iff_toNat_lt]; rfl

theorem char_eq_iff (c d : Char) : c = d ↔ c.toNat = d.toNat := by
  constructor
  · rintro rfl; rfl
  · intro h; exact Char.ext (UInt32.toNat_inj.mp h)

theorem digit_some {c : Char} {v : Nat} (h : HourMinute.digitVal? c = some v) : c.toNat = v + 48 ∧ v < 10 := by
  unfold HourMinute.digitVal? at h
  split at h
  · rename_i hc
    cases h
    obtain ⟨h1, h2⟩ := hc
    have h1' : (48 : Nat) ≤ c.toNat := by
      have := (Char.le_def.mp h1); rw [UInt32.le_iff_toNat_le] at this; exact this
    have h2' : c.toNat ≤ 57 := by
      have := (Char.le_def.mp h2); rw [UInt32.le_iff_toNat_le] at this; exact this
    have : '0'.toNat = 48 := rfl
    omega
  · cases h

theorem hm_parts {s : String} {a : HourMinute} (h : hmOfStr s = some a) :
    ∃ c1 c2 c3 c4 v1 v2 v3 v4, s.toList = [c1, c2, c3, c4] ∧ c1.toNat = v1 + 48 ∧ c2.toNat = v2 + 48 ∧
      c3.toNat = v3 + 48 ∧ c4.toNat = v4 + 48 ∧ v1 < 10 ∧ v2 < 10 ∧ v3 < 10 ∧ v4 < 10 ∧
      a.hour = v1 * 10 + v2 ∧ a.minute = v3 * 10 + v4 := by
  unfold hmOfStr HourMinute.parseHHmm at h
  split at h
  · rename_i c1 c2 c3 c4 hs
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
    obtain ⟨v1, h1, v2, h2, v3, h3, v4, h4, h⟩ := h
    obtain ⟨e1, e2⟩ := ofHm?_eq_some h
    obtain ⟨d1, l1⟩ := digit_some h1
    obtain ⟨d2, l2⟩ := digit_some h2
    obtain ⟨d3, l3⟩ := digit_some h3
    obtain ⟨d4, l4⟩ := digit_some h4
    exact ⟨c1, c2, c3, c4, v1, v2, v3, v4, hs, d1, d2, d3, d4, l1, l2, l3, l4, e1, e2⟩
  · cases h

/-- `HHmm` の 4 桁の数字列の文字列の順序（符号位置）は、時分の分数の順序に等しい。 -/
theorem hm_le_iff {s t : String} {a b : HourMinute} (hs : hmOfStr s = some a) (ht : hmOfStr t = some b) :
    s ≤ t ↔ a.toMinutes ≤ b.toMinutes := by
  obtain ⟨c1, c2, c3, c4, v1, v2, v3, v4, hsl, d1, d2, d3, d4, l1, l2, l3, l4, e1, e2⟩ := hm_parts hs
  obtain ⟨k1, k2, k3, k4, w1, w2, w3, w4, htl, f1, f2, f3, f4, m1, m2, m3, m4, g1, g2⟩ := hm_parts ht
  have va := a.valid
  have vb := b.valid
  rw [← String.not_lt, String.lt_iff, hsl, htl]
  simp only [List.cons_lt_cons_iff, char_lt_iff, char_eq_iff, List.not_lt_nil, and_false, or_false]
  unfold HourMinute.toMinutes
  omega

/-! ## 整列キーの比較 -/

theorem key_cmp (a b : VacantSeatRow) :
    compareKeys sortCfg vacantSeatDirs (vacantSeatKey a) (vacantSeatKey b) =
      (compare a.displayOrder.val b.displayOrder.val).then (Collation.codepoint a.departureTime.val b.departureTime.val) := by
  simp only [compareKeys, compareKey, vacantSeatKey, vacantSeatDirs, Int4.toSql, Varchar.toSql, SqlValue.cmp,
    sortCfg, sortConfig, collationC, Option.getD_some]
  cases compare a.displayOrder.val b.displayOrder.val <;> cases Collation.codepoint a.departureTime.val b.departureTime.val <;> rfl

theorem key_le (a b : VacantSeatRow) :
    compareKeys sortCfg vacantSeatDirs (vacantSeatKey a) (vacantSeatKey b) ≠ .gt ↔
      a.displayOrder.val < b.displayOrder.val ∨
        (a.displayOrder.val = b.displayOrder.val ∧ a.departureTime.val ≤ b.departureTime.val) := by
  rw [key_cmp, ← Collation.codepoint_ne_gt]
  cases h : compare a.displayOrder.val b.displayOrder.val
  · rw [Int.compare_eq_lt] at h; simp [Ordering.then, h]
  · rw [Int.compare_eq_eq] at h; simp [Ordering.then, h]
  · rw [Int.compare_eq_gt] at h; simp only [Ordering.then]; constructor
    · intro e; exact absurd rfl e
    · intro e; omega

/-! ## 許される並びの存在 -/

/-- 許される並びの 1 つ（整列キーの比較で `mergeSort` したもの）。 -/
def mergeSortRows (rows : List VacantSeatRow) : List VacantSeatRow :=
  rows.mergeSort fun a b => compareKeys sortCfg vacantSeatDirs (vacantSeatKey a) (vacantSeatKey b) != .gt

theorem sortAllowed_mergeSortRows : SortAllowed mergeSortRows := by
  intro rows
  have hle : ∀ a b : VacantSeatRow,
      (compareKeys sortCfg vacantSeatDirs (vacantSeatKey a) (vacantSeatKey b) != .gt) = true ↔
        (a.displayOrder.val < b.displayOrder.val ∨
          (a.displayOrder.val = b.displayOrder.val ∧ a.departureTime.val ≤ b.departureTime.val)) := by
    intro a b; rw [bne_iff_ne]; exact key_le a b
  have hsorted := List.pairwise_mergeSort
    (le := fun a b => compareKeys sortCfg vacantSeatDirs (vacantSeatKey a) (vacantSeatKey b) != .gt)
    (fun a b c hab hbc => by
      rw [hle] at hab hbc ⊢
      rcases hab with h1 | ⟨h1, h2⟩ <;> rcases hbc with h3 | ⟨h3, h4⟩
      · exact Or.inl (by omega)
      · exact Or.inl (by omega)
      · exact Or.inl (by omega)
      · exact Or.inr ⟨by omega, String.le_trans h2 h4⟩)
    (fun a b => by
      rw [Bool.or_eq_true, hle, hle]
      rcases Int.lt_trichotomy a.displayOrder.val b.displayOrder.val with h | h | h
      · exact Or.inl (Or.inl h)
      · rcases String.le_total a.departureTime.val b.departureTime.val with h' | h'
        · exact Or.inl (Or.inr ⟨h, h'⟩)
        · exact Or.inr (Or.inr ⟨h.symm, h'⟩)
      · exact Or.inr (Or.inl h)) rows
  simp only [isAllowedOrder, Bool.and_eq_true, Bag.bagEq_iff_perm, List.all_eq_true, bne_iff_ne, ne_eq]
  refine ⟨(List.mergeSort_perm _ _).symm, fun p hp => ?_⟩
  have := adjacent_of_pairwise hsorted p hp
  simpa using this

/-! ## [Spec] の整列の性質 -/

theorem candidateLe_trans (a b c : Candidate) (hab : candidateLe a b = true) (hbc : candidateLe b c = true) :
    candidateLe a c = true := by
  simp only [candidateLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at *
  rcases hab with h1 | ⟨h1, h2 | ⟨h2, h3⟩⟩ <;> rcases hbc with h4 | ⟨h4, h5 | ⟨h5, h6⟩⟩ <;>
    first
    | exact Or.inl (by omega)
    | exact Or.inr ⟨by omega, Or.inl (by omega)⟩
    | exact Or.inr ⟨by omega, Or.inr ⟨by omega, String.le_trans h3 h6⟩⟩

theorem candidateLe_total (a b : Candidate) : (candidateLe a b || candidateLe b a) = true := by
  simp only [candidateLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
  rcases Nat.lt_trichotomy a.fareType.displayOrder b.fareType.displayOrder with h | h | h
  · exact Or.inl (Or.inl h)
  · rcases Nat.lt_trichotomy a.master.departureTime.toMinutes b.master.departureTime.toMinutes with h' | h' | h'
    · exact Or.inl (Or.inr ⟨h, Or.inl h'⟩)
    · rcases String.le_total a.flight.key.flightName.val b.flight.key.flightName.val with h'' | h''
      · exact Or.inl (Or.inr ⟨h, Or.inr ⟨h', h''⟩⟩)
      · exact Or.inr (Or.inr ⟨h.symm, Or.inr ⟨h'.symm, h''⟩⟩)
    · exact Or.inr (Or.inr ⟨h.symm, Or.inl h'⟩)
  · exact Or.inr (Or.inl h)

theorem candidateLe_refl (a : Candidate) : candidateLe a a = true := by
  simp [candidateLe]

/-! ## 許される並びと [Spec] の整列 -/

/-- 同順位が無いこと: 候補の間で、運賃種別の表示順と便マスタの出発時刻が同じなら、同じ候補。 -/
def NoTie (cs : List Candidate) : Prop :=
  ∀ X ∈ cs, ∀ Y ∈ cs, X.fareType.displayOrder = Y.fareType.displayOrder →
    X.master.departureTime = Y.master.departureTime → X = Y

/-- 許される並びの写しは、候補の `mergeSort candidateLe`。 -/
theorem sorted_cands {md : Spec.MasterData} {rows : List VacantSeatRow} {cs : List Candidate}
    (hmap : rows.mapM (candOfRow md) = some cs) (hok : ∀ row ∈ rows, ∃ X ∈ cs, RowOk md row X)
    (htie : NoTie cs) {o : List VacantSeatRow}
    (ho : isAllowedOrder sortCfg vacantSeatDirs vacantSeatKey rows o = true) :
    o.mapM (candOfRow md) = some (cs.mergeSort candidateLe) := by
  have hp : o.Perm rows := allowed_perm ho
  obtain ⟨o', ho', hpo⟩ := mapM_perm hp hmap
  have hsq := ho
  simp only [isAllowedOrder, Bool.and_eq_true, List.all_eq_true, bne_iff_ne, ne_eq] at hsq
  -- 行の上の関係: 両方とも結果の行で、写しが candidateLe を満たす
  let R : VacantSeatRow → VacantSeatRow → Prop := fun a b => a ∈ rows ∧ b ∈ rows ∧
    ∀ x y, candOfRow md a = some x → candOfRow md b = some y → candidateLe x y = true
  have htrans : ∀ a b c, R a b → R b c → R a c := by
    intro a b c ⟨ha, hb, hab⟩ ⟨_, hc, hbc⟩
    refine ⟨ha, hc, fun x z hx hz => ?_⟩
    obtain ⟨y, -, hy, -⟩ := hok b hb
    exact candidateLe_trans x y z (hab x y hx hy) (hbc y z hy hz)
  have hpw : o.Pairwise R := by
    apply pairwise_of_adjacent htrans
    intro p hpm
    have h1 : p.1 ∈ rows := hp.mem_iff.mp (List.of_mem_zip hpm).1
    have h2 : p.2 ∈ rows := hp.mem_iff.mp (List.mem_of_mem_tail (List.of_mem_zip hpm).2)
    refine ⟨h1, h2, fun x y hx hy => ?_⟩
    obtain ⟨X, hX, hx', hd1, ht1⟩ := hok p.1 h1
    obtain ⟨Y, hY, hy', hd2, ht2⟩ := hok p.2 h2
    rw [hx] at hx'; cases hx'
    rw [hy] at hy'; cases hy'
    have hk := (key_le p.1 p.2).mp (hsq.2 p hpm)
    have e1 := natOfInt4_eq_some.mp hd1
    have e2 := natOfInt4_eq_some.mp hd2
    rw [hm_le_iff ht1 ht2] at hk
    simp only [candidateLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
    rcases hk with hk | ⟨hk1, hk2⟩
    · exact Or.inl (by omega)
    · rcases Nat.lt_or_eq_of_le hk2 with hk2 | hk2
      · exact Or.inr ⟨by omega, Or.inl hk2⟩
      · have := htie x hX y hY (by omega) (HourMinute.toMinutes_inj hk2)
        subst this
        exact Or.inr ⟨rfl, Or.inr ⟨rfl, String.le_refl _⟩⟩
  have hpw' : o'.Pairwise fun a b => candidateLe a b = true :=
    mapM_pairwise ho' (hpw.imp fun ⟨_, _, h⟩ => h)
  have hms := List.pairwise_mergeSort (le := candidateLe) candidateLe_trans candidateLe_total cs
  rw [ho']
  congr 1
  refine eq_of_perm_of_pairwise (R := fun a b => candidateLe a b = true) ?_
    (hpo.trans (List.mergeSort_perm cs candidateLe).symm) hpw' hms
  intro a ha b hb hab hba
  have ha' := hpo.mem_iff.mp ha
  have hb' := hpo.mem_iff.mp hb
  simp only [candidateLe, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at hab hba
  apply htie a ha' b hb'
  · omega
  · apply HourMinute.toMinutes_inj; omega

/-! ## 同順位の無さ -/

theorem candidateOf_cond {md : Spec.MasterData} {c : Criteria} {route : Route} {bdn : Int} {F : Flight}
    {X : Candidate} (h : candidateOf md c route bdn F = some X) :
    X.flight = F ∧ md.flightMasterOf F.key.flightName = some X.master ∧ md.fareTypeOf F.key.fareTypeCd = some X.fareType ∧
      F.key.departureDate = c.depDate ∧ X.master.routeNo = route.routeNo ∧ F.key.boardingClassCd = c.boardingClassCd ∧
      F.key.fareTypeCd ∈ fareTypesFor c.flightType := by
  unfold candidateOf at h
  simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
  obtain ⟨fm, hfm, ft, hft, h⟩ := h
  split at h
  · rename_i hc
    cases h
    exact ⟨rfl, hfm, hft, hc.1, hc.2.1, hc.2.2.1, hc.2.2.2.1⟩
  · cases h

/-- MD-1（運賃種別の表示順の一意性）・MD-5（同じ区間の便マスタの出発時刻の一意性）・`World.Inv`（フライトの主キーの
一意性）の下で、照会の候補には同順位が無い。 -/
theorem noTie_cands {cfg : Spec.Config} {md : Spec.MasterData} (hv : md.Valid cfg) {w : Spec.Port.World}
    (hw : w.Inv) (c : Criteria) (route : Route) (bdn : Int) :
    NoTie (w.flights.filterMap (candidateOf md c route bdn)) := by
  intro X hX Y hY hdo hdt
  obtain ⟨F, hF, hFX⟩ := List.mem_filterMap.mp hX
  obtain ⟨G, hG, hGY⟩ := List.mem_filterMap.mp hY
  obtain ⟨eX, fmX, ftX, dX, rX, bX, -⟩ := candidateOf_cond hFX
  obtain ⟨eY, fmY, ftY, dY, rY, bY, -⟩ := candidateOf_cond hGY
  -- 運賃種別
  have hft : X.fareType = Y.fareType :=
    LangSemantics.Core.List.inj_of_nodup_map hv.md1.2.2.2.2.2.2.2.2.2.2.1 (List.mem_of_find?_eq_some ftX)
      (List.mem_of_find?_eq_some ftY) hdo
  -- 便マスタ
  have hsym : ∀ f g : Spec.MasterData.FlightMaster, (f.routeNo = g.routeNo → f.departureTime ≠ g.departureTime) →
      (g.routeNo = f.routeNo → g.departureTime ≠ f.departureTime) := fun _ _ h e e' => h e.symm e'.symm
  have hfm : X.master = Y.master := by
    refine Classical.byContradiction fun hne => ?_
    exact LangSemantics.Core.List.rel_of_pairwise_symm hsym hv.md5 (List.mem_of_find?_eq_some fmX)
      (List.mem_of_find?_eq_some fmY) hne (by rw [rX, rY]) hdt
  have nX := List.find?_some fmX
  have nY := List.find?_some fmY
  have cX := List.find?_some ftX
  have cY := List.find?_some ftY
  simp only [beq_iff_eq] at nX nY cX cY
  -- フライト
  have hk : F.key = G.key := by
    show (⟨F.key.departureDate, F.key.flightName, F.key.boardingClassCd, F.key.fareTypeCd⟩ : FlightKey) =
      ⟨G.key.departureDate, G.key.flightName, G.key.boardingClassCd, G.key.fareTypeCd⟩
    rw [dX, dY, bX, bY, ← nX, ← nY, hfm, ← cX, ← cY, hft]
  have hFG : F = G := LangSemantics.Core.List.inj_of_nodup_map hw hF hG hk
  obtain ⟨xf, xm, xt⟩ := X
  obtain ⟨yf, ym, yt⟩ := Y
  simp only at eX eY hft hfm
  rw [eX, eY, hFG, hft, hfm]

end Abstraction.FlightSearch.Order
