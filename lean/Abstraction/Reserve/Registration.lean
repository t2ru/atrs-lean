import Abstraction.Reserve.RegisterRun
import Abstraction.Reserve.Keys
import Abstraction.Reserve.FlightFacts

/-!
# Abstraction.Reserve.Registration

ABS-041 の補題: 予約の登録（`TicketReserveServiceImpl.registerReservation`）の三つ組（backlog aedf の第 3 段）。
空席の確保の列、予約・予約フライト・搭乗者の挿入、トランザクションの取消をつなぐ。

- 正常に終われば、空席の確保の [Spec] の値が `w1` で、状態の表の α は `w1` に新しい予約を足し、採番を進めたもの。
- 例外で終われば、障害で状態の表の α は `advance w a`（採番だけ進む）か、空席の確保の業務例外で状態の表の α は `w`。
-/

namespace Abstraction.Reserve.Registration
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.Insert Abstraction.Reserve.Register Abstraction.Reserve.Rollback
  Abstraction.Reserve.RegisterRun Abstraction.Reserve.Vacancy Abstraction.World.Alpha Abstraction.Reserve.Alpha
open Abstraction.Fare.TotalFareRun Abstraction.MasterData.Alpha
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.Domain.Repository.Reservation SourceModel.Domain.Service.B2
  SourceModel.Domain.Common.Exception SourceModel.App.B2

theorem lift_pure {α : Type} (a : α) : (lift (pure a) : DbM α) = pure a := rfl

theorem lift_ok {α : Type} (a : α) : (lift (.ok a) : DbM α) = pure a := rfl

theorem advance_zero (w : Spec.World) : Spec.Reserve.advance w {} = w := by
  simp [Spec.Reserve.advance]

theorem forall₂_get' {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β}
    (h : LangSemantics.Core.List.Forall₂ R xs ys) {j : Nat} {x : α} {y : β} (hx : xs[j]? = some x)
    (hy : ys[j]? = some y) : R x y := forall₂_get h hx hy

theorem secureAll_world {md : Spec.Env.MasterData} {T : Spec.Prim.Date} {n : Nat} :
    ∀ {ks : List Spec.Model.FlightKey} {w w1 : Spec.World}, secureAll md T n ks w = some (.ok w1) →
      w1.reservations = w.reservations ∧ w1.members = w.members ∧ w1.sequences = w.sequences ∧
      w1.flights.map (·.key) = w.flights.map (·.key)
  | [], w, w1, h => by simp only [secureAll, Option.some.injEq, Except.ok.injEq] at h; subst h; exact ⟨rfl, rfl, rfl, rfl⟩
  | k :: ks, w, w1, h => by
    simp only [secureAll] at h
    cases hs : Spec.Reserve.secureSeats md T n w k with
    | none => simp [hs] at h
    | some x =>
      rw [hs, Option.bind_some] at h
      cases x with
      | error e => simp at h
      | ok w' =>
        obtain ⟨h1, h2, h3, h4⟩ := secureAll_world h
        have hk := Spec.Reserve.secureSeats_keys hs
        have hq := secureSeats_seq hs
        have hr : w'.reservations = w.reservations ∧ w'.members = w.members := by
          unfold Spec.Reserve.secureSeats at hs
          simp only [Option.bind_eq_bind] at hs
          cases hft : md.fareTypeOf k.fareTypeCd with
          | none => simp [hft] at hs
          | some ft =>
            simp only [hft, Option.bind_some] at hs
            split at hs
            · simp at hs
            · split at hs
              · simp at hs
              · split at hs
                · simp at hs
                · simp only [Option.pure_def, Option.some.injEq, Except.ok.injEq] at hs
                  subst hs
                  exact ⟨rfl, rfl⟩
        exact ⟨h1.trans hr.1, h2.trans hr.2, h3.trans hq, h4.trans hk⟩

/-- 予約情報の搭乗者の列。 -/
def paxList (pfs : List SourceModel.App.B2.PassengerForm) : List (JRef SourceModel.Domain.Model.Passenger) :=
  pfs.map (some ∘ SourceModel.App.B2.B2Mapper.mapPassenger)

