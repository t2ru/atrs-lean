import LangSemantics.Java.Int

/-!
# LangSemantics.Java.DecimalFormat

`java.text.DecimalFormat` の意味のうち、整数を 3 桁区切りのパターン（`"###,###"` など、整数部だけで、
区切りの間隔が 3 のもの）で書式化する場合だけを定義する。

- 書式の記号（`DecimalFormatSymbols`）は、既定ではプロセスの既定の書式ロケール（`Locale.getDefault(Locale.Category.FORMAT)`）
  による。この書式が使う記号は、区切り文字 `groupingSeparator`、数字の 0 `zeroDigit`（各数字は `zeroDigit` から数える）、
  負の記号の文字列（`minusSignText`。既定の負の接頭辞）である（`Symbols`。`formatGroupedS`）。日本語・英語のロケールでは
  `,`・`0`・`-` である（`Symbols.ascii`。`formatGrouped` は区切り文字だけを引数に取る特殊形）。`Symbols` は形の証明
  （`Symbols.valid`。数字が Unicode のスカラー値で、区切り文字が数字でなく、負の記号が空でない）を持つ。
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

/-- 記号の形: 数字（`zeroDigit` から数えた 10 文字）がどれも Unicode のスカラー値で（`localizeDigit` の `Char.ofNat` が
`'\0'` に落ちない）、区切り文字がそのどれでもなく、負の記号の文字列が空でない（`toList` で見る）。 -/
def Symbols.valid (groupingSeparator zeroDigit : Char) (minusSignText : String) : Bool :=
  (List.range 10).all (fun i => decide (zeroDigit.toNat + i).isValidChar && groupingSeparator.toNat != zeroDigit.toNat + i) &&
    !minusSignText.toList.isEmpty

/-- この書式が使う `DecimalFormatSymbols` の記号。形（`Symbols.valid`）の証明を持つ。 -/
structure Symbols where
  groupingSeparator : Char
  zeroDigit : Char
  /-- 負の接頭辞（`DecimalFormatSymbols` の負の記号の文字列。方向の制御文字を含みうる） -/
  minusSignText : String
  wf : Symbols.valid groupingSeparator zeroDigit minusSignText = true := by decide
  deriving DecidableEq, Repr

/-- 記号を作る。形に合わなければ無し。 -/
def Symbols.mk? (groupingSeparator zeroDigit : Char) (minusSignText : String) : Option Symbols :=
  if h : Symbols.valid groupingSeparator zeroDigit minusSignText then some ⟨groupingSeparator, zeroDigit, minusSignText, h⟩
  else none

/-- 記号は 3 つの値で決まる。 -/
theorem Symbols.ext {a b : Symbols} (h1 : a.groupingSeparator = b.groupingSeparator) (h2 : a.zeroDigit = b.zeroDigit)
    (h3 : a.minusSignText = b.minusSignText) : a = b := by
  cases a; cases b; cases h1; cases h2; cases h3; rfl

/-- 記号の値から作ると、その記号。 -/
@[simp] theorem Symbols.mk?_self (s : Symbols) : Symbols.mk? s.groupingSeparator s.zeroDigit s.minusSignText = some s := by
  simp [Symbols.mk?, s.wf]

/-- 作れるのは、形に合うときに限る。 -/
theorem Symbols.mk?_isSome_iff {g z : Char} {m : String} : (Symbols.mk? g z m).isSome ↔ Symbols.valid g z m = true := by
  unfold Symbols.mk?
  split <;> simp_all

/-- 日本語・英語のロケールの記号。 -/
def Symbols.ascii : Symbols := ⟨',', '0', "-", by decide⟩

/-- ASCII の数字を、記号の `zeroDigit` から数えた数字に置き換える。 -/
def localizeDigit (s : Symbols) (c : Char) : Char :=
  if '0' ≤ c ∧ c ≤ '9' then Char.ofNat (s.zeroDigit.toNat + (c.toNat - '0'.toNat)) else c

/-- `new DecimalFormat("###,###", symbols).format(n)`。 -/
def formatGroupedS (s : Symbols) (n : Int) : String :=
  (if n < 0 then s.minusSignText else "") ++
    String.ofList ((group3 s.groupingSeparator (toString n.natAbs).toList.reverse).reverse.map (localizeDigit s))

