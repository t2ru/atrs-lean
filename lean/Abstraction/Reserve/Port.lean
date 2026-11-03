import Abstraction.World.Alpha
import Abstraction.FlightSearch.Alpha
import SourceModel.Domain.Repository.Flight.FlightRepository
import SourceModel.Domain.Repository.Member.MemberRepository
import SourceModel.Domain.Repository.Reservation.ReservationRepository

/-!
# Abstraction.Reserve.Port

L 課題 ABS-023 の補題: 予約が使うリポジトリの文（`LangSemantics.Sql` で写した SQL）の結果を、α `worldOfDb` の像の
`World` のポートの操作（`lean/Spec/Port.lean`）で表す（backlog aedf の第 3 段）。

- FLIGHT: 主キーの条件 `keyCond`、`exists`・`findOneForUpdate`・`update` の行
-/

namespace Abstraction.Reserve.Port
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.World.Alpha Abstraction.FlightSearch.Alpha
  Spec.Model Machine.Kernel
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.Postgresql SourceModel.Db.Schema Spec.Prim
open SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository

/-! ## FLIGHT の主キー -/

/-- 主キー `k` の束縛変数。 -/
def keyParams (k : FlightKey) : KeyParams :=
  ⟨.date k.departureDate.epochDay, .text k.flightName.val, .text k.boardingClassCd.toCode, .text k.fareTypeCd.toCode⟩

theorem toCode_inj_bc {a b : BoardingClassCd} (h : a.toCode = b.toCode) : a = b := by
  cases a <;> cases b <;> first | rfl | exact absurd h (by decide)

theorem toCode_inj_ft {a b : FareTypeCd} (h : a.toCode = b.toCode) : a = b := by
  cases a <;> cases b <;> first | rfl | exact absurd h (by decide)

/-- 主キーの条件は、行の α のフライトの主キーの等しさ。 -/
theorem keyCond_holds {r : FlightRow} {f : Flight} (hf : flightOfRow r = some f) (k : FlightKey) :
    (keyCond (keyParams k) r).holds = (f.key == k) := by
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hf
  obtain ⟨d, hd, bc, hbc, ft, hft, v, -, rfl⟩ := hf
  have ed := Date.epochDay_ofEpochDay? hd
  have ebc := bcCdOf_eq_some hbc
  have eft := ftCdOf_eq_some hft
  obtain ⟨kd, ⟨kn⟩, kbc, kft⟩ := k
  simp only [keyCond, keyParams, Truth.holds_and, PgDate.toSql, Varchar.toSql, collationC,
    SqlValue.eq_date_holds, SqlValue.eq_text_holds, ebc, eft]
  rw [Bool.eq_iff_iff]
  simp only [Bool.and_eq_true, beq_iff_eq, FlightKey.mk.injEq, FlightName.mk.injEq]
  constructor
  · rintro ⟨h1, h2, h3, h4⟩
    exact ⟨Date.epochDay_inj (by omega), h2, toCode_inj_bc h3, toCode_inj_ft h4⟩
  · rintro ⟨rfl, rfl, rfl, rfl⟩
    exact ⟨by omega, rfl, rfl, rfl⟩

/-- `Bag.select (keyCond …)` の行の α は、主キーで選んだフライト。 -/
theorem select_key {rs : List FlightRow} {fs : List Flight} (h : rs.mapM flightOfRow = some fs) (k : FlightKey) :
    (Bag.select (keyCond (keyParams k)) rs).mapM flightOfRow = some (fs.filter (·.key == k)) := by
  induction rs generalizing fs with
  | nil => simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | cons r rs ih =>
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨f, hf, fs', hfs, rfl⟩ := h
    simp only [Bag.select, List.filter_cons, keyCond_holds hf] at ih ⊢
    split
    · simp [List.mapM_cons, hf, ih hfs]
    · exact ih hfs

