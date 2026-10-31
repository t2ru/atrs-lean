import Trace

/-!
# Spec.Prim.Text

文字列長と文字クラス（`docs/spec/input-validation.md#文字クラス`、ADR 10a5）。

- 文字列は Unicode スカラ値の列である。Lean の `Char` はスカラ値なので、長さは `String.length` である。
- 文字クラスはコードポイントの閉区間で定める。
-/

namespace Spec.Prim

/-- スカラ値の個数（[Spec] の文字列長）。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def scalarLen (s : String) : Nat := s.length

/-- `c` のコードポイントが閉区間 `[lo, hi]` にある。 -/
def inRange (lo hi : Nat) (c : Char) : Bool := lo ≤ c.toNat && c.toNat ≤ hi

/-- `Half`: U+0020–U+007E -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def isHalf : Char → Bool := inRange 0x20 0x7E

/-- `HalfKana`: U+FF61–U+FF9F -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def isHalfKana : Char → Bool := inRange 0xFF61 0xFF9F

/-- `Katakana`: U+30A0–U+30FF -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def isKatakana : Char → Bool := inRange 0x30A0 0x30FF

/-- `Digit`: U+0030–U+0039 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def isDigit : Char → Bool := inRange 0x30 0x39

/-- `Blank`（空白）: U+0009–U+000D、U+001C–U+001F、U+0020、U+1680、U+2000–U+2006、U+2008–U+200A、
U+2028–U+2029、U+205F、U+3000（空白区切り文字のうち、改行を禁止する空白 U+00A0・U+2007・U+202F を除いたものと、
制御文字の空白） -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def isBlank (c : Char) : Bool :=
  inRange 0x09 0x0D c || inRange 0x1C 0x20 c || inRange 0x1680 0x1680 c || inRange 0x2000 0x2006 c ||
    inRange 0x2008 0x200A c || inRange 0x2028 0x2029 c || inRange 0x205F 0x205F c || inRange 0x3000 0x3000 c

/-- 空白以外の文字を含む。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def hasText (s : String) : Bool := s.any fun c => !isBlank c

/-- 制約 `FullWidth`: すべての文字が `Half` にも `HalfKana` にも属さない（空文字も合格）。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def fullWidth (s : String) : Bool := s.all fun c => !isHalf c && !isHalfKana c

/-- 制約 `FullWidthKatakana`: 1 文字以上で、すべての文字が `Katakana`。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def fullWidthKatakana (s : String) : Bool := !s.isEmpty && s.all isKatakana

/-- 制約 `HalfWidth`: 1 文字以上で、すべての文字が `Half`。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def halfWidth (s : String) : Bool := !s.isEmpty && s.all isHalf

/-- 制約 `HalfWidthNumber`: 1 文字以上で、すべての文字が `Digit`。 -/
@[spec_doc "docs/spec/input-validation.md#文字クラス"]
def halfWidthNumber (s : String) : Bool := !s.isEmpty && s.all isDigit

#guard scalarLen "a𠮷" == 2
#guard fullWidth "" && fullWidth "山田" && !fullWidth "山田a" && !fullWidth "ｱ" && fullWidth "𠮷"
#guard fullWidthKatakana "ヤマダ" && fullWidthKatakana "ー" && !fullWidthKatakana "" && !fullWidthKatakana "やまだ"
#guard halfWidth "abc ~" && !halfWidth "" && !halfWidth "\t"
#guard halfWidthNumber "0123" && !halfWidthNumber "" && !halfWidthNumber "１"

end Spec.Prim