/-- `int` の値の書式化（記号 `s`）。 -/
def formatJ32S (s : Symbols) (x : J32) : String := formatGroupedS s x.val

theorem Symbols.digit_valid (s : Symbols) {i : Nat} (hi : i < 10) :
    (s.zeroDigit.toNat + i).isValidChar ∧ s.groupingSeparator.toNat ≠ s.zeroDigit.toNat + i := by
  have h := s.wf
  simp only [Symbols.valid, Bool.and_eq_true, List.all_eq_true, List.mem_range, decide_eq_true_eq,
    bne_iff_ne, ne_eq] at h
  exact h.1 i hi

theorem toNat_ofNat_of_valid {n : Nat} (h : n.isValidChar) : (Char.ofNat n).toNat = n := by
  simp only [Char.ofNat, h, ↓reduceDIte, Char.ofNatAux, Char.toNat]
  simp [UInt32.toNat_ofNatLT]

/-- ASCII の数字の置き換えは、`zeroDigit` から数えた文字そのもの（形の証明により `'\0'` に落ちない）。 -/
theorem localizeDigit_toNat (s : Symbols) {c : Char} (hc : '0' ≤ c ∧ c ≤ '9') :
    (localizeDigit s c).toNat = s.zeroDigit.toNat + (c.toNat - '0'.toNat) := by
  have h1 : c.toNat ≤ '9'.toNat := by
    have := Char.le_def.mp hc.2; rw [UInt32.le_iff_toNat_le] at this; exact this
  have hi : c.toNat - '0'.toNat < 10 := by
    have : '9'.toNat = 57 := rfl
    have : '0'.toNat = 48 := rfl
    omega
  simp only [localizeDigit, hc, and_self, ↓reduceIte]
  exact toNat_ofNat_of_valid (s.digit_valid hi).1

/-- 置き換えた数字は、区切り文字ではない（書式化の結果から数字と区切りを読み分けられる）。 -/
theorem localizeDigit_ne_sep (s : Symbols) {c : Char} (hc : '0' ≤ c ∧ c ≤ '9') :
    localizeDigit s c ≠ s.groupingSeparator := by
  have h1 : c.toNat ≤ '9'.toNat := by
    have := Char.le_def.mp hc.2; rw [UInt32.le_iff_toNat_le] at this; exact this
  have hi : c.toNat - '0'.toNat < 10 := by
    have : '9'.toNat = 57 := rfl
    have : '0'.toNat = 48 := rfl
    omega
  intro he
  have := congrArg Char.toNat he
  rw [localizeDigit_toNat s hc] at this
  exact (s.digit_valid hi).2 this.symm

/-- 記号の零の数字が `0` なら、ASCII の数字はそのまま。 -/
theorem localizeDigit_zero (s : Symbols) (hz : s.zeroDigit = '0') (c : Char) : localizeDigit s c = c := by
  unfold localizeDigit
  split
  · rename_i h
    have : '0'.toNat ≤ c.toNat := by
      have := Char.le_def.mp h.1; rw [UInt32.le_iff_toNat_le] at this; exact this
    rw [hz]
    show Char.ofNat ('0'.toNat + (c.toNat - '0'.toNat)) = c
    rw [Nat.add_sub_cancel' this, Char.ofNat_toNat]
  · rfl

/-- 記号の数字が ASCII で負の記号が `-` なら、`formatGroupedS` は（記号の区切り文字の）`formatGrouped`。 -/
theorem formatGroupedS_ascii (s : Symbols) (hz : s.zeroDigit = '0') (hm : s.minusSignText = "-") (n : Int) :
    formatGroupedS s n = formatGrouped s.groupingSeparator n := by
  have hmap : ∀ l : List Char, l.map (localizeDigit s) = l := fun l => by
    rw [show localizeDigit s = id from funext (localizeDigit_zero s hz), List.map_id]
  unfold formatGroupedS formatGrouped groupNat
  rw [hmap, hm]
  by_cases h : n < 0
  · simp [h]
  · have e : n.natAbs = n.toNat := by omega
    simp only [h, ↓reduceIte, String.empty_append, e]

end LangSemantics.Java.DecimalFormat
