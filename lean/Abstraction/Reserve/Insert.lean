import SourceModel.Domain.Repository.Reservation.ReservationRepository
import Abstraction.MasterData.AlphaLeaf
import Abstraction.Reserve.Alpha
import SourceModel.App.B2.B2Mapper
import Abstraction.FlightSearch.Alpha

/-!
# Abstraction.Reserve.Insert

ABS-041 の補題: 予約の登録の挿入の文の型変換（`VARCHAR(n)`・`INT`・`DATE`）が値域内で成功すること（backlog aedf の
第 3 段）。
-/

namespace Abstraction.Reserve.Insert
open LangSemantics.Sql.Postgresql LangSemantics.Sql.Core LangSemantics.Java LangSemantics.Java.Int
open SourceModel.Domain.Repository.Reservation.ReservationRepository Abstraction.MasterData.AlphaLeaf

theorem ofString_ok {col : String} {n : Nat} {v : String} (h : v.length ≤ n) :
    Varchar.ofString col n v = .ok ⟨v, h⟩ := by
  simp only [Varchar.ofString, varchar, h, ite_true, bind, Except.bind, dite_true, pure, Except.pure]

theorem convText_ok {col : String} {n : Nat} {v : String} (h : v.length ≤ n) :
    convText col n (some v) = .ok (some ⟨v, h⟩) := by
  simp only [convText, ofString_ok h]; rfl

theorem convInt_ok {v : J32} {m : Nat} (hv : v.val = (m : Int)) (hm : m ≤ 2147483647) :
    ∃ x : Int4, convInt (some v) = .ok (some x) ∧ x.val = (m : Int) := by
  have hr : (-2147483648 : Int) ≤ v.val ∧ v.val ≤ 2147483647 := by omega
  refine ⟨⟨v.val, hr⟩, ?_, hv⟩
  simp only [convInt, Int4.ofInt, hr]; rfl

theorem storeNullIf_none (col : String) (n : Nat) : storeNullIf col n (some "") = .ok none := rfl

theorem storeNullIf_some {col : String} {n : Nat} {v : String} (hne : v ≠ "") (h : v.length ≤ n) :
    storeNullIf col n (some v) = .ok (some ⟨v, h⟩) := by
  unfold storeNullIf
  split
  · rename_i h'
    simp only [Option.some.injEq] at h'
    exact absurd h' hne
  · rename_i h'
    cases h'
  · rename_i s' _ _ h'
    simp only [Option.some.injEq] at h'
    subst h'
    rw [ofString_ok h]
    rfl

theorem ordinal_le (X : Spec.Prim.Date) : X.ordinal ≤ 4000000 := by
  have h1 := Spec.Prim.Date.dayOfYear_lt X
  have h2 : Spec.Prim.Date.daysInYear X.year ≤ 366 := by unfold Spec.Prim.Date.daysInYear; split <;> omega
  have h3 := X.valid.2.1
  simp only [Spec.Prim.Date.ordinal, Spec.Prim.Date.daysBeforeYear]
  omega

/-- [Spec] の暦日の Java の日付は、`DATE` に格納でき、その α は元の暦日。 -/
theorem convDate_ok {tJ : JLocalDate} {T : Spec.Prim.Date} (hT : dateOfJ tJ = some T) :
    ∃ x : PgDate, convDate (some tJ) = .ok (some x) ∧ dateOfPg x = some T := by
  obtain ⟨-, he⟩ := dateOfJ_eq_some hT
  have hb : dateMin ≤ tJ.toEpochDay ∧ tJ.toEpochDay ≤ dateMax := by
    have := ordinal_le T
    rw [he]
    simp only [dateMin, dateMax, Spec.Prim.Date.epochDay, Spec.Prim.Date.epochOrdinal]
    omega
  refine ⟨⟨tJ.toEpochDay, hb⟩, ?_, ?_⟩
  · simp only [convDate, LangSemantics.Sql.Postgresql.date, hb]; rfl
  · unfold dateOfJ at hT
    split at hT
    · exact hT
    · cases hT

theorem gender_code (g : Spec.Model.Gender) :
    (SourceModel.Domain.Model.Gender.getCode g).length ≤ 1 ∧
      Spec.Model.Gender.ofCode? (SourceModel.Domain.Model.Gender.getCode g) = some g := by
  cases g <;> exact ⟨by decide, rfl⟩

