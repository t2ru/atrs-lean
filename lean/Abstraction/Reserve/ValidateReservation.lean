import Abstraction.Reserve.MemberCheck

/-!
# Abstraction.Reserve.ValidateReservation

ABS-041 の補題: 予約内容の検証（`TicketReserveServiceImpl.validateReservation`）の Hoare 三つ組と、[Spec] の
`Spec.UseCase.Reserve.validateReservation` の対応（backlog aedf の第 3 段）。

検証は、代表者の年齢・運賃種別の利用条件・代表者の会員照合・搭乗者の会員照合の順で、文は会員の取得だけである。
トランザクションの取消は、状態の表を変えていないので、状態を変えない。
-/

namespace Abstraction.Reserve.ValidateReservation
open LangSemantics.Core.EStateHoare
open Abstraction.Reserve.Tx Abstraction.Reserve.ValidateFlights Abstraction.Reserve.Validate
  Abstraction.Reserve.MemberCheck
open LangSemantics.Java LangSemantics.Java.Exception
open SourceModel.Db.Schema SourceModel.Db.Tx SourceModel.Domain.Common.Exception SourceModel.Domain.Service.B2

/-- 業務例外の検査の結果の持ち上げ。 -/
theorem lift_agreeB {P : St → Prop} {r : JResult Unit} {x : Except Spec.Error.AtrsError Unit} (h : AgreeB r x) :
    Hoare P (lift r) (PostB P x) (PostBE P x) := by
  intro s hs
  rcases h with ⟨rfl, rfl⟩ | ⟨be, rfl, rfl⟩
  · exact ⟨hs, rfl⟩
  · exact ⟨hs, .inr ⟨be, rfl, rfl⟩⟩

/-- 検査の逐次: [Spec] の検査の結果も、最初に失敗した検査の結果。 -/
theorem seqB {P : St → Prop} {m1 m2 : DbM Unit} {v1 v2 : Except Spec.Error.AtrsError Unit}
    (h1 : Hoare P m1 (PostB P v1) (PostBE P v1)) (h2 : Hoare P m2 (PostB P v2) (PostBE P v2)) :
    Hoare P (m1 >>= fun _ => m2) (PostB P (v1 >>= fun _ => v2)) (PostBE P (v1 >>= fun _ => v2)) := by
  refine Hoare.bind' (Hoare.conseq h1 (fun _ h => h) (fun _ _ h => h) fun e s ⟨hs, he⟩ => ⟨hs, ?_⟩) fun _ => ?_
  · rcases he with he | ⟨be, rfl, hv⟩
    · exact .inl he
    · exact .inr ⟨be, rfl, by rw [hv]; rfl⟩
  · intro s ⟨hs, hv⟩
    rw [hv]
    exact h2 s hs

theorem rollback_self (fd : FlightDb) : FlightDb.rollback fd fd = fd := by
  cases fd; rfl

/-- 状態の表を変えない計算のトランザクション: 取消は状態を変えない。 -/
theorem transactional_hoare {α : Type} {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {body : DbM α}
    {Q : α → St → Prop} {E : JThrow → St → Prop} (h : Hoare P body Q E) (hE : ∀ e s, E e s → P s) :
    Hoare P (transactional body) Q E := by
  intro s hs
  have hb := h s hs
  have h0 := hP.db s hs
  unfold transactional LangSemantics.Sql.Transaction.run
  revert hb
  cases body s with
  | ok a s' => exact id
  | error e s' =>
    intro he
    have h' := hP.db _ (hE _ _ he)
    have hs' : ({ s' with db := FlightDb.rollback s.db s'.db } : St) = s' := by
      rw [h0, h', rollback_self, ← h']
    simp only [hs']
    exact he

/-- 運賃種別の利用条件の検査の列（[Spec]）は、予約フライトごとの検査の最初の失敗。 -/
theorem foldlM_fareTypes {md : Spec.MasterData} {ps : List Spec.Model.Passenger} :
    ∀ {ks : List Spec.Model.FlightKey} {FTs : List Spec.MasterData.FareType},
      LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) ks FTs →
      ∀ acc : Except Spec.Error.AtrsError Unit,
        ks.foldlM (init := acc) (fun acc k => do
            match acc with
            | .error e => return .error e
            | .ok () => Spec.UseCase.Reserve.checkFareTypeOf md ps k) =
          some (acc.bind fun _ => firstErr (FTs.map (specFareTypeOf · ps)))
  | [], [], .nil, acc => by cases acc <;> rfl
  | k :: ks, FT :: FTs, .cons h hr, acc => by
    rw [List.foldlM_cons]
    cases acc with
    | error e => exact foldlM_fareTypes hr (.error e)
    | ok u =>
      cases u
      simp only [checkFareTypeOf_eq h]
      change Option.bind (some (specFareTypeOf FT ps)) (fun init => List.foldlM _ init ks) = _
      rw [Option.bind_some, foldlM_fareTypes hr]
      simp only [List.map_cons]
      cases specFareTypeOf FT ps <;> rfl

theorem checkFareTypes_eq {md : Spec.MasterData} {d : Spec.UseCase.Reserve.Draft} {FTs : List Spec.MasterData.FareType}
    (h : LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) d.flights FTs) :
    Spec.UseCase.Reserve.checkFareTypes md d = some (firstErr (FTs.map (specFareTypeOf · d.passengers))) :=
  foldlM_fareTypes h (.ok ())

