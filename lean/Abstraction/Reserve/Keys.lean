import Abstraction.World.Alpha
import LangSemantics.Core.MapM
import Spec.Port

/-!
# Abstraction.Reserve.Keys

ABS-041 の補題: 予約の表の主キー（backlog aedf の第 3 段）。

- 予約番号の書式（10 桁ゼロ埋めの十進文字列）は単射。
- 主キーの性質 `KeysOk` から、既存の予約・予約フライト・搭乗者の行の番号は採番の次の値より小さい（新しい番号と重ならない）。
-/

namespace Abstraction.Reserve.Keys
open Abstraction.World.Alpha SourceModel.Db.Schema

/-- 10 進の数字列の値（左から）。 -/
def decode (l : List Char) : Nat := l.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0

theorem decode_append (l : List Char) (c : Char) : decode (l ++ [c]) = decode l * 10 + (c.toNat - 48) := by
  simp [decode, List.foldl_append]

theorem foldl_zeros : ∀ k : Nat,
    (List.replicate k '0').foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0 = 0
  | 0 => rfl
  | k + 1 => by
    rw [List.replicate_succ, List.foldl_cons]
    exact foldl_zeros k

theorem decode_zeros (k : Nat) (l : List Char) : decode (List.replicate k '0' ++ l) = decode l := by
  simp only [decode, List.foldl_append, foldl_zeros]

theorem decode_digitChar {d : Nat} (h : d < 10) : (Nat.digitChar d).toNat - 48 = d := by
  match d, h with
  | 0, _ | 1, _ | 2, _ | 3, _ | 4, _ | 5, _ | 6, _ | 7, _ | 8, _ | 9, _ => rfl

theorem decode_toDigits (n : Nat) : decode (Nat.toDigits 10 n) = n := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    rw [Nat.toDigits_eq_ite (by decide)]
    split
    · rename_i h
      simp only [decode, List.foldl_cons, List.foldl_nil, Nat.zero_mul, Nat.zero_add]
      exact decode_digitChar h
    · rename_i h
      rw [decode_append, ih (n / 10) (by omega), decode_digitChar (Nat.mod_lt _ (by decide))]
      omega

theorem toString_toList (n : Nat) : (toString n).toList = Nat.toDigits 10 n := by
  simp [toString, Nat.repr]

/-- 10 桁ゼロ埋めの十進文字列は単射（予約番号の書式）。 -/
theorem reserveNoOf_inj {n m : Nat} (h : (Spec.Port.World.reserveNoOf n).val = (Spec.Port.World.reserveNoOf m).val) :
    n = m := by
  simp only [Spec.Port.World.reserveNoOf, Spec.Model.ReserveNo.val, Spec.Prim.Format.padNat] at h
  have h' := congrArg (fun s => decode s.toList) h
  simp only [String.toList_append, String.toList_ofList, decode_zeros, toString_toList, decode_toDigits] at h'
  exact h'


/-- 予約番号の表記を読むと、元の予約番号に戻る。 -/
theorem ofString?_val (n : Spec.Model.ReserveNo) : Spec.Model.ReserveNo.ofString? n.val = some n := by
  have hd : decode n.val.toList = n.num := by
    simp only [Spec.Model.ReserveNo.val, Spec.Prim.Format.padNat, String.toList_append, String.toList_ofList,
      decode_zeros, toString_toList, decode_toDigits]
  unfold Spec.Model.ReserveNo.ofString?
  simp only [show (⟨n.val.toList.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0⟩ : Spec.Model.ReserveNo) = n from by
    cases n; simp only [Spec.Model.ReserveNo.mk.injEq]; exact hd, ite_true]

