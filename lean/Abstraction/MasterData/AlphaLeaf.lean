import Abstraction.Prim.Kernel
import LangSemantics.Java
import LangSemantics.Sql.Postgresql
import SourceModel.Repository.Schema
import Spec

/-!
# Abstraction.MasterData.AlphaLeaf

ABS-026 の標準の抽象化 α の、値の葉（`docs/spec/abstraction.md#抽象化関数-α`）。どれも部分写像で、
[Spec] の型で表せない値には定義しない（既知差異 D-027）。定義域の上で単射なので、核は `undefOrEq`（ABS-048）。

| 葉 | [Source] の値 | 定義しない値 |
| --- | --- | --- |
| `natOfInt4`・`natOfJ32` | `INT`・`int` | 負 |
| `dateOfPg` | `DATE` | 1〜9999 年の外 |
| `dateOfJ` | `LocalDate` | 正規でない値（月が 13 など）・1〜9999 年の外。通算日数で写す |
| `hmOfStr` | `HHmm` の文字列 | 4 桁の数字でない・時分の範囲外（例: `2415`） |
| `dateOfSlash` | `yyyy/MM/dd` の文字列 | その形でない・妥当でない年月日 |
| `bcCdOf`・`ftCdOf` | 列挙型のコードの文字列 | 未知のコード |
-/

namespace Abstraction.MasterData

open Machine LangSemantics.Java LangSemantics.Sql.Postgresql Spec Spec.Prim Spec.Prim.HourMinute Abstraction.Prim

/-! ## 数 -/

/-- `INT` の値（非負なら自然数）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def natOfInt4 (v : Int4) : Option Nat := if 0 ≤ v.val then some v.val.toNat else none

/-- `int` の値（非負なら自然数）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def natOfJ32 (v : J32) : Option Nat := if 0 ≤ v.val then some v.val.toNat else none

theorem natOfInt4_eq_some {v : Int4} {n : Nat} : natOfInt4 v = some n ↔ v.val = n := by
  unfold natOfInt4; split <;> simp <;> omega

theorem natOfJ32_eq_some {v : J32} {n : Nat} : natOfJ32 v = some n ↔ v.val = n := by
  unfold natOfJ32; split <;> simp <;> omega

@[obligation "ABS-048"]
theorem natOfInt4_kernel : KernelIs natOfInt4 (undefOrEq natOfInt4) :=
  kernelIs_undefOrEq fun x y _ hx hy => Subtype.ext (by
    rw [natOfInt4_eq_some] at hx hy; omega)

@[obligation "ABS-048"]
theorem natOfJ32_kernel : KernelIs natOfJ32 (undefOrEq natOfJ32) :=
  kernelIs_undefOrEq fun x y _ hx hy => BitVec.eq_of_toInt_eq (by
    rw [natOfJ32_eq_some] at hx hy; simp only [J32.val] at hx hy; omega)

/-! ## 暦日 -/

/-- `DATE` の値（1970-01-01 からの日数）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def dateOfPg (d : PgDate) : Option Date := Date.ofEpochDay? d.val

@[obligation "ABS-048"]
theorem dateOfPg_kernel : KernelIs dateOfPg (undefOrEq dateOfPg) :=
  kernelIs_undefOrEq fun x y _ hx hy => Subtype.ext (by
    rw [← Date.epochDay_ofEpochDay? hx, ← Date.epochDay_ofEpochDay? hy])

/-- `LocalDate` の値: 通算日数が同じ [Spec] の暦日。`LocalDate` として正規な値（通算日数から作り直して同じ値）
だけに定義する（月が 13 などの値には定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def dateOfJ (d : JLocalDate) : Option Date :=
  if JLocalDate.ofEpochDay d.toEpochDay = d then Date.ofEpochDay? d.toEpochDay else none

theorem ofYmd?_eq_some {y m d : Nat} {D : Date} (h : Date.ofYmd? y m d = some D) :
    D.year = y ∧ D.month = m ∧ D.day = d := by
  unfold Date.ofYmd? at h
  split at h
  · cases h; exact ⟨rfl, rfl, rfl⟩
  · cases h

theorem dateOfJ_eq_some {d : JLocalDate} {D : Date} (h : dateOfJ d = some D) :
    d = JLocalDate.ofEpochDay D.epochDay ∧ d.toEpochDay = D.epochDay := by
  unfold dateOfJ at h
  split at h
  · rename_i hc
    have e := Date.epochDay_ofEpochDay? h
    exact ⟨by rw [e, hc], e.symm⟩
  · cases h

