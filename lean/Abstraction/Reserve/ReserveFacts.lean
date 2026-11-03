import Abstraction.Reserve.Draft
import Abstraction.Reserve.RegisterRun
import Abstraction.Reserve.Registration
import Abstraction.Reserve.SpecFacts

/-!
# Abstraction.Reserve.ReserveFacts

ABS-041 の補題: 予約確定の前提の事実（backlog aedf の第 3 段）。[Spec] の予約内容の検証が成功すれば会員番号の会員が
あること、搭乗者欄を詰めても組み立てと原典の予約情報が変わらないこと、要求の長さの制約から原典の予約情報の欄の
長さと桁が分かること。[Spec] の予約確定の操作の値の分解（`reserveOp_cases`）と、登録の結果の形（`register_eq`）。
-/

namespace Abstraction.Reserve.ReserveFacts
open Abstraction.Reserve.Alpha Abstraction.Reserve.Draft Abstraction.Reserve.MemberCheck
  Abstraction.Reserve.RegisterRun
open Spec.Ticket Spec.Error Spec.Model
open SourceModel.App.B2
open Spec.UseCase.Reserve

theorem forall₂_mem_left {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List α} {ys : List β}, LangSemantics.Core.List.Forall₂ R xs ys → ∀ {x}, x ∈ xs → ∃ y ∈ ys, R x y
  | [], [], .nil, _, h => by simp at h
  | _ :: _, _ :: _, .cons hab hr, _, h => by
    rcases List.mem_cons.mp h with rfl | h
    · exact ⟨_, List.mem_cons_self, hab⟩
    · obtain ⟨y, hy, hr'⟩ := forall₂_mem_left hr h
      exact ⟨y, List.mem_cons_of_mem _ hy, hr'⟩

theorem foldlM_ok_all {ε α : Type} {f : Unit → α → Except ε Unit} :
    ∀ (l : List α), l.foldlM f () = .ok () → ∀ x ∈ l, f () x = .ok ()
  | [], _, x, hx => by simp at hx
  | y :: l, h, x, hx => by
    rw [List.foldlM_cons] at h
    cases hy : f () y with
    | error e => rw [hy] at h; cases h
    | ok u =>
      cases u
      rw [hy] at h
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hy
      · exact foldlM_ok_all l h x hx

/-- 予約内容の検証が成功すれば、代表者と搭乗者の会員番号の会員がある。 -/
theorem validate_members {cfg : Spec.Config} {md : Spec.MasterData} {w : Spec.Port.World} {d : Draft}
    (h : validateReservation cfg md w d = some (.ok ())) :
    (∀ n, d.repMembershipNumber = some n → (w.findMember n).isSome) ∧
      ∀ q ∈ d.passengers, ∀ n, q.membershipNumber = some n → (w.findMember n).isSome := by
  simp only [validateReservation, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h
  obtain ⟨ft, -, h⟩ := h
  cases h1 : checkRepAge cfg d with
  | error e => rw [h1] at h; cases h
  | ok u =>
  rw [h1] at h
  cases ft with
  | error e => cases h
  | ok u' =>
  cases h3 : checkRepMember w d with
  | error e => rw [h3] at h; cases h
  | ok u'' =>
  rw [h3] at h
  refine ⟨fun n hn => ?_, fun q hq n hn => ?_⟩
  · simp only [checkRepMember, hn] at h3
    cases hf : w.findMember n with
    | none => rw [hf] at h3; cases h3
    | some _ => rfl
  · have h4 : checkPassengerMembers w d.passengers = .ok () := h
    unfold checkPassengerMembers at h4
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hq
    have hz : (d.passengers[i], i) ∈ d.passengers.zipIdx := by
      rw [List.mem_iff_getElem?]
      exact ⟨i, by simp [hi]⟩
    have := foldlM_ok_all _ h4 _ hz
    simp only [hn] at this
    cases hf : w.findMember n with
    | none => rw [hf] at this; cases this
    | some _ => rfl

theorem memberNoOf_some {s : String} (h : s ≠ "") : memberNoOf (some s) = some ⟨s⟩ := by
  simp only [memberNoOf, Option.bind_some]
  rw [ite_eq_right_iff.mpr (fun h' => absurd (by simpa [String.isEmpty_iff] using h') h)]

theorem buildDraft_compact (ri : ReserveInput) (ks : List Spec.Model.FlightKey) :
    buildDraft { ri with passengers := compactPassengers ri.passengers } ks = buildDraft ri ks := by
  simp only [buildDraft, compact_filter]

theorem create_reset (form : TicketReserveForm) (fl : List (LangSemantics.Java.Exception.JRef SourceModel.Domain.Model.Flight)) :
    TicketReserveHelper.createReservation form.resetPassengersIndex fl = TicketReserveHelper.createReservation form fl := by
  have h := reset_filter form
  simp only [TicketReserveHelper.createReservation, B2Mapper.mapReservation] at h ⊢
  rw [h]
  rfl