/-- NULLIF の会員番号の列の値（空文字・`null` は無し）。会員番号は形式に合うので、列の値の α は、入力の会員番号を
読んだもの。 -/
theorem customerNo_ok {fd : SourceModel.Db.Schema.FlightDb} {col : String} {v : Exception.JRef String}
    (hmem : ∀ s, v = some s → s ≠ "" → s.length ≤ 10 ∧ fd.member.any (·.customerNo.val == s) = true ∧
      Spec.Model.MembershipNumber.valid s = true) :
    ∃ cn : Option (Varchar 10), storeNullIf col 10 v = .ok cn ∧
      Abstraction.World.Alpha.optMemberNo cn =
        some ((Spec.UseCase.Reserve.memberNoOf v).bind Spec.Model.MembershipNumber.ofString?) ∧
      ∀ c, cn = some c → fd.member.any (·.customerNo.val == c.val) = true := by
  cases hmn : v with
  | none => exact ⟨none, rfl, rfl, fun _ h => by cases h⟩
  | some s =>
    by_cases hv : s = ""
    · subst hv
      exact ⟨none, rfl, rfl, fun _ h => by cases h⟩
    · obtain ⟨hl, hfk', hval⟩ := hmem s hmn hv
      refine ⟨some ⟨s, hl⟩, storeNullIf_some hv hl, ?_, fun c hc => by cases hc; exact hfk'⟩
      obtain ⟨n, hn⟩ := Option.isSome_iff_exists.mp (Spec.Model.MembershipNumber.ofString?_isSome_iff.mpr hval)
      simp [Spec.UseCase.Reserve.memberNoOf, Abstraction.World.Alpha.optMemberNo, membershipNumberOf, hn, hv]

open Abstraction.World.Alpha Abstraction.Reserve.Alpha SourceModel.Db.Schema in
/-- 搭乗者の行の挿入: 空でない欄の搭乗者（`mapPassenger`）に搭乗者番号 `n`・予約フライト番号 `m` を書き込んで挿入すると、
行が末尾に足され、その α は [Spec] の搭乗者 `q` の記録。 -/
theorem insertPassengerRow_ok {fd : FlightDb} {f : SourceModel.App.B2.PassengerForm}
    {i : Spec.UseCase.Reserve.PassengerInput} {q : Spec.UseCase.Reserve.DraftPassenger} (hi : passengerInputOf f = some i)
    (hq : i.toPassenger = some q) (hfn : q.familyName.length ≤ 10) (hgn : q.givenName.length ≤ 10)
    (hage : q.age ≤ 999)
    (hmem : ∀ s, f.membershipNumber = some s → s ≠ "" → s.length ≤ 10 ∧ fd.member.any (·.customerNo.val == s) ∧
      Spec.Model.MembershipNumber.valid s = true)
    {no rfNo : J32} {n m : Nat} (hno : no.val = (n : Int)) (hrf : rfNo.val = (m : Int)) (hn : n ≤ 2147483647)
    (hm : m ≤ 2147483647) (hpk : ∀ p ∈ fd.passenger, p.passengerNo.val ≠ (n : Int))
    (hfk : fd.reserveFlight.any (·.reserveFlightNo.val == (m : Int))) :
    ∃ row, insertPassengerRow fd
        { SourceModel.App.B2.B2Mapper.mapPassenger f with passengerNo := some no, reserveFlightNo := some rfNo } =
        .ok (1, { fd with passenger := fd.passenger ++ [row] }) ∧
      passengerOfRow row = some ⟨n, q.toPassenger⟩ ∧ row.reserveFlightNo.val = (m : Int) := by
  simp only [passengerInputOf, Option.map_eq_some_iff] at hi
  obtain ⟨a, ha, rfl⟩ := hi
  simp only [Spec.UseCase.Reserve.PassengerInput.toPassenger, Option.bind_eq_bind, Option.bind_eq_some_iff,
    Option.pure_def, Option.some.injEq] at hq
  obtain ⟨fn, hfn0, gn, hgn0, ag, hag, g, hg0, rfl⟩ := hq
  subst hag
  simp only at hfn hgn hage
  obtain ⟨x, hx, hxa⟩ : ∃ x, f.age = some x ∧ natOfJ32 x = some ag := by
    cases hf : f.age with
    | none => rw [hf] at ha; cases ha
    | some x =>
      rw [hf] at ha
      simp only [optAgeOf, Option.map_eq_some_iff, Option.some.injEq] at ha
      obtain ⟨n', hn', rfl⟩ := ha
      exact ⟨x, rfl, hn'⟩
  rw [natOfJ32_eq_some] at hxa
  obtain ⟨pn, hpn, hpnv⟩ := convInt_ok hno hn
  obtain ⟨rn, hrn, hrnv⟩ := convInt_ok hrf hm
  obtain ⟨an, han, hanv⟩ := convInt_ok hxa (by omega)
  obtain ⟨hgl, hgc⟩ := gender_code g
  obtain ⟨cn, hcn, hcnm, hcnfk⟩ := customerNo_ok (col := "customer_no") hmem
  have hpk' : (fd.passenger.any fun r => r.passengerNo.val == (n : Int)) = false := by
    rw [Bool.eq_false_iff]
    intro h
    obtain ⟨p, hp, e⟩ := List.any_eq_true.mp h
    exact hpk p hp (beq_iff_eq.mp e)
  refine ⟨⟨pn, rn, ⟨fn, hfn⟩, ⟨gn, hgn⟩, an, ⟨SourceModel.Domain.Model.Gender.getCode g, hgl⟩, cn⟩, ?_, ?_, hrnv⟩
  · simp only [insertPassengerRow, SourceModel.App.B2.B2Mapper.mapPassenger, hpn, hrn, hfn0, hgn0, hx, han, hg0,
      convText_ok hfn, convText_ok hgn, Option.map_some, convText_ok hgl, Option.bind_some, hcn, notNull,
      LangSemantics.Sql.Query.insertUnique, hpnv, hrnv, hpk', hfk, Bind.bind, Except.bind, Pure.pure, Except.pure,
      Bool.false_eq_true, ite_false, Bool.not_true]
    cases cn with
    | none => rfl
    | some c => simp [hcnfk c rfl]
  · simp only [passengerOfRow, natOfInt4, hpnv, hanv, hgc, hcnm, Option.bind_eq_bind, Option.pure_def]
    simp [Spec.UseCase.Reserve.DraftPassenger.toPassenger]

