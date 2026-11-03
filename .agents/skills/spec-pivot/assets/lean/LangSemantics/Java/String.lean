import LangSemantics.Java.Exception

/-!
# LangSemantics.Java.String

`java.lang.String` の意味のうち、長さ・空白除去・分割・部分文字列を定義する。
Lean の `String` は Unicode スカラ値の列であり、Java の UTF-16 の列とは長さの単位が異なる。
不対サロゲートを含む Java 文字列は、このモデルでは表さない（抽象化 α は未定義）。

lang: `lang:java#JLS-3.1`, `dep:java.base#java.lang.String.length`,
`dep:java.base#java.lang.String.trim`, `dep:java.base#java.lang.String.strip`,
`dep:java.base#java.lang.Character.isWhitespace`, `dep:java.base#java.lang.String.substring`
-/

namespace LangSemantics.Java.String

/-- 1 文字の UTF-16 符号単位数（補助文字は 2）。 -/
def utf16Units (c : Char) : Nat := if c.toNat ≥ 0x10000 then 2 else 1

/-- `String.length()`（UTF-16 符号単位数）。 -/
def utf16Len (s : String) : Nat := s.toList.foldl (fun n c => n + utf16Units c) 0

/-- `Character.isWhitespace(int)`。
空白区切り文字（Zs・Zl・Zp）のうち改行を禁止する空白（U+00A0, U+2007, U+202F）を除いたものと、
U+0009〜U+000D、U+001C〜U+001F。 -/
def isJavaWhitespace (c : Char) : Bool :=
  let n := c.toNat
  (0x09 ≤ n && n ≤ 0x0D) || (0x1C ≤ n && n ≤ 0x1F) || n == 0x20 || n == 0x1680 ||
  (0x2000 ≤ n && n ≤ 0x200A && n != 0x2007) || n == 0x2028 || n == 0x2029 ||
  n == 0x205F || n == 0x3000

private def dropBoth (p : Char → Bool) (s : String) : String :=
  String.ofList ((s.toList.dropWhile p).reverse.dropWhile p).reverse

/-- `String.trim()`: 前後の U+0000〜U+0020 を除く。 -/
def jTrim (s : String) : String := dropBoth (fun c => c.toNat ≤ 0x20) s

/-- `String.strip()`: 前後の `Character.isWhitespace` を除く。 -/
def jStrip (s : String) : String := dropBoth isJavaWhitespace s

private def splitOnChar (sep : Char) : List Char → List (List Char)
  | [] => [[]]
  | c :: cs =>
    let rest := splitOnChar sep cs
    if c == sep then [] :: rest
    else match rest with
      | w :: ws => (c :: w) :: ws
      | [] => [[c]]

/-- `String.split(regex)`（`limit = 0`）を、正規表現として特別な意味を持たない 1 文字の区切りに限って定義する。
末尾の空要素を取り除く。区切りが 1 つも無ければ元の文字列 1 要素を返す。 -/
def jSplitChar (s : String) (sep : Char) : List String :=
  let parts := splitOnChar sep s.toList
  if parts.length == 1 then [s]
  else
    let trimmed := (parts.reverse.dropWhile List.isEmpty).reverse
    trimmed.map String.ofList

/-- UTF-16 の位置 `i`（符号単位）より前にある文字の数。位置が補助文字の中なら、その文字の手前で止める。 -/
def charsBeforeUtf16 : List Char → Nat → Nat
  | [], _ => 0
  | c :: cs, i => if utf16Units c ≤ i then charsBeforeUtf16 cs (i - utf16Units c) + 1 else 0

/-- `String.substring(beginIndex, endIndex)`（位置は UTF-16 符号単位）。
`beginIndex > endIndex` か `endIndex > length()` なら `StringIndexOutOfBoundsException`。
切り口が補助文字の中にあるとき、Java の結果は不対サロゲートを含み、このモデルでは表さない
（その文字の手前で切った値を返す。抽象化 α はこの場合を定義しない）。 -/
def jSubstring (s : String) (b e : Nat) : LangSemantics.Java.Exception.JResult String :=
  if b ≤ e ∧ e ≤ utf16Len s then
    let cs := s.toList
    .ok (String.ofList ((cs.take (charsBeforeUtf16 cs e)).drop (charsBeforeUtf16 cs b)))
  else .error (.other cls!"java.lang.StringIndexOutOfBoundsException" s!"begin {b}, end {e}, length {utf16Len s}")

/-- `String.substring(beginIndex)` = `substring(beginIndex, length())`。 -/
def jSubstringFrom (s : String) (b : Nat) : LangSemantics.Java.Exception.JResult String := jSubstring s b (utf16Len s)

/-- 補助文字を含まない文字列では、UTF-16 の位置は文字の位置に等しい。 -/
theorem charsBeforeUtf16_bmp (cs : List Char) (h : ∀ c ∈ cs, c.toNat < 0x10000) (i : Nat) (hi : i ≤ cs.length) :
    charsBeforeUtf16 cs i = i := by
  induction cs generalizing i with
  | nil => simp at hi; simp [charsBeforeUtf16, hi]
  | cons c cs ih =>
    have hc : utf16Units c = 1 := by
      have := h c (by simp); unfold utf16Units; split <;> omega
    cases i with
    | zero => simp [charsBeforeUtf16, hc]
    | succ i =>
      simp only [charsBeforeUtf16, hc, show 1 ≤ i + 1 by omega, ↓reduceIte, Nat.add_sub_cancel]
      rw [ih (fun x hx => h x (by simp [hx])) i (by simp at hi; omega)]

end LangSemantics.Java.String
