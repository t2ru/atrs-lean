import Abstraction.Reserve.Alpha

/-!
# Abstraction.Reserve.Input

ABS-041 の補題: 予約の入力の α `aiR` の像の分解（backlog aedf の第 3 段）。
-/

namespace Abstraction.Reserve.Input
open Abstraction.Reserve.Alpha Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Abstraction.Fare.TotalAlpha
open Spec.UseCase.Reserve

theorem aiR_eq {ic : SourceModel.ReserveQuery.MInput} {ia : MInput} (h : aiR ic = some ia) :
    configOf ic.input.config = some ia.cfg ∧ masterDataOf ic.input.db = some ia.md ∧
      dateOfJ (ic.input.env.clock 0) = some ia.today ∧ requestOf ic.input.form = some ia.req ∧
      opOf ic.kind = some ia.op := by
  simp only [aiR, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨cfg, h1, md, h2, today, h3, req, h4, op, h5, rfl⟩ := h
  exact ⟨h1, h2, h3, h4, h5⟩

theorem requestOf_eq {f : SourceModel.App.B2.TicketReserveForm} {req : Request} (h : requestOf f = some req) :
    f.selectFlightFormList.mapM selectOfForm = some req.selects ∧ reserveInputOf f = some req.form := by
  simp only [requestOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨ss, h1, r, h2, rfl⟩ := h
  exact ⟨h1, h2⟩

theorem selectOfForm_key {f : SourceModel.App.B0.SelectFlightForm} {s : Spec.Ticket.SelectFlight}
    (h : selectOfForm f = some s) : keyOfForm f = some s.key := by
  simp only [selectOfForm, Option.map_eq_some_iff] at h
  obtain ⟨k, hk, rfl⟩ := h
  exact hk

theorem selects_keys : ∀ {fs : List SourceModel.App.B0.SelectFlightForm} {ss : List Spec.Ticket.SelectFlight},
    fs.mapM selectOfForm = some ss → fs.mapM keyOfForm = some (ss.map (·.key))
  | [], ss, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | f :: fs, ss, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨s, hs, ss', hss, rfl⟩ := h
    simp only [List.mapM_cons, selectOfForm_key hs, selects_keys hss, Option.bind_eq_bind, Option.bind_some,
      Option.pure_def, List.map_cons]

theorem resolve_eq (md : Spec.MasterData) (ss : List Spec.Ticket.SelectFlight) :
    ss.map (Spec.Ticket.resolve md) = (ss.map (·.key)).map fun k => ⟨k, md.flightMasterOf k.flightName⟩ := by
  simp only [List.map_map]
  rfl

end Abstraction.Reserve.Input
