import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.Fare
import Spec.Error
import Spec.Port

/-!
# Spec.Ticket

選択フライトとその検証（`docs/spec/reservation.md#選択フライト`・`#validateflightlist`。backlog aedf）。

- 選択フライト `SelectFlight` をマスタで解決したものを `ResolvedFlight` とする。便マスタが無ければ `master = none`
  で、次の検証で `InvalidRequest` にする。
- `validateFlightList` は、改竄（通常の画面操作では起きない値）を `InvalidRequest`、利用者の選択ミスを
  `Business` とする。`InvalidRequest` の詳細の文字列は、変えうる部分（自由な選択 N-004）である。
- 往路便の到着日時は、出発日 0:00 からの分数（翌日着を含む。ADR ce36）で数える。[Source] は到着時刻が 24:00 より
  後の便を往路とする往復の予約で例外を投げる（既知差異 D-031）。
-/

namespace Spec.Ticket
open Spec.Config Spec.Model Spec.Prim Spec.Prim.Time Spec.Error Spec.MasterData Spec.Port

/-- 画面から送られる選択フライト（往路、復路の順）。 -/
@[spec_doc "docs/spec/reservation.md#選択フライト"]
structure SelectFlight where
  depDate : Date
  flightName : FlightName
  boardingClassCd : BoardingClassCd
  fareTypeCd : FareTypeCd
  deriving DecidableEq

/-- 選択フライトの主キー。 -/
def SelectFlight.key (s : SelectFlight) : FlightKey := ⟨s.depDate, s.flightName, s.boardingClassCd, s.fareTypeCd⟩

/-- マスタで解決した選択フライト。便マスタが無い場合は `master = none`。 -/
@[spec_doc "docs/spec/reservation.md#選択フライト"]
structure ResolvedFlight where
  key : FlightKey
  master : Option FlightMaster

/-- `resolve(sel)`: 便マスタを引く（搭乗クラス・運賃種別は主キーのコードで引く）。 -/
@[spec_doc "docs/spec/reservation.md#選択フライト"]
def resolve (md : MasterData) (s : SelectFlight) : ResolvedFlight := ⟨s.key, md.flightMasterOf s.flightName⟩

/-- 便の区間（便マスタの区間番号で引く）。 -/
def routeOfMaster (md : MasterData) (m : FlightMaster) : Option Route := md.routes.find? (·.routeNo == m.routeNo)

/-- 1 便の検査: 便マスタがあり、主キーのフライトがある。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist"]
def checkFlight (w : World) (f : ResolvedFlight) : Except AtrsError FlightMaster :=
  match f.master with
  | none => .error (.invalidRequest "flightMaster is null")
  | some m => if w.existsFlight f.key then .ok m else .error (.invalidRequest "flight not found")

/-- 往路便の到着日時から `reserveIntervalTime` 分後（エポックからの分数）。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist", gap "D-031"]
def availableMinute (cfg : Config) (o : FlightKey) (om : FlightMaster) : Int :=
  o.departureDate.epochDay * 1440 + om.arrivalTime.toMinutes + cfg.reserveIntervalTime

/-- 復路便の出発日時（エポックからの分数）。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist"]
def departureMinute (h : FlightKey) (hm : FlightMaster) : Int :=
  h.departureDate.epochDay * 1440 + hm.departureTime.toMinutes

/-- 搭乗間隔の検査: 復路便の出発が、往路便の到着から `reserveIntervalTime` 分より前なら `Business("e.ar.b2.2001")`。
ちょうど間隔分なら可。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist", gap "D-031"]
def checkInterval (cfg : Config) (o : FlightKey) (om : FlightMaster) (h : FlightKey) (hm : FlightMaster) :
    Except AtrsError Unit :=
  if departureMinute h hm < availableMinute cfg o om then .error (.business .intervalTooShort) else .ok ()

/-- 逆区間の検査: 往路の出発空港 ≠ 復路の到着空港、または往路の到着空港 ≠ 復路の出発空港なら `InvalidRequest`。
区間がマスタに無ければ無し（PRE: MD-2）。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist"]
def checkReverse (md : MasterData) (om hm : FlightMaster) : Option (Except AtrsError Unit) := do
  let orr ← routeOfMaster md om
  let hr ← routeOfMaster md hm
  return if orr.depAirportCd == hr.arrAirportCd && orr.arrAirportCd == hr.depAirportCd then .ok ()
    else .error (.invalidRequest "homeward route is not outward route reverse")

/-- 運賃種別の検査: 片道は往路が片道運賃、往復は往路・復路とも往復運賃。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist"]
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
搭乗日が照会可能期間内か・運賃種別が予約可能期間内かは検査しない。選択フライトが 1〜2 件でなければ無し（PRE）、
区間がマスタに無ければ無し（PRE: MD-2）。 -/
@[spec_doc "docs/spec/reservation.md#validateflightlist"]
def validateFlightList (cfg : Config) (md : MasterData) (w : World) (flights : List ResolvedFlight) :
    Option (Except AtrsError Unit) :=
  match flights with
  | [o] => some do
    let _ ← checkFlight w o
    checkFareTypes [o.key]
  | [o, h] =>
    match checkFlight w o with
    | .error e => some (.error e)
    | .ok om =>
      match checkFlight w h with
      | .error e => some (.error e)
      | .ok hm =>
        match checkInterval cfg o.key om h.key hm with
        | .error e => some (.error e)
        | .ok () => do
          let r ← checkReverse md om hm
          return r.bind fun _ => checkFareTypes [o.key, h.key]
  | _ => none

end Spec.Ticket