/-- 予約内容の検証。予約情報 `r` は、すべての予約フライトに同じ搭乗者の列 `xs`（[Spec] の `d.passengers`）を持ち、
代表者の年齢・会員・氏名・性別が [Spec] の予約内容 `d` に当たる。 -/
theorem validate_hoare {P : St → Prop} {fd : FlightDb} (hP : Stable P fd) {svc : TicketReserveServiceImpl}
    {w : Spec.Port.World} (he : MemberEnv fd svc.memberRepository w) {cfg : Spec.Config} {md : Spec.MasterData}
    {r : SourceModel.Domain.Model.Reservation} {d : Spec.UseCase.Reserve.Draft}
    {xs : List SourceModel.Domain.Model.Passenger} {fl : SourceModel.Domain.Model.Flight}
    {fls : List SourceModel.Domain.Model.Flight} {FTs : List Spec.MasterData.FareType} {age : Int.J32}
    {M0 : SourceModel.Domain.Model.Member}
    (hrfl : r.reserveFlightList =
      some ((fl :: fls).map fun fl => some { flight := some fl, passengerList := some (xs.map some) }))
    (hage : r.repAge = some age) (hagev : age.val = (d.repAge : Int))
    (hmin : svc.representativeMinAge.val = (cfg.representativeMinAge : Int))
    (hm : r.repMember = some M0) (hn : Spec.UseCase.Reserve.memberNoOf M0.membershipNumber = d.repMembershipNumber)
    (hf : r.repFamilyName = some d.repFamilyName) (hg : r.repGivenName = some d.repGivenName)
    (hgd : r.repGender = some d.repGender)
    (hR : LangSemantics.Core.List.Forall₂ PassengerFacts xs d.passengers) (hne : xs ≠ []) (hlen : xs.length ≤ 6)
    (hFT : LangSemantics.Core.List.Forall₂ FareTypeFacts (fl :: fls) FTs)
    (hkf : LangSemantics.Core.List.Forall₂ (fun k FT => md.fareTypeOf k.fareTypeCd = some FT) d.flights FTs) :
    ∃ v, Spec.UseCase.Reserve.validateReservation cfg md w d = some v ∧
      Hoare P (TicketReserveServiceImpl.validateReservation svc (some r)) (PostB P v) (PostBE P v) := by
  have hgen : LangSemantics.Core.List.Forall₂ (fun x q => x.gender = some q.gender) xs d.passengers :=
    LangSemantics.Core.List.Forall₂.imp (fun _ _ ⟨_, _, _, _, _, h⟩ => h) hR
  refine ⟨_, by simp only [Spec.UseCase.Reserve.validateReservation, checkFareTypes_eq hkf]; rfl, ?_⟩
  have hnevL : ∀ g : SourceModel.Domain.Model.Flight → JRef SourceModel.Domain.Model.ReserveFlight,
      LangSemantics.Java.Spring.Assert.notEmptyValue (some ((fl :: fls).map g)) "reserveFlightList must not empty." =
        pure ((fl :: fls).map g) := fun _ => rfl
  unfold TicketReserveServiceImpl.validateReservation
  refine transactional_hoare hP ?_ fun _ _ h => h.1
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, lift_pure, pure_bind, hrfl,
    hnevL, hage,
    LangSemantics.Java.EStateSimp.deref_some, lift_ok]
  exact seqB (lift_agreeB (repAge hmin hagev)) (seqB (lift_agreeB (fareTypes hgen hne hlen hFT))
    (seqB (repMember_hoare hP he hm hn hf hg hgd) (passengerMember_hoare hP he hR hne hlen)))

end Abstraction.Reserve.ValidateReservation