open Abstraction.World.Alpha SourceModel.Db.Schema in
/-- 予約フライトの行の挿入: フライト情報の搭乗日・便名・搭乗クラス・運賃種別が主キー `k` のもので、予約番号 `no`・
予約フライト番号 `m` を書き込んで挿入すると、行が末尾に足され、その α は [Spec] の予約フライト。 -/
theorem insertReserveFlightRow_ok {fd : FlightDb} {fl : SourceModel.Domain.Model.Flight} {k : Spec.Model.FlightKey}
    {dj : JLocalDate} (hd : fl.departureDate = some dj) (hdj : dateOfJ dj = some k.departureDate)
    {fm : SourceModel.Domain.Model.FlightMaster} (hfm : fl.flightMaster = some fm)
    (hfn : fm.flightName = some k.flightName.val) (hfnl : k.flightName.val.length ≤ 6)
    {b : SourceModel.Domain.Model.BoardingClass} (hb : fl.boardingClass = some b)
    (hbc : b.boardingClassCd = some k.boardingClassCd) {t : SourceModel.Domain.Model.FareType}
    (ht : fl.fareType = some t) (htc : t.fareTypeCd = some k.fareTypeCd)
    {no : String} (hnol : no.length ≤ 10) {rfNoJ : J32} {m : Nat} (hm : rfNoJ.val = (m : Int))
    (hmax : m ≤ 2147483647) (hpk : ∀ g ∈ fd.reserveFlight, g.reserveFlightNo.val ≠ (m : Int))
    (hfk1 : fd.reservation.any (·.reserveNo.val == no) = true)
    (hfk2 : ∃ r ∈ fd.flight, ∃ fx, flightOfRow r = some fx ∧ fx.key = k)
    (rfObj : SourceModel.Domain.Model.ReserveFlight) (hrf : rfObj.flight = some fl) :
    ∃ row, insertReserveFlightRow fd { rfObj with reserveNo := some no, reserveFlightNo := some rfNoJ } =
        .ok (1, { fd with reserveFlight := fd.reserveFlight ++ [row] }) ∧
      reserveFlightOfRow row = some ⟨m, k⟩ ∧ row.reserveNo.val = no ∧
      row.reserveFlightNo.val = (m : Int) := by
  obtain ⟨rn, hrn, hrnv⟩ := convInt_ok hm hmax
  obtain ⟨dx, hdx, hdxv⟩ := convDate_ok hdj
  have hbl : (SourceModel.Domain.Model.BoardingClassCd.name k.boardingClassCd).length ≤ 1 := by
    cases k.boardingClassCd <;> decide
  have hfl : (SourceModel.Domain.Model.FareTypeCd.name k.fareTypeCd).length ≤ 4 := by
    cases k.fareTypeCd <;> decide
  have hpk' : (fd.reserveFlight.any fun r => r.reserveFlightNo.val == (m : Int)) = false := by
    rw [Bool.eq_false_iff]
    intro h
    obtain ⟨g, hg, e⟩ := List.any_eq_true.mp h
    exact hpk g hg (beq_iff_eq.mp e)
  obtain ⟨r, hr, fx, hfx, hfxk⟩ := hfk2
  have hdxe : dx.val = k.departureDate.epochDay := by
    have := Spec.Prim.Date.epochDay_ofEpochDay? hdxv
    exact this.symm
  have hfk2' : (fd.flight.any fun x => x.departureDate.val == dx.val && x.flightName.val == k.flightName.val &&
      x.boardingClassCd.val == SourceModel.Domain.Model.BoardingClassCd.name k.boardingClassCd &&
      x.fareTypeCd.val == SourceModel.Domain.Model.FareTypeCd.name k.fareTypeCd) = true := by
    apply List.any_eq_true.mpr
    refine ⟨r, hr, ?_⟩
    simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hfx
    obtain ⟨d, hd', n, hn', bc, hbc', ft, hft', v, -, rfl⟩ := hfx
    subst hfxk
    have := Spec.Prim.Date.epochDay_ofEpochDay? hd'
    simp only [Abstraction.FlightSearch.Alpha.boardingClassCdName_eq, Abstraction.FlightSearch.Alpha.fareTypeCdName_eq,
      bcCdOf_eq_some hbc', ftCdOf_eq_some hft', flightNameOf_eq_some hn', hdxe, this, beq_self_eq_true, Bool.and_self]
  refine ⟨⟨rn, ⟨no, hnol⟩, dx, ⟨k.flightName.val, hfnl⟩,
    ⟨SourceModel.Domain.Model.BoardingClassCd.name k.boardingClassCd, hbl⟩,
    ⟨SourceModel.Domain.Model.FareTypeCd.name k.fareTypeCd, hfl⟩⟩, ?_, ?_, rfl, hrnv⟩
  · simp only [insertReserveFlightRow, hrf, Option.bind_some, hd, hfm, hfn, hb, hbc, ht, htc, Option.map_some, hrn,
      convText_ok hnol, hdx, convText_ok hfnl, convText_ok hbl, convText_ok hfl, notNull,
      LangSemantics.Sql.Query.insertUnique, hrnv, hpk', hfk1, hfk2', Bind.bind, Except.bind, Pure.pure, Except.pure,
      Bool.false_eq_true, ite_false, Bool.not_true]
  · simp only [reserveFlightOfRow, natOfInt4, hrnv, hdxv, Abstraction.FlightSearch.Alpha.boardingClassCdName_eq,
      Abstraction.FlightSearch.Alpha.fareTypeCdName_eq, Option.bind_eq_bind, Option.pure_def]
    simp [bcCdOf, ftCdOf, Spec.Model.BoardingClassCd.ofCode?_toCode, Spec.Model.FareTypeCd.ofCode?_toCode]

open Abstraction.World.Alpha SourceModel.Db.Schema in
/-- 予約の行の挿入: 予約情報の各欄が値域内で、予約番号 `no` を書き込んで挿入すると、行が末尾に足され、その α は
[Spec] の予約の記録（予約フライト `fs`）。 -/
theorem insertRow_ok {fd : FlightDb} {r : SourceModel.Domain.Model.Reservation} {no : String} (hnol : no.length ≤ 10)
    {tJ : JLocalDate} {T : Spec.Prim.Date} (hrd : r.reserveDate = some tJ) (hT : dateOfJ tJ = some T)
    {tf : J32} {tfn : Nat} (htf : r.totalFare = some tf) (htfv : tf.val = (tfn : Int)) (htfm : tfn ≤ 2147483647)
    {fn gn : String} (hfn : r.repFamilyName = some fn) (hfnl : fn.length ≤ 10) (hgn : r.repGivenName = some gn)
    (hgnl : gn.length ≤ 10) {age : J32} {an : Nat} (hage : r.repAge = some age) (hagev : age.val = (an : Int))
    (hanm : an ≤ 2147483647) {g : Spec.Model.Gender} (hg : r.repGender = some g) {tel : String}
    (htel : r.repTel = some tel) (htell : tel.length ≤ 13) {mail : String} (hmail : r.repMail = some mail)
    (hmaill : mail.length ≤ 256) {M0 : SourceModel.Domain.Model.Member} (hm : r.repMember = some M0)
    (hmem : ∀ s, M0.membershipNumber = some s → s ≠ "" → s.length ≤ 10 ∧ fd.member.any (·.customerNo.val == s) = true ∧
      Spec.Model.MembershipNumber.valid s = true)
    (hpk : ∀ x ∈ fd.reservation, x.reserveNo.val ≠ no) {rn0 : Spec.Model.ReserveNo}
    (hrn0 : Spec.Model.ReserveNo.ofString? no = some rn0) :
    ∃ row, insertRow fd { r with reserveNo := some no } = .ok (1, { fd with reservation := fd.reservation ++ [row] }) ∧
      row.reserveNo.val = no ∧ ∀ fs, reservationOfRow row fs = some
        { reserveNo := rn0, reserveDate := T, totalFare := tfn, repFamilyName := fn, repGivenName := gn,
          repAge := an, repGender := g, repTel := tel, repMail := mail,
          repMembershipNumber := (Spec.UseCase.Reserve.memberNoOf M0.membershipNumber).bind
            Spec.Model.MembershipNumber.ofString?, reserveFlights := fs } := by
  obtain ⟨dx, hdx, hdxv⟩ := convDate_ok hT
  obtain ⟨tx, htx, htxv⟩ := convInt_ok htfv htfm
  obtain ⟨ax, hax, haxv⟩ := convInt_ok hagev hanm
  obtain ⟨hgl, hgc⟩ := gender_code g
  obtain ⟨cn, hcn, hcnm, hcnfk⟩ := customerNo_ok (col := "rep_customer_no") hmem
  have hpk' : (fd.reservation.any fun x => x.reserveNo.val == no) = false := by
    rw [Bool.eq_false_iff]
    intro h
    obtain ⟨x, hx, e⟩ := List.any_eq_true.mp h
    exact hpk x hx (beq_iff_eq.mp e)
  refine ⟨⟨⟨no, hnol⟩, dx, tx, ⟨fn, hfnl⟩, ⟨gn, hgnl⟩, ax, ⟨SourceModel.Domain.Model.Gender.getCode g, hgl⟩,
    ⟨tel, htell⟩, ⟨mail, hmaill⟩, cn⟩, ?_, rfl, fun fs => ?_⟩
  · simp only [insertRow, hrd, htf, hfn, hgn, hage, hg, htel, hmail, hm, Option.bind_some, Option.map_some,
      convText_ok hnol, hdx, htx, convText_ok hfnl, convText_ok hgnl, hax, convText_ok hgl, convText_ok htell,
      convText_ok hmaill, hcn, notNull, LangSemantics.Sql.Query.insertUnique, hpk', Bind.bind, Except.bind,
      Pure.pure, Except.pure, Bool.false_eq_true, ite_false]
    cases cn with
    | none => rfl
    | some c => simp [hcnfk c rfl]
  · simp only [reservationOfRow, hdxv, natOfInt4, htxv, haxv, hgc, hcnm, Option.bind_eq_bind, Option.pure_def]
    simp [hrn0]

end Abstraction.Reserve.Insert
