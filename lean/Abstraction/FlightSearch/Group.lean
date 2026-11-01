import Abstraction.FlightSearch.Alpha
import Abstraction.FlightSearch.Format

/-!
# Abstraction.FlightSearch.Group

ABS-011 の補題: `createFlightVacantInfoList`（便マスタの出発時刻をキーにした `LinkedHashMap` への畳み込み）と、
[Spec] の `group`（`insertOrdered` への畳み込み）の対応。

- `insertOrdered` は `JHashMap.put` の項目の列に等しい（`insertOrdered_eq_put`）。両方の畳み込みの状態は、
  項目ごとの写し（キーは `hmOfStr`・運賃種別のコード、値は `vacantInfoOf`・運賃種別の空席情報）で結ばれ、
  スキルの `get_alpha`・`put_alpha` で 1 歩ずつ保たれる（`body_step`）。
- 各フライトは、`FlightOk`（Provider で詰め直した値が候補の写し）を満たすとする。
-/

namespace Abstraction.FlightSearch.Group
open Abstraction.MasterData.AlphaLeaf Abstraction.FlightSearch.Alpha Abstraction.FlightSearch.Format
open Spec.FlightSearch Spec.Prim Spec.Prim.Time Spec.Prim.Format Spec.Model Machine.Kernel
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int
  LangSemantics.Java.ResultLemmas

open SourceModel.FlightSearch SourceModel.Model

abbrev VMap := JLinkedHashMap (JRef String) FlightVacantInfoDto

/-! ## 畳み込みの本体 -/

/-- `createFlightVacantInfoList` の `for` の本体（`rfl` で原典の写しに等しい）。 -/
def body (sep : Char) (bf : J32) (flight : SourceModel.Model.Flight) (m : VMap) : JResult (ForInStep VMap) := do
  let fm ← flight.flightMaster.deref "flightMaster"
  let departureTime := fm.departureTime
  let jp : FlightVacantInfoDto → JResult (ForInStep VMap) := fun vacantInfo => do
    let ft ← flight.fareType.deref "fareType"
    let d ← ft.discountRate.deref "discountRate"
    let fare ← SourceModel.Fare.calculateFare bf d
    let info : FareTypeVacantInfoDto := ⟨ft.fareTypeName, some (DecimalFormat.formatJ32 sep fare), flight.vacantNum⟩
    let v ← vacantInfo.addFareTypeVacantInfo ft.fareTypeCd info
    pure (ForInStep.yield (m.put departureTime v))
  match m.get departureTime with
  | some v => do let vacantInfo ← pure v; jp vacantInfo
  | none => do let vacantInfo ← createFlightVacantInfo flight; jp vacantInfo

theorem createFlightVacantInfoList_eq (sep : Char) (fl : List SourceModel.Model.Flight) (bf : J32) :
    createFlightVacantInfoList sep fl bf =
      (forIn fl ({} : VMap) (body sep bf)) >>= fun m => pure (m.entries.map (·.2)) := rfl

/-- グループの選び方（あればそのグループ、無ければ見出し `d`）。 -/
def pickG (gs : List (HourMinute × FlightVacantInfo)) (k : HourMinute) (d : FlightVacantInfo) : FlightVacantInfo :=
  match gs.find? (·.1 == k) with
  | some (_, g) => g
  | none => d

/-- [Spec] の `group` の 1 歩。 -/
def gstep (depName arrName : String) (b : Nat) (gs : List (HourMinute × FlightVacantInfo)) (x : Candidate) :
    List (HourMinute × FlightVacantInfo) :=
  let key := x.master.departureTime
  let g := pickG gs key (headerOf depName arrName x)
  let g := { g with fareTypes := insertOrdered g.fareTypes x.flight.key.fareTypeCd (Spec.FlightSearch.fareTypeInfoOf b x) }
  insertOrdered gs key g

theorem group_eq (depName arrName : String) (b : Nat) (cs : List Candidate) :
    group depName arrName b cs = (cs.foldl (gstep depName arrName b) []).map (·.2) := rfl

theorem insertOrdered_eq_put {κ ν : Type} [DecidableEq κ] (m : List (κ × ν)) (k : κ) (v : ν) :
    insertOrdered m k v = ((⟨m⟩ : JHashMap κ ν).put k v).entries := by
  simp only [insertOrdered, JHashMap.put, JHashMap.containsKey, beq_iff_eq]
  by_cases h : (m.any fun x => x.1 == k) = true <;> simp only [h, ↓reduceIte, Bool.false_eq_true]

