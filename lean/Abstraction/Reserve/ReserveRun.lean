import Abstraction.Reserve.ConfirmRun
import Abstraction.Reserve.ReserveFacts
import Abstraction.Reserve.Select
import Abstraction.Reserve.ReserveHelper
import Abstraction.Reserve.KeysPres
import Abstraction.World.Init

/-!
# Abstraction.Reserve.ReserveRun

ABS-041 の補題: 予約確定の 1 歩の対応（backlog aedf の第 3 段）。具体機械の予約確定の 1 歩（どの許される並びでも）は、
出力の値で終わり、実行後の状態は具体側の不変条件を満たし、その α と出力の像は、[Spec] の予約の 1 歩（環境の選択
N-001・N-002 と自由な選択 N-004 を適当に選んだもの）の結果である。障害で終われば、状態は採番の前進だけ変わる。
-/

namespace Abstraction.Reserve.ReserveRun
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate
  Abstraction.Reserve.MemberCheck Abstraction.Reserve.Draft Abstraction.Reserve.Alpha
  Abstraction.Reserve.Input Abstraction.Reserve.SpecFacts Abstraction.Reserve.Catch Abstraction.Reserve.NoNL
  Abstraction.Reserve.Selects Abstraction.Reserve.Vacancy Abstraction.Reserve.ConfirmRun Abstraction.Reserve.ReserveFacts
  Abstraction.Reserve.ReserveHelper Abstraction.Reserve.KeysPres Abstraction.Reserve.Registration
open Abstraction.Fare.TotalAlpha Abstraction.Fare.TotalFareRun Abstraction.MasterData.Alpha
  Abstraction.MasterData.AlphaLeaf Abstraction.World.Alpha
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.App.B2 SourceModel.MasterQuery SourceModel.ReserveQuery
open Spec.UseCase.Reserve
open Abstraction.World.Init Abstraction.MasterData.QueryRun Machine

section
open Spec.Model Spec.Prim Spec.Prim.Text SourceModel.Domain.Common.Masterdata

/-- 空席の確保の前提（`VacCond`）: 選択フライトの主キーのフライトがあれば、マスタに搭乗クラス・運賃種別・便マスタがあり、
フライト情報の便マスタは主キーの便名を持つ。 -/
theorem vacCond_of {md : Spec.MasterData} {p : Providers} {w : Spec.Port.World}
    (hmc : ∀ name : String, hasText name = true →
      ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
      ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name = .ok (some fm) ∧
        fm.flightName = some name ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
        fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
        r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
        aa.code = some rt.arrAirportCd.val)
    (h3 : md.MD3) (href : w.RefMaster md) {f : SourceModel.App.B0.SelectFlightForm} {k : FlightKey}
    (hk : keyOfForm f = some k) (ht : hasText k.flightName.val = true) (he : w.existsFlight k = true) :
    VacCond md p f k := by
  have he' := he
  simp only [Spec.Port.World.existsFlight, List.any_eq_true, beq_iff_eq] at he'
  obtain ⟨g, hg, rfl⟩ := he'
  obtain ⟨⟨m, hm, hmn⟩, ⟨b, hb, hbn⟩, -⟩ := href g hg
  obtain ⟨X, hX⟩ : ∃ X, md.flightMasterOf g.key.flightName.val = some X := by
    apply Option.isSome_iff_exists.mp
    unfold Spec.MasterData.flightMasterOf
    rw [List.find?_isSome]
    exact ⟨m, hm, by simp [hmn]⟩
  have hXm : X ∈ md.flightMasters := List.mem_of_find?_eq_some hX
  obtain ⟨rt, hrt⟩ : ∃ rt, Spec.Ticket.routeOfMaster md X = some rt := by
    apply Option.isSome_iff_exists.mp
    unfold Spec.Ticket.routeOfMaster
    rw [List.find?_isSome]
    obtain ⟨r, hr, hrn⟩ := h3.2 X hXm
    exact ⟨r, hr, by simp [hrn]⟩
  obtain ⟨fm, -, -, hfm, hfn, -⟩ := Abstraction.Reserve.Select.mkFlight_master_some hmc hk ht hX hrt
  refine ⟨hk, ?_, fareTypeOf_of_exists href he, fm, hfm, hfn⟩
  apply Option.isSome_iff_exists.mp
  unfold Spec.MasterData.boardingClassOf
  rw [List.find?_isSome]
  exact ⟨b, hb, by simp [hbn]⟩

end