/-- 予約情報の予約フライト（選択フライト情報 `f` から作ったフライト情報と、搭乗者の列）。 -/
def rfOfForm (p : SourceModel.MasterQuery.Providers) (pfs : List SourceModel.App.B2.PassengerForm)
    (f : SourceModel.App.B0.SelectFlightForm) : JRef SourceModel.Domain.Model.ReserveFlight :=
  some ⟨none, none, some (mkFlight p f), some (paxList pfs)⟩

/-- 予約フライトの列（予約情報の）。 -/
def rfList (p : SourceModel.MasterQuery.Providers) (fs : List SourceModel.App.B0.SelectFlightForm)
    (pfs : List SourceModel.App.B2.PassengerForm) : List (JRef SourceModel.Domain.Model.ReserveFlight) :=
  fs.map (rfOfForm p pfs)

/-- 登録する予約の記録（予約番号は採番の次の値、予約フライトは採番の順）。 -/
def regRes (w : Spec.World) (RD : Spec.Prim.Date) (tfn : Nat) (fn gn : String) (an : Nat)
    (g : Spec.Model.Gender) (tel mail : String) (mn : Option Spec.Model.MembershipNumber)
    (qs : List Spec.Model.Passenger) (it : Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey) : Spec.Model.Reservation :=
  { reserveNo := Spec.World.reserveNoOf w.sequences.reserve, reserveDate := RD, totalFare := tfn,
    repFamilyName := fn, repGivenName := gn, repAge := an, repGender := g, repTel := tel, repMail := mail,
    repMembershipNumber := mn,
    reserveFlights := RegSpec.rfsIt qs w.sequences.reserveFlight w.sequences.passenger it }

/-- 予約を登録した後の `World`（空席の確保の後の `w1` に予約 `R` を足し、`w` の採番を進めたもの）。 -/
def regWorld (w w1 : Spec.World) (R : Spec.Model.Reservation) (nf np : Nat) : Spec.World :=
  { w1 with reservations := w1.reservations ++ [R],
            sequences := { w.sequences with reserve := w.sequences.reserve + 1,
                                             reserveFlight := w.sequences.reserveFlight + nf,
                                             passenger := w.sequences.passenger + np } }

