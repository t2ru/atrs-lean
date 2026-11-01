import LangSemantics.Rust.Panic

/-!
# LangSemantics.Rust.Text

`char`・`String`・`Vec` の意味のうち、長さ・添字・分割を定義する。
Lean の `Char` は Unicode スカラ値であり、Rust の `char` と同じ値域を持つ。
Lean の `String` は Unicode スカラ値の列であり、Rust の `String`（妥当な UTF-8）と 1 対 1 に対応する。

lang: `lang:rust#textual-types`, `dep:alloc#String::len`, `dep:core#str::chars`, `dep:core#slice::get`
-/

namespace LangSemantics.Rust.Text
open LangSemantics.Rust.Panic

/-- Rust の `char`。 -/
abbrev RChar := Char
/-- Rust の `String` / `&str`。 -/
abbrev RString := String

/-- `s.len()`: UTF-8 のバイト数。 -/
def strLen (s : RString) : Nat := s.utf8ByteSize

/-- `s.chars().count()`: スカラ値の数。 -/
def charsCount (s : RString) : Nat := s.length

/-- `char::is_whitespace`（Unicode の White_Space 特性）。 -/
def isWhitespace (c : RChar) : Bool :=
  let n := c.toNat
  (0x09 ≤ n && n ≤ 0x0D) || n == 0x20 || n == 0x85 || n == 0xA0 || n == 0x1680 ||
  (0x2000 ≤ n && n ≤ 0x200A) || n == 0x2028 || n == 0x2029 || n == 0x202F || n == 0x205F || n == 0x3000

/-- `s.trim()`: 前後の `char::is_whitespace` を除く。 -/
def trim (s : RString) : RString :=
  String.ofList ((s.toList.dropWhile isWhitespace).reverse.dropWhile isWhitespace).reverse

/-- `s.split(c)`: 区切りごとに分割する（空要素も残す。Java の `split` と異なる）。 -/
def splitChar (s : RString) (sep : RChar) : List RString :=
  let rec go : List Char → List Char → List String
    | [], cur => [String.ofList cur.reverse]
    | c :: cs, cur => if c == sep then String.ofList cur.reverse :: go cs [] else go cs (c :: cur)
  go s.toList []

/-- Rust の `Vec<T>`。 -/
abbrev RVec (α : Type) := List α

/-- `v[i]`: 範囲外はパニック。 -/
def index {α : Type} (v : RVec α) (i : Nat) : RExec α :=
  match v[i]? with
  | some x => .ok x
  | none => rpanic s!"index out of bounds: the len is {v.length} but the index is {i}"

/-- `v.get(i)`。 -/
def get {α : Type} (v : RVec α) (i : Nat) : Option α := v[i]?

/-- ASCII だけからなる文字列では、バイト数とスカラ値数が等しい。 -/
theorem charsCount_eq_strLen_ascii_example : charsCount "abc" = strLen "abc" := by decide

end LangSemantics.Rust.Text
