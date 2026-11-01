import LangSemantics.Java.Int

/-!
# LangSemantics.Java.DecimalFormat

`java.text.DecimalFormat` の意味のうち、整数を 3 桁区切りのパターン（`"###,###"` など、整数部だけで、
区切りの間隔が 3 のもの）で書式化する場合だけを定義する。

- 区切り文字は書式の記号（`DecimalFormatSymbols`）の `groupingSeparator` で、既定ではプロセスの既定の
  書式ロケール（`Locale.getDefault(Locale.Category.FORMAT)`）による。このモデルは区切り文字を引数に取る。
  日本語・英語のロケールでは `,` である。
- 負の数は `-` を前に付ける（既定の負の接頭辞）。0 は `"0"`（パターンの `#` だけでも最小の整数桁は 1）。

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

end LangSemantics.Java.DecimalFormat