/-- 通算日数から作った `LocalDate` の写しは、同じ通算日数の [Spec] の暦日。 -/
theorem dateOfJ_ofEpochDay (z : Int) : dateOfJ (JLocalDate.ofEpochDay z) = Date.ofEpochDay? z := by
  simp only [dateOfJ, JLocalDate.toEpochDay_ofEpochDay, ite_true]

@[obligation "ABS-048"]
theorem dateOfJ_kernel : KernelIs dateOfJ (undefOrEq dateOfJ) :=
  kernelIs_undefOrEq fun _ _ _ hx hy => (dateOfJ_eq_some hx).1.trans (dateOfJ_eq_some hy).1.symm

/-! ## 数字の文字列 -/

theorem digitVal?_eq_some {c : Char} {v : Nat} :
    digitVal? c = some v ↔ 48 ≤ c.toNat ∧ c.toNat ≤ 57 ∧ v = c.toNat - 48 := by
  have e1 : ('0' : Char) ≤ c ↔ 48 ≤ c.toNat := Iff.rfl
  have e2 : c ≤ ('9' : Char) ↔ c.toNat ≤ 57 := Iff.rfl
  unfold digitVal?
  split
  · rename_i h
    have : ('0' : Char).toNat = 48 := rfl
    simp only [Option.some.injEq, this]
    have := e1.mp h.1; have := e2.mp h.2; omega
  · rename_i h
    simp only [reduceCtorEq, false_iff]
    intro ⟨a, b, _⟩
    exact h ⟨e1.mpr a, e2.mpr b⟩

theorem digitVal?_lt {c : Char} {v : Nat} (h : digitVal? c = some v) : v < 10 := by
  rw [digitVal?_eq_some] at h; omega

theorem digitVal?_inj {a b : Char} {v : Nat} (ha : digitVal? a = some v) (hb : digitVal? b = some v) :
    a = b := by
  rw [digitVal?_eq_some] at ha hb
  exact Char.toNat_inj.mp (by omega)

/-- `HHmm` の時刻の文字列（[Spec] の `parseHHmm`）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def hmOfStr (s : String) : Option HourMinute := parseHHmm s

theorem ofHm?_eq_some {h m : Nat} {t : HourMinute} (e : ofHm? h m = some t) : t.hour = h ∧ t.minute = m := by
  unfold ofHm? at e
  split at e
  · cases e; exact ⟨rfl, rfl⟩
  · cases e

