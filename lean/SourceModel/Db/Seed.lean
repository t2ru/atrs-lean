import SourceModel.Db.Schema
import SourceModel.Db.FlightSeed
import SourceModel.Db.MemberSeed

/-!
# SourceModel.Db.Seed

シードを投入した後の状態の表（初期状態）。FLIGHT は `SourceModel.Db.FlightSeed`、MEMBER・MEMBER_LOGIN と
`sq_member_1` は `SourceModel.Db.MemberSeed`（どちらも生成物）、予約の表は空、ほかのシーケンスは未使用（backlog aedf）。
原典のクラスではないので、原典のソースツリーの外に置く。
-/

namespace SourceModel.Db.Seed

/-- シードを投入した後の状態の表。 -/
def seedDb : SourceModel.Db.Schema.FlightDb :=
  let fd := SourceModel.Db.FlightSeed.seedFlightDb
  { flight := fd.flight, member := SourceModel.Db.MemberSeed.memberRows,
    memberLogin := SourceModel.Db.MemberSeed.memberLoginRows, sqMember := SourceModel.Db.MemberSeed.sqMember }

end SourceModel.Db.Seed
