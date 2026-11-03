import Lean.Data.Json
import SourceModel
import Tests.Conformance
import Tests.MasterSql

/-!
# Tests.ReservationSql

予約が使う Mapper の文の差分実行（backlog aedf の第 2 段）。`conformance/sql/reservation.json`
（`tools/conformance/reservation_sql.py` が PostgreSQL で生成）と照合する。

- 各ケース: PostgreSQL から読み戻した初期状態を `FlightDb` にし、段ごとに文の写し
  （`FlightRepository.{existsRows, findOneForUpdateRows, updateRows}`・`MemberRepository.findOneRows`・
  `ReservationRepository.{nextReserveNo, insertRow, nextReserveFlightNo, insertReserveFlightRow, nextPassengerNo,
  insertPassengerRow}`）を評価して、PostgreSQL の結果（行・件数・誤り）と、最後の状態（表の全行をバッグとして、
  シーケンスの状態）を比べる。束縛変数の値は、原典の引数のオブジェクト（`Reservation` など）を作り、写しの側で
  SQL の値にする（`bindKey`・`storeText` など。MyBatis の型ハンドラの写し）。
- 誤りは `SqlError` の種類を SQLSTATE の条件名に写して比べる。一意性・外部キーは制約名（大文字小文字を区別しない）、
  NOT NULL は列名も比べる。`string_data_right_truncation` は PostgreSQL の文言に列名が無いので、種類だけを比べる。
- 予約フライト番号・搭乗者番号の `NEXTVAL` が int の範囲を超えるとき: 値と、`readInteger` が失敗すること
  （JDBC の読み出しの失敗）を確かめ、あわせてその値を INSERT に束縛したときの PostgreSQL の誤りが `Int4.ofInt` の誤り
  （`numericOutOfRange`）と一致することを確かめる。
- `knownMismatch` のあるケースは、モデルと PostgreSQL が異なると分かっているもので、実際に異なることを確かめる
  （モデルが直ったら、生成器の注記を外す）。
- シード: `SourceModel.Db.MemberSeed` の MEMBER・MEMBER_LOGIN の行と `sq_member_1` の状態を、上流のシードを投入した
  PostgreSQL の表と比べる。`LOGIN_DATE_TIME` はシードでは `localtimestamp`（投入の時刻）で、モデルは投入日の 0:00 に
  固定するので、この列だけは比べない（PostgreSQL の側は NULL でないこと、モデルの側は値があることだけを確かめる）。
-/

open Lean LangSemantics.Sql.Core LangSemantics.Sql.Postgresql LangSemantics.Sql.Query LangSemantics.Java
  LangSemantics.Java.Int LangSemantics.Java.Exception SourceModel.Db.Schema SourceModel.Domain.Model ConformanceKit Tests.Conformance

open ConformanceKit.SqlTable ConformanceKit.Runner

namespace Tests.ReservationSql

open SourceModel.Domain.Repository.Flight.FlightRepository (KeyParams bindKey existsRows findOneForUpdateRows updateRows FlightResult)
open SourceModel.Domain.Repository.Reservation.ReservationRepository
  (nextReserveNo insertRow nextReserveFlightNo insertReserveFlightRow nextPassengerNo insertPassengerRow readInteger)

/-! ## 表の行を読む -/

/-- NULL を許す `VARCHAR(n)` の列。 -/
def ovcol (n : Nat) (t : Table) (r : Row) (c : String) : Except String (Option (Varchar n)) := do
  match ← col t r c with
  | none => pure none
  | some s => some <$> liftSql (Varchar.ofString c n s) c

/-- `BOOLEAN` の列（`t`・`f`）。 -/
def bcol (t : Table) (r : Row) (c : String) : Except String Bool := do
  match ← notNull (← col t r c) c with
  | "t" => pure true
  | "f" => pure false
  | s => throw s!"{c}: not a boolean: {s}"

/-- 数字だけの列を自然数に。 -/
def nat? (s : String) : Option Nat := if !s.isEmpty && s.all Char.isDigit then s.toNat? else none

