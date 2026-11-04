import Trace

/-!
# Spec.Prim.Text

文字列長と[文字クラス](#文字クラス)（ADR 10a5）。

- 文字列は Unicode スカラ値の列である。Lean の `Char` はスカラ値なので、長さは `String.length` である。
- 文字クラスはコードポイントの閉区間で定める。
-/

namespace Spec.Prim.Text

/-!
## 文字クラス

**[Spec=Source]**（[ADR 10a5](../../../docs/decision/10a5-text-length-and-character-classes.md)）コードポイントの閉区間で定義する。

| 名前 | 文字集合 |
| --- | --- |
| `Half` | U+0020–U+007E |
| `HalfKana` | U+FF61–U+FF9F |
| `Katakana` | U+30A0–U+30FF（`゠`, `・`, `ー`, `ヽ`, `ヾ`, `ヿ` を含む） |
| `Digit` | U+0030–U+0039 |
| `Blank` | U+0009–U+000D、U+001C–U+0020、U+1680、U+2000–U+2006、U+2008–U+200A、U+2028–U+2029、U+205F、U+3000（Java の `Character.isWhitespace` と同じ集合。改行を禁止する空白 U+00A0・U+2007・U+202F は含まない）。`Blank` 以外の文字を含む文字列を「空白でない」という（`hasText`） |

| 制約 | 合格条件（未入力は合格） | コード |
| --- | --- | --- |
| `FullWidth` | すべての文字が `Half` にも `HalfKana` にも属さない（空文字も合格） | `FullWidth` |
| `FullWidthKatakana` | 1 文字以上で、すべての文字が `Katakana` | `FullWidthKatakana` |
| `HalfWidth` | 1 文字以上で、すべての文字が `Half` | `HalfWidth` |
| `HalfWidthNumber` | 1 文字以上で、すべての文字が `Digit` | `HalfWidthNumber` |
| `Size(min, max)` | `min ≤ len ≤ max` | `Size` |
| `FixedLength(n)` | `len = n` | `FixedLength` |
| `Email` | 電子メールアドレスの形式 | `Email` |
| `Min(n)` / `Max(n)` | 数値として `≥ n` / `≤ n`。文字列項目の場合は十進整数（`[0-9]+`）として解釈し、解釈できなければ不合格。[Source] は文字列を `BigDecimal` として解釈するので `"1.5"`・`"+1"`・`"1e1"` も数として比較される（既知差異 [D-018](../../../docs/spec/abstraction.md#既知差異)） | `Min` / `Max` |
| `Digits(i, f)` | 整数部 `i` 桁以下・小数部 `f` 桁以下 | `Digits` |
| `Required` | 入力がある | `NotNull`（文字列で空文字も不可の場合 `NotEmpty`） |
| `InCodeList(id)` | 値がコードリスト `id`（[`Spec.Env.CodeList`](../Env/CodeList.lean#空港コードリスト画面用)）に存在 | `ExistInCodeList` |

`len` は [Spec] では `scalarLen`、[Source] では `utf16Len`（既知差異 [D-006](../../../docs/spec/abstraction.md#既知差異)）。

### Email

**[Spec]**（[ADR ac33](../../../docs/decision/ac33-email-validation-rule.md)）原典の Hibernate Validator 9.1.0.Final `AbstractEmailValidator`・`DomainNameUtil` の規則から、IDN 変換（`IDN.toASCII`）を除いたもの。文字列 `s` について:

1. `s` が空文字なら合格（REST で空文字が送られた場合も合格）。
2. `s` に `@` が無ければ不合格。**最後の** `@` で、前をローカル部 `l`、後をドメイン部 `d` に分ける。
3. ローカル部: `len(l) ≤ 64` で、`l` が下記の `LOCAL` に一致する。
4. ドメイン部: `d` が `.` で終わらず、`d` を `.` で区切った各部分の長さが 63 以下、`len(d) ≤ 255` で、`d` が下記の `DOMAIN` に一致する。

照合は ASCII の英字の大小を区別しない（`a-z` は `A-Z` も含む）。`len` はスカラ値の数。

```
LATOM   = [a-z0-9!#$%&'*+/=?^_`{|}~-] | U+0080–U+FFFF
QATOM   = [a-z0-9!#$%&'*.(),<>\[\]:; @+/=?^_`{|}~-] | U+0080–U+FFFF | "\\" | "\""
LWORD   = LATOM+ | '"' QATOM+ '"'
LOCAL   = LWORD ("." LWORD)*

DCHAR   = [a-z0-9!#$%&'*+/=?^_`{|}~] | U+0080–U+FFFF
LABEL   = DCHAR+ ("-"+ DCHAR+)*
DOMAIN  = LABEL ("." LABEL)*
        | "[" IPV4 "]"
        | "[IPv6:" IPV6 "]"
IPV4    = [0-9]{1,3} "." [0-9]{1,3} "." [0-9]{1,3} "." [0-9]{1,3}   （各部の値の範囲は検査しない）
IPV6    = 下記の正規表現（原典 DomainNameUtil.IP_V6_DOMAIN と同一）
```

```
(?:(?:[0-9a-f]{1,4}:){7,7}[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,7}:|(?:[0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,5}(?::[0-9a-f]{1,4}){1,2}|(?:[0-9a-f]{1,4}:){1,4}(?::[0-9a-f]{1,4}){1,3}|(?:[0-9a-f]{1,4}:){1,3}(?::[0-9a-f]{1,4}){1,4}|(?:[0-9a-f]{1,4}:){1,2}(?::[0-9a-f]{1,4}){1,5}|[0-9a-f]{1,4}:(?:(?::[0-9a-f]{1,4}){1,6})|:(?:(?::[0-9a-f]{1,4}){1,7}|:)|fe80:(?::[0-9a-f]{0,4}){0,4}%[0-9a-z]{1,}|::(?:ffff(:0{1,4}){0,1}:){0,1}(?:(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])|(?:[0-9a-f]{1,4}:){1,4}:(?:(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(?:25[0-5]|(?:2[0-4]|1{0,1}[0-9]){0,1}[0-9]))
```

（原典の `a-fA-F`・`a-zA-Z` は、大小を区別しない照合なので `a-f`・`a-z` と書いた。）

`QATOM` の `"\\"`・`"\""` は、それぞれ 2 文字の列 `\\`・`\"` である。U+10000 以上の文字はどの集合にも属さない。
各部分の長さ 63 以下という条件は、原典では `IDN.toASCII` の検査として課される（ASCII のドメインでも課される）。

**[Source]** ドメイン部に `IDN.toASCII` を適用し、失敗すれば不合格、変換後の長さ（UTF-16 単位）が 255 を超えれば不合格とする。正規表現の照合は変換前の文字列に対して行う。ドメイン部が ASCII だけからなる場合は [Spec] と一致する（既知差異 [D-011](../../../docs/spec/abstraction.md#既知差異)）。

出典: hibernate-validator 9.1.0.Final `AbstractEmailValidator.isValid`, `DomainNameUtil.isValidEmailDomainAddress`
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
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def fullWidth (s : String) : Bool := s.all fun c => !isHalf c && !isHalfKana c

/-- 制約 `FullWidthKatakana`: 1 文字以上で、すべての文字が `Katakana`。 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def fullWidthKatakana (s : String) : Bool := !s.isEmpty && s.all isKatakana

/-- 制約 `HalfWidth`: 1 文字以上で、すべての文字が `Half`。 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def halfWidth (s : String) : Bool := !s.isEmpty && s.all isHalf

/-- 制約 `HalfWidthNumber`: 1 文字以上で、すべての文字が `Digit`。 -/
@[spec_doc "lean/Spec/Prim/Text.lean#文字クラス"]
def halfWidthNumber (s : String) : Bool := !s.isEmpty && s.all isDigit

#guard scalarLen "a𠮷" == 2
#guard fullWidth "" && fullWidth "山田" && !fullWidth "山田a" && !fullWidth "ｱ" && fullWidth "𠮷"
#guard fullWidthKatakana "ヤマダ" && fullWidthKatakana "ー" && !fullWidthKatakana "" && !fullWidthKatakana "やまだ"
#guard halfWidth "abc ~" && !halfWidth "" && !halfWidth "\t"
#guard halfWidthNumber "0123" && !halfWidthNumber "" && !halfWidthNumber "１"

end Spec.Prim.Text
