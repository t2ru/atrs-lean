import Lean.Data.Json
import Spec
import SourceModel
import Tests.Conformance
import Tests.ConformanceFare
import Tests.ConformanceMaster
import Tests.ConformanceFlightSearch

/-!
# Tests.ConformanceReservation

`reservation.*` の操作の割当（`docs/spec/conformance.md`。backlog aedf）。`Spec` 用と `SourceModel` 用の 2 つの表を、
ベクタの共有入力（`fixtures/master-data.json`・`config.json`）から作る。

入力の JSON:

- `flights`: フライト（[Spec] では `World.flights`、[Source] では FLIGHT 表の行）
- `members`: 会員（`membershipNumber`・`kanaFamilyName`・`kanaGivenName`・`gender`。ほかの項目は既定の値）。
  [Source] では MEMBER・MEMBER_LOGIN の行（カード種別は `VIS`）
- `sequences`: 採番の次の値（`reserve`・`reserveFlight`・`passenger`。省略は 1）
- `today`: 今日（[Source] では Clock がいつもこの値を返す）
- `selectFlights`: 選択フライト（`depDate`・`flightName`・`boardingClassCd`・`fareTypeCd`）
- `form`: 予約入力（入力検証の後の値。搭乗者欄 `passengers` の項目は省略・`null` で未入力）

結果の JSON: エラーは `{"error": {"kind": …}}` で、`business` は `code`・`args`、`system` は `code` を持つ。
`invalidRequest` の詳細は比較しない（N-004）。[Source] の `BadRequestException`・`InvalidFlightException` は
`invalidRequest`、`AtrsBusinessException` は `business` に対応させる。`reservation.reserve` は、結果と実行後の状態
（フライト・予約・採番の次の値）を返す。
-/

open Lean Spec ConformanceKit Tests.Conformance

open ConformanceKit.Runner LangSemantics.Java.Exception LangSemantics.Java.Int

open Spec.Config Spec.Model Spec.Prim.Format

namespace Tests.ConformanceReservation
open Tests.ConformanceFare (boardingClassCd fareTypeCd decodeMaster decodeConfig decodeMembershipNumber)
open Tests.ConformanceFlightSearch (specFlight flightRow jdate getObjVal)

/-! ## 共通 -/

def gender (s : String) : Except String Gender := need (Gender.ofCode? s) s!"gender: {s}"

/-- 省略・`null` は無し。 -/
def optStr (j : Json) (k : String) : Except String (Option String) :=
  match j.getObjVal? k with
  | .ok .null | .error _ => .ok none
  | .ok v => some <$> v.getStr?

def optNat (j : Json) (k : String) : Except String (Option Nat) :=
  match j.getObjVal? k with
  | .ok .null | .error _ => .ok none
  | .ok v => some <$> v.getNat?

def optArr (j : Json) (k : String) : Except String (List Json) :=
  match j.getObjVal? k with
  | .ok .null | .error _ => .ok []
  | .ok _ => getArr j k

def seqOf (i : Json) (k : String) : Except String Nat := do
  match i.getObjVal? "sequences" with
  | .ok s => match s.getObjVal? k with
    | .ok v => v.getNat?
    | .error _ => pure 1
  | .error _ => pure 1

def errorJson (kind : String) (fields : List (String × Json)) : Json :=
  Json.mkObj [("error", Json.mkObj (("kind", .str kind) :: fields))]

def businessJson (code : String) (args : List String) : Json :=
  errorJson "business" [("code", .str code), ("args", .arr (args.map Json.str).toArray)]

def strOrNull (o : Option String) : Json := optJson Json.str o

/-! ## Spec -/

def specMember (m : Json) : Except String Member := do
  return { membershipNumber := ← decodeMembershipNumber (← getStr m "membershipNumber"), kanjiFamilyName := "", kanjiGivenName := "",
           kanaFamilyName := ← getStr m "kanaFamilyName", kanaGivenName := ← getStr m "kanaGivenName",
           birthday := Spec.Prim.Date.ymd! 1970 1 1, gender := ← gender (← getStr m "gender"), tel := "", zipCode := "", address := "",
           mail := "", creditNo := "", creditTypeCd := { val := "VIS" }, creditTerm := "",
           login := { password := ⟨""⟩, lastPassword := none, loginDateTime := none, loginFlg := false } }

