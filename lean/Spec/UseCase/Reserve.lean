import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.Fare
import Spec.Error
import Spec.Port
import Spec.FlightSearch
import Spec.Ticket
import Spec.Nondet
import Spec.Seed.World
import Spec.Seed.FlightProps
import Machine

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

/-- 搭乗者を 1 人登録する（搭乗者番号を採番する）。 -/
def addPassenger (acc : List PassengerRecord × World) (p : Passenger) : List PassengerRecord × World :=
  ((acc.1 ++ [⟨acc.2.nextPassengerNo.1, p⟩]), acc.2.nextPassengerNo.2)

/-- 予約フライトを 1 便登録する（予約フライト番号を採番し、搭乗者を順に登録する）。 -/
def addReserveFlight (ps : List Passenger) (reserveNo : ReserveNo) (acc : List ReserveFlight × World) (k : FlightKey) :
    List ReserveFlight × World :=
  let w := acc.2.nextReserveFlightNo.2
  let recs := ps.foldl addPassenger ([], w)
  (acc.1 ++ [⟨acc.2.nextReserveFlightNo.1, reserveNo, k, recs.1⟩], recs.2)

/-- 5〜6. 予約の登録: 予約番号、予約フライトごとに予約フライト番号と搭乗者番号を採番して登録する。 -/
@[spec_doc "docs/spec/reservation.md#予約確定reserve"]
def register (d : Draft) (today : Date) (totalFare : Nat) (w : World) : ReserveNo × World :=
  let reserveNo := w.nextReserveNo.1
  let rfs := d.flights.foldl (addReserveFlight d.passengers reserveNo) ([], w.nextReserveNo.2)
  let r : Reservation :=
    { reserveNo, reserveDate := today, totalFare, repFamilyName := d.repFamilyName, repGivenName := d.repGivenName,
      repAge := d.repAge, repGender := d.repGender, repTel := d.repTel, repMail := d.repMail,
      repMembershipNumber := d.repMembershipNumber, reserveFlights := rfs.1 }
  (reserveNo, rfs.2.insertReservation r)

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

/-- 要求が、入力検証の単項目制約のうち長さと桁を満たし（`docs/spec/input-validation.md#予約入力b2`）、選択フライトの
便名が空白でない（原典の `Assert.hasText`）。代表者の電話番号は相関 1（`repTel1`・`repTel2` の長さの和が 6〜7）の上限を
課す。PRE に含める（[Source] の列の長さ `VARCHAR(n)` と `int` に収まることに使う。backlog aedf の第 3 段）。 -/
@[spec_doc "docs/spec/input-validation.md#予約入力b2"]
def Request.Valid (r : Request) : Prop :=
  (∀ s ∈ r.selects, hasText s.flightName.val = true) ∧
    r.form.repFamilyName.length ≤ 10 ∧ r.form.repGivenName.length ≤ 10 ∧ r.form.repAge ≤ 999 ∧
    r.form.repTel1.length + r.form.repTel2.length ≤ 7 ∧ r.form.repTel3.length ≤ 4 ∧ r.form.repMail.length ≤ 256 ∧
    r.form.passengers.length ≤ Config.maxPassengersNumber ∧
    ∀ p ∈ r.form.passengers, (∀ s ∈ p.familyName, s.length ≤ 10) ∧ (∀ s ∈ p.givenName, s.length ≤ 10) ∧
      (∀ a ∈ p.age, a ≤ 999)

instance (r : Request) : Decidable r.Valid := by unfold Request.Valid; infer_instance

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

/-! ## 抽象機械（backlog aedf の第 2 段） -/

/-- 予約の操作の種類: 予約確認・予約確定。 -/
@[spec_doc "docs/spec/reservation.md"]
inductive Op where
  | confirm
  | reserve
  deriving DecidableEq, Repr

/-- 予約の機械の入力: 設定・マスタ・今日の日付（1 回だけ読んだ値。D-014）・要求・操作の種類。 -/
@[spec_doc "docs/spec/reservation.md"]
structure MInput where
  cfg : Config
  md : MasterData
  today : Date
  req : Request
  op : Op

/-- 予約の機械の出力の値: 予約確認は合計金額、予約確定は予約番号・支払期限・合計金額。 -/
@[spec_doc "docs/spec/reservation.md"]
inductive MOutputValue where
  | confirmed (totalFare : Nat)
  | reserved (r : ReserveResult)
  deriving DecidableEq

