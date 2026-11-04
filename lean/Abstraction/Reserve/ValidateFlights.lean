import Abstraction.Reserve.Select
import Abstraction.Reserve.Tx

/-!
# Abstraction.Reserve.ValidateFlights

ABS-041 の補題: 選択フライトの検証（`TicketSharedServiceImpl.validateFlightList`）の Hoare 三つ組と、[Spec] の
`Spec.Reserve.FlightSelection.validateFlightList` の対応（backlog aedf の第 3 段）。

文は存在の確認（`exists`）だけで、状態の表を変えない。事後条件は次のとおりである。

- 正常に終われば、[Spec] の結果は成功（`.ok`。予約する便の主キー）。
- 例外で終われば、不正要求に包まれる例外（`BadReq`）で [Spec] の結果がエラーか、実行環境の障害（`IsFault`）。
-/

namespace Abstraction.Reserve.ValidateFlights
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.Flights
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.Domain.Service.B0
open SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository

/-- 文の実行の計数で変わらない事前条件（状態の表 `fd` を含む）。 -/
structure Stable (P : St → Prop) (fd : FlightDb) : Prop where
  db : ∀ s, P s → s.db = fd
  tick : ∀ s, P s → P (tick s)

/-- 選択フライトの検証の事後条件（[Spec] の結果は成功）。 -/
def Post {α : Type} (P : St → Prop) (v : Except Spec.Error.AtrsError α) : Unit → St → Prop :=
  fun _ s => P s ∧ ∃ a, v = .ok a

/-- 選択フライトの検証の例外の事後条件。 -/
def PostE {α : Type} (P : St → Prop) (v : Except Spec.Error.AtrsError α) : JThrow → St → Prop :=
  fun e s => P s ∧ ((BadReq e ∧ ∃ e', v = .error e') ∨ IsIoFault s.env e)

theorem badReq_invalid (msg : String) : BadReq (InvalidFlightException.new msg) := ⟨_, msg, rfl, .inl rfl⟩

theorem agreeV_post {P : St → Prop} {r : JResult Unit} {v : Except Spec.Error.AtrsError Unit} (h : AgreeV r v)
    {s : St} (hs : P s) :
    match (match r with | .ok a => pure a | .error e => throw e : DbM Unit) s with
    | .ok a s' => Post P v a s' | .error e s' => PostE P v e s' := by
  rcases h with ⟨rfl, rfl⟩ | ⟨cls, msg, rfl, hc, e, rfl⟩
  · exact ⟨hs, (), rfl⟩
  · exact ⟨hs, .inl ⟨⟨cls, msg, rfl, hc⟩, e, rfl⟩⟩

/-- 1 便: 便マスタがあり、存在の確認の結果が `World.existsFlight`、存在すれば運賃種別の検査が対応する。 -/
theorem one_some {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {w : Spec.World} (ri : Int.J32)
    {cfg : Spec.Env.Config} {md : Spec.Env.MasterData}
    {f0 : SourceModel.Domain.Model.Flight} {fm : SourceModel.Domain.Model.FlightMaster} (hfm : f0.flightMaster = some fm)
    {k0 : Spec.Model.FlightKey} {X : Spec.Env.MasterData.FlightMaster}
    (he : existsRows fd (bindKey f0.departureDate fm.flightName f0.boardingClass f0.fareType) = w.existsFlight k0)
    (hft : w.existsFlight k0 = true →
      AgreeV (TicketSharedServiceImpl.validateFlightFareType [some f0]) (Spec.Reserve.FlightSelection.checkFareTypes [k0]))
    {v : Except Spec.Error.AtrsError (Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey)}
    (hv : Spec.Reserve.FlightSelection.validateFlightList cfg md w [some ⟨k0, X⟩] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some f0])) (Post P v) (PostE P v) := by
  intro s hs
  have hdb := hP.db s hs
  have ht := hP.tick s hs
  java_estate_simp [TicketSharedServiceImpl.validateFlightList, TicketSharedServiceImpl.existsFlight,
    FlightRepository.exists, lift, query, hfm]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨ht, .inr ⟨_, rfl, by simp [h1]⟩⟩
  have hx : existsRows s.db (bindKey f0.departureDate fm.flightName f0.boardingClass f0.fareType) =
      w.existsFlight k0 := hdb ▸ he
  simp only [h1, ite_false, hx]
  cases hw : w.existsFlight k0
  · simp only [Bool.not_false, ite_true]
    refine ⟨ht, .inl ⟨badReq_invalid _, .invalidRequest "flight not found", ?_⟩⟩
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw, Bool.false_eq_true, ite_false,
      Option.some.injEq] at hv
    exact hv.symm
  · simp only [Bool.not_true, Bool.false_eq_true, ite_false]
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw, ite_true, Option.some.injEq] at hv
    rcases hft hw with ⟨hr, hc⟩ | ⟨cls, msg, hr, hcl, e, hc⟩
    · rw [hr]
      refine ⟨ht, .oneWay k0, ?_⟩
      rw [← hv]; simp only [Bind.bind, Except.bind, hc]; rfl
    · rw [hr]
      refine ⟨ht, .inl ⟨⟨cls, msg, rfl, hcl⟩, e, ?_⟩⟩
      rw [← hv]; simp only [Bind.bind, Except.bind, hc]

