import Abstraction.Reserve.Confirm
import Abstraction.Reserve.Input
import Abstraction.Reserve.NoNL
import Abstraction.Reserve.SpecFacts
import Abstraction.Reserve.Providers

/-!
# Abstraction.Reserve.ConfirmRun

ABS-041 の補題: 予約確認の 1 歩の対応（backlog aedf の第 3 段）。具体機械の予約確認の 1 歩（どの許される並びでも）は、
状態を変えずに出力の値で終わり、その像は、[Spec] の予約確認の 1 歩（環境の選択と自由な選択を適当に選んだもの）の
出力である。
-/

namespace Abstraction.Reserve.ConfirmRun
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate
  Abstraction.Reserve.MemberCheck Abstraction.Reserve.Confirm Abstraction.Reserve.Draft Abstraction.Reserve.Alpha
  Abstraction.Reserve.Input Abstraction.Reserve.SpecFacts Abstraction.Reserve.Catch Abstraction.Reserve.NoNL
  Abstraction.Reserve.Selects
open Abstraction.Fare.TotalAlpha Abstraction.Fare.TotalFareRun Abstraction.MasterData.Alpha
  Abstraction.MasterData.AlphaLeaf Abstraction.World.Alpha
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.App.B2 SourceModel.MasterQuery SourceModel.ReserveQuery
open Spec.UseCase.Reserve

