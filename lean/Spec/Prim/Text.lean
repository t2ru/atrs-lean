import Trace

/-!
# 文字列の長さと文字クラス（`Spec.Prim.Text`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

文字列の長さの数え方と、入力検証が使う文字クラス（半角・半角カナ・全角カタカナ・数字・空白）を定める。
文字列は Unicode スカラ値の列で、長さはスカラ値の個数である。文字クラスはコードポイントの閉区間で定める。
文字クラスを使う入力検証の制約（`FullWidth`・`Size` など）は [`Spec.Validation`](../Validation.lean#単項目検証の制約) にある。
-/

namespace Spec.Prim.Text

/-!
## 文字クラス

**[Spec=Source]** 文字クラスは、コードポイントの閉区間で定義する。

| 名前 | 文字集合 |
| --- | --- |
| `Half` | U+0020–U+007E |
| `HalfKana` | U+FF61–U+FF9F |
| `Katakana` | U+30A0–U+30FF（`゠`, `・`, `ー`, `ヽ`, `ヾ`, `ヿ` を含む） |
| `Digit` | U+0030–U+0039 |
| `Blank` | U+0009–U+000D、U+001C–U+0020、U+1680、U+2000–U+2006、U+2008–U+200A、U+2028–U+2029、U+205F、U+3000（Java の `Character.isWhitespace` と同じ集合。改行を禁止する空白 U+00A0・U+2007・U+202F は含まない）。`Blank` 以外の文字を含む文字列を「空白でない」という（`hasText`） |

文字列の長さ `len` は、[Spec] ではスカラ値の個数 `scalarLen`、[Source] では UTF-16 の符号単位の個数 `utf16Len` である（補助文字（U+10000 以上）を含む文字列で異なる。既知差異 [D-006](../../../docs/spec/abstraction.md#既知差異)）。
-/

/-- スカラ値の個数（[Spec] の文字列長）。 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def scalarLen (s : String) : Nat := s.length

/-- `c` のコードポイントが閉区間 `[lo, hi]` にある。 -/
def inRange (lo hi : Nat) (c : Char) : Bool := lo ≤ c.toNat && c.toNat ≤ hi

/-- `Half`: U+0020–U+007E -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def isHalf : Char → Bool := inRange 0x20 0x7E

/-- `HalfKana`: U+FF61–U+FF9F -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def isHalfKana : Char → Bool := inRange 0xFF61 0xFF9F

/-- `Katakana`: U+30A0–U+30FF -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def isKatakana : Char → Bool := inRange 0x30A0 0x30FF

/-- `Digit`: U+0030–U+0039 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def isDigit : Char → Bool := inRange 0x30 0x39

/-- `Blank`（空白）: U+0009–U+000D、U+001C–U+001F、U+0020、U+1680、U+2000–U+2006、U+2008–U+200A、
U+2028–U+2029、U+205F、U+3000（空白区切り文字のうち、改行を禁止する空白 U+00A0・U+2007・U+202F を除いたものと、
制御文字の空白） -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def isBlank (c : Char) : Bool :=
  inRange 0x09 0x0D c || inRange 0x1C 0x20 c || inRange 0x1680 0x1680 c || inRange 0x2000 0x2006 c ||
    inRange 0x2008 0x200A c || inRange 0x2028 0x2029 c || inRange 0x205F 0x205F c || inRange 0x3000 0x3000 c

/-- 空白以外の文字を含む。 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def hasText (s : String) : Bool := s.any fun c => !isBlank c

/-- 制約 `FullWidth`: すべての文字が `Half` にも `HalfKana` にも属さない（空文字も合格）。 -/
@[spec_doc "lean/Spec/Validation.lean#単項目検証の制約"]
def fullWidth (s : String) : Bool := s.all fun c => !isHalf c && !isHalfKana c

/-- 制約 `FullWidthKatakana`: 1 文字以上で、すべての文字が `Katakana`。 -/
@[spec_doc "lean/Spec/Validation.lean#単項目検証の制約"]
def fullWidthKatakana (s : String) : Bool := !s.isEmpty && s.all isKatakana

/-- 制約 `HalfWidth`: 1 文字以上で、すべての文字が `Half`。 -/
@[spec_doc "lean/Spec/Validation.lean#単項目検証の制約"]
def halfWidth (s : String) : Bool := !s.isEmpty && s.all isHalf

/-- 制約 `HalfWidthNumber`: 1 文字以上で、すべての文字が `Digit`。 -/
@[spec_doc "lean/Spec/Validation.lean#単項目検証の制約"]
def halfWidthNumber (s : String) : Bool := !s.isEmpty && s.all isDigit

#guard scalarLen "a𠮷" == 2
#guard fullWidth "" && fullWidth "山田" && !fullWidth "山田a" && !fullWidth "ｱ" && fullWidth "𠮷"
#guard fullWidthKatakana "ヤマダ" && fullWidthKatakana "ー" && !fullWidthKatakana "" && !fullWidthKatakana "やまだ"
#guard halfWidth "abc ~" && !halfWidth "" && !halfWidth "\t"
#guard halfWidthNumber "0123" && !halfWidthNumber "" && !halfWidthNumber "１"

end Spec.Prim.Text

/-!
## 根拠と対応

- 根拠: [ADR 10a5](../../../docs/decision/10a5-text-length-and-character-classes.md)（文字列の長さと文字クラス）
- 既知差異: D-006（文字列の長さ）。[一覧](../../../docs/spec/abstraction.md#既知差異)
-/
