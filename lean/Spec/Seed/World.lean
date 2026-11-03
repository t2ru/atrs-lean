import Spec.Port
import Spec.Seed.FlightProps
import Spec.Seed.Member

/-!
# Spec.Seed.World

シードを投入した後の `World`（初期状態。SPEC-007）。フライトは `Spec.Seed.Flight`、会員と採番の初期値は
`Spec.Seed.Member`（どちらも生成物）、予約は無い（backlog aedf）。フライトの主キーの一意性の証明は、生成の形から示した
`Spec.Seed.FlightProps.flights_nodup`（ADR 6d36 の L3）。
-/

namespace Spec.Seed.World

/-- シードを投入した後の `World`。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
def world : Spec.Port.World :=
  { flights := Spec.Seed.Flight.flights, flights_nodup := Spec.Seed.FlightProps.flights_nodup,
    members := Spec.Seed.Member.members, reservations := [], sequences := Spec.Seed.Member.sequences }

/-- シードを投入した後の `World` は、シードのマスタを参照する（`World.RefMaster`。FK_FLIGHT_1〜3）。 -/
theorem world_refMaster : world.RefMaster Spec.Seed.masterData := Spec.Seed.FlightProps.flights_refMaster

end Spec.Seed.World
