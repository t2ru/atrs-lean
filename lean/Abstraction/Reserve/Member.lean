import Abstraction.World.Alpha
import Abstraction.FlightSearch.Join
import SourceModel.Domain.Repository.Member.MemberRepository
import SourceModel.Domain.Service.B2.TicketReserveServiceImpl

/-!
# Abstraction.Reserve.Member

L 課題 ABS-023 の補題: `MemberRepository.findOne` の文の結果を、α `worldOfDb` の像の `World.findMember` で表す
（backlog aedf の第 3 段）。会員番号の一意性（具体側の不変条件 `IcW`）と、カード種別の一意性（MD-1）・参照整合性
（`World.MemberRefMaster`）の下で、文の結果は高々 1 行で、その行の α は `findMember` の会員である。
-/

namespace Abstraction.Reserve.Member
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.World.Alpha Spec.Model
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.QueryLemmas LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Domain.Repository.Member SourceModel.Domain.Repository.Member.MemberRepository

/-! ## 会員の表の組 -/

theorem membersOf_numbers : ∀ {ms : List MemberRow} {ls : List MemberLoginRow} {xs : List Member},
    membersOf ms ls = some xs →
      ms.map (·.customerNo.val) = xs.map (·.membershipNumber.val) ∧ ls.map (·.customerNo.val) = ms.map (·.customerNo.val)
  | [], [], xs, h => by simp only [membersOf, Option.some.injEq] at h; subst h; exact ⟨rfl, rfl⟩
  | m :: ms, l :: ls, xs, h => by
    simp only [membersOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
    obtain ⟨x, hx, ys, hys, rfl⟩ := h
    obtain ⟨ih1, ih2⟩ := membersOf_numbers hys
    unfold memberOfRow at hx
    split at hx
    · rename_i hc
      simp only [Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hx
      obtain ⟨_, _, _, _, _, _, _, _, _, hmn, rfl⟩ := hx
      have := membershipNumberOf_eq_some hmn
      refine ⟨?_, ?_⟩ <;> simp [ih1, ih2, hc, this]
    · cases hx
  | [], _ :: _, _, h => by simp [membersOf] at h
  | _ :: _, [], _, h => by simp [membersOf] at h

/-- 会員番号で引いた会員の行と、同じ位置のログインの行と、`findMember` の会員。 -/
theorem membersOf_find : ∀ {ms : List MemberRow} {ls : List MemberLoginRow} {xs : List Member},
    membersOf ms ls = some xs → ∀ s : String,
      match xs.find? (·.membershipNumber.val == s) with
      | none => ms.find? (·.customerNo.val == s) = none
      | some x => ∃ m l, ms.find? (·.customerNo.val == s) = some m ∧ ls.find? (·.customerNo.val == s) = some l ∧
          memberOfRow m l = some x
  | [], [], xs, h, s => by simp only [membersOf, Option.some.injEq] at h; subst h; rfl
  | m :: ms, l :: ls, xs, h, s => by
    simp only [membersOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
    obtain ⟨x, hx, ys, hys, rfl⟩ := h
    have ih := membersOf_find hys s
    have hx' := hx
    unfold memberOfRow at hx'
    split at hx'
    · rename_i hc
      simp only [Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hx'
      obtain ⟨_, _, _, _, _, _, _, _, mn, hmn, rfl⟩ := hx'
      have hmn' := membershipNumberOf_eq_some hmn
      by_cases hs : m.customerNo.val = s
      · simp [hs, ← hc, hx, hmn']
      · have hs' : ¬ l.customerNo.val = s := by rw [← hc]; exact hs
        have e1 : (mn.val == s) = false := by simp [hmn', hs]
        have e2 : (m.customerNo.val == s) = false := by simp [hs]
        have e3 : (l.customerNo.val == s) = false := by simp [hs']
        simp only [List.find?_cons, e1, e2, e3]
        exact ih
    · cases hx'
  | [], _ :: _, _, h, _ => by simp [membersOf] at h
  | _ :: _, [], _, h, _ => by simp [membersOf] at h

/-! ## `findOne` の文 -/

open Abstraction.FlightSearch.Join in
/-- `findOne` の文の結果: 会員番号・会員とログインの会員番号・カード種別のコードがそれぞれ一意なら、会員番号の行と、
同じ会員番号のログインの行と、同じコードのカード種別の行の組（高々 1 つ）。 -/
theorem findOneRows_eq (mdb : MasterDb) (fd : FlightDb) (s : String)
    (hm : (fd.member.map (·.customerNo.val)).Nodup) (hl : (fd.memberLogin.map (·.customerNo.val)).Nodup)
    (hc : (mdb.creditType.map (·.creditTypeCd.val)).Nodup) :
    findOneRows mdb fd (.text s) =
      ((fd.member.find? (·.customerNo.val == s)).bind fun m =>
        (fd.memberLogin.find? (·.customerNo.val == m.customerNo.val)).bind fun l =>
          (mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val)).map fun c => ⟨m, l, c⟩).toList := by
  let cond : (MemberRow × MemberLoginRow) × CreditTypeRow → Bool := fun t =>
    t.1.1.customerNo.val == s && t.1.1.customerNo.val == t.1.2.customerNo.val &&
      t.1.1.creditTypeCd.val == t.2.creditTypeCd.val
  have hcond : ∀ t : (MemberRow × MemberLoginRow) × CreditTypeRow,
      (((SqlValue.eq collationC t.1.1.customerNo.toSql (.text s)).and (eqText t.1.1.customerNo t.1.2.customerNo)).and
        (eqText t.1.1.creditTypeCd t.2.creditTypeCd)).holds = cond t := by
    intro t
    simp only [Truth.holds_and, Varchar.toSql, collationC, SqlValue.eq_text_holds, eqText, cond]
  unfold findOneRows Bag.project Bag.select
  simp only [hcond]
  rw [map_filter_eq_filterMap]
  let h : MemberRow × MemberLoginRow → CreditTypeRow → Option MemberResult := fun x c =>
    if cond (x, c) then some ⟨x.1, x.2, c⟩ else none
  change (Bag.cross (Bag.cross fd.member fd.memberLogin) mdb.creditType).filterMap (fun t => h t.1 t.2) = _
  rw [filterMap_cross _ mdb.creditType h (fun x => mdb.creditType.find? (·.creditTypeCd.val == x.1.creditTypeCd.val))
    (fun x _ => filterMap_unique mdb.creditType (·.creditTypeCd.val) x.1.creditTypeCd.val (h x) hc
      (fun c _ hne => by simp only [h, cond]; simp [Ne.symm hne]))]
  let h2 : MemberRow → MemberLoginRow → Option MemberResult := fun m l =>
    (mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val)).bind (h (m, l))
  change (Bag.cross fd.member fd.memberLogin).filterMap (fun t => h2 t.1 t.2) = _
  rw [filterMap_cross _ fd.memberLogin h2 (fun m => fd.memberLogin.find? (·.customerNo.val == m.customerNo.val))
    (fun m _ => filterMap_unique fd.memberLogin (·.customerNo.val) m.customerNo.val (h2 m) hl
      (fun l _ hne => by
        simp only [h2, h, cond]
        cases (mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val)) <;> simp [Ne.symm hne]))]
  rw [filterMap_unique fd.member (·.customerNo.val) s _ hm (fun m _ hne => by
    simp only [h2, h, cond]
    cases (fd.memberLogin.find? (·.customerNo.val == m.customerNo.val)) with
    | none => rfl
    | some l =>
      cases (mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val)) <;> simp [hne])]
  congr 1
  cases e1 : fd.member.find? (·.customerNo.val == s) with
  | none => rfl
  | some m =>
    have hs : m.customerNo.val = s := by simpa using List.find?_some e1
    simp only [Option.bind_some]
    cases e2 : fd.memberLogin.find? (·.customerNo.val == m.customerNo.val) with
    | none => rfl
    | some l =>
      have hl' : l.customerNo.val = m.customerNo.val := by simpa using List.find?_some e2
      simp only [Option.bind_some]
      cases e3 : mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val) with
      | none => simp only [h2, e3, Option.bind_none, Option.map_none]
      | some c =>
        have hc' : c.creditTypeCd.val = m.creditTypeCd.val := by simpa using List.find?_some e3
        simp [h2, e3, h, cond, hs, hl', hc']

/-! ## `World.findMember` -/

theorem mapM_map_eq {α β γ : Type} {f : α → Option β} {g : β → γ} {k : α → γ} (hk : ∀ a b, f a = some b → g b = k a) :
    ∀ {l : List α} {l' : List β}, l.mapM f = some l' → l'.map g = l.map k
  | [], l', h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | a :: l, l', h => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨b, hb, t, ht, rfl⟩ := h
    simp only [List.map_cons, hk a b hb, mapM_map_eq hk ht]

theorem nodup_map_comp {α β γ : Type} {g : β → γ} (hg : ∀ a b, g a = g b → a = b) {f : α → β} :
    ∀ {xs : List α}, (xs.map f).Nodup → (xs.map fun x => g (f x)).Nodup
  | [], _ => List.nodup_nil
  | x :: xs, h => by
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at h ⊢
    exact ⟨fun ⟨y, hy, e⟩ => h.1 ⟨y, hy, hg _ _ e⟩, nodup_map_comp hg h.2⟩

theorem nodup_map_val {α : Type} {xs : List α} {f : α → MembershipNumber} (h : (xs.map f).Nodup) :
    (xs.map fun x => (f x).val).Nodup :=
  nodup_map_comp (fun _ _ e => MembershipNumber.ext e) h

/-- `findOne` の文の結果と `World.findMember`: 会員が無ければ 0 行、あれば 1 行で、その会員とログインの行の α は
`findMember` の会員。 -/
@[obligation "ABS-023"]
theorem findOneRows_world {mdb : MasterDb} {fd : FlightDb} {w : Spec.World} {md : Spec.Env.MasterData}
    (hw : worldOfDb fd = some w) (hk : KeysOk w) (hmd : masterDataOf mdb = some md) (h1 : md.MD1)
    (href : w.MemberRefMaster md) (s : String) :
    match w.findMember s with
    | none => findOneRows mdb fd (.text s) = []
    | some x => ∃ r, findOneRows mdb fd (.text s) = [r] ∧ memberOfRow r.member r.login = some x := by
  have hms := (worldOfDb_eq_some.mp hw).2.1
  obtain ⟨en, el⟩ := membersOf_numbers hms
  have hm : (fd.member.map (·.customerNo.val)).Nodup := by rw [en]; exact nodup_map_val hk.1
  have hl : (fd.memberLogin.map (·.customerNo.val)).Nodup := by rw [el]; exact hm
  have hcts : mdb.creditType.mapM creditTypeOfRow = some md.creditTypes := by
    simp only [masterDataOf, Option.bind_eq_some_iff, Option.map_eq_some_iff] at hmd
    obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, c, hc, rfl⟩ := hmd
    exact hc
  have hcode : ∀ a b, creditTypeOfRow a = some b → b.creditTypeCd.val = a.creditTypeCd.val := by
    intro a b h
    simp only [creditTypeOfRow, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨_, hk, _, _, rfl⟩ := h
    exact CreditTypeCd.val_of_ofString? hk
  have hc : (mdb.creditType.map (·.creditTypeCd.val)).Nodup := by
    rw [← mapM_map_eq (g := fun b => b.creditTypeCd.val) hcode hcts]
    have h8 := h1.2.2.2.2.2.2.2.1
    exact nodup_map_comp (g := CreditTypeCd.val) (fun _ _ e => CreditTypeCd.ext e) h8
  rw [findOneRows_eq mdb fd s hm hl hc]
  have hf := membersOf_find hms s
  unfold Spec.World.findMember
  cases hx : w.members.find? (·.membershipNumber.val == s) with
  | none =>
    rw [hx] at hf
    simp only [hf, Option.bind_none, Option.toList_none]
  | some x =>
    rw [hx] at hf
    dsimp only at hf ⊢
    obtain ⟨m, l, e1, e2, hml⟩ := hf
    have hs : m.customerNo.val = s := by simpa using List.find?_some e1
    have hxm : x ∈ w.members := List.mem_of_find?_eq_some hx
    obtain ⟨ct, hct, hctx⟩ := href x hxm
    obtain ⟨c, hcm, hcc⟩ := LangSemantics.Core.MapM.mapM_some_mem' hcts hct
    have hxct : x.creditTypeCd.val = m.creditTypeCd.val := by
      unfold memberOfRow at hml
      split at hml
      · simp only [Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hml
        obtain ⟨_, _, _, _, _, _, _, hk, _, _, rfl⟩ := hml
        exact CreditTypeCd.val_of_ofString? hk
      · cases hml
    obtain ⟨c', e3⟩ : ∃ c', mdb.creditType.find? (·.creditTypeCd.val == m.creditTypeCd.val) = some c' := by
      apply Option.isSome_iff_exists.mp
      rw [List.find?_isSome]
      refine ⟨c, hcm, ?_⟩
      have := hcode c ct hcc
      rw [hctx, hxct] at this
      simp [← this]
    refine ⟨⟨m, l, c'⟩, ?_, hml⟩
    simp [e1, hs, e2, e3]

/-! ## `member-map` と会員の照合 -/

/-- 会員とログインの行の α が会員 `x` なら、`member-map` は例外を投げず、カナの氏名・性別は `x` のもの。 -/
theorem memberMap_ok {m : MemberRow} {l : MemberLoginRow} {x : Member} (h : memberOfRow m l = some x)
    (c : CreditTypeRow) :
    ∃ M, memberMap ⟨m, l, c⟩ = .ok M ∧ M.kanaFamilyName = some x.kanaFamilyName ∧
      M.kanaGivenName = some x.kanaGivenName ∧ M.gender = some x.gender := by
  unfold memberOfRow at h
  split at h
  · simp only [Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
    obtain ⟨b, hb, g, hg, dt, hdt, _, _, _, _, rfl⟩ := h
    have hv : SourceModel.Domain.Model.Gender.valueOf m.gender.val = .ok g := by
      unfold Gender.ofCode? at hg
      unfold SourceModel.Domain.Model.Gender.valueOf
      split at hg <;> cases hg <;> rename_i e <;> simp [e] <;> rfl
    exact ⟨_, by simp only [memberMap, hv]; rfl, rfl, rfl, rfl⟩
  · cases h

open SourceModel.Domain.Service.B2.TicketReserveServiceImpl in
/-- 会員の照合（`sameAsMember`）は、[Spec] の `matchesMember`。 -/
theorem sameAsMember_eq {M : SourceModel.Domain.Model.Member} {x : Member} (fn gn : String) (g : Gender)
    (h1 : M.kanaFamilyName = some x.kanaFamilyName) (h2 : M.kanaGivenName = some x.kanaGivenName)
    (h3 : M.gender = some x.gender) :
    sameAsMember (some fn) (some gn) (some g) M = .ok (Spec.Reserve.matchesMember fn gn g x) := by
  unfold sameAsMember Spec.Reserve.matchesMember
  simp only [LangSemantics.Java.Exception.JRef.deref, h1, h2, h3]
  by_cases a : fn = x.kanaFamilyName <;> by_cases b : gn = x.kanaGivenName <;>
    simp [a, b, Bind.bind, Except.bind, Pure.pure, Except.pure, Functor.map, Except.map]

end Abstraction.Reserve.Member
