import Abstraction.Fare.Alpha

/-!
# Abstraction.Fare.TotalAlpha

合計金額の R 課題（ABS-004）の標準の抽象化 α と、前提型の差異の述語。

- 入力の α: ABS-026 の `configOf`・`masterDataOf` と、選択フライト情報（`keyOfForm`）・搭乗者の年齢（`ageOfPassenger`）。
- 差異: D-001・D-002 はフライトごとに基本運賃・運賃の前提（`dev_D001`・`dev_D002` と同じ形）を課す。D-012 は、
  フライトごとに小児分の途中計算 `b × (childFareRate − r)` が int32 に収まること。D-027 は具体側の入力が表せること。
-/

namespace Abstraction.Fare
open LangSemantics.Core.List LangSemantics.Core.MapM LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String Machine.Adequacy Machine.Kernel

open Machine LangSemantics.Java Spec Spec.Prim LangSemantics.Core Abstraction.MasterData SourceModel.FareQuery

/-! ## 入力（合成） -/

/-- 選択フライト情報: 出発日・便名・搭乗クラス・運賃種別（`null` には定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def keyOfForm (f : SourceModel.Ticket.SelectFlightForm) : Option FlightKey :=
  (f.depDate.bind dateOfJ).bind fun d => f.flightName.bind fun n => f.boardingClassCd.bind fun bc =>
    f.fareTypeCd.map fun ft => ⟨d, ⟨n⟩, bc, ft⟩

/-- 搭乗者の年齢（`null` と負の値には定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def ageOfPassenger (p : JRef SourceModel.Model.Passenger) : Option Nat :=
  (p.bind (·.age)).bind natOfJ32

/-- 合計金額の入力: 設定・マスタ・フライトのキーの列・搭乗者の年齢の列。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiTF (ic : TotalFareInput) : Option Spec.Fare.TotalFareInput :=
  (configOf ic.config).bind fun cfg => (masterDataOf ic.db).bind fun md =>
    (ic.flights.mapM keyOfForm).bind fun ks => (ic.passengers.mapM ageOfPassenger).map fun ages => ⟨cfg, md, ks, ages⟩

/-- 合計金額の標準の貼り合わせ。 -/
abbrev glueTF := Glue.ofStd betaMQ (fun _ => True) aiTF natOfJ32

/-! ## 前提型の差異 -/

/-- 便の基本運賃の元（区間の運賃 + 加算料金）と、出発日の積算比率。 -/
def keyBasic (md : MasterData) (k : FlightKey) : Option (Nat × Nat) := do
  let rt ← Spec.Fare.routeOfFlightName md k.flightName
  let bc ← md.boardingClassOf k.boardingClassCd
  return (rt.basicFare + bc.extraCharge, md.multiplicationRatioOn k.departureDate)

/-- 便の基本運賃と割引率。 -/
def keyFare (md : MasterData) (k : FlightKey) : Option (Nat × Nat) := do
  let xc ← keyBasic md k
  let ft ← md.fareTypeOf k.fareTypeCd
  return (xc.1 * xc.2 / 100, ft.discountRate)

/-- D-027（合計金額）: 具体側の入力（DB のマスタ・設定・選択フライト情報・搭乗者）が [Spec] の型で表せる。 -/
@[deviation "D-027"]
def dev_D027TF (ic : TotalFareInput) : Prop := (aiTF ic).isSome = true

/-- D-001（合計金額）: 各フライトで、基本運賃の前提（`dev_D001` と同じ形）。 -/
@[deviation "D-001"]
def dev_D001T (i : Spec.Fare.TotalFareInput) : Prop :=
  ∀ k ∈ i.flights, (keyBasic i.md k).all (fun xc => decide (xc.1 * xc.2 % 100 ≠ 0 ∨ xc.2 ∉ unsafeBasicRatios)) = true

/-- D-002（合計金額）: 各フライトで、運賃の前提（`dev_D002` と同じ形）。 -/
@[deviation "D-002"]
def dev_D002T (i : Spec.Fare.TotalFareInput) : Prop :=
  ∀ k ∈ i.flights, (keyFare i.md k).all (fun br => decide (br.1 * (100 - br.2) % 10000 ≠ 100 ∨ br.2 ∉ unsafeDiscountRates)) = true