/-- 入力の `World`。フライトが主キーで一意でなければ、`World` を作れない（INV の外。ADR 6d36 の L3）。 -/
def specWorld (i : Json) : Except String Spec.Port.World := do
  let flights ← (← optArr i "flights").mapM specFlight
  if h : (flights.map (·.key)).Nodup then
    return { flights, flights_nodup := h, members := ← (← optArr i "members").mapM specMember,
             sequences := { reserve := ← seqOf i "reserve", reserveFlight := ← seqOf i "reserveFlight",
                            passenger := ← seqOf i "passenger" } }
  else throw "outside INV (duplicate flight key)"

def specSelect (s : Json) : Except String Spec.Ticket.SelectFlight := do
  return { depDate := ← decodeDate (← getStr s "depDate"), flightName := ← getStr s "flightName",
           boardingClassCd := ← boardingClassCd (← getStr s "boardingClassCd"), fareTypeCd := ← fareTypeCd (← getStr s "fareTypeCd") }

def specPassengerInput (p : Json) : Except String Spec.UseCase.Reserve.PassengerInput := do
  return { familyName := ← optStr p "familyName", givenName := ← optStr p "givenName", age := ← optNat p "age",
           gender := ← (← optStr p "gender").mapM gender, membershipNumber := ← optStr p "membershipNumber" }

def specForm (f : Json) : Except String Spec.UseCase.Reserve.ReserveInput := do
  return { repFamilyName := ← getStr f "repFamilyName", repGivenName := ← getStr f "repGivenName", repAge := ← getNat f "repAge",
           repGender := ← gender (← getStr f "repGender"), repTel1 := ← getStr f "repTel1", repTel2 := ← getStr f "repTel2",
           repTel3 := ← getStr f "repTel3", repMail := ← getStr f "repMail", repMembershipNumber := ← optStr f "repMembershipNumber",
           passengers := ← (← getArr f "passengers").mapM specPassengerInput }

def specRequest (i : Json) : Except String Spec.UseCase.Reserve.Request := do
  return { selects := ← (← getArr i "selectFlights").mapM specSelect, form := ← specForm (← getObjVal i "form") }

def specErrorJson : Spec.Error.AtrsError → Json
  | .business e => businessJson e.code e.args
  | .notFound e => errorJson "notFound" [("code", .str e.code)]
  | .invalidRequest _ => errorJson "invalidRequest" []
  | .system e => errorJson "system" [("code", .str e.code)]
  | .conflict _ => errorJson "conflict" []

def flightJson (k : FlightKey) (vacantNum : Nat) : Json :=
  Json.mkObj [("departureDate", .str (fmtIsoDate k.departureDate)), ("flightName", .str k.flightName.val),
    ("boardingClassCd", .str k.boardingClassCd.toCode), ("fareTypeCd", .str k.fareTypeCd.toCode), ("vacantNum", toJson vacantNum)]

def specReservationJson (r : Reservation) : Json :=
  Json.mkObj [("reserveNo", .str r.reserveNo.val), ("reserveDate", .str (fmtIsoDate r.reserveDate)),
    ("totalFare", toJson r.totalFare), ("repFamilyName", .str r.repFamilyName), ("repGivenName", .str r.repGivenName),
    ("repAge", toJson r.repAge), ("repGender", .str r.repGender.toCode), ("repTel", .str r.repTel), ("repMail", .str r.repMail),
    ("repMembershipNumber", strOrNull (r.repMembershipNumber.map (·.val))),
    ("reserveFlights", .arr (r.reserveFlights.legs.map fun (rf, ps) => Json.mkObj [
      ("reserveFlightNo", toJson rf.reserveFlightNo), ("departureDate", .str (fmtIsoDate rf.flight.departureDate)),
      ("flightName", .str rf.flight.flightName.val), ("boardingClassCd", .str rf.flight.boardingClassCd.toCode),
      ("fareTypeCd", .str rf.flight.fareTypeCd.toCode),
      ("passengers", .arr (ps.map fun (no, p) => Json.mkObj [
        ("passengerNo", toJson no), ("familyName", .str p.familyName),
        ("givenName", .str p.givenName), ("age", toJson p.age),
        ("gender", .str p.gender.toCode),
        ("membershipNumber", strOrNull (p.membershipNumber.map (·.val)))]).toArray)]).toArray)]

