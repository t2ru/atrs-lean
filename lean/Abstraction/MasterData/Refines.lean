import Abstraction.MasterData.Query

/-!
# Abstraction.MasterData.Refines

R 課題 ABS-026: マスタ・設定・コードリストの読み込み（`SourceModel.MasterQuery.queryConcrete`）は、既知差異 D-027 の
前提（`dev_D027`）の下で、[Spec] の `Spec.MasterData.queryMachine` をリファインする。Mapper の結果のどの許される
並びでも成り立つ。あわせて、付帯の義務（`InitSurj`）と、D-027 の必要性（W 課題 ABS-127）を示す。
-/

namespace Abstraction.MasterData

open Machine LangSemantics.Java LangSemantics.Sql Spec Spec.Prim Abstraction.Prim
  SourceModel.Repository.Schema SourceModel.Repository.MasterData SourceModel.MasterData SourceModel.MasterQuery

/-- 標準の貼り合わせ。 -/
abbrev glueMQ := Glue.ofStd betaMQ (fun _ => True) aiMQ answerOf?

/-- 前提を満たす DB では、どの許される並びでも起動時の読み込み `load` は例外を投げない。搭乗クラスのキャッシュは
[Spec] の搭乗クラスの参照に対応し、ピーク時期のキャッシュは並びの写しである（運賃計算の R 課題で使う）。 -/
theorem load_correct {db : MasterDb} {cfg : Config} {md : MasterData} (hm : masterDataOf db = some md)
    (hv : md.Valid cfg) {o : Order} (ho : o.Allowed db) :
    ∃ p, load o = .ok p ∧ p.peakTime = PeakTimeProvider.load o.peakTime ∧
      ∀ cd : BoardingClassCd, answerOf? (.boardingClass (p.boardingClass.boardingClassCodeMap.get cd)) =
        some (.boardingClass ((md.boardingClassOf cd).map (·.info))) := by
  obtain ⟨-, -, -, hbcs, hfts, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨hpr, hpf, hpb, hpft, -, -, -, -, -⟩ := ho
  obtain ⟨bcp, hbl, hbq⟩ := boardingClass_query hbcs hv.md1.2.2.2.1 hpb
  obtain ⟨ftp, hfl, -⟩ := fareType_query hfts hv.md1.2.2.2.2.1 hpft
  obtain ⟨rtp, hrl, -⟩ := route_query hm hv.md1 hv.md2 hv.md3 hv.md8 hpr
  obtain ⟨fmp, hml, -⟩ := flightMaster_query hm hv.md1 hv.md3 hv.md8 hpf
  refine ⟨_, by simp only [load, hbl, hfl, hrl, hml, ok_bind]; rfl, rfl, fun cd => hbq cd⟩

