import Spec.UseCase.Reserve

/-!
# Abstraction.Reserve.RegSpec

ABS-041 の補題: [Spec] の予約の登録（`register`）の採番の分解（backlog aedf の第 3 段）。搭乗者・予約フライトの記録は、
採番の次の値から順に番号を振ったもの。
-/

namespace Abstraction.Reserve.RegSpec
open Spec.UseCase.Reserve Spec.Model

/-- 位置 `n` から採番した搭乗者の記録。 -/
def recsFrom : Nat → List Passenger → List PassengerRecord
  | _, [] => []
  | n, q :: qs => ⟨n, q⟩ :: recsFrom (n + 1) qs

/-- 搭乗者の採番を `k` だけ進める。 -/
def advP (w : Spec.Port.World) (k : Nat) : Spec.Port.World :=
  { w with sequences := { w.sequences with passenger := w.sequences.passenger + k } }

theorem foldl_addPassenger : ∀ (qs : List Passenger) (pre : List PassengerRecord) (w : Spec.Port.World),
    qs.foldl addPassenger (pre, w) = (pre ++ recsFrom w.sequences.passenger qs, advP w qs.length)
  | [], pre, w => by simp [recsFrom, advP]
  | q :: qs, pre, w => by
    rw [List.foldl_cons]
    simp only [addPassenger, Spec.Port.World.nextPassengerNo]
    rw [foldl_addPassenger qs]
    simp only [recsFrom, advP, List.append_assoc, List.singleton_append, List.length_cons]
    rw [Nat.add_assoc, Nat.add_comm 1 qs.length]

/-- 予約フライト番号 `rfn`・搭乗者番号 `pn` から採番した予約フライトの記録（搭乗者の列 `ps`、予約番号 `no`）。 -/
def rfsFrom (ps : List Passenger) (no : ReserveNo) : Nat → Nat → List FlightKey → List ReserveFlight
  | _, _, [] => []
  | rfn, pn, k :: ks => ⟨rfn, no, k, recsFrom pn ps⟩ :: rfsFrom ps no (rfn + 1) (pn + ps.length) ks

/-- 予約フライト・搭乗者の採番を進める。 -/
def advRF (w : Spec.Port.World) (f p : Nat) : Spec.Port.World :=
  { w with sequences := { w.sequences with reserveFlight := w.sequences.reserveFlight + f,
                                            passenger := w.sequences.passenger + p } }

theorem foldl_addReserveFlight (ps : List Passenger) (no : ReserveNo) :
    ∀ (ks : List FlightKey) (pre : List ReserveFlight) (w : Spec.Port.World),
      ks.foldl (addReserveFlight ps no) (pre, w) =
        (pre ++ rfsFrom ps no w.sequences.reserveFlight w.sequences.passenger ks,
          advRF w ks.length (ks.length * ps.length))
  | [], pre, w => by simp [rfsFrom, advRF]
  | k :: ks, pre, w => by
    rw [List.foldl_cons]
    simp only [addReserveFlight, Spec.Port.World.nextReserveFlightNo, foldl_addPassenger, List.nil_append]
    rw [foldl_addReserveFlight ps no ks]
    simp only [rfsFrom, advRF, advP, List.append_assoc, List.singleton_append, List.length_cons]
    congr 3 <;> first | omega | (rw [Nat.succ_mul]; omega)

theorem recsFrom_take : ∀ (n : Nat) (qs : List Passenger) (j : Nat) (q : Passenger), qs[j]? = some q →
    recsFrom n (qs.take (j + 1)) = recsFrom n (qs.take j) ++ [⟨n + j, q⟩]
  | _, [], _, _, h => by simp at h
  | n, q' :: qs, 0, q, h => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h
    subst h
    simp [recsFrom]
  | n, q' :: qs, j + 1, q, h => by
    simp only [List.getElem?_cons_succ] at h
    simp only [List.take_succ_cons, recsFrom, recsFrom_take (n + 1) qs j q h, List.cons_append]
    rw [Nat.add_assoc, Nat.add_comm 1 j]

theorem recsFrom_length : ∀ (n : Nat) (qs : List Passenger), (recsFrom n qs).length = qs.length
  | _, [] => rfl
  | n, _ :: qs => by simp [recsFrom, recsFrom_length (n + 1) qs]

theorem mem_recsFrom : ∀ {n : Nat} {qs : List Passenger} {x : PassengerRecord}, x ∈ recsFrom n qs →
    n ≤ x.passengerNo ∧ x.passengerNo < n + qs.length
  | _, [], _, h => by simp [recsFrom] at h
  | n, q :: qs, x, h => by
    simp only [recsFrom, List.mem_cons] at h
    rcases h with rfl | h
    · simp
    · have := mem_recsFrom h
      simp only [List.length_cons]
      omega

end Abstraction.Reserve.RegSpec
