import Abstraction.World.Alpha
import SourceModel.Domain.Repository.Reservation.ReservationRepository

/-!
# Abstraction.Reserve.Register

ABS-041 の補題（L 課題 ABS-021 を含む）: 予約の登録（採番と挿入）の文の結果と、[Spec] の `register` の対応
（backlog aedf の第 3 段）。
-/

namespace Abstraction.Reserve.Register
open Abstraction.World.Alpha LangSemantics.Sql.Sequence

/-- L 課題 ABS-021（採番）: 採番の文（`nextval`）は、次の値が `n`（最大値以下）なら、`n` を返し、次の値を `n + 1`
にする（[Spec] の `IdGenerator` の参照実装 `n`, `n+1`, …）。 -/
@[obligation "ABS-021"]
theorem nextval_seq {d : SequenceDef} (h1 : d.minValue = 1) (h2 : d.increment = 1) (h3 : d.start = 1)
    {st : SequenceState} {n : Nat} (h : seqOf st = some n) (hn : (n : Int) ≤ d.maxValue) :
    nextval d st = .ok ((n : Int), some (n : Int)) ∧ seqOf (some (n : Int)) = some (n + 1) := by
  cases st with
  | none =>
    simp only [seqOf, Option.some.injEq] at h
    subst h
    refine ⟨by simp [nextval, h3], by simp [seqOf]⟩
  | some v =>
    simp only [seqOf] at h
    split at h
    · rename_i hv
      simp only [Option.some.injEq] at h
      subst h
      refine ⟨?_, by simp [seqOf]; omega⟩
      have hb : ¬ (v + d.increment > d.maxValue || v + d.increment < d.minValue) = true := by
        rw [h1, h2]; simp; omega
      simp only [nextval, hb]
      rw [h2]
      simp only [Bool.false_eq_true, ite_false]
      have e : v + 1 = ((v.toNat + 1 : Nat) : Int) := by omega
      rw [e]
    · cases h

theorem toDigits_len {n : Nat} (hn : n ≤ 9999999999) : (Nat.toDigits 10 n).length ≤ 10 :=
  (Nat.length_toDigits_le_iff (by decide) (by decide)).mpr (by omega)

/-- L 課題 ABS-021（採番）: 予約番号の書式（`TO_CHAR(n, 'FM0999999999')`）は、[Spec] の予約番号の書式（10 桁ゼロ埋め）。 -/
@[obligation "ABS-021"]
theorem toChar_reserveNo {n : Nat} (hn : n ≤ 9999999999) :
    LangSemantics.Sql.Postgresql.toChar (n : Int) "FM0999999999" = some (Spec.Port.World.reserveNoOf n).val := by
  have e : "FM0999999999".toList = ['F', 'M', '0', '9', '9', '9', '9', '9', '9', '9', '9', '9'] := rfl
  have hd : (toString (n : Int).natAbs).toList = Nat.toDigits 10 n := by
    simp [toString, Nat.repr]
  have hl := toDigits_len hn
  unfold LangSemantics.Sql.Postgresql.toChar
  rw [e]
  have hlen : (toString n).length = (Nat.toDigits 10 n).length := by
    simp [toString, Nat.repr, String.length]
  simp (config := { decide := true }) only [hd, Spec.Port.World.reserveNoOf, Spec.Model.ReserveNo.val, Spec.Prim.Format.padNat, hlen,
    List.length_cons, List.length_nil, ite_false, Int.natCast_nonneg, Int.not_lt.mpr]
  have hfz : List.findIdx (fun x => x == '0') ['0', '9', '9', '9', '9', '9', '9', '9', '9', '9'] = 0 := by decide
  have hgt : ¬ (Nat.toDigits 10 n).length > 0 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 := by omega
  have hmax : max (0 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 0) (Nat.toDigits 10 n).length = 10 := by omega
  have hts : toString n = String.ofList (Nat.toDigits 10 n) := by simp [toString, Nat.repr]
  simp only [hgt, ite_false, ite_true, hfz, hmax, String.empty_append, hts, String.ofList_append]

