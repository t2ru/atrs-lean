-- expect:
namespace Spec.MisuOk

/-- 正例: 形式を証明フィールドで持つコード値。 -/
structure Code where
  val : String
  wf : val.length = 3 := by decide

/-- 正例: 外部から来る生の値（妥当性の述語は機械の PRE）。 -/
@[raw_input "画面から送られる値"]
structure RawCode where
  val : String

def RawCode.Valid (c : RawCode) : Prop := c.val.length = 3

end Spec.MisuOk
