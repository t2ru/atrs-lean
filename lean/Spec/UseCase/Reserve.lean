import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.Fare
import Spec.Error
import Spec.Port
import Spec.FlightSearch
import Spec.Ticket

/-!
# Spec.UseCase.Reserve

予約（B2。`docs/spec/reservation.md`。backlog aedf）。予約入力とフライト列から予約内容を組み立て、
`validateReservation` で検証し、予約確認（合計金額）と予約確定（空席の確保と予約の登録）を行う。

- 予約入力は、入力検証（`docs/spec/input-validation.md#予約入力b2`。backlog 4e0e）を通った後の値である。
  空でない搭乗者欄は姓・名・年齢・性別をすべて持つ（PRE）。
- 予約確定は `World` に対する関数で、1 つのトランザクションとして原子的に実行する。失敗したとき状態は変わらない
  （採番の前進を除く。標準の選択では、失敗する前に採番しない）。`Conflict`・I/O 失敗の結果は、抽象機械の選択
  （N-001・N-002）で与える（第 2 段）。
- 今日の日付は入力の成分で、1 回だけ読んだ値である（[Source] は複数回読む。既知差異 D-014）。
-/

namespace Spec.UseCase.Reserve
open Spec.Config Spec.Model Spec.Prim Spec.Prim.Text Spec.Error Spec.MasterData Spec.Port Spec.Ticket

/-! ## 予約入力 -/

/-- 搭乗者欄（入力検証の後。空白のみの文字列は前処理で未入力になっている）。 -/
@[spec_doc "docs/spec/input-validation.md#予約入力b2"]
structure PassengerInput where
  familyName : Option String := none
  givenName : Option String := none
  age : Option Nat := none
  gender : Option Gender := none
  membershipNumber : Option String := none
  deriving DecidableEq

/-- 搭乗者欄が空: 姓・名・会員番号がいずれも空白のみか未入力で、年齢と性別が未入力。 -/
@[spec_doc "docs/spec/reservation.md#予約内容の組み立て"]
def PassengerInput.isEmpty (p : PassengerInput) : Bool :=
  !(p.familyName.any hasText) && !(p.givenName.any hasText) && p.age.isNone && p.gender.isNone &&
    !(p.membershipNumber.any hasText)

/-- 予約入力（`TicketReserveInput`）。搭乗者欄は 6 欄。 -/
@[spec_doc "docs/spec/input-validation.md#予約入力b2"]
structure ReserveInput where
  repFamilyName : String
  repGivenName : String
  repAge : Nat
  repGender : Gender
  repTel1 : String
  repTel2 : String
  repTel3 : String
  repMail : String
  repMembershipNumber : Option String := none
  passengers : List PassengerInput
  deriving DecidableEq

/-- 会員番号の入力: 空でない文字列なら会員番号とする（空文字は未入力と同じ）。 -/
@[spec_doc "docs/spec/reservation.md#予約内容の組み立て"]
def memberNoOf (s : Option String) : Option MembershipNumber :=
  s.bind fun v => if v.isEmpty then none else some ⟨v⟩

/-- 空でない搭乗者欄を搭乗者にする。姓・名・年齢・性別のどれかが無ければ無し（PRE）。 -/
@[spec_doc "docs/spec/reservation.md#予約内容の組み立て"]
def PassengerInput.toPassenger (p : PassengerInput) : Option Passenger := do
  return { familyName := ← p.familyName, givenName := ← p.givenName, age := ← p.age, gender := ← p.gender,
           membershipNumber := memberNoOf p.membershipNumber }

/-- 搭乗者欄を詰める（空でない欄を前に詰め、6 欄に戻す）。 -/
@[spec_doc "docs/spec/reservation.md#予約確認reserveconfirm"]
def compactPassengers (ps : List PassengerInput) : List PassengerInput :=
  let ne := ps.filter (!·.isEmpty)
  ne ++ List.replicate (Config.maxPassengersNumber - ne.length) ({} : PassengerInput)

/-! ## 予約内容の組み立て -/

/-- 採番前の予約内容。すべての予約フライトが同じ搭乗者列を持つ。 -/
@[spec_doc "docs/spec/reservation.md#予約内容の組み立て"]
structure Draft where
  repFamilyName : String
  repGivenName : String
  repAge : Nat
  repGender : Gender
  repTel : String
  repMail : String
  repMembershipNumber : Option MembershipNumber
  passengers : List Passenger
  flights : List FlightKey
  deriving DecidableEq

/-- 予約内容を組み立てる。搭乗者は空でない欄を入力順に並べたもの。空でない欄が無ければ無し（PRE。入力検証の相関
`e.ar.b2.5002` が除く）。 -/
@[spec_doc "docs/spec/reservation.md#予約内容の組み立て"]
def buildDraft (i : ReserveInput) (flights : List FlightKey) : Option Draft := do
  let ps ← (i.passengers.filter (!·.isEmpty)).mapM PassengerInput.toPassenger
  if ps.isEmpty then none
  return { repFamilyName := i.repFamilyName, repGivenName := i.repGivenName, repAge := i.repAge,
           repGender := i.repGender, repTel := i.repTel1 ++ "-" ++ i.repTel2 ++ "-" ++ i.repTel3,
           repMail := i.repMail, repMembershipNumber := memberNoOf i.repMembershipNumber,
           passengers := ps, flights }