/-- `TIMESTAMP` の値（`yyyy-MM-dd HH:mm:ss[.f…]`）をマイクロ秒に。 -/
def parseTimestamp (s : String) : Except String PgTimestamp := do
  let [d, t] := s.splitOn " " | throw s!"invalid timestamp: {s}"
  let date ← decodeDate d
  let (hms, frac) := match t.splitOn "." with
    | [a, b] => (a, b)
    | _ => (t, "")
  let [h, m, sec] := hms.splitOn ":" | throw s!"invalid timestamp: {s}"
  let some h := nat? h | throw s!"invalid timestamp: {s}"
  let some m := nat? m | throw s!"invalid timestamp: {s}"
  let some sec := nat? sec | throw s!"invalid timestamp: {s}"
  if frac.length > 6 then throw s!"invalid timestamp: {s}"
  let f ← if frac.isEmpty then pure 0 else
    match nat? (frac ++ String.ofList (List.replicate (6 - frac.length) '0')) with
    | some v => pure v
    | none => throw s!"invalid timestamp: {s}"
  let us : Int := date.epochDay * 86400000000 + ((h * 3600 + m * 60 + sec : Nat) : Int) * 1000000 + f
  if hv : dateMin * 86400000000 ≤ us ∧ us ≤ 9224318015999999999 then pure ⟨us, hv⟩
  else throw s!"timestamp out of range: {s}"

/-- NULL を許す `TIMESTAMP` の列（列が無ければ NULL とする。シードの `login_date_time` は書き出さない）。 -/
def otscol (t : Table) (r : Row) (c : String) : Except String (Option PgTimestamp) := do
  if !t.columns.contains c then return none
  match ← col t r c with
  | none => pure none
  | some s => some <$> parseTimestamp s

def flightRow (t : Table) (x : Row) : Except String FlightRow := do
  return { departureDate := ← Tests.MasterSql.dcol t x "departure_date", flightName := ← vcol 6 t x "flight_name",
           boardingClassCd := ← vcol 1 t x "boarding_class_cd", fareTypeCd := ← vcol 4 t x "fare_type_cd",
           vacantNum := ← icol t x "vacant_num" }

def memberRow (t : Table) (x : Row) : Except String MemberRow := do
  return { customerNo := ← vcol 10 t x "customer_no", kanjiFamilyName := ← vcol 10 t x "kanji_family_name",
           kanjiGivenName := ← vcol 10 t x "kanji_given_name", kanaFamilyName := ← vcol 10 t x "kana_family_name",
           kanaGivenName := ← vcol 10 t x "kana_given_name", birthday := ← Tests.MasterSql.dcol t x "birthday",
           gender := ← vcol 1 t x "gender", tel := ← vcol 13 t x "tel", zipCode := ← vcol 7 t x "zip_code",
           address := ← vcol 60 t x "address", mail := ← vcol 256 t x "mail", creditNo := ← vcol 16 t x "credit_no",
           creditTypeCd := ← vcol 3 t x "credit_type_cd", creditTerm := ← vcol 5 t x "credit_term" }

def memberLoginRow (t : Table) (x : Row) : Except String MemberLoginRow := do
  return { customerNo := ← vcol 10 t x "customer_no", password := ← vcol 124 t x "password",
           lastPassword := ← ovcol 124 t x "last_password", loginDateTime := ← otscol t x "login_date_time",
           loginFlg := ← bcol t x "login_flg" }

def reservationRow (t : Table) (x : Row) : Except String ReservationRow := do
  return { reserveNo := ← vcol 10 t x "reserve_no", reserveDate := ← Tests.MasterSql.dcol t x "reserve_date",
           totalFare := ← icol t x "total_fare", repFamilyName := ← vcol 10 t x "rep_family_name",
           repGivenName := ← vcol 10 t x "rep_given_name", repAge := ← icol t x "rep_age",
           repGender := ← vcol 1 t x "rep_gender", repTel := ← vcol 13 t x "rep_tel", repMail := ← vcol 256 t x "rep_mail",
           repCustomerNo := ← ovcol 10 t x "rep_customer_no" }

def reserveFlightRow (t : Table) (x : Row) : Except String ReserveFlightRow := do
  return { reserveFlightNo := ← icol t x "reserve_flight_no", reserveNo := ← vcol 10 t x "reserve_no",
           departureDate := ← Tests.MasterSql.dcol t x "departure_date", flightName := ← vcol 6 t x "flight_name",
           boardingClassCd := ← vcol 1 t x "boarding_class_cd", fareTypeCd := ← vcol 4 t x "fare_type_cd" }