theorem pickG_eq_get (gs : List (HourMinute × FlightVacantInfo)) (k : HourMinute) (d : FlightVacantInfo) :
    pickG gs k d = (match (⟨gs⟩ : JHashMap HourMinute FlightVacantInfo).get k with | some g => g | none => d) := by
  simp only [pickG, JHashMap.get]
  cases gs.find? (·.1 == k) <;> rfl

theorem deref_some {α : Type} (a : α) (w : String) : JRef.deref (some a) w = .ok a := rfl

/-! ## 写し -/

/-- 出発時刻のキーの写し。 -/
def kaT (o : JRef String) : Option HourMinute := o.bind hmOfStr

theorem kaT_inj : ∀ a b x, kaT a = some x → kaT b = some x → a = b := by
  intro a b x ha hb
  cases a <;> cases b <;> simp only [kaT, Option.bind_none, Option.bind_some, reduceCtorEq] at ha hb
  rw [inj_of_kernel hmOfStr_kernel ha hb]

theorem ftCdOf_inj : ∀ a b x, ftCdOf a = some x → ftCdOf b = some x → a = b :=
  fun _ _ _ ha hb => inj_of_kernel ftCdOf_kernel ha hb

/-- 運賃種別の空席情報の値の写し。 -/
def ftVal (d : FareTypeVacantInfoDto) : Option FareTypeVacantInfo := do
  let n ← d.fareTypeName
  let f ← d.fare
  let v ← d.vacantNum.bind natOfJ32
  pure ⟨n, f, v⟩

theorem fareTypeInfoOf_eq : Alpha.fareTypeInfoOf = pairAlpha ftCdOf ftVal := by
  funext e
  simp only [Alpha.fareTypeInfoOf, pairAlpha, ftVal, Option.bind_eq_bind]
  cases ftCdOf e.1 <;> simp only [Option.bind_none, Option.bind_some]
  cases e.2.fareTypeName <;> cases e.2.fare <;> cases e.2.vacantNum.bind natOfJ32 <;> rfl

