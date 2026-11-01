import SourceModel.Domain.Common.Masterdata.BoardingClassProvider
import SourceModel.Domain.Common.Masterdata.PeakTimeProvider
import SourceModel.Domain.Common.Masterdata.FareTypeProvider
import SourceModel.Domain.Common.Masterdata.RouteProvider
import SourceModel.Domain.Common.Masterdata.FlightMasterProvider

/-!
# Abstraction.MasterData.Load

Provider の `load()` の形。各行の対応（`Enum.valueOf` など）が例外を投げなければ、`load()` は例外を投げず、
キャッシュは、行ごとの（キー, 値）の列を順に `put` した表（`JHashMap.ofList`）である。
-/

namespace Abstraction.MasterData.Load
open LangSemantics.Java.HashMap LangSemantics.Java.ResultLemmas

open SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata SourceModel.Db.Schema SourceModel.Domain.Repository.Route
  SourceModel.Domain.Repository.Route.RouteRepository SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Flight.FlightRepository SourceModel.Domain.Repository.Boardingclass
  SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository SourceModel.Domain.Repository.Faretype SourceModel.Domain.Repository.Faretype.FareTypeRepository SourceModel.Domain.Repository.Peaktime
  SourceModel.Domain.Repository.Peaktime.PeakTimeRepository

/-- 搭乗クラスの行の対応（コード `cd` の値に対応したとき）。 -/
def boardingClassOf (b : BoardingClassResult) (cd : Spec.Model.BoardingClassCd) : BoardingClass :=
  { boardingClassCd := some cd, boardingClassName := b.boardingClassName.map (·.val),
    extraCharge := SourceModel.Db.MyBatis.int b.extraCharge }

/-- 運賃種別の行の対応。 -/
def fareTypeOf (f : FareTypeResult) (cd : Spec.Model.FareTypeCd) : FareType :=
  { fareTypeCd := some cd, fareTypeName := SourceModel.Db.MyBatis.str f.fareTypeName,
    discountRate := SourceModel.Db.MyBatis.int f.discountRate,
    rsrvAvailableStartDayNum := SourceModel.Db.MyBatis.int f.rsrvAvailableStartDayNum,
    rsrvAvailableEndDayNum := SourceModel.Db.MyBatis.int f.rsrvAvailableEndDayNum,
    passengerMinNum := SourceModel.Db.MyBatis.int f.passengerMinNum }

/-- `BoardingClassProvider.load`: 各行のコードが列挙型の値なら、キャッシュはコードをキーにした表。 -/
theorem boardingClassLoad_eq (rows : List BoardingClassResult) (k : BoardingClassResult → Spec.Model.BoardingClassCd)
    (hk : ∀ b ∈ rows, SourceModel.Domain.Model.BoardingClassCd.valueOf b.boardingClassCd.val = .ok (k b)) :
    BoardingClassProvider.load rows =
      .ok { boardingClassCodeMap := JHashMap.ofList (rows.map fun b => (k b, boardingClassOf b (k b))) } := by
  have hm := mapM_ok rows SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository.boardingClassMap (fun b => boardingClassOf b (k b)) fun b hb => by
    simp only [SourceModel.Domain.Repository.Boardingclass.BoardingClassRepository.boardingClassMap, hk b hb]; rfl
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
    (hk : ∀ f ∈ rows, SourceModel.Domain.Model.FareTypeCd.valueOf f.fareTypeCd.val = .ok (k f)) :
    FareTypeProvider.load rows =
      .ok { fareTypeCodeMap := JHashMap.ofList (rows.map fun f => (k f, fareTypeOf f (k f))) } := by
  have hm := mapM_ok rows SourceModel.Domain.Repository.Faretype.FareTypeRepository.fareTypeMap (fun f => fareTypeOf f (k f)) fun f hf => by
    simp only [SourceModel.Domain.Repository.Faretype.FareTypeRepository.fareTypeMap, hk f hf]; rfl
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
      (RouteProvider.makeCacheKey r.depAirportCd.val r.aarAirportCd.val, SourceModel.Domain.Repository.Route.RouteRepository.routeMap r)) } := by
  simp only [RouteProvider.load]
  rw [forIn_ok _ _ (fun r m => m.put (RouteProvider.makeCacheKey
      (((r : Route).departureAirport.bind (·.code)).getD "") ((r.arrivalAirport.bind (·.code)).getD "")) r), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

/-- 便名が一意な行の `flightMaster-map` の対応は、行ごとの対応（入れ子の対応のまとめは何もしない）。 -/
theorem flightMasters_eq {rows : List FlightMasterResult} (h : (rows.map (·.flightName.val)).Nodup) :
    SourceModel.Domain.Repository.Flight.FlightRepository.flightMasters rows = rows.map SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap := by
  suffices ∀ (acc : List FlightMasterResult), (acc.map (·.flightName.val) ++ rows.map (·.flightName.val)).Nodup →
      rows.foldl (fun (acc : List FlightMasterResult) r =>
        if acc.any (fun a => a.flightName.val == r.flightName.val) then acc else acc ++ [r]) acc = acc ++ rows by
    unfold SourceModel.Domain.Repository.Flight.FlightRepository.flightMasters
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
      (f.flightName.val, SourceModel.Domain.Repository.Flight.FlightRepository.flightMasterMap f)) } := by
  simp only [FlightMasterProvider.load, flightMasters_eq h]
  rw [forIn_ok _ _ (fun f m => m.put ((f : FlightMaster).flightName.getD "") f), ok_bind]
  · unfold JHashMap.ofList
    simp only [List.foldl_map]
    rfl
  · intro x hx b
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    rfl

end Abstraction.MasterData.Load