theorem step_reserve {w w' : Spec.Port.World} {ia : Spec.UseCase.Reserve.MInput} (hop : ia.op = .reserve)
    {x : Except Spec.Error.AtrsError ReserveResult} (hx : reserveOp ia.cfg ia.md ia.today w ia.req = some (w', x))
    (d : Spec.Nondet.InvalidRequestDetail) :
    reserveStep w ia ((.none, .none), d) = (w', withDetail d (x.map .reserved)) := by
  simp [reserveStep, baseStep, hop, hx]

/-- 障害の像: I/O の失敗は環境の選択 N-002、排他の失敗は N-001 で、状態は採番の前進だけ変わる。 -/
theorem fault_out {env : Env} {e : JThrow} (hf : IsFault env e) (w : Spec.Port.World)
    {ia : Spec.UseCase.Reserve.MInput} (hop : ia.op = .reserve) (a : Spec.Nondet.SeqAdvance) :
    ∃ oc oa c, catchReserve (.error e) = .ok oc ∧ reserveStep w ia c = (advance w a, oa) ∧ aoR oc = some oa ∧
      Spec.Nondet.admits ⟨env.ioFailAt, env.conflictAt⟩ c.1 := by
  obtain ⟨m, ⟨rfl, hi⟩ | ⟨rfl, hc⟩⟩ := hf
  · exact ⟨_, _, ((.none, .failure a), .std), catch_ioFault ⟨m, rfl, hi⟩, by simp [reserveStep], rfl,
      admits_ioFault ⟨m, rfl, hi⟩ a⟩
  · exact ⟨_, _, ((.conflict a, .none), .std), catch_conflict m, by simp [reserveStep, hop], rfl, admits_conflict hc a⟩

/-- 予約確定の流れ（`reserveBody`）: 前段の選択フライトの検証の三つ組と、前段が成功したときの後段の三つ組をつなぐ。 -/
theorem reserve_core {α : Type} {P : St → Prop} {p : Providers} {ic : SourceModel.ReserveQuery.ReserveInput}
    {fl0 : SourceModel.Domain.Model.Flight} {fls : List SourceModel.Domain.Model.Flight}
    (htf : SourceModel.App.B0.TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p)
      ic.form.selectFlightFormList = .ok ((fl0 :: fls).map some))
    {v : Except Spec.Error.AtrsError α}
    (hvf : Hoare P (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList
      (helperOf p ic).reserveIntervalTime (some ((fl0 :: fls).map some))) (Post P v) (PostE P v))
    (hreq : ∀ e, v = .error e → IsReq e) {Q : ReserveCompleteOutputDto → St → Prop} {E : JThrow → St → Prop}
    (hE : ∀ e s, PostS P v e s → E e s)
    (hrest : (∃ a, v = .ok a) → Hoare P (TicketReserveHelper.reserve (helperOf p ic) ic.form ((fl0 :: fls).map some)) Q E) :
    Hoare P (reserveBody p ic) Q E := by
  unfold reserveBody
  simp only [htf, MemberCheck.lift_ok, pure_bind]
  refine Hoare.bind' (Hoare.conseq (helper_vf hvf hreq) (fun _ h => h) (fun _ _ h => h) hE) fun _ => ?_
  intro s ⟨hs, hv⟩
  exact hrest hv s hs

/-- 空席の確保の業務例外のコードは `e.ar.b2.2008` か `e.ar.b2.2009`。 -/
theorem secureAll_code {md : Spec.MasterData} {T : Spec.Prim.Date} {n : Nat} :
    ∀ {ks : List Spec.Model.FlightKey} {w : Spec.Port.World} {be : Spec.Error.BusinessError},
      secureAll md T n ks w = some (.error (.business be)) → be = .fareTypeUnavailable ∨ be = .noVacancy
  | [], w, be, h => by simp [secureAll] at h
  | k :: ks, w, be, h => by
    simp only [secureAll] at h
    cases hs : secureSeats md T n w k with
    | none => rw [hs] at h; cases h
    | some r =>
      rw [hs] at h
      simp only [Option.bind_some] at h
      cases r with
      | ok w' => exact secureAll_code h
      | error e =>
        simp only [Option.some.injEq, Except.error.injEq] at h
        subst h
        simp only [secureSeats, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at hs
        obtain ⟨ft, -, hs⟩ := hs
        split at hs
        · simp only [Option.some.injEq, Except.error.injEq, Spec.Error.AtrsError.business.injEq] at hs
          exact .inl hs.symm
        · split at hs
          · simp at hs
          · split at hs
            · simp only [Option.some.injEq, Except.error.injEq, Spec.Error.AtrsError.business.injEq] at hs
              exact .inr hs.symm
            · simp at hs

theorem forall₂_imp_mem {α β : Type} {R S : α → β → Prop} :
    ∀ {xs : List α} {ys : List β}, LangSemantics.Core.List.Forall₂ R xs ys → (∀ x y, R x y → y ∈ ys → S x y) →
      LangSemantics.Core.List.Forall₂ S xs ys
  | [], [], .nil, _ => .nil
  | _ :: _, _ :: _, .cons hab hr, h =>
    .cons (h _ _ hab List.mem_cons_self) (forall₂_imp_mem hr fun x y hxy hy => h x y hxy (List.mem_cons_of_mem _ hy))

theorem findForUpdate_isSome {w : Spec.Port.World} {k : Spec.Model.FlightKey} (h : w.existsFlight k = true) :
    (w.findForUpdate k).isSome := by
  simp only [Spec.Port.World.existsFlight, List.any_eq_true] at h
  unfold Spec.Port.World.findForUpdate
  rw [List.find?_isSome]
  exact h

/-- 予約確定の 1 歩: 具体機械の予約確定の 1 歩（どの許される並びでも）は出力の値で終わり、実行後の状態は具体側の不変条件を
満たし、その α と出力の像は、[Spec] の予約の 1 歩（環境の選択と自由な選択を適当に選んだもの）の結果である。 -/
@[obligation "ABS-020", "ABS-022"]
theorem reserve_run {t : FlightDb} {w : Spec.Port.World} (hw : worldOfDb t = some w) (hic : IcW t) (hinv : w.Inv)
    {ic : SourceModel.ReserveQuery.MInput} {ia : Spec.UseCase.Reserve.MInput} (hα : aiR ic = some ia)
    (hk : ic.kind = .reserve) (hpre : ia.Pre w) (h9 : dev_D009 w ia) (h14 : dev_D014R ic) (h31 : dev_D031 ia)
    (h1 : dev_D001R ia) (h2 : dev_D002R ia) (h12 : dev_D012R ia) (h27 : dev_D027R ic) {mo : Order}
    (hmo : mo.Allowed ic.input.db) :
    ∃ oc w' oa c, catchReserve (runOp t ic mo).1 = .ok oc ∧ worldOfDb (runOp t ic mo).2 = some w' ∧
      IcW (runOp t ic mo).2 ∧ reserveStep w ia c = (w', oa) ∧ aoR oc = some oa ∧ Spec.Nondet.admits (ceR ic) c.1 := by
  obtain ⟨hcfg, hmd, hT, hreq, hop⟩ := aiR_eq hα
  have hop' : ia.op = .reserve := by
    rw [hk] at hop; simp only [opOf, Option.some.injEq] at hop; exact hop.symm
  obtain ⟨hsel, hri⟩ := requestOf_eq hreq
  have hrv0 := hpre.2.2.1
  obtain ⟨hok, hrv, href, hmref, hx⟩ := hpre
  obtain ⟨hcv, hmv⟩ := hok.valid
  rw [hop'] at hx
  obtain ⟨⟨w', x⟩, hx⟩ := Option.isSome_iff_exists.mp hx
  obtain ⟨v, hv, hcases⟩ := reserveOp_cases hx
  obtain ⟨p, hl, hbq, hfq, hmn, hmc⟩ := Abstraction.Reserve.Providers.load_res hmd hmv hmo
  have hrun : runOp t ic mo = ((runOn (reserveBody p ic.input) t ic.input.env).1.map
      SourceModel.ReserveQuery.MOutputValue.reserved, (runOn (reserveBody p ic.input) t ic.input.env).2) := by
    simp only [runOp, hk, runReserve, hl]
  let P : St → Prop := fun s => s.db = t ∧ s.env = ic.input.env
  have hP : Stable P t := ⟨fun _ h => h.1, fun _ h => h⟩
  have hkw : KeysOk w := hic w hw
  have he : MemberEnv t ic.input.db w := ⟨hw, hkw, ia.md, hmd, hmv.md1, hmref⟩
  obtain ⟨hriT, hminT⟩ := configOf_more hcfg
  have hnames := hrv.1
  obtain ⟨fl0, fls, hfl, hvf⟩ := vf_all hP hmv.md3 hbq hfq hmn hmc hw href
    (ri := (helperOf p ic.input).reserveIntervalTime) hriT hsel hnames h31 hv
  have htf : SourceModel.App.B0.TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p)
      ic.input.form.selectFlightFormList = .ok ((fl0 :: fls).map some) := by
    rw [toFlightList_ok p hsel hnames, ← hfl, List.map_map]
    rfl
  have hreq' := validateFlightList_req hv
  have hs0 : P { db := t, env := ic.input.env } := ⟨rfl, rfl⟩
  rw [hrun]
  unfold runOn
  rcases hcases with ⟨e, rfl, hww, rfl⟩ | ⟨it, rfl, d, vr, hd, hvr, hres⟩
  · -- 前段の失敗
    rw [hww] at hx
    have hH := reserve_core (P := P) (Q := fun _ _ => False) htf hvf hreq' (fun _ _ h => h) (fun ⟨_, h⟩ => by cases h)
    have hr := Hoare.run hH hs0
    revert hr
    cases (reserveBody p ic.input).run { db := t, env := ic.input.env } with
    | ok o s => intro h; exact h.elim
    | error e' s =>
      rintro ⟨⟨hsd, hse⟩, hE⟩
      rcases hE with hf | ⟨⟨msg, rfl⟩, str, hstr⟩
      · obtain ⟨oc, oa, c, hc, hst, ho, had⟩ := fault_out (IsIoFault.fault (hse ▸ hf)) w hop' {}
        rw [ConfirmRun.advance_zero] at hst
        exact ⟨oc, w, oa, c, hc, by show worldOfDb s.db = _; rw [hsd]; exact hw,
          by show IcW s.db; rw [hsd]; exact hic, hst, ho, had⟩
      · simp only [Except.mapError, Except.error.injEq] at hstr
        refine ⟨.error .badRequest, w, _, ((.none, .none), ⟨some ""⟩), catch_badRequest msg,
          by show worldOfDb s.db = _; rw [hsd]; exact hw, by show IcW s.db; rw [hsd]; exact hic, step_reserve hop' hx _, ?_,
          admits_std _⟩
        simp only [Except.map, hstr, withDetail, Option.getD_some]
        rfl
  · -- 前段の成功
    have hsk := selects_ok hv
    obtain ⟨hl1, hl2⟩ := validateFlightList_len hv
    rw [List.length_map, forall₂_len hsk] at hl1 hl2
    have hex' : ∀ k ∈ it.toList, w.existsFlight k = true ∧ Spec.Prim.Text.hasText k.flightName.val = true := by
      intro k hk'
      obtain ⟨s, hs, r, hr, rfl, he⟩ := forall₂_right_mem hsk k hk'
      obtain ⟨-, hrk, hrv⟩ := resolve_key hr
      refine ⟨he, ?_⟩
      rw [hrk]
      simp only
      rw [hrv]
      exact hnames s hs
    have hexk : ∀ k ∈ it.toList, ∃ FT, ia.md.fareTypeOf k.fareTypeCd = some FT :=
      fun k hk' => fareTypeOf_of_exists href (hex' k hk').1
    obtain ⟨FTs, hkf⟩ := exists_forall₂ hexk
    have htf0 := htf
    obtain ⟨f0, fs, hff⟩ : ∃ f0 fs, ic.input.form.selectFlightFormList = f0 :: fs := by
      cases h : ic.input.form.selectFlightFormList with
      | nil => rw [h] at hfl; cases hfl
      | cons f0 fs => exact ⟨f0, fs, rfl⟩
    have hks := forms_keys hsel hsk
    rw [hff] at hks hfl
    have hvc : LangSemantics.Core.List.Forall₂ (VacCond ia.md p) (f0 :: fs) it.toList :=
      forall₂_imp_mem hks fun f k hk' hkm =>
        vacCond_of hmc hmv.md3 href hk' (hex' k hkm).2 (hex' k hkm).1
    have hFT : LangSemantics.Core.List.Forall₂ FareTypeFacts ((f0 :: fs).map (mkFlight p)) FTs := ft_forall hfq hks hkf
    have hexU : ∀ k ∈ it.toList, (w.findForUpdate k).isSome :=
      fun k hk' => findForUpdate_isSome (hex' k hk').1
    have hdc : buildDraft { ia.req.form with passengers := compactPassengers ia.req.form.passengers }
        it = some d := by rw [buildDraft_compact]; exact hd
    let tfn := (Spec.Fare.totalFareOfKeys ia.cfg ia.md (tfOf ia).flights (tfOf ia).ages).getD 0
    have hcalc : validateReservation ia.cfg ia.md w d = some (.ok ()) →
        SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare
          (helperOf p ic.input).ticketReserveService (some (((f0 :: fs).map (mkFlight p)).map some))
          (some (((ic.input.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).map some)) =
          .ok (Int.J32.ofInt tfn) ∧ (Int.J32.ofInt tfn).val = (tfn : Int) ∧ tfn ≤ 2147483647 := by
      intro hvr'
      rw [hvr] at hvr'
      cases hvr'
      rcases hres with ⟨e, he', -⟩ | ⟨-, n, hn, -⟩
      · cases he'
      obtain ⟨hA, hPre, -⟩ := tf_facts hcfg hmd hsel hri hcv hmv hrv hsk hl1 hl2 hdc hn
      have hle : tfn ≤ 1200000000 := totalFareOfKeys_le hPre
      refine ⟨?_, LangSemantics.Java.IntLemmas.ofInt_nat (by omega), by omega⟩
      rw [hfl]
      exact Abstraction.Reserve.TotalFare.calc_eq hA hPre h1 h2 h12 hmo hl htf0 ic.input.db
    obtain ⟨v', hv', hH'⟩ := helperReserve_hoare hw hinv hkw he hbq hfq hminT hrv hri hd hvc hexU (h9 hop')
      hl2 hFT hkf hcalc h14 hT
    rw [hvr] at hv'
    cases hv'
    rw [hfl] at hH'
    have hH := reserve_core (P := P) htf0 hvf hreq' (fun e s ⟨⟨hsd, hse⟩, h⟩ => ⟨hse, .inl ⟨IsIoFault.fault (hse ▸ (h.resolve_right
      (by rintro ⟨-, str, hstr⟩; simp [Except.mapError] at hstr))), {}, by rw [ConfirmRun.advance_zero, hsd]; exact hw⟩⟩)
      (fun _ => hH')
    have hr := Hoare.run hH hs0
    have hdfl := (buildDraft_eq hd).2.2.2.2.2.2
    have hkf' : LangSemantics.Core.List.Forall₂ (fun k FT => ia.md.fareTypeOf k.fareTypeCd = some FT) d.flights.toList FTs :=
      hdfl ▸ hkf
    have hft : ∀ FT ∈ ia.md.fareTypes, NoNL FT.fareTypeName := fareTypeNames_noNL hmd h27.2
    revert hr
    cases (reserveBody p ic.input).run { db := t, env := ic.input.env } with
    | ok o s =>
      rintro ⟨hvr0, hse, w1, hsa, hdb, hno, hpd, hto⟩
      rcases hres with ⟨e, he', -⟩ | ⟨-, n, hn, sec, hsec, hsc⟩
      · rw [hvr0] at he'; cases he'
      rw [hsa] at hsec
      cases hsec
      rcases hsc with ⟨e, he', -⟩ | ⟨w1', hw1', pd, hpd', hww, rfl⟩
      · cases he'
      cases hw1'
      obtain ⟨-, hPre, hages⟩ := tf_facts hcfg hmd hsel hri hcv hmv hrv hsk hl1 hl2 hdc hn
      have hTn : tfn = n := by
        show (Spec.Fare.totalFareOfKeys ia.cfg ia.md (tfOf ia).flights (tfOf ia).ages).getD 0 = n
        rw [hages, show (tfOf ia).flights = it.toList from selectKeys_eq hsk, hn]
        rfl
      have hle : tfn ≤ 1200000000 := totalFareOfKeys_le hPre
      rw [hTn] at hdb hle
      rw [hww] at hx
      have hseq := (secureAll_world hsa).2.2.1
      have hdb' : worldOfDb s.db = some (register d ia.today n w1).2 := hdb
      refine ⟨.ok (.reserved o), _, _, ((.none, .none), .std), rfl, hdb', fun w'' h => ?_, step_reserve hop' hx _, ?_,
        admits_std _⟩
      · rw [hdb'] at h
        cases h
        rw [register_eq d ia.today n hseq]
        simpa only [List.length_map] using
          keysOk_regWorld hkw (secureAll_world hsa).1 (secureAll_world hsa).2.1 ia.today n d.repFamilyName d.repGivenName
            d.repAge d.repGender d.repTel d.repMail _ (d.passengers.map DraftPassenger.toPassenger) d.flights
      · obtain ⟨k0, ks', hk0s⟩ : ∃ k0 ks', it.toList = k0 :: ks' := by
          cases h : it.toList with
          | nil => rw [h] at hks; cases hks
          | cons k0 ks' => exact ⟨k0, ks', rfl⟩
        rw [hk0s] at hks hpd'
        rcases hks with _ | ⟨hk0, -⟩
        obtain ⟨dj, hdj, hdjk, -⟩ := keyOfForm_eq hk0
        simp only [List.head?_cons, Option.map_some, Option.some.injEq] at hpd'
        have hv' : natOfJ32 (Int.J32.ofInt tfn) = some n := by
          rw [natOfJ32_eq_some, hTn]
          exact LangSemantics.Java.IntLemmas.ofInt_nat (by omega)
        rw [hTn] at hv'
        simp only [aoR, hno, hpd, mkFlight, hdj, Option.bind_some, hdjk, hto, Except.map, withDetail, hpd']
        rw [hTn, hv', Abstraction.Reserve.Keys.ofString?_val, Option.bind_some, Option.map_some]
    | error e' s =>
      rintro ⟨hse, hE⟩
      rcases hE with ⟨hf, a, hdb⟩ | ⟨be, rfl, hdb, hcv⟩
      · obtain ⟨oc, oa, ch, hc, hst, ho, had⟩ := fault_out hf w hop' a
        exact ⟨oc, _, oa, ch, hc, hdb, fun w'' h => by rw [hdb] at h; cases h; exact keysOk_advance hkw a, hst, ho, had⟩
      · have hic' : IcW s.db := fun w'' h => by rw [hdb] at h; cases h; exact hkw
        rcases hcv with hvb | ⟨hvr0, hba, hsa⟩
        · rcases hres with ⟨e, he', hww, rfl⟩ | ⟨hvr0, -⟩
          · rw [hvb] at he'
            cases he'
            rw [hww] at hx
            have hnl := validate_nl hkf' hft hvr be hvb
            exact ⟨_, w, _, ((.none, .none), .std), catch_business hnl.1 hnl.2, hdb, hic', step_reserve hop' hx _,
              aoR_business be,
              admits_std _⟩
          · rw [hvb] at hvr0; cases hvr0
        · rcases hres with ⟨e, he', -⟩ | ⟨-, n, hn, sec, hsec, hsc⟩
          · rw [hvr0] at he'; cases he'
          rw [hsa] at hsec
          cases hsec
          rcases hsc with ⟨e, he', hww, rfl⟩ | ⟨w1, hw1, -⟩
          · cases he'
            rw [hww] at hx
            have hnc : NoNL be.code := Abstraction.Reserve.NoNL.code_noNL be
            exact ⟨_, w, _, ((.none, .none), .std), catch_business hnc (by simp [hba]), hdb, hic',
              step_reserve hop' hx _, aoR_business be,
              admits_std _⟩
          · cases hw1

/-- 予約の 1 歩（予約確認・予約確定）: どの許される並びでも、具体機械の 1 歩は出力の値で終わり、実行後の状態は具体側の
不変条件を満たし、その α と出力の像は、[Spec] の予約の 1 歩の結果である。 -/
theorem run_any {t : FlightDb} {w : Spec.Port.World} (hw : worldOfDb t = some w) (hic : IcW t)
    (hinv : w.Inv) {ic : SourceModel.ReserveQuery.MInput} {ia : Spec.UseCase.Reserve.MInput} (hα : aiR ic = some ia)
    (hpre : ia.Pre w) (h9 : dev_D009 w ia) (h31 : dev_D031 ia) (h1 : dev_D001R ia) (h2 : dev_D002R ia)
    (h12 : dev_D012R ia) (h27 : dev_D027R ic) (h14 : dev_D014R ic)
    {mo : Order} (hmo : mo.Allowed ic.input.db) :
    ∃ oc w' oa c, catchReserve (runOp t ic mo).1 = .ok oc ∧ worldOfDb (runOp t ic mo).2 = some w' ∧
      IcW (runOp t ic mo).2 ∧ reserveStep w ia c = (w', oa) ∧ aoR oc = some oa ∧ Spec.Nondet.admits (ceR ic) c.1 := by
  cases hk : ic.kind with
  | confirm =>
    obtain ⟨oc, oa, c, hc, ht, hst, ho, had⟩ := confirm_run hw hic hα hk hpre h31 h1 h2 h12 h27 hmo
    exact ⟨oc, w, oa, c, hc, by rw [ht]; exact hw, by rw [ht]; exact hic, hst, ho, had⟩
  | reserve => exact reserve_run hw hic hinv hα hk hpre h9 h14 h31 h1 h2 h12 h27 hmo

end Abstraction.Reserve.ReserveRun