/-! ## 予約の表の末尾への追加 -/

open SourceModel.Db.Schema

theorem flightsOf_append (a b : List ReserveFlightRow) (r : ReservationRow) :
    flightsOf (a ++ b) r = flightsOf a r ++ flightsOf b r := List.filter_append ..

theorem passengersOf_append (a b : List PassengerRow) (r : ReserveFlightRow) :
    passengersOf (a ++ b) r = passengersOf a r ++ passengersOf b r := List.filter_append ..

theorem flightsOf_nil {rfs : List ReserveFlightRow} {r : ReservationRow}
    (h : ∀ g ∈ rfs, g.reserveNo ≠ r.reserveNo) : flightsOf rfs r = [] := by
  rw [flightsOf, List.filter_eq_nil_iff]
  intro g hg e
  exact h g hg (beq_iff_eq.mp e)

theorem passengersOf_nil {ps : List PassengerRow} {r : ReserveFlightRow}
    (h : ∀ p ∈ ps, p.reserveFlightNo ≠ r.reserveFlightNo) : passengersOf ps r = [] := by
  rw [passengersOf, List.filter_eq_nil_iff]
  intro p hp e
  exact h p hp (beq_iff_eq.mp e)

theorem mem_flatMap_flightsOf {rs : List ReservationRow} {rfs : List ReserveFlightRow} {g : ReserveFlightRow}
    (h : g ∈ rs.flatMap (flightsOf rfs)) : ∃ r ∈ rs, g.reserveNo = r.reserveNo := by
  simp only [List.mem_flatMap, flightsOf, List.mem_filter, beq_iff_eq] at h
  obtain ⟨r, hr, -, e⟩ := h
  exact ⟨r, hr, e⟩

theorem mem_flatMap_passengersOf {rfs : List ReserveFlightRow} {ps : List PassengerRow} {p : PassengerRow}
    (h : p ∈ rfs.flatMap (passengersOf ps)) : ∃ g ∈ rfs, p.reserveFlightNo = g.reserveFlightNo := by
  simp only [List.mem_flatMap, passengersOf, List.mem_filter, beq_iff_eq] at h
  obtain ⟨g, hg, -, e⟩ := h
  exact ⟨g, hg, e⟩

