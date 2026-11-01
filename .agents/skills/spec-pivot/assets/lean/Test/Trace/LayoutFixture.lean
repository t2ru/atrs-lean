import Trace

/-!
# Test.Trace.LayoutFixture

`layout-check`（`Trace.Layout`）のフィクスチャ。合格する宣言（NS-1・E3）と、違反を置く。E1・E2・E4 は、assets の実際の定数で確かめる。
期待する判定は `Test/Trace/Main.lean` の `layoutTests` に書く。スキルの `layout-check` の対象からは除く。
-/

namespace Test.Trace.LayoutFixture

/-- 合格: モジュール名の下。 -/
def ok : Nat := 0

/-- 合格: モジュール名の下の型と、その名前空間。 -/
structure Box where
  val : Nat
deriving Repr

def Box.get (b : Box) : Nat := b.val

end Test.Trace.LayoutFixture

namespace Test.Trace

/-- 違反: モジュールの親の名前空間に置いた。 -/
def layoutStray : Nat := 1

/-- 合格（E3）: 理由を明示した例外。 -/
@[ns_exception "フィクスチャ: 明示した例外"]
def layoutExempt : Nat := 2

end Test.Trace

/-- 違反: ルートに置いた（`main` 以外）。 -/
def layoutRootStray : Nat := 3
