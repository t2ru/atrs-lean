import Abstraction.Reserve.Alpha
import Abstraction.Reserve.MemberCheck
import Abstraction.MasterData.Pre
import SourceModel.App.B2.TicketReserveHelper
import Abstraction.Fare.TotalAlpha

/-!
# Abstraction.Reserve.Draft

ABS-041 の補題: 予約情報の組み立て（`TicketReserveHelper.createReservation`）と、[Spec] の予約内容の組み立て
（`buildDraft`）の対応（backlog aedf の第 3 段）。

- 空の搭乗者欄の判定（`PassengerForm.isEmpty`・`PassengerInput.isEmpty`）は、α `passengerInputOf` の上で同じ。
- 搭乗者欄を詰める処理（`resetPassengersIndex`・`compactPassengers`）は、空でない欄の列を変えない。
- 空でない欄の搭乗者（`B2Mapper.mapPassenger`）は、[Spec] の搭乗者の会員番号・氏名・性別を持つ（`PassengerFacts`）。
-/

namespace Abstraction.Reserve.Draft
open Abstraction.Reserve.Alpha Abstraction.Reserve.MemberCheck Abstraction.MasterData.AlphaLeaf
open LangSemantics.Java LangSemantics.Java.Exception SourceModel.App.B2 Spec.Reserve

theorem hasText_eq (s : JRef String) : Spring.StringUtils.hasText s = s.any Spec.Prim.Text.hasText := by
  cases s with
  | none => rfl
  | some v =>
    simp only [Spring.StringUtils.hasText, Option.any_some, Spec.Prim.Text.hasText]
    have e : (fun c => !LangSemantics.Java.String.isJavaWhitespace c) = (fun c => !Spec.Prim.Text.isBlank c) :=
      funext fun c => by rw [Abstraction.MasterData.Pre.isBlank_eq_isJavaWhitespace]
    rw [e]

theorem isEmpty_eq {f : PassengerForm} {q : PassengerInput} (h : passengerInputOf f = some q) :
    f.isEmpty = q.isEmpty := by
  simp only [passengerInputOf, Option.map_eq_some_iff] at h
  obtain ⟨a, ha, rfl⟩ := h
  have hage : f.age.isNone = a.isNone := by
    cases hf : f.age with
    | none => rw [hf] at ha; cases ha; rfl
    | some x =>
      rw [hf] at ha
      simp only [optAgeOf, Option.map_eq_some_iff] at ha
      obtain ⟨n, -, rfl⟩ := ha
      rfl
  simp only [PassengerForm.isEmpty, PassengerInput.isEmpty, hasText_eq, hage]

theorem filter_mapM : ∀ {fs : List PassengerForm} {qs : List PassengerInput}, fs.mapM passengerInputOf = some qs →
    (fs.filter (!·.isEmpty)).mapM passengerInputOf = some (qs.filter (!·.isEmpty))
  | [], qs, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | f :: fs, qs, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨q, hq, qs', hqs, rfl⟩ := h
    have ih := filter_mapM hqs
    rw [List.filter_cons, List.filter_cons, isEmpty_eq hq]
    cases q.isEmpty
    · simp only [Bool.not_false, ite_true, List.mapM_cons, hq, ih, Option.bind_eq_bind, Option.bind_some,
        Option.pure_def]
    · simpa using ih

theorem reset_filter (form : TicketReserveForm) :
    form.resetPassengersIndex.passengerFormList.filter (!·.isEmpty) = form.passengerFormList.filter (!·.isEmpty) := by
  simp only [TicketReserveForm.resetPassengersIndex, List.filter_append, List.filter_filter, Bool.and_self]
  have : (List.replicate (TicketReserveForm.MAX_PASSENGERS_NUMBER -
      (form.passengerFormList.filter (!·.isEmpty)).length) ({} : PassengerForm)).filter (!·.isEmpty) = [] := by
    rw [List.filter_eq_nil_iff]
    intro x hx
    rw [List.eq_of_mem_replicate hx]
    decide
  rw [this, List.append_nil]

