import Spec

/-!
# Tests.SpecChecks

`Spec` の土台（backlog 591d）の検査。

- `dateExhaustive`: 0001-01-01〜9999-12-31 の全日について、`ofOrdinal?` が値を返し（取りこぼしが無い）、
  翌日が年月日の繰り上がりの規則どおりであることを確かめる（`Spec.Prim.Date` の冒頭を参照）。
- マスタの不変条件の判定（`#guard`）。
-/

open Spec Spec.Prim

namespace Tests.SpecChecks

/-- `d` の翌日の年月日（規則から直接求める）。 -/
def nextYmd (d : Date) : Nat × Nat × Nat :=
  if d.day < daysInMonth d.year d.month then (d.year, d.month, d.day + 1)
  else if d.month < 12 then (d.year, d.month + 1, 1)
  else (d.year + 1, 1, 1)

/-- 全日の検査。失敗した通算日数の一覧（先頭の数件）と、検査した日数を返す。 -/
def dateExhaustive : Array Nat × Nat := Id.run do
  let last : Date := ⟨9999, 12, 31, by decide⟩
  let mut bad : Array Nat := #[]
  let mut prev : Option Date := none
  for n in [0:last.ordinal + 1] do
    match Date.ofOrdinal? n with
    | none => if bad.size < 10 then bad := bad.push n
    | some d =>
      if let some p := prev then
        if nextYmd p != (d.year, d.month, d.day) then
          if bad.size < 10 then bad := bad.push n
      prev := some d
  if Date.ofOrdinal? (last.ordinal + 1) != none then bad := bad.push (last.ordinal + 1)
  return (bad, last.ordinal + 1)

/-! ## マスタの不変条件 -/

def hnd : Airport := ⟨⟨"HND"⟩, "東京（羽田）", 1⟩
def itm : Airport := ⟨⟨"ITM"⟩, "大阪（伊丹）", 2⟩
def route1 : Route := ⟨1, ⟨"HND"⟩, ⟨"ITM"⟩, 25000⟩
def route2 : Route := ⟨2, ⟨"ITM"⟩, ⟨"HND"⟩, 25000⟩
def hm (h m : Nat) (hv : h ≤ 23 ∧ m ≤ 59 := by decide) : HourMinute := ⟨h, m, hv⟩
def fm1 : FlightMaster := ⟨⟨"NTT001"⟩, 1, hm 7 0, hm 8 10, "B777"⟩
def fm2 : FlightMaster := ⟨⟨"NTT002"⟩, 1, hm 9 0, hm 10 10, "B777"⟩
def ow : FareType := ⟨.OW, "片道運賃", 0, 90, 0, 1, 1⟩
def gd : FareType := ⟨.GD, "グループ割", 30, 60, 1, 3, 7⟩
def bcN : BoardingClass := ⟨.N, "一般席", 0, 1⟩
def bcS : BoardingClass := ⟨.S, "特別席", 5000, 2⟩
def ymd (y m d : Nat) (h : IsValidYmd y m d := by decide) : Date := ⟨y, m, d, h⟩
def peak1 : PeakTime := ⟨"PEAK1", ymd 2026 12 26, ymd 2026 12 31, 140⟩
def peak2 : PeakTime := ⟨"PEAK2", ymd 2026 12 19, ymd 2026 12 25, 125⟩

def sample : MasterData where
  airports := [hnd, itm]
  routes := [route1, route2]
  flightMasters := [fm1, fm2]
  boardingClasses := [bcN, bcS]
  fareTypes := [ow, gd]
  peakTimes := [peak1, peak2]
  planes := [⟨"B777", 300, 20⟩]
  creditTypes := [⟨⟨"VIS"⟩, "VISA", 1⟩]

#guard decide (sample.Valid Config.default)
-- MD-2: 同じ区間
#guard !decide ({ sample with routes := [route1, { route2 with depAirportCd := ⟨"HND"⟩, arrAirportCd := ⟨"ITM"⟩ }] }.MD2)
-- MD-3: 存在しない空港
#guard !decide ({ sample with airports := [hnd] }.MD3)
-- MD-4: 重なるピーク時期
#guard !decide ({ sample with peakTimes := [peak1, { peak2 with peakEndDate := ymd 2026 12 26 }] }.MD4)
-- MD-5: 同一区間で同じ出発時刻
#guard !decide ({ sample with flightMasters := [fm1, { fm2 with departureTime := hm 7 0 }] }.MD5)
-- MD-6: 到着が出発より前
#guard !decide ({ sample with flightMasters := [{ fm1 with arrivalTime := hm 6 0 }] }.MD6)
-- MD-7: 割引率が小児運賃の比率を超える
#guard !decide ({ sample with fareTypes := [{ ow with discountRate := 61 }] }.MD7 Config.default)
-- MD-8: 基本運賃と加算料金の合計が値域を超える
#guard !decide ({ sample with routes := [{ route1 with basicFare := 9995001 }] }.MD8)
-- MD-8: 空港コードが英大文字 3 文字でない
#guard !decide ({ sample with airports := [hnd, { itm with code := ⟨"I-T"⟩ }] }.MD8)

#guard sample.multiplicationRatioOn (ymd 2026 12 26) == 140
#guard sample.multiplicationRatioOn (ymd 2026 12 25) == 125
#guard sample.multiplicationRatioOn (ymd 2027 1 1) == 100
#guard (sample.routeOf ⟨"ITM"⟩ ⟨"HND"⟩).map (·.routeNo) == some 2
#guard (sample.routeOf ⟨"HND"⟩ ⟨"HND"⟩).isNone
#guard CodeList.contains (CodeList.airport sample) "HND" && !CodeList.contains (CodeList.airport sample) "NOP"

end Tests.SpecChecks
