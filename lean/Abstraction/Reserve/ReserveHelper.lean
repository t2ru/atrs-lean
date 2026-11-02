import Abstraction.Reserve.ReserveFacts
import Abstraction.Reserve.Confirm

/-!
# Abstraction.Reserve.ReserveHelper

ABS-041 の補題: 予約確定（`TicketReserveHelper.reserve`。選択フライトの検証の後）の三つ組（backlog aedf の第 3 段）。
予約情報の組み立て（`Draft`）、予約内容の検証（`ValidateReservation`）、Clock の読み出し（D-014）、合計金額、予約の登録
（`Registration`）をつなぐ。
-/

namespace Abstraction.Reserve.ReserveHelper
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate
  Abstraction.Reserve.MemberCheck Abstraction.Reserve.ValidateReservation Abstraction.Reserve.Draft
  Abstraction.Reserve.Alpha Abstraction.Reserve.Vacancy Abstraction.Reserve.RegisterRun
  Abstraction.Reserve.Registration Abstraction.Reserve.ReserveFacts Abstraction.World.Alpha
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.App.B2 SourceModel.Domain.Service.B2 SourceModel.ReserveQuery
open SourceModel.Domain.Common.Exception
open Abstraction.Fare.TotalFareRun Abstraction.MasterData.Alpha LangSemantics.Java.Int

theorem now_hoare {t : FlightDb} {env : Env} {tJ : JLocalDate} (hclock : ∀ n, env.clock n = tJ)
    {E : JThrow → St → Prop} :
    Hoare (fun s : St => s.db = t ∧ s.env = env) now (fun r s => r = tJ ∧ s.db = t ∧ s.env = env) E := by
  intro s ⟨h1, h2⟩
  subst h1 h2
  exact ⟨hclock _, rfl, rfl⟩