def passengerRow (t : Table) (x : Row) : Except String PassengerRow := do
  return { passengerNo := ← icol t x "passenger_no", reserveFlightNo := ← icol t x "reserve_flight_no",
           familyName := ← vcol 10 t x "family_name", givenName := ← vcol 10 t x "given_name", age := ← icol t x "age",
           gender := ← vcol 1 t x "gender", customerNo := ← ovcol 10 t x "customer_no" }

/-- 表の全行を読む。 -/
def rowsOf {α : Type} (st : Json) (name : String) (f : Table → Row → Except String α) : Except String (List α) := do
  let t ← table st name
  t.rows.mapM (f t)

/-- シーケンスの状態（`null` は未使用）。 -/
def seqOf (st : Json) (name : String) : Except String LangSemantics.Sql.Sequence.SequenceState := do
  match ← st.getObjVal? "sequences" >>= (·.getObjVal? name) with
  | .null => pure none
  | j => some <$> (fromJson? j : Except String Int)

/-- 状態（表とシーケンス）を `FlightDb` に。 -/
def decodeState (st : Json) : Except String FlightDb := do
  return { flight := ← rowsOf st "FLIGHT" flightRow, member := ← rowsOf st "MEMBER" memberRow,
           memberLogin := ← rowsOf st "MEMBER_LOGIN" memberLoginRow, reservation := ← rowsOf st "RESERVATION" reservationRow,
           reserveFlight := ← rowsOf st "RESERVE_FLIGHT" reserveFlightRow, passenger := ← rowsOf st "PASSENGER" passengerRow,
           sqMember := ← seqOf st "sq_member_1", sqReservation := ← seqOf st "sq_reservation_1",
           sqReserveFlight := ← seqOf st "sq_reserve_flight_1", sqPassenger := ← seqOf st "sq_passenger_1" }

/-- 2 つの状態が等しい（表はバッグとして）。異なる表・シーケンスの名前の列。 -/
def stateDiff (a b : FlightDb) : List String :=
  [("FLIGHT", Bag.bagEq a.flight b.flight), ("MEMBER", Bag.bagEq a.member b.member),
   ("MEMBER_LOGIN", Bag.bagEq a.memberLogin b.memberLogin), ("RESERVATION", Bag.bagEq a.reservation b.reservation),
   ("RESERVE_FLIGHT", Bag.bagEq a.reserveFlight b.reserveFlight), ("PASSENGER", Bag.bagEq a.passenger b.passenger),
   ("sq_member_1", a.sqMember == b.sqMember), ("sq_reservation_1", a.sqReservation == b.sqReservation),
   ("sq_reserve_flight_1", a.sqReserveFlight == b.sqReserveFlight), ("sq_passenger_1", a.sqPassenger == b.sqPassenger)
  ].filterMap fun (n, ok) => if ok then none else some n

/-! ## 束縛する値（原典の引数のオブジェクトの欄） -/

def pVal (p : Json) (k : String) : Except String Json :=
  match p.getObjVal? k with
  | .ok v => .ok v
  | .error _ => .error s!"parameter {k} missing"

def pStr (p : Json) (k : String) : Except String (JRef String) := do
  match ← pVal p k with
  | .null => pure none
  | .str s => pure (some s)
  | _ => throw s!"parameter {k}: not a string"

def pInt (p : Json) (k : String) : Except String (JRef J32) := do
  match ← pVal p k with
  | .null => pure none
  | j => do
    let v : Int ← fromJson? j
    if -2147483648 ≤ v ∧ v ≤ 2147483647 then pure (some (J32.ofInt v)) else throw s!"parameter {k}: not an int"

def pDate (p : Json) (k : String) : Except String (JRef JLocalDate) := do
  match ← pStr p k with
  | none => pure none
  | some s => do
    let d ← decodeDate s
    some <$> need (JLocalDate.ofYMD? d.year d.month d.day) s!"parameter {k}: {s}"

def pEnum {α : Type} (p : Json) (k : String) (f : String → Option α) : Except String (JRef α) := do
  match ← pStr p k with
  | none => pure none
  | some s => some <$> need (f s) s!"parameter {k}: {s}"

/-- `exists`・`findOneForUpdate` の主キー（`bindKey`）。 -/
def keyParams (p : Json) : Except String KeyParams := do
  let bc ← pEnum p "boardingClass.boardingClassCd" Spec.Model.BoardingClassCd.ofCode?
  let ft ← pEnum p "fareType.fareTypeCd" Spec.Model.FareTypeCd.ofCode?
  return bindKey (← pDate p "departureDate") (← pStr p "flightName") (bc.map fun c => { boardingClassCd := some c })
    (ft.map fun c => { fareTypeCd := some c })