/-- `exists` の文の結果は、`World.existsFlight`。 -/
@[obligation "ABS-023"]
theorem existsRows_eq {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (k : FlightKey) :
    existsRows fd (keyParams k) = w.existsFlight k := by
  have hs := select_key (worldOfDb_flights hw) k
  unfold existsRows Bag.exists' Spec.Port.World.existsFlight
  have hl := LangSemantics.Core.MapM.mapM_length hs
  rw [Bool.eq_iff_iff]
  simp only [Bool.not_eq_true', List.isEmpty_eq_false_iff, ne_eq, List.any_eq_true]
  constructor
  · intro hne
    have : (w.flights.filter (·.key == k)).length ≠ 0 := by
      rw [← hl]; intro e; exact hne (List.length_eq_zero_iff.mp e)
    obtain ⟨f, hf⟩ := List.exists_mem_of_length_pos (Nat.pos_of_ne_zero this)
    simp only [List.mem_filter] at hf
    exact ⟨f, hf⟩
  · rintro ⟨f, hm, hk⟩ e
    rw [e] at hl
    have : f ∈ w.flights.filter (·.key == k) := List.mem_filter.mpr ⟨hm, hk⟩
    rw [List.length_eq_zero_iff.mp hl.symm] at this
    cases this

/-- 主キーが一意なら、主キーで選んだフライトの列は `findForUpdate` の結果（高々 1 つ）。 -/
theorem filter_key_eq : ∀ {fs : List Flight}, (fs.map (·.key)).Nodup → ∀ k : FlightKey,
    fs.filter (·.key == k) = (fs.find? (·.key == k)).toList
  | [], _, _ => rfl
  | f :: fs, hn, k => by
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at hn
    by_cases hk : (f.key == k) = true
    · have : fs.filter (·.key == k) = [] := by
        rw [List.filter_eq_nil_iff]
        intro g hg e
        exact hn.1 ⟨g, hg, (beq_iff_eq.mp e).trans (beq_iff_eq.mp hk).symm⟩
      simp [hk, this]
    · simp only [Bool.not_eq_true] at hk
      simp [hk, filter_key_eq hn.2 k]

/-- `findOneForUpdate` の文の行: 主キーのフライトがあれば、その行 1 つ。 -/
@[obligation "ABS-023"]
theorem select_key_find {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (hinv : w.Inv)
    (k : FlightKey) :
    (Bag.select (keyCond (keyParams k)) fd.flight).mapM flightOfRow = some (w.findForUpdate k).toList := by
  rw [select_key (worldOfDb_flights hw) k, filter_key_eq hinv k]
  rfl

/-- `update` の文: 主キーのフライトがあり、空席数 `v` が非負なら、更新件数は 1 で、α の像は `World.updateVacantNum`。 -/
@[obligation "ABS-023"]
theorem updateWhere_alpha {k : FlightKey} {n : Nat} {v : Int4} (hv : v.val = n) :
    ∀ {rs : List FlightRow} {fs : List Flight}, rs.mapM flightOfRow = some fs →
      (updateWhere (keyCond (keyParams k)) (fun f => { f with vacantNum := v }) rs).1.mapM flightOfRow =
          some (fs.map fun f => if f.key == k then { f with vacantNum := n } else f) ∧
        (updateWhere (keyCond (keyParams k)) (fun f => { f with vacantNum := v }) rs).2 = (fs.filter (·.key == k)).length
  | [], fs, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact ⟨rfl, rfl⟩
  | r :: rs, fs, h => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨f, hf, fs', hfs, rfl⟩ := h
    obtain ⟨ih1, ih2⟩ := updateWhere_alpha (k := k) hv hfs
    simp only [updateWhere, List.foldr_cons] at ih1 ih2 ⊢
    rw [keyCond_holds hf]
    split
    · rename_i hk
      refine ⟨?_, by simp [hk, ih2]⟩
      simp only [List.mapM_cons, ih1, List.map_cons, hk, ite_true]
      have : flightOfRow { r with vacantNum := v } = some { f with vacantNum := n } := by
        simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
          Option.some.injEq] at hf ⊢
        obtain ⟨d, hd, bc, hbc, ft, hft, w, -, rfl⟩ := hf
        refine ⟨d, hd, bc, hbc, ft, hft, n, ?_, rfl⟩
        simp [natOfInt4, hv]
      simp [this]
    · rename_i hk
      refine ⟨?_, by simp [hk, ih2]⟩
      have hk' : f.key ≠ k := fun e => by simp [e] at hk
      simp [List.mapM_cons, ih1, hf, hk']

end Abstraction.Reserve.Port
