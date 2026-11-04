import Spec.World
import Spec.Seed.FlightProps
import Spec.Seed.Member

/-!
# シードを投入した後の状態（`Spec.Seed.World`）

> **区分: 要約（informative）。**

シードを投入した後の抽象状態 `World` を定める。空席照会と予約の抽象機械は、これを初期状態とする（証明課題 SPEC-007）。

- フライト: [`Spec.Seed.Flight`](Flight.lean)（生成物）。主キーの一意性は [`Spec.Seed.FlightProps`](FlightProps.lean) が示す。
- 会員と採番の初期値: [`Spec.Seed.Member`](Member.lean)（生成物）。
- 予約: 無い。

シードのフライトは、シードのマスタを参照する（`world_refMaster`）。
-/

namespace Spec.Seed.World

/-- シードを投入した後の `World`。 -/
@[spec_doc "lean/Spec/World.lean#world抽象状態"]
def world : Spec.World :=
  { flights := Spec.Seed.Flight.flights, flights_nodup := Spec.Seed.FlightProps.flights_nodup,
    members := Spec.Seed.Member.members, reservations := [], sequences := Spec.Seed.Member.sequences }

/-- シードを投入した後の `World` は、シードのマスタを参照する（`World.RefMaster`。DDL の FK_FLIGHT_1〜3）。 -/
theorem world_refMaster : world.RefMaster Spec.Seed.Master.masterData := Spec.Seed.FlightProps.flights_refMaster

end Spec.Seed.World
