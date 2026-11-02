import Abstraction.Reserve.Insert
import Abstraction.Reserve.Register
import Abstraction.Reserve.Rollback
import Abstraction.Reserve.Vacancy

/-!
# Abstraction.Reserve.RegisterRun

ABS-041 の補題: 予約の登録（採番と挿入）の三つ組（backlog aedf の第 3 段）。

- 搭乗者・予約フライト・予約の 1 件の挿入（採番の文と挿入の文）。
- 例外で終われば、障害（`IsFault`）で、シーケンスは開始時から進んだだけ（`SeqGe`）。
-/

namespace Abstraction.Reserve.RegisterRun
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.Insert Abstraction.Reserve.Register Abstraction.Reserve.Rollback
  Abstraction.World.Alpha Abstraction.Reserve.Alpha
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.Domain.Repository.Reservation

theorem readInteger_ok {n : Nat} (hn : n ≤ 2147483647) :
    ReservationRepository.readInteger (n : Int) = .ok (J32.ofInt n) := by
  simp only [ReservationRepository.readInteger]
  split
  · rfl
  · omega

/-- 搭乗者 1 人の挿入（採番・挿入）。 -/
theorem insertPassenger_hoare {D : FlightDb} {env : Env} {n : Nat} (hseq : seqOf D.sqPassenger = some n)
    (hn : n ≤ 2147483647) {f : SourceModel.App.B2.PassengerForm} {i : Spec.UseCase.Reserve.PassengerInput}
    {q : Spec.Model.Passenger} (hi : passengerInputOf f = some i) (hq : i.toPassenger = some q)
    (hfn : q.familyName.length ≤ 10) (hgn : q.givenName.length ≤ 10) (hage : q.age ≤ 999)
    (hmem : ∀ s, f.membershipNumber = some s → s ≠ "" → s.length ≤ 10 ∧ D.member.any (·.customerNo.val == s) = true)
    {rfNoJ : J32} {m : Nat} (hrf : rfNoJ.val = (m : Int)) (hm : m ≤ 2147483647)
    (hpk : ∀ p ∈ D.passenger, p.passengerNo.val ≠ (n : Int))
    (hfk : D.reserveFlight.any (·.reserveFlightNo.val == (m : Int)) = true) :
    Hoare (fun s => s.db = D ∧ s.env = env)
      (ReservationRepository.insertPassenger
        { SourceModel.App.B2.B2Mapper.mapPassenger f with reserveFlightNo := some rfNoJ })
      (fun r s => r.1 = J32.ofInt 1 ∧ s.env = env ∧ ∃ row,
        s.db = { D with passenger := D.passenger ++ [row], sqPassenger := some (n : Int) } ∧
        passengerOfRow row = some ⟨n, q⟩ ∧ row.reserveFlightNo.val = (m : Int))
      (fun e s => s.env = env ∧ IsFault env e ∧ (s.db = D ∨ s.db = { D with sqPassenger := some (n : Int) })) := by
  intro s ⟨hdb, hse⟩
  obtain ⟨hnv, -⟩ := nextval_seq (d := sqPassenger) rfl rfl rfl hseq (by simp [sqPassenger]; omega)
  java_estate_simp [ReservationRepository.insertPassenger, sql, lift, ReservationRepository.nextPassengerNo, hdb]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h2 : s.env.conflictAt = some s.sqlCalls
  · simp only [h1, h2, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h2]⟩⟩, by simp⟩
  simp only [h1, h2, ite_false, hnv, Except.bind, EStateM.modifyGet, EStateM.bind, EStateM.pure, readInteger_ok hn]
  by_cases h3 : s.env.ioFailAt = some (s.sqlCalls + 1)
  · simp only [h3, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h4 : s.env.conflictAt = some (s.sqlCalls + 1)
  · simp only [h3, h4, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h4]⟩⟩, by simp⟩
  have hno : (J32.ofInt (n : Int)).val = (n : Int) := LangSemantics.Java.IntLemmas.ofInt_nat hn
  obtain ⟨row, hrow, hpo, hrfn⟩ := insertPassengerRow_ok (fd := { D with sqPassenger := some (n : Int) }) hi hq hfn hgn
    hage hmem hno hrf hn hm hpk hfk
  simp only [h3, h4, ite_false]
  rw [hrow]
  simp only [EStateM.modifyGet, EStateM.bind, EStateM.pure]
  exact ⟨rfl, hse, row, rfl, hpo, hrfn⟩

/-- 予約フライト 1 件の挿入（採番・挿入）。挿入した予約フライトは、採番した予約フライト番号を持つ。 -/
theorem insertReserveFlight_hoare {D : FlightDb} {env : Env} {m : Nat} (hseq : seqOf D.sqReserveFlight = some m)
    (hm : m ≤ 2147483647) {fl : SourceModel.Domain.Model.Flight} {k : Spec.Model.FlightKey}
    {dj : JLocalDate} (hd : fl.departureDate = some dj) (hdj : Abstraction.MasterData.AlphaLeaf.dateOfJ dj = some k.departureDate)
    {fm : SourceModel.Domain.Model.FlightMaster} (hfm : fl.flightMaster = some fm)
    (hfn : fm.flightName = some k.flightName.val) (hfnl : k.flightName.val.length ≤ 6)
    {b : SourceModel.Domain.Model.BoardingClass} (hb : fl.boardingClass = some b)
    (hbc : b.boardingClassCd = some k.boardingClassCd) {t : SourceModel.Domain.Model.FareType}
    (ht : fl.fareType = some t) (htc : t.fareTypeCd = some k.fareTypeCd)
    {no : String} (hnol : no.length ≤ 10) (hpk : ∀ g ∈ D.reserveFlight, g.reserveFlightNo.val ≠ (m : Int))
    (hfk1 : D.reservation.any (·.reserveNo.val == no) = true)
    (hfk2 : ∃ r ∈ D.flight, ∃ fx, flightOfRow r = some fx ∧ fx.key = k)
    (ps : List Spec.Model.PassengerRecord) (rfObj : SourceModel.Domain.Model.ReserveFlight)
    (hrf : rfObj.flight = some fl) :
    Hoare (fun s => s.db = D ∧ s.env = env)
      (ReservationRepository.insertReserveFlight { rfObj with reserveNo := some no })
      (fun r s => r.1 = J32.ofInt 1 ∧ r.2.reserveFlightNo = some (J32.ofInt m) ∧
        r.2.passengerList = rfObj.passengerList ∧ s.env = env ∧ ∃ row,
        s.db = { D with reserveFlight := D.reserveFlight ++ [row], sqReserveFlight := some (m : Int) } ∧
        reserveFlightOfRow row ps = some ⟨m, ⟨no⟩, k, ps⟩ ∧ row.reserveNo.val = no ∧
        row.reserveFlightNo.val = (m : Int))
      (fun e s => s.env = env ∧ IsFault env e ∧
        (s.db = D ∨ s.db = { D with sqReserveFlight := some (m : Int) })) := by
  intro s ⟨hdb, hse⟩
  obtain ⟨hnv, -⟩ := nextval_seq (d := sqReserveFlight) rfl rfl rfl hseq (by simp [sqReserveFlight]; omega)
  java_estate_simp [ReservationRepository.insertReserveFlight, sql, lift, ReservationRepository.nextReserveFlightNo,
    hdb]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h2 : s.env.conflictAt = some s.sqlCalls
  · simp only [h1, h2, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h2]⟩⟩, by simp⟩
  simp only [h1, h2, ite_false, hnv, Except.bind, EStateM.modifyGet, EStateM.bind, EStateM.pure, readInteger_ok hm]
  by_cases h3 : s.env.ioFailAt = some (s.sqlCalls + 1)
  · simp only [h3, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h4 : s.env.conflictAt = some (s.sqlCalls + 1)
  · simp only [h3, h4, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h4]⟩⟩, by simp⟩
  have hmo : (J32.ofInt (m : Int)).val = (m : Int) := LangSemantics.Java.IntLemmas.ofInt_nat hm
  obtain ⟨row, hrow, hro, hrno, hrfn⟩ := insertReserveFlightRow_ok (fd := { D with sqReserveFlight := some (m : Int) })
    hd hdj hfm hfn hfnl hb hbc ht htc hnol hmo hm hpk hfk1 hfk2 ps { rfObj with reserveNo := some no } hrf
  simp only [h3, h4, ite_false]
  rw [hrow]
  simp only [EStateM.modifyGet, EStateM.bind, EStateM.pure]
  exact ⟨rfl, trivial, trivial, hse, row, rfl, hro, hrno, hrfn⟩

/-- 予約 1 件の挿入（予約番号の採番・挿入）。予約番号は [Spec] の予約番号の書式。 -/
theorem insert_hoare {D : FlightDb} {env : Env} {n : Nat} (hseq : seqOf D.sqReservation = some n)
    (hn : n ≤ 9999999999) {r : SourceModel.Domain.Model.Reservation}
    {tJ : JLocalDate} {T : Spec.Prim.Date} (hrd : r.reserveDate = some tJ)
    (hT : Abstraction.MasterData.AlphaLeaf.dateOfJ tJ = some T)
    {tf : J32} {tfn : Nat} (htf : r.totalFare = some tf) (htfv : tf.val = (tfn : Int)) (htfm : tfn ≤ 2147483647)
    {fn gn : String} (hfn : r.repFamilyName = some fn) (hfnl : fn.length ≤ 10) (hgn : r.repGivenName = some gn)
    (hgnl : gn.length ≤ 10) {age : J32} {an : Nat} (hage : r.repAge = some age) (hagev : age.val = (an : Int))
    (hanm : an ≤ 2147483647) {g : Spec.Model.Gender} (hg : r.repGender = some g) {tel : String}
    (htel : r.repTel = some tel) (htell : tel.length ≤ 13) {mail : String} (hmail : r.repMail = some mail)
    (hmaill : mail.length ≤ 256) {M0 : SourceModel.Domain.Model.Member} (hm : r.repMember = some M0)
    (hmem : ∀ s, M0.membershipNumber = some s → s ≠ "" → s.length ≤ 10 ∧ D.member.any (·.customerNo.val == s) = true)
    (hpk : ∀ x ∈ D.reservation, x.reserveNo.val ≠ (Spec.Port.World.reserveNoOf n).val) :
    Hoare (fun s => s.db = D ∧ s.env = env) (ReservationRepository.insert r)
      (fun res s => res.1 = J32.ofInt 1 ∧ res.2 = { r with reserveNo := some (Spec.Port.World.reserveNoOf n).val } ∧
        s.env = env ∧ ∃ row,
        s.db = { D with reservation := D.reservation ++ [row], sqReservation := some (n : Int) } ∧
        row.reserveNo.val = (Spec.Port.World.reserveNoOf n).val ∧ ∀ fs, reservationOfRow row fs = some
          { reserveNo := Spec.Port.World.reserveNoOf n, reserveDate := T, totalFare := tfn, repFamilyName := fn,
            repGivenName := gn, repAge := an, repGender := g, repTel := tel, repMail := mail,
            repMembershipNumber := Spec.UseCase.Reserve.memberNoOf M0.membershipNumber, reserveFlights := fs })
      (fun e s => s.env = env ∧ IsFault env e ∧
        (s.db = D ∨ s.db = { D with sqReservation := some (n : Int) })) := by
  intro s ⟨hdb, hse⟩
  obtain ⟨hnv, -⟩ := nextval_seq (d := sqReservation) rfl rfl rfl hseq (by simp [sqReservation]; omega)
  have hnol : (Spec.Port.World.reserveNoOf n).val.length ≤ 10 := by
    have := toDigits_len hn
    simp only [Spec.Port.World.reserveNoOf, Spec.Prim.Format.padNat, String.length_append, String.length_ofList,
      List.length_replicate]
    have hl : (toString n).length = (Nat.toDigits 10 n).length := by simp [toString, Nat.repr, String.length]
    omega
  java_estate_simp [ReservationRepository.insert, sql, ReservationRepository.nextReserveNo, hdb]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h2 : s.env.conflictAt = some s.sqlCalls
  · simp only [h1, h2, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h2]⟩⟩, by simp⟩
  simp only [h1, h2, ite_false, hnv, Except.bind, EStateM.modifyGet, EStateM.bind, EStateM.pure,
    toChar_reserveNo hn, Option.getD_some]
  by_cases h3 : s.env.ioFailAt = some (s.sqlCalls + 1)
  · simp only [h3, ite_true]
    exact ⟨hse, ⟨_, .inl rfl⟩, by simp⟩
  by_cases h4 : s.env.conflictAt = some (s.sqlCalls + 1)
  · simp only [h3, h4, ite_true, ite_false]
    exact ⟨hse, ⟨_, .inr ⟨rfl, by rw [← hse]; simp [h4]⟩⟩, by simp⟩
  obtain ⟨row, hrow, hrno, hro⟩ := insertRow_ok (fd := { D with sqReservation := some (n : Int) }) hnol hrd hT htf
    htfv htfm hfn hfnl hgn hgnl hage hagev hanm hg htel htell hmail hmaill hm hmem hpk
  simp only [h3, h4, ite_false]
  rw [hrow]
  simp only [EStateM.modifyGet, EStateM.bind, EStateM.pure]
  exact ⟨rfl, trivial, hse, row, rfl, hrno, hro⟩

end Abstraction.Reserve.RegisterRun
