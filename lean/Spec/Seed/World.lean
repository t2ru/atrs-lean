import Spec.Port
import Spec.Seed.Flight
import Spec.Seed.Member

/-!
# Spec.Seed.World

シードを投入した後の `World`（初期状態。SPEC-007）。フライトは `Spec.Seed.Flight`、会員と採番の初期値は
`Spec.Seed.Member`（どちらも生成物）、予約は無い（backlog aedf）。
-/

namespace Spec.Seed.World

/-- シードを投入した後の `World`。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
def world : Spec.Port.World :=
  { flights := Spec.Seed.Flight.world.flights, members := Spec.Seed.Member.members, reservations := [],
    sequences := Spec.Seed.Member.sequences }

end Spec.Seed.World
