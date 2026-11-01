import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import SourceModel.Repository.Schema
import Spec.Port
import Spec.FlightSearch
import SourceModel.FlightSearchQuery
import Abstraction.Fare.Alpha

/-!
# Abstraction.FlightSearch.Alpha

空席照会（R 課題 ABS-011）の標準の抽象化 α と、前提型の差異の述語（backlog 0be7 の第 2・3 段。
`docs/spec/abstraction.md#抽象化関数-α`）。

- 状態: FLIGHT 表の行を [Spec] のフライトに、表を `World` に写す（`flightOfRow`・`worldOfDb`）。
- 入力: 設定・マスタは ABS-026 の `configOf`・`masterDataOf`、今日は `dateOfJ`、照会条件は空港コード・列挙・日付（`aiS`）。
  配備の環境（区切り文字）は抽象側に無い（D-032 の前提で固定する）。
- 出力: 便ごとの空席情報（文字列はそのまま、空席数は `natOfJ32`、運賃種別のキーは `ftCdOf`）と業務例外（`aoS`）。

FLIGHT の行の α はどれも部分写像で、[Spec] の型で表せない行
（負の空席数、未知の搭乗クラス・運賃種別のコード、暦日の外の日付）には定義しない。これは既知差異 D-027 の範囲で、
空席照会は状態を変えないので、シードの状態から到達する状態は定義域にある（初期状態の対応は第 3 段で示す）。
-/

namespace Abstraction.FlightSearch.Alpha
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Spec.Model Machine.Kernel
open Machine.Preserves (KernelIs)

open LangSemantics.Sql.Postgresql SourceModel.Repository.Schema Spec.Prim

/-- FLIGHT の行。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def flightOfRow (r : FlightRow) : Option Flight := do
  let d ← dateOfPg r.departureDate
  let bc ← bcCdOf r.boardingClassCd.val
  let ft ← ftCdOf r.fareTypeCd.val
  let v ← natOfInt4 r.vacantNum
  pure ⟨⟨d, ⟨r.flightName.val⟩, bc, ft⟩, v⟩

/-- FLIGHT 表（状態）。すべての行が写せるときに限って定義する。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def worldOfDb (fd : FlightDb) : Option Spec.Port.World := (fd.flight.mapM flightOfRow).map Spec.Port.World.mk

