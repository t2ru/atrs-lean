import SourceModel.MasterData

/-!
# Abstraction.MasterData.Load

Provider の `load()` の形。各行の対応（`Enum.valueOf` など）が例外を投げなければ、`load()` は例外を投げず、
キャッシュは、行ごとの（キー, 値）の列を順に `put` した表（`JHashMap.ofList`）である。
-/

namespace Abstraction.MasterData.Load
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.ResultLemmas LangSemantics.Java.String

open LangSemantics.Java SourceModel.Model SourceModel.MasterData SourceModel.Repository.MasterData SourceModel.Repository
  SourceModel.Repository.Schema




/-- 搭乗クラスの行の対応（コード `cd` の値に対応したとき）。 -/
def boardingClassOf (b : BoardingClassResult) (cd : Spec.Model.BoardingClassCd) : BoardingClass :=
  { boardingClassCd := some cd, boardingClassName := b.boardingClassName.map (·.val),
    extraCharge := Mapping.int b.extraCharge }

/-- 運賃種別の行の対応。 -/
def fareTypeOf (f : FareTypeResult) (cd : Spec.Model.FareTypeCd) : FareType :=
  { fareTypeCd := some cd, fareTypeName := Mapping.str f.fareTypeName,
    discountRate := Mapping.int f.discountRate,
    rsrvAvailableStartDayNum := Mapping.int f.rsrvAvailableStartDayNum,
    rsrvAvailableEndDayNum := Mapping.int f.rsrvAvailableEndDayNum,
    passengerMinNum := Mapping.int f.passengerMinNum }

/-- `BoardingClassProvider.load`: 各行のコードが列挙型の値なら、キャッシュはコードをキーにした表。 -/
theorem boardingClassLoad_eq (rows : List BoardingClassResult) (k : BoardingClassResult → Spec.Model.BoardingClassCd)
    (hk : ∀ b ∈ rows, Mapping.boardingClassCd b.boardingClassCd.val = .ok (k b)) :
    BoardingClassProvider.load rows =
      .ok { boardingClassCodeMap := JHashMap.ofList (rows.map fun b => (k b, boardingClassOf b (k b))) } := by
  have hm := mapM_ok rows Mapping.boardingClass (fun b => boardingClassOf b (k b)) fun b hb => by
    simp only [Mapping.boardingClass, hk b hb]; rfl
  simp only [BoardingClassProvider.load, hm, ok_bind]
  rw [forIn_ok _ _ (fun bc m => m.put ((bc : BoardingClass).boardingClassCd.getD .N) bc), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

/-- `FareTypeProvider.load`: 各行のコードが列挙型の値なら、キャッシュはコードをキーにした表。 -/
theorem fareTypeLoad_eq (rows : List FareTypeResult) (k : FareTypeResult → Spec.Model.FareTypeCd)
    (hk : ∀ f ∈ rows, Mapping.fareTypeCd f.fareTypeCd.val = .ok (k f)) :
    FareTypeProvider.load rows =
      .ok { fareTypeCodeMap := JHashMap.ofList (rows.map fun f => (k f, fareTypeOf f (k f))) } := by
  have hm := mapM_ok rows Mapping.fareType (fun f => fareTypeOf f (k f)) fun f hf => by
    simp only [Mapping.fareType, hk f hf]; rfl
  simp only [FareTypeProvider.load, hm, ok_bind]
  rw [forIn_ok _ _ (fun ft m => m.put ((ft : FareType).fareTypeCd.getD .OW) ft), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

/-- `RouteProvider.load`: 例外を投げず、キャッシュは出発・到着の空港コードのキーの表。 -/
theorem routeLoad_eq (rows : List RouteResult) :
    RouteProvider.load rows = .ok { routeMap := JHashMap.ofList (rows.map fun r =>
      (makeCacheKey r.depAirportCd.val r.aarAirportCd.val, Mapping.route r)) } := by
  simp only [RouteProvider.load]
  rw [forIn_ok _ _ (fun r m => m.put (makeCacheKey
      (((r : Route).departureAirport.bind (·.code)).getD "") ((r.arrivalAirport.bind (·.code)).getD "")) r), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

/-- 便名が一意な行の `flightMaster-map` の対応は、行ごとの対応（入れ子の対応のまとめは何もしない）。 -/
theorem flightMasters_eq {rows : List FlightMasterResult} (h : (rows.map (·.flightName.val)).Nodup) :
    Mapping.flightMasters rows = rows.map Mapping.flightMasterRow := by
  suffices ∀ (acc : List FlightMasterResult), (acc.map (·.flightName.val) ++ rows.map (·.flightName.val)).Nodup →
      rows.foldl (fun (acc : List FlightMasterResult) r =>
        if acc.any (fun a => a.flightName.val == r.flightName.val) then acc else acc ++ [r]) acc = acc ++ rows by
    unfold Mapping.flightMasters
    rw [this [] (by simpa using h)]
    rfl
  clear h
  induction rows with
  | nil => simp
  | cons r rows ih =>
    intro acc hnd
    have hr : acc.any (fun a => a.flightName.val == r.flightName.val) = false := by
      simp only [List.any_eq_false, beq_iff_eq]
      intro a ha e
      exact (List.nodup_append.mp hnd).2.2 _ (List.mem_map.mpr ⟨a, ha, rfl⟩) _ (by simp) e
    simp only [List.foldl_cons, hr, Bool.false_eq_true, ite_false]
    rw [ih _ (by simpa [List.append_assoc] using hnd)]
    simp

/-- `FlightMasterProvider.load`: 便名が一意なら、例外を投げず、キャッシュは便名をキーにした表。 -/
theorem flightMasterLoad_eq {rows : List FlightMasterResult} (h : (rows.map (·.flightName.val)).Nodup) :
    FlightMasterProvider.load rows = .ok { flightMasterMap := JHashMap.ofList (rows.map fun f =>
      (f.flightName.val, Mapping.flightMasterRow f)) } := by
  simp only [FlightMasterProvider.load, flightMasters_eq h]
  rw [forIn_ok _ _ (fun f m => m.put ((f : FlightMaster).flightName.getD "") f), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

end Abstraction.MasterData.Load