/-- D-012: 各フライトで、小児分の途中計算 `b × (childFareRate − r)` が int32 の最大値以下。 -/
@[deviation "D-012"]
def dev_D012 (i : Spec.Fare.TotalFareInput) : Prop :=
  ∀ k ∈ i.flights, (keyFare i.md k).all (fun br => decide (br.1 * (i.cfg.childFareRate - br.2) ≤ 2147483647)) = true

instance : DecidablePred dev_D001T := fun i => by unfold dev_D001T; infer_instance
instance : DecidablePred dev_D002T := fun i => by unfold dev_D002T; infer_instance
instance : DecidablePred dev_D012 := fun i => by unfold dev_D012; infer_instance

/-! ## 例（差異の述語の非自明性と、W 課題の証人） -/

/-- 空港 2 つ・区間 1 つ（運賃 `bf`）・便 1 つ・搭乗クラス N（加算料金 0）・運賃種別 OW（割引率 `disc`）・
1970-01-01 の積算比率 `ratio` のピーク時期を持つ DB。 -/
def dbTF (bf ratio disc : LangSemantics.Sql.Postgresql.Int4) : SourceModel.Repository.Schema.MasterDb :=
  { airport := [⟨⟨"HND", by decide⟩, ⟨"Haneda", by decide⟩, ⟨1, by decide⟩⟩,
      ⟨⟨"ITM", by decide⟩, ⟨"Itami", by decide⟩, ⟨2, by decide⟩⟩],
    route := [⟨⟨1, by decide⟩, ⟨"HND", by decide⟩, ⟨"ITM", by decide⟩, ⟨"0100", by decide⟩, bf⟩],
    flightMaster := [⟨⟨"NTT001", by decide⟩, ⟨1, by decide⟩, ⟨"0800", by decide⟩, ⟨"0900", by decide⟩,
      ⟨"B777", by decide⟩⟩],
    boardingClass := [⟨⟨"N", by decide⟩, some ⟨"N", by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩⟩],
    fareType := [⟨⟨"OW", by decide⟩, ⟨"OW", by decide⟩, disc, ⟨355, by decide⟩, ⟨0, by decide⟩, ⟨1, by decide⟩,
      ⟨1, by decide⟩⟩],
    peakTime := [⟨⟨"P", by decide⟩, ⟨0, by decide⟩, ⟨0, by decide⟩, ratio⟩] }

/-- 1970-01-01 の NTT001・N・OW を 1 つ選び、搭乗者の年齢を `ages` とする入力。 -/
def icTF (bf ratio disc : LangSemantics.Sql.Postgresql.Int4) (ages : List Int) : TotalFareInput :=
  { db := dbTF bf ratio disc, config := SourceModel.Config.upstreamConfig,
    flights := [SourceModel.Ticket.SelectFlightForm.mk (some ⟨1970, 1, 1⟩) (some "NTT001") (some FareTypeCd.OW)
      (some BoardingClassCd.N)],
    passengers := ages.map fun a => some ({ age := some (J32.ofInt a) } : SourceModel.Model.Passenger) }

/-- D-012 の差異が起きる入力: 区間の運賃 10,000,000 円・積算比率 1000%（基本運賃 1 億円）・割引率 0・小児 1 名。 -/
def icTF012 : TotalFareInput := icTF ⟨10000000, by decide⟩ ⟨1000, by decide⟩ ⟨0, by decide⟩ [5]

/-- 1970-01-01。 -/
def day0 : Spec.Prim.Date := ⟨1970, 1, 1, by decide⟩

/-- `icTF012` の DB の [Spec] の写し。 -/
def mdTF012 : MasterData :=
  { airports := [⟨⟨"HND"⟩, "Haneda", 1⟩, ⟨⟨"ITM"⟩, "Itami", 2⟩],
    routes := [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 10000000⟩],
    flightMasters := [⟨⟨"NTT001"⟩, 1, ⟨8, 0, by decide⟩, ⟨9, 0, by decide⟩, "B777"⟩],
    boardingClasses := [⟨.N, "N", 0, 1⟩],
    fareTypes := [⟨.OW, "OW", 0, 355, 0, 1, 1⟩],
    peakTimes := [⟨"P", day0, day0, 1000⟩],
    planes := [], creditTypes := [] }

