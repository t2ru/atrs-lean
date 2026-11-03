-- expect: MISU-1
namespace Spec.MisuWrapper

/-- 違反: 形式を型の外の述語で持つコード値。 -/
structure Code where
  val : String
  deriving DecidableEq

def Code.WellFormed (c : Code) : Prop := c.val.length = 3

end Spec.MisuWrapper