/-- 1 便: 便マスタが無い。 -/
theorem one_none {P : St → Prop} {fd : FlightDb} (_hP : Stable P fd) {w : Spec.World} (ri : Int.J32)
    {cfg : Spec.Env.Config} {md : Spec.Env.MasterData}
    {f0 : SourceModel.Domain.Model.Flight} (hfm : f0.flightMaster = none)
    {v : Except Spec.Error.AtrsError (Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey)}
    (hv : Spec.Reserve.FlightSelection.validateFlightList cfg md w [none] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some f0])) (Post P v) (PostE P v) := by
  intro s hs
  java_estate_simp [TicketSharedServiceImpl.validateFlightList, lift, hfm]
  simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, Option.some.injEq] at hv
  exact ⟨hs, .inl ⟨badReq_invalid _, .invalidRequest "flightMaster is null", hv.symm⟩⟩

/-- 往復: 往路・復路とも便マスタがあり、存在の確認の結果が `World.existsFlight`、存在すれば搭乗間隔・逆区間・運賃種別の
検査が対応する。 -/
theorem two_some {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {w : Spec.World} (ri : Int.J32)
    {cfg : Spec.Env.Config} {md : Spec.Env.MasterData}
    {f0 f1 : SourceModel.Domain.Model.Flight} {fm0 fm1 : SourceModel.Domain.Model.FlightMaster}
    (hfm0 : f0.flightMaster = some fm0) (hfm1 : f1.flightMaster = some fm1)
    {k0 k1 : Spec.Model.FlightKey} {X0 X1 : Spec.Env.MasterData.FlightMaster}
    (he0 : existsRows fd (bindKey f0.departureDate fm0.flightName f0.boardingClass f0.fareType) = w.existsFlight k0)
    (he1 : existsRows fd (bindKey f1.departureDate fm1.flightName f1.boardingClass f1.fareType) = w.existsFlight k1)
    (hiv : w.existsFlight k0 = true → w.existsFlight k1 = true →
      AgreeV (TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight ri f0 f1)
        (Spec.Reserve.FlightSelection.checkInterval cfg k0 X0 k1 X1))
    {rv : Except Spec.Error.AtrsError Unit} (hrv : Spec.Reserve.FlightSelection.checkReverse md X0 X1 = some rv)
    (hrt : AgreeV (TicketSharedServiceImpl.validateFlightRouteForRoundTripFlight f0 f1) rv)
    (hft : w.existsFlight k0 = true → w.existsFlight k1 = true →
      AgreeV (TicketSharedServiceImpl.validateFlightFareType [some f0, some f1]) (Spec.Reserve.FlightSelection.checkFareTypes [k0, k1]))
    {v : Except Spec.Error.AtrsError (Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey)}
    (hv : Spec.Reserve.FlightSelection.validateFlightList cfg md w [some ⟨k0, X0⟩, some ⟨k1, X1⟩] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some f0, some f1])) (Post P v) (PostE P v) := by
  intro s hs
  have hdb := hP.db s hs
  have ht := hP.tick s hs
  have htt := hP.tick _ ht
  have hdb' := hP.db _ ht
  have hx0 : existsRows s.db (bindKey f0.departureDate fm0.flightName f0.boardingClass f0.fareType) =
      w.existsFlight k0 := hdb ▸ he0
  java_estate_simp [TicketSharedServiceImpl.validateFlightList, TicketSharedServiceImpl.existsFlight,
    FlightRepository.exists, lift, query, hfm0, hfm1]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨ht, .inr ⟨_, rfl, by simp [h1]⟩⟩
  simp only [h1, ite_false, hx0]
  cases hw0 : w.existsFlight k0
  · simp only [Bool.not_false, ite_true]
    refine ⟨ht, .inl ⟨badReq_invalid _, .invalidRequest "flight not found", ?_⟩⟩
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw0, Bool.false_eq_true, ite_false,
      Option.some.injEq] at hv
    exact hv.symm
  simp only [Bool.not_true, Bool.false_eq_true, ite_false]
  have hx1 : existsRows (tick s).db (bindKey f1.departureDate fm1.flightName f1.boardingClass f1.fareType) =
      w.existsFlight k1 := hdb' ▸ he1
  simp only [tick] at hx1 htt
  by_cases h3 : s.env.ioFailAt = some (s.sqlCalls + 1)
  · simp only [h3, ite_true]
    exact ⟨htt, .inr ⟨_, rfl, by simp [h3]⟩⟩
  simp only [h3, ite_false, hx1]
  cases hw1 : w.existsFlight k1
  · simp only [Bool.not_false, ite_true]
    refine ⟨htt, .inl ⟨badReq_invalid _, .invalidRequest "flight not found", ?_⟩⟩
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw0, hw1, Bool.false_eq_true, ite_false,
      ite_true, Option.some.injEq] at hv
    exact hv.symm
  simp only [Bool.not_true, Bool.false_eq_true, ite_false]
  simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw0, hw1, ite_true] at hv
  rcases hiv hw0 hw1 with ⟨hi, hc⟩ | ⟨cls, msg, hi, hcl, e, hc⟩
  · simp only [hi, hc, hrv, Option.bind_eq_bind, Option.bind_some, Option.pure_def, Option.some.injEq] at hv ⊢
    subst hv
    rcases hrt with ⟨hr, hc'⟩ | ⟨cls', msg', hr, hcl', e', hc'⟩
    · simp only [hr, hc', Except.bind]
      rcases hft hw0 hw1 with ⟨hf, hc''⟩ | ⟨cls'', msg'', hf, hcl'', e'', hc''⟩
      · simp only [hf, hc'']; exact ⟨htt, _, rfl⟩
      · simp only [hf, hc'']; exact ⟨htt, .inl ⟨⟨cls'', msg'', rfl, hcl''⟩, e'', rfl⟩⟩
    · simp only [hr, hc', Except.bind]; exact ⟨htt, .inl ⟨⟨cls', msg', rfl, hcl'⟩, e', rfl⟩⟩
  · simp only [hi, hc, Option.some.injEq] at hv ⊢
    subst hv
    exact ⟨htt, .inl ⟨⟨cls, msg, rfl, hcl⟩, e, rfl⟩⟩

/-- 往復: 往路の便マスタが無い。 -/
theorem two_none0 {P : St → Prop} {fd : FlightDb} (_hP : Stable P fd) {w : Spec.World} (ri : Int.J32)
    {cfg : Spec.Env.Config} {md : Spec.Env.MasterData} {f0 f1 : SourceModel.Domain.Model.Flight}
    (hfm0 : f0.flightMaster = none) {M1 : Option Spec.Reserve.FlightSelection.ResolvedFlight}
    {v : Except Spec.Error.AtrsError (Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey)}
    (hv : Spec.Reserve.FlightSelection.validateFlightList cfg md w [none, M1] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some f0, some f1])) (Post P v) (PostE P v) := by
  intro s hs
  java_estate_simp [TicketSharedServiceImpl.validateFlightList, lift, hfm0]
  simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, Option.some.injEq] at hv
  exact ⟨hs, .inl ⟨badReq_invalid _, .invalidRequest "flightMaster is null", hv.symm⟩⟩