/-- 予約の登録（骨組み）。 -/
theorem registerReservation_hoare {md : Spec.Env.MasterData} {p : SourceModel.MasterQuery.Providers}
    (hbq : ∀ cd : Spec.Model.BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hfq : ∀ cd : Spec.Model.FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    {env : Env} {w : Spec.World} {D0 : FlightDb} (hw0 : worldOfDb D0 = some w) (hinv : w.Inv)
    (svc : TicketReserveServiceImpl) {tJ : JLocalDate} {T : Spec.Prim.Date} (hclock : ∀ n, env.clock n = tJ)
    (hT : Abstraction.MasterData.AlphaLeaf.dateOfJ tJ = some T)
    {f0 : SourceModel.App.B0.SelectFlightForm} {fs : List SourceModel.App.B0.SelectFlightForm}
    {it : Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey} {ks : List Spec.Model.FlightKey} (hit : it.toList = ks)
    (hvc : LangSemantics.Core.List.Forall₂ (VacCond md p) (f0 :: fs) ks)
    (hex : ∀ k ∈ ks, (w.findForUpdate k).isSome)
    {pfs : List SourceModel.App.B2.PassengerForm} {qs : List Spec.Model.Passenger}
    (hpc : LangSemantics.Core.List.Forall₂ PassCond pfs qs) (hql : qs.length ≤ 6)
    (hk : KeysOk w)
    (hd9 : w.sequences.reserve ≤ 9999999999 ∧ w.sequences.reserveFlight + 1 ≤ 2147483647 ∧
      w.sequences.passenger + 11 ≤ 2147483647) (hkl : ks.length ≤ 2)
    (hpm : ∀ f ∈ pfs, ∀ s, f.membershipNumber = some s → s ≠ "" → ∃ x, w.findMember s = some x)
    (r : SourceModel.Domain.Model.Reservation) (hrfl : r.reserveFlightList = some (rfList p (f0 :: fs) pfs))
    {rJ : JLocalDate} {RD : Spec.Prim.Date} (hrd : r.reserveDate = some rJ)
    (hRD : Abstraction.MasterData.AlphaLeaf.dateOfJ rJ = some RD)
    {tf : J32} {tfn : Nat} (htf : r.totalFare = some tf) (htfv : tf.val = (tfn : Int)) (htfm : tfn ≤ 2147483647)
    {fn gn : String} (hfn : r.repFamilyName = some fn) (hfnl : fn.length ≤ 10) (hgn : r.repGivenName = some gn)
    (hgnl : gn.length ≤ 10) {age : J32} {an : Nat} (hage : r.repAge = some age) (hagev : age.val = (an : Int))
    (hanm : an ≤ 2147483647) {g : Spec.Model.Gender} (hg : r.repGender = some g) {tel : String}
    (htel : r.repTel = some tel) (htell : tel.length ≤ 13) {mail : String} (hmail : r.repMail = some mail)
    (hmaill : mail.length ≤ 256) {M0 : SourceModel.Domain.Model.Member} (hm : r.repMember = some M0)
    (hrm : ∀ s, M0.membershipNumber = some s → s ≠ "" → ∃ x, w.findMember s = some x) :
    Hoare (fun s => s.db = D0 ∧ s.env = env) (TicketReserveServiceImpl.registerReservation svc (some r))
      (fun dto s => s.env = env ∧ ∃ w1, secureAll md T qs.length ks w = some (.ok w1) ∧
        worldOfDb s.db = some (regWorld w w1 (regRes w RD tfn fn gn an g tel mail
          ((Spec.Reserve.memberNoOf M0.membershipNumber).bind Spec.Model.MembershipNumber.ofString?) qs it)
          ks.length (ks.length * qs.length)) ∧
        dto.reserveNo = some (Spec.World.reserveNoOf w.sequences.reserve).val ∧
        dto.paymentDate = (mkFlight p f0).departureDate)
      (fun e s => s.env = env ∧ ((IsFault env e ∧ ∃ a, worldOfDb s.db = some (Spec.Reserve.advance w a)) ∨
        (∃ be : Spec.Error.BusinessError, be.args = [] ∧ e = AtrsBusinessException.newArgs be.code [] ∧
          secureAll md T qs.length ks w = some (.error (.business be)) ∧ worldOfDb s.db = some w))) := by
  have hlenp : (pfs.map SourceModel.App.B2.B2Mapper.mapPassenger).length = qs.length := by
    rw [List.length_map]; exact Abstraction.Reserve.Validate.forall₂_length hpc
  have hlenq : (pfs.map SourceModel.App.B2.B2Mapper.mapPassenger).length ≤ 6 := hlenp ▸ hql
  refine transactional_hoare' (E := fun e s => s.env = env ∧ ((IsFault env e ∧ SeqGe w s.db) ∨
      (∃ be : Spec.Error.BusinessError, be.args = [] ∧ e = AtrsBusinessException.newArgs be.code [] ∧ secureAll md T qs.length ks w = some (.error (.business be)) ∧
        ∃ w', worldOfDb s.db = some w' ∧ w'.sequences = w.sequences))) fun s0 ⟨hd0, he0⟩ => ?_
  have hnev : LangSemantics.Java.Spring.Assert.notEmptyValue (some (rfList p (f0 :: fs) pfs))
      "reserveFlightList must not empty." = pure (rfList p (f0 :: fs) pfs) := rfl
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, lift_pure, pure_bind, hrfl, hnev]
  have hvac := vacancies_hoare hbq hfq (env := env) svc hlenq hclock hT hvc hinv hex
  have hrl : rfList p (f0 :: fs) pfs = (f0 :: fs).map fun f =>
      some { flight := some (mkFlight p f), passengerList := some ((pfs.map B2Mapper.mapPassenger).map some) } := by
    simp only [rfList, List.map_map]; rfl
  -- 取消の後の α
  refine Hoare.conseq (P := fun s => s = s0) (E := fun e s => s.env = env ∧ ((IsFault env e ∧ SeqGe w s.db) ∨
      (∃ be : Spec.Error.BusinessError, be.args = [] ∧ e = AtrsBusinessException.newArgs be.code [] ∧ secureAll md T qs.length ks w = some (.error (.business be)) ∧
        ∃ w', worldOfDb s.db = some w' ∧ w'.sequences = w.sequences))) ?_ (fun _ h => h) (fun _ _ h => h)
    (fun e s h => ⟨h, fun db' hdb' => ⟨h.1, ?_⟩⟩)
  · rw [hrl]
    refine Hoare.bind' (Hoare.conseq hvac (fun s h => ?_) (fun _ _ h => h) (fun e s h => ?_)) fun _ => ?_
    · subst h; exact ⟨hd0 ▸ hw0, he0⟩
    · obtain ⟨w', ⟨hw', hse⟩, hseq, he⟩ := h
      refine ⟨hse, ?_⟩
      rcases he with he | ⟨be, hba, hc, hsa⟩
      · refine .inl ⟨he, {}, ?_⟩
        rw [advance_zero, ← hseq]; exact (worldOfDb_eq_some.mp hw').2.2.2
      · exact .inr ⟨be, hba, hc, by rw [← hlenp]; exact hsa, w', hw', hseq⟩
    · intro s ⟨w1, hw1, hdb1, hse1⟩
      obtain ⟨hr1, hm1, hq1, hk1⟩ := secureAll_world hw1
      have hk1' : KeysOk w1 := by unfold KeysOk at hk ⊢; rw [hr1, hm1, hq1]; exact hk
      obtain ⟨-, -, -, hsq1⟩ := worldOfDb_eq_some.mp hdb1
      obtain ⟨hsm, hsr, hsf, hsp⟩ := sequencesOf_eq.mp hsq1
      rw [hq1] at hsm hsr hsf hsp
      obtain ⟨hres, hrfo, hpo⟩ := Abstraction.Reserve.Keys.rows_lt hdb1 hk1'
      rw [hq1] at hrfo hpo
      have hpk0 : ∀ x ∈ s.db.reservation, x.reserveNo.val ≠ (Spec.World.reserveNoOf w.sequences.reserve).val := by
        intro x hx e
        obtain ⟨m, hm', hxm⟩ := hres x hx
        rw [hq1] at hm'
        have : (Spec.World.reserveNoOf m).val = (Spec.World.reserveNoOf w.sequences.reserve).val := by
          rw [← hxm]; exact e
        have := Abstraction.Reserve.Keys.reserveNoOf_inj this
        omega
      have hmem0 : ∀ str, M0.membershipNumber = some str → str ≠ "" →
          str.length ≤ 10 ∧ s.db.member.any (·.customerNo.val == str) = true ∧
            Spec.Model.MembershipNumber.valid str = true := by
        intro str h1 h2
        obtain ⟨x, hx⟩ := hrm str h1 h2
        exact Abstraction.Reserve.FlightFacts.member_row hdb1 (by rw [Spec.World.findMember, hm1]; exact hx)
      have hins := insert_hoare (D := s.db) (env := env) hsr hd9.1 hrd hRD htf htfv htfm hfn hfnl hgn hgnl hage hagev
        hanm hg htel htell hmail hmaill hm hmem0 hpk0
      have hsg1 : SeqGe w s.db := ⟨{}, by rw [advance_zero, ← hq1]; exact hsq1⟩
      refine Hoare.bind' (Hoare.conseq hins (fun _ h => h) (fun _ _ h => h)
        (fun e s' ⟨hse', hf', hd'⟩ => ⟨hse', .inl ⟨hf', hd'.elim (fun h => h ▸ hsg1)
          (fun h => h ▸ seqGe_reserve hsg1 hsr)⟩⟩)) (fun res => ?_) s ⟨rfl, hse1⟩
      intro s2 ⟨hres1, hres2, hse2, row0, hdb2, hrno0, hro0⟩
      rw [hres1, hres2]
      simp only [show (J32.ofInt 1).val ≠ 1 ↔ False from by decide, decide_false, Bool.false_eq_true, ite_false]
      have hsg2 : SeqGe w s2.db := by
        rw [hdb2]; exact seqGe_tables (seqGe_reserve hsg1 hsr) rfl rfl rfl rfl
      have hlenL : ((f0 :: fs).map fun f =>
          some { flight := some (mkFlight p f), passengerList := some ((pfs.map B2Mapper.mapPassenger).map some) }
            : List (JRef SourceModel.Domain.Model.ReserveFlight)).length = ks.length := by
        rw [List.length_map]; exact Abstraction.Reserve.Validate.forall₂_length hvc
      refine Hoare.bind' (P := fun s => s = s2)
        (Hoare.conseq (flights_hoare (D := s2.db) (rfn := w.sequences.reserveFlight) (pn := w.sequences.passenger)
          (ps := qs) (rn := Spec.World.reserveNoOf w.sequences.reserve) hlenL ?_ ?_ ?_)
          (fun s' h => ?_) (fun _ _ h => h) (fun e s' h => ⟨h.1, .inl h.2⟩)) (fun _ => ?_) s2 rfl
      · intro j x k hx hk D' hsfD hspD hsgD hrfD hpD hflD hresD hmemD
        rw [List.getElem?_map] at hx
        obtain ⟨f, hf, rfl⟩ := Option.map_eq_some_iff.mp hx
        obtain ⟨hkf, ⟨BC, hb⟩, ⟨FT, hft⟩, ⟨fm, hfm, hfn⟩⟩ := forall₂_get hvc hf hk
        obtain ⟨dj, b, t, hdep, hdj, hbo, hbc, hto, htc⟩ :=
          Abstraction.Reserve.FlightFacts.mkFlight_codes hbq hfq hkf hb hft
        have hkm : k ∈ ks := List.mem_of_getElem? hk
        obtain ⟨fx, hfx⟩ := Option.isSome_iff_exists.mp (findForUpdate_isSome_of_keys hk1 (hex k hkm))
        obtain ⟨hrowf, hfnl⟩ := Abstraction.Reserve.FlightFacts.flight_row hdb1 hfx
        have hjk : j < ks.length := (List.getElem?_eq_some_iff.mp hk).1
        have hm : w.sequences.reserveFlight + j ≤ 2147483647 := by omega
        have hfk2 : ∃ r ∈ D'.flight, ∃ fx', flightOfRow r = some fx' ∧ fx'.key = k := by
          rw [hflD, hdb2]; exact hrowf
        have hfk1 : D'.reservation.any (·.reserveNo.val == (Spec.World.reserveNoOf w.sequences.reserve).val)
            = true := by
          rw [hresD, hdb2]
          simp [hrno0]
        have hnol : (Spec.World.reserveNoOf w.sequences.reserve).val.length ≤ 10 := by
          rw [← hrno0]; exact row0.reserveNo.property
        have hpkr : ∀ g ∈ D'.reserveFlight, g.reserveFlightNo.val ≠ ((w.sequences.reserveFlight + j : Nat) : Int) :=
          fun g hg => by have := hrfD g hg; omega
        have hirf := insertReserveFlight_hoare (D := D') (env := env) hsfD hm hdep hdj hfm hfn hfnl hbo hbc hto htc
          hnol hpkr hfk1 hfk2
          ⟨none, none, some (mkFlight p f), some ((pfs.map B2Mapper.mapPassenger).map some)⟩ rfl
        simp only [LangSemantics.Java.EStateSimp.deref_some, lift_ok, pure_bind]
        refine Hoare.bind' (Hoare.conseq hirf (fun _ h => h) (fun _ _ h => h)
          (fun e s' ⟨hse', hf', hd'⟩ => ⟨hse', hf', hd'.elim (fun h => h ▸ hsgD)
            (fun h => h ▸ seqGe_reserveFlight hsgD hsfD)⟩)) fun res => ?_
        intro s4 ⟨h1, h2, h3, hse4, row, hdb4, hro, hrno, hrfn⟩
        rw [h1, h2, h3]
        simp only [show (J32.ofInt 1).val ≠ 1 ↔ False from by decide, decide_false, Bool.false_eq_true, ite_false,
          LangSemantics.Java.EStateSimp.deref_some, lift_ok, pure_bind, List.map_map]
        have hsg4 : SeqGe w s4.db := by
          rw [hdb4]; exact seqGe_tables (seqGe_reserveFlight hsgD hsfD) rfl rfl rfl rfl
        have hsp4 : seqOf s4.db.sqPassenger = some (w.sequences.passenger + j * qs.length + 0) := by
          rw [hdb4]; exact hspD
        have hmo : (J32.ofInt ((w.sequences.reserveFlight + j : Nat) : Int)).val =
            ((w.sequences.reserveFlight + j : Nat) : Int) := LangSemantics.Java.IntLemmas.ofInt_nat hm
        have hlq : qs.length ≤ 6 := hql
        have hpmax : w.sequences.passenger + j * qs.length + qs.length ≤ 2147483648 := by
          have : j * qs.length ≤ 1 * 6 := Nat.mul_le_mul (by omega) hlq
          omega
        have hpold4 : ∀ p ∈ s4.db.passenger, p.passengerNo.val < ((w.sequences.passenger + j * qs.length : Nat) : Int) := by
          intro p' hp'
          have : s4.db.passenger = D'.passenger := by rw [hdb4]
          rw [this] at hp'
          exact hpD p' hp'
        simp only [Function.comp_def]
        refine Hoare.bind' (P := PassInv env w s4.db (w.sequences.passenger + j * qs.length)
            (w.sequences.reserveFlight + j) qs 0)
          (Hoare.conseq (passengers_hoare (D := s4.db) hpc ?_ hpmax hpold4) (fun _ h => h) (fun _ _ h => h)
            (fun _ _ h => h)) (fun _ => Hoare.pure' fun s5 h5 => ?_) s4 ?_
        · intro D'' n'' f' q' hf' hc' hsq'' hn'' hpk'' hm'' hrf''
          obtain ⟨⟨i, d, hi, hq, rfl⟩, hfnq, hgnq, hageq⟩ := hc'
          have hmem4 : D''.member = s.db.member := by
            rw [hm'', hdb4]; exact hmemD.trans (by rw [hdb2])
          have hmem : ∀ str, f'.membershipNumber = some str → str ≠ "" →
              str.length ≤ 10 ∧ D''.member.any (·.customerNo.val == str) = true ∧
                Spec.Model.MembershipNumber.valid str = true := by
            intro str h1' h2'
            obtain ⟨x, hx⟩ := hpm f' hf' str h1' h2'
            rw [hmem4]
            exact Abstraction.Reserve.FlightFacts.member_row hdb1 (by rw [Spec.World.findMember, hm1]; exact hx)
          have hfk : D''.reserveFlight.any (·.reserveFlightNo.val == ((w.sequences.reserveFlight + j : Nat) : Int))
              = true := by
            rw [hrf'', hdb4]
            simp [hrfn]
          simp only [LangSemantics.Java.EStateSimp.deref_some, lift_ok, pure_bind]
          refine Hoare.bind' (insertPassenger_hoare (D := D'') (env := env) hsq'' hn'' hi hq hfnq hgnq hageq hmem hmo hm
            hpk'' hfk) fun r' => ?_
          intro s6 ⟨hr1, hse6, row', hdb6, hpo6, hrf6⟩
          rw [hr1]
          simp only [show (J32.ofInt 1).val ≠ 1 ↔ False from by decide, decide_false, Bool.false_eq_true, ite_false]
          exact ⟨rfl, hse6, row', hdb6, hpo6, hrf6⟩
        · obtain ⟨hse5, hsg5, hsq5, rows, hdb5, hrows, hrf5⟩ := h5
          have hpl : pfs.length = qs.length := Abstraction.Reserve.Validate.forall₂_length hpc
          rw [hpl, List.take_length] at hrows
          rw [hpl] at hsq5
          refine ⟨rfl, hse5, hsg5, ?_, row, rows, ?_, hro, hrows, ?_, hrno, hrfn⟩
          · rw [hsq5, Nat.succ_mul]; congr 1; omega
          · rw [hdb5]
            conv => lhs; rw [hdb4]
          · intro p' hp'
            exact Subtype.ext ((hrf5 p' hp').trans hrfn.symm)
        · refine ⟨hse4, hsg4, hsp4, [], ?_, rfl, fun _ h => by cases h⟩
          conv => lhs; rw [hdb4]
          conv => rhs; rw [hdb4]
          simp
      · intro g hg
        have : s2.db.reserveFlight = s.db.reserveFlight := by rw [hdb2]
        rw [this] at hg
        exact hrfo g hg
      · intro p' hp'
        have : s2.db.passenger = s.db.passenger := by rw [hdb2]
        rw [this] at hp'
        exact hpo p' hp'
      · subst h
        refine ⟨hse2, hsg2, ?_, ?_, [], [], ?_, rfl, rfl, fun g hg => by cases hg⟩
        · rw [hdb2]; simpa using hsf
        · rw [hdb2]; simpa using hsp
        · conv => lhs; rw [hdb2]
          conv => rhs; rw [hdb2]
          simp
      · rw [hlenL]
        intro s3 ⟨hse3, _, hsf3, hsp3, nfs, nps, hdb3, hnfs, hnps, hg3⟩
        simp only [List.map_cons, LangSemantics.Java.JList.get_cons_zero, lift_ok, pure_bind,
          LangSemantics.Java.EStateSimp.deref_some, Option.bind_some]
        refine ⟨hse3, w1, hlenp ▸ hw1, ?_, rfl, rfl⟩
        -- 最終の状態の表の α
        have hreso : reservationsOf s.db.reservation s.db.reserveFlight s.db.passenger = some w1.reservations :=
          (worldOfDb_eq_some.mp hdb1).2.2.1
        have hrow : ∀ x ∈ s.db.reservation, x.reserveNo ≠ row0.reserveNo := by
          intro x hx e
          exact hpk0 x hx (by rw [e, hrno0])
        have hnfs' : ∀ g ∈ nfs, g.reserveNo = row0.reserveNo := by
          intro g hg
          exact Subtype.ext ((hg3 g hg).1.trans hrno0.symm)
        have hrf' : ∀ f ∈ s.db.reserveFlight, ∀ g ∈ nfs, f.reserveFlightNo ≠ g.reserveFlightNo := by
          intro f hf g hg e
          have h1 := hrfo f hf
          have h2 := (hg3 g hg).2.1
          rw [e] at h1
          omega
        have hfo : flightsOf nfs row0 = nfs := by
          rw [flightsOf, List.filter_eq_self]
          intro g hg
          simp [hnfs' g hg]
        have htk : ks.take ks.length = ks := List.take_length
        rw [htk] at hnfs
        have hR0 : resOf nfs nps row0 = some (regRes w RD tfn fn gn an g tel mail
            ((Spec.Reserve.memberNoOf M0.membershipNumber).bind Spec.Model.MembershipNumber.ofString?) qs it) := by
          simp only [resOf, hfo, hnfs, Option.bind_eq_bind, Option.bind_some, ← hit, ← RegSpec.legs_rfsIt,
            reserveFlightsOf_of_legs]
          rw [hro0]
          rfl
        have happ := reservationsOf_append hreso hrow hnfs' hrf' hnps hR0
        obtain ⟨hfl1, hme1, -, -⟩ := worldOfDb_eq_some.mp hdb1
        have e3 : s3.db.flight = s.db.flight ∧ s3.db.member = s.db.member ∧ s3.db.memberLogin = s.db.memberLogin ∧
            s3.db.reservation = s.db.reservation ++ [row0] ∧ s3.db.reserveFlight = s.db.reserveFlight ++ nfs ∧
            s3.db.passenger = s.db.passenger ++ nps ∧ s3.db.sqMember = s.db.sqMember ∧
            s3.db.sqReservation = some (w.sequences.reserve : Int) := by
          rw [hdb3, hdb2]; exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
        obtain ⟨e1, e2, e2', e4, e5, e6, e7, e8⟩ := e3
        refine worldOfDb_eq_some.mpr ⟨?_, ?_, ?_, ?_⟩
        · rw [e1]; exact hfl1
        · rw [e2, e2']; exact hme1
        · rw [e4, e5, e6]; exact happ
        · refine sequencesOf_eq.mpr ⟨?_, ?_, ?_, ?_⟩
          · rw [e7]; exact hsm
          · rw [e8]; exact seqOf_some_succ hsr
          · exact hsf3
          · exact hsp3
  · rcases h.2 with ⟨hf, a, ha⟩ | ⟨be, hba, hc, hsa, w', hw', hseq⟩
    · exact .inl ⟨hf, a, by rw [hdb', hd0]; exact worldOfDb_rollback hw0 ha⟩
    · refine .inr ⟨be, hba, hc, hsa, ?_⟩
      have hsq : sequencesOf s.db = some (Spec.Reserve.advance w {}).sequences := by
        rw [advance_zero, ← hseq]; exact (worldOfDb_eq_some.mp hw').2.2.2
      rw [hdb', hd0, worldOfDb_rollback hw0 hsq, advance_zero]

end Abstraction.Reserve.Registration
