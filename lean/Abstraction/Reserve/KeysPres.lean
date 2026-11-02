import Abstraction.Reserve.Registration

/-!
# Abstraction.Reserve.KeysPres

ABS-041 の補題: 予約確定の後も、具体側の不変条件（主キーの性質 `KeysOk`）が保たれる（backlog aedf の第 3 段）。採番を
進めるだけの変化（障害）と、予約の登録の両方。
-/

namespace Abstraction.Reserve.KeysPres
open Abstraction.World.Alpha Abstraction.Reserve.Registration Abstraction.Reserve.RegisterRun

theorem keysOk_advance {w : Spec.Port.World} (h : KeysOk w) (a : Spec.Nondet.SeqAdvance) :
    KeysOk (Spec.UseCase.Reserve.advance w a) := by
  obtain ⟨h1, h2⟩ := h
  refine ⟨h1, fun r hr => ?_⟩
  obtain ⟨⟨n, hn, hrn⟩, hf⟩ := h2 r hr
  refine ⟨⟨n, by simp only [Spec.UseCase.Reserve.advance]; omega, hrn⟩, fun f hf' => ?_⟩
  obtain ⟨a1, a2⟩ := hf f hf'
  exact ⟨by simp only [Spec.UseCase.Reserve.advance]; omega,
    fun p hp => by have := a2 p hp; simp only [Spec.UseCase.Reserve.advance]; omega⟩

theorem mem_rfsFrom_no {ps : List Spec.Model.Passenger} {no : Spec.Model.ReserveNo} :
    ∀ {rfn pn : Nat} {ks : List Spec.Model.FlightKey} {rf : Spec.Model.ReserveFlight},
      rf ∈ RegSpec.rfsFrom ps no rfn pn ks → rfn ≤ rf.reserveFlightNo ∧ rf.reserveFlightNo < rfn + ks.length
  | _, _, [], _, h => by simp [RegSpec.rfsFrom] at h
  | rfn, pn, k :: ks, rf, h => by
    simp only [RegSpec.rfsFrom, List.mem_cons] at h
    rcases h with rfl | h
    · simp
    · have := mem_rfsFrom_no h
      simp only [List.length_cons]
      omega

/-- 登録の後も、主キーの性質が保たれる。 -/
theorem keysOk_regWorld {w w1 : Spec.Port.World} (h : KeysOk w) (hr1 : w1.reservations = w.reservations)
    (hm1 : w1.members = w.members) (RD : Spec.Prim.Date) (tfn : Nat) (fn gn : String) (an : Nat)
    (g : Spec.Model.Gender) (tel mail : String) (mn : Option Spec.Model.MembershipNumber)
    (qs : List Spec.Model.Passenger) (ks : List Spec.Model.FlightKey) :
    KeysOk (regWorld w w1 (regRes w RD tfn fn gn an g tel mail mn qs ks) ks.length (ks.length * qs.length)) := by
  obtain ⟨h1, h2⟩ := h
  refine ⟨by simp only [regWorld, hm1]; exact h1, fun r hr => ?_⟩
  simp only [regWorld, hr1, List.mem_append, List.mem_singleton] at hr ⊢
  rcases hr with hr | rfl
  · obtain ⟨⟨n, hn, hrn⟩, hf⟩ := h2 r hr
    refine ⟨⟨n, by omega, hrn⟩, fun f hf' => ?_⟩
    obtain ⟨a1, a2⟩ := hf f hf'
    exact ⟨by omega, fun p hp => by have := a2 p hp; omega⟩
  · refine ⟨⟨w.sequences.reserve, by omega, rfl⟩, fun f hf' => ?_⟩
    have := mem_rfsFrom_no hf'
    exact ⟨by omega, fun p hp => by have := mem_rfsFrom hf' p hp; omega⟩

end Abstraction.Reserve.KeysPres
