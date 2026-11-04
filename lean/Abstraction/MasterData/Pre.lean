import Abstraction.MasterData.Alpha
import Abstraction.MasterData.Load
import LangSemantics.Core.MapM

/-!
# Abstraction.MasterData.Pre

ABS-026 の証明の前提の取り出し。`aiMQ` が定義されることと [Spec] の PRE（MD-1〜MD-8・`Query.Valid`）から、
DB の行と [Source] の対応（MyBatis の対応・`Assert.hasText`）について使う事実を導く。
-/

namespace Abstraction.MasterData.Pre
open Abstraction.MasterData.Alpha Abstraction.MasterData.AlphaLeaf Spec.MasterQuery Spec.Model
  Spec.Prim.Text
open LangSemantics.Core.List LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
  LangSemantics.Java.String

open LangSemantics.Java LangSemantics.Sql.Postgresql Spec Spec.Env LangSemantics.Core
open LangSemantics.Java.Spring SourceModel.Db.Schema SourceModel.MasterQuery SourceModel.AtrsProperties

/-! ## α の分解 -/

theorem aiMQ_eq_some {ic : SrcInput} {cfg : Config} {md : MasterData} {q : Spec.MasterQuery.Query} :
    aiMQ ic = some (cfg, md, q) ↔
      configOf ic.config = some cfg ∧ masterDataOf ic.db = some md ∧ queryOf? ic.query = some q := by
  simp only [aiMQ, Option.bind_eq_some_iff, Option.map_eq_some_iff, Prod.mk.injEq]
  constructor
  · rintro ⟨c, hc, m, hm, q', hq, rfl, rfl, rfl⟩; exact ⟨hc, hm, hq⟩
  · rintro ⟨hc, hm, hq⟩; exact ⟨cfg, hc, md, hm, q, hq, rfl, rfl, rfl⟩

theorem masterDataOf_eq_some {db : MasterDb} {md : MasterData} :
    masterDataOf db = some md ↔
      db.airport.mapM airportOfRow = some md.airports ∧ db.route.mapM routeOfRow = some md.routes ∧
      db.flightMaster.mapM flightMasterOfRow = some md.flightMasters ∧
      db.boardingClass.mapM boardingClassOfRow = some md.boardingClasses ∧
      db.fareType.mapM fareTypeOfRow = some md.fareTypes ∧ db.peakTime.mapM peakTimeOfRow = some md.peakTimes ∧
      db.plane.mapM planeOfRow = some md.planes ∧ db.creditType.mapM creditTypeOfRow = some md.creditTypes := by
  obtain ⟨a, r, f, b, ft, p, pl, c⟩ := md
  simp only [masterDataOf, Option.bind_eq_some_iff, Option.map_eq_some_iff, MasterData.mk.injEq]
  constructor
  · rintro ⟨a', ha, r', hr, f', hf, b', hb, ft', hft, p', hp, pl', hpl, c', hc, rfl, rfl, rfl, rfl, rfl, rfl, rfl,
      rfl⟩
    exact ⟨ha, hr, hf, hb, hft, hp, hpl, hc⟩
  · rintro ⟨ha, hr, hf, hb, hft, hp, hpl, hc⟩
    exact ⟨a, ha, r, hr, f, hf, b, hb, ft, hft, p, hp, pl, hpl, c, hc, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-! ## 文字 -/

/-- [Spec] の空白（`Blank`）は、Java の `Character.isWhitespace` と同じ文字の集合。 -/
theorem isBlank_eq_isJavaWhitespace (c : Char) : isBlank c = isJavaWhitespace c := by
  simp only [isBlank, inRange, isJavaWhitespace]
  generalize c.toNat = n
  rw [Bool.eq_iff_iff]
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, bne_iff_ne, ne_eq]
  omega

/-- [Spec] の `hasText` が成り立てば、原典の `Assert.hasText` は通る。 -/
theorem assertHasText_ok {s : String} (h : hasText s = true) (m : String) :
    LangSemantics.Java.Spring.Assert.hasText s m = .ok () := by
  simp only [LangSemantics.Java.Spring.Assert.hasText, Assert.isTrue]
  have : (s.any fun c => !isJavaWhitespace c) = true := by
    have e : (fun c => !isJavaWhitespace c) = (fun c => !isBlank c) :=
      funext fun c => by rw [isBlank_eq_isJavaWhitespace]
    rw [e]; exact h
  simp [this]

theorem isUpperAlpha_not_blank {c : Char} (h : isUpperAlpha c = true) : isBlank c = false := by
  simp only [isUpperAlpha, inRange, Bool.and_eq_true, decide_eq_true_eq] at h
  simp only [isBlank, inRange, Bool.or_eq_false_iff, Bool.and_eq_false_iff, decide_eq_false_iff_not, Nat.not_le]
  omega

/-- 空港コードの形式（`AirportCd.valid`）を満たす文字列は空白でない。 -/
theorem AirportCd.hasText_of_valid {s : String} (h : AirportCd.valid s = true) : hasText s = true := by
  simp only [AirportCd.valid, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨hl, ha⟩ := h
  rw [hasText, string_any_toList]
  cases hs : s.toList with
  | nil => rw [hs] at hl; cases hl
  | cons x xs =>
    rw [hs] at ha
    have hx : isUpperAlpha x = true := (List.all_eq_true.mp ha) x (List.mem_cons_self ..)
    simp [isUpperAlpha_not_blank hx]

/-- 空港コードの形式（`AirportCd.valid`）を満たす文字列は `-` を含まない（`RouteProvider.makeCacheKey` の区切り）。 -/
theorem AirportCd.no_dash_of_valid {s : String} (h : AirportCd.valid s = true) : '-' ∉ s.toList := by
  intro hm
  simp only [AirportCd.valid, Bool.and_eq_true] at h
  have := (List.all_eq_true.mp h.2) '-' hm
  simp [isUpperAlpha, inRange] at this

/-- 空港コードは空白でない。 -/
theorem AirportCd.hasText_val (c : AirportCd) : hasText c.val = true := AirportCd.hasText_of_valid c.wf

/-- 空港コードは `-` を含まない（`RouteProvider.makeCacheKey` の区切り）。 -/
theorem AirportCd.no_dash (c : AirportCd) : '-' ∉ c.val.toList := AirportCd.no_dash_of_valid c.wf

/-! ## 値の対応 -/

theorem natOfJ32_int {v : Int4} : (SourceModel.Db.MyBatis.int v).bind natOfJ32 = natOfInt4 v := by
  have h := J32.val_ofInt_of_inRange v.val ⟨by
    have := v.property.1; simp only [J32.minValue]; omega, by
    have := v.property.2; simp only [J32.maxValue]; omega⟩
  simp only [SourceModel.Db.MyBatis.int, Option.bind_some, natOfJ32, natOfInt4, h]

theorem bcCdOf_mapping {s : String} {c : BoardingClassCd} (h : bcCdOf s = some c) :
    SourceModel.Domain.Model.BoardingClassCd.valueOf s = .ok c := by
  rw [bcCdOf_eq_some h]; cases c <;> rfl

theorem ftCdOf_mapping {s : String} {c : FareTypeCd} (h : ftCdOf s = some c) :
    SourceModel.Domain.Model.FareTypeCd.valueOf s = .ok c := by
  rw [ftCdOf_eq_some h]; cases c <;> rfl

end Abstraction.MasterData.Pre