/-- 前提を満たす入力では、どの許される並びでも `run` は例外を投げず、答えの写しは [Spec] の答え。 -/
theorem run_correct {ic : SrcInput} {cfg : Config} {md : MasterData} {q : MasterData.Query}
    (hα : aiMQ ic = some (cfg, md, q)) (hv : md.Valid cfg) (hq : q.Valid) {o : Order} (ho : o.Allowed ic.db) :
    ∃ a, run ic o = .ok a ∧ answerOf? a = some (MasterData.answer cfg md q) := by
  obtain ⟨hc, hm, hqq⟩ := aiMQ_eq_some.mp hα
  obtain ⟨-, -, -, hbcs, hfts, -⟩ := masterDataOf_eq_some.mp hm
  obtain ⟨hpr, hpf, hpb, hpft, hppt, hoa, hob, hof, hoc⟩ := ho
  obtain ⟨bcp, hbl, hbq⟩ := boardingClass_query hbcs hv.md1.2.2.2.1 hpb
  obtain ⟨ftp, hfl, hfq⟩ := fareType_query hfts hv.md1.2.2.2.2.1 hpft
  obtain ⟨rtp, hrl, hrq⟩ := route_query hm hv.md1 hv.md2 hv.md3 hv.md8 hpr
  obtain ⟨fmp, hml, hmq⟩ := flightMaster_query hm hv.md1 hv.md3 hv.md8 hpf
  simp only [run, load, hbl, hfl, hrl, hml, ok_bind, pure_bind, Providers.shared]
  generalize ic.query = sq at hqq ⊢
  cases sq with
  | routeOf dep arr =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    obtain ⟨ans, he, ha⟩ := hrq ⟨dep⟩ ⟨arr⟩ hq.1 hq.2
    exact ⟨_, by simp only [he, ok_bind]; rfl, ha⟩
  | flightMasterOf name =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    obtain ⟨ans, he, ha⟩ := hmq ⟨name⟩ hq.2
    exact ⟨_, by simp only [he, ok_bind]; rfl, ha⟩
  | fareTypeOf cd =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    exact ⟨_, rfl, hfq cd⟩
  | boardingClassOf cd =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    exact ⟨_, rfl, hbq cd⟩
  | peakTimeOn d =>
    simp only [queryOf?, Option.map_eq_some_iff] at hqq
    obtain ⟨D, hd, rfl⟩ := hqq
    obtain ⟨ans, he, ha⟩ := peakTime_query hm hv.md4 hppt hd
    exact ⟨_, by simp only [he, ok_bind]; rfl, ha⟩
  | multiplicationRatioOn d =>
    simp only [queryOf?, Option.map_eq_some_iff] at hqq
    obtain ⟨D, hd, rfl⟩ := hqq
    obtain ⟨n, he, ha⟩ := ratio_query hm hv.md4 hppt hd bcp
    exact ⟨_, by simp only [he, ok_bind]; rfl, ha⟩
  | config =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    refine ⟨_, rfl, ?_⟩
    simp only [answerOf?, hc, Option.map_some, MasterData.answer]
  | codeList n =>
    simp only [queryOf?, Option.some.injEq] at hqq; subst hqq
    refine ⟨_, rfl, ?_⟩
    simp only [answerOf?, MasterData.answer, Option.some.injEq, MasterData.Answer.codeList.injEq]
    obtain ⟨f1, f2, f3, f4⟩ := codeList_fixed
    cases n
    · exact codeList_airport hm hv.md1 hv.md8 hoa
    · exact codeList_boardingClass hm hv.md1 hob
    · exact codeList_fareType hm hv.md1 hof
    · exact codeList_creditType hm hv.md1 hoc
    · exact f1
    · exact f2
    · exact f3
    · exact f4

/-- 許される並びの 1 つ: 順序の無い文は評価の結果のまま、`ORDER BY display_order` の文は表示順で `mergeSort`。 -/
def mergeOrder (db : MasterDb) : Order where
  route := routeFindAll db
  flightMaster := flightMasterFindAll db
  boardingClass := boardingClassFindAll db
  fareType := fareTypeFindAll db
  peakTime := peakTimeFindAll db
  airportCl := (airportCodeListRows db).mergeSort fun a b => decide (a.displayOrder.val ≤ b.displayOrder.val)
  boardingClassCl := (boardingClassCodeListRows db).mergeSort fun a b => decide (a.displayOrder.val ≤ b.displayOrder.val)
  fareTypeCl := (fareTypeCodeListRows db).mergeSort fun a b => decide (a.displayOrder.val ≤ b.displayOrder.val)
  creditTypeCl := (creditTypeCodeListRows db).mergeSort fun a b => decide (a.displayOrder.val ≤ b.displayOrder.val)

theorem mergeOrder_allowed (db : MasterDb) : (mergeOrder db).Allowed db :=
  ⟨List.Perm.refl _, List.Perm.refl _, List.Perm.refl _, List.Perm.refl _, List.Perm.refl _,
    allowed_mergeSort_self _ _ (fun r : AirportRow => r.displayOrder.val),
    allowed_mergeSort_self _ _ (fun r : BoardingClassRow => r.displayOrder.val),
    allowed_mergeSort_self _ _ (fun r : FareTypeRow => r.displayOrder.val),
    allowed_mergeSort_self _ _ (fun r : CreditTypeRow => r.displayOrder.val)⟩