/-! ## validateReservation -/

/-- 1. 代表者年齢。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def checkRepAge (cfg : Config) (d : Draft) : Except AtrsError Unit :=
  if d.repAge < cfg.representativeMinAge then .error (.business "e.ar.b2.2004" [toString cfg.representativeMinAge])
  else .ok ()

/-- 2. 運賃種別の利用条件（1 便）。運賃種別がマスタに無ければ無し（PRE: MD-3）。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def checkFareTypeOf (md : MasterData) (ps : List Passenger) (k : FlightKey) : Option (Except AtrsError Unit) := do
  let ft ← md.fareTypeOf k.fareTypeCd
  return match ft.fareTypeCd with
  | .LD => if ps.any (·.gender == .M) then .error (.business "e.ar.b2.2007") else .ok ()
  | .GD => if ps.length < ft.passengerMinNum then
      .error (.business "e.ar.b2.2010" [ft.fareTypeName, toString ft.passengerMinNum]) else .ok ()
  | _ => .ok ()

/-- 2. 運賃種別の利用条件（予約フライトを順に）。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def checkFareTypes (md : MasterData) (d : Draft) : Option (Except AtrsError Unit) :=
  d.flights.foldlM (init := .ok ()) fun acc k => do
    match acc with
    | .error e => return .error e
    | .ok () => checkFareTypeOf md d.passengers k

/-- 氏名（カナ）と性別が会員と一致する。 -/
def matchesMember (familyName givenName : String) (gender : Gender) (m : Member) : Bool :=
  familyName == m.kanaFamilyName && givenName == m.kanaGivenName && gender == m.gender

/-- 3. 代表者の会員照合（会員番号がある場合のみ）。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def checkRepMember (w : World) (d : Draft) : Except AtrsError Unit :=
  match d.repMembershipNumber with
  | none => .ok ()
  | some n =>
    match w.findMember n with
    | none => .error (.business "e.ar.b2.2002")
    | some m => if matchesMember d.repFamilyName d.repGivenName d.repGender m then .ok ()
      else .error (.business "e.ar.b2.2003")

/-- 4. 搭乗者の会員照合（1 から数えた位置 `pos`。空の欄を詰めた後の位置）。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def checkPassengerMembers (w : World) (ps : List Passenger) : Except AtrsError Unit :=
  ps.zipIdx.foldlM (init := ()) fun _ (p, i) =>
    match p.membershipNumber with
    | none => .ok ()
    | some n =>
      match w.findMember n with
      | none => .error (.business "e.ar.b2.2005" [toString (i + 1)])
      | some m => if matchesMember p.familyName p.givenName p.gender m then .ok ()
        else .error (.business "e.ar.b2.2006" [toString (i + 1)])

/-- `validateReservation`（評価順。最初に失敗した検査のエラーを返す）。搭乗者の会員照合は、原典では予約フライトごとに
繰り返すが、すべての予約フライトが同じ搭乗者列を持つので、1 回と同じ結果になる。 -/
@[spec_doc "docs/spec/reservation.md#validatereservation"]
def validateReservation (cfg : Config) (md : MasterData) (w : World) (d : Draft) : Option (Except AtrsError Unit) := do
  let ft ← checkFareTypes md d
  return do
    checkRepAge cfg d
    ft
    checkRepMember w d
    checkPassengerMembers w d.passengers

/-! ## 予約確認・予約確定 -/

/-- 予約確認（`reserveConfirm`）: 予約内容を組み立てて検証し、合計金額を返す。搭乗者欄を詰める処理は、組み立てに
影響しない（空の欄は組み立てで除かれる）。 -/
@[spec_doc "docs/spec/reservation.md#予約確認reserveconfirm"]
def reserveConfirm (cfg : Config) (md : MasterData) (w : World) (i : ReserveInput) (flights : List FlightKey) :
    Option (Except AtrsError Nat) := do
  let d ← buildDraft { i with passengers := compactPassengers i.passengers } flights
  match ← validateReservation cfg md w d with
  | .error e => return .error e
  | .ok () => return .ok (← Spec.Fare.totalFareOfKeys cfg md flights (d.passengers.map (·.age)))

/-- 予約確定の結果。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve"]
structure ReserveResult where
  reserveNo : ReserveNo
  paymentDate : Date
  totalFare : Nat
  deriving DecidableEq

