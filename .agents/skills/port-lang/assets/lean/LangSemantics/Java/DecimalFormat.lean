import LangSemantics.Java.Int

/-!
# LangSemantics.Java.DecimalFormat

`java.text.DecimalFormat` の意味のうち、整数を 3 桁区切りのパターン（`"###,###"` など、整数部だけで、
区切りの間隔が 3 のもの）で書式化する場合だけを定義する。

- 書式の記号（`DecimalFormatSymbols`）は、既定ではプロセスの既定の書式ロケール（`Locale.getDefault(Locale.Category.FORMAT)`）
  による。この書式が使う記号は、区切り文字 `groupingSeparator`、数字の 0 `zeroDigit`（各数字は `zeroDigit` から数える）、
  負の記号の文字列（`minusSignText`。既定の負の接頭辞）である（`Symbols`。`formatGroupedS`）。日本語・英語のロケールでは
  `,`・`0`・`-` である（`Symbols.ascii`。`formatGrouped` は区切り文字だけを引数に取る特殊形）。
- 0 は `"0"`（パターンの `#` だけでも最小の整数桁は 1）。

lang: `dep:java.base#java.text.DecimalFormat`, `dep:java.base#java.text.DecimalFormatSymbols`
-/

namespace LangSemantics.Java.DecimalFormat
open LangSemantics.Java.Int

/-- 下位の桁から 3 桁ごとに区切り文字を挟む（引数・結果とも下位の桁が先頭）。 -/
def group3 (sep : Char) : List Char → List Char
  | a :: b :: c :: d :: rest => a :: b :: c :: sep :: group3 sep (d :: rest)
  | cs => cs

/-- 非負の整数の十進表記を 3 桁ごとに区切る。 -/
def groupNat (sep : Char) (n : Nat) : String :=
  String.ofList (group3 sep (toString n).toList.reverse).reverse

/-- `new DecimalFormat("###,###").format(n)`（区切り文字 `sep`）。`n` は `long` に広げた整数。 -/
def formatGrouped (sep : Char) (n : Int) : String :=
  if n < 0 then "-" ++ groupNat sep n.natAbs else groupNat sep n.toNat

/-- `int` の値の書式化（`format(long)` に広げる）。 -/
def formatJ32 (sep : Char) (x : J32) : String := formatGrouped sep x.val

/-- この書式が使う `DecimalFormatSymbols` の記号。 -/
structure Symbols where
  groupingSeparator : Char
  zeroDigit : Char
  /-- 負の接頭辞（`DecimalFormatSymbols` の負の記号の文字列。方向の制御文字を含みうる） -/
  minusSignText : String
  deriving DecidableEq, Repr

/-- 日本語・英語のロケールの記号。 -/
def Symbols.ascii : Symbols := ⟨',', '0', "-"⟩

/-- ASCII の数字を、記号の `zeroDigit` から数えた数字に置き換える。 -/
def localizeDigit (s : Symbols) (c : Char) : Char :=
  if '0' ≤ c ∧ c ≤ '9' then Char.ofNat (s.zeroDigit.toNat + (c.toNat - '0'.toNat)) else c

/-- `new DecimalFormat("###,###", symbols).format(n)`。 -/
def formatGroupedS (s : Symbols) (n : Int) : String :=
  (if n < 0 then s.minusSignText else "") ++
    String.ofList ((group3 s.groupingSeparator (toString n.natAbs).toList.reverse).reverse.map (localizeDigit s))

/-- `int` の値の書式化（記号 `s`）。 -/
def formatJ32S (s : Symbols) (x : J32) : String := formatGroupedS s x.val

theorem localizeDigit_zero (sep : Char) (m : String) (c : Char) : localizeDigit ⟨sep, '0', m⟩ c = c := by
  unfold localizeDigit
  split
  · rename_i h
    have : '0'.toNat ≤ c.toNat := by
      have := Char.le_def.mp h.1; rw [UInt32.le_iff_toNat_le] at this; exact this
    show Char.ofNat ('0'.toNat + (c.toNat - '0'.toNat)) = c
    rw [Nat.add_sub_cancel' this, Char.ofNat_toNat]
  · rfl

/-- 記号の数字が ASCII で負の記号が `-` なら、`formatGroupedS` は `formatGrouped`。 -/
theorem formatGroupedS_ascii (sep : Char) (n : Int) : formatGroupedS ⟨sep, '0', "-"⟩ n = formatGrouped sep n := by
  have hm : ∀ l : List Char, l.map (localizeDigit ⟨sep, '0', "-"⟩) = l := fun l => by
    rw [show localizeDigit ⟨sep, '0', "-"⟩ = id from funext (localizeDigit_zero sep "-"), List.map_id]
  unfold formatGroupedS formatGrouped groupNat
  rw [hm]
  by_cases h : n < 0
  · simp [h]
  · have e : n.natAbs = n.toNat := by omega
    simp only [h, ↓reduceIte, String.empty_append, e]

end LangSemantics.Java.DecimalFormat
