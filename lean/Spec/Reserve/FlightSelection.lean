import Spec.Prim
import Spec.Model
import Spec.Env.Config
import Spec.Env.MasterData
import Spec.Fare
import Spec.Error
import Spec.World

/-!
# 選択フライトとその検証（`Spec.Reserve.FlightSelection`）

> **区分: 要約（informative）。** 本文は本章の Lean の定義の非規範の要約で、食い違ったら Lean が正である。

予約確認・予約確定の前段で、利用者が空席照会の結果から選んだフライト（選択フライト）をマスタで解決し、その整合性を
検証する（画面 B0 の共通処理）。

- 選択フライト `SelectFlight` の便名は外部の入力なので文字列のまま持ち、便マスタで引く。解決したもの
  `ResolvedFlight` の主キーの便名は便マスタの便名である。便マスタが無ければ解決できず（`none`）、次の検証で
  `InvalidRequest` にする。
- `validateFlightList` は、成功すれば予約する便（片道・往復。`Itinerary`）の主キーを返す。改竄（通常の画面操作では
  起きない値）は `InvalidRequest`、利用者の選択ミスは `Business` とする。`InvalidRequest` の詳細の文字列は、
  実装が変えてよい部分（自由な選択 N-004）である。
- 往路便の到着日時は、出発日 0:00 からの分数（翌日着を含む）で数える。
-/

namespace Spec.Reserve.FlightSelection
open Spec.Env
open Spec.Env.Config Spec.Model Spec.Prim Spec.Prim.Time Spec.Error Spec.Env.MasterData

/-!
## 選択フライト

画面から送られる選択フライトは `SelectFlight = { depDate, flightName, boardingClassCd, fareTypeCd }` の列（往路、復路の順）である。
これをマスタで解決したものが `ResolvedFlight`（フライトの主キーと便マスタ）である。