theorem buildDraft_eq {ri : Spec.UseCase.Reserve.ReserveInput} {ks : List Spec.Model.FlightKey}
    {d : Spec.UseCase.Reserve.Draft} (h : Spec.UseCase.Reserve.buildDraft ri ks = some d) :
    d.repFamilyName = ri.repFamilyName ∧ d.repGivenName = ri.repGivenName ∧ d.repAge = ri.repAge ∧
      d.repTel = ri.repTel1 ++ "-" ++ ri.repTel2 ++ "-" ++ ri.repTel3 ∧ d.repMail = ri.repMail ∧
      (ri.passengers.filter (!·.isEmpty)).mapM Spec.UseCase.Reserve.PassengerInput.toPassenger = some d.passengers ∧
      d.flights = ks := by
  simp only [Spec.UseCase.Reserve.buildDraft, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at h
  obtain ⟨ps, hps, hd⟩ := h
  split at hd
  · cases hd
  simp only [Option.some.injEq] at hd
  subst hd
  exact ⟨rfl, rfl, rfl, rfl, rfl, hps, rfl⟩

/-- 予約確定（前段の後）の三つ組。予約内容の検証の [Spec] の値 `v` が成功なら、空席の確保の [Spec] の値が `w1` で、
状態の表の α は [Spec] の登録の結果。例外なら、障害（α は採番の前進だけ変わる）か、予約内容の検証または空席の確保の業務例外
（α は変わらない）。 -/
theorem helperReserve_hoare {t : FlightDb} {w : Spec.Port.World} (hw : worldOfDb t = some w) (hinv : w.Inv)
    (hk : KeysOk w) {p : SourceModel.MasterQuery.Providers} {ic : ReserveInput} (he : MemberEnv t ic.db w)
    {cfg : Spec.Config} {md : Spec.MasterData}
    (hbq : ∀ cd : Spec.Model.BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hfq : ∀ cd : Spec.Model.FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    (hmin : (helperOf p ic).ticketReserveService.representativeMinAge.val = (cfg.representativeMinAge : Int))
    {rq : Spec.UseCase.Reserve.Request} (hrv : rq.Valid) (hri : reserveInputOf ic.form = some rq.form)
    {ks : List Spec.Model.FlightKey} {d : Spec.UseCase.Reserve.Draft}
    (hd : Spec.UseCase.Reserve.buildDraft rq.form ks = some d)
    {f0 : SourceModel.App.B0.SelectFlightForm} {fs : List SourceModel.App.B0.SelectFlightForm}
    (hvc : LangSemantics.Core.List.Forall₂ (VacCond md p) (f0 :: fs) ks)
    (hex : ∀ k ∈ ks, (w.findForUpdate k).isSome)
    (hd9 : w.sequences.reserve ≤ 9999999999 ∧ w.sequences.reserveFlight + 1 ≤ 2147483647 ∧
      w.sequences.passenger + 11 ≤ 2147483647) (hkl : ks.length ≤ 2)
    {FTs : List Spec.MasterData.FareType}
    (hFT : LangSemantics.Core.List.Forall₂ FareTypeFacts ((f0 :: fs).map (mkFlight p)) FTs)
    (hkf : LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) ks FTs)
    {T : Int.J32} {tfn : Nat}
    (hcalc : Spec.UseCase.Reserve.validateReservation cfg md w d = some (.ok ()) →
      TicketReserveServiceImpl.calculateTotalFare (helperOf p ic).ticketReserveService
        (some (((f0 :: fs).map (mkFlight p)).map some))
        (some (((ic.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).map some)) = .ok T ∧
      T.val = (tfn : Int) ∧ tfn ≤ 2147483647)
    {tJ : JLocalDate} {TD : Spec.Prim.Date} (hclock : ∀ n, ic.env.clock n = tJ)
    (hT : Abstraction.MasterData.AlphaLeaf.dateOfJ tJ = some TD) :
    ∃ v, Spec.UseCase.Reserve.validateReservation cfg md w d = some v ∧
      Hoare (fun s => s.db = t ∧ s.env = ic.env)
        (TicketReserveHelper.reserve (helperOf p ic) ic.form (((f0 :: fs).map (mkFlight p)).map some))
        (fun o s => v = .ok () ∧ s.env = ic.env ∧ ∃ w1, secureAll md TD d.passengers.length ks w = some (.ok w1) ∧
          worldOfDb s.db = some (Spec.UseCase.Reserve.register d TD tfn w1).2 ∧
          o.reserveNo = some (Spec.UseCase.Reserve.register d TD tfn w1).1.val ∧
          o.paymentDate = (mkFlight p f0).departureDate ∧ o.totalFare = some T)
        (fun e s => s.env = ic.env ∧ ((IsFault ic.env e ∧ ∃ a, worldOfDb s.db = some (Spec.UseCase.Reserve.advance w a)) ∨
          (∃ c args, e = AtrsBusinessException.newArgs c args ∧ worldOfDb s.db = some w ∧
            (v = .error (.business c args) ∨ (v = .ok () ∧ args = [] ∧
              secureAll md TD d.passengers.length ks w = some (.error (.business c []))))))) := by
  obtain ⟨hrfl, ⟨age, hage, hagev⟩, ⟨M0, hm, hn⟩, hf, hg, hgd, hR, hne, hks⟩ :=
    reservation_facts hri (by rw [buildDraft_compact]; exact hd) (((f0 :: fs).map (mkFlight p)).map some)
  simp only [create_reset] at hrfl hage hm hf hg hgd
  subst hks
  obtain ⟨hdfn, hdgn, hdage, hdtel, hdmail, hdps, -⟩ := buildDraft_eq hd
  obtain ⟨hnames, hfnl, hgnl, hagel, htel12, htel3, hmaill, hplen, hpass⟩ := hrv
  obtain ⟨h1, h2, -, -, h5, h6, h7, h8, -, h10⟩ := reserveInputOf_eq hri
  have hf10 := filter_mapM h10
  have hpc : LangSemantics.Core.List.Forall₂ PassCond (ic.form.passengerFormList.filter (!·.isEmpty)) d.passengers :=
    passConds hf10 hdps fun q hq => hpass q (List.mem_filter.mp hq).1
  have hlen' : ((ic.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).length ≤ 6 := by
    have := LangSemantics.Core.MapM.mapM_some_length h10
    rw [List.length_map]
    exact Nat.le_trans (List.length_filter_le _ _) (this ▸ hplen)
  have hql : d.passengers.length ≤ 6 := by
    rw [← forall₂_length hpc]; simpa using hlen'
  have hFT' : LangSemantics.Core.List.Forall₂ FareTypeFacts (mkFlight p f0 :: fs.map (mkFlight p)) FTs := hFT
  obtain ⟨v, hv, hH⟩ := validate_hoare (P := fun s => s.db = t ∧ s.env = ic.env) ⟨fun _ h => h.1, fun _ h => h⟩ he
    (fl := mkFlight p f0) (fls := fs.map (mkFlight p)) (by rw [hrfl]; simp only [List.map_map, List.map_cons]; rfl) hage hagev hmin hm hn hf hg hgd hR hne hlen' hFT' hkf
  refine ⟨v, hv, ?_⟩
  unfold TicketReserveHelper.reserve
  refine Hoare.bind' (Hoare.conseq hH (fun _ h => h) (fun _ _ h => h) fun e s ⟨⟨hsd, hse⟩, he'⟩ => ⟨hse, ?_⟩)
    fun _ => ?_
  · rcases he' with hft | ⟨c, args, rfl, hc⟩
    · exact .inl ⟨hse ▸ hft, {}, by rw [advance_zero, hsd]; exact hw⟩
    · exact .inr ⟨c, args, rfl, hsd ▸ hw, .inl hc⟩
  intro s ⟨hs, hv0⟩
  subst hv0
  refine (?_ : Hoare (fun s => s.db = t ∧ s.env = ic.env) _ _ _) s hs
  refine Hoare.bind' (now_hoare hclock) fun rd => ?_
  intro s ⟨hrd, hsd, hse⟩
  subst hrd
  refine (?_ : Hoare (fun s => s.db = t ∧ s.env = ic.env) _ _ _) s ⟨hsd, hse⟩
  obtain ⟨hc, hTv, hTm⟩ := hcalc hv
  generalize hR : ({ TicketReserveHelper.createReservation ic.form (((f0 :: fs).map (mkFlight p)).map some) with
    reserveDate := some rd } : SourceModel.Domain.Model.Reservation) = R
  have hRf := (show R.reserveFlightList = (TicketReserveHelper.createReservation ic.form
    (((f0 :: fs).map (mkFlight p)).map some)).reserveFlightList by rw [← hR]).trans hrfl
  have hc' : TicketReserveHelper.calculateTotalFare (helperOf p ic) (((f0 :: fs).map (mkFlight p)).map some) R =
      .ok T := by
    simp only [TicketReserveHelper.calculateTotalFare, hRf, LangSemantics.Java.EStateSimp.deref_some, List.map_cons,
      LangSemantics.Java.JList.get_cons_zero, LangSemantics.Java.EStateSimp.except_ok_bind]
    simp only [List.map_cons] at hc
    exact hc
  dsimp only
  simp only [hc', MemberCheck.lift_ok, pure_bind]
  have hmem := validate_members hv
  have hpm : ∀ f ∈ ic.form.passengerFormList.filter (!·.isEmpty), ∀ s, f.membershipNumber = some s → s ≠ "" →
      ∃ x, w.findMember ⟨s⟩ = some x := by
    intro f hf s hs hne
    obtain ⟨q, hq, hpcq⟩ := forall₂_mem_left hpc hf
    obtain ⟨i, hi, hiq⟩ := hpcq.input
    have hqm : q.membershipNumber = some ⟨s⟩ := by
      simp only [passengerInputOf, Option.map_eq_some_iff] at hi
      obtain ⟨a, -, rfl⟩ := hi
      simp only [Spec.UseCase.Reserve.PassengerInput.toPassenger, Option.bind_eq_bind, Option.bind_eq_some_iff,
        Option.pure_def, Option.some.injEq] at hiq
      obtain ⟨_, _, _, _, _, _, _, _, rfl⟩ := hiq
      simp only [hs, memberNoOf_some hne]
    exact Option.isSome_iff_exists.mp (hmem.2 q hq _ hqm)
  have hrm : ∀ s, M0.membershipNumber = some s → s ≠ "" → ∃ x, w.findMember ⟨s⟩ = some x := by
    intro s hs hne
    have := hn
    rw [hs, memberNoOf_some hne] at this
    exact Option.isSome_iff_exists.mp (hmem.1 _ this.symm)
  have hreg := registerReservation_hoare hbq hfq (env := ic.env) hw hinv (helperOf p ic).ticketReserveService
    hclock hT hvc hex hpc hql hk hd9 hkl hpm { R with totalFare := some T } ?_ (by rw [← hR]) hT rfl hTv hTm
    (fn := d.repFamilyName) (by rw [← hR]; exact hf) (hdfn ▸ hfnl) (gn := d.repGivenName) (by rw [← hR]; exact hg)
    (hdgn ▸ hgnl) (by rw [← hR]; exact hage) hagev (by rw [hdage]; omega) (by rw [← hR]; exact hgd) (tel := d.repTel)
    ?_ ?_ (mail := d.repMail) ?_ (hdmail ▸ hmaill) (by rw [← hR]; exact hm) hrm
  · refine Hoare.bind' (Hoare.conseq hreg (fun _ h => h) (fun _ _ h => h) fun e s ⟨hse, h⟩ => ⟨hse, ?_⟩)
      fun dto => Hoare.pure' fun s ⟨hse, w1, hsa, hdb, hno, hpd⟩ => ⟨trivial, hse, w1, hsa, ?_, ?_, hpd, rfl⟩
    · rcases h with h | ⟨c, hc, hsa, hdb⟩
      · exact .inl h
      · exact .inr ⟨c, [], hc, hdb, .inr ⟨trivial, rfl, hsa⟩⟩
    · rw [register_eq d TD tfn (secureAll_world hsa).2.2.1, ← hn]
      exact hdb
    · rw [register_eq d TD tfn (secureAll_world hsa).2.2.1]
      exact hno
  · show R.reserveFlightList = _
    rw [hRf]
    simp only [rfList, rfOfForm, paxList, List.map_cons, List.map_map]
    rfl
  · show R.repTel = _
    rw [← hR]
    simp only [TicketReserveHelper.createReservation, h5, h6, h7, Option.getD_some, hdtel]
  · rw [hdtel]
    have h1 : "-".length = 1 := by decide
    simp only [String.length_append, h1]
    omega
  · show R.repMail = _
    rw [← hR]
    simp only [TicketReserveHelper.createReservation, B2Mapper.mapReservation, h8, hdmail]

end Abstraction.Reserve.ReserveHelper
