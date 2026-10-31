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
-- MD-8: 空港コードが区切り行のコード NOP
#guard !decide ({ sample with airports := [hnd, { itm with code := ⟨"NOP"⟩ }] }.MD8)

-- 参照の問い合わせの値域: 空白だけの便名は Valid でない（原典の Assert.hasText）
#guard !decide (MasterData.Query.flightMasterOf ⟨" "⟩).Valid
#guard !decide (MasterData.Query.flightMasterOf ⟨"\t\u3000"⟩).Valid
#guard decide (MasterData.Query.flightMasterOf ⟨"NTT1"⟩).Valid
#guard decide (MasterData.Query.flightMasterOf ⟨"\u00A0"⟩).Valid  -- 改行を禁止する空白は Blank でない
-- 文字クラス Blank の端
#guard [0x09, 0x0D, 0x1C, 0x20, 0x1680, 0x2006, 0x2008, 0x200A, 0x2028, 0x2029, 0x205F, 0x3000].all
  fun n => isBlank (Char.ofNat n)
#guard [0x08, 0x0E, 0x1B, 0x21, 0xA0, 0x2007, 0x200B, 0x202F, 0x3001].all fun n => !isBlank (Char.ofNat n)

#guard sample.multiplicationRatioOn (ymd 2026 12 26) == 140
#guard sample.multiplicationRatioOn (ymd 2026 12 25) == 125
#guard sample.multiplicationRatioOn (ymd 2027 1 1) == 100
#guard (sample.routeOf ⟨"ITM"⟩ ⟨"HND"⟩).map (·.routeNo) == some 2
#guard (sample.routeOf ⟨"HND"⟩ ⟨"HND"⟩).isNone
#guard CodeList.contains (CodeList.airport sample) "HND" && !CodeList.contains (CodeList.airport sample) "NOP"

/-! ### 運賃計算の意図から書く例（`docs/spec/fare-calculation.md` の例の表。ADR 9ac6 の採用 C）

期待値は表から手で書いたもので、`run`・ベクタから写していない。拒む例（[Source] の値・丸め前の値・マスタに無い入力）を含む。 -/

-- 基本運賃: floorDiv((routeBasicFare + extraCharge) * ratio, 100)。ピーク時期は 12/19〜25 が 125、12/26〜31 が 140
#guard Fare.basicFare sample 20600 .N (ymd 2026 11 1) == some 20600
#guard Fare.basicFare sample 20600 .N (ymd 2026 12 26) == some 28840
#guard Fare.basicFare sample 20600 .S (ymd 2026 12 20) == some 32000
#guard Fare.basicFare sample 37900 .S (ymd 2026 12 31) == some 60060
-- 拒む例: マスタに無い搭乗クラスでは基本運賃が無い
#guard Fare.basicFare { sample with boardingClasses := [bcN] } 20600 .S (ymd 2026 11 1) == none

-- 運賃: 割引後に 1 円未満を切り捨て、100 円単位に切り上げる
#guard Fare.fare 20600 0 == 20600
#guard Fare.fare 20600 5 == 19600
#guard Fare.fare 28840 30 == 20200
#guard Fare.fare 32000 10 == 28800
#guard Fare.fare 1430 30 == 1100
#guard Fare.fare 0 30 == 0
-- 拒む例: [Source] の値 1000（D-002）にはならない
#guard Fare.fare 1430 30 != 1000

-- 合計金額: 区間の基本運賃 20600、片道 OW（0%）・往復 RT（5%）、小児の比率 60%、大人は 12 歳以上
def rt : FareType := ⟨.RT, "往復運賃", 5, 90, 0, 1, 2⟩
def fareMd : MasterData :=
  { sample with routes := [{ route1 with basicFare := 20600 }, { route2 with basicFare := 20600 }],
                fareTypes := [ow, rt] }
def flight (name : String) (ft : FareTypeCd) : Flight := ⟨⟨ymd 2026 11 1, ⟨name⟩, .N, ft⟩, 10⟩
def pax (age : Nat) : Passenger := ⟨"山田", "太郎", age, .M, none⟩

#guard Fare.totalFare Config.default fareMd [flight "NTT001" .OW] [pax 30] == some 20600
#guard Fare.totalFare Config.default fareMd [flight "NTT001" .OW] [pax 30, pax 28, pax 5] == some 53600
#guard Fare.totalFare Config.default fareMd [flight "NTT001" .RT, flight "NTT002" .RT] [pax 40] == some 39200
#guard Fare.totalFare Config.default fareMd [flight "NTT001" .RT, flight "NTT002" .RT] [pax 40, pax 11] == some 61900
-- 拒む例: 切上げは合計にだけ行う（丸め前の 53560 ではない）。マスタに無い便名では合計が無い
#guard Fare.totalFare Config.default fareMd [flight "NTT001" .OW] [pax 30, pax 28, pax 5] != some 53560
#guard Fare.totalFare Config.default fareMd [flight "NTT999" .OW] [pax 30] == none

-- 基本運賃・運賃の抽象機械（ABS-001・ABS-002 の抽象側）: PRE と出力
def bfIn (rbf : Nat) (cd : BoardingClassCd) (d : Date) : Fare.BasicFareInput := ⟨Config.default, fareMd, rbf, cd, d⟩
#guard decide (bfIn 20600 .N (ymd 2026 11 1)).Pre
#guard (Fare.basicFareMachine.run () (bfIn 20600 .N (ymd 2026 11 1))).2 == 20600
-- 拒む例: 区間の運賃と加算料金の和が値域（10,000,000）を超える入力は PRE の外
#guard !decide (bfIn 10000000 .S (ymd 2026 11 1)).Pre
#guard (Fare.fareMachine.run () ⟨1430, 30⟩).2 == 1100
#guard decide (Fare.FareInput.Pre ⟨100000000, 100⟩)
-- 拒む例: 割引率 101 は PRE の外
#guard !decide (Fare.FareInput.Pre ⟨1430, 101⟩)

end Tests.SpecChecks