/-- `update(Flight)` の主キー（`#{flightMaster.flightName}` など）。 -/
def updateKey (p : Json) : Except String KeyParams := do
  let bc ← pEnum p "boardingClass.boardingClassCd" Spec.Model.BoardingClassCd.ofCode?
  let ft ← pEnum p "fareType.fareTypeCd" Spec.Model.FareTypeCd.ofCode?
  return bindKey (← pDate p "departureDate") (← pStr p "flightMaster.flightName")
    (bc.map fun c => { boardingClassCd := some c }) (ft.map fun c => { fareTypeCd := some c })

def memberRef (s : JRef String) : JRef Member := s.map fun n => { membershipNumber := some n }

def reservationOf (p : Json) : Except String Reservation := do
  return { reserveNo := ← pStr p "reserveNo", reserveDate := ← pDate p "reserveDate", totalFare := ← pInt p "totalFare",
           repFamilyName := ← pStr p "repFamilyName", repGivenName := ← pStr p "repGivenName", repAge := ← pInt p "repAge",
           repGender := ← pEnum p "repGender.code" Spec.Model.Gender.ofCode?, repTel := ← pStr p "repTel",
           repMail := ← pStr p "repMail", repMember := memberRef (← pStr p "repMember.membershipNumber") }

def reserveFlightOf (p : Json) : Except String ReserveFlight := do
  let bc ← pEnum p "flight.boardingClass.boardingClassCd" Spec.Model.BoardingClassCd.ofCode?
  let ft ← pEnum p "flight.fareType.fareTypeCd" Spec.Model.FareTypeCd.ofCode?
  let fn ← pStr p "flight.flightMaster.flightName"
  return { reserveFlightNo := ← pInt p "reserveFlightNo", reserveNo := ← pStr p "reserveNo",
           flight := some { departureDate := ← pDate p "flight.departureDate",
                            flightMaster := fn.map fun n => { flightName := some n },
                            boardingClass := bc.map fun c => { boardingClassCd := some c },
                            fareType := ft.map fun c => { fareTypeCd := some c } } }

def passengerOf (p : Json) : Except String Passenger := do
  return { passengerNo := ← pInt p "passengerNo", reserveFlightNo := ← pInt p "reserveFlightNo",
           familyName := ← pStr p "familyName", givenName := ← pStr p "givenName", age := ← pInt p "age",
           gender := ← pEnum p "gender.code" Spec.Model.Gender.ofCode?, member := memberRef (← pStr p "member.membershipNumber") }

/-! ## 結果の比較 -/

/-- `SqlError` を（SQLSTATE の条件名, 比べる名前）に。`string_data_right_truncation` は名前を比べない。 -/
def errorKey : SqlError → String × Option String
  | .uniqueViolation c => ("unique_violation", some c.toLower)
  | .notNullViolation c => ("not_null_violation", some c.toLower)
  | .foreignKeyViolation c => ("foreign_key_violation", some c.toLower)
  | .numericOutOfRange => ("numeric_value_out_of_range", none)
  | .stringTooLong _ => ("string_data_right_truncation", none)
  | .dateOutOfRange => ("datetime_field_overflow", none)
  | .sequenceExhausted _ => ("sequence_generator_limit_exceeded", none)
  | .other m => ("other", some m)

/-- PostgreSQL の誤りを（条件名, 比べる名前）に。 -/
def pgErrorKey (e : Json) : Except String (String × Option String) := do
  let cond ← getStr e "condition"
  let name := match cond with
    | "unique_violation" | "foreign_key_violation" => (e.getObjValAs? String "constraint").toOption.map (·.toLower)
    | "not_null_violation" => (e.getObjValAs? String "column").toOption.map (·.toLower)
    | _ => none
  return (cond, name)

/-- PostgreSQL の段の結果。 -/
inductive PgResult where
  | rows (t : Table)
  | count (n : Nat)
  | error (key : String × Option String)