@[obligation "ABS-048"]
theorem hmOfStr_kernel : KernelIs hmOfStr (undefOrEq hmOfStr) := by
  apply kernelIs_undefOrEq
  intro s s' t hs hs'
  unfold hmOfStr parseHHmm at hs hs'
  apply String.toList_inj.mp
  split at hs <;> split at hs' <;> try simp at hs hs'
  rename_i a b c d ha _ a' b' c' d' ha'
  rw [ha, ha']
  simp only [Option.bind_eq_some_iff] at hs hs'
  obtain ⟨x1, e1, x2, e2, x3, e3, x4, e4, h⟩ := hs
  obtain ⟨y1, f1, y2, f2, y3, f3, y4, f4, h'⟩ := hs'
  obtain ⟨g1, g2⟩ := ofHm?_eq_some h
  obtain ⟨k1, k2⟩ := ofHm?_eq_some h'
  have := digitVal?_lt e1; have := digitVal?_lt e2; have := digitVal?_lt e3; have := digitVal?_lt e4
  have := digitVal?_lt f1; have := digitVal?_lt f2; have := digitVal?_lt f3; have := digitVal?_lt f4
  have q1 : x1 = y1 := by omega
  have q2 : x2 = y2 := by omega
  have q3 : x3 = y3 := by omega
  have q4 : x4 = y4 := by omega
  subst q1 q2 q3 q4
  rw [digitVal?_inj e1 f1, digitVal?_inj e2 f2, digitVal?_inj e3 f3, digitVal?_inj e4 f4]

/-- `yyyy/MM/dd` の暦日の文字列（設定 `atrs.dateOfBirthMinDate`。[Spec] の `fmtDate` の書式）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def dateOfSlash (s : String) : Option Date :=
  match s.toList with
  | [y1, y2, y3, y4, '/', m1, m2, '/', d1, d2] => do
    let a ← digitVal? y1
    let b ← digitVal? y2
    let c ← digitVal? y3
    let d ← digitVal? y4
    let e ← digitVal? m1
    let f ← digitVal? m2
    let g ← digitVal? d1
    let h ← digitVal? d2
    Date.ofYmd? (a * 1000 + b * 100 + c * 10 + d) (e * 10 + f) (g * 10 + h)
  | _ => none

@[obligation "ABS-048"]
theorem dateOfSlash_kernel : KernelIs dateOfSlash (undefOrEq dateOfSlash) := by
  apply kernelIs_undefOrEq
  intro s s' t hs hs'
  unfold dateOfSlash at hs hs'
  apply String.toList_inj.mp
  split at hs <;> split at hs' <;> try simp at hs hs'
  rename_i y1 y2 y3 y4 m1 m2 d1 d2 ha _ y1' y2' y3' y4' m1' m2' d1' d2' ha'
  rw [ha, ha']
  simp only [Option.bind_eq_some_iff] at hs hs'
  obtain ⟨x1, e1, x2, e2, x3, e3, x4, e4, x5, e5, x6, e6, x7, e7, x8, e8, h⟩ := hs
  obtain ⟨z1, f1, z2, f2, z3, f3, z4, f4, z5, f5, z6, f6, z7, f7, z8, f8, h'⟩ := hs'
  obtain ⟨g1, g2, g3⟩ := ofYmd?_eq_some h
  obtain ⟨k1, k2, k3⟩ := ofYmd?_eq_some h'
  have := digitVal?_lt e1; have := digitVal?_lt e2; have := digitVal?_lt e3; have := digitVal?_lt e4
  have := digitVal?_lt e5; have := digitVal?_lt e6; have := digitVal?_lt e7; have := digitVal?_lt e8
  have := digitVal?_lt f1; have := digitVal?_lt f2; have := digitVal?_lt f3; have := digitVal?_lt f4
  have := digitVal?_lt f5; have := digitVal?_lt f6; have := digitVal?_lt f7; have := digitVal?_lt f8
  obtain rfl : x1 = z1 := by omega
  obtain rfl : x2 = z2 := by omega
  obtain rfl : x3 = z3 := by omega
  obtain rfl : x4 = z4 := by omega
  obtain rfl : x5 = z5 := by omega
  obtain rfl : x6 = z6 := by omega
  obtain rfl : x7 = z7 := by omega
  obtain rfl : x8 = z8 := by omega
  rw [digitVal?_inj e1 f1, digitVal?_inj e2 f2, digitVal?_inj e3 f3, digitVal?_inj e4 f4,
    digitVal?_inj e5 f5, digitVal?_inj e6 f6, digitVal?_inj e7 f7, digitVal?_inj e8 f8]

/-! ## 列挙型のコード -/

/-- 搭乗クラスのコード（MyBatis の `EnumTypeHandler` の `Enum.valueOf`）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def bcCdOf (s : String) : Option BoardingClassCd := BoardingClassCd.ofCode? s

/-- 運賃種別のコード。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def ftCdOf (s : String) : Option FareTypeCd := FareTypeCd.ofCode? s

theorem bcCdOf_eq_some {s : String} {c : BoardingClassCd} (h : bcCdOf s = some c) : s = c.toCode := by
  unfold bcCdOf BoardingClassCd.ofCode? at h
  split at h <;> cases h <;> rfl

theorem ftCdOf_eq_some {s : String} {c : FareTypeCd} (h : ftCdOf s = some c) : s = c.toCode := by
  unfold ftCdOf FareTypeCd.ofCode? at h
  split at h <;> cases h <;> rfl

@[obligation "ABS-048"]
theorem bcCdOf_kernel : KernelIs bcCdOf (undefOrEq bcCdOf) :=
  kernelIs_undefOrEq fun _ _ _ hx hy => (bcCdOf_eq_some hx).trans (bcCdOf_eq_some hy).symm

@[obligation "ABS-048"]
theorem ftCdOf_kernel : KernelIs ftCdOf (undefOrEq ftCdOf) :=
  kernelIs_undefOrEq fun _ _ _ hx hy => (ftCdOf_eq_some hx).trans (ftCdOf_eq_some hy).symm

end Abstraction.MasterData