theorem mapM_congr' {α β : Type} {f g : α → Option β} :
    ∀ {l : List α}, (∀ x ∈ l, f x = g x) → l.mapM f = l.mapM g
  | [], _ => rfl
  | x :: l, h => by
    simp only [List.mapM_cons, h x (List.mem_cons_self ..), mapM_congr' fun y hy => h y (List.mem_cons_of_mem _ hy)]

/-- 予約の表の末尾に、新しい予約の行 `row` と、その予約フライトの行 `nfs`・搭乗者の行 `nps` を足したときの α。
新しい予約番号・予約フライト番号は既存の行に無いとする。 -/
theorem reservationsOf_append {rs : List ReservationRow} {rfs : List ReserveFlightRow} {ps : List PassengerRow}
    {R : List Spec.Model.Reservation} (h : reservationsOf rs rfs ps = some R) {row : ReservationRow}
    {nfs : List ReserveFlightRow} {nps : List PassengerRow} {r : Spec.Model.Reservation}
    (hrow : ∀ x ∈ rs, x.reserveNo ≠ row.reserveNo)
    (hnfs : ∀ g ∈ nfs, g.reserveNo = row.reserveNo)
    (hrf : ∀ f ∈ rfs, ∀ g ∈ nfs, f.reserveFlightNo ≠ g.reserveFlightNo)
    (hnps : nps = nfs.flatMap (passengersOf nps))
    (hr : resOf nfs nps row = some r) :
    reservationsOf (rs ++ [row]) (rfs ++ nfs) (ps ++ nps) = some (R ++ [r]) := by
  unfold reservationsOf at h ⊢
  split at h
  · rename_i hw
    obtain ⟨hw1, hw2⟩ := hw
    -- 既存の予約フライトの行の予約番号は既存の予約のもの
    have hold : ∀ f ∈ rfs, f.reserveNo ≠ row.reserveNo := by
      intro f hf
      rw [hw1] at hf
      obtain ⟨x, hx, e⟩ := mem_flatMap_flightsOf hf
      rw [e]; exact hrow x hx
    have holdp : ∀ p ∈ ps, ∀ g ∈ nfs, p.reserveFlightNo ≠ g.reserveFlightNo := by
      intro p hp g hg
      rw [hw2] at hp
      obtain ⟨f, hf, e⟩ := mem_flatMap_passengersOf hp
      rw [e]; exact hrf f hf g hg
    have hnewp : ∀ p ∈ nps, ∀ f ∈ rfs, p.reserveFlightNo ≠ f.reserveFlightNo := by
      intro p hp f hf
      rw [hnps] at hp
      obtain ⟨g, hg, e⟩ := mem_flatMap_passengersOf hp
      rw [e]; exact fun e' => hrf f hf g hg e'.symm
    have hfo : ∀ x ∈ rs, flightsOf (rfs ++ nfs) x = flightsOf rfs x := by
      intro x hx
      rw [flightsOf_append, flightsOf_nil (rfs := nfs) (fun g hg e => hrow x hx (e.symm.trans (hnfs g hg))),
        List.append_nil]
    have hfr : flightsOf (rfs ++ nfs) row = nfs := by
      rw [flightsOf_append, flightsOf_nil hold, List.nil_append, flightsOf, List.filter_eq_self]
      intro g hg
      simp [hnfs g hg]
    have hpo : ∀ f ∈ rfs, passengersOf (ps ++ nps) f = passengersOf ps f := by
      intro f hf
      rw [passengersOf_append, passengersOf_nil (fun p hp => hnewp p hp f hf), List.append_nil]
    have hpn : ∀ g ∈ nfs, passengersOf (ps ++ nps) g = passengersOf nps g := by
      intro g hg
      rw [passengersOf_append, passengersOf_nil (fun p hp => holdp p hp g hg), List.nil_append]
    have hc1 : rfs ++ nfs = (rs ++ [row]).flatMap (flightsOf (rfs ++ nfs)) := by
      rw [List.flatMap_append, List.flatMap_singleton, hfr]
      congr 1
      rw [flatMap_congr' hfo]
      exact hw1
    have hc2 : ps ++ nps = (rfs ++ nfs).flatMap (passengersOf (ps ++ nps)) := by
      rw [List.flatMap_append, flatMap_congr' hpo, flatMap_congr' hpn, ← hw2, ← hnps]
    have hold' : rs.mapM (resOf (rfs ++ nfs) (ps ++ nps)) = rs.mapM (resOf rfs ps) := by
      apply mapM_congr'
      intro x hx
      simp only [resOf, hfo x hx]
      congr 1
      apply mapM_congr'
      intro f hf
      have hf' : f ∈ rfs := (List.mem_filter.mp hf).1
      simp only [rfOf, hpo f hf']
    have hfr' : flightsOf nfs row = nfs := by
      rw [flightsOf, List.filter_eq_self]
      intro g hg
      simp [hnfs g hg]
    have hnew : resOf (rfs ++ nfs) (ps ++ nps) row = some r := by
      rw [← hr]
      simp only [resOf, hfr, hfr']
      congr 1
      apply mapM_congr'
      intro g hg
      simp only [rfOf, hpn g hg]
    split
    · rw [List.mapM_append, hold', h]
      simp [hnew]
    · rename_i hn
      exact absurd ⟨hc1, hc2⟩ hn
  · cases h

end Abstraction.Reserve.Register