theorem vacantInfoOf_fields {d : FlightVacantInfoDto} {g : FlightVacantInfo} (h : vacantInfoOf d = some g) :
    d.fareTypes.entries.mapM Alpha.fareTypeInfoOf = some g.fareTypes ∧
      ∀ es fts, es.mapM Alpha.fareTypeInfoOf = some fts →
        vacantInfoOf { d with fareTypes := ⟨es⟩ } = some { g with fareTypes := fts } := by
  simp only [vacantInfoOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h
  obtain ⟨n, hn, dn, hdn, an, han, dt, hdt, art, hat, dd, hdd, bc, hbc, fts, hfts, rfl⟩ := h
  refine ⟨hfts, fun es fts' h' => ?_⟩
  simp only [vacantInfoOf, hn, hdn, han, hdt, hat, hdd, hbc, h', Option.bind_eq_bind, Option.bind_some,
    Option.pure_def]

theorem mapM_snd {κ υ κ' υ' : Type} {ka : κ → Option κ'} {va : υ → Option υ'} :
    ∀ {es : List (κ × υ)} {gs : List (κ' × υ')}, es.mapM (pairAlpha ka va) = some gs →
      (es.map (·.2)).mapM va = some (gs.map (·.2))
  | [], gs, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | e :: es, gs, h => by
    simp only [List.mapM_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.some.injEq] at h
    obtain ⟨e', he, gs', hgs, rfl⟩ := h
    simp only [List.map_cons, List.mapM_cons, (pairAlpha_some he).2, mapM_snd hgs, Option.pure_def,
      Option.bind_eq_bind, Option.bind_some]

/-! ## 1 歩 -/

/-- フライト（Provider で詰め直した値）が候補 `X` の写しで、運賃の計算と書式が [Spec] に一致する。 -/
structure FlightOk (sep : Char) (bf : J32) (b : Nat) (depName arrName : String) (fl : SourceModel.Model.Flight) (X : Candidate) :
    Prop where
  fm : ∃ fm r da aa dt art, fl.flightMaster = some fm ∧ fm.flightName = some X.flight.key.flightName.val ∧
    fm.departureTime = some dt ∧ hmOfStr dt = some X.master.departureTime ∧ fm.arrivalTime = some art ∧
    arrOfStr art = some X.master.arrivalTime ∧ fm.route = some r ∧ r.departureAirport = some da ∧
    da.name = some depName ∧ r.arrivalAirport = some aa ∧ aa.name = some arrName
  bc : ∃ bc, fl.boardingClass = some bc ∧ bc.boardingClassCd = some X.flight.key.boardingClassCd
  date : ∃ jd, fl.departureDate = some jd ∧ dateOfJ jd = some X.flight.key.departureDate
  ft : ∃ ft dr fv, fl.fareType = some ft ∧ ft.fareTypeCd = some X.flight.key.fareTypeCd ∧
    ft.fareTypeName = some X.fareType.fareTypeName ∧ ft.discountRate = some dr ∧
    SourceModel.Fare.calculateFare bf dr = .ok fv ∧
    DecimalFormat.formatJ32 sep fv = fmtYen (Spec.Fare.fare b X.fareType.discountRate)
  vacant : ∃ v, fl.vacantNum = some v ∧ natOfJ32 v = some X.flight.vacantNum

theorem header_ok {sep : Char} {bf : J32} {b : Nat} {depName arrName : String} {fl : SourceModel.Model.Flight} {X : Candidate}
    (h : FlightOk sep bf b depName arrName fl X) :
    ∃ hdr, createFlightVacantInfo fl = .ok hdr ∧ vacantInfoOf hdr = some (headerOf depName arrName X) := by
  obtain ⟨fm, r, da, aa, dt, art, hfm, hn, hdt, hdt', hat, hat', hr, hda, hdn, haa, han⟩ := h.fm
  obtain ⟨bc, hbc, hbcc⟩ := h.bc
  obtain ⟨jd, hjd, hjd'⟩ := h.date
  refine ⟨(⟨fm.flightName, da.name, aa.name, some (fmtTime X.master.departureTime),
    some (fmtArrTime X.master.arrivalTime), some (fmtDate X.flight.key.departureDate), bc.boardingClassCd, {}⟩ :
      FlightVacantInfoDto), ?_, ?_⟩
  · simp only [createFlightVacantInfo, hfm, hr, hda, haa, hbc, JRef.deref, hdt, hat, ok_bind,
      toFormatTimeString_hm hdt', toFormatTimeString_arr hat', hjd, toFormatDateString_eq hjd']
    rfl
  · simp only [vacantInfoOf, hn, hdn, han, hbcc, Option.bind_eq_bind, Option.bind_some, Option.pure_def, headerOf]
    rfl

/-- 1 歩: 状態が写しで結ばれていれば、本体は例外を投げず、次の状態も写しで結ばれる。 -/
theorem body_step {sep : Char} {bf : J32} {b : Nat} {depName arrName : String} {fl : SourceModel.Model.Flight} {X : Candidate}
    (h : FlightOk sep bf b depName arrName fl X) {m : VMap} {gs : List (HourMinute × FlightVacantInfo)}
    (hR : m.entries.mapM (pairAlpha kaT vacantInfoOf) = some gs) :
    ∃ m', body sep bf fl m = .ok (.yield m') ∧
      m'.entries.mapM (pairAlpha kaT vacantInfoOf) = some (gstep depName arrName b gs X) := by
  obtain ⟨fm, r, da, aa, dt, art, hfm, hn, hdt, hdt', hat, hat', hr, hda, hdn, haa, han⟩ := h.fm
  obtain ⟨ft, dr, fv, hft, hftc, hftn, hdr, hfv, hfmt⟩ := h.ft
  obtain ⟨v, hv, hv'⟩ := h.vacant
  obtain ⟨hdr0, hhdr, hhdr'⟩ := header_ok h
  have hk : kaT fm.departureTime = some X.master.departureTime := by simp only [kaT, hdt, Option.bind_some, hdt']
  -- 運賃種別の空席情報
  let info : FareTypeVacantInfoDto := ⟨ft.fareTypeName, some (DecimalFormat.formatJ32 sep fv), fl.vacantNum⟩
  have hinfo : ftVal info = some (Spec.FlightSearch.fareTypeInfoOf b X) := by
    simp only [info, ftVal, hftn, hfmt, hv, hv', Option.bind_eq_bind, Option.bind_some, Option.pure_def]
    rfl
  have hcd : ftCdOf (SourceModel.Model.fareTypeCdCode X.flight.key.fareTypeCd) = some X.flight.key.fareTypeCd := by
    rw [fareTypeCdCode_eq]; exact FareTypeCd.ofCode?_toCode _
  -- グループを更新した値の写し
  have hupd : ∀ (vi : FlightVacantInfoDto) (g : FlightVacantInfo), vacantInfoOf vi = some g →
      vacantInfoOf { vi with fareTypes := vi.fareTypes.put (SourceModel.Model.fareTypeCdCode X.flight.key.fareTypeCd) info } =
        some { g with fareTypes := insertOrdered g.fareTypes X.flight.key.fareTypeCd (Spec.FlightSearch.fareTypeInfoOf b X) } := by
    intro vi g hg
    obtain ⟨h1, h2⟩ := vacantInfoOf_fields hg
    rw [fareTypeInfoOf_eq] at h1
    have := put_alpha ftCdOf_inj h1 hcd hinfo
    rw [← fareTypeInfoOf_eq] at this
    rw [insertOrdered_eq_put]
    exact h2 _ _ this
  have hjp : ∀ (vi : FlightVacantInfoDto) (g : FlightVacantInfo), vacantInfoOf vi = some g →
      ∃ m', (do
        let ft ← fl.fareType.deref "fareType"
        let d ← ft.discountRate.deref "discountRate"
        let fare ← SourceModel.Fare.calculateFare bf d
        let info : FareTypeVacantInfoDto := ⟨ft.fareTypeName, some (DecimalFormat.formatJ32 sep fare), fl.vacantNum⟩
        let v ← vi.addFareTypeVacantInfo ft.fareTypeCd info
        pure (ForInStep.yield (m.put fm.departureTime v)) : JResult (ForInStep VMap)) = .ok (.yield m') ∧
        m'.entries.mapM (pairAlpha kaT vacantInfoOf) = some (insertOrdered gs X.master.departureTime
          { g with fareTypes := insertOrdered g.fareTypes X.flight.key.fareTypeCd (Spec.FlightSearch.fareTypeInfoOf b X) }) := by
    intro vi g hg
    refine ⟨m.put fm.departureTime { vi with fareTypes := vi.fareTypes.put (SourceModel.Model.fareTypeCdCode X.flight.key.fareTypeCd) info }, ?_, ?_⟩
    · simp only [hft, hdr, deref_some, hfv, FlightVacantInfoDto.addFareTypeVacantInfo, hftc, ok_bind, pure_bind]
      rfl
    · rw [insertOrdered_eq_put]
      exact put_alpha kaT_inj hR hk (hupd vi g hg)
  have hrel := get_alpha (va := vacantInfoOf) kaT_inj hR hk
  unfold body gstep
  simp only [hfm, deref_some, ok_bind]
  rw [pickG_eq_get]
  generalize JHashMap.get m fm.departureTime = gm at hrel ⊢
  generalize JHashMap.get (⟨gs⟩ : JHashMap HourMinute FlightVacantInfo) X.master.departureTime = gg at hrel ⊢
  cases hrel with
  | none =>
    obtain ⟨m', h1, h2⟩ := hjp hdr0 _ hhdr'
    exact ⟨m', by simp only [hhdr, ok_bind]; exact h1, h2⟩
  | some hvg =>
    rename_i vi g
    obtain ⟨m', h1, h2⟩ := hjp vi g hvg
    exact ⟨m', by simp only [pure_bind]; exact h1, h2⟩

/-- 畳み込み全体: 各フライトが `FlightOk` なら、`createFlightVacantInfoList` は例外を投げず、結果の写しは
[Spec] の `group`。 -/
theorem group_spec {ρ : Type} {sep : Char} {bf : J32} {b : Nat} {depName arrName : String} (o : List ρ)
    (E : ρ → SourceModel.Model.Flight) (C : ρ → Candidate) (h : ∀ r ∈ o, FlightOk sep bf b depName arrName (E r) (C r)) :
    ∃ ds, createFlightVacantInfoList sep (o.map E) bf = .ok ds ∧
      ds.mapM vacantInfoOf = some (group depName arrName b (o.map C)) := by
  obtain ⟨m, hm, hR⟩ := forIn_map_sim o E C (body sep bf) (fun m gs => m.entries.mapM (pairAlpha kaT vacantInfoOf) = some gs)
    (gstep depName arrName b) {} [] rfl fun r hr m gs hR => body_step (h r hr) hR
  rw [createFlightVacantInfoList_eq, hm]
  exact ⟨_, rfl, by rw [group_eq]; exact mapM_snd hR⟩

end Abstraction.FlightSearch.Group