**[Spec=Source]** `resolve(md, sel) : Option ResolvedFlight`: 便マスタを便名（生の文字列）の値で引き、主キーの便名は便マスタの便名とする。搭乗クラス・運賃種別は主キーのコードのまま持ち、検証・登録の段でマスタを引く。便マスタが無ければ解決の結果は無く（`none`）、次の検証で `InvalidRequest` にする。便名が空白だけ（U+3000 など）の場合も同じである。[Source] は `FlightMasterProvider.getFlightMaster` の `Assert.hasText` で例外（500）になる（既知差異 [D-039](../../../docs/spec/abstraction.md#既知差異)）。

出典: `java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)`
-/

/-- 画面から送られる選択フライト（往路、復路の順）。便名は外部の入力なので文字列のまま持つ（便マスタで引く）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#選択フライト", raw_input "画面・REST の選択フライト。検証済みの便は validateFlightList が Itinerary で返す"]
structure SelectFlight where
  depDate : Date
  flightName : String
  boardingClassCd : BoardingClassCd
  fareTypeCd : FareTypeCd
  deriving DecidableEq

/-- 予約する便: 片道（1 便）か往復（往路・復路）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#選択フライト"]
inductive Itinerary (α : Type) where
  | oneWay (f : α)
  | roundTrip (out home : α)
  deriving DecidableEq, Repr

/-- 便の列（往路、復路の順）。 -/
def Itinerary.toList {α : Type} : Itinerary α → List α
  | .oneWay f => [f]
  | .roundTrip o h => [o, h]

/-- 便ごとに写す。 -/
def Itinerary.map {α β : Type} (g : α → β) : Itinerary α → Itinerary β
  | .oneWay f => .oneWay (g f)
  | .roundTrip o h => .roundTrip (g o) (g h)

@[simp] theorem Itinerary.toList_map {α β : Type} (g : α → β) (it : Itinerary α) :
    (it.map g).toList = it.toList.map g := by
  cases it <;> rfl

/-- マスタで解決した選択フライト: 主キーと便マスタ。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#選択フライト"]
structure ResolvedFlight where
  key : FlightKey
  master : FlightMaster

/-- `resolve(sel)`: 便マスタを便名（文字列）で引き、主キーの便名は便マスタの便名とする（搭乗クラス・運賃種別は
主キーのコードで引く）。便マスタが無ければ無し（次の検証で `InvalidRequest` にする）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#選択フライト"]
def resolve (md : MasterData) (s : SelectFlight) : Option ResolvedFlight :=
  (md.flightMasterOf s.flightName).map fun m => ⟨⟨s.depDate, m.flightName, s.boardingClassCd, s.fareTypeCd⟩, m⟩

/-- 便の区間（便マスタの区間番号で引く）。 -/
def routeOfMaster (md : MasterData) (m : FlightMaster) : Option Route := md.routes.find? (·.routeNo == m.routeNo)

/-!
## validateFlightList

選択フライトの整合性検証。改竄（通常の画面操作では起きない値）は `InvalidRequest`、利用者の選択ミスは `Business` とする。

### シグネチャ

`validateFlightList(cfg: Config, md: MasterData, w: World, flights: [Option ResolvedFlight]) : Option (Except AtrsError (Itinerary FlightKey))`

`flights` は選択フライトを `resolve` したもの（往路、復路の順）。フライトの有無は抽象状態 `w` のフライト（`FlightRepository.exists`）で見る。
成功したときは、検証した便の主キーを、片道（1 便）か往復（往路・復路）の `Itinerary` で返す。予約確認・予約確定は、この主キーを使う。

### 事前条件

- `1 ≤ len(flights) ≤ 2`（[Source]: `Assert`）。外れれば `none`。
- 往復のとき、往路・復路の区間がマスタにある（MD-2）。無ければ `none`。

### 定義（評価順）

1. 往路 `o = flights[0]`: 便マスタが無ければ `InvalidRequest("flightMaster is null")`。`o` の主キーに一致するフライトが `w` に無ければ `InvalidRequest("flight not found")`。
2. `len(flights) = 2` のとき、復路 `h = flights[1]` に同じ検査を行い、さらに:
   1. 搭乗間隔: `at(o.departureDate, o.arrivalTime) + reserveIntervalTime 分 > at(h.departureDate, h.departureTime)` なら `Business("e.ar.b2.2001")`。ちょうど間隔分なら可。到着時刻は出発日 0:00 からの時分で、24:00 より後（翌日着）でもよい（[Source] は `HHmm` で読むので、翌日着の便で例外になる。既知差異 [D-031](../../../docs/spec/abstraction.md#既知差異)）。
   2. 逆区間: `o` の区間の出発空港 ≠ `h` の区間の到着空港、または `o` の到着空港 ≠ `h` の出発空港なら `InvalidRequest("homeward route is not outward route reverse")`。
3. 運賃種別:
   - `len = 1`: `o.fareTypeCd ∉ oneWayFareTypes` なら `InvalidRequest`。
   - `len = 2`: `o.fareTypeCd ∉ roundTripFareTypes` または `h.fareTypeCd ∉ roundTripFareTypes` なら `InvalidRequest`。

搭乗日が照会可能期間内か・運賃種別が予約可能期間内かは **ここでは検査しない**（後者は予約登録時に検査する）。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateFlightList(List)`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#existsFlight(Flight)`

### 例

`reserveIntervalTime = 120`。往路 HND→ITM 2026-04-11 09:00–10:00、復路 ITM→HND 2026-04-11 12:00 発 → 可（10:00 + 120 分 = 12:00）。復路 11:59 発 → `e.ar.b2.2001`。復路が 2026-04-10 → `e.ar.b2.2001`。
-/

/-- 1 便の検査: 便マスタがあり、主キーのフライトがある。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist"]
def checkFlight (w : World) : Option ResolvedFlight → Except AtrsError ResolvedFlight
  | none => .error (.invalidRequest "flightMaster is null")
  | some f => if w.existsFlight f.key then .ok f else .error (.invalidRequest "flight not found")

/-- 往路便の到着日時から `reserveIntervalTime` 分後（エポックからの分数）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist", gap "D-031"]
def availableMinute (cfg : Config) (o : FlightKey) (om : FlightMaster) : Int :=
  o.departureDate.epochDay * 1440 + om.arrivalTime.toMinutes + cfg.reserveIntervalTime

/-- 復路便の出発日時（エポックからの分数）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist"]
def departureMinute (h : FlightKey) (hm : FlightMaster) : Int :=
  h.departureDate.epochDay * 1440 + hm.departureTime.toMinutes

/-- 搭乗間隔の検査: 復路便の出発が、往路便の到着から `reserveIntervalTime` 分より前なら `Business("e.ar.b2.2001")`。
ちょうど間隔分なら可。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist", gap "D-031"]
def checkInterval (cfg : Config) (o : FlightKey) (om : FlightMaster) (h : FlightKey) (hm : FlightMaster) :
    Except AtrsError Unit :=
  if departureMinute h hm < availableMinute cfg o om then .error (.business .intervalTooShort) else .ok ()

/-- 逆区間の検査: 往路の出発空港 ≠ 復路の到着空港、または往路の到着空港 ≠ 復路の出発空港なら `InvalidRequest`。
区間がマスタに無ければ無し（PRE: MD-2）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist"]
def checkReverse (md : MasterData) (om hm : FlightMaster) : Option (Except AtrsError Unit) := do
  let orr ← routeOfMaster md om
  let hr ← routeOfMaster md hm
  return if orr.depAirportCd == hr.arrAirportCd && orr.arrAirportCd == hr.depAirportCd then .ok ()
    else .error (.invalidRequest "homeward route is not outward route reverse")

/-- 運賃種別の検査: 片道は往路が片道運賃、往復は往路・復路とも往復運賃。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist"]
def checkFareTypes (keys : List FlightKey) : Except AtrsError Unit :=
  match keys with
  | [o] => if oneWayFareTypes.contains o.fareTypeCd then .ok ()
      else .error (.invalidRequest "outward flight fareType is invalid")
  | [o, h] =>
    if !roundTripFareTypes.contains o.fareTypeCd then .error (.invalidRequest "outward flight fareType is invalid")
    else if !roundTripFareTypes.contains h.fareTypeCd then .error (.invalidRequest "homeward flight fareType is invalid")
    else .ok ()
  | _ => .error (.invalidRequest "flightList size must be between 1 and 2")

/-- `validateFlightList`（評価順）。往路の検査、往復なら復路の検査・搭乗間隔・逆区間、最後に運賃種別。
搭乗日が照会可能期間内か・運賃種別が予約可能期間内かは検査しない。成功すれば予約する便の主キーを返す。
選択フライトが 1〜2 件でなければ無し（PRE）、区間がマスタに無ければ無し（PRE: MD-2）。 -/
@[spec_doc "lean/Spec/Reserve/FlightSelection.lean#validateflightlist"]
def validateFlightList (cfg : Config) (md : MasterData) (w : World) (flights : List (Option ResolvedFlight)) :
    Option (Except AtrsError (Itinerary FlightKey)) :=
  match flights with
  | [o] => some do
    let o ← checkFlight w o
    let _ ← checkFareTypes [o.key]
    return .oneWay o.key
  | [o, h] =>
    match checkFlight w o with
    | .error e => some (.error e)
    | .ok o =>
      match checkFlight w h with
      | .error e => some (.error e)
      | .ok h =>
        match checkInterval cfg o.key o.master h.key h.master with
        | .error e => some (.error e)
        | .ok () => do
          let r ← checkReverse md o.master h.master
          return r.bind fun _ => (checkFareTypes [o.key, h.key]).map fun _ => .roundTrip o.key h.key
  | _ => none

end Spec.Reserve.FlightSelection

/-!
## 根拠と対応

- 根拠: [ADR 6d36](../../../docs/decision/6d36-misu-spec-types.md)（選択フライトの便名を生の文字列で受け、便マスタで解決する）、[ADR ce36](../../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)（到着時刻を出発日 0:00 からの分数で表す）。
- 既知差異: D-031（翌日着の往路便で [Source] が例外を投げる）、D-039（空白だけの便名）（[一覧](../../../docs/spec/abstraction.md#既知差異)）。
- 移植元モデル: [`SourceModel.Domain.Service.B0.TicketSharedServiceImpl`](../../SourceModel/Domain/Service/B0/TicketSharedServiceImpl.lean)、[`SourceModel.App.B0.TicketHelper`](../../SourceModel/App/B0/TicketHelper.lean)。
- 抽象化の証明: [`Abstraction.Reserve`](../../Abstraction/Reserve.lean)（予約の R 課題 ABS-041 の一部）。
- 適合テストベクタ: [`conformance/shared/reservation/`](../../../conformance/shared/reservation/)。
-/
