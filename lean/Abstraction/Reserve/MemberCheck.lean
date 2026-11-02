import Abstraction.Reserve.Validate
import Abstraction.Reserve.ValidateFlights

/-!
# Abstraction.Reserve.MemberCheck

ABS-041 の補題: 予約内容の検証の会員照合（`validateRepresentativeMemberInfo`・`validatePassengerMemberInfo`）の Hoare
三つ組と、[Spec] の `checkRepMember`・`checkPassengerMembers` の対応（backlog aedf の第 3 段）。

文は会員の取得（`findOne`）だけで、状態の表を変えない。事後条件は次のとおりである。

- 正常に終われば、[Spec] の結果は `.ok ()`。
- 例外で終われば、実行環境の障害（`IsFault`）か、[Spec] と同じコードと引数の業務例外。
-/

namespace Abstraction.Reserve.MemberCheck
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate Abstraction.Reserve.Member
open Abstraction.MasterData.Alpha Abstraction.World.Alpha
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.Domain.Common.Exception
open SourceModel.Domain.Repository.Member SourceModel.Domain.Service.B2

/-- 会員照合の事後条件。 -/
def PostB (P : St → Prop) (v : Except Spec.Error.AtrsError Unit) : Unit → St → Prop :=
  fun _ s => P s ∧ v = .ok ()

/-- 会員照合の例外の事後条件。 -/
def PostBE (P : St → Prop) (v : Except Spec.Error.AtrsError Unit) : JThrow → St → Prop :=
  fun e s => P s ∧ (IsFault e ∨ ∃ c args, e = AtrsBusinessException.newArgs c args ∧ v = .error (.business c args))

/-- 会員の取得の答え: 会員が無ければ `null`、あれば照合が [Spec] の `matchesMember` になる会員。 -/
def MemberAns (w : Spec.Port.World) (s : String) (r : JRef SourceModel.Domain.Model.Member) : Prop :=
  match w.findMember ⟨s⟩ with
  | none => r = none
  | some x => ∃ M, r = some M ∧ ∀ fn gn g,
      TicketReserveServiceImpl.sameAsMember (some fn) (some gn) (some g) M =
        .ok (Spec.UseCase.Reserve.matchesMember fn gn g x)

/-- 会員の取得の前提（α の像・会員番号の一意性・カード種別のマスタ）。 -/
structure MemberEnv (fd : FlightDb) (mdb : MasterDb) (w : Spec.Port.World) : Prop where
  world : worldOfDb fd = some w
  keys : KeysOk w
  md : ∃ md, masterDataOf mdb = some md ∧ md.MD1 ∧ w.MemberRefMaster md

