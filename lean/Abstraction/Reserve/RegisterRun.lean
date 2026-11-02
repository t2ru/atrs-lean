import Abstraction.Reserve.Insert
import Abstraction.Reserve.Register
import Abstraction.Reserve.Rollback
import Abstraction.Reserve.Vacancy
import Abstraction.Reserve.RegSpec
import Abstraction.Reserve.Validate

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

/-! ## 搭乗者の列の挿入 -/

/-- 搭乗者 1 人の挿入の材料: 空でない欄の α が [Spec] の搭乗者 `q` で、氏名・年齢が列に収まる。 -/
structure PassCond (f : SourceModel.App.B2.PassengerForm) (q : Spec.Model.Passenger) : Prop where
  input : ∃ i, passengerInputOf f = some i ∧ i.toPassenger = some q
  fn : q.familyName.length ≤ 10
  gn : q.givenName.length ≤ 10
  age : q.age ≤ 999

theorem passengerOfRow_no {p : PassengerRow} {x : Spec.Model.PassengerRecord} (h : passengerOfRow p = some x) :
    p.passengerNo.val = (x.passengerNo : Int) := by
  simp only [passengerOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
  obtain ⟨no, hno, -, -, -, -, rfl⟩ := h
  exact Abstraction.MasterData.AlphaLeaf.natOfInt4_eq_some.mp hno

/-- 搭乗者の列の挿入の不変条件: `j` 人を挿入した。 -/
def PassInv (env : Env) (w : Spec.Port.World) (D : FlightDb) (n m : Nat) (qs : List Spec.Model.Passenger) (j : Nat)
    (s : St) : Prop :=
  s.env = env ∧ SeqGe w s.db ∧ seqOf s.db.sqPassenger = some (n + j) ∧ ∃ rows,
    s.db = { D with passenger := D.passenger ++ rows, sqPassenger := s.db.sqPassenger } ∧
    rows.mapM passengerOfRow = some (RegSpec.recsFrom n (qs.take j)) ∧ ∀ row ∈ rows, row.reserveFlightNo.val = (m : Int)

theorem forall₂_get {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List α} {ys : List β}, LangSemantics.Core.List.Forall₂ R xs ys → ∀ {j : Nat} {x : α} {y : β},
      xs[j]? = some x → ys[j]? = some y → R x y
  | [], [], .nil, _, _, _, h, _ => by simp at h
  | _ :: _, _ :: _, .cons hab _, 0, _, _, h1, h2 => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
    subst h1; subst h2; exact hab
  | _ :: _, _ :: _, .cons _ hr, j + 1, _, _, h1, h2 => by
    simp only [List.getElem?_cons_succ] at h1 h2
    exact forall₂_get hr h1 h2

/-- 搭乗者の列の挿入。本体 `body` は、1 人の挿入の三つ組を満たすとする（`insertPassenger_hoare` から示す）。 -/
theorem passengers_hoare {env : Env} {w : Spec.Port.World} {D : FlightDb} {n m : Nat}
    {body : JRef SourceModel.Domain.Model.Passenger → PUnit → DbM (ForInStep PUnit)}
    {fs : List SourceModel.App.B2.PassengerForm} {qs : List Spec.Model.Passenger}
    (hfq : LangSemantics.Core.List.Forall₂ PassCond fs qs)
    (hbody : ∀ (D' : FlightDb) (n' : Nat) (f : SourceModel.App.B2.PassengerForm) (q : Spec.Model.Passenger),
      PassCond f q → seqOf D'.sqPassenger = some n' → n' ≤ 2147483647 →
      (∀ p ∈ D'.passenger, p.passengerNo.val ≠ (n' : Int)) → D'.member = D.member →
      D'.reserveFlight = D.reserveFlight →
      Hoare (fun s => s.db = D' ∧ s.env = env) (body (some (SourceModel.App.B2.B2Mapper.mapPassenger f)) ())
        (fun r s => r = .yield () ∧ s.env = env ∧ ∃ row,
          s.db = { D' with passenger := D'.passenger ++ [row], sqPassenger := some (n' : Int) } ∧
          passengerOfRow row = some ⟨n', q⟩ ∧ row.reserveFlightNo.val = (m : Int))
        (fun e s => s.env = env ∧ IsFault env e ∧
          (s.db = D' ∨ s.db = { D' with sqPassenger := some (n' : Int) })))
    (hmax : n + qs.length ≤ 2147483648) (hold : ∀ p ∈ D.passenger, p.passengerNo.val < (n : Int)) :
    Hoare (PassInv env w D n m qs 0)
      (forIn (fs.map fun f => some (SourceModel.App.B2.B2Mapper.mapPassenger f)) () body)
      (fun _ s => PassInv env w D n m qs fs.length s)
      (fun e s => s.env = env ∧ IsFault env e ∧ SeqGe w s.db) := by
  have hlen : fs.length = qs.length := Abstraction.Reserve.Validate.forall₂_length hfq
  refine Hoare.conseq (Hoare.forIn_idx _ body (PassInv env w D n m qs)
    (E := fun e s => s.env = env ∧ IsFault env e ∧ SeqGe w s.db) fun j x hx => ?_) (fun _ h => h)
    (fun _ _ h => by simpa using h) (fun _ _ h => h)
  rw [List.getElem?_map] at hx
  obtain ⟨f, hf, rfl⟩ := Option.map_eq_some_iff.mp hx
  have hj : j < fs.length := (List.getElem?_eq_some_iff.mp hf).1
  obtain ⟨q, hq⟩ : ∃ q, qs[j]? = some q := ⟨qs[j]'(hlen ▸ hj), List.getElem?_eq_getElem _⟩
  have hc : PassCond f q := forall₂_get hfq hf hq
  intro s ⟨hse, hsg, hsq, rows, hdb, hrows, hrf⟩
  have hpass : s.db.passenger = D.passenger ++ rows := by rw [hdb]
  have hpk : ∀ p ∈ s.db.passenger, p.passengerNo.val ≠ ((n + j : Nat) : Int) := by
    intro p hp
    rw [hpass, List.mem_append] at hp
    rcases hp with hp | hp
    · have := hold p hp; omega
    · obtain ⟨r, hr, hpr⟩ := LangSemantics.Core.MapM.mapM_some_mem hrows hp
      have hb := RegSpec.mem_recsFrom hr
      have hl : (qs.take j).length ≤ j := List.length_take_le _ _
      rw [passengerOfRow_no hpr]
      omega
  have hjm : n + j ≤ 2147483647 := by
    have : j < qs.length := hlen ▸ hj
    omega
  have hmem : s.db.member = D.member := by rw [hdb]
  have hrfs : s.db.reserveFlight = D.reserveFlight := by rw [hdb]
  refine Hoare.conseq (hbody s.db (n + j) f q hc hsq hjm hpk hmem hrfs) (fun _ h => h)
    (fun r s' ⟨hr, hse', row, hdb', hro, hrfn⟩ => ⟨hr, hse', ?_, ?_, rows ++ [row], ?_, ?_, ?_⟩)
    (fun e s' ⟨hse', hf', hd'⟩ => ⟨hse', hf', ?_⟩) s ⟨rfl, hse⟩
  · rw [hdb']
    exact seqGe_tables (seqGe_passenger hsg hsq) rfl rfl rfl rfl
  · rw [hdb']
    exact seqOf_some_succ hsq
  · rw [hdb']
    conv => lhs; rw [hdb]
    simp
  · rw [List.mapM_append, hrows, RegSpec.recsFrom_take n qs j q hq]
    simp [hro]
  · intro r' hr'
    rw [List.mem_append, List.mem_singleton] at hr'
    rcases hr' with hr' | rfl
    · exact hrf r' hr'
    · exact hrfn
  · rcases hd' with hd' | hd'
    · rw [hd']; exact hsg
    · rw [hd']; exact seqGe_passenger hsg hsq

/-! ## 予約フライトの列の挿入 -/

/-- 新しい予約フライトの行 `g` の搭乗者の行は、`g` の番号を持つ新しい行だけ。 -/
theorem passengersOf_new {nps prows : List PassengerRow} {g : ReserveFlightRow}
    (hp : ∀ p ∈ prows, p.reserveFlightNo = g.reserveFlightNo)
    (hold : ∀ p ∈ nps, p.reserveFlightNo ≠ g.reserveFlightNo) : passengersOf (nps ++ prows) g = prows := by
  rw [passengersOf, List.filter_append]
  have h1 : nps.filter (fun p => p.reserveFlightNo == g.reserveFlightNo) = [] := by
    rw [List.filter_eq_nil_iff]
    intro p hp' e
    exact hold p hp' (beq_iff_eq.mp e)
  have h2 : prows.filter (fun p => p.reserveFlightNo == g.reserveFlightNo) = prows := by
    rw [List.filter_eq_self]
    intro p hp'
    simp [hp p hp']
  rw [h1, h2, List.nil_append]

/-- 既存の予約フライトの行の搭乗者の行は、新しい行を足しても変わらない。 -/
theorem passengersOf_old {nps prows : List PassengerRow} {g : ReserveFlightRow}
    (hp : ∀ p ∈ prows, p.reserveFlightNo ≠ g.reserveFlightNo) : passengersOf (nps ++ prows) g = passengersOf nps g := by
  rw [passengersOf, List.filter_append]
  have h2 : prows.filter (fun p => p.reserveFlightNo == g.reserveFlightNo) = [] := by
    rw [List.filter_eq_nil_iff]
    intro p hp' e
    exact hp p hp' (beq_iff_eq.mp e)
  rw [h2, List.append_nil]
  rfl

theorem mem_rfsFrom {ps : List Spec.Model.Passenger} {no : Spec.Model.ReserveNo} :
    ∀ {rfn pn : Nat} {ks : List Spec.Model.FlightKey} {rf : Spec.Model.ReserveFlight},
      rf ∈ RegSpec.rfsFrom ps no rfn pn ks → ∀ x ∈ rf.passengers, pn ≤ x.passengerNo ∧
        x.passengerNo < pn + ks.length * ps.length
  | _, _, [], _, h => by simp [RegSpec.rfsFrom] at h
  | rfn, pn, k :: ks, rf, h => by
    intro x hx
    simp only [RegSpec.rfsFrom, List.mem_cons] at h
    rcases h with rfl | h
    · have := RegSpec.mem_recsFrom hx
      simp only [List.length_cons, Nat.succ_mul]
      omega
    · have := mem_rfsFrom h x hx
      simp only [List.length_cons, Nat.succ_mul]
      omega

theorem rfOf_passengers {nps : List PassengerRow} {g : ReserveFlightRow} {rf : Spec.Model.ReserveFlight}
    (h : rfOf nps g = some rf) : (passengersOf nps g).mapM passengerOfRow = some rf.passengers := by
  simp only [rfOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at h
  obtain ⟨xs, hxs, hr⟩ := h
  simp only [reserveFlightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at hr
  obtain ⟨_, -, _, -, _, -, _, -, rfl⟩ := hr
  exact hxs

/-- 予約フライトの列の挿入の不変条件: `j` 便を挿入した。 -/
def FlightInv (env : Env) (w : Spec.Port.World) (D : FlightDb) (rfn pn : Nat) (ps : List Spec.Model.Passenger)
    (no : String) (ks : List Spec.Model.FlightKey) (j : Nat) (s : St) : Prop :=
  s.env = env ∧ SeqGe w s.db ∧ seqOf s.db.sqReserveFlight = some (rfn + j) ∧
    seqOf s.db.sqPassenger = some (pn + j * ps.length) ∧ ∃ nfs nps,
    s.db = { D with reserveFlight := D.reserveFlight ++ nfs, passenger := D.passenger ++ nps,
                    sqReserveFlight := s.db.sqReserveFlight, sqPassenger := s.db.sqPassenger } ∧
    nfs.mapM (rfOf nps) = some (RegSpec.rfsFrom ps ⟨no⟩ rfn pn (ks.take j)) ∧
    nps = nfs.flatMap (passengersOf nps) ∧
    ∀ g ∈ nfs, g.reserveNo.val = no ∧ (rfn : Int) ≤ g.reserveFlightNo.val ∧ g.reserveFlightNo.val < ((rfn + j : Nat) : Int)

/-- 予約フライトの列の挿入。本体 `body` は、1 便（予約フライトとその搭乗者の列）の挿入の三つ組を満たすとする。 -/
theorem flights_hoare {env : Env} {w : Spec.Port.World} {D : FlightDb} {rfn pn : Nat}
    {ps : List Spec.Model.Passenger} {no : String} {β : Type} {body : β → PUnit → DbM (ForInStep PUnit)}
    {xs : List β} {ks : List Spec.Model.FlightKey} (hlen : xs.length = ks.length)
    (hbody : ∀ (j : Nat) (x : β) (k : Spec.Model.FlightKey), xs[j]? = some x → ks[j]? = some k →
      ∀ (D' : FlightDb), seqOf D'.sqReserveFlight = some (rfn + j) →
        seqOf D'.sqPassenger = some (pn + j * ps.length) → SeqGe w D' →
        (∀ g ∈ D'.reserveFlight, g.reserveFlightNo.val < ((rfn + j : Nat) : Int)) →
        (∀ p ∈ D'.passenger, p.passengerNo.val < ((pn + j * ps.length : Nat) : Int)) →
        Hoare (fun s => s.db = D' ∧ s.env = env) (body x ())
          (fun r s => r = .yield () ∧ s.env = env ∧ SeqGe w s.db ∧
            seqOf s.db.sqPassenger = some (pn + (j + 1) * ps.length) ∧ ∃ row prows,
            s.db = { D' with reserveFlight := D'.reserveFlight ++ [row], passenger := D'.passenger ++ prows,
                             sqReserveFlight := some ((rfn + j : Nat) : Int), sqPassenger := s.db.sqPassenger } ∧
            reserveFlightOfRow row (RegSpec.recsFrom (pn + j * ps.length) ps) =
              some ⟨rfn + j, ⟨no⟩, k, RegSpec.recsFrom (pn + j * ps.length) ps⟩ ∧
            prows.mapM passengerOfRow = some (RegSpec.recsFrom (pn + j * ps.length) ps) ∧
            (∀ p ∈ prows, p.reserveFlightNo = row.reserveFlightNo) ∧ row.reserveNo.val = no ∧
            row.reserveFlightNo.val = ((rfn + j : Nat) : Int))
          (fun e s => s.env = env ∧ IsFault env e ∧ SeqGe w s.db))
    (hrfold : ∀ g ∈ D.reserveFlight, g.reserveFlightNo.val < (rfn : Int))
    (hpold : ∀ p ∈ D.passenger, p.passengerNo.val < (pn : Int)) :
    Hoare (FlightInv env w D rfn pn ps no ks 0) (forIn xs () body)
      (fun _ s => FlightInv env w D rfn pn ps no ks xs.length s)
      (fun e s => s.env = env ∧ IsFault env e ∧ SeqGe w s.db) := by
  refine Hoare.conseq (Hoare.forIn_idx _ body (FlightInv env w D rfn pn ps no ks)
    (E := fun e s => s.env = env ∧ IsFault env e ∧ SeqGe w s.db) fun j x hx => ?_) (fun _ h => h)
    (fun _ _ h => by simpa using h) (fun _ _ h => h)
  have hj : j < xs.length := (List.getElem?_eq_some_iff.mp hx).1
  obtain ⟨k, hk⟩ : ∃ k, ks[j]? = some k := ⟨ks[j]'(hlen ▸ hj), List.getElem?_eq_getElem _⟩
  intro s ⟨hse, hsg, hsf, hsp, nfs, nps, hdb, hnfs, hnps, hg⟩
  have hrf' : ∀ g ∈ s.db.reserveFlight, g.reserveFlightNo.val < ((rfn + j : Nat) : Int) := by
    intro g hgm
    rw [hdb] at hgm
    simp only [List.mem_append] at hgm
    rcases hgm with hgm | hgm
    · have := hrfold g hgm; omega
    · exact (hg g hgm).2.2
  have hp' : ∀ p ∈ s.db.passenger, p.passengerNo.val < ((pn + j * ps.length : Nat) : Int) := by
    intro p hpm
    rw [hdb] at hpm
    simp only [List.mem_append] at hpm
    rcases hpm with hpm | hpm
    · have := hpold p hpm; omega
    · have hpm' := hpm
      rw [hnps] at hpm'
      obtain ⟨g, hgm, hpg⟩ := List.mem_flatMap.mp hpm'
      obtain ⟨rf, hrf, hrfg⟩ := LangSemantics.Core.MapM.mapM_some_mem hnfs hgm
      obtain ⟨x, hx, hpx⟩ := LangSemantics.Core.MapM.mapM_some_mem (rfOf_passengers hrfg) hpg
      have hb := mem_rfsFrom hrf x hx
      have hl : (ks.take j).length ≤ j := List.length_take_le _ _
      have hmul : (ks.take j).length * ps.length ≤ j * ps.length := Nat.mul_le_mul_right _ hl
      rw [passengerOfRow_no hpx]
      omega
  refine Hoare.conseq (hbody j x k hx hk s.db hsf hsp hsg hrf' hp') (fun _ h => h)
    (fun r s' ⟨hr, hse', hsg', hsp', row, prows, hdb', hro, hpr, hprf, hrno, hrfn⟩ => ⟨hr, hse', hsg', ?_, hsp', ?_⟩)
    (fun _ _ h => h) s ⟨rfl, hse⟩
  · rw [hdb']; exact seqOf_some_succ hsf
  · -- 既存の予約フライトの行の番号は、新しい行の番号より小さい
    have hnew : ∀ p ∈ nps, p.reserveFlightNo ≠ row.reserveFlightNo := by
      intro p hpm e
      have hpm' := hpm
      rw [hnps] at hpm'
      obtain ⟨g, hgm, hpg⟩ := List.mem_flatMap.mp hpm'
      have hpg' : p.reserveFlightNo = g.reserveFlightNo := beq_iff_eq.mp (List.mem_filter.mp hpg).2
      have := (hg g hgm).2.2
      rw [← hpg', e, hrfn] at this
      omega
    have hold : ∀ g ∈ nfs, ∀ p ∈ prows, p.reserveFlightNo ≠ g.reserveFlightNo := by
      intro g hgm p hpm e
      have := (hg g hgm).2.2
      rw [← e, hprf p hpm, hrfn] at this
      omega
    refine ⟨nfs ++ [row], nps ++ prows, ?_, ?_, ?_, ?_⟩
    · rw [hdb']
      conv => lhs; rw [hdb]
      simp
    · rw [List.mapM_append, RegSpec.rfsFrom_take ps ⟨no⟩ rfn pn ks j k hk]
      have h1 : nfs.mapM (rfOf (nps ++ prows)) = nfs.mapM (rfOf nps) := by
        apply Abstraction.Reserve.Register.mapM_congr'
        intro g hgm
        simp only [rfOf, passengersOf_old (hold g hgm)]
      have h2 : rfOf (nps ++ prows) row = some ⟨rfn + j, ⟨no⟩, k, RegSpec.recsFrom (pn + j * ps.length) ps⟩ := by
        simp only [rfOf, passengersOf_new hprf hnew, hpr, Option.bind_eq_bind, Option.bind_some, hro]
      rw [h1, hnfs]
      simp [h2]
    · rw [List.flatMap_append, List.flatMap_singleton, passengersOf_new hprf hnew]
      congr 1
      conv => lhs; rw [hnps]
      apply Abstraction.World.Alpha.flatMap_congr'
      intro g hgm
      exact (passengersOf_old (hold g hgm)).symm
    · intro g hgm
      simp only [List.mem_append, List.mem_singleton] at hgm
      rcases hgm with hgm | rfl
      · obtain ⟨h1, h2, h3⟩ := hg g hgm
        exact ⟨h1, h2, by omega⟩
      · exact ⟨hrno, by rw [hrfn]; omega, by rw [hrfn]; omega⟩

end Abstraction.Reserve.RegisterRun
