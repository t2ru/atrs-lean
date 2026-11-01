import Spec.Model
import Spec.MasterData

/-!
# Spec.Port

ポートと抽象状態 `World`（`docs/spec/ports.md`）。いまの成分はフライトだけで、会員・予約・採番・レポートは、
それを使う機能の backlog で足す（ADR ce36）。マスタ・設定は `World` に含めず、不変の入力とする。
-/

namespace Spec.Port
open Spec.Model

/-- 抽象状態。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
structure World where
  /-- フライトの集合（主キーで一意。列の順序は意味を持たない） -/
  flights : List Flight
  deriving DecidableEq

namespace World

/-- `World` の不変条件: フライトは主キーで一意である。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
def Inv (w : World) : Prop := (w.flights.map (·.key)).Nodup

instance (w : World) : Decidable w.Inv := by unfold Inv; infer_instance

/-- フライトの参照整合性（DDL の FK_FLIGHT_1〜3）: 各フライトの便名・搭乗クラス・運賃種別がマスタにある。
マスタは `World` に含めない入力なので、`World.Inv` でなく、マスタとの組の述語とする（MD-3 の残り。
機械の PRE に入れるのは backlog 0be7 の第 2 段）。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec"]
def RefMaster (md : Spec.MasterData) (w : World) : Prop :=
  ∀ f ∈ w.flights, (∃ m ∈ md.flightMasters, m.flightName = f.key.flightName) ∧
    (∃ b ∈ md.boardingClasses, b.boardingClassCd = f.key.boardingClassCd) ∧
    (∃ t ∈ md.fareTypes, t.fareTypeCd = f.key.fareTypeCd)

instance (md : Spec.MasterData) (w : World) : Decidable (w.RefMaster md) := by
  unfold RefMaster; infer_instance

/-- `FlightRepository.findAll`: 全フライト（絞り込み・整列は呼び出し側の純粋関数で行う）。 -/
@[spec_doc "docs/spec/ports.md#flightrepository"]
def findAll (w : World) : List Flight := w.flights

end World

end Spec.Port