/-- 会員の取得（`findOne`）。 -/
theorem findOne_hoare {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {mdb : MasterDb} {w : Spec.Port.World}
    (he : MemberEnv fd mdb w) (s : String) :
    Hoare P (MemberRepository.findOne mdb (some s)) (fun r s' => P s' ∧ MemberAns w s r)
      (fun e s' => P s' ∧ IsFault e) := by
  intro s0 hs
  have hdb := hP.db s0 hs
  have ht := hP.tick s0 hs
  obtain ⟨md, hmd, h1, href⟩ := he.md
  have hf := findOneRows_world he.world he.keys hmd h1 href s
  rw [← hdb] at hf
  java_estate_simp [MemberRepository.findOne, query, sql, lift]
  by_cases h1 : s0.env.ioFailAt = some s0.sqlCalls
  · simp only [h1, ite_true]
    exact ⟨ht, _, .inl rfl⟩
  by_cases h2 : s0.env.conflictAt = some s0.sqlCalls
  · simp only [h1, h2, ite_true, ite_false]
    exact ⟨ht, _, .inr rfl⟩
  simp only [h1, h2, ite_false]
  unfold MemberAns
  have htk : ({ db := s0.db, env := s0.env, clockReads := s0.clockReads, sqlCalls := s0.sqlCalls + 1 } : St) =
      tick s0 := rfl
  rw [htk]
  cases hx : w.findMember ⟨s⟩ with
  | none =>
    rw [hx] at hf
    simp only [hf]
    exact ⟨ht, rfl⟩
  | some x =>
    rw [hx] at hf
    obtain ⟨r, hr, hml⟩ := hf
    obtain ⟨M, hM, k1, k2, k3⟩ := memberMap_ok hml r.creditType
    have hM' : MemberRepository.memberMap r = .ok M := hM
    simp only [hr, hM']
    exact ⟨ht, M, rfl, fun fn gn g => sameAsMember_eq fn gn g k1 k2 k3⟩

/-- 代表者の会員照合。 -/
theorem repMember_hoare {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {svc : TicketReserveServiceImpl}
    {w : Spec.Port.World} (he : MemberEnv fd svc.memberRepository w) {r : SourceModel.Domain.Model.Reservation}
    {d : Spec.UseCase.Reserve.Draft} {M0 : SourceModel.Domain.Model.Member} (hm : r.repMember = some M0)
    (hn : Spec.UseCase.Reserve.memberNoOf M0.membershipNumber = d.repMembershipNumber)
    (hf : r.repFamilyName = some d.repFamilyName) (hg : r.repGivenName = some d.repGivenName)
    (hgd : r.repGender = some d.repGender) :
    Hoare P (TicketReserveServiceImpl.validateRepresentativeMemberInfo svc r)
      (PostB P (Spec.UseCase.Reserve.checkRepMember w d)) (PostBE P (Spec.UseCase.Reserve.checkRepMember w d)) := by
  intro s hs
  java_estate_simp [TicketReserveServiceImpl.validateRepresentativeMemberInfo, lift, hm]
  unfold Spec.UseCase.Reserve.checkRepMember
  rw [← hn]
  cases hmn : M0.membershipNumber with
  | none => exact ⟨hs, rfl⟩
  | some str =>
    by_cases hempty : str.isEmpty = true
    · simp only [Spring.StringUtils.hasLength, hempty, Spec.UseCase.Reserve.memberNoOf, Option.bind_some,
        ite_true, Bool.not_true, Bool.false_eq_true, ite_false]
      exact ⟨hs, rfl⟩
    simp only [Spring.StringUtils.hasLength, hempty, Spec.UseCase.Reserve.memberNoOf, Option.bind_some,
      ite_false, Bool.not_false, ite_true, Bool.false_eq_true]
    have h := findOne_hoare hP he str s hs
    revert h
    cases MemberRepository.findOne svc.memberRepository (some str) s with
    | error e s' => intro h; exact ⟨h.1, .inl h.2⟩
    | ok a s' =>
      intro ⟨hs', ha⟩
      unfold MemberAns at ha
      cases hx : w.findMember ⟨str⟩ with
      | none =>
        rw [hx] at ha; subst ha
        exact ⟨hs', .inr ⟨_, [], rfl, rfl⟩⟩
      | some x =>
        rw [hx] at ha
        obtain ⟨M, rfl, hM⟩ := ha
        simp only [hf, hg, hgd, hM]
        java_estate_simp []
        cases Spec.UseCase.Reserve.matchesMember d.repFamilyName d.repGivenName d.repGender x
        · exact ⟨hs', .inr ⟨_, [], rfl, rfl⟩⟩
        · exact ⟨hs', rfl⟩

/-! ## 搭乗者の会員照合 -/

/-- 1 人の搭乗者の会員照合（位置 `i` は 0 から数える）。 -/
def checkOne (w : Spec.Port.World) (p : Spec.Model.Passenger) (i : Nat) : Except Spec.Error.AtrsError Unit :=
  match p.membershipNumber with
  | none => .ok ()
  | some n =>
    match w.findMember n with
    | none => .error (.business "e.ar.b2.2005" [toString (i + 1)])
    | some m => if Spec.UseCase.Reserve.matchesMember p.familyName p.givenName p.gender m then .ok ()
      else .error (.business "e.ar.b2.2006" [toString (i + 1)])

/-- 搭乗者の会員照合を、位置 `i` から順に。 -/
def pmFrom (w : Spec.Port.World) : List Spec.Model.Passenger → Nat → Except Spec.Error.AtrsError Unit
  | [], _ => .ok ()
  | p :: ps, i => (checkOne w p i).bind fun _ => pmFrom w ps (i + 1)

theorem foldlM_zipIdx (w : Spec.Port.World) :
    ∀ (ps : List Spec.Model.Passenger) (n : Nat),
      (ps.zipIdx n).foldlM (init := ()) (fun _ (pi : Spec.Model.Passenger × Nat) =>
        match pi.1.membershipNumber with
        | none => .ok ()
        | some m =>
          match w.findMember m with
          | none => .error (.business "e.ar.b2.2005" [toString (pi.2 + 1)])
          | some x => if Spec.UseCase.Reserve.matchesMember pi.1.familyName pi.1.givenName pi.1.gender x then .ok ()
            else .error (.business "e.ar.b2.2006" [toString (pi.2 + 1)])) = pmFrom w ps n
  | [], _ => rfl
  | p :: ps, n => by
    rw [List.zipIdx_cons, List.foldlM_cons]
    show Except.bind _ _ = Except.bind _ _
    congr 1
    funext u
    cases u
    exact foldlM_zipIdx w ps (n + 1)

theorem checkPassengerMembers_eq (w : Spec.Port.World) (ps : List Spec.Model.Passenger) :
    Spec.UseCase.Reserve.checkPassengerMembers w ps = pmFrom w ps 0 :=
  foldlM_zipIdx w ps 0

/-- 搭乗者の会員照合の材料: 会員のオブジェクトの会員番号が [Spec] の会員番号に当たり、氏名（カナ）・性別が [Spec] と
同じ。 -/
def PassengerFacts (x : SourceModel.Domain.Model.Passenger) (q : Spec.Model.Passenger) : Prop :=
  ∃ M0, x.member = some M0 ∧ Spec.UseCase.Reserve.memberNoOf M0.membershipNumber = q.membershipNumber ∧
    x.familyName = some q.familyName ∧ x.givenName = some q.givenName ∧ x.gender = some q.gender

theorem lift_ok {α : Type} (a : α) : (lift (.ok a) : DbM α) = pure a := rfl

theorem lift_pure {α : Type} (a : α) : (lift (pure a) : DbM α) = pure a := rfl

/-- 位置を数えながら搭乗者を順に照合する `for` 文。 -/
theorem forIn_pos {P : St → Prop} {w : Spec.Port.World} {R : SourceModel.Domain.Model.Passenger → Spec.Model.Passenger → Prop}
    {f : JRef SourceModel.Domain.Model.Passenger → Int.J32 → DbM (ForInStep Int.J32)}
    (hf : ∀ x q (pos : Int.J32) (i : Nat), R x q → pos.val = (i : Int) + 1 → i < 6 →
      Hoare P (f (some x) pos)
        (fun r s => P s ∧ checkOne w q i = .ok () ∧ ∃ p', r = .yield p' ∧ p'.val = pos.val + 1)
        (PostBE P (checkOne w q i))) :
    ∀ {xs qs}, LangSemantics.Core.List.Forall₂ R xs qs → ∀ (i : Nat) (pos : Int.J32), pos.val = (i : Int) + 1 →
      i + xs.length ≤ 6 →
      Hoare P (forIn (xs.map some) pos f) (fun _ s => P s ∧ pmFrom w qs i = .ok ()) (PostBE P (pmFrom w qs i))
  | [], [], .nil, _, _, _, _ => fun s hs => ⟨hs, rfl⟩
  | x :: xs, q :: qs, .cons hxq hr, i, pos, hpos, hlen => by
    rw [List.map_cons, List.forIn_cons]
    refine Hoare.bind' (Hoare.conseq (hf x q pos i hxq hpos (by simp at hlen; omega)) (fun _ h => h)
      (fun _ _ h => h) fun e s' ⟨hs', he⟩ => ⟨hs', ?_⟩) fun r => ?_
    · rcases he with he | ⟨c, args, rfl, hc⟩
      · exact .inl he
      · exact .inr ⟨c, args, rfl, by simp only [pmFrom, hc]; rfl⟩
    intro s ⟨hs, hc, p', hr', hp'⟩
    subst hr'
    have ih := forIn_pos hf hr (i + 1) p' (by rw [hp', hpos]; push_cast; omega) (by simp at hlen; omega)
    have hv : pmFrom w (q :: qs) i = pmFrom w qs (i + 1) := by simp only [pmFrom, hc]; rfl
    rw [hv]
    exact ih s hs

/-- 同じ検査を繰り返す `for` 文（[Spec] の結果がすでに `.ok ()`）。 -/
theorem forIn_same_ok {β : Type} {P : St → Prop} {v : Except Spec.Error.AtrsError Unit}
    {g : β → PUnit → DbM (ForInStep PUnit)} :
    ∀ (l : List β), (∀ a ∈ l, Hoare P (g a ()) (fun r s => P s ∧ r = .yield () ∧ v = .ok ()) (PostBE P v)) →
      Hoare (fun s => P s ∧ v = .ok ()) (forIn l () g) (PostB P v) (PostBE P v)
  | [], _ => fun _ hs => hs
  | a :: l, hg => by
    rw [List.forIn_cons]
    refine Hoare.bind' (Hoare.conseq (hg a (List.mem_cons_self ..)) (fun _ h => h.1) (fun _ _ h => h)
      (fun _ _ h => h)) fun r => ?_
    intro s ⟨hs, hr, hv⟩
    subst hr
    exact forIn_same_ok l (fun b hb => hg b (List.mem_cons_of_mem _ hb)) s ⟨hs, hv⟩

/-- 同じ検査を繰り返す `for` 文（空でない列）。 -/
theorem forIn_same {β : Type} {P : St → Prop} {v : Except Spec.Error.AtrsError Unit}
    {g : β → PUnit → DbM (ForInStep PUnit)} {a : β} {l : List β}
    (hg : ∀ b ∈ a :: l, Hoare P (g b ()) (fun r s => P s ∧ r = .yield () ∧ v = .ok ()) (PostBE P v)) :
    Hoare P (forIn (a :: l) () g) (PostB P v) (PostBE P v) := by
  rw [List.forIn_cons]
  refine Hoare.bind' (hg a (List.mem_cons_self ..)) fun r => ?_
  intro s ⟨hs, hr, hv⟩
  subst hr
  exact forIn_same_ok l (fun b hb => hg b (List.mem_cons_of_mem _ hb)) s ⟨hs, hv⟩

/-- 搭乗者の会員照合。すべての予約フライトが同じ搭乗者の列 `xs`（[Spec] の `qs`）を持つ。 -/
theorem passengerMember_hoare {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {svc : TicketReserveServiceImpl}
    {w : Spec.Port.World} (he : MemberEnv fd svc.memberRepository w) {xs : List SourceModel.Domain.Model.Passenger}
    {qs : List Spec.Model.Passenger} (hR : LangSemantics.Core.List.Forall₂ PassengerFacts xs qs) (hne : xs ≠ [])
    (hlen : xs.length ≤ 6) {fl : SourceModel.Domain.Model.Flight} {fls : List SourceModel.Domain.Model.Flight} :
    Hoare P (TicketReserveServiceImpl.validatePassengerMemberInfo svc
        ((fl :: fls).map fun fl => some { flight := some fl, passengerList := some (xs.map some) }))
      (PostB P (Spec.UseCase.Reserve.checkPassengerMembers w qs))
      (PostBE P (Spec.UseCase.Reserve.checkPassengerMembers w qs)) := by
  have hnev : LangSemantics.Java.Spring.Assert.notEmptyValue (some (xs.map some)) "passengerList must not empty." =
      pure (xs.map some) := by
    cases xs with
    | nil => exact absurd rfl hne
    | cons x xs' => rfl
  rw [checkPassengerMembers_eq]
  unfold TicketReserveServiceImpl.validatePassengerMemberInfo
  rw [List.map_cons]
  refine Hoare.bind' (forIn_same fun b hb => ?_) fun u => Hoare.pure' fun s h => by cases u; exact h
  obtain ⟨fl', rfl⟩ : ∃ fl', b = some { flight := some fl', passengerList := some (xs.map some) } := by
    simp only [List.mem_cons, List.mem_map] at hb
    rcases hb with rfl | ⟨fl', -, rfl⟩
    · exact ⟨fl, rfl⟩
    · exact ⟨fl', rfl⟩
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, lift_pure, pure_bind, hnev]
  refine Hoare.bind' (forIn_pos (R := PassengerFacts) (fun x q pos i hxq hpos hi => ?_) hR 0 _ (by decide)
    (by omega)) fun _ => Hoare.pure' fun s h => ⟨h.1, rfl, h.2⟩
  obtain ⟨M0, hm, hn, hf, hg, hgd⟩ := hxq
  have hpos' : pos.val = ((i + 1 : Nat) : Int) := by rw [hpos]; push_cast; rfl
  have hts : toString pos.val = toString (i + 1) := by rw [hpos']; rfl
  have hadd : (Int.j32add pos (Int.J32.ofInt 1)).val = pos.val + 1 := by
    have h := LangSemantics.Java.IntLemmas.j32add_ofInt (v := 1) hpos' (by omega)
    simp only [Int.natCast_one] at h
    rw [h, hpos']; push_cast; rfl
  intro s hs
  java_estate_simp [lift, hm]
  unfold checkOne
  rw [← hn]
  cases hmn : M0.membershipNumber with
  | none => exact ⟨hs, by first | rfl | trivial, _, rfl, hadd⟩
  | some str =>
    by_cases hempty : str.isEmpty = true
    · simp only [Spring.StringUtils.hasLength, hempty, Spec.UseCase.Reserve.memberNoOf, Option.bind_some,
        ite_true, Bool.not_true, Bool.false_eq_true, ite_false]
      exact ⟨hs, by first | rfl | trivial, _, rfl, hadd⟩
    simp only [Spring.StringUtils.hasLength, hempty, Spec.UseCase.Reserve.memberNoOf, Option.bind_some,
      ite_false, Bool.not_false, ite_true, Bool.false_eq_true]
    have h := findOne_hoare hP he str s hs
    revert h
    cases MemberRepository.findOne svc.memberRepository (some str) s with
    | error e s' => intro h; exact ⟨h.1, .inl h.2⟩
    | ok a s' =>
      intro ⟨hs', ha⟩
      unfold MemberAns at ha
      cases hx : w.findMember ⟨str⟩ with
      | none =>
        rw [hx] at ha; subst ha
        exact ⟨hs', .inr ⟨_, _, rfl, by rw [hts]; rfl⟩⟩
      | some x =>
        rw [hx] at ha
        obtain ⟨M, rfl, hM⟩ := ha
        simp only [hf, hg, hgd, hM]
        java_estate_simp []
        cases Spec.UseCase.Reserve.matchesMember q.familyName q.givenName q.gender x
        · exact ⟨hs', .inr ⟨_, _, rfl, by rw [hts]; rfl⟩⟩
        · exact ⟨hs', by first | rfl | trivial, _, rfl, hadd⟩

end Abstraction.Reserve.MemberCheck