theorem reservationOfRow_no {r : ReservationRow} {fs : List Spec.Model.ReserveFlight} {R : Spec.Model.Reservation}
    (h : reservationOfRow r fs = some R) : R.reserveNo.val = r.reserveNo.val ∧ R.reserveFlights = fs := by
  simp only [reservationOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
  obtain ⟨_, -, _, -, _, -, _, -, _, hrn, rfl⟩ := h
  exact ⟨Spec.Model.ReserveNo.val_of_ofString? hrn, rfl⟩

theorem reserveFlightOfRow_no {r : ReserveFlightRow} {ps : List Spec.Model.PassengerRecord}
    {F : Spec.Model.ReserveFlight} (h : reserveFlightOfRow r ps = some F) :
    r.reserveFlightNo.val = (F.reserveFlightNo : Int) ∧ F.passengers = ps := by
  simp only [reserveFlightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h
  obtain ⟨no, hno, _, -, _, -, _, -, _, -, _, -, rfl⟩ := h
  exact ⟨Abstraction.MasterData.AlphaLeaf.natOfInt4_eq_some.mp hno, rfl⟩

/-- 予約の表の行は、α の像の予約・予約フライト・搭乗者に当たる。 -/
theorem rows_of_world {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) :
    (∀ x ∈ fd.reservation, ∃ R ∈ w.reservations, R.reserveNo.val = x.reserveNo.val) ∧
    (∀ g ∈ fd.reserveFlight, ∃ R ∈ w.reservations, ∃ F ∈ R.reserveFlights,
      g.reserveFlightNo.val = (F.reserveFlightNo : Int)) ∧
    (∀ p ∈ fd.passenger, ∃ R ∈ w.reservations, ∃ F ∈ R.reserveFlights, ∃ P ∈ F.passengers,
      p.passengerNo.val = (P.passengerNo : Int)) := by
  have hr := (worldOfDb_eq_some.mp hw).2.2.1
  unfold reservationsOf at hr
  split at hr
  · rename_i hwf
    obtain ⟨hw1, hw2⟩ := hwf
    -- 予約フライトの行の α
    have hrf : ∀ g ∈ fd.reserveFlight, ∃ R ∈ w.reservations, ∃ F ∈ R.reserveFlights, rfOf fd.passenger g = some F := by
      intro g hg
      have hg' := hg
      rw [hw1] at hg'
      obtain ⟨x, hx, hgx⟩ := List.mem_flatMap.mp hg'
      obtain ⟨R, hR, hxR⟩ := LangSemantics.Core.MapM.mapM_some_mem hr hx
      simp only [resOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at hxR
      obtain ⟨fs, hfs, hxr⟩ := hxR
      obtain ⟨F, hF, hgF⟩ := LangSemantics.Core.MapM.mapM_some_mem hfs hgx
      exact ⟨R, hR, F, (reservationOfRow_no hxr).2 ▸ hF, hgF⟩
    refine ⟨?_, ?_, ?_⟩
    · intro x hx
      obtain ⟨R, hR, hxR⟩ := LangSemantics.Core.MapM.mapM_some_mem hr hx
      simp only [resOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at hxR
      obtain ⟨fs, -, hxr⟩ := hxR
      exact ⟨R, hR, (reservationOfRow_no hxr).1⟩
    · intro g hg
      obtain ⟨R, hR, F, hF, hgF⟩ := hrf g hg
      simp only [rfOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at hgF
      obtain ⟨xs, -, hgr⟩ := hgF
      exact ⟨R, hR, F, hF, (reserveFlightOfRow_no hgr).1⟩
    · intro p hp
      have hp' := hp
      rw [hw2] at hp'
      obtain ⟨g, hg, hpg⟩ := List.mem_flatMap.mp hp'
      obtain ⟨R, hR, F, hF, hgF⟩ := hrf g hg
      simp only [rfOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at hgF
      obtain ⟨xs, hxs, hgr⟩ := hgF
      obtain ⟨P, hP, hpP⟩ := LangSemantics.Core.MapM.mapM_some_mem hxs hpg
      refine ⟨R, hR, F, hF, P, (reserveFlightOfRow_no hgr).2 ▸ hP, ?_⟩
      simp only [passengerOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
        Option.some.injEq] at hpP
      obtain ⟨no, hno, -, -, -, -, rfl⟩ := hpP
      exact Abstraction.MasterData.AlphaLeaf.natOfInt4_eq_some.mp hno
  · cases hr

/-- 主キーの性質（`KeysOk`）から、予約の表の行の番号は採番の次の値より小さい。 -/
theorem rows_lt {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) (hk : KeysOk w) :
    (∀ x ∈ fd.reservation, ∃ n, n < w.sequences.reserve ∧ x.reserveNo.val = (Spec.Port.World.reserveNoOf n).val) ∧
    (∀ g ∈ fd.reserveFlight, g.reserveFlightNo.val < (w.sequences.reserveFlight : Int)) ∧
    (∀ p ∈ fd.passenger, p.passengerNo.val < (w.sequences.passenger : Int)) := by
  obtain ⟨h1, h2, h3⟩ := rows_of_world hw
  refine ⟨fun x hx => ?_, fun g hg => ?_, fun p hp => ?_⟩
  · obtain ⟨R, hR, e⟩ := h1 x hx
    obtain ⟨⟨n, hn, hRn⟩, -⟩ := hk.2 R hR
    exact ⟨n, hn, e.symm.trans (congrArg Spec.Model.ReserveNo.val hRn)⟩
  · obtain ⟨R, hR, F, hF, e⟩ := h2 g hg
    have := ((hk.2 R hR).2 F hF).1
    omega
  · obtain ⟨R, hR, F, hF, P, hP, e⟩ := h3 p hp
    have := ((hk.2 R hR).2 F hF).2 P hP
    omega

end Abstraction.Reserve.Keys
