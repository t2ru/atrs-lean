import Spec.Prim.Date

/-!
# Spec.Prim.Time

時刻と日時（`docs/spec/domain-model.md#hourminute`・`#datetime`、ADR 6eb2）。
-/

namespace Spec.Prim.Time

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

/-- 到着時刻（出発日 0:00 からの時分。0:00〜47:59。`24:15` は翌日の 0:15）。
便マスタの到着時刻だけに使う（ADR ce36）。 -/
@[spec_doc "docs/spec/domain-model.md#arrivaltime"]
structure ArrivalTime where
  hour : Nat
  minute : Nat
  valid : hour ≤ 47 ∧ minute ≤ 59
  deriving DecidableEq

namespace ArrivalTime

instance : Repr ArrivalTime where
  reprPrec t _ := s!"{t.hour}:{t.minute}"

/-- 到着時刻を作る。範囲外なら無し。 -/
@[spec_doc "docs/spec/domain-model.md#arrivaltime"]
def ofHm? (h m : Nat) : Option ArrivalTime := if hv : h ≤ 47 ∧ m ≤ 59 then some ⟨h, m, hv⟩ else none

/-- 出発日 0:00 からの分数。 -/
@[spec_doc "docs/spec/domain-model.md#arrivaltime"]
def toMinutes (t : ArrivalTime) : Nat := t.hour * 60 + t.minute

/-- 4 桁の数字列 `HHmm` を到着時刻に変換する。4 文字の数字列で、到着時刻の範囲内のものだけを受け付ける。 -/
@[spec_doc "docs/spec/domain-model.md#arrivaltime"]
def parseHHmm (s : String) : Option ArrivalTime :=
  match s.toList with
  | [a, b, c, d] => do
    let h ← HourMinute.digitVal? a
    let h' ← HourMinute.digitVal? b
    let m ← HourMinute.digitVal? c
    let m' ← HourMinute.digitVal? d
    ofHm? (h * 10 + h') (m * 10 + m')
  | _ => none

/-- 同じ日の時分を到着時刻とみなす。 -/
def ofHourMinute (t : HourMinute) : ArrivalTime := ⟨t.hour, t.minute, by have := t.valid; omega⟩

theorem toMinutes_ofHourMinute (t : HourMinute) : (ofHourMinute t).toMinutes = t.toMinutes := rfl

theorem toMinutes_lt (t : ArrivalTime) : t.toMinutes < 2880 := by
  have := t.valid; unfold toMinutes; omega

theorem toMinutes_inj {a b : ArrivalTime} (h : a.toMinutes = b.toMinutes) : a = b := by
  obtain ⟨ah, am, av⟩ := a
  obtain ⟨bh, bm, bv⟩ := b
  simp only [toMinutes] at h
  simp only [mk.injEq]; omega

end ArrivalTime

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

end Spec.Prim.Time