/-- 4. 空席の確保（1 便）: 運賃種別の予約可能判定、主キーでの取得、空席数の検査と更新。
フライトが無ければ `InvalidRequest`（`validateFlightList` の後なので到達しない）。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve", gap "D-014"]
def secureSeats (md : MasterData) (today : Date) (n : Nat) (w : World) (k : FlightKey) :
    Option (Except AtrsError World) := do
  let ft ← md.fareTypeOf k.fareTypeCd
  if !Spec.FlightSearch.isAvailableFareType ft k.departureDate today then return .error (.business "e.ar.b2.2008")
  match w.findForUpdate k with
  | none => return .error (.invalidRequest "flight not found")
  | some f =>
    if f.vacantNum < n then return .error (.business "e.ar.b2.2009")
    return .ok (w.updateVacantNum k (f.vacantNum - n))

/-- 5〜6. 予約の登録: 予約番号、予約フライトごとに予約フライト番号と搭乗者番号を採番して登録する。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve"]
def register (d : Draft) (today : Date) (totalFare : Nat) (w : World) : ReserveNo × World :=
  let (reserveNo, w) := w.nextReserveNo
  let step := fun (acc : List ReserveFlight × World) (k : FlightKey) =>
    let (rfs, w) := acc
    let (rfNo, w) := w.nextReserveFlightNo
    let (recs, w) := d.passengers.foldl (fun (acc : List PassengerRecord × World) p =>
      let (rs, w) := acc
      let (pNo, w) := w.nextPassengerNo
      (rs ++ [⟨pNo, p⟩], w)) ([], w)
    (rfs ++ [⟨rfNo, reserveNo, k, recs⟩], w)
  let (rfs, w) := d.flights.foldl step ([], w)
  let r : Reservation :=
    { reserveNo, reserveDate := today, totalFare, repFamilyName := d.repFamilyName, repGivenName := d.repGivenName,
      repAge := d.repAge, repGender := d.repGender, repTel := d.repTel, repMail := d.repMail,
      repMembershipNumber := d.repMembershipNumber, reserveFlights := rfs }
  (reserveNo, w.insertReservation r)

/-- 予約確定（`reserve`）の標準の結果。1 つのトランザクションとして実行し、失敗したときは元の状態を返す。
予約内容の組み立て・`validateReservation`・合計金額のあと、予約フライトを順に空席を確保し、予約を登録する。
支払期限は往路の搭乗日。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve", gap "D-014"]
def reserve (cfg : Config) (md : MasterData) (today : Date) (w : World) (i : ReserveInput)
    (flights : List FlightKey) : Option (World × Except AtrsError ReserveResult) := do
  let d ← buildDraft i flights
  match ← validateReservation cfg md w d with
  | .error e => return (w, .error e)
  | .ok () =>
    let totalFare ← Spec.Fare.totalFareOfKeys cfg md flights (d.passengers.map (·.age))
    let secured ← flights.foldlM (init := Except.ok w) fun acc k => do
      match acc with
      | .error e => return .error e
      | .ok w' => secureSeats md today d.passengers.length w' k
    match secured with
    | .error e => return (w, .error e)
    | .ok w' =>
      let paymentDate ← flights.head?.map (·.departureDate)
      let (reserveNo, w'') := register d today totalFare w'
      return (w'', .ok { reserveNo, paymentDate, totalFare })

/-! ## 予約の操作（選択フライトの検証を含む） -/

/-- 予約の要求: 選択フライトと予約入力。 -/
@[spec_doc "docs/spec/http-contract.md#b2-予約"]
structure Request where
  selects : List SelectFlight
  form : ReserveInput
  deriving DecidableEq

/-- 選択フライトの検証の失敗は、予約確認・予約確定ではすべて改竄（`InvalidRequest`）とする（`Business` の
`e.ar.b2.2001` も含む。`docs/spec/http-contract.md#b2-予約`）。 -/
@[spec_doc "docs/spec/http-contract.md#b2-予約"]
def asInvalidRequest : AtrsError → AtrsError
  | .business code _ => .invalidRequest code
  | e => e

/-- 選択フライトの検証（予約確認・予約確定の前段）。 -/
@[spec_doc "docs/spec/http-contract.md#b2-予約"]
def checkSelects (cfg : Config) (md : MasterData) (w : World) (r : Request) : Option (Except AtrsError Unit) :=
  (validateFlightList cfg md w (r.selects.map (resolve md))).map fun x => x.mapError asInvalidRequest

/-- 予約確認の操作: 選択フライトの検証、予約確認。 -/
@[spec_doc "docs/spec/reservation.md#予約確認reserveconfirm"]
def confirmOp (cfg : Config) (md : MasterData) (w : World) (r : Request) : Option (Except AtrsError Nat) := do
  match ← checkSelects cfg md w r with
  | .error e => return .error e
  | .ok () => reserveConfirm cfg md w r.form (r.selects.map (·.key))

/-- 予約確定の操作の標準の結果: 選択フライトの検証、予約確定。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve", gap "D-014"]
def reserveOp (cfg : Config) (md : MasterData) (today : Date) (w : World) (r : Request) :
    Option (World × Except AtrsError ReserveResult) := do
  match ← checkSelects cfg md w r with
  | .error e => return (w, .error e)
  | .ok () => reserve cfg md today w r.form (r.selects.map (·.key))

end Spec.UseCase.Reserve
