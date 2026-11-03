import Abstraction.World.Alpha
import LangSemantics.Core.MapM
import Abstraction.Reserve.Member
import Abstraction.Reserve.Vacancy

/-!
# Abstraction.Reserve.FlightFacts

ABS-041 の補題: 予約の登録の挿入の文の前提（backlog aedf の第 3 段）。主キーで取れるフライトの行の存在と便名の長さ、
`findMember` で見つかる会員の行の存在と会員番号の長さ、選択フライト情報から作ったフライト情報の搭乗クラス・運賃種別の
コード。
-/

namespace Abstraction.Reserve.FlightFacts
open Abstraction.World.Alpha SourceModel.Db.Schema

/-- 主キーで取れるフライトは、FLIGHT の行の α で、その便名は 6 文字以内（`VARCHAR(6)`）。 -/
theorem flight_row {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) {k : Spec.Model.FlightKey}
    {fx : Spec.Model.Flight} (hfx : w.findForUpdate k = some fx) :
    (∃ r ∈ fd.flight, ∃ fx', flightOfRow r = some fx' ∧ fx'.key = k) ∧ k.flightName.val.length ≤ 6 := by
  have hm := worldOfDb_flights hw
  have hmem : fx ∈ w.flights := List.mem_of_find?_eq_some hfx
  have hk : fx.key = k := by simpa using List.find?_some hfx
  obtain ⟨r, hr, hrf⟩ := LangSemantics.Core.MapM.mapM_some_mem' hm hmem
  refine ⟨⟨r, hr, fx, hrf, hk⟩, ?_⟩
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at hrf
  obtain ⟨_, -, n, hn, _, -, _, -, _, -, rfl⟩ := hrf
  rw [← hk]
  show n.val.length ≤ 6
  rw [Abstraction.MasterData.AlphaLeaf.flightNameOf_eq_some hn]
  exact r.flightName.property

/-- `findMember` で見つかる会員番号は、MEMBER の行の会員番号で、10 文字以内（`VARCHAR(10)`）で、会員番号の形式に合う。 -/
theorem member_row {fd : FlightDb} {w : Spec.Port.World} (hw : worldOfDb fd = some w) {s : String}
    {x : Spec.Model.Member} (hx : w.findMember s = some x) :
    s.length ≤ 10 ∧ fd.member.any (·.customerNo.val == s) = true ∧ Spec.Model.MembershipNumber.valid s = true := by
  have hval : Spec.Model.MembershipNumber.valid s = true :=
    Spec.Model.MembershipNumber.ofString?_isSome_iff.mp (by rw [Spec.Port.World.findMember_ofString? hx]; rfl)
  have hms := (worldOfDb_eq_some.mp hw).2.1
  have hf := Abstraction.Reserve.Member.membersOf_find hms s
  unfold Spec.Port.World.findMember at hx
  rw [hx] at hf
  obtain ⟨m, l, e1, -, -⟩ := hf
  have hs : m.customerNo.val = s := by simpa using List.find?_some e1
  refine ⟨hs ▸ m.customerNo.property, List.any_eq_true.mpr ⟨m, List.mem_of_find?_eq_some e1, by simp [hs]⟩, hval⟩

section
open Abstraction.MasterData.Alpha Abstraction.Fare.TotalFareRun Abstraction.Fare.TotalAlpha Spec.Model

/-- 選択フライト情報から作ったフライト情報の搭乗クラス・運賃種別のオブジェクトは、主キーのコードを持つ（マスタにある場合）。 -/
theorem mkFlight_codes {md : Spec.MasterData} {p : SourceModel.MasterQuery.Providers}
    (hbq : ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
      some (.boardingClass ((md.boardingClassOf cd).map (·.info))))
    (hfq : ∀ cd : FareTypeCd, answerOf? (.fareType (p.fareType.fareTypeMap.get cd)) =
      some (.fareType ((md.fareTypeOf cd).map (·.info))))
    {f : SourceModel.App.B0.SelectFlightForm} {k : FlightKey} (hk : keyOfForm f = some k)
    {BC : Spec.MasterData.BoardingClass} {FT : Spec.MasterData.FareType}
    (hb : md.boardingClassOf k.boardingClassCd = some BC) (hf : md.fareTypeOf k.fareTypeCd = some FT) :
    ∃ dj b t, (mkFlight p f).departureDate = some dj ∧ Abstraction.MasterData.AlphaLeaf.dateOfJ dj = some k.departureDate ∧
      (mkFlight p f).boardingClass = some b ∧ b.boardingClassCd = some k.boardingClassCd ∧
      (mkFlight p f).fareType = some t ∧ t.fareTypeCd = some k.fareTypeCd := by
  obtain ⟨dj, hdj, hd, hn, hbc, hft⟩ := keyOfForm_eq hk
  have hb' := hbq k.boardingClassCd
  rw [hb] at hb'
  have hBC : BC.boardingClassCd = k.boardingClassCd := by
    have := List.find?_some hb; simpa using this
  obtain ⟨b, e, hbe, hbcd, -⟩ := Abstraction.Fare.Load.boardingClass_of_answer (by simpa [hBC] using hb')
  have hf' := hfq k.fareTypeCd
  rw [hf] at hf'
  have hFT : FT.fareTypeCd = k.fareTypeCd := by
    have := List.find?_some hf; simpa using this
  obtain ⟨t, d, hte, htcd, -, -⟩ := Abstraction.FlightSearch.Providers.fareType_of_answer' (by simpa using hf')
  refine ⟨dj, b, t, by simp [mkFlight, hdj], hd, by simp [mkFlight, hbc, hbe], by rw [hbcd, hBC],
    by simp [mkFlight, hft, hte], by rw [htcd, hFT]⟩

end

end Abstraction.Reserve.FlightFacts
