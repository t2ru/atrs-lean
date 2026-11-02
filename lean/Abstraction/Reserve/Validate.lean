import LangSemantics.Java.IntLemmas
import Abstraction.Reserve.Member
import Abstraction.Reserve.Tx
import Spec.UseCase.Reserve
import Abstraction.FlightSearch.Providers

/-!
# Abstraction.Reserve.Validate

ABS-041 の補題: 予約内容の検証（`TicketReserveServiceImpl.validateReservation`）の各検査と、[Spec] の
`Spec.UseCase.Reserve.validateReservation` の各検査の対応（backlog aedf の第 3 段）。

業務例外は、コードと引数が [Spec] の `Business` と同じであることを示す（`AgreeB`）。
-/

namespace Abstraction.Reserve.Validate
open Abstraction.Reserve.Tx
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Domain.Service.B2 SourceModel.Domain.Common.Exception

/-- 検査の結果の対応: どちらも成功するか、[Source] が業務例外（コードと引数）を投げ、[Spec] が同じコードと引数の
`Business` を返す。 -/
def AgreeB (r : JResult Unit) (x : Except Spec.Error.AtrsError Unit) : Prop :=
  (r = .ok () ∧ x = .ok ()) ∨ ∃ c args, r = .error (AtrsBusinessException.newArgs c args) ∧ x = .error (.business c args)

/-- 整数の値の文字列（非負なら自然数の文字列）。 -/
theorem toString_int_ofNat (n : Nat) : toString (n : Int) = toString n := rfl