theorem configOf_more {c : SourceModel.AtrsProperties.AtrsConfig} {cfg : Spec.Config} (h : configOf c = some cfg) :
    c.reserveIntervalTime.val = (cfg.reserveIntervalTime : Int) ∧
      c.representativeMinAge.val = (cfg.representativeMinAge : Int) := by
  simp only [configOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨a1, e1, a2, e2, a3, e3, a4, e4, a5, e5, a6, e6, rfl⟩ := h
  exact ⟨natOfJ32_eq_some.mp e2, natOfJ32_eq_some.mp e3⟩

theorem ftFacts {md : Spec.MasterData} {p : Providers}
    (hfq : ∀ cd : Spec.Model.FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    {f : SourceModel.App.B0.SelectFlightForm} {k : Spec.Model.FlightKey} {FT : Spec.MasterData.FareType}
    (hk : keyOfForm f = some k) (hF : md.fareTypeOf k.fareTypeCd = some FT) : FareTypeFacts (mkFlight p f) FT := by
  obtain ⟨-, -, -, -, -, hft⟩ := keyOfForm_eq hk
  have h := hfq k.fareTypeCd
  rw [hF] at h
  obtain ⟨f', m, e1, e2, e3, e4, e5⟩ := fareType_full (ft := FT) (by simpa using h)
  exact ⟨f', m, by simp [mkFlight, hft, e1], e2, e3, e4, e5⟩

theorem advance_zero (w : Spec.Port.World) : advance w {} = w := by
  simp [advance]

theorem step_confirm {w : Spec.Port.World} {ia : Spec.UseCase.Reserve.MInput} (hop : ia.op = .confirm) {x : Except Spec.Error.AtrsError Nat}
    (hx : confirmOp ia.cfg ia.md w ia.req = some x) (d : Spec.Nondet.InvalidRequestDetail) :
    reserveStep w ia ((.none, .none), d) = (w, withDetail d (x.map .confirmed)) := by
  simp [reserveStep, baseStep, hop, hx]

theorem step_io (w : Spec.Port.World) (ia : Spec.UseCase.Reserve.MInput) (d : Spec.Nondet.InvalidRequestDetail) :
    reserveStep w ia ((.none, .failure {}), d) = (w, .error (.system "e.ar.fw.9999")) := by
  simp [reserveStep, advance_zero]

/-- 予約確認の合計金額の入力: 合計金額の具体側の入力の α は `tfOf`、その PRE が成り立ち、年齢の列は予約内容の搭乗者の
年齢。 -/
theorem tf_facts {ic : SourceModel.ReserveQuery.ReserveInput} {ia : Spec.UseCase.Reserve.MInput} (hcfg : configOf ic.config = some ia.cfg)
    (hmd : masterDataOf ic.db = some ia.md)
    (hsel : ic.form.selectFlightFormList.mapM selectOfForm = some ia.req.selects)
    (hri : reserveInputOf ic.form = some ia.req.form) (hcv : ia.cfg.Valid) (hmv : ia.md.Valid ia.cfg)
    (hrv : ia.req.Valid) (hl1 : 1 ≤ ia.req.selects.length) (hl2 : ia.req.selects.length ≤ 2)
    {d : Draft} (hd : buildDraft { ia.req.form with passengers := compactPassengers ia.req.form.passengers }
      (ia.req.selects.map (·.key)) = some d)
    {n : Nat} (hn : Spec.Fare.totalFareOfKeys ia.cfg ia.md (ia.req.selects.map (·.key)) (d.passengers.map (·.age)) =
      some n) :
    aiTF ⟨ic.db, ic.config, ic.form.selectFlightFormList,
        ((ic.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).map some⟩ = some (tfOf ia) ∧
      (tfOf ia).Pre ∧ (tfOf ia).ages = d.passengers.map (·.age) := by
  obtain ⟨-, -, -, -, -, -, -, -, -, h10⟩ := reserveInputOf_eq hri
  have hf := filter_mapM h10
  simp only [buildDraft, compact_filter, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def] at hd
  obtain ⟨ps, hps, hd⟩ := hd
  split at hd
  · cases hd
  rename_i hne
  simp only [Option.some.injEq] at hd
  subst hd
  obtain ⟨hA, hB⟩ := ages_eq hf hps
  have hages : (tfOf ia).ages = ps.map (·.age) := hB
  refine ⟨?_, ?_, hages⟩
  · rw [List.map_map]
    simp only [aiTF, hcfg, hmd, selects_keys hsel, Option.bind_some]
    rw [show ((fun x => some x) ∘ B2Mapper.mapPassenger) = fun f => some (B2Mapper.mapPassenger f) from rfl, hA]
    simp only [Option.map_some, tfOf, hB]
  · obtain ⟨hnames, -, -, -, -, -, -, hplen, hpages⟩ := hrv
    have hpsl : ps.length = (ia.req.form.passengers.filter (!·.isEmpty)).length :=
      LangSemantics.Core.MapM.mapM_some_length hps |>.symm |>.symm
    have hfl := List.length_filter_le (fun x : PassengerInput => !x.isEmpty) ia.req.form.passengers
    refine ⟨hcv, hmv, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · simpa [tfOf, Spec.Model.Range.minReserveFlights] using hl1
    · simpa [tfOf, Spec.Model.Range.maxReserveFlights] using hl2
    · rw [hages, List.length_map]
      simp only [Spec.Model.Range.minPassengers]
      cases ps with
      | nil => exact absurd rfl hne
      | cons _ _ => simp
    · rw [hages, List.length_map, hpsl]
      simp only [Spec.Model.Range.maxPassengers]
      simp only [Spec.Config.maxPassengersNumber] at hplen
      omega
    · intro a ha
      simp only [tfOf, List.mem_map, List.mem_filter] at ha
      obtain ⟨q, ⟨hq, -⟩, rfl⟩ := ha
      simp only [Spec.Model.Range.maxAge]
      cases hqa : q.age with
      | none => simp
      | some a => simpa using (hpages q hq).2.2 a hqa
    · intro k hk
      simp only [tfOf, List.mem_map] at hk
      obtain ⟨s, hs, rfl⟩ := hk
      exact hnames s hs
    · rw [hages]
      simp only [tfOf] at hn ⊢
      rw [hn]
      rfl

theorem forms_keys : ∀ {fs : List SourceModel.App.B0.SelectFlightForm} {ss : List Spec.Ticket.SelectFlight},
    fs.mapM selectOfForm = some ss →
      LangSemantics.Core.List.Forall₂ (fun f k => keyOfForm f = some k) fs (ss.map (·.key))
  | [], ss, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .nil
  | f :: fs, ss, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨s, hs, ss', hss, rfl⟩ := h
    exact .cons (selectOfForm_key hs) (forms_keys hss)

theorem ft_forall {md : Spec.MasterData} {p : Providers}
    (hfq : ∀ cd : Spec.Model.FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info)))) :
    ∀ {fs : List SourceModel.App.B0.SelectFlightForm} {ks : List Spec.Model.FlightKey}
      {FTs : List Spec.MasterData.FareType},
      LangSemantics.Core.List.Forall₂ (fun f k => keyOfForm f = some k) fs ks →
      LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) ks FTs →
      LangSemantics.Core.List.Forall₂ FareTypeFacts (fs.map (mkFlight p)) FTs
  | [], [], [], .nil, .nil => .nil
  | _ :: _, _ :: _, _ :: _, .cons hk hks, .cons hF hFs => .cons (ftFacts hfq hk hF) (ft_forall hfq hks hFs)