def specWorldJson (w : Spec.Port.World) : Json :=
  Json.mkObj [("flights", .arr (w.flights.map fun f => flightJson f.key f.vacantNum).toArray),
    ("reservations", .arr (w.reservations.map specReservationJson).toArray),
    ("sequences", Json.mkObj [("reserve", toJson w.sequences.reserve), ("reserveFlight", toJson w.sequences.reserveFlight),
      ("passenger", toJson w.sequences.passenger)])]

/-- `Spec` の `reservation.*`。 -/
def specOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let md ← decodeMaster fx.master
  let cfg ← decodeConfig fx.config
  let checkWorld (w : Spec.Port.World) : Except String Unit := do
    if !decide (w.RefMaster md) then throw "outside PRE (flight refers to a missing master row)"
  return [
    ("reservation.validateFlightList", fun i => do
      let w ← specWorld i
      checkWorld w
      let sels ← (← getArr i "selectFlights").mapM specSelect
      match ← need (Spec.Ticket.validateFlightList cfg md w (sels.map (Spec.Ticket.resolve md))) "outside PRE" with
      | .ok _ => return .null
      | .error e => return specErrorJson e),
    ("reservation.validateReservation", fun i => do
      let w ← specWorld i
      let r ← specRequest i
      -- 予約内容の検証は選択フライトの検証の後なので、選択フライトの主キーは便名を便名の型で読んだもの
      let ks ← r.selects.mapM fun s => do
        return ({ departureDate := s.depDate, flightName := ← Tests.ConformanceFare.decodeFlightName s.flightName,
                  boardingClassCd := s.boardingClassCd, fareTypeCd := s.fareTypeCd } : FlightKey)
      let it ← match ks with
        | [k] => pure (Spec.Ticket.Itinerary.oneWay k)
        | [o, h] => pure (Spec.Ticket.Itinerary.roundTrip o h)
        | _ => throw "outside PRE (selectFlights must have 1 or 2 flights)"
      let d ← need (Spec.UseCase.Reserve.buildDraft r.form it) "outside PRE (passenger)"
      match ← need (Spec.UseCase.Reserve.validateReservation cfg md w d) "outside PRE" with
      | .ok () => return .null
      | .error e => return specErrorJson e),
    ("reservation.confirm", fun i => do
      let w ← specWorld i
      checkWorld w
      match ← need (Spec.UseCase.Reserve.confirmOp cfg md w (← specRequest i)) "outside PRE" with
      | .ok n => return Json.mkObj [("totalFare", toJson n)]
      | .error e => return specErrorJson e),
    ("reservation.reserve", fun i => do
      let w ← specWorld i
      checkWorld w
      let today ← decodeDate (← getStr i "today")
      let (w', r) ← need (Spec.UseCase.Reserve.reserveOp cfg md today w (← specRequest i)) "outside PRE"
      let result := match r with
        | .ok v => Json.mkObj [("reserveNo", .str v.reserveNo.val), ("paymentDate", .str (fmtIsoDate v.paymentDate)),
            ("totalFare", toJson v.totalFare)]
        | .error e => specErrorJson e
      return Json.mkObj [("result", result), ("world", specWorldJson w')])
  ]

/-! ## SourceModel -/

open LangSemantics.Java LangSemantics.Sql.Postgresql SourceModel.Db.Schema SourceModel.Db.Tx
open SourceModel.App.B0 SourceModel.App.B2

def liftSql {α : Type} (r : LangSemantics.Sql.Core.SqlResult α) (what : String) : Except String α :=
  r.mapError fun e => s!"{what}: {repr e}"

def text (n : Nat) (s : String) (what : String) : Except String (Varchar n) := liftSql (Varchar.ofString what n s) what

def memberRows (m : Json) : Except String (MemberRow × MemberLoginRow) := do
  let no ← text 10 (← getStr m "membershipNumber") "customer_no"
  let e0 ← text 10 "" "x"
  return ({ customerNo := no, kanjiFamilyName := e0, kanjiGivenName := e0,
            kanaFamilyName := ← text 10 (← getStr m "kanaFamilyName") "kana_family_name",
            kanaGivenName := ← text 10 (← getStr m "kanaGivenName") "kana_given_name",
            birthday := ⟨0, by decide⟩, gender := ← text 1 (← getStr m "gender") "gender",
            tel := ← text 13 "" "tel", zipCode := ← text 7 "" "zip_code", address := ← text 60 "" "address",
            mail := ← text 256 "" "mail", creditNo := ← text 16 "" "credit_no", creditTypeCd := ← text 3 "VIS" "credit_type_cd",
            creditTerm := ← text 5 "" "credit_term" },
          { customerNo := no, password := ← text 124 "" "password", lastPassword := none, loginDateTime := none, loginFlg := false })

def seqState (n : Nat) : LangSemantics.Sql.Sequence.SequenceState := if n ≤ 1 then none else some ((n : Int) - 1)

def nextOf (st : LangSemantics.Sql.Sequence.SequenceState) : Int := match st with | none => 1 | some v => v + 1

def srcDb (i : Json) : Except String FlightDb := do
  let ms ← (← optArr i "members").mapM memberRows
  return { flight := ← (← optArr i "flights").mapM flightRow, member := ms.map (·.1), memberLogin := ms.map (·.2),
           sqReservation := seqState (← seqOf i "reserve"), sqReserveFlight := seqState (← seqOf i "reserveFlight"),
           sqPassenger := seqState (← seqOf i "passenger") }

def srcSelect (s : Json) : Except String SelectFlightForm := do
  return { depDate := some (← jdate (← getStr s "depDate")), flightName := some (← getStr s "flightName"),
           boardingClassCd := some (← boardingClassCd (← getStr s "boardingClassCd")),
           fareTypeCd := some (← fareTypeCd (← getStr s "fareTypeCd")) }

def srcPassengerForm (p : Json) : Except String PassengerForm := do
  return { familyName := ← optStr p "familyName", givenName := ← optStr p "givenName",
           age := (← optNat p "age").map J32.ofInt, gender := ← (← optStr p "gender").mapM gender,
           membershipNumber := ← optStr p "membershipNumber" }

def srcForm (i : Json) : Except String TicketReserveForm := do
  let f ← getObjVal i "form"
  return { repFamilyName := some (← getStr f "repFamilyName"), repGivenName := some (← getStr f "repGivenName"),
           repAge := some (J32.ofInt (← getNat f "repAge")), repGender := some (← gender (← getStr f "repGender")),
           repMembershipNumber := ← optStr f "repMembershipNumber", repTel1 := some (← getStr f "repTel1"),
           repTel2 := some (← getStr f "repTel2"), repTel3 := some (← getStr f "repTel3"), repMail := some (← getStr f "repMail"),
           passengerFormList := ← (← getArr f "passengers").mapM srcPassengerForm,
           selectFlightFormList := ← (← getArr i "selectFlights").mapM srcSelect }

/-- 業務例外・不正要求を JSON に。ほかの例外はテストの失敗。 -/
def srcErrorJson (e : JThrow) : Except String Json :=
  match e with
  | .other ⟨"jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException", _⟩ msg =>
    match msg.splitOn "\n" with
    | code :: args => .ok (businessJson code args)
    | [] => .ok (businessJson msg [])
  | .other ⟨"jp.co.ntt.atrs.app.common.exception.BadRequestException", _⟩ _ => .ok (errorJson "invalidRequest" [])
  | .other ⟨"jp.co.ntt.atrs.domain.service.b0.InvalidFlightException", _⟩ _ => .ok (errorJson "invalidRequest" [])
  | e => .error s!"java exception: {repr e}"

def srcWorldJson (fd : FlightDb) : Json :=
  let flights := fd.flight.map fun f => Json.mkObj [("departureDate", .str (fmtIsoDate (Spec.Prim.Date.ofEpochDay? f.departureDate.val |>.getD (Spec.Prim.Date.ymd! 1970 1 1)))),
      ("flightName", .str f.flightName.val), ("boardingClassCd", .str f.boardingClassCd.val), ("fareTypeCd", .str f.fareTypeCd.val),
      ("vacantNum", toJson f.vacantNum.val)]
  let dateStr (d : PgDate) : String := fmtIsoDate (Spec.Prim.Date.ofEpochDay? d.val |>.getD (Spec.Prim.Date.ymd! 1970 1 1))
  let reservations := fd.reservation.map fun r => Json.mkObj [
    ("reserveNo", .str r.reserveNo.val), ("reserveDate", .str (dateStr r.reserveDate)), ("totalFare", toJson r.totalFare.val),
    ("repFamilyName", .str r.repFamilyName.val), ("repGivenName", .str r.repGivenName.val), ("repAge", toJson r.repAge.val),
    ("repGender", .str r.repGender.val), ("repTel", .str r.repTel.val), ("repMail", .str r.repMail.val),
    ("repMembershipNumber", strOrNull (r.repCustomerNo.map (·.val))),
    ("reserveFlights", .arr ((fd.reserveFlight.filter (·.reserveNo.val == r.reserveNo.val)).map fun rf => Json.mkObj [
      ("reserveFlightNo", toJson rf.reserveFlightNo.val), ("departureDate", .str (dateStr rf.departureDate)),
      ("flightName", .str rf.flightName.val), ("boardingClassCd", .str rf.boardingClassCd.val), ("fareTypeCd", .str rf.fareTypeCd.val),
      ("passengers", .arr ((fd.passenger.filter (·.reserveFlightNo.val == rf.reserveFlightNo.val)).map fun p => Json.mkObj [
        ("passengerNo", toJson p.passengerNo.val), ("familyName", .str p.familyName.val), ("givenName", .str p.givenName.val),
        ("age", toJson p.age.val), ("gender", .str p.gender.val),
        ("membershipNumber", strOrNull (p.customerNo.map (·.val)))]).toArray)]).toArray)]
  Json.mkObj [("flights", .arr flights.toArray), ("reservations", .arr reservations.toArray),
    ("sequences", Json.mkObj [("reserve", toJson (nextOf fd.sqReservation)), ("reserveFlight", toJson (nextOf fd.sqReserveFlight)),
      ("passenger", toJson (nextOf fd.sqPassenger))])]

/-- `SourceModel` の `reservation.*`（標準の並び。障害の無い実行環境で、Clock はいつも `today`）。 -/
def sourceOps (fx : Fixtures) : Except String (List (String × Op)) := do
  let db ← Tests.ConformanceMaster.decodeDb fx.master
  let cfg ← Tests.ConformanceMaster.srcConfig fx.config
  let mo := SourceModel.MasterQuery.standardOrder db
  let p ← match SourceModel.MasterQuery.load mo with
    | .ok p => pure p
    | .error e => throw s!"load: {repr e}"
  let input (i : Json) : Except String SourceModel.ReserveQuery.ReserveInput := do
    let today ← match i.getObjVal? "today" with
      | .ok _ => jdate (← getStr i "today")
      | .error _ => pure (JLocalDate.ofEpochDay 0)
    return { db, config := cfg, form := ← srcForm i, env := Env.fixed today }
  return [
    ("reservation.validateFlightList", fun i => do
      let sels ← (← getArr i "selectFlights").mapM srcSelect
      let flights ← match TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p) sels with
        | .ok fs => pure fs
        | .error e => throw s!"java exception: {repr e}"
      match (runOn (SourceModel.Domain.Service.B0.TicketSharedServiceImpl.validateFlightList cfg.reserveIntervalTime
          (some flights)) (← srcDb i) (Env.fixed (JLocalDate.ofEpochDay 0))).1 with
      | .ok () => return .null
      | .error e => srcErrorJson e),
    ("reservation.validateReservation", fun i => do
      let ic ← input i
      let flights ← match TicketHelper.toFlightList (SourceModel.FareQuery.ticketHelper p) ic.form.selectFlightFormList with
        | .ok fs => pure fs
        | .error e => throw s!"java exception: {repr e}"
      let h := SourceModel.ReserveQuery.helperOf p ic
      let r := TicketReserveHelper.createReservation ic.form flights
      match (runOn (SourceModel.Domain.Service.B2.TicketReserveServiceImpl.validateReservation h.ticketReserveService (some r))
          (← srcDb i) ic.env).1 with
      | .ok () => return .null
      | .error e => srcErrorJson e),
    ("reservation.confirm", fun i => do
      match (SourceModel.ReserveQuery.runConfirm (← srcDb i) (← input i) mo).1 with
      | .ok o => return Json.mkObj [("totalFare", toJson o.totalFare.val)]
      | .error e => srcErrorJson e),
    ("reservation.reserve", fun i => do
      let (r, fd) := SourceModel.ReserveQuery.runReserve (← srcDb i) (← input i) mo
      let result ← match r with
        | .ok o => pure (Json.mkObj [("reserveNo", strOrNull o.reserveNo),
            ("paymentDate", optJson (fun (d : JLocalDate) => .str (d.formatYMD "-")) o.paymentDate),
            ("totalFare", optJson (fun (n : J32) => toJson n.val) o.totalFare)])
        | .error e => srcErrorJson e
      return Json.mkObj [("result", result), ("world", srcWorldJson fd)])
  ]

end Tests.ConformanceReservation