/-- 往復: 往路の便マスタがあり、復路の便マスタが無い。 -/
theorem two_none1 {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {w : Spec.World} (ri : Int.J32)
    {cfg : Spec.Env.Config} {md : Spec.Env.MasterData} {f0 f1 : SourceModel.Domain.Model.Flight}
    {fm0 : SourceModel.Domain.Model.FlightMaster} (hfm0 : f0.flightMaster = some fm0) (hfm1 : f1.flightMaster = none)
    {k0 : Spec.Model.FlightKey} {X0 : Spec.Env.MasterData.FlightMaster}
    (he0 : existsRows fd (bindKey f0.departureDate fm0.flightName f0.boardingClass f0.fareType) = w.existsFlight k0)
    {v : Except Spec.Error.AtrsError (Spec.Reserve.FlightSelection.Itinerary Spec.Model.FlightKey)}
    (hv : Spec.Reserve.FlightSelection.validateFlightList cfg md w [some ⟨k0, X0⟩, none] = some v) :
    Hoare P (TicketSharedServiceImpl.validateFlightList ri (some [some f0, some f1])) (Post P v) (PostE P v) := by
  intro s hs
  have hdb := hP.db s hs
  have ht := hP.tick s hs
  have hx0 : existsRows s.db (bindKey f0.departureDate fm0.flightName f0.boardingClass f0.fareType) =
      w.existsFlight k0 := hdb ▸ he0
  java_estate_simp [TicketSharedServiceImpl.validateFlightList, TicketSharedServiceImpl.existsFlight,
    FlightRepository.exists, lift, query, hfm0, hfm1]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨ht, .inr ⟨_, rfl, by simp [h1]⟩⟩
  simp only [h1, ite_false, hx0]
  cases hw0 : w.existsFlight k0
  · simp only [Bool.not_false, ite_true]
    refine ⟨ht, .inl ⟨badReq_invalid _, .invalidRequest "flight not found", ?_⟩⟩
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw0, Bool.false_eq_true, ite_false,
      Option.some.injEq] at hv
    exact hv.symm
  · simp only [Bool.not_true, Bool.false_eq_true, ite_false]
    refine ⟨ht, .inl ⟨badReq_invalid _, .invalidRequest "flightMaster is null", ?_⟩⟩
    simp only [Spec.Reserve.FlightSelection.validateFlightList, Spec.Reserve.FlightSelection.checkFlight, hw0, ite_true, Option.some.injEq] at hv
    exact hv.symm

end Abstraction.Reserve.ValidateFlights
