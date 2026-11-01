import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import SourceModel.Repository.Schema
import Spec.Port

/-!
# Abstraction.FlightSearch.Alpha

空席照会の状態の標準の抽象化 α（backlog 0be7 の第 2 段。`docs/spec/abstraction.md#抽象化関数-α`）。
FLIGHT 表の行を [Spec] のフライトに、表を `World` に写す。どれも部分写像で、[Spec] の型で表せない行
（負の空席数、未知の搭乗クラス・運賃種別のコード、暦日の外の日付）には定義しない。これは既知差異 D-027 の範囲で、
空席照会は状態を変えないので、シードの状態から到達する状態は定義域にある（初期状態の対応は第 3 段で示す）。
-/

namespace Abstraction.FlightSearch.Alpha
open Abstraction.MasterData.AlphaLeaf Spec.Model Machine.Kernel
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

end Abstraction.FlightSearch.Alpha
