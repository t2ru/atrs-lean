import Abstraction.World.Alpha
import Spec.UseCase.Reserve

/-!
# Abstraction.Reserve.Rollback

ABS-041 の補題: トランザクションの取消（`FlightDb.rollback`）の後の α（backlog aedf の第 3 段）。取消は表を開始時に
戻し、シーケンスは終了時のまま（巻き戻らない）なので、α は開始時の `World` の採番を進めたもの（`advance`）。
-/

namespace Abstraction.Reserve.Rollback
open Abstraction.World.Alpha SourceModel.Db.Schema

/-- 状態の表のシーケンスが、`w` の採番を `a` だけ進めたもの。 -/
def SeqGe (w : Spec.Port.World) (fd : FlightDb) : Prop :=
  ∃ a : Spec.Nondet.SeqAdvance, sequencesOf fd = some (Spec.UseCase.Reserve.advance w a).sequences

theorem sequencesOf_rollback (start stop : FlightDb) : sequencesOf (FlightDb.rollback start stop) = sequencesOf stop := by
  rfl

/-- 取消の後の α は、開始時の `World` の採番を進めたもの。 -/
theorem worldOfDb_rollback {start stop : FlightDb} {w : Spec.Port.World} (hw : worldOfDb start = some w)
    {a : Spec.Nondet.SeqAdvance} (hs : sequencesOf stop = some (Spec.UseCase.Reserve.advance w a).sequences) :
    worldOfDb (FlightDb.rollback start stop) = some (Spec.UseCase.Reserve.advance w a) := by
  obtain ⟨hf, hm, hr, -⟩ := worldOfDb_eq_some.mp hw
  exact worldOfDb_eq_some.mpr ⟨hf, hm, hr, (sequencesOf_rollback start stop).trans hs⟩

theorem seqGe_self {w : Spec.Port.World} {fd : FlightDb} (hw : worldOfDb fd = some w) : SeqGe w fd :=
  ⟨{}, by rw [(worldOfDb_eq_some.mp hw).2.2.2]; simp [Spec.UseCase.Reserve.advance]⟩

theorem sequencesOf_eq {fd : FlightDb} {q : Spec.Port.Sequences} :
    sequencesOf fd = some q ↔ seqOf fd.sqMember = some q.member ∧ seqOf fd.sqReservation = some q.reserve ∧
      seqOf fd.sqReserveFlight = some q.reserveFlight ∧ seqOf fd.sqPassenger = some q.passenger := by
  obtain ⟨qm, qr, qf, qp⟩ := q
  simp only [sequencesOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq,
    Spec.Port.Sequences.mk.injEq]
  constructor
  · rintro ⟨m, hm, r, hr, f, hf, p, hp, rfl, rfl, rfl, rfl⟩
    exact ⟨hm, hr, hf, hp⟩
  · rintro ⟨hm, hr, hf, hp⟩
    exact ⟨_, hm, _, hr, _, hf, _, hp, rfl, rfl, rfl, rfl⟩

theorem seqOf_some_succ {st : LangSemantics.Sql.Sequence.SequenceState} {n : Nat} (h : seqOf st = some n) :
    seqOf (some (n : Int)) = some (n + 1) := by
  cases st with
  | none => simp only [seqOf, Option.some.injEq] at h; subst h; rfl
  | some v =>
    simp only [seqOf] at h
    split at h
    · simp only [Option.some.injEq] at h; subst h; simp [seqOf]; omega
    · cases h

theorem seqGe_reserve {w : Spec.Port.World} {fd : FlightDb} (h : SeqGe w fd) {n : Nat}
    (hn : seqOf fd.sqReservation = some n) : SeqGe w { fd with sqReservation := some (n : Int) } := by
  obtain ⟨a, ha⟩ := h
  obtain ⟨h1, h2, h3, h4⟩ := sequencesOf_eq.mp ha
  rw [hn] at h2
  refine ⟨{ a with reserve := a.reserve + 1 }, sequencesOf_eq.mpr ⟨h1, ?_, h3, h4⟩⟩
  rw [seqOf_some_succ hn]
  simp only [Spec.UseCase.Reserve.advance, Option.some.injEq] at h2 ⊢
  omega

theorem seqGe_reserveFlight {w : Spec.Port.World} {fd : FlightDb} (h : SeqGe w fd) {n : Nat}
    (hn : seqOf fd.sqReserveFlight = some n) : SeqGe w { fd with sqReserveFlight := some (n : Int) } := by
  obtain ⟨a, ha⟩ := h
  obtain ⟨h1, h2, h3, h4⟩ := sequencesOf_eq.mp ha
  rw [hn] at h3
  refine ⟨{ a with reserveFlight := a.reserveFlight + 1 }, sequencesOf_eq.mpr ⟨h1, h2, ?_, h4⟩⟩
  rw [seqOf_some_succ hn]
  simp only [Spec.UseCase.Reserve.advance, Option.some.injEq] at h3 ⊢
  omega

theorem seqGe_passenger {w : Spec.Port.World} {fd : FlightDb} (h : SeqGe w fd) {n : Nat}
    (hn : seqOf fd.sqPassenger = some n) : SeqGe w { fd with sqPassenger := some (n : Int) } := by
  obtain ⟨a, ha⟩ := h
  obtain ⟨h1, h2, h3, h4⟩ := sequencesOf_eq.mp ha
  rw [hn] at h4
  refine ⟨{ a with passenger := a.passenger + 1 }, sequencesOf_eq.mpr ⟨h1, h2, h3, ?_⟩⟩
  rw [seqOf_some_succ hn]
  simp only [Spec.UseCase.Reserve.advance, Option.some.injEq] at h4 ⊢
  omega

/-- 表だけを替えても、シーケンスは変わらない。 -/
theorem seqGe_tables {w : Spec.Port.World} {fd fd' : FlightDb} (h : SeqGe w fd)
    (h1 : fd'.sqMember = fd.sqMember) (h2 : fd'.sqReservation = fd.sqReservation)
    (h3 : fd'.sqReserveFlight = fd.sqReserveFlight) (h4 : fd'.sqPassenger = fd.sqPassenger) : SeqGe w fd' := by
  obtain ⟨a, ha⟩ := h
  exact ⟨a, by simp only [sequencesOf, h1, h2, h3, h4]; exact ha⟩

end Abstraction.Reserve.Rollback