theorem compact_filter (ps : List PassengerInput) :
    (compactPassengers ps).filter (!·.isEmpty) = ps.filter (!·.isEmpty) := by
  simp only [compactPassengers, List.filter_append, List.filter_filter, Bool.and_self]
  have : (List.replicate (Spec.Env.Config.maxPassengersNumber - (ps.filter (!·.isEmpty)).length)
      ({} : PassengerInput)).filter (!·.isEmpty) = [] := by
    rw [List.filter_eq_nil_iff]
    intro x hx
    rw [List.eq_of_mem_replicate hx]
    decide
  rw [this, List.append_nil]

/-- 空でない欄の搭乗者は、[Spec] の搭乗者の会員番号・氏名・性別を持つ。 -/
theorem passengerFacts : ∀ {fs : List PassengerForm} {ins : List PassengerInput} {ps : List Spec.Reserve.DraftPassenger},
    fs.mapM passengerInputOf = some ins → ins.mapM PassengerInput.toPassenger = some ps →
    LangSemantics.Core.List.Forall₂ PassengerFacts (fs.map B2Mapper.mapPassenger) ps
  | [], ins, ps, h1, h2 => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h1
    subst h1
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h2
    subst h2
    exact .nil
  | f :: fs, ins, ps, h1, h2 => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h1
    obtain ⟨i, hi, ins', hins, rfl⟩ := h1
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h2
    obtain ⟨p, hp, ps', hps, rfl⟩ := h2
    refine .cons ?_ (passengerFacts hins hps)
    simp only [passengerInputOf, Option.map_eq_some_iff] at hi
    obtain ⟨a, -, rfl⟩ := hi
    simp only [PassengerInput.toPassenger, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hp
    obtain ⟨fn, hfn, gn, hgn, ag, -, g, hg, rfl⟩ := hp
    exact ⟨_, rfl, rfl, hfn, hgn, hg⟩

/-- 空でない欄の搭乗者の年齢（`ageOfPassenger`）は、[Spec] の搭乗者の年齢。 -/
theorem ages_eq : ∀ {fs : List PassengerForm} {ins : List PassengerInput} {ps : List Spec.Reserve.DraftPassenger},
    fs.mapM passengerInputOf = some ins → ins.mapM PassengerInput.toPassenger = some ps →
    (fs.map fun f => some (B2Mapper.mapPassenger f)).mapM Abstraction.Fare.TotalAlpha.ageOfPassenger =
        some (ps.map (·.age)) ∧ ins.map (·.age.getD 0) = ps.map (·.age)
  | [], ins, ps, h1, h2 => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h1
    subst h1
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h2
    subst h2
    exact ⟨rfl, rfl⟩
  | f :: fs, ins, ps, h1, h2 => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h1
    obtain ⟨i, hi, ins', hins, rfl⟩ := h1
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h2
    obtain ⟨p, hp, ps', hps, rfl⟩ := h2
    obtain ⟨ih1, ih2⟩ := ages_eq hins hps
    simp only [passengerInputOf, Option.map_eq_some_iff] at hi
    obtain ⟨a, ha, rfl⟩ := hi
    simp only [PassengerInput.toPassenger, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hp
    obtain ⟨fn, -, gn, -, ag, hag, g, -, rfl⟩ := hp
    subst hag
    have hage : Abstraction.Fare.TotalAlpha.ageOfPassenger (some (B2Mapper.mapPassenger f)) = some ag := by
      cases hf : f.age with
      | none => rw [hf] at ha; cases ha
      | some x =>
        rw [hf] at ha
        simp only [optAgeOf, Option.map_eq_some_iff, Option.some.injEq] at ha
        obtain ⟨n, hn, rfl⟩ := ha
        simp [Abstraction.Fare.TotalAlpha.ageOfPassenger, B2Mapper.mapPassenger, hf, hn]
    refine ⟨?_, ?_⟩
    · simp only [List.map_cons, List.mapM_cons, hage, ih1, Option.bind_eq_bind, Option.bind_some, Option.pure_def]
    · simp only [List.map_cons, Option.getD_some, ih2]

theorem reserveInputOf_eq {form : TicketReserveForm} {ri : ReserveInput} (h : reserveInputOf form = some ri) :
    form.repFamilyName = some ri.repFamilyName ∧ form.repGivenName = some ri.repGivenName ∧
      (∃ a, form.repAge = some a ∧ natOfJ32 a = some ri.repAge) ∧ form.repGender = some ri.repGender ∧
      form.repTel1 = some ri.repTel1 ∧ form.repTel2 = some ri.repTel2 ∧ form.repTel3 = some ri.repTel3 ∧
      form.repMail = some ri.repMail ∧ form.repMembershipNumber = ri.repMembershipNumber ∧
      form.passengerFormList.mapM passengerInputOf = some ri.passengers := by
  simp only [reserveInputOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨fn, h1, gn, h2, age, ⟨a, ha, hage⟩, g, h4, t1, h5, t2, h6, t3, h7, ml, h8, ps, h9, rfl⟩ := h
  exact ⟨h1, h2, ⟨a, ha, hage⟩, h4, h5, h6, h7, h8, rfl, h9⟩

/-- 予約内容の組み立て: [Spec] の予約内容 `d` が組み立てられれば、原典の予約情報は、代表者の欄と、すべての予約フライトに
同じ空でない搭乗者の列を持ち、その搭乗者は `d` の搭乗者に当たる。 -/
theorem reservation_facts {form : TicketReserveForm} {ri : ReserveInput} (hri : reserveInputOf form = some ri)
    {it : Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey} {d : Draft}
    (hd : buildDraft { ri with passengers := compactPassengers ri.passengers } it = some d)
    (fl : List (JRef SourceModel.Domain.Model.Flight)) :
    let r := TicketReserveHelper.createReservation form.resetPassengersIndex fl
    let xs := (form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger
    r.reserveFlightList = some (fl.map fun f => some { flight := f, passengerList := some (xs.map some) }) ∧
      (∃ age, r.repAge = some age ∧ age.val = (d.repAge : Int)) ∧
      (∃ M0, r.repMember = some M0 ∧ memberNoOf M0.membershipNumber = d.repMembershipNumber) ∧
      r.repFamilyName = some d.repFamilyName ∧ r.repGivenName = some d.repGivenName ∧
      r.repGender = some d.repGender ∧
      LangSemantics.Core.List.Forall₂ PassengerFacts xs d.passengers ∧ xs ≠ [] ∧ d.flights = it := by
  obtain ⟨h1, h2, ⟨a, ha, hage⟩, h4, -, -, -, -, h9, h10⟩ := reserveInputOf_eq hri
  have hf := filter_mapM h10
  simp only [buildDraft, compact_filter, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at hd
  obtain ⟨ps, hps, hd⟩ := hd
  split at hd
  · cases hd
  rename_i hne
  simp only [Option.some.injEq] at hd
  subst hd
  have hpf := passengerFacts hf hps
  refine ⟨?_, ⟨a, ?_, natOfJ32_eq_some.mp hage⟩, ⟨_, rfl, by simp only [TicketReserveForm.resetPassengersIndex, h9]⟩, ?_, ?_, ?_, hpf,
    ?_, rfl⟩
  · simp only [TicketReserveHelper.createReservation, reset_filter, List.map_map]
    rfl
  · simp [TicketReserveHelper.createReservation, B2Mapper.mapReservation, TicketReserveForm.resetPassengersIndex, ha]
  · simp [TicketReserveHelper.createReservation, B2Mapper.mapReservation, TicketReserveForm.resetPassengersIndex, h1]
  · simp [TicketReserveHelper.createReservation, B2Mapper.mapReservation, TicketReserveForm.resetPassengersIndex, h2]
  · simp [TicketReserveHelper.createReservation, B2Mapper.mapReservation, TicketReserveForm.resetPassengersIndex, h4]
  · intro hx
    rw [List.map_eq_nil_iff] at hx
    rw [hx] at hf
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at hf
    rw [← hf] at hps
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at hps
    subst hps
    exact hne rfl

end Abstraction.Reserve.Draft
