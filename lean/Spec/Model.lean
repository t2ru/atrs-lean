import Spec.Prim

/-!
# Spec.Model

列挙・コード値・エンティティ・値域（`docs/spec/domain-model.md`）。

- 列挙の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（`toCode`・`ofCode?`）。
- コード値は `String` を包む structure とする。形式の決まったコード値（空港コード・便名・カード種別コード）は、形式の
  証明を欄（`wf`、既定 `by decide`）に持ち、形式に合わない値を表現できない（`ofString?` で読む）。会員番号の形式は
  述語（`WellFormed`）で表す。マスタに存在することは `Spec.MasterData` の参照関数と不変条件で表す。
- エンティティの `?` は `Option` である。採番される番号（予約番号・会員番号など）は、登録の操作で決まる。
-/

namespace Spec.Model
open Spec.Prim.Text

open Spec.Prim

/-! ## 列挙 -/

/-- 往復・片道。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive FlightType where
  | RT | OW
  deriving DecidableEq, Repr

/-- 搭乗クラス（一般席・特別席）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive BoardingClassCd where
  | N | S
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive FareTypeCd where
  | OW | RT | RD1 | RD7 | ED | LD | GD | SOW | SRT | SRD
  deriving DecidableEq, Repr

/-- 性別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive Gender where
  | F | M
  deriving DecidableEq, Repr

/-- 往路・復路。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive LineType where
  | OUTWARD | HOMEWARD
  deriving DecidableEq, Repr

namespace FlightType
def toCode : FlightType → String | RT => "RT" | OW => "OW"
def ofCode? : String → Option FlightType | "RT" => some RT | "OW" => some OW | _ => none
theorem ofCode?_toCode (x : FlightType) : ofCode? x.toCode = some x := by cases x <;> rfl
end FlightType

namespace BoardingClassCd
def toCode : BoardingClassCd → String | N => "N" | S => "S"
def ofCode? : String → Option BoardingClassCd | "N" => some N | "S" => some S | _ => none
theorem ofCode?_toCode (x : BoardingClassCd) : ofCode? x.toCode = some x := by cases x <;> rfl
end BoardingClassCd

namespace FareTypeCd
def toCode : FareTypeCd → String
  | OW => "OW" | RT => "RT" | RD1 => "RD1" | RD7 => "RD7" | ED => "ED"
  | LD => "LD" | GD => "GD" | SOW => "SOW" | SRT => "SRT" | SRD => "SRD"
def ofCode? : String → Option FareTypeCd
  | "OW" => some OW | "RT" => some RT | "RD1" => some RD1 | "RD7" => some RD7 | "ED" => some ED
  | "LD" => some LD | "GD" => some GD | "SOW" => some SOW | "SRT" => some SRT | "SRD" => some SRD
  | _ => none
theorem ofCode?_toCode (x : FareTypeCd) : ofCode? x.toCode = some x := by cases x <;> rfl
end FareTypeCd

namespace Gender
def toCode : Gender → String | F => "F" | M => "M"
def ofCode? : String → Option Gender | "F" => some F | "M" => some M | _ => none
theorem ofCode?_toCode (x : Gender) : ofCode? x.toCode = some x := by cases x <;> rfl
end Gender

namespace LineType
def toCode : LineType → String | OUTWARD => "OUTWARD" | HOMEWARD => "HOMEWARD"
def ofCode? : String → Option LineType
  | "OUTWARD" => some OUTWARD | "HOMEWARD" => some HOMEWARD | _ => none
theorem ofCode?_toCode (x : LineType) : ofCode? x.toCode = some x := by cases x <;> rfl
/-- 表示用ラベル。 -/
def label : LineType → String | OUTWARD => "往路" | HOMEWARD => "復路"
end LineType

/-- 片道の運賃種別（この順序）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def oneWayFareTypes : List FareTypeCd := [.OW, .RD1, .RD7, .ED, .LD, .GD, .SOW, .SRD]

/-- 往復の運賃種別（この順序）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def roundTripFareTypes : List FareTypeCd := [.RT, .SRT]

/-- 搭乗の種別に対応する運賃種別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def fareTypesFor : FlightType → List FareTypeCd
  | .OW => oneWayFareTypes
  | .RT => roundTripFareTypes

/-- どの運賃種別も、片道か往復のどちらか一方だけに属する。 -/
theorem fareType_partition (c : FareTypeCd) : (c ∈ oneWayFareTypes) ≠ (c ∈ roundTripFareTypes) := by
  cases c <;> decide

/-! ## コード値 -/

/-- 英大文字。 -/
def isUpperAlpha (c : Char) : Bool := inRange 0x41 0x5A c

/-- 空港コードの形式: 英大文字 3 文字（`toList` で見る）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def AirportCd.valid (s : String) : Bool := s.toList.length == 3 && s.toList.all isUpperAlpha

/-- 空港コード。形式（`AirportCd.valid`）の証明を持つ。形式に合わない DB のマスタのコードは表せない（D-036。D-027 に覆われる）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値", gap "D-036"]
structure AirportCd where
  val : String
  wf : AirportCd.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 空港コードを読む。形式に合わなければ無し。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def AirportCd.ofString? (s : String) : Option AirportCd := if h : AirportCd.valid s then some ⟨s, h⟩ else none