/-- 代表者の年齢の検査。 -/
theorem repAge {svc : TicketReserveServiceImpl} {cfg : Spec.Config} {age : J32} {d : Spec.UseCase.Reserve.Draft}
    (hmin : svc.representativeMinAge.val = (cfg.representativeMinAge : Int)) (hage : age.val = (d.repAge : Int)) :
    AgreeB (TicketReserveServiceImpl.validateRepresentativeAge svc age) (Spec.UseCase.Reserve.checkRepAge cfg d) := by
  unfold TicketReserveServiceImpl.validateRepresentativeAge Spec.UseCase.Reserve.checkRepAge
  by_cases h : d.repAge < cfg.representativeMinAge
  · have h' : age.val < (cfg.representativeMinAge : Int) := by omega
    refine .inr ⟨"e.ar.b2.2004", [toString cfg.representativeMinAge], ?_, by simp [h]⟩
    simp only [hmin, toString_int_ofNat, h', decide_true, ite_true]
    rfl
  · have h' : ¬ age.val < (cfg.representativeMinAge : Int) := by omega
    refine .inl ⟨?_, by simp [h]⟩
    simp only [hmin, h', decide_false, Bool.false_eq_true, ite_false]
    rfl

/-! ## 運賃種別の利用条件 -/

open Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf in
/-- 運賃種別のキャッシュの答えから、コード・名前・最少人数を取り出す。 -/
theorem fareType_full {r : JRef SourceModel.Domain.Model.FareType} {ft : Spec.MasterData.FareType}
    (h : answerOf? (.fareType r) = some (.fareType (some ft.info))) :
    ∃ f m, r = some f ∧ f.fareTypeCd = some ft.fareTypeCd ∧ f.fareTypeName = some ft.fareTypeName ∧
      f.passengerMinNum = some m ∧ m.val = (ft.passengerMinNum : Int) := by
  cases r with
  | none => simp [answerOf?, AnswerOf.opt] at h
  | some f =>
    simp only [answerOf?, AnswerOf.opt, Option.map_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, hxe⟩ := h
    simp only [Function.comp, Spec.MasterQuery.Answer.fareType.injEq, Option.some.injEq] at hxe
    subst hxe
    simp only [AnswerOf.fareType, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at hx
    obtain ⟨cd, hc0, nm, hn0, dr, -, s0, -, e0, -, pm0, hp0, he⟩ := hx
    obtain ⟨m, hm1, hm2⟩ := hp0
    rw [natOfJ32_eq_some] at hm2
    simp only [Spec.MasterData.FareType.info, Spec.MasterData.FareTypeInfo.mk.injEq] at he
    obtain ⟨rfl, rfl, -, -, -, rfl⟩ := he
    exact ⟨f, m, rfl, hc0, hn0, hm1, hm2⟩

/-- 要素ごとの検査の `for` 文: 本体が、要素が悪いときに例外 `e`、そうでなければ次へ進むなら、どれかの要素が悪いときに
限って例外 `e`。 -/
theorem forIn_check {α ε : Type} (f : α → PUnit → Except ε (ForInStep PUnit)) (bad : α → Bool) (e : ε)
    (hf : ∀ a, f a () = if bad a then .error e else .ok (.yield ())) :
    ∀ l : List α, forIn l () f = if l.any bad then .error e else .ok ()
  | [] => rfl
  | a :: l => by
    rw [List.forIn_cons, hf a, List.any_cons]
    cases bad a
    · simp only [Bool.false_eq_true, ite_false, Bool.false_or]
      exact forIn_check f bad e hf l
    · rfl

/-- 女性限定の検査の本体（男性の搭乗者で業務例外）。 -/
theorem ladies_body (x : SourceModel.Domain.Model.Passenger) :
    (do
        let passenger ← LangSemantics.Java.Spring.Assert.notNullValue (some x) "passenger must not null."
        if passenger.gender = some .M then
          throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2007"))
        pure (ForInStep.yield PUnit.unit) : JResult (ForInStep PUnit)) =
      if x.gender == some .M then .error (AtrsBusinessException.new "e.ar.b2.2007") else .ok (.yield ()) := by
  by_cases h : x.gender = some .M <;> simp [h, LangSemantics.Java.Spring.Assert.notNullValue_some, Bind.bind,
    Except.bind, Pure.pure, Except.pure, throw, throwThe, MonadExceptOf.throw] <;> rfl

/-- 予約フライトの検査の材料: フライト情報の運賃種別のオブジェクトが、マスタの運賃種別 `FT` のコード・名前・最少人数を
持つ。 -/
def FareTypeFacts (fl : SourceModel.Domain.Model.Flight) (FT : Spec.MasterData.FareType) : Prop :=
  ∃ ft m, fl.fareType = some ft ∧ ft.fareTypeCd = some FT.fareTypeCd ∧ ft.fareTypeName = some FT.fareTypeName ∧
    ft.passengerMinNum = some m ∧ m.val = (FT.passengerMinNum : Int)

/-- 予約フライトごとの [Spec] の検査の値。 -/
def specFareTypeOf (FT : Spec.MasterData.FareType) (qs : List Spec.Model.Passenger) : Except Spec.Error.AtrsError Unit :=
  match FT.fareTypeCd with
  | .LD => if qs.any (·.gender == .M) then .error (.business "e.ar.b2.2007") else .ok ()
  | .GD => if qs.length < FT.passengerMinNum then
      .error (.business "e.ar.b2.2010" [FT.fareTypeName, toString FT.passengerMinNum]) else .ok ()
  | _ => .ok ()

theorem checkFareTypeOf_eq {md : Spec.MasterData} {qs : List Spec.Model.Passenger} {k : Spec.Model.FlightKey}
    {FT : Spec.MasterData.FareType} (h : md.fareTypeOf k.fareTypeCd = some FT) :
    Spec.UseCase.Reserve.checkFareTypeOf md qs k = some (specFareTypeOf FT qs) := by
  simp only [Spec.UseCase.Reserve.checkFareTypeOf, h, Option.bind_eq_bind, Option.bind_some, Option.pure_def,
    specFareTypeOf]
  cases FT.fareTypeCd <;> rfl

theorem any_gender_eq {xs : List SourceModel.Domain.Model.Passenger} {qs : List Spec.Model.Passenger}
    (h : LangSemantics.Core.List.Forall₂ (fun x q => x.gender = some q.gender) xs qs) :
    xs.any (fun x => x.gender == some .M) = qs.any (·.gender == .M) := by
  induction h with
  | nil => rfl
  | cons hxq _ ih =>
    simp only [List.any_cons, hxq, ih]
    rename_i q _ _ _
    cases q.gender <;> rfl

theorem forall₂_length {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β}
    (h : LangSemantics.Core.List.Forall₂ R xs ys) : xs.length = ys.length := by
  induction h with
  | nil => rfl
  | cons _ _ ih => simp [ih]

/-- 検査の列の、最初に失敗した検査の結果。 -/
def firstErr {ε : Type} : List (Except ε Unit) → Except ε Unit
  | [] => .ok ()
  | .ok () :: rs => firstErr rs
  | .error e :: _ => .error e

/-- `for` 文の 1 回分の結果の対応: どちらも成功して次へ進むか、[Source] が業務例外を投げ、[Spec] が同じコードと引数の
`Business` を返す。 -/
def AgreeStep (r : JResult (ForInStep PUnit)) (x : Except Spec.Error.AtrsError Unit) : Prop :=
  (r = .ok (.yield ()) ∧ x = .ok ()) ∨ ∃ c args, r = .error (AtrsBusinessException.newArgs c args) ∧ x = .error (.business c args)

/-- 要素ごとの検査の `for` 文と、[Spec] の検査の列の最初の失敗の対応。 -/
theorem forIn_agree {α : Type} (f : α → PUnit → JResult (ForInStep PUnit)) :
    ∀ {l : List α} {ss : List (Except Spec.Error.AtrsError Unit)},
      LangSemantics.Core.List.Forall₂ (fun a s => AgreeStep (f a ()) s) l ss →
      AgreeB (do forIn l () f; pure ()) (firstErr ss)
  | [], [], .nil => .inl ⟨rfl, rfl⟩
  | a :: l, s :: ss, .cons h hr => by
    rw [List.forIn_cons]
    rcases h with ⟨hf, rfl⟩ | ⟨c, args, hf, rfl⟩
    · have ih := forIn_agree f hr
      simp only [hf, bind, Except.bind, firstErr] at ih ⊢
      exact ih
    · exact .inr ⟨c, args, by simp only [hf, bind, Except.bind], rfl⟩

/-- 運賃種別の利用条件の検査（予約フライトを順に）。すべての予約フライトが同じ搭乗者の列 `xs`（[Spec] の `qs`）を持つ。 -/
theorem fareTypes {xs : List SourceModel.Domain.Model.Passenger} {qs : List Spec.Model.Passenger}
    (hg : LangSemantics.Core.List.Forall₂ (fun x q => x.gender = some q.gender) xs qs) (hne : xs ≠ [])
    (hlen : xs.length ≤ 6) {fls : List SourceModel.Domain.Model.Flight} {FTs : List Spec.MasterData.FareType}
    (h : LangSemantics.Core.List.Forall₂ FareTypeFacts fls FTs) :
    AgreeB (TicketReserveServiceImpl.validateFareType
        (fls.map fun fl => some { flight := some fl, passengerList := some (xs.map some) }))
      (firstErr (FTs.map (specFareTypeOf · qs))) := by
  have hnev : LangSemantics.Java.Spring.Assert.notEmptyValue (some (xs.map some)) "passengerList must not empty." =
      pure (xs.map some) := by
    cases xs with
    | nil => exact absurd rfl hne
    | cons x xs' => rfl
  unfold TicketReserveServiceImpl.validateFareType
  apply forIn_agree
  refine LangSemantics.Core.List.Forall₂.map_of (fun fl FT hf => ?_) h
  obtain ⟨ft, m, h1, h2, h3, h4, h5⟩ := hf
  simp only [LangSemantics.Java.Spring.Assert.notNullValue_some, LangSemantics.Java.EStateSimp.deref_some, h1, h2,
    h3, h4, hnev, pure_bind, LangSemantics.Java.EStateSimp.except_ok_bind, Option.some.injEq, Option.getD_some]
  unfold specFareTypeOf
  cases hcd : FT.fareTypeCd <;> simp only [hcd, reduceCtorEq, ite_false, ite_true] at h2 ⊢
  case LD =>
    rw [List.forIn_map, forIn_check _ (fun x => x.gender == some .M) _ ladies_body, any_gender_eq hg]
    cases qs.any (·.gender == .M)
    · exact .inl ⟨rfl, rfl⟩
    · exact .inr ⟨"e.ar.b2.2007", [], rfl, rfl⟩
  case GD =>
    have hl : (J32.ofInt ((List.map some xs).length : Int)).val = (qs.length : Int) := by
      rw [List.length_map, LangSemantics.Java.IntLemmas.ofInt_nat (by omega), forall₂_length hg]
    simp only [hl, h5, toString_int_ofNat]
    by_cases hlt : qs.length < FT.passengerMinNum
    · have : (qs.length : Int) < FT.passengerMinNum := by omega
      simp only [this, hlt, decide_true, ite_true]
      exact .inr ⟨_, _, rfl, rfl⟩
    · have : ¬ (qs.length : Int) < FT.passengerMinNum := by omega
      simp only [this, hlt, decide_false, Bool.false_eq_true, ite_false]
      exact .inl ⟨rfl, rfl⟩
  all_goals exact .inl ⟨rfl, rfl⟩

end Abstraction.Reserve.Validate
