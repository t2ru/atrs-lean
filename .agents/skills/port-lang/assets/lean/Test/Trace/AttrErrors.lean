import Trace

/-!
# Test.Trace.AttrErrors

追跡属性の引数の誤りが、エラーとして報告されることを確かめる。
-/

namespace Test.Trace.AttrErrors

/-- error: @[source]: empty string argument -/
#guard_msgs in
@[source ""] def emptyArg : Nat := 0

/-- error: @[nondet]: empty string argument -/
#guard_msgs in
@[nondet ""] def emptyNondet : Nat := 0

/-- error: @[spec_doc]: empty string argument -/
#guard_msgs in
@[spec_doc "docs/spec/x.md#a", ""] def emptySecondArg : Nat := 0

end Test.Trace.AttrErrors

namespace Test.Trace.AttrKeywords

/-- 属性名（`source`, `target` など）が予約語にならず、識別子として使えることを確かめる。 -/
def useNames (source target obligation deviation nondet std_abs kernel env_pre spec_doc no_source gap gap_entry : Nat) :
    Nat :=
  source + target + obligation + deviation + nondet + std_abs + kernel + env_pre + spec_doc + no_source + gap + gap_entry

#guard useNames 1 2 3 4 5 6 7 8 9 10 11 12 = 78

end Test.Trace.AttrKeywords