/-- `icTF012` の [Spec] の入力。 -/
def iaTF012 : Spec.Fare.TotalFareInput := ⟨Config.default, mdTF012, [⟨day0, ⟨"NTT001"⟩, .N, .OW⟩], [5]⟩

theorem aiTF_icTF012 : aiTF icTF012 = some iaTF012 := by
  rfl

theorem iaTF012_pre : iaTF012.Pre := by
  refine ⟨by decide, ⟨by decide, by decide, by decide, by decide, by decide, by decide, by decide, ?_⟩,
    by decide, by decide, by decide, by decide, by decide, ?_, by decide⟩
  · refine ⟨?_, by decide, by decide, by decide⟩
    intro a ha
    simp only [iaTF012, mdTF012, List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl <;> exact ⟨⟨by decide, by rw [String.all_bool_eq]; decide⟩, by decide⟩
  · intro k hk
    simp only [iaTF012, List.mem_cons, List.not_mem_nil, or_false] at hk
    subst hk
    rw [hasText, string_any_toList]
    decide

theorem iaTF012_devs : dev_D001T iaTF012 ∧ dev_D002T iaTF012 ∧ ¬ dev_D012 iaTF012 := by
  decide

/-- 前提を満たさない入力: 便名が `null`。 -/
def icTFnull : TotalFareInput :=
  ⟨dbTF ⟨100, by decide⟩ ⟨100, by decide⟩ ⟨0, by decide⟩, SourceModel.Config.upstreamConfig,
    [SourceModel.Ticket.SelectFlightForm.mk (some ⟨1970, 1, 1⟩) none (some FareTypeCd.OW) (some BoardingClassCd.N)],
    []⟩

/-- フライトの無い入力（各フライトの述語は自明に成り立つ）。 -/
def iaTFempty : Spec.Fare.TotalFareInput := ⟨Config.default, mdTF012, [], []⟩

/-- D-001 の前提を破る入力: 区間の運賃 100 円・積算比率 29%。 -/
def mdTF29 : MasterData :=
  ⟨mdTF012.airports, [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 100⟩], mdTF012.flightMasters, mdTF012.boardingClasses, mdTF012.fareTypes,
    [⟨"P", day0, day0, 29⟩], [], []⟩

def iaTF29 : Spec.Fare.TotalFareInput := ⟨Config.default, mdTF29, iaTF012.flights, [5]⟩

/-- D-002 の前提を破る入力: 基本運賃 1430 円・割引率 30%。 -/
def mdTF1430 : MasterData :=
  ⟨mdTF012.airports, [⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 1430⟩], mdTF012.flightMasters, mdTF012.boardingClasses,
    [⟨.OW, "OW", 30, 355, 0, 1, 1⟩], [], [], []⟩

def iaTF1430 : Spec.Fare.TotalFareInput := ⟨Config.default, mdTF1430, iaTF012.flights, [5]⟩

theorem dev_D027TF_nontrivial : Nontrivial dev_D027TF :=
  ⟨⟨icTF012, by unfold dev_D027TF; rw [aiTF_icTF012]; rfl⟩, ⟨icTFnull, by unfold dev_D027TF; decide⟩⟩

theorem dev_D001T_nontrivial : Nontrivial dev_D001T := ⟨⟨iaTFempty, by decide⟩, ⟨iaTF29, by decide⟩⟩

theorem dev_D002T_nontrivial : Nontrivial dev_D002T := ⟨⟨iaTFempty, by decide⟩, ⟨iaTF1430, by decide⟩⟩

theorem dev_D012_nontrivial : Nontrivial dev_D012 := ⟨⟨iaTFempty, by decide⟩, ⟨iaTF012, iaTF012_devs.2.2⟩⟩

end Abstraction.Fare