/-- 空港コードは値で決まる。 -/
theorem AirportCd.ext {a b : AirportCd} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めた空港コードの値は、読んだ文字列そのもの。 -/
theorem AirportCd.val_of_ofString? {s : String} {c : AirportCd} (h : AirportCd.ofString? s = some c) : c.val = s := by
  unfold AirportCd.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- 空港コードの値を読むと、その空港コード。 -/
@[simp] theorem AirportCd.ofString?_val (c : AirportCd) : AirportCd.ofString? c.val = some c := by
  simp [AirportCd.ofString?, c.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem AirportCd.ofString?_isSome_iff {s : String} : (AirportCd.ofString? s).isSome ↔ AirportCd.valid s = true := by
  unfold AirportCd.ofString?
  split <;> simp_all

/-- 便名の形式: 1〜6 文字で、`"`・`,`・改行を含まない（[Spec] の前提。ADR f353。`toList` で見る）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def FlightName.valid (s : String) : Bool :=
  1 ≤ s.toList.length && s.toList.length ≤ 6 &&
    s.toList.all (fun c => c != '"' && c != ',' && c != '\n' && c != '\r')

/-- 便名。形式（`FlightName.valid`）の証明を持つ。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure FlightName where
  val : String
  wf : FlightName.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 便名を読む。形式に合わなければ無し。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def FlightName.ofString? (s : String) : Option FlightName := if h : FlightName.valid s then some ⟨s, h⟩ else none

/-- 便名は値で決まる。 -/
theorem FlightName.ext {a b : FlightName} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めた便名の値は、読んだ文字列そのもの。 -/
theorem FlightName.val_of_ofString? {s : String} {n : FlightName} (h : FlightName.ofString? s = some n) : n.val = s := by
  unfold FlightName.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- 便名の値を読むと、その便名。 -/
@[simp] theorem FlightName.ofString?_val (n : FlightName) : FlightName.ofString? n.val = some n := by
  simp [FlightName.ofString?, n.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem FlightName.ofString?_isSome_iff {s : String} : (FlightName.ofString? s).isSome ↔ FlightName.valid s = true := by
  unfold FlightName.ofString?
  split <;> simp_all

/-- 会員番号。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure MembershipNumber where
  val : String
  deriving DecidableEq, Repr

/-- 会員番号の形式: 数字 10 文字。 -/
def MembershipNumber.WellFormed (n : MembershipNumber) : Prop := n.val.length = 10 ∧ n.val.all isDigit = true

/-- 予約番号。採番の値で持つ（上限を持たない。ADR 6d36）。表記 `val` は 10 桁にゼロ埋めした十進文字列で、採番が
10^10 以上なら 11 桁以上になる（[Source] のシーケンスは上限で循環する。既知差異 D-009）。どの採番の値も予約番号として
妥当なので、型は不正な値を持たない。 -/
@[spec_doc "docs/spec/domain-model.md#コード値", gap "D-009"]
structure ReserveNo where
  num : Nat
  deriving DecidableEq, Repr

/-- 予約番号の表記: 10 桁にゼロ埋めした十進文字列。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def ReserveNo.val (n : ReserveNo) : String := Spec.Prim.Format.padNat 10 n.num

/-- 予約番号の表記を読む。表記 `val` の形（10 桁以上のゼロ埋めの十進文字列）でなければ無し。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def ReserveNo.ofString? (s : String) : Option ReserveNo :=
  let n : ReserveNo := ⟨s.toList.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0⟩
  if n.val = s then some n else none

/-- 読めた予約番号の表記は、読んだ文字列そのもの。 -/
theorem ReserveNo.val_of_ofString? {s : String} {n : ReserveNo} (h : ReserveNo.ofString? s = some n) : n.val = s := by
  unfold ReserveNo.ofString? at h
  by_cases hv : (⟨s.toList.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0⟩ : ReserveNo).val = s
  · simp only [hv, ite_true, Option.some.injEq] at h
    subst h; exact hv
  · simp only [hv, ite_false, reduceCtorEq] at h

/-- カード種別コードの形式: 3 文字（`toList` で見る）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def CreditTypeCd.valid (s : String) : Bool := s.toList.length == 3

/-- カード種別コード。形式（`CreditTypeCd.valid`）の証明を持つ。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure CreditTypeCd where
  val : String
  wf : CreditTypeCd.valid val = true := by decide
  deriving DecidableEq, Repr

/-- カード種別コードを読む。形式に合わなければ無し。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
def CreditTypeCd.ofString? (s : String) : Option CreditTypeCd :=
  if h : CreditTypeCd.valid s then some ⟨s, h⟩ else none

/-- カード種別コードは値で決まる。 -/
theorem CreditTypeCd.ext {a b : CreditTypeCd} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めたカード種別コードの値は、読んだ文字列そのもの。 -/
theorem CreditTypeCd.val_of_ofString? {s : String} {c : CreditTypeCd} (h : CreditTypeCd.ofString? s = some c) :
    c.val = s := by
  unfold CreditTypeCd.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- カード種別コードの値を読むと、そのカード種別コード。 -/
@[simp] theorem CreditTypeCd.ofString?_val (c : CreditTypeCd) : CreditTypeCd.ofString? c.val = some c := by
  simp [CreditTypeCd.ofString?, c.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem CreditTypeCd.ofString?_isSome_iff {s : String} :
    (CreditTypeCd.ofString? s).isSome ↔ CreditTypeCd.valid s = true := by
  unfold CreditTypeCd.ofString?
  split <;> simp_all

/-- パスワードのハッシュ（不透明。ADR 2d1f）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値", raw_input "パスワードエンコーダのポートが返す不透明な値（ADR 2d1f）"]
structure PasswordHash where
  val : String
  deriving DecidableEq, Repr

instance (n : MembershipNumber) : Decidable n.WellFormed := by
  unfold MembershipNumber.WellFormed; infer_instance

/-! ## エンティティ -/

/-- フライトの主キー。 -/
@[spec_doc "docs/spec/domain-model.md#flight"]
structure FlightKey where
  departureDate : Date
  flightName : FlightName
  boardingClassCd : BoardingClassCd
  fareTypeCd : FareTypeCd
  deriving DecidableEq

/-- フライト（空席数を持つ）。 -/
@[spec_doc "docs/spec/domain-model.md#flight"]
structure Flight where
  key : FlightKey
  vacantNum : Nat
  deriving DecidableEq

/-- 搭乗者。採番される搭乗者番号は、予約の登録で決まる（`PassengerRecord`）。 -/
@[spec_doc "docs/spec/domain-model.md#passenger"]
structure Passenger where
  familyName : String
  givenName : String
  age : Nat
  gender : Gender
  membershipNumber : Option MembershipNumber
  deriving DecidableEq

/-- 登録した搭乗者（採番した搭乗者番号を伴う）。 -/
@[spec_doc "docs/spec/domain-model.md#passenger"]
structure PassengerRecord where
  passengerNo : Nat
  passenger : Passenger
  deriving DecidableEq

/-- 予約フライト。往路・復路で同一の搭乗者列を持つ（搭乗者番号は予約フライトごとに採番する）。 -/
@[spec_doc "docs/spec/domain-model.md#reserveflight"]
structure ReserveFlight where
  reserveFlightNo : Nat
  reserveNo : ReserveNo
  flight : FlightKey
  passengers : List PassengerRecord
  deriving DecidableEq

/-- 予約。`reserveFlights` は長さ 1（片道）または 2（往復: 往路, 復路の順）。 -/
@[spec_doc "docs/spec/domain-model.md#reservation"]
structure Reservation where
  reserveNo : ReserveNo
  reserveDate : Date
  totalFare : Nat
  repFamilyName : String
  repGivenName : String
  repAge : Nat
  repGender : Gender
  repTel : String
  repMail : String
  repMembershipNumber : Option MembershipNumber
  reserveFlights : List ReserveFlight
  deriving DecidableEq

/-- 会員のログイン情報。 -/
@[spec_doc "docs/spec/domain-model.md#memberlogin"]
structure MemberLogin where
  password : PasswordHash
  lastPassword : Option PasswordHash
  loginDateTime : Option Date
  loginFlg : Bool
  deriving DecidableEq

/-- 会員。 -/
@[spec_doc "docs/spec/domain-model.md#member"]
structure Member where
  membershipNumber : MembershipNumber
  kanjiFamilyName : String
  kanjiGivenName : String
  kanaFamilyName : String
  kanaGivenName : String
  birthday : Date
  gender : Gender
  tel : String
  zipCode : String
  address : String
  mail : String
  creditNo : String
  creditTypeCd : CreditTypeCd
  creditTerm : String
  login : MemberLogin
  deriving DecidableEq

/-! ## 値域（`docs/spec/domain-model.md#値域`。各操作の PRE に含める） -/

namespace Range

/-- `Route.basicFare + BoardingClass.extraCharge` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域", gap "D-030"]
def maxBasicFareWithCharge : Nat := 10000000

/-- 基本運賃（`basicFare` の値）の上限。`maxBasicFareWithCharge × maxMultiplicationRatio / 100`。 -/
@[spec_doc "docs/spec/domain-model.md#値域", gap "D-030"]
def maxBasicFare : Nat := 100000000

/-- `PeakTime.multiplicationRatio` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域", gap "D-030"]
def maxMultiplicationRatio : Nat := 1000

/-- `FareType.discountRate` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域", gap "D-030"]
def maxDiscountRate : Nat := 100

/-- 搭乗者数の範囲。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def minPassengers : Nat := 1
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxPassengers : Nat := 6

/-- 予約フライト数の範囲。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def minReserveFlights : Nat := 1
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxReserveFlights : Nat := 2

/-- `Flight.vacantNum` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxVacantNum : Nat := 2147483647

/-- 年齢の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxAge : Nat := 999

end Range

end Spec.Model
