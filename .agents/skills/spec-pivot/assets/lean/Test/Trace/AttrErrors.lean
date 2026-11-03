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

/-! ## 引数の形式（付けた時点で型の値に解析する。ADR bf1b） -/

/-- error: @[obligation]: "ABS-1" is not ABS-NNN / REF-NNN / SPEC-NNN -/
#guard_msgs in
@[obligation "ABS-1"] theorem badObligation : True := trivial

/-- error: @[gap]: "X-001" is not D-NNN / T-NNN -/
#guard_msgs in
@[gap "D-001", "X-001"] def badGap : Nat := 0

/-- error: @[nondet]: "N-1" is not N-NNN -/
#guard_msgs in
@[nondet "N-1"] def badNondet : Nat := 0

/-- error: @[spec_doc]: "docs/spec/x" is not <path>.md or <path>.md#<anchor> -/
#guard_msgs in
@[spec_doc "docs/spec/x"] def badSpecDoc : Nat := 0

/-- error: @[source]: "upstream/Foo.java" is not <scheme>:<locator>@<pin> -/
#guard_msgs in
@[source "upstream/Foo.java"] def badSource : Nat := 0

/-- error: @[env_pre]: "md-1" is not an upper-case ID with an optional number (MD-1, CFG) -/
#guard_msgs in
@[env_pre "md-1"] def badEnvPre : Nat := 0

end Test.Trace.AttrErrors

/-! 差異の定数は ID を 1 つだけ持つ。2 つ目の ID は構文の誤りになる（属性の構文が 1 つの文字列だけを受ける）。 -/

namespace Test.Trace.AttrErrors

/-- 属性名（`source`, `target` など）が予約語にならず、識別子として使えることを確かめる。 -/
def useNames (source target obligation deviation nondet std_abs kernel env_pre spec_doc no_source gap gap_entry : Nat) :
    Nat :=
  source + target + obligation + deviation + nondet + std_abs + kernel + env_pre + spec_doc + no_source + gap + gap_entry

#guard useNames 1 2 3 4 5 6 7 8 9 10 11 12 = 78

end Test.Trace.AttrErrors
