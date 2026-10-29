import Spec.Prim.Date

/-!
# Spec.Prim.Time

時刻と日時（`docs/spec/domain-model.md#hourminute`・`#datetime`、ADR 0009）。
-/

namespace Spec.Prim

/-- 時分（0:00〜23:59）。 -/
@[spec_doc "docs/spec/domain-model.md#hourminute"]
structure HourMinute where
  hour : Nat
  minute : Nat
  valid : hour ≤ 23 ∧ minute ≤ 59
  deriving DecidableEq

namespace HourMinute

instance : Repr HourMinute where
  reprPrec t _ := s!"{t.hour}:{t.minute}"

/-- 時分を作る。範囲外なら無し。 -/
@[spec_doc "docs/spec/domain-model.md#hourminute"]
def ofHm? (h m : Nat) : Option HourMinute := if hv : h ≤ 23 ∧ m ≤ 59 then some ⟨h, m, hv⟩ else none

/-- 0:00 からの分数。 -/
@[spec_doc "docs/spec/domain-model.md#hourminute"]
def toMinutes (t : HourMinute) : Nat := t.hour * 60 + t.minute

instance : LT HourMinute := ⟨fun a b => a.toMinutes < b.toMinutes⟩
instance : LE HourMinute := ⟨fun a b => a.toMinutes ≤ b.toMinutes⟩
instance (a b : HourMinute) : Decidable (a < b) := inferInstanceAs (Decidable (a.toMinutes < b.toMinutes))
instance (a b : HourMinute) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.toMinutes ≤ b.toMinutes))

/-- 数字 1 文字の値。 -/
def digitVal? (c : Char) : Option Nat := if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat) else none

/-- 4 桁の数字列 `HHmm` を時分に変換する。4 文字の数字列で、時分の範囲内のものだけを受け付ける。 -/
@[spec_doc "docs/spec/domain-model.md#hourminute"]
def parseHHmm (s : String) : Option HourMinute :=
  match s.toList with
  | [a, b, c, d] => do
    let h ← digitVal? a
    let h' ← digitVal? b
    let m ← digitVal? c
    let m' ← digitVal? d
    ofHm? (h * 10 + h') (m * 10 + m')
  | _ => none

theorem toMinutes_lt (t : HourMinute) : t.toMinutes < 1440 := by
  have := t.valid; unfold toMinutes; omega

theorem toMinutes_inj {a b : HourMinute} (h : a.toMinutes = b.toMinutes) : a = b := by
  obtain ⟨ah, am, av⟩ := a
  obtain ⟨bh, bm, bv⟩ := b
  simp only [toMinutes] at h
  simp only [mk.injEq]; omega

end HourMinute

/-- 日時（暦日と時・分・秒）。 -/
@[spec_doc "docs/spec/domain-model.md#datetime"]
structure DateTime where
  date : Date
  hour : Nat
  minute : Nat
  second : Nat
  valid : hour ≤ 23 ∧ minute ≤ 59 ∧ second ≤ 59
  deriving DecidableEq

namespace DateTime

/-- 日付 `d` と時刻 `t` の日時 `at(d, t)`（秒は 0）。 -/
@[spec_doc "docs/spec/domain-model.md#datetime"]
def atTime (d : Date) (t : HourMinute) : DateTime := ⟨d, t.hour, t.minute, 0, ⟨t.valid.1, t.valid.2, by decide⟩⟩

/-- 1970-01-01 0:00 からの分数（秒は切り捨てる）。 -/
@[spec_doc "docs/spec/domain-model.md#datetime"]
def toEpochMinutes (dt : DateTime) : Int := dt.date.epochDay * 1440 + dt.hour * 60 + dt.minute

theorem toEpochMinutes_at (d : Date) (t : HourMinute) :
    (atTime d t).toEpochMinutes = d.epochDay * 1440 + t.toMinutes := by
  simp only [atTime, toEpochMinutes, HourMinute.toMinutes]; omega

end DateTime

end Spec.Prim