def pgResult (r : Json) : Except String PgResult := do
  if let .ok e := r.getObjVal? "error" then return .error (← pgErrorKey e)
  if let .ok n := r.getObjValAs? Nat "count" then return .count n
  let cols ← (r.getObjValAs? (Array String) "columns").map (·.toList)
  let rows ← (← getArr r "rows").mapM rowOf
  return .rows (← Table.ofRows cols rows)

def showPg : PgResult → String
  | .rows t => s!"{t.rows.length} rows"
  | .count n => s!"count {n}"
  | .error (c, n) => s!"{c} {n.getD ""}"

/-- モデルの段の結果。 -/
inductive ModelResult where
  /-- 行を返す文: PostgreSQL の表と比べる関数。 -/
  | rows (eq : Table → Except String Bool) (info : String)
  | count (n : Nat)
  | error (e : SqlError)

def showModel : ModelResult → String
  | .rows _ info => info
  | .count n => s!"count {n}"
  | .error e => let (c, n) := errorKey e; s!"{c} {n.getD ""}"

/-- 1 列の値の表。 -/
def single (t : Table) : Except String String := do
  let [[some v]] := t.rows | throw s!"expected a single value, got {t.rows}"
  pure v

/-- 段の評価: モデルの結果と次の状態。 -/
def evalStep (mdb : MasterDb) (fd : FlightDb) (op : String) (p : Json) : Except String (ModelResult × FlightDb) := do
  let ofSql {α : Type} (r : SqlResult (α × FlightDb)) (f : α → ModelResult) : ModelResult × FlightDb :=
    match r with
    | .ok (a, fd') => (f a, fd')
    | .error e => (.error e, fd)
  match op with
  | "flight.exists" =>
    let b := existsRows fd (← keyParams p)
    return (.rows (fun t => do pure ((← single t) == (if b then "t" else "f"))) s!"exists {b}", fd)
  | "flight.findOneForUpdate" =>
    let mine := findOneForUpdateRows fd (← keyParams p)
    let eq (t : Table) : Except String Bool := do
      let pg ← t.rows.mapM fun x => do
        let f ← flightRow t x
        pure ({ departureDate := f.departureDate, flightName := f.flightName, fareTypeCd := f.fareTypeCd,
                vacantNum := f.vacantNum, boardingClassCd := f.boardingClassCd } : FlightResult)
      pure (t.columns == ["departure_date", "flight_name", "fare_type_cd", "vacant_num", "boarding_class_cd"] &&
        Bag.bagEq mine pg)
    return (.rows eq s!"{mine.length} rows", fd)
  | "flight.update" =>
    return ofSql (updateRows fd (← updateKey p) (← pInt p "vacantNum")) .count
  | "member.findOne" =>
    let mine := SourceModel.Domain.Repository.Member.MemberRepository.findOneRows mdb fd
      (match ← pStr p "membershipNumber" with | some s => .text s | none => .null)
    let eq (t : Table) : Except String Bool := do
      -- 会員の credit_type_cd は c_t.credit_type_cd（結合の条件で等しい）、会員ログインの customer_no は m.customer_no
      let pg ← t.rows.mapM fun x => do
        let m ← memberRow t x
        pure (m, ← memberLoginRow t x, ← vcol 80 t x "credit_firm")
      let mine' := mine.map fun r => (r.member, r.login, r.creditType.creditFirm)
      pure (Bag.bagEq mine' pg)
    return (.rows eq s!"{mine.length} rows", fd)
  | "reservation.nextReserveNo" =>
    return ofSql (nextReserveNo fd) fun s => .rows (fun t => do pure ((← single t) == s)) s!"\"{s}\""
  | "reservation.insert" => return ofSql (insertRow fd (← reservationOf p)) .count
  | "reservation.nextReserveFlightNo" =>
    return ofSql (nextReserveFlightNo fd) fun n => .rows (fun t => do pure ((← single t) == toString n)) s!"{n}"
  | "reservation.insertReserveFlight" => return ofSql (insertReserveFlightRow fd (← reserveFlightOf p)) .count
  | "reservation.nextPassengerNo" =>
    return ofSql (nextPassengerNo fd) fun n => .rows (fun t => do pure ((← single t) == toString n)) s!"{n}"
  | "reservation.insertPassenger" => return ofSql (insertPassengerRow fd (← passengerOf p)) .count
  | _ => throw s!"unknown op {op}"

/-- モデルの結果と PostgreSQL の結果が一致する。 -/
def resultMatches (m : ModelResult) (pg : PgResult) : Except String Bool :=
  match m, pg with
  | .rows eq _, .rows t => eq t
  | .count n, .count k => pure (n == k)
  | .error e, .error k => pure (errorKey e == k)
  | _, _ => pure false

/-- `NEXTVAL` の値が int の範囲を超える段: `readInteger` が失敗し、その値の INSERT の誤りが `Int4.ofInt` の誤りと一致する。 -/
def overflowMatches (step : Json) (res : ModelResult) : Except String Bool := do
  let some n := (match res with | .rows _ info => info.toInt? | _ => none) | return true
  let inRange := decide (-2147483648 ≤ n ∧ n ≤ 2147483647)
  let readOk := match readInteger n with | .ok v => v.val == n | .error _ => false
  match step.getObjVal? "insertWithValue" with
  | .error _ => return inRange && readOk
  | .ok iv =>
    let pg ← pgErrorKey (← (← iv.getObjVal? "result").getObjVal? "error")
    let mine := match Int4.ofInt n with | .ok _ => none | .error e => some (errorKey e)
    return !inRange && !readOk && mine == some pg

/-- 1 つのケースの照合（ID, 一致したか, 説明, 既知の差異か）。 -/
def checkCase (mdb : MasterDb) (c : Json) : Except String (String × Bool × String × Bool) := do
  let id ← getStr c "id"
  let known := (c.getObjVal? "knownMismatch").isOk
  let mut fd ← decodeState (← c.getObjVal? "initial")
  let mut ok := true
  let mut info : List String := []
  for s in ← getArr c "steps" do
    let op ← getStr s "op"
    let (res, fd') ← evalStep mdb fd op (← s.getObjVal? "params")
    let pg ← pgResult (← s.getObjVal? "result")
    let same ← resultMatches res pg
    let ovf ← if op == "reservation.nextReserveFlightNo" || op == "reservation.nextPassengerNo" then overflowMatches s res
      else pure true
    unless same && ovf do
      ok := false
      info := info ++ [s!"{op}: model {showModel res}, PostgreSQL {showPg pg}{if ovf then "" else " (int overflow check)"}"]
    if !same then break
    fd := fd'
    if let .error _ := res then break
  let final ← decodeState (← c.getObjVal? "final")
  let diff := stateDiff fd final
  if ok && !diff.isEmpty then
    ok := false
    info := info ++ [s!"final state differs: {diff}"]
  let n := (← getArr c "steps").length
  return (id, ok, if info.isEmpty then s!"{n} steps" else String.intercalate "; " info, known)

def run (master : Json) (doc : Json) : Except String (List (String × Bool × String × Bool)) := do
  let mdb ← Tests.MasterSql.decodeDb master
  (← getArr doc "cases").mapM (checkCase mdb)

/-! ## シード -/

/-- シードの照合（項目, 一致したか）。 -/
def seedMatches (doc : Json) : Except String (List (String × Bool)) := do
  let seed ← doc.getObjVal? "seed"
  let members ← rowsOf seed "MEMBER" memberRow
  let logins ← rowsOf seed "MEMBER_LOGIN" memberLoginRow
  let noTime (l : MemberLoginRow) : MemberLoginRow := { l with loginDateTime := none }
  let pgNotNull := (seed.getObjValAs? Bool "loginDateTimeNotNull").toOption == some true
  return [
    (s!"MEMBER = MemberSeed.memberRows ({members.length} rows)", Bag.bagEq members SourceModel.Db.MemberSeed.memberRows),
    (s!"MEMBER_LOGIN = MemberSeed.memberLoginRows except login_date_time ({logins.length} rows)",
      Bag.bagEq logins (SourceModel.Db.MemberSeed.memberLoginRows.map noTime)),
    ("login_date_time is not NULL (PostgreSQL: localtimestamp; model: load date 00:00)",
      pgNotNull && SourceModel.Db.MemberSeed.memberLoginRows.all (·.loginDateTime.isSome)),
    ("sq_member_1 = MemberSeed.sqMember", (← seqOf seed "sq_member_1") == SourceModel.Db.MemberSeed.sqMember),
    ("sq_reservation_1, sq_reserve_flight_1, sq_passenger_1 unused",
      (← seqOf seed "sq_reservation_1") == none && (← seqOf seed "sq_reserve_flight_1") == none &&
      (← seqOf seed "sq_passenger_1") == none)]

end Tests.ReservationSql
