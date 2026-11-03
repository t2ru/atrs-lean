import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import SourceModel.Db.Schema
import Spec.Port

/-!
# Abstraction.World.Alpha

状態の表とシーケンス（`FlightDb`）の標準の抽象化 α `worldOfDb` と、具体側の不変条件 `IcW`
（`docs/spec/abstraction.md#抽象化関数-α`）。空席照会（ABS-011）と予約（ABS-041）が、同じ状態の上で共有する
（`Machine.alt`。backlog aedf の第 3 段）。

- FLIGHT: 行ごとに [Spec] のフライトに写す（`flightOfRow`）。
- MEMBER・MEMBER_LOGIN: 同じ位置の行を組にして会員に写す（`memberOfRow`）。組の会員番号が違えば定義しない。
  会員番号は α の葉 `membershipNumberOf` で読む（予約の代表者・搭乗者の会員番号も同じ。形式に合わなければ定義しない）。
  ログイン日時（`TIMESTAMP`）は、0:00 のときだけ暦日に写す（`dateOfTimestamp`。シードは投入日の 0:00 とみなす）。
- RESERVATION・RESERVE_FLIGHT・PASSENGER: 予約の行ごとに、予約番号の同じ予約フライトの行を、予約フライトの行ごとに、
  予約フライト番号の同じ搭乗者の行を、表の順に集める（`reservationsOf`）。どの行も親の順に並んでいる
  （子の表が、親ごとの子の列をつないだものに等しい）ときに限って定義する。登録は親・子の順に表の末尾に足すので、
  [Source] の到達する状態はこの形である。予約フライトの行が 1 件なら片道、2 件なら往復（表の順に往路・復路）とし
  （`reserveFlightsOf`）、0 件・3 件以上の予約と、往復で往路・復路の搭乗者（番号を除く値の列）が違う予約には
  定義しない。
- シーケンス: 次に返す値（未使用なら 1、最後に返した値 `v ≥ 1` なら `v + 1`）。
- 写したフライトの主キー（出発日・便名・搭乗クラス・運賃種別）が重複する状態には定義しない（`World` は主キーの一意性を
  証明フィールドで持つ。ADR 6d36 の L3）。DDL の PK_FLIGHT が保つ性質で、[Source] の到達する状態は満たす。

どの α も部分写像で、[Spec] の型で表せない状態（負の数・未知のコード・暦日の外の日付など）には定義しない（既知差異
D-027）。`worldOfDb` は葉（定義域の上で単射なので、核は `undefOrEq`。ABS-048 の `worldOfDb_kernel`）で、会員・予約の
部分（複数の行を組にする写像）は、その内部の補助の定義である。
-/

namespace Abstraction.World.Alpha
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Spec.Model Machine.Kernel
open Machine.Preserves (KernelIs)

open LangSemantics.Sql.Postgresql SourceModel.Db.Schema Spec.Prim

/-! ## 補題 -/

/-- 2 つの写像の `mapM` の像が等しければ、元の列も等しい（左の要素は `Q`、右の要素は `R` を満たし、その対で像が
等しければ要素が等しく、性質 `P` を持つ）。 -/
theorem mapM_inj₂ {α β : Type} {f g : α → Option β} {P Q R : α → Prop}
    (h : ∀ x y b, Q x → R y → f x = some b → g y = some b → x = y ∧ P x) :
    ∀ {xs ys : List α} {bs : List β}, (∀ x ∈ xs, Q x) → (∀ y ∈ ys, R y) →
      xs.mapM f = some bs → ys.mapM g = some bs → xs = ys ∧ ∀ x ∈ xs, P x
  | [], [], _, _, _, _, _ => ⟨rfl, by simp⟩
  | [], _ :: _, bs, _, _, hx, hy => by
    simp only [List.mapM_nil, List.mapM_cons, Option.pure_def, Option.some.injEq, Option.bind_eq_bind,
      Option.bind_eq_some_iff] at hx hy
    obtain ⟨_, _, _, _, rfl⟩ := hy
    cases hx
  | _ :: _, [], bs, _, _, hx, hy => by
    simp only [List.mapM_nil, List.mapM_cons, Option.pure_def, Option.some.injEq, Option.bind_eq_bind,
      Option.bind_eq_some_iff] at hx hy
    obtain ⟨_, _, _, _, rfl⟩ := hx
    cases hy
  | x :: xs, y :: ys, bs, hQ, hR, hx, hy => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at hx hy
    obtain ⟨b, hb, bs', hbs, rfl⟩ := hx
    obtain ⟨b', hb', bs'', hbs', he⟩ := hy
    simp only [List.cons.injEq] at he
    obtain ⟨e1, e2⟩ := he
    rw [e1] at hb'
    rw [e2] at hbs'
    obtain ⟨rfl, hp⟩ := h x y b (hQ x (List.mem_cons_self ..)) (hR y (List.mem_cons_self ..)) hb hb'
    obtain ⟨rfl, hps⟩ := mapM_inj₂ h (fun z hz => hQ z (List.mem_cons_of_mem _ hz))
      (fun z hz => hR z (List.mem_cons_of_mem _ hz)) hbs hbs'
    exact ⟨rfl, by simp only [List.mem_cons, forall_eq_or_imp]; exact ⟨hp, hps⟩⟩

