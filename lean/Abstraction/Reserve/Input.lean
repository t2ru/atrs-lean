import Abstraction.Reserve.Alpha
import Abstraction.Reserve.SpecFacts

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

theorem selectOfForm_eq {f : SourceModel.App.B0.SelectFlightForm} {s : Spec.Ticket.SelectFlight}
    (h : selectOfForm f = some s) :
    ∃ dj, f.depDate = some dj ∧ dateOfJ dj = some s.depDate ∧ f.flightName = some s.flightName ∧
      f.boardingClassCd = some s.boardingClassCd ∧ f.fareTypeCd = some s.fareTypeCd := by
  simp only [selectOfForm, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
  obtain ⟨d, ⟨dj, hdj, hd⟩, n, hn, bc, hbc, ft, hft, rfl⟩ := h
  exact ⟨dj, hdj, hd, hn, hbc, hft⟩

/-- 便マスタで解決できる選択フライト情報の主キーの α は、解決した選択フライトの主キー。 -/
theorem keyOfForm_of_resolve {md : Spec.MasterData} {f : SourceModel.App.B0.SelectFlightForm}
    {s : Spec.Ticket.SelectFlight} {r : Spec.Ticket.ResolvedFlight} (hs : selectOfForm f = some s)
    (hr : Spec.Ticket.resolve md s = some r) : keyOfForm f = some r.key := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := selectOfForm_eq hs
  obtain ⟨-, hk, hv⟩ := Abstraction.Reserve.SpecFacts.resolve_key hr
  rw [hk]
  simp only [keyOfForm, hdj, hd, hn, hbc, hft, Option.bind_some, Option.map_some, ← hv, flightNameOf_val]

/-- 選択フライト情報の列の α が選択フライトの列で、選択フライトがそれぞれ主キーに解決されれば、選択フライト情報の
主キーの α は、その主キー。 -/
theorem forms_keys {md : Spec.MasterData} {Q : Spec.Model.FlightKey → Prop} :
    ∀ {fs : List SourceModel.App.B0.SelectFlightForm} {ss : List Spec.Ticket.SelectFlight}
      {ks : List Spec.Model.FlightKey}, fs.mapM selectOfForm = some ss →
      LangSemantics.Core.List.Forall₂ (fun s k => ∃ r, Spec.Ticket.resolve md s = some r ∧ r.key = k ∧ Q k) ss ks →
      LangSemantics.Core.List.Forall₂ (fun f k => keyOfForm f = some k) fs ks
  | [], ss, ks, h, hks => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; cases hks; exact .nil
  | f :: fs, ss, ks, h, hks => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨s, hs, ss', hss, rfl⟩ := h
    rcases hks with _ | ⟨⟨r, hr, rfl, -⟩, hks⟩
    exact .cons (keyOfForm_of_resolve hs hr) (forms_keys hss hks)

theorem forall₂_of_mapM {α β : Type} {g : α → Option β} :
    ∀ {as : List α} {bs : List β}, as.mapM g = some bs →
      LangSemantics.Core.List.Forall₂ (fun a b => g a = some b) as bs
  | [], bs, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .nil
  | a :: as, bs, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨b, hb, bs', hbs, rfl⟩ := h
    exact .cons hb (forall₂_of_mapM hbs)

theorem mapM_of_forall₂ {α β : Type} {g : α → Option β} :
    ∀ {as : List α} {bs : List β}, LangSemantics.Core.List.Forall₂ (fun a b => g a = some b) as bs →
      as.mapM g = some bs
  | [], [], .nil => rfl
  | _ :: _, _ :: _, .cons h hs => by
    simp only [List.mapM_cons, h, mapM_of_forall₂ hs, Option.bind_eq_bind, Option.bind_some, Option.pure_def]

/-- 選択フライトがそれぞれ主キーに解決されれば、解決した主キーの列（`selectKeys`）は、その主キーの列。 -/
theorem selectKeys_eq {md : Spec.MasterData} {Q : Spec.Model.FlightKey → Prop} :
    ∀ {ss : List Spec.Ticket.SelectFlight} {ks : List Spec.Model.FlightKey},
      LangSemantics.Core.List.Forall₂ (fun s k => ∃ r, Spec.Ticket.resolve md s = some r ∧ r.key = k ∧ Q k) ss ks →
      selectKeys md ss = ks
  | [], [], .nil => rfl
  | _ :: _, _ :: _, .cons h hs => by
    obtain ⟨r, hr, rfl, -⟩ := h
    have ih := selectKeys_eq hs
    simp only [selectKeys, List.filterMap_cons, hr, Option.map_some] at ih ⊢
    rw [ih]

end Abstraction.Reserve.Input