/-- 空でない搭乗者欄の条件（`PassCond`）: 要求の長さと桁の制約から。 -/
theorem passConds : ∀ {fs : List PassengerForm} {ins : List PassengerInput} {ps : List Spec.Model.Passenger},
    fs.mapM passengerInputOf = some ins → ins.mapM PassengerInput.toPassenger = some ps →
    (∀ p ∈ ins, (∀ s ∈ p.familyName, s.length ≤ 10) ∧ (∀ s ∈ p.givenName, s.length ≤ 10) ∧ (∀ a ∈ p.age, a ≤ 999)) →
    LangSemantics.Core.List.Forall₂ PassCond fs ps
  | [], ins, ps, h1, h2, _ => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h1
    subst h1
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h2
    subst h2
    exact .nil
  | f :: fs, ins, ps, h1, h2, hb => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h1
    obtain ⟨i, hi, ins', hins, rfl⟩ := h1
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h2
    obtain ⟨p, hp, ps', hps, rfl⟩ := h2
    refine .cons ?_ (passConds hins hps fun q hq => hb q (List.mem_cons_of_mem _ hq))
    obtain ⟨b1, b2, b3⟩ := hb i List.mem_cons_self
    have hp' := hp
    simp only [PassengerInput.toPassenger, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hp'
    obtain ⟨fn, hfn, gn, hgn, ag, hag, g, hg, rfl⟩ := hp'
    exact ⟨⟨i, hi, hp⟩, b1 fn hfn, b2 gn hgn, b3 ag hag⟩

/-- [Spec] の `register` は、`Registration.regWorld`（採番の次の値から順に番号を振った予約を足し、採番を進めたもの）。 -/
theorem register_eq (d : Draft) (T : Spec.Prim.Date) (tfn : Nat) {w w1 : Spec.Port.World}
    (hseq : w1.sequences = w.sequences) :
    register d T tfn w1 = (Spec.Port.World.reserveNoOf w.sequences.reserve,
      Registration.regWorld w w1 (Registration.regRes w T tfn d.repFamilyName d.repGivenName d.repAge d.repGender d.repTel d.repMail
        d.repMembershipNumber d.passengers d.flights) d.flights.length (d.flights.length * d.passengers.length)) := by
  simp only [register, Spec.Port.World.nextReserveNo, RegSpec.foldl_addReserveFlight, List.nil_append,
    RegSpec.advRF, Spec.Port.World.insertReservation, Registration.regWorld, Registration.regRes, hseq]

/-- 予約確定の操作の値の分解。 -/
theorem reserveOp_cases {cfg : Spec.Config} {md : Spec.MasterData} {today : Spec.Prim.Date} {w : Spec.Port.World}
    {r : Request} {w' : Spec.Port.World} {x : Except AtrsError ReserveResult}
    (h : reserveOp cfg md today w r = some (w', x)) :
    ∃ v, Spec.Ticket.validateFlightList cfg md w (r.selects.map (Spec.Ticket.resolve md)) = some v ∧
      ((∃ e, v = .error e ∧ w' = w ∧ x = .error (asInvalidRequest e)) ∨
        (∃ it, v = .ok it ∧ ∃ d vr, buildDraft r.form it.toList = some d ∧
          validateReservation cfg md w d = some vr ∧
          ((∃ e, vr = .error e ∧ w' = w ∧ x = .error e) ∨
            (vr = .ok () ∧ ∃ n, Spec.Fare.totalFareOfKeys cfg md it.toList (d.passengers.map (·.age)) =
              some n ∧ ∃ sec, Abstraction.Reserve.Vacancy.secureAll md today d.passengers.length it.toList w = some sec ∧
              ((∃ e, sec = .error e ∧ w' = w ∧ x = .error e) ∨
                (∃ w1, sec = .ok w1 ∧ ∃ pd, it.toList.head?.map (·.departureDate) = some pd ∧
                  w' = (register d today n w1).2 ∧ x = .ok ⟨(register d today n w1).1, pd, n⟩)))))) := by
  unfold reserveOp checkSelects at h
  cases hv : Spec.Ticket.validateFlightList cfg md w (r.selects.map (Spec.Ticket.resolve md)) with
  | none => simp [hv] at h
  | some v =>
    refine ⟨v, rfl, ?_⟩
    simp only [hv, Option.map_some, Option.bind_eq_bind, Option.bind_some] at h
    cases v with
    | error e =>
      left
      simp only [Except.mapError, Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
      exact ⟨e, rfl, h.1.symm, h.2.symm⟩
    | ok it =>
      right
      refine ⟨it, rfl, ?_⟩
      simp only [Except.mapError, reserve, Option.bind_eq_bind] at h
      cases hd : buildDraft r.form it.toList with
      | none => simp [hd] at h
      | some d =>
        cases hvr : validateReservation cfg md w d with
        | none => simp [hd, hvr] at h
        | some vr =>
          refine ⟨d, vr, rfl, hvr, ?_⟩
          simp only [hd, hvr, Option.bind_some] at h
          cases vr with
          | error e =>
            left
            simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
            exact ⟨e, rfl, h.1.symm, h.2.symm⟩
          | ok u =>
            cases u
            right
            refine ⟨rfl, ?_⟩
            cases ht : Spec.Fare.totalFareOfKeys cfg md it.toList (d.passengers.map (·.age)) with
            | none => simp [ht] at h
            | some n =>
              refine ⟨n, rfl, ?_⟩
              simp only [ht, Option.bind_some] at h
              erw [Abstraction.Reserve.Vacancy.foldlM_secure] at h
              cases hs : Abstraction.Reserve.Vacancy.secureAll md today d.passengers.length it.toList w with
              | none => simp [hs] at h
              | some sec =>
                refine ⟨sec, rfl, ?_⟩
                simp only [hs, Option.bind_some] at h
                cases sec with
                | error e =>
                  left
                  simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
                  exact ⟨e, rfl, h.1.symm, h.2.symm⟩
                | ok w1 =>
                  right
                  refine ⟨w1, rfl, ?_⟩
                  cases hp : it.toList.head? with
                  | none => simp [hp] at h
                  | some k0 =>
                    simp only [hp, Option.map_some, Option.bind_some, Option.pure_def,
                      Option.some.injEq, Prod.mk.injEq] at h
                    exact ⟨k0.departureDate, rfl, h.1.symm, h.2.symm⟩

end Abstraction.Reserve.ReserveFacts