/-- R 課題 ABS-026。 -/
@[obligation "ABS-026"]
theorem queryRefines : Refines MasterData.queryMachine (queryConcrete.restrict dev_D027) glueMQ where
  init _ _ := ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩
  input_total ic hd := by
    obtain ⟨ia, h⟩ := Option.isSome_iff_exists.mp hd.2
    exact ⟨ia, h⟩
  applicable s t ic ia _ _ hα hpre _ := by
    obtain ⟨cfg, md, q⟩ := ia
    have hα' : aiMQ ic = some (cfg, md, q) := hα
    refine ⟨⟨_, mergeOrder ic.db, mergeOrder_allowed ic.db, rfl⟩, fun e ⟨o, ho, he⟩ => ?_⟩
    obtain ⟨a, hr, -⟩ := run_correct hα' hpre.2.1 hpre.2.2 ho
    rw [hr] at he
    cases he
  correct s t ic ia t' oc _ _ hα hpre _ hs := by
    obtain ⟨cfg, md, q⟩ := ia
    have hα' : aiMQ ic = some (cfg, md, q) := hα
    obtain ⟨o, ho, he⟩ := hs
    obtain ⟨a, hr, ha⟩ := run_correct hα' hpre.2.1 hpre.2.2 ho
    rw [hr] at he
    simp only [Except.map, Except.ok.injEq, Prod.mk.injEq] at he
    obtain ⟨-, rfl⟩ := he
    exact ⟨(), _, rfl, Or.inl ⟨rfl, trivial⟩, Or.inl ha⟩

/-- 付帯の義務: 抽象側の初期状態は、具体側の初期状態の像。 -/
theorem queryRefines_initSurj : Refines.InitSurj MasterData.queryMachine (queryConcrete.restrict dev_D027) glueMQ :=
  fun _ _ => ⟨(), trivial, Or.inl ⟨rfl, trivial⟩⟩

/-- W 課題 ABS-127（D-027 の必要性。G9）: 前提を外すと、ABS-026 は成り立たない。未知の搭乗クラスコード `X` の行を
持つ DB では α が定義されず、入力の全域性が破れる。 -/
@[obligation "ABS-127"]
theorem need_D027 : ¬ Refines MasterData.queryMachine queryConcrete glueMQ := fun h => by
  obtain ⟨ia, hia⟩ := h.input_total ic_unknownBoardingClass trivial
  have : aiMQ ic_unknownBoardingClass = none := by decide
  rw [show glueMQ.αi ic_unknownBoardingClass ia = (aiMQ ic_unknownBoardingClass = some ia) from rfl, this] at hia
  cases hia

/-- ABS-127 の [Source] の振る舞い: 未知の搭乗クラスコード `X` の行を持つ DB では、どの許される並びでも、
読み込み（`BoardingClassProvider.load` の `Enum.valueOf`）が `IllegalArgumentException` を投げる。 -/
theorem unknownBoardingClass_throws {r : Except JThrow (Unit × SrcAnswer)}
    (h : queryConcrete.step () ic_unknownBoardingClass r) : ∃ msg, r = .error (.illegalArgument msg) := by
  obtain ⟨o, ho, rfl⟩ := h
  have hb : o.boardingClass = boardingClassFindAll ic_unknownBoardingClass.db :=
    List.perm_singleton.mp ho.2.2.1
  refine ⟨"No enum constant BoardingClassCd.X", ?_⟩
  simp only [run, load, hb, BoardingClassProvider.load, ic_unknownBoardingClass, boardingClassFindAll, Bag.project,
    List.map_cons, List.map_nil, List.mapM_cons, SourceModel.Repository.Mapping.boardingClass,
    SourceModel.Repository.Mapping.boardingClassCd]
  rfl

end Abstraction.MasterData
