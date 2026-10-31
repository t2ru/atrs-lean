import Trace

/-!
# TraceTest.Fixture

trace-dump のフィクスチャ。`TraceTest.Fixture.<層>` の下に、各層を模したダミー定義と全種類の追跡属性を置く。
テストは、接頭辞 `TraceTest.Fixture` を除いた名前で層を決める。
-/

namespace TraceTest.Fixture

namespace LangSemantics.Rust
/-- 移植先の言語意味論を模す。 -/
@[target "lang:rust#integer-overflow@rust-1.88"]
def wrapAdd (a b : Nat) : Nat := (a + b) % 256
end LangSemantics.Rust

namespace Spec
/-- 仕様の定義を模す。 -/
@[spec_doc "docs/spec/example.md#base", no_source "フィクスチャ"]
def base (n : Nat) : Nat := n * 2

/-- 既知差異の前提を模す。 -/
@[deviation "T-999"]
def smallInput (n : Nat) : Prop := n < 10
end Spec

namespace SourceModel
/-- 移植元モデルを模す。 -/
@[source "java:com.example.Fare#base(int)@0123456789abcdef", "lang:java#JLS-15.17.1@java-17"]
def base (n : Int) : Int := n * 2
end SourceModel

namespace TargetModel
/-- 移植先モデルを模す（移植先の言語意味論を参照する）。 -/
@[target "rust:app::fare::double@0123456789abcdef"]
def double (n : Nat) : Nat := LangSemantics.Rust.wrapAdd n n

/-- `Spec` を参照する（`Spec` は合成の範囲外）。 -/
def useSpec (n : Nat) : Nat := Spec.base n

/-- `match` の補助定数（`match_1`）を展開して参照に含めることを確かめる。 -/
def useMatch (n : Nat) : Nat :=
  match n with
  | 0 => 1
  | k + 1 => double k

mutual
/-- 相互再帰。ギャップの箇所の印を付ける。 -/
@[gap "T-998"]
def isEven : Nat → Bool
  | 0 => true
  | n + 1 => isOdd n
/-- 相互再帰。 -/
def isOdd : Nat → Bool
  | 0 => false
  | n + 1 => isEven n
end
end TargetModel

namespace Refinement
/-- 証明課題の主定理を模す。 -/
@[obligation "REF-999"]
theorem double_eq (n : Nat) (_h : Spec.smallInput n) :
    TargetModel.double n = TargetModel.double n := rfl

/-- フィクスチャの **ギャップ** の説明。 -/
@[gap_entry]
def gT998 : Trace.Gap :=
  { id := "T-998", kind := .outsidePre, sites := [⟨"例", "docs/spec/example.md#base", "（注記）"⟩], premise := "PRE X-1" }
end Refinement

end TraceTest.Fixture