/-- 予約の機械の出力。 -/
abbrev MOutput := Except AtrsError MOutputValue

/-- PRE: 設定・マスタが妥当で、要求が入力検証の長さと桁を満たし（`Request.Valid`）、会員のカード種別がマスタにあり
（`World.MemberRefMaster`）、操作の標準の結果が定まる（選択フライトが 1〜2 件、空でない搭乗者欄が姓・名・年齢・性別を
持ち、少なくとも 1 欄あり、マスタに便・区間・運賃種別がある）。 -/
@[spec_doc "docs/spec/reservation.md"]
def MInput.Pre (w : World) (i : MInput) : Prop :=
  i.cfg.Valid ∧ i.md.Valid i.cfg ∧ i.req.Valid ∧ w.MemberRefMaster i.md ∧
    match i.op with
    | .confirm => (confirmOp i.cfg i.md w i.req).isSome = true
    | .reserve => (reserveOp i.cfg i.md i.today w i.req).isSome = true

/-- 採番を進める（`Conflict`・I/O 失敗のときの、失敗するまでに進んだ採番）。 -/
def advance (w : World) (a : Spec.Nondet.SeqAdvance) : World :=
  { w with sequences := { member := w.sequences.member + a.member, reserve := w.sequences.reserve + a.reserve,
                          reserveFlight := w.sequences.reserveFlight + a.reserveFlight,
                          passenger := w.sequences.passenger + a.passenger } }

/-- 操作の標準の結果（選択を持たない部分）。PRE の外は、状態を変えずに `InvalidRequest`。 -/
def baseStep (w : World) (i : MInput) : World × MOutput :=
  match i.op with
  | .confirm =>
    match confirmOp i.cfg i.md w i.req with
    | some r => (w, r.map .confirmed)
    | none => (w, .error (.invalidRequest "outside PRE"))
  | .reserve =>
    match reserveOp i.cfg i.md i.today w i.req with
    | some (w', r) => (w', r.map .reserved)
    | none => (w, .error (.invalidRequest "outside PRE"))

/-- 自由な選択 N-004: `InvalidRequest` の詳細を置き換える（変えうるのは詳細の文字列だけ）。 -/
def withDetail (d : Spec.Nondet.InvalidRequestDetail) : MOutput → MOutput
  | .error (.invalidRequest s) => .error (.invalidRequest (d.override.getD s))
  | o => o

/-- 予約の 1 歩（選択の像）。環境の選択（N-001・N-002）と自由な選択（N-004）を受ける。
- I/O 失敗: 出力は `System("e.ar.fw.9999")`。状態は採番の前進だけ変わる。
- `Conflict`（予約確定だけ。予約確認は状態を変えないので `Conflict` を返さない）: 出力は `Conflict`。状態は採番の前進だけ
  変わる。
- それ以外は、標準の結果の `InvalidRequest` の詳細を自由な選択で置き換えたもの。 -/
@[spec_doc "docs/spec/ports.md#トランザクション"]
def reserveStep (w : World) (i : MInput)
    (c : (Spec.Nondet.ConflictChoice × Spec.Nondet.IoFailureChoice) × Spec.Nondet.InvalidRequestDetail) :
    World × MOutput :=
  match c.1.2, c.1.1, i.op with
  | .failure a, _, _ => (advance w a, .error (.system "e.ar.fw.9999"))
  | .none, .conflict a, .reserve => (advance w a, .error (.conflict "conflict"))
  | _, _, _ => let r := baseStep w i; (r.1, withDetail c.2 r.2)

/-- 予約の抽象機械。状態は `World`、初期状態はシードを投入した後の `World` の 1 点。 -/
@[spec_doc "docs/spec/reservation.md"]
def reserveMachine : Machine.Machine World MInput MOutput :=
  Machine.Machine.ofChoice World.Inv (· = Spec.Seed.World.world) MInput.Pre reserveStep
    (Spec.Nondet.ConflictChoice.std, Spec.Nondet.IoFailureChoice.std) Spec.Nondet.InvalidRequestDetail.std

/-- SPEC-001: PRE の下で、標準の選択は関係に含まれる。 -/
@[obligation "SPEC-001"]
theorem reserveMachine_run_step :
    ∀ s i, reserveMachine.Pre s i → reserveMachine.step s i (reserveMachine.run s i).1 (reserveMachine.run s i).2 :=
  reserveMachine.run_step

/-! ### 空席の確保は主キーを保つ -/