theorem flatMap_congr' {α β : Type} {f g : α → List β} :
    ∀ {l : List α}, (∀ x ∈ l, f x = g x) → l.flatMap f = l.flatMap g
  | [], _ => rfl
  | x :: l, h => by
    simp only [List.flatMap_cons, h x (List.mem_cons_self ..),
      flatMap_congr' fun y hy => h y (List.mem_cons_of_mem _ hy)]

theorem genderOf_inj {a b : String} {g : Gender} (ha : Gender.ofCode? a = some g) (hb : Gender.ofCode? b = some g) :
    a = b := by
  have e : ∀ {s : String} {g : Gender}, Gender.ofCode? s = some g → s = g.toCode := fun {s g} h => by
    unfold Gender.ofCode? at h
    split at h <;> cases h <;> rfl
  rw [e ha, e hb]

/-! ## FLIGHT -/

/-- FLIGHT の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def flightOfRow (r : FlightRow) : Option Flight := do
  let d ← dateOfPg r.departureDate
  let n ← flightNameOf r.flightName.val
  let bc ← bcCdOf r.boardingClassCd.val
  let ft ← ftCdOf r.fareTypeCd.val
  let v ← natOfInt4 r.vacantNum
  pure ⟨⟨d, n, bc, ft⟩, v⟩

@[obligation "ABS-048"]
theorem flightOfRow_kernel : KernelIs flightOfRow (undefOrEq flightOfRow) := by
  apply kernelIs_undefOrEq
  intro r r' a h h'
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨d, hd, n, hn, bc, hbc, ft, hft, v, hv, rfl⟩ := h
  obtain ⟨d', hd', n', hn', bc', hbc', ft', hft', v', hv', h⟩ := h'
  simp only [Flight.mk.injEq, FlightKey.mk.injEq] at h
  obtain ⟨⟨rfl, rfl, rfl, rfl⟩, rfl⟩ := h
  have h2 := (flightNameOf_eq_some hn').symm.trans (flightNameOf_eq_some hn)
  cases r; cases r'
  simp only [FlightRow.mk.injEq] at *
  exact ⟨inj_of_kernel dateOfPg_kernel hd hd', Subtype.ext h2.symm,
    Subtype.ext (inj_of_kernel bcCdOf_kernel hbc hbc'), Subtype.ext (inj_of_kernel ftCdOf_kernel hft hft'),
    Abstraction.MasterData.Alpha.natOfInt4_inj hv hv'⟩

/-! ## MEMBER・MEMBER_LOGIN -/

/-- `TIMESTAMP` の値: 0:00 のときだけ、その暦日。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def dateOfTimestamp (t : PgTimestamp) : Option Date :=
  if t.val % 86400000000 = 0 then Date.ofEpochDay? (t.val / 86400000000) else none

@[obligation "ABS-048"]
theorem dateOfTimestamp_kernel : KernelIs dateOfTimestamp (undefOrEq dateOfTimestamp) :=
  kernelIs_undefOrEq fun x y _ hx hy => by
    unfold dateOfTimestamp at hx hy
    split at hx
    · split at hy
      · have h1 := Date.epochDay_ofEpochDay? hx
        have h2 := Date.epochDay_ofEpochDay? hy
        apply Subtype.ext
        omega
      · cases hy
    · cases hx

/-- ログイン日時（`NULL` は無し）。 -/
def optDate : Option PgTimestamp → Option (Option Date)
  | none => some none
  | some t => (dateOfTimestamp t).map some

theorem optDate_inj {x y : Option PgTimestamp} {b : Option Date} (hx : optDate x = some b) (hy : optDate y = some b) :
    x = y := by
  cases x <;> cases y <;> simp only [optDate, Option.some.injEq, Option.map_eq_some_iff] at hx hy
  · rfl
  · obtain ⟨_, _, rfl⟩ := hy; cases hx
  · obtain ⟨_, _, rfl⟩ := hx; cases hy
  · obtain ⟨d, hd, rfl⟩ := hx
    obtain ⟨d', hd', he⟩ := hy
    cases he
    rw [inj_of_kernel dateOfTimestamp_kernel hd hd']

/-- 会員番号の列（`NULL` は無し。形式に合わない値には定義しない）。 -/
def optMemberNo : Option (Varchar 10) → Option (Option MembershipNumber)
  | none => some none
  | some c => (membershipNumberOf c.val).map some

theorem optMemberNo_inj {x y : Option (Varchar 10)} {b : Option MembershipNumber} (hx : optMemberNo x = some b)
    (hy : optMemberNo y = some b) : x = y := by
  cases x <;> cases y <;> simp only [optMemberNo, Option.some.injEq, Option.map_eq_some_iff] at hx hy
  · rfl
  · obtain ⟨_, _, rfl⟩ := hy; cases hx
  · obtain ⟨_, _, rfl⟩ := hx; cases hy
  · obtain ⟨n, hn, rfl⟩ := hx
    obtain ⟨n', hn', he⟩ := hy
    cases he
    exact congrArg some (Subtype.ext ((membershipNumberOf_eq_some hn).symm.trans (membershipNumberOf_eq_some hn')))

/-- MEMBER の行と MEMBER_LOGIN の行の組（会員番号が同じときに限る）。 -/
def memberOfRow (m : MemberRow) (l : MemberLoginRow) : Option Member :=
  if m.customerNo = l.customerNo then do
    let b ← dateOfPg m.birthday
    let g ← Gender.ofCode? m.gender.val
    let dt ← optDate l.loginDateTime
    let ct ← Abstraction.MasterData.AlphaLeaf.creditTypeCdOf m.creditTypeCd.val
    let mn ← membershipNumberOf m.customerNo.val
    pure { membershipNumber := mn, kanjiFamilyName := m.kanjiFamilyName.val,
           kanjiGivenName := m.kanjiGivenName.val, kanaFamilyName := m.kanaFamilyName.val,
           kanaGivenName := m.kanaGivenName.val, birthday := b, gender := g, tel := m.tel.val, zipCode := m.zipCode.val,
           address := m.address.val, mail := m.mail.val, creditNo := m.creditNo.val,
           creditTypeCd := ct, creditTerm := m.creditTerm.val,
           login := { password := ⟨l.password.val⟩, lastPassword := l.lastPassword.map fun p => ⟨p.val⟩,
                      loginDateTime := dt, loginFlg := l.loginFlg } }
  else none

theorem memberOfRow_inj {m m' : MemberRow} {l l' : MemberLoginRow} {x : Member}
    (h : memberOfRow m l = some x) (h' : memberOfRow m' l' = some x) : m = m' ∧ l = l' := by
  unfold memberOfRow at h h'
  split at h
  case isFalse => cases h
  split at h'
  case isFalse => cases h'
  rename_i hc hc'
  simp only [Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨b, hb, g, hg, dt, hdt, ct, hct, mn, hmn, rfl⟩ := h
  obtain ⟨b', hb', g', hg', dt', hdt', ct', hct', mn', hmn', h⟩ := h'
  simp only [Member.mk.injEq, MemberLogin.mk.injEq, PasswordHash.mk.injEq] at h
  obtain ⟨rfl, h2, h3, h4, h5, rfl, rfl, h8, h9, h10, h11, h12, rfl, h14, h15, h16, rfl, h18⟩ := h
  have h1 := (membershipNumberOf_eq_some hmn').symm.trans (membershipNumberOf_eq_some hmn)
  have h13 := (CreditTypeCd.val_of_ofString? hct').symm.trans (CreditTypeCd.val_of_ofString? hct)
  have hlp : l'.lastPassword = l.lastPassword := by
    cases e1 : l'.lastPassword <;> cases e2 : l.lastPassword <;> rw [e1, e2] at h16 <;> simp_all
    exact Subtype.ext h16
  obtain ⟨⟩ := m; obtain ⟨⟩ := m'; obtain ⟨⟩ := l; obtain ⟨⟩ := l'
  simp only [MemberRow.mk.injEq, MemberLoginRow.mk.injEq] at *
  subst hc hc'
  have e1 := Subtype.ext h1
  subst e1
  exact ⟨⟨rfl, Subtype.ext h2.symm, Subtype.ext h3.symm, Subtype.ext h4.symm, Subtype.ext h5.symm,
      inj_of_kernel dateOfPg_kernel hb hb', Subtype.ext (genderOf_inj hg hg'), Subtype.ext h8.symm,
      Subtype.ext h9.symm, Subtype.ext h10.symm, Subtype.ext h11.symm, Subtype.ext h12.symm,
      Subtype.ext h13.symm, Subtype.ext h14.symm⟩,
    ⟨rfl, Subtype.ext h15.symm, hlp.symm, optDate_inj hdt hdt', h18.symm⟩⟩

/-- MEMBER・MEMBER_LOGIN（同じ位置の行を組にする。行数が違えば定義しない）。 -/
def membersOf : List MemberRow → List MemberLoginRow → Option (List Member)
  | [], [] => some []
  | m :: ms, l :: ls => do
    let x ← memberOfRow m l
    let xs ← membersOf ms ls
    pure (x :: xs)
  | _, _ => none

theorem membersOf_inj {ms ms' : List MemberRow} {ls ls' : List MemberLoginRow} {xs : List Member}
    (h : membersOf ms ls = some xs) (h' : membersOf ms' ls' = some xs) : ms = ms' ∧ ls = ls' := by
  induction ms generalizing ls ms' ls' xs with
  | nil =>
    cases ls with
    | cons => simp [membersOf] at h
    | nil =>
      simp only [membersOf, Option.some.injEq] at h
      subst h
      cases ms' <;> cases ls' <;> simp_all [membersOf, Option.bind_eq_some_iff]
  | cons m ms ih =>
    cases ls with
    | nil => simp [membersOf] at h
    | cons l ls =>
      simp only [membersOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
      obtain ⟨x, hx, ys, hys, rfl⟩ := h
      cases ms' with
      | nil => cases ls' <;> simp [membersOf] at h'
      | cons m' ms' =>
        cases ls' with
        | nil => simp [membersOf] at h'
        | cons l' ls' =>
          simp only [membersOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
            Option.some.injEq, List.cons.injEq] at h'
          obtain ⟨x', hx', ys', hys', e1, e2⟩ := h'
          subst e1 e2
          obtain ⟨rfl, rfl⟩ := memberOfRow_inj hx hx'
          obtain ⟨rfl, rfl⟩ := ih hys hys'
          exact ⟨rfl, rfl⟩

/-! ## RESERVATION・RESERVE_FLIGHT・PASSENGER -/

/-- PASSENGER の行: 搭乗者番号と搭乗者（予約フライト番号は親の予約フライトで表す）。 -/
def passengerOfRow (p : PassengerRow) : Option (Nat × Passenger) := do
  let no ← natOfInt4 p.passengerNo
  let age ← natOfInt4 p.age
  let g ← Gender.ofCode? p.gender.val
  let mn ← optMemberNo p.customerNo
  pure (no, ⟨p.familyName.val, p.givenName.val, age, g, mn⟩)

/-- RESERVE_FLIGHT の行（予約番号は親の予約で表す）。 -/
def reserveFlightOfRow (r : ReserveFlightRow) : Option ReserveFlight := do
  let no ← natOfInt4 r.reserveFlightNo
  let d ← dateOfPg r.departureDate
  let n ← flightNameOf r.flightName.val
  let bc ← bcCdOf r.boardingClassCd.val
  let ft ← ftCdOf r.fareTypeCd.val
  pure ⟨no, ⟨d, n, bc, ft⟩⟩

/-- 予約の便と搭乗者: 予約フライト（とその搭乗者）が 1 件なら片道、2 件なら往復（往路、復路の順）。往復は、往路・復路
の搭乗者（搭乗者番号を除く）の列が等しいときに限る。0 件・3 件以上には定義しない。 -/
def reserveFlightsOf : List (ReserveFlight × List (Nat × Passenger)) → Option ReserveFlights
  | [(f, ps)] => some (.oneWayOf f ps)
  | [(o, ops), (h, hps)] => if ops.map (·.2) = hps.map (·.2) then some (.roundTripOf o h ops hps) else none
  | _ => none

theorem reserveFlightsOf_legs {l : List (ReserveFlight × List (Nat × Passenger))} {x : ReserveFlights}
    (h : reserveFlightsOf l = some x) : x.legs = l := by
  match l, h with
  | [(f, ps)], h => simp only [reserveFlightsOf, Option.some.injEq] at h; subst h; simp
  | [(o, ops), (hf, hps)], h =>
    simp only [reserveFlightsOf] at h
    split at h
    · rename_i he
      simp only [Option.some.injEq] at h
      subst h
      exact ReserveFlights.legs_roundTripOf o hf he
    · cases h

/-- 予約の便と搭乗者は、その便ごとの組の列から戻る。 -/
theorem reserveFlightsOf_of_legs (x : ReserveFlights) : reserveFlightsOf x.legs = some x := by
  cases x with
  | oneWay f ps =>
    simp only [ReserveFlights.legs, reserveFlightsOf, ReserveFlights.oneWayOf, List.map_map, Option.some.injEq]
    congr 1
    conv => rhs; rw [← List.map_id ps]
    rfl
  | roundTrip o h ps =>
    simp only [ReserveFlights.legs, reserveFlightsOf, List.map_map]
    have he : List.map ((fun x => x.snd) ∘ fun p : RoundTripPassenger => (p.outwardNo, p.passenger)) ps =
        List.map ((fun x => x.snd) ∘ fun p : RoundTripPassenger => (p.homewardNo, p.passenger)) ps := by
      simp [Function.comp_def]
    simp only [he, ite_true, ReserveFlights.roundTripOf, Option.some.injEq, List.zipWith_map, List.zipWith_self]
    congr 1
    conv => rhs; rw [← List.map_id ps]
    rfl

theorem reserveFlightsOf_inj {l l' : List (ReserveFlight × List (Nat × Passenger))} {x : ReserveFlights}
    (h : reserveFlightsOf l = some x) (h' : reserveFlightsOf l' = some x) : l = l' :=
  (reserveFlightsOf_legs h).symm.trans (reserveFlightsOf_legs h')

/-- RESERVATION の行と、その便と搭乗者。 -/
def reservationOfRow (r : ReservationRow) (fs : ReserveFlights) : Option Reservation := do
  let d ← dateOfPg r.reserveDate
  let tf ← natOfInt4 r.totalFare
  let age ← natOfInt4 r.repAge
  let g ← Gender.ofCode? r.repGender.val
  let rn ← Spec.Model.ReserveNo.ofString? r.reserveNo.val
  let mn ← optMemberNo r.repCustomerNo
  pure { reserveNo := rn, reserveDate := d, totalFare := tf, repFamilyName := r.repFamilyName.val,
         repGivenName := r.repGivenName.val, repAge := age, repGender := g, repTel := r.repTel.val,
         repMail := r.repMail.val, repMembershipNumber := mn, reserveFlights := fs }

/-- 予約フライトの行の搭乗者の行（予約フライト番号が同じ行を、表の順に）。 -/
def passengersOf (ps : List PassengerRow) (r : ReserveFlightRow) : List PassengerRow :=
  ps.filter fun p => p.reserveFlightNo == r.reserveFlightNo

/-- 予約の行の予約フライトの行（予約番号が同じ行を、表の順に）。 -/
def flightsOf (rfs : List ReserveFlightRow) (r : ReservationRow) : List ReserveFlightRow :=
  rfs.filter fun f => f.reserveNo == r.reserveNo

/-- 予約フライトの行（搭乗者を集めて写す）。 -/
def rfOf (ps : List PassengerRow) (r : ReserveFlightRow) : Option (ReserveFlight × List (Nat × Passenger)) := do
  let xs ← (passengersOf ps r).mapM passengerOfRow
  let f ← reserveFlightOfRow r
  pure (f, xs)

/-- 予約の行（予約フライトを集めて、片道・往復の形にして写す）。 -/
def resOf (rfs : List ReserveFlightRow) (ps : List PassengerRow) (r : ReservationRow) : Option Reservation := do
  let ls ← (flightsOf rfs r).mapM (rfOf ps)
  let fs ← reserveFlightsOf ls
  reservationOfRow r fs

/-- 予約の表（RESERVATION・RESERVE_FLIGHT・PASSENGER）。子の表が、親の順に親ごとの子の列をつないだものに等しいときに
限って定義する。 -/
def reservationsOf (rs : List ReservationRow) (rfs : List ReserveFlightRow) (ps : List PassengerRow) :
    Option (List Reservation) :=
  if rfs = rs.flatMap (flightsOf rfs) ∧ ps = rfs.flatMap (passengersOf ps) then rs.mapM (resOf rfs ps) else none

theorem passengerOfRow_inj {p q : PassengerRow} {x : Nat × Passenger} (hp : passengerOfRow p = some x)
    (hq : passengerOfRow q = some x) (hr : p.reserveFlightNo = q.reserveFlightNo) : p = q := by
  simp only [passengerOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hp hq
  obtain ⟨n, hn, a, ha, g, hg, mn, hmn, rfl⟩ := hp
  obtain ⟨n', hn', a', ha', g', hg', mn', hmn', h⟩ := hq
  simp only [Prod.mk.injEq, Passenger.mk.injEq] at h
  obtain ⟨rfl, h1, h2, rfl, rfl, rfl⟩ := h
  have hc : q.customerNo = p.customerNo := optMemberNo_inj hmn' hmn
  obtain ⟨⟩ := p; obtain ⟨⟩ := q
  simp only [PassengerRow.mk.injEq] at *
  exact ⟨natOfInt4_inj hn hn', hr, Subtype.ext h1.symm, Subtype.ext h2.symm, natOfInt4_inj ha ha',
    Subtype.ext (genderOf_inj hg hg'), hc.symm⟩

theorem reserveFlightOfRow_inj {r r' : ReserveFlightRow} {y : ReserveFlight}
    (h : reserveFlightOfRow r = some y) (h' : reserveFlightOfRow r' = some y) (hr : r.reserveNo = r'.reserveNo) :
    r = r' := by
  simp only [reserveFlightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h h'
  obtain ⟨n, hn, d, hd, fn, hfn, bc, hbc, ft, hft, rfl⟩ := h
  obtain ⟨n', hn', d', hd', fn', hfn', bc', hbc', ft', hft', h⟩ := h'
  simp only [ReserveFlight.mk.injEq, FlightKey.mk.injEq] at h
  obtain ⟨rfl, ⟨rfl, rfl, rfl, rfl⟩⟩ := h
  have h4 := (flightNameOf_eq_some hfn').symm.trans (flightNameOf_eq_some hfn)
  obtain ⟨⟩ := r; obtain ⟨⟩ := r'
  simp only [ReserveFlightRow.mk.injEq] at *
  exact ⟨natOfInt4_inj hn hn', hr, inj_of_kernel dateOfPg_kernel hd hd', Subtype.ext h4.symm,
    Subtype.ext (inj_of_kernel bcCdOf_kernel hbc hbc'), Subtype.ext (inj_of_kernel ftCdOf_kernel hft hft')⟩

theorem reservationOfRow_inj {r r' : ReservationRow} {fs fs' : ReserveFlights} {z : Reservation}
    (h : reservationOfRow r fs = some z) (h' : reservationOfRow r' fs' = some z) : r = r' ∧ fs = fs' := by
  simp only [reservationOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h h'
  obtain ⟨d, hd, tf, htf, a, ha, g, hg, rn, hrn, mn, hmn, rfl⟩ := h
  obtain ⟨d', hd', tf', htf', a', ha', g', hg', rn', hrn', mn', hmn', h⟩ := h'
  simp only [Reservation.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, h4, h5, rfl, rfl, h8, h9, rfl, rfl⟩ := h
  have h1 : r'.reserveNo.val = r.reserveNo.val :=
    (ReserveNo.val_of_ofString? hrn').symm.trans (ReserveNo.val_of_ofString? hrn)
  have hc : r'.repCustomerNo = r.repCustomerNo := optMemberNo_inj hmn' hmn
  obtain ⟨⟩ := r; obtain ⟨⟩ := r'
  simp only [ReservationRow.mk.injEq] at *
  exact ⟨⟨Subtype.ext h1.symm, inj_of_kernel dateOfPg_kernel hd hd', natOfInt4_inj htf htf', Subtype.ext h4.symm,
    Subtype.ext h5.symm, natOfInt4_inj ha ha', Subtype.ext (genderOf_inj hg hg'), Subtype.ext h8.symm,
    Subtype.ext h9.symm, hc.symm⟩, trivial⟩

theorem mem_passengersOf {ps : List PassengerRow} {r : ReserveFlightRow} {p : PassengerRow}
    (h : p ∈ passengersOf ps r) : p.reserveFlightNo = r.reserveFlightNo := by
  simp only [passengersOf, List.mem_filter, beq_iff_eq] at h
  exact h.2

theorem mem_flightsOf {rfs : List ReserveFlightRow} {r : ReservationRow} {g : ReserveFlightRow}
    (h : g ∈ flightsOf rfs r) : g.reserveNo = r.reserveNo := by
  simp only [flightsOf, List.mem_filter, beq_iff_eq] at h
  exact h.2

theorem rfOf_inj {ps ps' : List PassengerRow} {r r' : ReserveFlightRow} {y : ReserveFlight × List (Nat × Passenger)}
    (h : rfOf ps r = some y) (h' : rfOf ps' r' = some y) (hr : r.reserveNo = r'.reserveNo) :
    r = r' ∧ passengersOf ps r = passengersOf ps' r := by
  simp only [rfOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨xs, hxs, f, hf, rfl⟩ := h
  obtain ⟨xs', hxs', f', hf', h'⟩ := h'
  simp only [Prod.mk.injEq] at h'
  obtain ⟨rfl, rfl⟩ := h'
  obtain rfl := reserveFlightOfRow_inj hf hf' hr
  refine ⟨rfl, (mapM_inj₂ (P := fun _ => True) (Q := fun p => p ∈ passengersOf ps r)
    (R := fun p => p ∈ passengersOf ps' r) (fun x y b qx ry hx hy => ?_) (fun _ h => h) (fun _ h => h) hxs hxs').1⟩
  exact ⟨passengerOfRow_inj hx hy ((mem_passengersOf qx).trans (mem_passengersOf ry).symm), trivial⟩

theorem resOf_inj {rfs rfs' : List ReserveFlightRow} {ps ps' : List PassengerRow} {r r' : ReservationRow}
    {z : Reservation} (h : resOf rfs ps r = some z) (h' : resOf rfs' ps' r' = some z) :
    r = r' ∧ flightsOf rfs r = flightsOf rfs' r ∧ ∀ f ∈ flightsOf rfs r, passengersOf ps f = passengersOf ps' f := by
  simp only [resOf, Option.bind_eq_bind, Option.bind_eq_some_iff] at h h'
  obtain ⟨ls, hls, fs, hfs, h⟩ := h
  obtain ⟨ls', hls', fs', hfs', h'⟩ := h'
  obtain ⟨rfl, rfl⟩ := reservationOfRow_inj h h'
  obtain rfl := reserveFlightsOf_inj hfs hfs'
  obtain ⟨he, hp⟩ := mapM_inj₂ (Q := fun g => g ∈ flightsOf rfs r) (R := fun g => g ∈ flightsOf rfs' r)
    (P := fun f => passengersOf ps f = passengersOf ps' f)
    (fun x y b qx ry hx hy => by
      obtain ⟨rfl, h2⟩ := rfOf_inj hx hy ((mem_flightsOf qx).trans (mem_flightsOf ry).symm)
      exact ⟨rfl, h2⟩)
    (fun _ h => h) (fun _ h => h) hls hls'
  exact ⟨rfl, he, hp⟩

theorem reservationsOf_inj {rs rs' : List ReservationRow} {rfs rfs' : List ReserveFlightRow}
    {ps ps' : List PassengerRow} {zs : List Reservation}
    (h : reservationsOf rs rfs ps = some zs) (h' : reservationsOf rs' rfs' ps' = some zs) :
    rs = rs' ∧ rfs = rfs' ∧ ps = ps' := by
  unfold reservationsOf at h h'
  split at h
  case isFalse => cases h
  split at h'
  case isFalse => cases h'
  rename_i g g'
  obtain ⟨g1, g2⟩ := g
  obtain ⟨g1', g2'⟩ := g'
  obtain ⟨rfl, hP⟩ := mapM_inj₂ (Q := fun _ => True) (R := fun _ => True)
    (P := fun r => flightsOf rfs r = flightsOf rfs' r ∧ ∀ f ∈ flightsOf rfs r, passengersOf ps f = passengersOf ps' f)
    (fun x y b _ _ hx hy => by obtain ⟨rfl, h1, h2⟩ := resOf_inj hx hy; exact ⟨rfl, h1, h2⟩)
    (fun _ _ => trivial) (fun _ _ => trivial) h h'
  have hrf : rfs = rfs' :=
    calc rfs = _ := g1
      _ = _ := flatMap_congr' fun r hr => (hP r hr).1
      _ = rfs' := g1'.symm
  subst hrf
  refine ⟨rfl, rfl, ?_⟩
  calc ps = _ := g2
    _ = _ := flatMap_congr' fun f hf => by
      rw [g1] at hf
      obtain ⟨r, hr, hf⟩ := List.mem_flatMap.mp hf
      exact (hP r hr).2 f hf
    _ = ps' := g2'.symm

/-! ## シーケンス -/

/-- シーケンスの状態: 次に返す値（未使用なら 1、最後に返した値 `v ≥ 1` なら `v + 1`）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def seqOf : LangSemantics.Sql.Sequence.SequenceState → Option Nat
  | none => some 1
  | some v => if 1 ≤ v then some (v.toNat + 1) else none

theorem seqOf_inj {x y : LangSemantics.Sql.Sequence.SequenceState} {n : Nat} (hx : seqOf x = some n)
    (hy : seqOf y = some n) : x = y := by
  cases x <;> cases y <;> simp only [seqOf, Option.some.injEq] at hx hy
  · rfl
  · split at hy <;> simp at hy; omega
  · split at hx <;> simp at hx; omega
  · split at hx <;> split at hy <;> simp at hx hy
    congr 1
    omega

@[obligation "ABS-048"]
theorem seqOf_kernel : KernelIs seqOf (undefOrEq seqOf) := kernelIs_undefOrEq fun _ _ _ hx hy => seqOf_inj hx hy

/-- 4 つのシーケンスの状態。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def sequencesOf (fd : FlightDb) : Option Spec.Port.Sequences := do
  let m ← seqOf fd.sqMember
  let r ← seqOf fd.sqReservation
  let f ← seqOf fd.sqReserveFlight
  let p ← seqOf fd.sqPassenger
  pure ⟨m, r, f, p⟩

/-! ## 状態 -/

/-- 状態の表とシーケンス（状態）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def worldOfDb (fd : FlightDb) : Option Spec.Port.World := do
  let flights ← fd.flight.mapM flightOfRow
  let members ← membersOf fd.member fd.memberLogin
  let reservations ← reservationsOf fd.reservation fd.reserveFlight fd.passenger
  let sequences ← sequencesOf fd
  if h : (flights.map (·.key)).Nodup then pure { flights, flights_nodup := h, members, reservations, sequences }
  else none

theorem worldOfDb_eq_some {fd : FlightDb} {w : Spec.Port.World} :
    worldOfDb fd = some w ↔ fd.flight.mapM flightOfRow = some w.flights ∧
      membersOf fd.member fd.memberLogin = some w.members ∧
      reservationsOf fd.reservation fd.reserveFlight fd.passenger = some w.reservations ∧
      sequencesOf fd = some w.sequences := by
  constructor
  · intro h
    simp only [worldOfDb, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at h
    obtain ⟨fs, hfs, ms, hms, rs, hrs, sq, hsq, h⟩ := h
    split at h
    · cases h
      exact ⟨hfs, hms, hrs, hsq⟩
    · cases h
  · rintro ⟨hfs, hms, hrs, hsq⟩
    simp only [worldOfDb, hfs, hms, hrs, hsq, Option.bind_eq_bind, Option.bind_some, Option.pure_def,
      dite_eq_left_of_eq_true (eq_true w.flights_nodup)]

theorem worldOfDb_flights {fd : FlightDb} {w : Spec.Port.World} (h : worldOfDb fd = some w) :
    fd.flight.mapM flightOfRow = some w.flights := (worldOfDb_eq_some.mp h).1

@[obligation "ABS-048"]
theorem worldOfDb_kernel : KernelIs worldOfDb (undefOrEq worldOfDb) := by
  apply kernelIs_undefOrEq
  intro t t' w h h'
  obtain ⟨hf, hm, hr, hs⟩ := worldOfDb_eq_some.mp h
  obtain ⟨hf', hm', hr', hs'⟩ := worldOfDb_eq_some.mp h'
  have ef := mapM_inj (fun _ _ _ hx hy => inj_of_kernel flightOfRow_kernel hx hy) hf hf'
  obtain ⟨em, el⟩ := membersOf_inj hm hm'
  obtain ⟨er, erf, ep⟩ := reservationsOf_inj hr hr'
  simp only [sequencesOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at hs hs'
  obtain ⟨a, ha, b, hb, c, hc, d, hd, e⟩ := hs
  obtain ⟨a', ha', b', hb', c', hc', d', hd', e'⟩ := hs'
  rw [← e'] at e
  simp only [Option.some.injEq, Spec.Port.Sequences.mk.injEq] at e
  obtain ⟨rfl, rfl, rfl, rfl⟩ := e
  cases t; cases t'
  simp only [FlightDb.mk.injEq] at *
  exact ⟨ef, em, el, er, erf, ep, seqOf_inj ha ha', seqOf_inj hb hb', seqOf_inj hc hc', seqOf_inj hd hd'⟩

/-! ## 具体側の不変条件 -/

/-- 主キーの性質: 会員は会員番号で一意（PK_MEMBER）。使用済みの番号は採番の次の値より小さい（予約番号は次の予約番号より
小さい番号の書式、予約フライト番号・搭乗者番号は次の値より小さい）。 -/
def KeysOk (w : Spec.Port.World) : Prop :=
  (w.members.map (·.membershipNumber)).Nodup ∧ ∀ r ∈ w.reservations, (∃ n, n < w.sequences.reserve ∧ r.reserveNo = Spec.Port.World.reserveNoOf n) ∧
    ∀ f ∈ r.reserveFlights.legs, f.1.reserveFlightNo < w.sequences.reserveFlight ∧
      ∀ p ∈ f.2, p.1 < w.sequences.passenger

/-- 具体側の不変条件: α の像で、主キーの性質 `KeysOk` が成り立つ（主キーの一意性に使う。ADR ca17）。 -/
def IcW (fd : FlightDb) : Prop := ∀ w, worldOfDb fd = some w → KeysOk w

theorem reservations_nil {fd : FlightDb} {w : Spec.Port.World} (hr : fd.reservation = [])
    (h : worldOfDb fd = some w) : w.reservations = [] := by
  have h3 := (worldOfDb_eq_some.mp h).2.2.1
  rw [hr] at h3
  unfold reservationsOf at h3
  split at h3
  · simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h3
    exact h3.symm
  · cases h3

/-- 会員・予約の表が空なら、具体側の不変条件を満たす。 -/
theorem icW_of_nil {fd : FlightDb} (hm : fd.member = []) (hr : fd.reservation = []) : IcW fd := fun w h => by
  refine ⟨?_, fun r hr' => ?_⟩
  · have h2 := (worldOfDb_eq_some.mp h).2.1
    rw [hm] at h2
    cases e : fd.memberLogin <;> rw [e] at h2 <;> simp [membersOf] at h2
    rw [h2]
    exact List.nodup_nil
  · rw [reservations_nil hr h] at hr'
    cases hr'

end Abstraction.World.Alpha