@[obligation "ABS-048"]
theorem flightOfRow_kernel : KernelIs flightOfRow (undefOrEq flightOfRow) := by
  apply kernelIs_undefOrEq
  intro r r' a h h'
  simp only [flightOfRow, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨d, hd, bc, hbc, ft, hft, v, hv, rfl⟩ := h
  obtain ⟨d', hd', bc', hbc', ft', hft', v', hv', h⟩ := h'
  simp only [Flight.mk.injEq, FlightKey.mk.injEq, FlightName.mk.injEq] at h
  obtain ⟨⟨rfl, h2, rfl, rfl⟩, rfl⟩ := h
  cases r; cases r'
  simp only [FlightRow.mk.injEq] at *
  exact ⟨inj_of_kernel dateOfPg_kernel hd hd', Subtype.ext h2.symm,
    Subtype.ext (inj_of_kernel bcCdOf_kernel hbc hbc'), Subtype.ext (inj_of_kernel ftCdOf_kernel hft hft'),
    Abstraction.MasterData.Alpha.natOfInt4_inj hv hv'⟩

@[obligation "ABS-048"]
theorem worldOfDb_kernel : KernelIs worldOfDb (undefOrEq worldOfDb) := by
  apply kernelIs_undefOrEq
  intro t t' w h h'
  simp only [worldOfDb, Option.map_eq_some_iff] at h h'
  obtain ⟨fs, hfs, rfl⟩ := h
  obtain ⟨fs', hfs', he⟩ := h'
  cases he
  cases t; cases t'
  congr 1
  exact mapM_inj (fun _ _ _ hx hy => inj_of_kernel flightOfRow_kernel hx hy) hfs hfs'

/-! ## 入力 -/

/-- 照会条件（`null` には定義しない。空港コードはそのまま包む）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def criteriaOf (c : SourceModel.FlightSearch.TicketSearchCriteriaDto) : Option Spec.FlightSearch.Criteria := do
  let d ← c.depDate.bind dateOfJ
  let bc ← c.boardingClassCd
  let dep ← c.departureAirportCd
  let arr ← c.arrivalAirportCd
  let ft ← c.flightType
  pure ⟨d, bc, ⟨dep⟩, ⟨arr⟩, ft⟩

@[obligation "ABS-048"]
theorem criteriaOf_kernel : KernelIs criteriaOf (undefOrEq criteriaOf) := by
  apply kernelIs_undefOrEq
  intro c c' a h h'
  simp only [criteriaOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨d, hd, bc, hbc, dep, hdep, arr, harr, ft, hft, rfl⟩ := h
  obtain ⟨d', hd', bc', hbc', dep', hdep', arr', harr', ft', hft', h⟩ := h'
  simp only [Spec.FlightSearch.Criteria.mk.injEq, AirportCd.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl, rfl⟩ := h
  obtain ⟨j, hj, hjd⟩ := hd
  obtain ⟨j', hj', hjd'⟩ := hd'
  cases c; cases c'
  simp only at *
  rw [hj, hj', hbc, hbc', hdep, hdep', harr, harr', hft, hft', inj_of_kernel dateOfJ_kernel hjd hjd']

/-- 入力: 設定・マスタ・今日の日付・照会条件。配備の環境（区切り文字）は写さない（D-032）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiS (ic : SourceModel.FlightSearch.SearchInput) : Option Spec.FlightSearch.SearchInput := do
  let cfg ← configOf ic.config
  let md ← masterDataOf ic.db
  let today ← dateOfJ ic.today
  let c ← ic.criteria.bind criteriaOf
  pure ⟨cfg, md, today, c⟩

/-! ## 出力 -/

/-- 運賃種別ごとの空席情報（キーは運賃種別のコード）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def fareTypeInfoOf (e : String × SourceModel.FlightSearch.FareTypeVacantInfoDto) :
    Option (FareTypeCd × Spec.FlightSearch.FareTypeVacantInfo) := do
  let cd ← ftCdOf e.1
  let n ← e.2.fareTypeName
  let f ← e.2.fare
  let v ← e.2.vacantNum.bind natOfJ32
  pure (cd, ⟨n, f, v⟩)

@[obligation "ABS-048"]
theorem fareTypeInfoOf_kernel : KernelIs fareTypeInfoOf (undefOrEq fareTypeInfoOf) := by
  apply kernelIs_undefOrEq
  intro e e' a h h'
  simp only [fareTypeInfoOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨cd, hcd, n, hn, f, hf, v, hv, rfl⟩ := h
  obtain ⟨cd', hcd', n', hn', f', hf', v', hv', h⟩ := h'
  simp only [Prod.mk.injEq, Spec.FlightSearch.FareTypeVacantInfo.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl⟩ := h
  obtain ⟨j, hj, hjv⟩ := hv
  obtain ⟨j', hj', hjv'⟩ := hv'
  obtain ⟨k, ⟨fn, fr, fv⟩⟩ := e
  obtain ⟨k', ⟨fn', fr', fv'⟩⟩ := e'
  simp only at *
  rw [inj_of_kernel ftCdOf_kernel hcd hcd', hn, hn', hf, hf', hj, hj', inj_of_kernel natOfJ32_kernel hjv hjv']

/-- 便ごとの空席情報。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def vacantInfoOf (d : SourceModel.FlightSearch.FlightVacantInfoDto) : Option Spec.FlightSearch.FlightVacantInfo := do
  let n ← d.flightName
  let dn ← d.depAirportName
  let an ← d.arrAirportName
  let dt ← d.depTime
  let art ← d.arrTime
  let dd ← d.depDate
  let bc ← d.boardingClassCd
  let fts ← d.fareTypes.entries.mapM fareTypeInfoOf
  pure ⟨⟨n⟩, dn, an, dt, art, dd, bc, fts⟩

@[obligation "ABS-048"]
theorem vacantInfoOf_kernel : KernelIs vacantInfoOf (undefOrEq vacantInfoOf) := by
  apply kernelIs_undefOrEq
  intro d d' a h h'
  simp only [vacantInfoOf, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def, Option.some.injEq] at h h'
  obtain ⟨n, hn, dn, hdn, an, han, dt, hdt, art, hat, dd, hdd, bc, hbc, fts, hfts, rfl⟩ := h
  obtain ⟨n', hn', dn', hdn', an', han', dt', hdt', art', hat', dd', hdd', bc', hbc', fts', hfts', h⟩ := h'
  simp only [Spec.FlightSearch.FlightVacantInfo.mk.injEq, FlightName.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩ := h
  obtain ⟨_, _, _, _, _, _, _, ⟨es⟩⟩ := d
  obtain ⟨_, _, _, _, _, _, _, ⟨es'⟩⟩ := d'
  simp only at *
  rw [hn, hn', hdn, hdn', han, han', hdt, hdt', hat, hat', hdd, hdd', hbc, hbc',
    mapM_inj (fun _ _ _ hx hy => inj_of_kernel fareTypeInfoOf_kernel hx hy) hfts hfts']

/-- 出力: 便ごとの空席情報の列、または業務例外（コードで写す）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoS : SourceModel.FlightSearchQuery.SearchOutput → Option Spec.FlightSearch.SearchOutput
  | .ok ds => (ds.mapM vacantInfoOf).map .ok
  | .error (.business c) => some (.error (.business c))
  | .error (.notFound c) => some (.error (.notFound c))

@[obligation "ABS-048"]
theorem aoS_kernel : KernelIs aoS (undefOrEq aoS) := by
  apply kernelIs_undefOrEq
  intro o o' a h h'
  rcases o with (⟨c⟩ | ⟨c⟩) | ds <;> rcases o' with (⟨c'⟩ | ⟨c'⟩) | ds' <;>
    simp only [aoS, Option.some.injEq, Option.map_eq_some_iff] at h h'
  all_goals first
    | (obtain ⟨x, hx, rfl⟩ := h; obtain ⟨y, hy, hxy⟩ := h'; cases hxy; congr 1
       exact mapM_inj (fun _ _ _ hx hy => inj_of_kernel vacantInfoOf_kernel hx hy) hx hy)
    | (obtain ⟨x, _, hx⟩ := h; rw [← hx] at h'; cases h'; done)
    | (obtain ⟨x, _, hx⟩ := h'; rw [← hx] at h; cases h; done)
    | (rw [← h'] at h; cases h; rfl)
    | (rw [← h'] at h; cases h; done)

/-- 具体側の入力の環境（[Spec] の選択の環境は `Unit` なので、どの入力も標準の環境 `()`）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def ceFS (_ : SourceModel.FlightSearch.SearchInput) : Unit := ()

/-- `ceFS` の核: どの入力も同一視する。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def ceFSKer (_ _ : SourceModel.FlightSearch.SearchInput) : Prop := True

@[obligation "ABS-048"]
theorem ceFS_kernel : KernelIs ceFS ceFSKer := fun _ _ => by simp [ceFS, ceFSKer]

/-- 空席照会の標準の貼り合わせ（状態は `worldOfDb`、具体側の不変条件は課さない）。 -/
abbrev glueFS := Machine.Glue.ofStd worldOfDb (fun _ => True) aiS aoS

/-! ## 前提型の差異 -/

/-- D-027（空席照会）: 具体側の入力（DB のマスタ・設定・今日の日付・照会条件）が [Spec] の型で表せる。
状態の表 FLIGHT が表せることは、貼り合わせの部分写像 `worldOfDb` で表す（表せない状態は `World` と結ばれない）。 -/
@[deviation "D-027"]
def dev_D027S (ic : SourceModel.FlightSearch.SearchInput) : Prop := (aiS ic).isSome = true

/-- D-014（空席照会）: `TicketSharedServiceImpl` が読む今日の日付（`validateDepatureDate`・`getSearchLimitDate`）が、
`searchFlight` の今日の日付と同じ（1 回の照会の中で Clock が日付をまたがない）。 -/
@[deviation "D-014"]
def dev_D014S (ic : SourceModel.FlightSearch.SearchInput) : Prop := ic.sharedClock = (ic.today, ic.today)

/-- D-032: 配備の環境の既定の書式ロケールの 3 桁区切りの文字が `,`。 -/
@[deviation "D-032"]
def dev_D032 (ic : SourceModel.FlightSearch.SearchInput) : Prop :=
  ic.formatSymbols = LangSemantics.Java.DecimalFormat.Symbols.ascii

/-- D-001（空席照会）: 搭乗日が照会可能期間の内で、照会の区間があるとき、区間の運賃・搭乗クラス・搭乗日の基本運賃に
ついて `dev_D001` が成り立つ（基本運賃を計算しない経路には課さない）。 -/
@[deviation "D-001"]
def dev_D001S (i : Spec.FlightSearch.SearchInput) : Prop :=
  ∀ r, i.md.routeOf i.criteria.depAirportCd i.criteria.arrAirportCd = some r →
    Spec.FlightSearch.outOfPeriod i.cfg i.today i.criteria.depDate = false →
    Abstraction.Fare.Alpha.dev_D001 ⟨i.cfg, i.md, r.basicFare, i.criteria.boardingClassCd, i.criteria.depDate⟩

/-- D-002（空席照会）: 搭乗日が照会可能期間の内で、照会の区間があるとき、照会の基本運賃と、照会の片道・往復の
運賃種別（`fareTypesFor`）の割引率について、`dev_D002` が成り立つ。候補に現れない運賃種別（予約可能期間の外・
フライトの無いもの）にも課す十分条件である。 -/
@[deviation "D-002"]
def dev_D002S (i : Spec.FlightSearch.SearchInput) : Prop :=
  ∀ r b, i.md.routeOf i.criteria.depAirportCd i.criteria.arrAirportCd = some r →
    Spec.FlightSearch.outOfPeriod i.cfg i.today i.criteria.depDate = false →
    Spec.Fare.basicFare i.md r.basicFare i.criteria.boardingClassCd i.criteria.depDate = some b →
    ∀ ft ∈ i.md.fareTypes, ft.fareTypeCd ∈ fareTypesFor i.criteria.flightType →
      Abstraction.Fare.Alpha.dev_D002 ⟨b, ft.discountRate⟩

/-! ## enum の名前 -/

theorem fareTypeCdCode_eq (t : FareTypeCd) : SourceModel.Model.fareTypeCdCode t = t.toCode := by cases t <;> rfl

theorem fareTypeCdName_eq (t : FareTypeCd) : SourceModel.Model.fareTypeCdName t = t.toCode := by cases t <;> rfl

theorem boardingClassCdName_eq (b : BoardingClassCd) : SourceModel.Model.boardingClassCdName b = b.toCode := by
  cases b <;> rfl

end Abstraction.FlightSearch.Alpha