theorem updateVacantNum_keys (w : World) (k : FlightKey) (n : Nat) :
    (w.updateVacantNum k n).flights.map (·.key) = w.flights.map (·.key) := by
  simp only [World.updateVacantNum, List.map_map]
  congr 1
  funext f
  simp only [Function.comp]
  split <;> rfl

theorem secureSeats_keys {md : MasterData} {today : Date} {n : Nat} {w w' : World} {k : FlightKey}
    (h : secureSeats md today n w k = some (.ok w')) : w'.flights.map (·.key) = w.flights.map (·.key) := by
  unfold secureSeats at h
  simp only [Option.bind_eq_bind] at h
  cases hft : md.fareTypeOf k.fareTypeCd with
  | none => simp [hft] at h
  | some ft =>
    simp only [hft, Option.bind_some] at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · simp only [Option.pure_def, Option.some.injEq, Except.ok.injEq] at h
          subst h
          exact updateVacantNum_keys _ _ _

theorem foldSecure_keys {md : MasterData} {today : Date} {n : Nat} :
    ∀ (ks : List FlightKey) (acc : Except AtrsError World) (w w' : World),
      (∀ w₀, acc = .ok w₀ → w₀.flights.map (·.key) = w.flights.map (·.key)) →
      ks.foldlM (init := acc) (fun acc k => do
        match acc with
        | .error e => return .error e
        | .ok w' => secureSeats md today n w' k) = some (.ok w') →
      w'.flights.map (·.key) = w.flights.map (·.key)
  | [], acc, w, w', hacc, h => by
    simp only [List.foldlM_nil, Option.pure_def, Option.some.injEq] at h
    exact hacc w' h
  | k :: ks, acc, w, w', hacc, h => by
    simp only [List.foldlM_cons, Option.bind_eq_bind] at h
    cases acc with
    | error e =>
      simp only [Option.pure_def, Option.bind_some] at h
      exact foldSecure_keys ks (.error e) w w' (fun _ he => by cases he) h
    | ok w₀ =>
      simp only at h
      cases hs : secureSeats md today n w₀ k with
      | none => simp [hs] at h
      | some r =>
        simp only [hs, Option.bind_some] at h
        refine foldSecure_keys ks r w w' (fun w₁ he => ?_) h
        subst he
        rw [secureSeats_keys hs, hacc w₀ rfl]

theorem foldl_addPassenger_flights :
    ∀ (ps : List Passenger) (acc : List PassengerRecord × World), (ps.foldl addPassenger acc).2.flights = acc.2.flights
  | [], _ => rfl
  | p :: ps, acc => by rw [List.foldl_cons, foldl_addPassenger_flights ps]; rfl

theorem foldl_addReserveFlight_flights (ps : List Passenger) (rn : ReserveNo) :
    ∀ (ks : List FlightKey) (acc : List ReserveFlight × World),
      (ks.foldl (addReserveFlight ps rn) acc).2.flights = acc.2.flights
  | [], _ => rfl
  | k :: ks, acc => by
    rw [List.foldl_cons, foldl_addReserveFlight_flights ps rn ks]
    simp only [addReserveFlight, foldl_addPassenger_flights]
    rfl

theorem register_flights (d : Draft) (today : Date) (t : Nat) (w : World) :
    (register d today t w).2.flights = w.flights := by
  simp only [register, World.insertReservation, foldl_addReserveFlight_flights]
  rfl

theorem reserve_keys {cfg : Config} {md : MasterData} {today : Date} {w w' : World} {i : ReserveInput}
    {ks : List FlightKey} {r : Except AtrsError ReserveResult} (h : reserve cfg md today w i ks = some (w', r)) :
    w'.flights.map (·.key) = w.flights.map (·.key) := by
  unfold reserve at h
  simp only [Option.bind_eq_bind] at h
  cases hd : buildDraft i ks with
  | none => simp [hd] at h
  | some d =>
    simp only [hd, Option.bind_some] at h
    cases hv : validateReservation cfg md w d with
    | none => simp [hv] at h
    | some v =>
      simp only [hv, Option.bind_some] at h
      cases v with
      | error e => simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h; rw [h.1]
      | ok u =>
        simp only at h
        cases ht : Spec.Fare.totalFareOfKeys cfg md ks (d.passengers.map (·.age)) with
        | none => simp [ht] at h
        | some t =>
          simp only [ht, Option.bind_some] at h
          generalize hf : ks.foldlM (init := Except.ok w) (fun acc k => do
            match acc with
            | .error e => return .error e
            | .ok w' => secureSeats md today d.passengers.length w' k) = sec at h
          cases sec with
          | none => simp at h
          | some sec =>
            simp only [Option.bind_some] at h
            cases sec with
            | error e => simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h; rw [h.1]
            | ok w₁ =>
              simp only at h
              cases hp : ks.head?.map (·.departureDate) with
              | none => simp [hp] at h
              | some p =>
                simp only [hp, Option.bind_some, Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
                rw [← h.1, register_flights]
                exact foldSecure_keys ks (.ok w) w w₁ (fun w₀ he => by cases he; rfl) hf

theorem reserveOp_keys {cfg : Config} {md : MasterData} {today : Date} {w w' : World} {q : Request}
    {r : Except AtrsError ReserveResult} (h : reserveOp cfg md today w q = some (w', r)) :
    w'.flights.map (·.key) = w.flights.map (·.key) := by
  unfold reserveOp at h
  simp only [Option.bind_eq_bind] at h
  cases hc : checkSelects cfg md w q with
  | none => simp [hc] at h
  | some c =>
    simp only [hc, Option.bind_some] at h
    cases c with
    | error e => simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h; rw [h.1]
    | ok u => exact reserve_keys h

theorem reserveStep_keys (w : World) (i : MInput) (c) :
    (reserveStep w i c).1.flights.map (·.key) = w.flights.map (·.key) := by
  unfold reserveStep
  split
  · rfl
  · rfl
  · simp only [baseStep]
    split
    · split <;> rfl
    · split
      · rename_i w' r h; exact reserveOp_keys h
      · rfl

/-- SPEC-002・SPEC-003: 初期状態（シードを投入した後の `World`）は INV を満たし、1 歩は INV（フライトの主キーの一意性）を
保つ。空席の確保は主キーを変えず、登録と採番はフライトを変えない。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem reserveMachine_sound : reserveMachine.Sound where
  init_inv s h := by
    subst h
    exact Spec.Seed.FlightProps.world_inv
  step_inv s i s' o hi _ hs := by
    obtain ⟨c, hc⟩ := hs
    have := reserveStep_keys s i c
    rw [hc] at this
    show World.Inv s'
    unfold World.Inv
    rw [this]
    exact hi

/-- SPEC-007: 初期状態は、シードを投入した後の `World` の 1 点。 -/
@[obligation "SPEC-007"]
theorem reserveMachine_initIs : reserveMachine.InitIs Spec.Seed.World.world := fun _ => Iff.rfl

/-- SPEC-004: I/O 失敗の選択では、出力は `System("e.ar.fw.9999")` で、状態は採番の前進だけ変わる。 -/
@[obligation "SPEC-004"]
theorem reserveStep_failure (w : World) (i : MInput) (e : Spec.Nondet.ConflictChoice) (a : Spec.Nondet.SeqAdvance)
    (d : Spec.Nondet.InvalidRequestDetail) :
    reserveStep w i ((e, .failure a), d) = (advance w a, .error (.system "e.ar.fw.9999")) := rfl

/-- SPEC-004: 予約確定の `Conflict` の選択（I/O 失敗が無いとき）では、出力は `Conflict` で、状態は採番の前進だけ変わる。 -/
@[obligation "SPEC-004"]
theorem reserveStep_conflict (w : World) (i : MInput) (hi : i.op = .reserve) (a : Spec.Nondet.SeqAdvance)
    (d : Spec.Nondet.InvalidRequestDetail) :
    reserveStep w i ((.conflict a, .none), d) = (advance w a, .error (.conflict "conflict")) := by
  unfold reserveStep; rw [hi]

/-- 採番の前進はフライト・会員・予約を変えない。 -/
theorem advance_frame (w : World) (a : Spec.Nondet.SeqAdvance) :
    (advance w a).flights = w.flights ∧ (advance w a).members = w.members ∧
      (advance w a).reservations = w.reservations := ⟨rfl, rfl, rfl⟩

/-! ### 標準の結果は環境に固有のエラーを返さない（SPEC-008） -/

/-- 環境に固有のエラー（N-001 の `Conflict`、N-002 の `System("e.ar.fw.9999")`）でない。 -/
def NotEnvError : AtrsError → Prop
  | .conflict _ => False
  | .system code _ => code ≠ "e.ar.fw.9999"
  | _ => True

theorem checkFlight_err {w : World} {f : ResolvedFlight} {e : AtrsError}
    (h : checkFlight w f = .error e) : NotEnvError e := by
  unfold checkFlight at h
  split at h
  · cases h; trivial
  · split at h <;> cases h; trivial

theorem checkInterval_err {cfg : Config} {o h' : FlightKey} {om hm : FlightMaster} {e : AtrsError}
    (h : checkInterval cfg o om h' hm = .error e) : NotEnvError e := by
  unfold checkInterval at h; split at h <;> cases h; trivial

theorem checkFareTypes_err {ks : List FlightKey} {e : AtrsError} (h : Spec.Ticket.checkFareTypes ks = .error e) :
    NotEnvError e := by
  unfold Spec.Ticket.checkFareTypes at h
  split at h
  · split at h <;> cases h; trivial
  · split at h
    · cases h; trivial
    · split at h <;> cases h; trivial
  · cases h; trivial

theorem asInvalidRequest_notEnv (e : AtrsError) (h : NotEnvError e) : NotEnvError (asInvalidRequest e) := by
  cases e <;> simp_all [asInvalidRequest, NotEnvError]

/-- `Except` の計算の、どのエラーも環境に固有でない。 -/
def AllNE {α : Type} (x : Except AtrsError α) : Prop := ∀ e, x = .error e → NotEnvError e

theorem AllNE.ok {α : Type} (a : α) : AllNE (.ok a : Except AtrsError α) := fun _ h => by cases h

theorem AllNE.err {α : Type} {e : AtrsError} (h : NotEnvError e) : AllNE (.error e : Except AtrsError α) :=
  fun _ he => by cases he; exact h

theorem AllNE.bind {α β : Type} {x : Except AtrsError α} {f : α → Except AtrsError β} (hx : AllNE x)
    (hf : ∀ a, x = .ok a → AllNE (f a)) : AllNE (x >>= f) := by
  intro e he
  cases hxv : x with
  | error e' => rw [hxv] at he; cases he; exact hx _ hxv
  | ok a => rw [hxv] at he; exact hf a hxv e he

theorem AllNE.map {α β : Type} {x : Except AtrsError α} {g : α → β} (hx : AllNE x) : AllNE (g <$> x) := by
  intro e he
  cases hxv : x with
  | error e' => rw [hxv] at he; cases he; exact hx _ hxv
  | ok a => rw [hxv] at he; cases he

theorem AllNE.mapError {α : Type} {x : Except AtrsError α} (hx : AllNE x) : AllNE (x.mapError asInvalidRequest) := by
  intro e he
  cases hxv : x with
  | error e' => rw [hxv] at he; cases he; exact asInvalidRequest_notEnv _ (hx _ hxv)
  | ok a => rw [hxv] at he; cases he

theorem checkReverse_allNE {md : MasterData} {om hm : FlightMaster} {r : Except AtrsError Unit}
    (h : checkReverse md om hm = some r) : AllNE r := by
  unfold checkReverse at h
  cases h1 : routeOfMaster md om <;> cases h2 : routeOfMaster md hm <;>
    simp only [h1, h2, Option.bind_eq_bind, Option.bind_none, Option.bind_some, reduceCtorEq, Option.pure_def,
      Option.some.injEq] at h
  subst h
  split
  · exact AllNE.ok _
  · exact AllNE.err trivial

theorem bind_reverse {o : Option (Except AtrsError Unit)} {f : Unit → Except AtrsError Unit} {x : Except AtrsError Unit}
    (ho : ∀ r, o = some r → AllNE r) (hf : ∀ u, AllNE (f u)) (h : o.bind (fun r => some (r.bind f)) = some x) :
    AllNE x := by
  cases hov : o with
  | none => rw [hov] at h; cases h
  | some r =>
    rw [hov] at h
    simp only [Option.bind_some, Option.some.injEq] at h
    subst h
    exact AllNE.bind (ho r hov) fun u _ => hf u

theorem validateFlightList_allNE {cfg : Config} {md : MasterData} {w : World} {fs : List ResolvedFlight}
    {x : Except AtrsError Unit} (h : validateFlightList cfg md w fs = some x) : AllNE x := by
  unfold validateFlightList at h
  split at h
  · cases h
    exact AllNE.bind (fun e he => checkFlight_err he) fun _ _ e he => checkFareTypes_err he
  · split at h
    · cases h; exact AllNE.err (checkFlight_err (by assumption))
    · split at h
      · cases h; exact AllNE.err (checkFlight_err (by assumption))
      · split at h
        · cases h; exact AllNE.err (checkInterval_err (by assumption))
        · simp only [Option.bind_eq_bind] at h
          exact bind_reverse (fun r hr => checkReverse_allNE hr) (fun _ e he => checkFareTypes_err he) h
  · cases h

theorem checkRepAge_allNE (cfg : Config) (d : Draft) : AllNE (checkRepAge cfg d) := by
  unfold checkRepAge; split
  · exact AllNE.err trivial
  · exact AllNE.ok _

theorem checkFareTypeOf_allNE {md : MasterData} {ps : List Passenger} {k : FlightKey} {r : Except AtrsError Unit}
    (h : checkFareTypeOf md ps k = some r) : AllNE r := by
  unfold checkFareTypeOf at h
  cases hft : md.fareTypeOf k.fareTypeCd with
  | none => simp [hft] at h
  | some ft =>
    simp only [hft, Option.bind_eq_bind, Option.bind_some, Option.pure_def, Option.some.injEq] at h
    subst h
    split
    · split
      · exact AllNE.err trivial
      · exact AllNE.ok _
    · split
      · exact AllNE.err trivial
      · exact AllNE.ok _
    · exact AllNE.ok _

theorem foldFareTypes_allNE {md : MasterData} {ps : List Passenger} :
    ∀ (ks : List FlightKey) (acc : Except AtrsError Unit) (r : Except AtrsError Unit), AllNE acc →
      ks.foldlM (init := acc) (fun acc k => do
        match acc with
        | .error e => return .error e
        | .ok () => checkFareTypeOf md ps k) = some r → AllNE r
  | [], acc, r, hacc, h => by
    simp only [List.foldlM_nil, Option.pure_def, Option.some.injEq] at h; exact h ▸ hacc
  | k :: ks, acc, r, hacc, h => by
    simp only [List.foldlM_cons, Option.bind_eq_bind] at h
    cases acc with
    | error e =>
      simp only [Option.pure_def, Option.bind_some] at h
      exact foldFareTypes_allNE ks (.error e) r hacc h
    | ok u =>
      simp only at h
      cases hc : checkFareTypeOf md ps k with
      | none => simp [hc] at h
      | some c =>
        simp only [hc, Option.bind_some] at h
        exact foldFareTypes_allNE ks c r (checkFareTypeOf_allNE hc) h

theorem checkRepMember_allNE (w : World) (d : Draft) : AllNE (checkRepMember w d) := by
  unfold checkRepMember
  split
  · exact AllNE.ok _
  · split
    · exact AllNE.err trivial
    · split
      · exact AllNE.ok _
      · exact AllNE.err trivial

theorem foldPassengerMembers_allNE (w : World) :
    ∀ (xs : List (Passenger × Nat)) (u : Unit), AllNE (xs.foldlM (init := u) fun _ (p, i) =>
      match p.membershipNumber with
      | none => (.ok () : Except AtrsError Unit)
      | some n =>
        match w.findMember n with
        | none => .error (.business "e.ar.b2.2005" [toString (i + 1)])
        | some m => if matchesMember p.familyName p.givenName p.gender m then .ok ()
          else .error (.business "e.ar.b2.2006" [toString (i + 1)]))
  | [], u => AllNE.ok u
  | (p, i) :: xs, u => by
    rw [List.foldlM_cons]
    refine AllNE.bind ?_ fun u' _ => foldPassengerMembers_allNE w xs u'
    dsimp only
    cases p.membershipNumber with
    | none => exact AllNE.ok _
    | some n =>
      dsimp only
      cases w.findMember n with
      | none => exact AllNE.err (e := .business _ _) trivial
      | some m =>
        dsimp only
        split
        · exact AllNE.ok _
        · exact AllNE.err (e := .business _ _) trivial

theorem validateReservation_allNE {cfg : Config} {md : MasterData} {w : World} {d : Draft} {r : Except AtrsError Unit}
    (h : validateReservation cfg md w d = some r) : AllNE r := by
  unfold validateReservation at h
  simp only [Option.bind_eq_bind] at h
  cases hft : checkFareTypes md d with
  | none => simp [hft] at h
  | some ft =>
    simp only [hft, Option.bind_some, Option.pure_def, Option.some.injEq] at h
    subst h
    have hft' : AllNE ft := foldFareTypes_allNE d.flights (.ok ()) ft (AllNE.ok _) hft
    exact AllNE.bind (checkRepAge_allNE cfg d) fun _ _ => AllNE.bind hft' fun _ _ =>
      AllNE.bind (checkRepMember_allNE w d) fun _ _ => foldPassengerMembers_allNE w _ ()

theorem secureSeats_allNE {md : MasterData} {today : Date} {n : Nat} {w : World} {k : FlightKey}
    {r : Except AtrsError World} (h : secureSeats md today n w k = some r) : AllNE r := by
  unfold secureSeats at h
  cases hft : md.fareTypeOf k.fareTypeCd with
  | none => simp [hft] at h
  | some ft =>
    simp only [hft, Option.bind_eq_bind, Option.bind_some] at h
    split at h
    · simp only [Option.pure_def, Option.some.injEq] at h; subst h; exact AllNE.err (e := .business _ _) trivial
    · split at h
      · simp only [Option.pure_def, Option.some.injEq] at h; subst h; exact AllNE.err (e := .invalidRequest _) trivial
      · split at h
        · simp only [Option.pure_def, Option.some.injEq] at h; subst h; exact AllNE.err (e := .business _ _) trivial
        · simp only [Option.pure_def, Option.some.injEq] at h; subst h; exact AllNE.ok _

theorem foldSecure_allNE {md : MasterData} {today : Date} {n : Nat} :
    ∀ (ks : List FlightKey) (acc r : Except AtrsError World), AllNE acc →
      ks.foldlM (init := acc) (fun acc k => do
        match acc with
        | .error e => return .error e
        | .ok w' => secureSeats md today n w' k) = some r → AllNE r
  | [], acc, r, hacc, h => by
    simp only [List.foldlM_nil, Option.pure_def, Option.some.injEq] at h; exact h ▸ hacc
  | k :: ks, acc, r, hacc, h => by
    simp only [List.foldlM_cons, Option.bind_eq_bind] at h
    cases acc with
    | error e =>
      simp only [Option.pure_def, Option.bind_some] at h
      exact foldSecure_allNE ks (.error e) r hacc h
    | ok w₀ =>
      simp only at h
      cases hs : secureSeats md today n w₀ k with
      | none => simp [hs] at h
      | some c =>
        simp only [hs, Option.bind_some] at h
        exact foldSecure_allNE ks c r (secureSeats_allNE hs) h

theorem reserve_allNE {cfg : Config} {md : MasterData} {today : Date} {w w' : World} {i : ReserveInput}
    {ks : List FlightKey} {r : Except AtrsError ReserveResult} (h : reserve cfg md today w i ks = some (w', r)) :
    AllNE r := by
  unfold reserve at h
  simp only [Option.bind_eq_bind] at h
  cases hd : buildDraft i ks with
  | none => simp [hd] at h
  | some d =>
    simp only [hd, Option.bind_some] at h
    cases hv : validateReservation cfg md w d with
    | none => simp [hv] at h
    | some v =>
      simp only [hv, Option.bind_some] at h
      cases v with
      | error e =>
        simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
        rw [← h.2]; exact AllNE.err (validateReservation_allNE hv e rfl)
      | ok u =>
        simp only at h
        cases ht : Spec.Fare.totalFareOfKeys cfg md ks (d.passengers.map (·.age)) with
        | none => simp [ht] at h
        | some t =>
          simp only [ht, Option.bind_some] at h
          generalize hf : ks.foldlM (init := Except.ok w) (fun acc k => do
            match acc with
            | .error e => return .error e
            | .ok w' => secureSeats md today d.passengers.length w' k) = sec at h
          cases sec with
          | none => simp at h
          | some sec =>
            simp only [Option.bind_some] at h
            cases sec with
            | error e =>
              simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
              rw [← h.2]; exact AllNE.err (foldSecure_allNE ks (.ok w) _ (AllNE.ok _) hf e rfl)
            | ok w₁ =>
              simp only at h
              cases hp : ks.head?.map (·.departureDate) with
              | none => simp [hp] at h
              | some p =>
                simp only [hp, Option.bind_some, Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
                rw [← h.2]; exact AllNE.ok _

theorem reserveConfirm_allNE {cfg : Config} {md : MasterData} {w : World} {i : ReserveInput} {ks : List FlightKey}
    {r : Except AtrsError Nat} (h : reserveConfirm cfg md w i ks = some r) : AllNE r := by
  unfold reserveConfirm at h
  simp only [Option.bind_eq_bind] at h
  cases hd : buildDraft { i with passengers := compactPassengers i.passengers } ks with
  | none => simp [hd] at h
  | some d =>
    simp only [hd, Option.bind_some] at h
    cases hv : validateReservation cfg md w d with
    | none => simp [hv] at h
    | some v =>
      simp only [hv, Option.bind_some] at h
      cases v with
      | error e =>
        simp only [Option.pure_def, Option.some.injEq] at h
        rw [← h]; exact AllNE.err (validateReservation_allNE hv e rfl)
      | ok u =>
        simp only at h
        cases ht : Spec.Fare.totalFareOfKeys cfg md ks (d.passengers.map (·.age)) with
        | none => simp [ht] at h
        | some t => simp only [ht, Option.bind_some, Option.pure_def, Option.some.injEq] at h; rw [← h]; exact AllNE.ok _

theorem checkSelects_allNE {cfg : Config} {md : MasterData} {w : World} {q : Request} {x : Except AtrsError Unit}
    (h : checkSelects cfg md w q = some x) : AllNE x := by
  unfold checkSelects at h
  cases hv : validateFlightList cfg md w (q.selects.map (resolve md)) with
  | none => simp [hv] at h
  | some v =>
    simp only [hv, Option.map_some, Option.some.injEq] at h
    subst h
    exact AllNE.mapError (validateFlightList_allNE hv)

theorem confirmOp_allNE {cfg : Config} {md : MasterData} {w : World} {q : Request} {r : Except AtrsError Nat}
    (h : confirmOp cfg md w q = some r) : AllNE r := by
  unfold confirmOp at h
  simp only [Option.bind_eq_bind] at h
  cases hc : checkSelects cfg md w q with
  | none => simp [hc] at h
  | some c =>
    simp only [hc, Option.bind_some] at h
    cases c with
    | error e => simp only [Option.pure_def, Option.some.injEq] at h; rw [← h]; exact AllNE.err (checkSelects_allNE hc e rfl)
    | ok u => exact reserveConfirm_allNE h

theorem reserveOp_allNE {cfg : Config} {md : MasterData} {today : Date} {w w' : World} {q : Request}
    {r : Except AtrsError ReserveResult} (h : reserveOp cfg md today w q = some (w', r)) : AllNE r := by
  unfold reserveOp at h
  simp only [Option.bind_eq_bind] at h
  cases hc : checkSelects cfg md w q with
  | none => simp [hc] at h
  | some c =>
    simp only [hc, Option.bind_some] at h
    cases c with
    | error e =>
      simp only [Option.pure_def, Option.some.injEq, Prod.mk.injEq] at h
      rw [← h.2]; exact AllNE.err (checkSelects_allNE hc e rfl)
    | ok u => exact reserve_allNE h

theorem baseStep_allNE (w : World) (i : MInput) : AllNE (baseStep w i).2 := by
  unfold baseStep
  split
  · split
    · rename_i r h; exact AllNE.map (confirmOp_allNE h)
    · exact AllNE.err (e := .invalidRequest _) trivial
  · split
    · rename_i w' r h; exact AllNE.map (reserveOp_allNE h)
    · exact AllNE.err (e := .invalidRequest _) trivial

theorem withDetail_allNE (d : Spec.Nondet.InvalidRequestDetail) {o : MOutput} (h : AllNE o) : AllNE (withDetail d o) := by
  intro e he
  unfold withDetail at he
  split at he
  · cases he; trivial
  · exact h e he

/-- SPEC-008: 標準の環境（衝突も I/O 失敗も起きない）では、予約の 1 歩は環境に固有の結果（N-001 の `Conflict`、N-002 の
`System("e.ar.fw.9999")`）を返さない。 -/
@[obligation "SPEC-008"]
theorem reserveStep_std (w : World) (i : MInput) (d : Spec.Nondet.InvalidRequestDetail) :
    AllNE (reserveStep w i ((Spec.Nondet.ConflictChoice.std, Spec.Nondet.IoFailureChoice.std), d)).2 := by
  have h : reserveStep w i ((Spec.Nondet.ConflictChoice.std, Spec.Nondet.IoFailureChoice.std), d) =
      ((baseStep w i).1, withDetail d (baseStep w i).2) := by
    unfold reserveStep; cases i.op <;> rfl
  rw [h]
  exact withDetail_allNE d (baseStep_allNE w i)

end Spec.UseCase.Reserve