/-- `toFlightList` は、選択フライト情報ごとのフライト情報を作る。 -/
theorem toFlightList_ok (p : Providers) {fs : List SourceModel.App.B0.SelectFlightForm}
    {ss : List Spec.Ticket.SelectFlight} (hsel : fs.mapM selectOfForm = some ss)
    (hnames : ∀ s ∈ ss, Spec.Prim.Text.hasText s.flightName.val = true) :
    SourceModel.App.B0.TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p) fs =
      .ok (fs.map fun f => some (mkFlight p f)) := by
  apply LangSemantics.Java.ResultLemmas.mapM_ok
  intro f hf
  obtain ⟨s, hs, hfs⟩ := LangSemantics.Core.MapM.mapM_some_mem hsel hf
  exact toFlight_ok p (selectOfForm_key hfs) (hnames s hs)

section
open Spec.Model Spec.Prim Spec.Prim.Text SourceModel.Domain.Common.Masterdata
variable {P : St → Prop} {fd : FlightDb} {cfg : Spec.Config} {md : Spec.MasterData} {p : Providers}
  {w : Spec.Port.World}
  (hP : Stable P fd) (h3 : md.MD3)
  (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
    some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
  (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
    some (.fareType ((md.fareTypeOf cd).map (·.info))))
  (hmn : ∀ name : FlightName, hasText name.val = true → md.flightMasterOf name = none →
    FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok none)
  (hmc : ∀ name : FlightName, hasText name.val = true →
    ∀ X, md.flightMasterOf name = some X → ∀ rt, md.routes.find? (fun r => r.routeNo == X.routeNo) = some rt →
    ∃ fm r da aa dt art, FlightMasterProvider.getFlightMaster p.flightMaster name.val = .ok (some fm) ∧
      fm.flightName = some name.val ∧ fm.departureTime = some dt ∧ hmOfStr dt = some X.departureTime ∧
      fm.arrivalTime = some art ∧ arrOfStr art = some X.arrivalTime ∧ fm.route = some r ∧
      r.departureAirport = some da ∧ da.code = some rt.depAirportCd.val ∧ r.arrivalAirport = some aa ∧
      aa.code = some rt.arrAirportCd.val)
  (hw : worldOfDb fd = some w) (href : w.RefMaster md)
include hP h3 hbq hfq hmn hmc hw href

/-- 選択フライトの検証（1 便・往復）。往復は D-031 の前提。 -/
theorem vf_all {ri : Int.J32} (hri : ri.val = (cfg.reserveIntervalTime : Int))
    {fs : List SourceModel.App.B0.SelectFlightForm} {ss : List Spec.Ticket.SelectFlight}
    (hsel : fs.mapM selectOfForm = some ss) (hnames : ∀ s ∈ ss, hasText s.flightName.val = true)
    (h31 : ∀ o h, ss = [o, h] → ∀ m, md.flightMasterOf o.flightName = some m → m.arrivalTime.toMinutes < 1440)
    {v : Except Spec.Error.AtrsError Unit}
    (hv : Spec.Ticket.validateFlightList cfg md w (ss.map (Spec.Ticket.resolve md)) = some v) :
    ∃ fl0 fls, fs.map (mkFlight p) = fl0 :: fls ∧
      Hoare P (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList ri
        (some ((fl0 :: fls).map some))) (Post P v) (PostE P v) := by
  have hks := forms_keys hsel
  rcases ss with _ | ⟨s0, _ | ⟨s1, _ | ⟨s2, ss⟩⟩⟩
  · simp [Spec.Ticket.validateFlightList] at hv
  · simp only [List.map_cons, List.map_nil] at hks
    rcases hks with _ | ⟨hk0, hr⟩
    rcases hr with _ | _
    refine ⟨_, [], rfl, ?_⟩
    simp only [List.map_cons, List.map_nil, Spec.Ticket.validateFlightList, Option.some.injEq] at hv
    subst hv
    exact vf_one hP h3 hbq hfq hmn hmc hw href ri hk0 (hnames s0 (by simp))
  · simp only [List.map_cons, List.map_nil] at hks
    rcases hks with _ | ⟨hk0, _ | ⟨hk1, hr⟩⟩
    rcases hr with _ | _
    refine ⟨_, [_], rfl, ?_⟩
    rw [resolve_eq] at hv
    exact vf_two hP h3 hbq hfq hmn hmc hw href hri hk0 hk1 (hnames s0 (by simp)) (hnames s1 (by simp))
      (h31 s0 s1 rfl) hv
  · simp [Spec.Ticket.validateFlightList] at hv

end

/-- 予約確認の 1 歩: 具体機械の予約確認の 1 歩（どの許される並びでも）は、状態を変えずに出力の値で終わり、その像は、
[Spec] の予約確認の 1 歩（環境の選択と自由な選択を適当に選んだもの）の出力である。 -/
theorem confirm_run {t : FlightDb} {w : Spec.Port.World} (hw : worldOfDb t = some w) (hic : IcW t)
    {ic : SourceModel.ReserveQuery.MInput} {ia : Spec.UseCase.Reserve.MInput} (hα : aiR ic = some ia)
    (hk : ic.kind = .confirm) (hpre : ia.Pre w) (h31 : dev_D031 ia) (h1 : dev_D001R ia) (h2 : dev_D002R ia)
    (h12 : dev_D012R ia) (h27 : dev_D027R ic) {mo : Order}
    (hmo : mo.Allowed ic.input.db) :
    ∃ oc oa c, catchReserve (runOp t ic mo).1 = .ok oc ∧ (runOp t ic mo).2 = t ∧
      reserveStep w ia c = (w, oa) ∧ aoR oc = some oa := by
  obtain ⟨hcfg, hmd, -, hreq, hop⟩ := aiR_eq hα
  have hop' : ia.op = .confirm := by
    rw [hk] at hop; simp only [opOf, Option.some.injEq] at hop; exact hop.symm
  obtain ⟨hsel, hri⟩ := requestOf_eq hreq
  obtain ⟨hcv, hmv, hrv, href, hmref, hx⟩ := hpre
  rw [hop'] at hx
  obtain ⟨x, hx⟩ := Option.isSome_iff_exists.mp hx
  obtain ⟨v, hv, hcases⟩ := confirmOp_cases hx
  obtain ⟨p, hl, hbq, hfq, hmn, hmc⟩ := Abstraction.Reserve.Providers.load_res hmd hmv hmo
  have hrun : runOp t ic mo = ((runOn (confirmBody p ic.input) t ic.input.env).1.map SourceModel.ReserveQuery.MOutputValue.confirmed,
      (runOn (confirmBody p ic.input) t ic.input.env).2) := by
    simp only [runOp, hk, runConfirm, hl]
  let P : St → Prop := fun s => s.db = t ∧ s.env = ic.input.env
  have hP : Stable P t := ⟨fun _ h => h.1, fun _ h => h⟩
  have he : MemberEnv t ic.input.db w := ⟨hw, hic w hw, ia.md, hmd, hmv.md1, hmref⟩
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
  rcases hcases with ⟨e, rfl, rfl⟩ | ⟨rfl, d, vr, hd, hvr, hres⟩
  · -- 前段の失敗
    have hH := confirm_core (vr := .ok ()) (T := Int.J32.ofInt 0) htf hvf hreq' (fun h => by cases h)
    have hr := Hoare.run hH hs0
    revert hr
    cases (confirmBody p ic.input).run { db := t, env := ic.input.env } with
    | ok o s => intro h; cases h.2.1
    | error e' s =>
      rintro ⟨⟨hsd, hse⟩, hE⟩
      rcases hE with hf | ⟨⟨msg, rfl⟩, str, hstr⟩ | ⟨hv0, -⟩
      · refine ⟨.error .ioFailure, _, ((.none, .failure {}), .std), ?_, hsd, step_io w ia _, rfl⟩
        exact catch_ioFault hf
      · simp only [Except.mapError, Except.error.injEq] at hstr
        refine ⟨.error .badRequest, _, ((.none, .none), ⟨some ""⟩), catch_badRequest msg, hsd, step_confirm hop' hx _, ?_⟩
        simp only [Except.map, hstr, withDetail, Option.getD_some]
        rfl
      · cases hv0
  · -- 前段の成功
    have hok := validateFlightList_ok hv
    obtain ⟨hl1, hl2⟩ := validateFlightList_len hv
    rw [List.length_map] at hl1 hl2
    have hex : ∀ k ∈ ia.req.selects.map (·.key), ∃ FT, ia.md.fareTypeOf k.fareTypeCd = some FT := by
      intro k hk'
      simp only [List.mem_map] at hk'
      obtain ⟨s, hs, rfl⟩ := hk'
      exact fareTypeOf_of_exists href (hok _ (List.mem_map_of_mem hs))
    obtain ⟨FTs, hkf⟩ := exists_forall₂ hex
    have hFT : LangSemantics.Core.List.Forall₂ FareTypeFacts (fl0 :: fls) FTs :=
      hfl ▸ ft_forall hfq (forms_keys hsel) hkf
    have hlen : ia.req.form.passengers.length ≤ 6 := hrv.2.2.2.2.2.2.2.1
    have hft : ∀ FT ∈ ia.md.fareTypes, NoNL FT.fareTypeName := fareTypeNames_noNL hmd h27.2
    have hdf : d.flights = ia.req.selects.map (·.key) := (reservation_facts hri hd []).2.2.2.2.2.2.2.2
    have hkf' : LangSemantics.Core.List.Forall₂ (fun k FT => ia.md.fareTypeOf k.fareTypeCd = some FT) d.flights FTs :=
      hdf ▸ hkf
    let T : Int.J32 := Int.J32.ofInt ((Spec.Fare.totalFareOfKeys ia.cfg ia.md (tfOf ia).flights (tfOf ia).ages).getD 0)
    have hcalc : ∀ vr', validateReservation ia.cfg ia.md w d = some vr' → vr' = .ok () →
        SourceModel.Domain.Service.B2.TicketReserveServiceImpl.calculateTotalFare
          (helperOf p ic.input).ticketReserveService (some ((fl0 :: fls).map some))
          (some (((ic.input.form.passengerFormList.filter (!·.isEmpty)).map B2Mapper.mapPassenger).map some)) =
          .ok T := by
      intro vr' hvr' hok'
      rw [hvr] at hvr'
      cases hvr'
      subst hok'
      rcases hres with ⟨e, he, -⟩ | ⟨-, n, hn, -⟩
      · cases he
      obtain ⟨hA, hPre, -⟩ := tf_facts hcfg hmd hsel hri hcv hmv hrv hl1 hl2 hd hn
      exact Abstraction.Reserve.TotalFare.calc_eq hA hPre h1 h2 h12 hmo hl htf ic.input.db
    obtain ⟨vr', hvr', hH'⟩ := helperConfirm_hoare hP he hminT hri hlen hd hFT hkf hcalc
    rw [hvr] at hvr'
    cases hvr'
    have hH := confirm_core (vr := vr) (T := T) htf hvf hreq' (fun _ => hH')
    have hr := Hoare.run hH hs0
    revert hr
    cases (confirmBody p ic.input).run { db := t, env := ic.input.env } with
    | ok o s =>
      rintro ⟨⟨hsd, hse⟩, -, hvr0, hT⟩
      rcases hres with ⟨e, he, -⟩ | ⟨-, n, hn, rfl⟩
      · rw [hvr0] at he; cases he
      obtain ⟨-, hPre, hages⟩ := tf_facts hcfg hmd hsel hri hcv hmv hrv hl1 hl2 hd hn
      have hle : (Spec.Fare.totalFareOfKeys ia.cfg ia.md (tfOf ia).flights (tfOf ia).ages).getD 0 ≤ 1200000000 :=
        totalFareOfKeys_le hPre
      have hTn : (Spec.Fare.totalFareOfKeys ia.cfg ia.md (tfOf ia).flights (tfOf ia).ages).getD 0 = n := by
        rw [hages]
        simp only [tfOf] at hn ⊢
        rw [hn]
        rfl
      rw [hTn] at hle
      refine ⟨.ok (.confirmed o), _, ((.none, .none), .std), rfl, hsd, step_confirm hop' hx _, ?_⟩
      have hv' : natOfJ32 o.totalFare = some n := by
        rw [hT, natOfJ32_eq_some]
        simp only [T, hTn]
        exact LangSemantics.Java.IntLemmas.ofInt_nat (by omega)
      simp only [aoR, hv', Option.map_some, Except.map, withDetail]
    | error e' s =>
      rintro ⟨⟨hsd, hse⟩, hE⟩
      rcases hE with hf | ⟨-, str, hstr⟩ | ⟨-, c, args, rfl, hc⟩
      · refine ⟨.error .ioFailure, _, ((.none, .failure {}), .std), ?_, hsd, step_io w ia _, rfl⟩
        exact catch_ioFault hf
      · simp [Except.mapError] at hstr
      · rcases hres with ⟨e, he, rfl⟩ | ⟨hvr0, -⟩
        · rw [hc] at he
          cases he
          have hnl := validate_nl hkf' hft hvr c args hc
          exact ⟨.error (.business c args), _, ((.none, .none), .std), catch_business hnl.1 hnl.2, hsd,
            step_confirm hop' hx _, rfl⟩
        · rw [hc] at hvr0; cases hvr0

end Abstraction.Reserve.ConfirmRun
